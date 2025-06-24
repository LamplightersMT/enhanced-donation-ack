/**
 * Mock implementation of IEmailService for testing
 */
@isTest
public class MockEmailService implements IEmailService {
  private Boolean successful = true;
  private String errorMessage;
  private Integer callCount = 0;
  private List<Messaging.SingleEmailMessage> lastEmailsSent;

  public MockEmailService setSuccessful() {
    this.successful = true;
    this.errorMessage = null;
    return this;
  }
  public MockEmailService setFailure(String errorMessage) {
    this.successful = false;
    this.errorMessage = errorMessage;
    return this;
  }
  public MockEmailService reset() {
    this.callCount = 0;
    this.lastEmailsSent = null;
    this.errorMessage = null;
    this.successful = true;
    return this;
  }
  public void sendEmail(List<Messaging.SingleEmailMessage> emails) {
    this.callCount++;
    this.lastEmailsSent = emails;
    if (!successful) {
      throw new System.EmailException(errorMessage);
    }
  }
  public void verifyEmailCount(Integer expectedCount) {
    System.assertEquals(
      expectedCount,
      lastEmailsSent != null ? lastEmailsSent.size() : 0,
      'Expected ' +
        expectedCount +
        ' emails to be sent, but found ' +
        (lastEmailsSent != null ? lastEmailsSent.size() : 0)
    );
  }
  public void verifySendCount(Integer expectedCount) {
    System.assertEquals(
      expectedCount,
      callCount,
      'Expected email service to be called ' +
        expectedCount +
        ' times, but was called ' +
        callCount
    );
  }
  public List<Messaging.SingleEmailMessage> getLastEmailsSent() {
    return lastEmailsSent;
  }
  public Integer getCallCount() {
    return callCount;
  }
}
