/**
 * IEmailService defines an interface for sending emails in bulk.
 * Implementations should return a List of Messaging.SendEmailResult,
 * one for each email sent.
 *
 * See: https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_email_outbound.htm
 */
public interface IEmailService {
  /**
   * Sends a list of SingleEmailMessage objects.
   * @param emails List of Messaging.SingleEmailMessage to send.
   * @return List of Messaging.SendEmailResult, one per email.
   */
  List<Messaging.SendEmailResult> sendEmails(
    List<Messaging.SingleEmailMessage> emails
  );
}
