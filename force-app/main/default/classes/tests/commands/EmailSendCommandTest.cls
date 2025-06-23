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
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Inject mock email service
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    EmailSendCommand.emailService = mock;

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
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(1);

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
  }

  @isTest
  static void testSendEmailsSuccessfulMultipleEmails() {
    // Test successful email sending with multiple emails
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Inject mock email service
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    EmailSendCommand.emailService = mock;

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
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(3);

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
  }

  @isTest
  static void testSendEmailsEmptyList() {
    // Test email sending with empty email list
    // Inject mock email service
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    EmailSendCommand.emailService = mock;

    List<Messaging.SingleEmailMessage> emptyEmails = new List<Messaging.SingleEmailMessage>();
    List<DonationAcknowledgementService.OpportunityResult> emptyResults = new List<DonationAcknowledgementService.OpportunityResult>();

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emptyEmails, emptyResults);
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called (should be 0 since no emails)
    mock.verifySendEmailsCalledWith(0);

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
  }

  @isTest
  static void testSendEmailsWithTemplateEmail() {
    // Test email sending with template-based email
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    // Inject mock email service
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    EmailSendCommand.emailService = mock;

    // Create template-based email message
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setTemplateId('00X000000000000AAA'); // Mock template ID
    email.setTargetObjectId(c.Id);
    email.setWhatId(opp.Id);

    // Create opportunity result
    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      opp.Id,
      'Template Test Opp'
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
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(1);

    // In successful case
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      1,
      output.successfulOpportunities.size(),
      'Should have 1 successful opportunity'
    );
  }

  @isTest
  static void testEmailSendingErrorHandling() {
    // Test error handling during email sending
    // Configure mock to simulate failure
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    MockEmailService mock = new MockEmailService();
    mock.setFailure('Simulated failure');
    EmailSendCommand.emailService = mock;

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
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(1);

    // Should be failure
    System.assertEquals(
      false,
      output.isSuccess,
      'Should be unsuccessful when mock fails'
    );
    System.assertNotEquals(
      null,
      output.errorMessage,
      'Should have error message on failure'
    );
    System.assertEquals(
      0,
      output.successfulOpportunities.size(),
      'Should have no successful opportunities on failure'
    );
    System.assertEquals(
      1,
      output.failedOpportunities.size(),
      'Should have 1 failed opportunity on failure'
    );
  }

  @isTest
  static void testEmailSendingPartialFailure() {
    // Test partial failure scenario
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Inject mock email service and configure partial failure
    MockEmailService mock = new MockEmailService();
    mock.setPartialFailure(new List<Integer>{ 1 }, 'Simulated partial failure');
    EmailSendCommand.emailService = mock;

    // Create two emails and opportunity results
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<DonationAcknowledgementService.OpportunityResult> oppResults = new List<DonationAcknowledgementService.OpportunityResult>();
    for (Integer i = 1; i <= 2; i++) {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setSubject('Partial ' + i);
      email.setPlainTextBody('Partial Body ' + i);
      email.setTargetObjectId(c.Id);
      emails.add(email);
      DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
        '00600000000000' + i + 'AAA',
        'Partial Opportunity ' + i
      );
      oppResult.contactEmail = 'testuser@example.com';
      oppResults.add(oppResult);
    }

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(2);

    // Should be partial success
    System.assertEquals(false, output.isSuccess, 'Should be failure (partial)');
    System.assertEquals(
      1,
      output.successfulOpportunities.size(),
      'Should have 1 successful opportunity'
    );
    System.assertEquals(
      1,
      output.failedOpportunities.size(),
      'Should have 1 failed opportunity'
    );

    // Verify which opportunity failed and which succeeded
    Boolean foundSuccess = false;
    Boolean foundFailure = false;
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
      foundSuccess = true;
    }
    for (
      DonationAcknowledgementService.OpportunityResult result : output.failedOpportunities
    ) {
      System.assertEquals(
        DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
        result.status,
        'Should be marked as failure'
      );
      System.assertEquals(
        'Simulated partial failure',
        result.reason,
        'Should have failure reason'
      );
      foundFailure = true;
    }
    System.assertEquals(true, foundSuccess, 'Should find a successful result');
    System.assertEquals(true, foundFailure, 'Should find a failed result');
  }

  @isTest
  static void testOpportunityResultStatusUpdates() {
    // Test that opportunity results are properly updated with status information
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Inject mock email service
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    EmailSendCommand.emailService = mock;

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
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(1);

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
  }

  @isTest
  static void testEmailSendCommandWithDifferentEmailTypes() {
    // Test email send command with different types of email configurations
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Inject mock email service
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    EmailSendCommand.emailService = mock;

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<DonationAcknowledgementService.OpportunityResult> oppResults = new List<DonationAcknowledgementService.OpportunityResult>();

    // Email 1: Plain text email
    Messaging.SingleEmailMessage plainEmail = new Messaging.SingleEmailMessage();
    plainEmail.setSubject('Plain Text Subject');
    plainEmail.setPlainTextBody('Plain text body content');
    plainEmail.setTargetObjectId(c.Id);
    emails.add(plainEmail);

    DonationAcknowledgementService.OpportunityResult plainResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000004AAA',
      'Plain Text Opportunity'
    );
    plainResult.contactEmail = 'testuser@example.com';
    oppResults.add(plainResult);

    // Email 2: HTML email
    Messaging.SingleEmailMessage htmlEmail = new Messaging.SingleEmailMessage();
    htmlEmail.setSubject('HTML Subject');
    htmlEmail.setHtmlBody('<html><body><h1>HTML Content</h1></body></html>');
    htmlEmail.setTargetObjectId(c.Id);
    emails.add(htmlEmail);

    DonationAcknowledgementService.OpportunityResult htmlResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000005AAA',
      'HTML Opportunity'
    );
    htmlResult.contactEmail = 'testuser@example.com';
    oppResults.add(htmlResult);

    Test.startTest();
    EmailSendCommand sendCmd = new EmailSendCommand(emails, oppResults);
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(2);

    // Verify both emails were sent successfully
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      2,
      output.successfulOpportunities.size(),
      'Should have 2 successful opportunities'
    );
    System.assertEquals(
      0,
      output.failedOpportunities.size(),
      'Should have no failed opportunities'
    );

    // Verify both opportunity results were updated
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
  }

  @isTest
  static void testEmailSendOutputStructure() {
    // Test the structure and properties of the SendOutput class
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Inject mock email service
    MockEmailService mock = new MockEmailService();
    mock.setSuccessful();
    EmailSendCommand.emailService = mock;

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
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput output = sendCmd.getOutput();
    Test.stopTest();

    // Verify mock was called
    mock.verifySendEmailsCalledWith(1);

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
  }
}
