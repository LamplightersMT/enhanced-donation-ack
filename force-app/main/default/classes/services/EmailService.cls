/**
 * Default implementation of IEmailService that uses the Salesforce Messaging class
 */
public with sharing class EmailService implements IEmailService {
  /**
   * Send email messages using the standard Salesforce Messaging class
   * @param emails List of email messages to send
   * @throws System.EmailException if there is an error sending emails
   */
  public void sendEmail(List<Messaging.SingleEmailMessage> emails) {
    List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails);
    for (Messaging.SendEmailResult result : results) {
      if (!result.isSuccess()) {
        List<String> errors = new List<String>();
        for (Messaging.SendEmailError err : result.getErrors()) {
          errors.add(err.getMessage());
        }
        throw new System.EmailException(String.join(errors, '; '));
      }
    }
  }
}
