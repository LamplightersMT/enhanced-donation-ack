/**
 * Test class for EmailSendCommand
 * Tests email sending mechanics, per-message error handling, and result tracking
 */
@isTest
private class EmailSendCommandTest {
  @testSetup
  static void setupTestData() {
    Contact c = AcknowledgementTestUtils.createTestContact(
      'testuser@example.com'
    );
    Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
      'Test Opp',
      c,
      null,
      100
    );
  }

  @isTest
  static void testSendEmailsSuccessfulSingleEmail() {
    // Test successful email sending with single email
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create prepared email message
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setSubject('Test Subject');
    email.setPlainTextBody('Test Body');
    email.setTargetObjectId(c.Id);

    // Create opportunity result
    AckOpportunityResult oppResult = new AckOpportunityResult(
      '006000000000001AAA',
      'Test Opportunity'
    );
    oppResult.contactEmail = 'testuser@example.com';

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
      email
    };
    List<AckOpportunityResult> oppResults = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify successful send output
    System.assertEquals(
      1,
      output.successfulOpportunities.size(),
      'Should have 1 successful opportunity'
    );
    System.assertEquals(
      0,
      output.failedOpportunities.size(),
      'Should have no failed opportunities'
    );

    // Verify opportunity result was marked as successful
    AckOpportunityResult result = output.successfulOpportunities[0];
    System.assertEquals(
      AckStatus.SUCCESS,
      result.status,
      'Should be marked as successful'
    );
    System.assertEquals(
      'Email sent successfully',
      result.reason,
      'Should have success reason'
    );
    System.assertEquals(
      Date.today(),
      result.acknowledgmentDate,
      'Should have acknowledgment date set'
    );

    // Verify that the mock was called as expected
    mock.verifyEmailCount(1);
  }

  @isTest
  static void testSendEmailsSuccessfulMultipleEmails() {
    // Test successful email sending with multiple emails
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<AckOpportunityResult> oppResults = new List<AckOpportunityResult>();

    // Create multiple prepared emails and opportunity results
    for (Integer i = 1; i <= 3; i++) {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setSubject('Test Subject ' + i);
      email.setPlainTextBody('Test Body ' + i);
      email.setTargetObjectId(c.Id);
      emails.add(email);

      AckOpportunityResult oppResult = new AckOpportunityResult(
        '00600000000000' + i + 'AAA',
        'Test Opportunity ' + i
      );
      oppResult.contactEmail = 'testuser@example.com';
      oppResults.add(oppResult);
    }

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify successful send output for all emails
    System.assertEquals(
      3,
      output.successfulOpportunities.size(),
      'Should have 3 successful opportunities'
    );
    System.assertEquals(
      0,
      output.failedOpportunities.size(),
      'Should have no failed opportunities'
    );

    // Verify all opportunity results were marked as successful
    for (AckOpportunityResult result : output.successfulOpportunities) {
      System.assertEquals(
        AckStatus.SUCCESS,
        result.status,
        'Should be marked as successful'
      );
      System.assertEquals(
        'Email sent successfully',
        result.reason,
        'Should have success reason'
      );
      System.assertEquals(
        Date.today(),
        result.acknowledgmentDate,
        'Should have acknowledgment date set'
      );
    }

    // Verify that the mock was called as expected
    mock.verifyEmailCount(3);
  }

  @isTest
  static void testSendEmailsEmptyList() {
    // Test email sending with empty email list
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    List<Messaging.SingleEmailMessage> emptyEmails = new List<Messaging.SingleEmailMessage>();
    List<AckOpportunityResult> emptyResults = new List<AckOpportunityResult>();

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emptyEmails, emptyResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify empty list handling
    System.assertEquals(
      0,
      output.successfulOpportunities.size(),
      'Should have no successful opportunities'
    );
    System.assertEquals(
      0,
      output.failedOpportunities.size(),
      'Should have no failed opportunities'
    );

    mock.verifySendCount(0);
  }

  @isTest
  static void testEmailSendingErrorHandling() {
    // Test per-message error handling during email sending - this must never throw
    MockEmailService mock = new MockEmailService();
    mock.setFailure('Simulated send failure');
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setSubject('Error Test Subject');
    email.setPlainTextBody('Error Test Body');
    email.setTargetObjectId(c.Id);

    AckOpportunityResult oppResult = new AckOpportunityResult(
      '006000000000002AAA',
      'Error Test Opportunity'
    );
    oppResult.contactEmail = 'testuser@example.com';

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
      email
    };
    List<AckOpportunityResult> oppResults = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify failure is captured on the output, not thrown
    System.assertEquals(
      0,
      output.successfulOpportunities.size(),
      'Should have no successful opportunities'
    );
    System.assertEquals(
      1,
      output.failedOpportunities.size(),
      'Should have 1 failed opportunity'
    );
    AckOpportunityResult failedResult = output.failedOpportunities[0];
    System.assertEquals(
      AckStatus.EMAIL_SEND_FAILED,
      failedResult.status,
      'Should be marked as failed'
    );
    System.assert(
      failedResult.reason.contains('Simulated send failure'),
      'Reason should include underlying error message. Actual: ' +
      failedResult.reason
    );
    System.assertEquals(
      null,
      failedResult.acknowledgmentDate,
      'Should not set acknowledgment date on failure'
    );

    mock.verifyEmailCount(1);
  }

  @isTest
  static void testSendEmailsPartialFailure() {
    // Test that a batch of emails can have some messages succeed and others fail
    MockEmailService mock = new MockEmailService();
    mock.setPartialFailure(new List<Integer>{ 1 }, 'Mailbox unavailable');
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<AckOpportunityResult> oppResults = new List<AckOpportunityResult>();

    for (Integer i = 0; i < 3; i++) {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setSubject('Partial Subject ' + i);
      email.setPlainTextBody('Partial Body ' + i);
      email.setTargetObjectId(c.Id);
      emails.add(email);

      AckOpportunityResult oppResult = new AckOpportunityResult(
        '00600000000000' + i + 'AAA',
        'Partial Opportunity ' + i
      );
      oppResult.contactEmail = 'testuser' + i + '@example.com';
      oppResults.add(oppResult);
    }

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    System.assertEquals(
      2,
      output.successfulOpportunities.size(),
      'Should have 2 successful opportunities'
    );
    System.assertEquals(
      1,
      output.failedOpportunities.size(),
      'Should have 1 failed opportunity'
    );

    System.assertEquals(
      AckStatus.EMAIL_SEND_FAILED,
      output.failedOpportunities[0].status,
      'Failed opportunity should be marked EMAIL_SEND_FAILED'
    );
    System.assertEquals(
      'Partial Opportunity 1',
      output.failedOpportunities[0].opportunityName,
      'Index 1 should be the opportunity that failed'
    );
    System.assert(
      output.failedOpportunities[0].reason.contains('Mailbox unavailable'),
      'Reason should include underlying error message'
    );

    for (AckOpportunityResult success : output.successfulOpportunities) {
      System.assertEquals(
        AckStatus.SUCCESS,
        success.status,
        'Should be marked as successful'
      );
      System.assertEquals(
        Date.today(),
        success.acknowledgmentDate,
        'Should have acknowledgment date set'
      );
    }

    mock.verifyEmailCount(3);
  }

  @isTest
  static void testOpportunityResultStatusUpdates() {
    // Test that opportunity results are properly updated with status information
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create email and opportunity result
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setSubject('Status Test Subject');
    email.setPlainTextBody('Status Test Body');
    email.setTargetObjectId(c.Id);

    AckOpportunityResult oppResult = new AckOpportunityResult(
      '006000000000003AAA',
      'Status Test Opportunity'
    );
    oppResult.contactEmail = 'testuser@example.com';

    // Verify initial state
    System.assertEquals(null, oppResult.status, 'Status should start as null');
    System.assertEquals(null, oppResult.reason, 'Reason should start as null');
    System.assertEquals(
      null,
      oppResult.acknowledgmentDate,
      'Acknowledgment date should start as null'
    );

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
      email
    };
    List<AckOpportunityResult> oppResults = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify opportunity result was updated
    AckOpportunityResult updatedResult = output.successfulOpportunities[0];

    // Check that it's the same object reference (should be modified in place)
    System.assertEquals(
      oppResult,
      updatedResult,
      'Should be the same object reference'
    );

    // Verify status updates
    System.assertEquals(
      AckStatus.SUCCESS,
      oppResult.status,
      'Original object should be updated with success status'
    );
    System.assertEquals(
      'Email sent successfully',
      oppResult.reason,
      'Original object should be updated with success reason'
    );
    System.assertEquals(
      Date.today(),
      oppResult.acknowledgmentDate,
      'Original object should be updated with acknowledgment date'
    );

    mock.verifyEmailCount(1);
  }

  @isTest
  static void testEmailSendOutputStructure() {
    // Test the structure and properties of the SendOutput class
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create single email for testing
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setSubject('Output Test Subject');
    email.setPlainTextBody('Output Test Body');
    email.setTargetObjectId(c.Id);

    AckOpportunityResult oppResult = new AckOpportunityResult(
      '006000000000006AAA',
      'Output Test Opportunity'
    );
    oppResult.contactEmail = 'testuser@example.com';

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
      email
    };
    List<AckOpportunityResult> oppResults = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify output structure
    System.assertNotEquals(null, output, 'Output should not be null');
    System.assertNotEquals(
      null,
      output.successfulOpportunities,
      'Successful opportunities list should not be null'
    );
    System.assertNotEquals(
      null,
      output.failedOpportunities,
      'Failed opportunities list should not be null'
    );

    // Verify success case properties
    System.assertEquals(
      1,
      output.successfulOpportunities.size(),
      'Should have 1 successful opportunity'
    );
    System.assertEquals(
      0,
      output.failedOpportunities.size(),
      'Should have 0 failed opportunities'
    );

    // Verify successful opportunity details
    AckOpportunityResult successResult = output.successfulOpportunities[0];
    System.assertEquals(
      '006000000000006AAA',
      successResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      'Output Test Opportunity',
      successResult.opportunityName,
      'Should have correct opportunity name'
    );
    System.assertEquals(
      'testuser@example.com',
      successResult.contactEmail,
      'Should have correct contact email'
    );

    mock.verifyEmailCount(1);
  }

  /**
   * NOTE: This test class was refactored as part of the test responsibility plan.
   * See docs/test-refactoring-plan.md for details on which methods were moved or removed.
   */

  // The following test methods were moved to DonationAcknowledgementServiceImplTest as part of the test refactoring plan:
  // - testSendEmailsWithTemplateEmail
  // - testEmailSendCommandWithDifferentEmailTypes
}
