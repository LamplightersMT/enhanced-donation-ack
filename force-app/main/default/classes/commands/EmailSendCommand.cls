/**
 * Command to send prepared email messages
 * Returns SendOutput with success/failure tracking
 */
public with sharing class EmailSendCommand implements IAcknowledgementCommand {
  private List<Messaging.SingleEmailMessage> emails;
  private List<DonationAcknowledgementService.OpportunityResult> opportunityResults;
  private AcknowledgementCommandOutputs.SendOutput sendOutput;

  // Mutable instance variable for dependency injection
  @TestVisible
  private IEmailService emailService = new EmailService();

  public EmailSendCommand(
    List<Messaging.SingleEmailMessage> emails,
    List<DonationAcknowledgementService.OpportunityResult> opportunityResults
  ) {
    this.emails = emails;
    this.opportunityResults = opportunityResults;
    this.sendOutput = new AcknowledgementCommandOutputs.SendOutput();
  }

  /**
   * Execute email sending
   */
  public void execute() {
    if (emails.isEmpty()) {
      sendOutput = new AcknowledgementCommandOutputs.SendOutput()
        .setSuccess(
          new List<DonationAcknowledgementService.OpportunityResult>()
        );
      return;
    }

    try {
      emailService.sendEmail(emails);

      // Mark all prepared opportunities as successful
      Date today = Date.today();
      for (
        DonationAcknowledgementService.OpportunityResult oppResult : opportunityResults
      ) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.SUCCESS,
          'Email sent successfully'
        );
        oppResult.acknowledgmentDate = today;
      }

      sendOutput = new AcknowledgementCommandOutputs.SendOutput()
        .setSuccess(opportunityResults);
    } catch (EmailException ee) {
      System.debug(
        LoggingLevel.ERROR,
        'Email sending failed: ' + ee.getMessage()
      );

      // Mark all prepared opportunities as failed
      for (
        DonationAcknowledgementService.OpportunityResult oppResult : opportunityResults
      ) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
          'Email sending failed: ' + ee.getMessage()
        );
      }

      sendOutput = new AcknowledgementCommandOutputs.SendOutput()
        .setFailure(
          'Failed to send acknowledgement emails: ' + ee.getMessage(),
          opportunityResults
        );

      throw new AuraHandledException(
        'Failed to send acknowledgement emails: ' + ee.getMessage()
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Unexpected error during email processing: ' + e.getMessage()
      );

      // Mark all prepared opportunities as failed
      for (
        DonationAcknowledgementService.OpportunityResult oppResult : opportunityResults
      ) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
          'Unexpected error: ' + e.getMessage()
        );
      }

      sendOutput = new AcknowledgementCommandOutputs.SendOutput()
        .setFailure(
          'Failed to send acknowledgement emails: ' + e.getMessage(),
          opportunityResults
        );

      throw new AuraHandledException(
        'Failed to send acknowledgement emails: ' + e.getMessage()
      );
    }
  }

  /**
   * Get the email send output
   * @return SendOutput with success/failure tracking
   */
  public AcknowledgementCommandOutputs.SendOutput getOutput() {
    return sendOutput;
  }
}
