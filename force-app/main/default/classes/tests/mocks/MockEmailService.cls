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
    sendEmailsCalls.add(
      emails == null ? new List<Messaging.SingleEmailMessage>() : emails
    );
    List<Messaging.SendEmailResult> results = new List<Messaging.SendEmailResult>();

    if (emails == null || emails.isEmpty()) {
      return results;
    }

    // Create cached failure result once if we haven't already
    if (cachedFailureResult == null) {
      cachedFailureResult = createCachedFailureResult();
    }

    // For each email, return the appropriate result type based on configuration
    for (Integer i = 0; i < emails.size(); i++) {
      if (shouldSucceed && !failureIndexes.contains(i)) {
        // Return null for successful result (EmailSendCommand treats null as success)
        results.add(null);
      } else {
        // Return failed result
        results.add(cachedFailureResult);
      }
    }

    return results;
  }

  // Cache for failure results only (success is represented by null)
  private static Messaging.SendEmailResult cachedFailureResult;

  /**
   * Create a cached failure email result by attempting to send to invalid address
   *
   * Salesforce disallows instantiation of Messaging.SendEmailResult directly,
   * so we create a dummy email and capture the result from Messaging.sendEmail.
   */
  private static Messaging.SendEmailResult createCachedFailureResult() {
    try {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ 'invalid.test.failure' });
      email.setSubject('Test Failure');
      email.setPlainTextBody('Failure');
      email.setSaveAsActivity(false);

      List<Messaging.SendEmailResult> results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ email },
        false
      );

      return results.isEmpty() ? null : results[0];
    } catch (Exception e) {
      System.debug('Error creating cached failure result: ' + e.getMessage());
      return null;
    }
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
    // Reset cached failure result to force recreation
    cachedFailureResult = null;
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
