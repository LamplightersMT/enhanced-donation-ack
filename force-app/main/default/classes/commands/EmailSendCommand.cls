/**
 * Command to send prepared email messages
 * Returns SendOutput with success/failure tracking
 */
public with sharing class EmailSendCommand implements IAcknowledgementCommand {
  private List<Messaging.SingleEmailMessage> emails;
  private List<DonationAcknowledgementService.OpportunityResult> opportunityResults;
  private AcknowledgementCommandOutputs.SendOutput sendOutput;

  @TestVisible
  public static IEmailService emailService = new SalesforceEmailService();

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
    try {
      // Defensive: Ensure emailService is set
      if (emailService == null) {
        emailService = new SalesforceEmailService();
      }

      // Early return for empty email list
      if (emails == null || emails.isEmpty()) {
        sendOutput = new AcknowledgementCommandOutputs.SendOutput()
          .setSuccess(
            new List<DonationAcknowledgementService.OpportunityResult>()
          );
        return;
      }

      List<Messaging.SendEmailResult> results = emailService.sendEmails(emails);

      // Defensive: Ensure results is not null and matches emails size
      if (results == null) {
        throw new System.CalloutException(
          'Email service returned null results'
        );
      }
      if (results.size() != emails.size()) {
        throw new System.CalloutException(
          'Email service returned ' +
            results.size() +
            ' results for ' +
            emails.size() +
            ' emails'
        );
      }
      if (opportunityResults.size() != emails.size()) {
        throw new System.CalloutException(
          'Opportunity results size (' +
            opportunityResults.size() +
            ') does not match emails size (' +
            emails.size() +
            ')'
        );
      }

      Date today = Date.today();
      Boolean allSuccessful = true;

      // For each opportunity result, match to its corresponding email send result by index.
      // If the email was sent successfully, mark as SUCCESS and set the acknowledgment date.
      // If the email failed, mark as EMAIL_SEND_FAILED and record the error message.
      for (Integer i = 0; i < opportunityResults.size(); i++) {
        DonationAcknowledgementService.OpportunityResult oppResult = opportunityResults[
          i
        ];
        Messaging.SendEmailResult emailResult = results[i];

        if (emailResult == null || emailResult.isSuccess()) {
          oppResult.setStatus(
            DonationAcknowledgementService.AckStatus.SUCCESS,
            'Email sent successfully'
          );
          oppResult.acknowledgmentDate = today;
        } else {
          allSuccessful = false;
          String errorMsg = 'Email sending failed';
          if (
            emailResult.getErrors() != null &&
            !emailResult.getErrors().isEmpty()
          ) {
            errorMsg += ': ' + emailResult.getErrors()[0].getMessage();
          }
          oppResult.setStatus(
            DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
            errorMsg
          );
        }
      }

      if (allSuccessful) {
        sendOutput = new AcknowledgementCommandOutputs.SendOutput()
          .setSuccess(opportunityResults);
      } else {
        // Separate successful and failed opportunities
        List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>();
        List<DonationAcknowledgementService.OpportunityResult> failedOpps = new List<DonationAcknowledgementService.OpportunityResult>();

        for (
          DonationAcknowledgementService.OpportunityResult oppResult : opportunityResults
        ) {
          if (
            oppResult.status == DonationAcknowledgementService.AckStatus.SUCCESS
          ) {
            successfulOpps.add(oppResult);
          } else {
            failedOpps.add(oppResult);
          }
        }

        sendOutput = new AcknowledgementCommandOutputs.SendOutput()
          .setPartialFailure(
            'Failed to send acknowledgement emails',
            successfulOpps,
            failedOpps
          );
      }
    } catch (System.CalloutException ee) {
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
          'Email sending failed: ' + ee.getMessage(),
          opportunityResults
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
