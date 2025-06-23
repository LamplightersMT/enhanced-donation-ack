/**
 * MockEmailService implements IEmailService for use in tests.
 * Allows configuration of success/failure scenarios and tracks calls.
 */
@isTest
public class MockEmailService implements IEmailService {
  private static final String DEFAULT_ERROR_MESSAGE = 'Mock email send failure';

  public Boolean shouldSucceed = true;
  public String errorMessage = DEFAULT_ERROR_MESSAGE;
  public List<Integer> failureIndexes = new List<Integer>();
  public List<List<Messaging.SingleEmailMessage>> sendEmailsCalls = new List<List<Messaging.SingleEmailMessage>>();
  public Integer callCount = 0;

  public List<Messaging.SendEmailResult> sendEmails(
    List<Messaging.SingleEmailMessage> emails
  ) {
    callCount++;
    sendEmailsCalls.add(emails);
    List<Messaging.SendEmailResult> results = new List<Messaging.SendEmailResult>();
    if (emails == null || emails.isEmpty()) {
      return results;
    }
    for (Integer i = 0; i < emails.size(); i++) {
      if (shouldSucceed && !failureIndexes.contains(i)) {
        results.add(AcknowledgementTestUtils.createSuccessfulSendEmailResult());
      } else {
        results.add(
          AcknowledgementTestUtils.createFailedSendEmailResult(errorMessage)
        );
      }
    }
    return results;
  }

  public MockEmailService setSuccessful() {
    this.shouldSucceed = true;
    this.failureIndexes.clear();
    return this;
  }
  public MockEmailService setFailure(String message) {
    this.shouldSucceed = false;
    this.errorMessage = message;
    return this;
  }
  public MockEmailService setPartialFailure(
    List<Integer> indexes,
    String message
  ) {
    this.shouldSucceed = true;
    this.failureIndexes = indexes;
    this.errorMessage = message;
    return this;
  }
  public MockEmailService reset() {
    this.shouldSucceed = true;
    this.errorMessage = DEFAULT_ERROR_MESSAGE;
    this.failureIndexes.clear();
    this.sendEmailsCalls.clear();
    this.callCount = 0;
    return this;
  }
  public void verifySendEmailsCalledWith(Integer expectedCount) {
    System.assertEquals(
      1,
      callCount,
      'sendEmails should have been called exactly once'
    );
    System.assert(
      !sendEmailsCalls.isEmpty(),
      'sendEmailsCalls should not be empty when verifying call arguments'
    );
    System.assertEquals(
      expectedCount,
      sendEmailsCalls[0].size(),
      'sendEmails should have been called with ' + expectedCount + ' emails'
    );
  }
  public void verifyCallCount(Integer expectedCalls) {
    System.assertEquals(
      expectedCalls,
      callCount,
      'sendEmails should have been called ' + expectedCalls + ' times'
    );
  }
}
