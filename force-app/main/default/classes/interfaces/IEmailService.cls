/**
 * Interface for email sending service
 * Allows for mocking of Messaging.sendEmail() in tests
 */
public interface IEmailService {
  /**
   * Send email messages. Never throws for per-message failures - each input
   * email produces exactly one AckSendResult, in the same order, indicating
   * whether that specific message succeeded or failed.
   * @param emails List of email messages to send
   * @return List of AckSendResult, one per input email, same order
   */
  List<AckSendResult> sendEmail(List<Messaging.SingleEmailMessage> emails);
}
