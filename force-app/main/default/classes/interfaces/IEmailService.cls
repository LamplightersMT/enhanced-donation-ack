/**
 * Interface for email sending service
 * Allows for mocking of Messaging.sendEmail() in tests
 */
public interface IEmailService {
  /**
   * Send email messages
   * @param emails List of email messages to send
   * @throws System.EmailException if there is an error sending emails
   */
  void sendEmail(List<Messaging.SingleEmailMessage> emails);
}
