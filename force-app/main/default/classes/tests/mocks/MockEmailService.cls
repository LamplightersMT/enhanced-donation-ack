/**
 * Mock implementation of IEmailService for testing
 */
@isTest
public class MockEmailService implements IEmailService {
  private Boolean successful = true;
  private String errorMessage;
  private Set<Integer> failingIndexes;
  private Integer callCount = 0;
  private List<Messaging.SingleEmailMessage> lastEmailsSent;

  public MockEmailService setSuccessful() {
    this.successful = true;
    this.errorMessage = null;
    this.failingIndexes = null;
    return this;
  }
  public MockEmailService setFailure(String errorMessage) {
    this.successful = false;
    this.errorMessage = errorMessage;
    this.failingIndexes = null;
    return this;
  }
  /**
   * Configure the mock so that only the messages at the given (zero-based) indexes
   * fail; all other messages succeed.
   */
  public MockEmailService setPartialFailure(
    List<Integer> failingIndexes,
    String errorMessage
  ) {
    this.successful = true;
    this.errorMessage = errorMessage;
    this.failingIndexes = new Set<Integer>();
    if (failingIndexes != null) {
      this.failingIndexes.addAll(failingIndexes);
    }
    return this;
  }
  public MockEmailService reset() {
    this.callCount = 0;
    this.lastEmailsSent = null;
    this.errorMessage = null;
    this.successful = true;
    this.failingIndexes = null;
    return this;
  }
  public List<AckSendResult> sendEmail(
    List<Messaging.SingleEmailMessage> emails
  ) {
    this.callCount++;
    this.lastEmailsSent = emails;
    List<AckSendResult> results = new List<AckSendResult>();
    for (Integer i = 0; i < emails.size(); i++) {
      Boolean thisMessageFails = failingIndexes != null
        ? failingIndexes.contains(i)
        : !successful;
      if (thisMessageFails) {
        results.add(AckSendResult.fail(errorMessage));
      } else {
        results.add(AckSendResult.ok());
      }
    }
    return results;
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
