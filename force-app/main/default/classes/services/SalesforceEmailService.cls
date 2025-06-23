/**
 * SalesforceEmailService is the production implementation of IEmailService.
 * It sends emails using Messaging.sendEmail and returns the results.
 */
public with sharing class SalesforceEmailService implements IEmailService {
  /**
   * Sends a list of SingleEmailMessage objects using Messaging.sendEmail.
   * @param emails List of Messaging.SingleEmailMessage to send.
   * @return List of Messaging.SendEmailResult, one per email.
   */
  public List<Messaging.SendEmailResult> sendEmails(
    List<Messaging.SingleEmailMessage> emails
  ) {
    if (emails == null || emails.isEmpty()) {
      return new List<Messaging.SendEmailResult>();
    }
    try {
      return Messaging.sendEmail(emails, false);
    } catch (Exception ex) {
      // Log and rethrow or handle as needed for your org
      System.debug(
        LoggingLevel.ERROR,
        'Error sending emails: ' + ex.getMessage()
      );
      throw ex;
    }
  }
}
