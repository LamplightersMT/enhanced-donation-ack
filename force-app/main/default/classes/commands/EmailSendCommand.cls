/**
 * Command to send prepared email messages.
 * Never throws for expected failures - each message's success/failure is tracked
 * individually via AckSendResult and reflected in the opportunity results.
 * Returns SendOutput with per-message success/failure tracking.
 */
public with sharing class EmailSendCommand implements IAcknowledgementCommand {
  private List<Messaging.SingleEmailMessage> emails;
  private List<AckOpportunityResult> opportunityResults;
  private AcknowledgementCommandOutputs.SendOutput sendOutput;

  // Mutable instance variable for dependency injection
  @TestVisible
  public IEmailService emailService = new EmailService();

  public EmailSendCommand(
    List<Messaging.SingleEmailMessage> emails,
    List<AckOpportunityResult> opportunityResults
  ) {
    this.emails = emails;
    this.opportunityResults = opportunityResults;
    this.sendOutput = new AcknowledgementCommandOutputs.SendOutput();
  }

  /**
   * Execute email sending. Maps each per-message AckSendResult back to its
   * corresponding AckOpportunityResult by index (emails and opportunityResults
   * are built together in EmailPreparationCommand, so the ordering is aligned).
   */
  public void execute() {
    if (emails.isEmpty()) {
      sendOutput = new AcknowledgementCommandOutputs.SendOutput()
        .setResults(
          new List<AckOpportunityResult>(),
          new List<AckOpportunityResult>()
        );
      return;
    }

    List<AckSendResult> results = emailService.sendEmail(emails);
    Date today = Date.today();

    List<AckOpportunityResult> successful = new List<AckOpportunityResult>();
    List<AckOpportunityResult> failed = new List<AckOpportunityResult>();

    for (Integer i = 0; i < opportunityResults.size(); i++) {
      AckOpportunityResult oppResult = opportunityResults[i];
      AckSendResult sendResult = i < results.size()
        ? results[i]
        : AckSendResult.fail('No send result returned for this message');

      if (sendResult.success) {
        oppResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
        oppResult.acknowledgmentDate = today;
        successful.add(oppResult);
      } else {
        oppResult.setStatus(
          AckStatus.EMAIL_SEND_FAILED,
          'Email sending failed: ' + sendResult.errorMessage
        );
        failed.add(oppResult);
      }
    }

    sendOutput = new AcknowledgementCommandOutputs.SendOutput()
      .setResults(successful, failed);
  }

  /**
   * Get the email send output
   * @return SendOutput with per-message success/failure tracking
   */
  public AcknowledgementCommandOutputs.SendOutput getOutput() {
    return sendOutput;
  }
}
