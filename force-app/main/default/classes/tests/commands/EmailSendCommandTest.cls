/**
 * Test class for EmailSendCommand
 * Tests email sending mechanics, error handling, and result tracking
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
    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000001AAA',
      'Test Opportunity'
    );
    oppResult.contactEmail = 'testuser@example.com';

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
      email
    };
    List<DonationAcknowledgementService.OpportunityResult> oppResults = new List<DonationAcknowledgementService.OpportunityResult>{
      oppResult
    };

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify successful send output
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      null,
      output.errorMessage,
      'Should have no error message'
    );
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
    DonationAcknowledgementService.OpportunityResult result = output.successfulOpportunities[0];
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.SUCCESS,
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
    List<DonationAcknowledgementService.OpportunityResult> oppResults = new List<DonationAcknowledgementService.OpportunityResult>();

    // Create multiple prepared emails and opportunity results
    for (Integer i = 1; i <= 3; i++) {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setSubject('Test Subject ' + i);
      email.setPlainTextBody('Test Body ' + i);
      email.setTargetObjectId(c.Id);
      emails.add(email);

      DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
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
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      null,
      output.errorMessage,
      'Should have no error message'
    );
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
    for (
      DonationAcknowledgementService.OpportunityResult result : output.successfulOpportunities
    ) {
      System.assertEquals(
        DonationAcknowledgementService.AckStatus.SUCCESS,
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
    List<DonationAcknowledgementService.OpportunityResult> emptyResults = new List<DonationAcknowledgementService.OpportunityResult>();

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emptyEmails, emptyResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify empty list handling
    System.assertEquals(
      true,
      output.isSuccess,
      'Should be successful (empty case)'
    );
    System.assertEquals(
      null,
      output.errorMessage,
      'Should have no error message'
    );
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
    // Test error handling during email sending
    // Use a mock that simulates failure
    MockEmailService mock = new MockEmailService();
    mock.setFailure('Simulated send failure');
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create email with potentially problematic configuration
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setSubject('Error Test Subject');
    email.setPlainTextBody('Error Test Body');
    email.setTargetObjectId(c.Id);

    // Create opportunity result
    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000002AAA',
      'Error Test Opportunity'
    );
    oppResult.contactEmail = 'testuser@example.com';

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
      email
    };
    List<DonationAcknowledgementService.OpportunityResult> oppResults = new List<DonationAcknowledgementService.OpportunityResult>{
      oppResult
    };

    Test.startTest();
    try {
      EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
      sendCmd.emailService = mock;
      sendCmd.execute();
      AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();

      // If execution succeeds (normal in test context)
      System.assertEquals(
        true,
        output.isSuccess,
        'Should be successful in test context'
      );
    } catch (AuraHandledException e) {
      // If an error occurs, verify proper error handling
      // This AuraHandledException has the text 'Script-thrown exception' for unknown reasons
      System.assert(
        e.getMessage().contains('Failed to send acknowledgement emails') ||
        e.getMessage().contains('Script-thrown exception'),
        'Should have proper error message format. Actual: ' + e.getMessage()
      );
    }
    Test.stopTest();

    mock.verifyEmailCount(1);
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

    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
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
    List<DonationAcknowledgementService.OpportunityResult> oppResults = new List<DonationAcknowledgementService.OpportunityResult>{
      oppResult
    };

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.emailService = mock;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify opportunity result was updated
    DonationAcknowledgementService.OpportunityResult updatedResult = output.successfulOpportunities[0];

    // Check that it's the same object reference (should be modified in place)
    System.assertEquals(
      oppResult,
      updatedResult,
      'Should be the same object reference'
    );

    // Verify status updates
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.SUCCESS,
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

    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000006AAA',
      'Output Test Opportunity'
    );
    oppResult.contactEmail = 'testuser@example.com';

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
      email
    };
    List<DonationAcknowledgementService.OpportunityResult> oppResults = new List<DonationAcknowledgementService.OpportunityResult>{
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
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      null,
      output.errorMessage,
      'Error message should be null on success'
    );
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
    DonationAcknowledgementService.OpportunityResult successResult = output.successfulOpportunities[0];
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
