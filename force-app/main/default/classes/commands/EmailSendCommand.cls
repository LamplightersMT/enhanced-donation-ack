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
    if (emails.isEmpty()) {
      sendOutput = new AcknowledgementCommandOutputs.SendOutput()
        .setSuccess(
          new List<DonationAcknowledgementService.OpportunityResult>()
        );
      return;
    }

    try {
      List<Messaging.SendEmailResult> results = emailService.sendEmails(emails);
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
        if (emailResult.isSuccess()) {
          oppResult.setStatus(
            DonationAcknowledgementService.AckStatus.SUCCESS,
            'Email sent successfully'
          );
          oppResult.acknowledgmentDate = today;
        } else {
          allSuccessful = false;
          String errorMsg = 'Email sending failed';
          if (!emailResult.getErrors().isEmpty()) {
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
        sendOutput = new AcknowledgementCommandOutputs.SendOutput()
          .setFailure(
            'Failed to send acknowledgement emails',
            opportunityResults
          );
      }
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
