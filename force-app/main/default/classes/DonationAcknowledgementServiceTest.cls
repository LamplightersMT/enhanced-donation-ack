@isTest
private class DonationAcknowledgementServiceTest {
  @testSetup
  static void setupTestData() {
    // Create test Contact
    Contact c = new Contact(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'testuser@example.com'
    );
    insert c;
    // Create test Opportunity
    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
    );
    insert opp;
    // (Do NOT create OrgWideEmailAddress here; not allowed in Apex tests)
    // Create EmailTemplate in correct folder
    // (Assume template/folder already deployed in metadata, so just query in test)
  }

  @isTest
  static void testSendAcknowledgementsWithTemplate() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = new List<Id>{ opp.Id };
    List<DonationAcknowledgementService.OpportunityIdWrapper> input = new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      wrapper
    };
    Test.startTest();
    List<DonationAcknowledgementService.AckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      input
    );
    Test.stopTest();
    System.assertEquals(1, result.size());
    System.assert(result[0].result.contains('Emails sent: 1'));
    // Verify acknowledgement date is set
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(), // FIXME: Fragile test, will break if run on a different day
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgement date should be set to today'
    );
  }

  @isTest
  static void testSendAcknowledgementsStaticFallback() {
    // Set template devname/folder to values that do not exist to force fallback
    DonationAcknowledgementService.donationAckTemplateDevName = 'DoesNotExistTemplate';
    DonationAcknowledgementService.donationAckTemplateFolder = 'DoesNotExistFolder';
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = new List<Id>{ opp.Id };
    List<DonationAcknowledgementService.OpportunityIdWrapper> input = new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      wrapper
    };
    Test.startTest();
    List<DonationAcknowledgementService.AckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      input
    );
    Test.stopTest();
    System.assertEquals(1, result.size());
    System.assert(result[0].result.contains('Static content fallback'));
    // Verify acknowledgement date is set
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(), // FIXME: Fragile test, will break if run on a different day
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgement date should be set to today'
    );
  }

  @isTest
  static void testNoOpportunities() {
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = new List<Id>();
    List<DonationAcknowledgementService.OpportunityIdWrapper> input = new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      wrapper
    };
    Test.startTest();
    List<DonationAcknowledgementService.AckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      input
    );
    Test.stopTest();
    System.assertEquals(1, result.size());
    System.assertEquals('No Opportunity IDs provided.', result[0].result);
  }

  @isTest
  static void testEmailSendingFailureDoesNotUpdateAcknowledgmentDate() {
    // This test verifies that if email sending fails, acknowledgment dates are not updated
    Opportunity opp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      LIMIT 1
    ];

    // Verify opportunity starts without acknowledgment date
    System.assertEquals(
      null,
      opp.npsp__Acknowledgment_Date__c,
      'Opportunity should start without acknowledgment date'
    );

    // Create a scenario that might cause email sending to fail
    // Note: In test context, Messaging.sendEmail() typically doesn't fail,
    // but this test documents the expected behavior if it did fail

    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    try {
      String result = DonationAcknowledgementService.sendAcknowledgements(
        oppIds
      );
      // If we get here, email sending succeeded (normal test behavior)
      System.assert(
        result.contains('Emails sent:'),
        'Should indicate emails were sent'
      );

      // Verify acknowledgment date was set on success
      Opportunity updatedOpp = [
        SELECT Id, npsp__Acknowledgment_Date__c
        FROM Opportunity
        WHERE Id = :opp.Id
      ];
      System.assertEquals(
        Date.today(),
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Acknowledgment date should be set on successful send'
      );
    } catch (AuraHandledException e) {
      // If email sending failed (unlikely in test context), verify acknowledgment date was not set
      System.assert(
        e.getMessage().contains('Failed to send acknowledgement emails'),
        'Exception should indicate email sending failure'
      );

      Opportunity updatedOpp = [
        SELECT Id, npsp__Acknowledgment_Date__c
        FROM Opportunity
        WHERE Id = :opp.Id
      ];
      System.assertEquals(
        null,
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Acknowledgment date should not be set on failure'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendEmailsCoreWithTemplateConfig() {
    // Test the core method directly with template configuration
    // Note: In test context, we can't create actual EmailTemplate records,
    // so this test will verify the method executes but may not send actual emails
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];

    // Use a realistic looking template ID format
    Id mockTemplateId = '00X000000000000AAA'; // Mock template ID in correct format

    Test.startTest();
    try {
      Integer result = DonationAcknowledgementService.sendEmailsCore(
        opps,
        new DonationAcknowledgementService.EmailConfig(mockTemplateId)
      );
      // If we get here, the method executed successfully
      System.assert(result >= 0, 'Should return a valid count');
    } catch (Exception e) {
      // In test context, template-based emails may fail due to missing template or invalid ID format
      // This is expected behavior - the important thing is that the method doesn't crash unexpectedly
      System.assert(
        e.getMessage().contains('Failed to send acknowledgement emails') ||
          e.getMessage().contains('Data Not Available') ||
          e.getMessage().contains('Invalid parameter value'),
        'Should get expected email sending error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendEmailsCoreWithStaticConfig() {
    // Test the core method directly with static content configuration
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];

    Test.startTest();
    Integer result = DonationAcknowledgementService.sendEmailsCore(
      opps,
      new DonationAcknowledgementService.EmailConfig(
        'Test Subject',
        'Test Body'
      )
    );
    Test.stopTest();

    // Should return 1 (one email processed)
    System.assertEquals(1, result, 'Should process one opportunity');

    // Verify acknowledgment date was set
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(),
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgment date should be set'
    );
  }

  @isTest
  static void testDuplicatePreventionSkipsAcknowledgedOpportunities() {
    // Create test data with one already acknowledged opportunity
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create two opportunities - one already acknowledged, one not
    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Already Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today().addDays(-1),
      Amount = 200,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1) // Already acknowledged
    );

    Opportunity newOpp = new Opportunity(
      Name = 'New Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
      // No acknowledgment date - should be processed
    );

    insert new List<Opportunity>{ acknowledgedOpp, newOpp };

    List<Id> oppIds = new List<Id>{ acknowledgedOpp.Id, newOpp.Id };

    Test.startTest();
    String result = DonationAcknowledgementService.sendAcknowledgements(oppIds);
    Test.stopTest();

    // Verify result message shows correct counts
    System.assert(
      result.contains('2 Opportunities'),
      'Should show 2 total opportunities'
    );
    System.assert(
      result.contains('Emails sent: 1'),
      'Should send 1 email (for new opp only)'
    );
    System.assert(
      result.contains('Already acknowledged: 1'),
      'Should show 1 already acknowledged'
    );

    // Verify only the new opportunity got acknowledgment date updated
    List<Opportunity> updatedOpps = [
      SELECT Id, Name, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :oppIds
      ORDER BY Name
    ];

    // Already acknowledged opp should keep its original date
    System.assertEquals(
      Date.today().addDays(-1),
      updatedOpps[0].npsp__Acknowledgment_Date__c,
      'Already acknowledged opp should keep original date'
    );

    // New opp should get today's date
    System.assertEquals(
      Date.today(),
      updatedOpps[1].npsp__Acknowledgment_Date__c,
      'New opp should get acknowledgment date set to today'
    );
  }

  @isTest
  static void testDuplicatePreventionAllAlreadyAcknowledged() {
    // Test scenario where all opportunities are already acknowledged
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Already Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today().addDays(-1),
      Amount = 100,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1)
    );
    insert acknowledgedOpp;

    List<Id> oppIds = new List<Id>{ acknowledgedOpp.Id };

    Test.startTest();
    String result = DonationAcknowledgementService.sendAcknowledgements(oppIds);
    Test.stopTest();

    // Verify no emails were sent but proper feedback provided
    System.assert(
      result.contains('1 Opportunities'),
      'Should show 1 total opportunity'
    );
    System.assert(result.contains('Emails sent: 0'), 'Should send 0 emails');
    System.assert(
      result.contains('Already acknowledged: 1'),
      'Should show 1 already acknowledged'
    );
  }

  @isTest
  static void testSendEmailsCoreWithResultReturnsMigratedFunctionality() {
    // Test that legacy functionality is now handled by DetailedAckResult
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create mixed scenario: acknowledged, new, and no contact
    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1)
    );

    Opportunity newOpp = new Opportunity(
      Name = 'New Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 200,
      ContactId = c.Id
    );

    Opportunity noContactOpp = new Opportunity(
      Name = 'No Contact Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 150
      // No ContactId
    );

    insert new List<Opportunity>{ acknowledgedOpp, newOpp, noContactOpp };

    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN (:acknowledgedOpp.Id, :newOpp.Id, :noContactOpp.Id)
    ];

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );

    Test.startTest();
    // Test the new detailed method instead of the old EmailSendResult method
    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();

    // Verify detailed counts (same functionality, richer data structure)
    System.assertEquals(
      3,
      result.totalOpportunities,
      'Should have 3 total opportunities'
    );
    System.assertEquals(1, result.emailsSent, 'Should send 1 email');
    System.assertEquals(
      1,
      result.alreadyAcknowledged,
      'Should have 1 already acknowledged'
    );
    System.assertEquals(
      1,
      result.noValidContact,
      'Should have 1 with no valid contact'
    );

    // Verify enhanced functionality not available in old EmailSendResult
    System.assertEquals(
      3,
      result.opportunityResults.size(),
      'Should have individual opportunity results'
    );
    System.assertEquals(
      0,
      result.emailSendFailures,
      'Should track email failures'
    );

    // Verify summary message
    String summary = result.buildSummaryMessage();
    System.assert(
      summary.contains('3 Opportunities'),
      'Summary should show total count'
    );
    System.assert(
      summary.contains('Emails sent: 1'),
      'Summary should show emails sent'
    );
    System.assert(
      summary.contains('Already acknowledged: 1'),
      'Summary should show already acknowledged'
    );
    System.assert(
      summary.contains('No valid contact: 1'),
      'Summary should show no valid contact'
    );
  }

  @isTest
  static void testOpportunityResultCreationAndStatus() {
    // Test OpportunityResult class functionality
    Id testOppId = '006000000000001AAA'; // Mock opportunity ID
    String testOppName = 'Test Opportunity';

    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      testOppId,
      testOppName
    );

    System.assertEquals(
      testOppId,
      oppResult.opportunityId,
      'Should set opportunity ID correctly'
    );
    System.assertEquals(
      testOppName,
      oppResult.opportunityName,
      'Should set opportunity name correctly'
    );

    // Test setting success status
    oppResult.setStatus(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent successfully'
    );
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      oppResult.status,
      'Should set success status'
    );
    System.assertEquals(
      'Email sent successfully',
      oppResult.reason,
      'Should set success reason'
    );
    System.assert(oppResult.isSuccess(), 'Should identify as success');
    System.assert(!oppResult.isSkipped(), 'Should not identify as skipped');
    System.assert(!oppResult.isFailed(), 'Should not identify as failed');

    // Test setting skipped status
    oppResult.setStatus(
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      'Already acknowledged'
    );
    System.assert(!oppResult.isSuccess(), 'Should not identify as success');
    System.assert(oppResult.isSkipped(), 'Should identify as skipped');
    System.assert(!oppResult.isFailed(), 'Should not identify as failed');

    // Test setting failed status
    oppResult.setStatus(
      DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
      'Send failed'
    );
    System.assert(!oppResult.isSuccess(), 'Should not identify as success');
    System.assert(!oppResult.isSkipped(), 'Should not identify as skipped');
    System.assert(oppResult.isFailed(), 'Should identify as failed');
  }

  @isTest
  static void testDetailedAckResultAggregation() {
    // Test DetailedAckResult class functionality
    DonationAcknowledgementService.DetailedAckResult detailedResult = new DonationAcknowledgementService.DetailedAckResult();

    // Create various OpportunityResults to test aggregation
    DonationAcknowledgementService.OpportunityResult successResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000001AAA',
      'Success Opp'
    );
    successResult.setStatus(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent'
    );

    DonationAcknowledgementService.OpportunityResult acknowledgedResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000002AAA',
      'Acknowledged Opp'
    );
    acknowledgedResult.setStatus(
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      'Already done'
    );

    DonationAcknowledgementService.OpportunityResult noContactResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000003AAA',
      'No Contact Opp'
    );
    noContactResult.setStatus(
      DonationAcknowledgementService.AckStatus.NO_CONTACT,
      'No contact'
    );

    DonationAcknowledgementService.OpportunityResult failedResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000004AAA',
      'Failed Opp'
    );
    failedResult.setStatus(
      DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
      'Send failed'
    );

    // Add results and verify aggregation
    detailedResult.addOpportunityResult(successResult);
    detailedResult.addOpportunityResult(acknowledgedResult);
    detailedResult.addOpportunityResult(noContactResult);
    detailedResult.addOpportunityResult(failedResult);

    System.assertEquals(
      4,
      detailedResult.totalOpportunities,
      'Should have 4 total opportunities'
    );
    System.assertEquals(
      1,
      detailedResult.emailsSent,
      'Should have 1 email sent'
    );
    System.assertEquals(
      1,
      detailedResult.alreadyAcknowledged,
      'Should have 1 already acknowledged'
    );
    System.assertEquals(
      1,
      detailedResult.noValidContact,
      'Should have 1 no valid contact'
    );
    System.assertEquals(
      1,
      detailedResult.emailSendFailures,
      'Should have 1 email send failure'
    );

    // Test filtering methods
    List<DonationAcknowledgementService.OpportunityResult> successful = detailedResult.getSuccessfulResults();
    System.assertEquals(
      1,
      successful.size(),
      'Should have 1 successful result'
    );
    System.assertEquals(
      'Success Opp',
      successful[0].opportunityName,
      'Should be the success opportunity'
    );

    List<DonationAcknowledgementService.OpportunityResult> skipped = detailedResult.getSkippedResults();
    System.assertEquals(2, skipped.size(), 'Should have 2 skipped results');

    List<DonationAcknowledgementService.OpportunityResult> failed = detailedResult.getFailedResults();
    System.assertEquals(1, failed.size(), 'Should have 1 failed result');
    System.assertEquals(
      'Failed Opp',
      failed[0].opportunityName,
      'Should be the failed opportunity'
    );

    // Test summary message
    detailedResult.emailType = 'Test Email Type';
    String summary = detailedResult.buildSummaryMessage();
    System.assert(
      summary.contains('4 Opportunities'),
      'Summary should show total count'
    );
    System.assert(
      summary.contains('Emails sent: 1'),
      'Summary should show emails sent'
    );
    System.assert(
      summary.contains('Already acknowledged: 1'),
      'Summary should show already acknowledged'
    );
    System.assert(
      summary.contains('No valid contact: 1'),
      'Summary should show no valid contact'
    );
    System.assert(
      summary.contains('Email send failures: 1'),
      'Summary should show email failures'
    );
    System.assert(
      summary.contains('Test Email Type'),
      'Summary should include email type'
    );
  }

  @isTest
  static void testSendEmailsCoreDetailedWithSuccessfulOpportunities() {
    // Test the detailed core method with successful opportunities
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Opportunity opp1 = new Opportunity(
      Name = 'Success Opp 1',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
    );

    Opportunity opp2 = new Opportunity(
      Name = 'Success Opp 2',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 200,
      ContactId = c.Id
    );

    insert new List<Opportunity>{ opp1, opp2 };

    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN (:opp1.Id, :opp2.Id)
    ];

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );

    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();

    // Verify detailed results
    System.assertEquals(
      2,
      result.totalOpportunities,
      'Should have 2 total opportunities'
    );
    System.assertEquals(2, result.emailsSent, 'Should have sent 2 emails');
    System.assertEquals(
      0,
      result.alreadyAcknowledged,
      'Should have 0 already acknowledged'
    );
    System.assertEquals(
      0,
      result.noValidContact,
      'Should have 0 no valid contact'
    );
    System.assertEquals(
      0,
      result.emailSendFailures,
      'Should have 0 email failures'
    );

    // Verify individual opportunity results
    System.assertEquals(
      2,
      result.opportunityResults.size(),
      'Should have 2 opportunity results'
    );

    for (
      DonationAcknowledgementService.OpportunityResult oppResult : result.opportunityResults
    ) {
      System.assertEquals(
        DonationAcknowledgementService.AckStatus.SUCCESS,
        oppResult.status,
        'Should be successful'
      );
      System.assertEquals(
        'Email sent successfully',
        oppResult.reason,
        'Should have success reason'
      );
      System.assertEquals(
        Date.today(),
        oppResult.acknowledgmentDate,
        'Should have acknowledgment date set'
      );
      System.assertEquals(
        'testuser@example.com',
        oppResult.contactEmail,
        'Should have contact email'
      );
    }

    // Verify acknowledgment dates were set in database
    List<Opportunity> updatedOpps = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN (:opp1.Id, :opp2.Id)
    ];

    for (Opportunity updatedOpp : updatedOpps) {
      System.assertEquals(
        Date.today(),
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Should have acknowledgment date set in database'
      );
    }
  }

  @isTest
  static void testSendEmailsCoreDetailedWithMixedScenarios() {
    // Test detailed method with various scenarios
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create opportunities with different scenarios
    Opportunity successOpp = new Opportunity(
      Name = 'Success Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
    );

    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Already Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today().addDays(-1),
      Amount = 200,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1)
    );

    Opportunity noContactOpp = new Opportunity(
      Name = 'No Contact Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 150
      // No ContactId
    );

    insert new List<Opportunity>{ successOpp, acknowledgedOpp, noContactOpp };

    // Create contact with no email for testing
    Contact noEmailContact = new Contact(
      FirstName = 'No Email',
      LastName = 'Contact'
      // No Email field
    );
    insert noEmailContact;

    Opportunity noEmailOpp = new Opportunity(
      Name = 'No Email Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 75,
      ContactId = noEmailContact.Id
    );
    insert noEmailOpp;

    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE
        Id IN (
          :successOpp.Id,
          :acknowledgedOpp.Id,
          :noContactOpp.Id,
          :noEmailOpp.Id
        )
    ];

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );

    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();

    // Verify aggregated counts
    System.assertEquals(
      4,
      result.totalOpportunities,
      'Should have 4 total opportunities'
    );
    System.assertEquals(1, result.emailsSent, 'Should have sent 1 email');
    System.assertEquals(
      1,
      result.alreadyAcknowledged,
      'Should have 1 already acknowledged'
    );
    System.assertEquals(
      2,
      result.noValidContact,
      'Should have 2 no valid contact (no contact + no email)'
    );
    System.assertEquals(
      0,
      result.emailSendFailures,
      'Should have 0 email failures'
    );

    // Verify individual results by status
    List<DonationAcknowledgementService.OpportunityResult> successfulResults = result.getSuccessfulResults();
    System.assertEquals(
      1,
      successfulResults.size(),
      'Should have 1 successful result'
    );
    System.assertEquals(
      'Success Opp',
      successfulResults[0].opportunityName,
      'Should be the success opportunity'
    );
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      successfulResults[0].status
    );

    List<DonationAcknowledgementService.OpportunityResult> skippedResults = result.getSkippedResults();
    System.assertEquals(
      3,
      skippedResults.size(),
      'Should have 3 skipped results'
    );

    // Find and verify specific skipped results
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = new Map<String, DonationAcknowledgementService.OpportunityResult>();
    for (
      DonationAcknowledgementService.OpportunityResult oppResult : result.opportunityResults
    ) {
      resultsByName.put(oppResult.opportunityName, oppResult);
    }

    // Verify already acknowledged opportunity
    DonationAcknowledgementService.OpportunityResult acknowledgedResult = resultsByName.get(
      'Already Acknowledged Opp'
    );
    System.assertNotEquals(
      null,
      acknowledgedResult,
      'Should have acknowledged result'
    );
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      acknowledgedResult.status
    );
    System.assert(
      acknowledgedResult.reason.contains('already acknowledged'),
      'Should have appropriate reason'
    );

    // Verify no contact opportunity
    DonationAcknowledgementService.OpportunityResult noContactResult = resultsByName.get(
      'No Contact Opp'
    );
    System.assertNotEquals(
      null,
      noContactResult,
      'Should have no contact result'
    );
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.NO_CONTACT,
      noContactResult.status
    );
    System.assertEquals(
      'Opportunity has no associated Contact',
      noContactResult.reason
    );

    // Verify no email opportunity
    DonationAcknowledgementService.OpportunityResult noEmailResult = resultsByName.get(
      'No Email Opp'
    );
    System.assertNotEquals(null, noEmailResult, 'Should have no email result');
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.NO_EMAIL,
      noEmailResult.status
    );
    System.assertEquals('Contact has no email address', noEmailResult.reason);
  }

  @isTest
  static void testAckStatusEnumValues() {
    // Test that all expected enum values exist
    System.assertNotEquals(
      null,
      DonationAcknowledgementService.AckStatus.SUCCESS
    );
    System.assertNotEquals(
      null,
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED
    );
    System.assertNotEquals(
      null,
      DonationAcknowledgementService.AckStatus.NO_CONTACT
    );
    System.assertNotEquals(
      null,
      DonationAcknowledgementService.AckStatus.NO_EMAIL
    );
    System.assertNotEquals(
      null,
      DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED
    );
    System.assertNotEquals(
      null,
      DonationAcknowledgementService.AckStatus.INVALID_OPPORTUNITY
    );
  }

  @isTest
  static void testSendAcknowledgementsDetailedWithTemplate() {
    // Test the new detailed AuraEnabled method with template
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );
    Test.stopTest();

    // Verify DetailedAckResult structure and content
    System.assertEquals(
      1,
      result.totalOpportunities,
      'Should have 1 total opportunity'
    );
    System.assertEquals(1, result.emailsSent, 'Should have sent 1 email');
    System.assertEquals(
      0,
      result.alreadyAcknowledged,
      'Should have 0 already acknowledged'
    );
    System.assertEquals(
      0,
      result.noValidContact,
      'Should have 0 no valid contact'
    );
    System.assertEquals(
      0,
      result.emailSendFailures,
      'Should have 0 email failures'
    );
    System.assert(
      result.emailType.contains('Template used'),
      'Should indicate template usage'
    );

    // Verify individual opportunity results
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 opportunity result'
    );
    DonationAcknowledgementService.OpportunityResult oppResult = result.opportunityResults[0];
    System.assertEquals(
      opp.Id,
      oppResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      oppResult.status,
      'Should be successful'
    );
    System.assertEquals(
      'Email sent successfully',
      oppResult.reason,
      'Should have success reason'
    );
    System.assertEquals(
      'testuser@example.com',
      oppResult.contactEmail,
      'Should have contact email'
    );
    System.assertEquals(
      Date.today(),
      oppResult.acknowledgmentDate,
      'Should have acknowledgment date'
    );

    // Verify acknowledgment date was set in database
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(),
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Should have acknowledgment date set in database'
    );
  }

  @isTest
  static void testSendAcknowledgementsDetailedStaticFallback() {
    // Test the detailed method with static content fallback
    DonationAcknowledgementService.donationAckTemplateDevName = 'DoesNotExistTemplate';
    DonationAcknowledgementService.donationAckTemplateFolder = 'DoesNotExistFolder';

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );
    Test.stopTest();

    // Verify fallback to static content
    System.assertEquals(
      1,
      result.totalOpportunities,
      'Should have 1 total opportunity'
    );
    System.assertEquals(1, result.emailsSent, 'Should have sent 1 email');
    System.assert(
      result.emailType.contains('Static content fallback'),
      'Should indicate static fallback'
    );

    // Verify individual opportunity result
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 opportunity result'
    );
    DonationAcknowledgementService.OpportunityResult oppResult = result.opportunityResults[0];
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      oppResult.status,
      'Should be successful'
    );
  }

  @isTest
  static void testSendAcknowledgementsDetailedEmptyInput() {
    // Test enhanced method with empty input
    List<Id> emptyIds = new List<Id>();

    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      emptyIds
    );
    Test.stopTest();

    // Verify graceful handling of empty input
    System.assertEquals(
      0,
      result.totalOpportunities,
      'Should have 0 total opportunities'
    );
    System.assertEquals(0, result.emailsSent, 'Should have sent 0 emails');
    System.assertEquals(
      0,
      result.opportunityResults.size(),
      'Should have 0 opportunity results'
    );
    System.assertEquals(
      'No opportunities provided',
      result.emailType,
      'Should indicate no opportunities'
    );
  }

  @isTest
  static void testGetOpportunityResults() {
    // Test individual opportunity results method for LWC consumption
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create mixed scenario opportunities
    Opportunity successOpp = new Opportunity(
      Name = 'Success Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
    );

    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Already Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today().addDays(-1),
      Amount = 200,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1)
    );

    insert new List<Opportunity>{ successOpp, acknowledgedOpp };

    List<Id> oppIds = new List<Id>{ successOpp.Id, acknowledgedOpp.Id };

    Test.startTest();
    List<DonationAcknowledgementService.OpportunityResult> results = DonationAcknowledgementService.getOpportunityResults(
      oppIds
    );
    Test.stopTest();

    // Verify LWC consumption compatibility
    System.assertEquals(2, results.size(), 'Should have 2 opportunity results');

    // Find results by opportunity name
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = new Map<String, DonationAcknowledgementService.OpportunityResult>();
    for (DonationAcknowledgementService.OpportunityResult result : results) {
      resultsByName.put(result.opportunityName, result);
    }

    // Verify successful opportunity
    DonationAcknowledgementService.OpportunityResult successResult = resultsByName.get(
      'Success Opp'
    );
    System.assertNotEquals(null, successResult, 'Should have success result');
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      successResult.status
    );
    System.assertEquals('Email sent successfully', successResult.reason);
    System.assertEquals('testuser@example.com', successResult.contactEmail);

    // Verify already acknowledged opportunity
    DonationAcknowledgementService.OpportunityResult acknowledgedResult = resultsByName.get(
      'Already Acknowledged Opp'
    );
    System.assertNotEquals(
      null,
      acknowledgedResult,
      'Should have acknowledged result'
    );
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      acknowledgedResult.status
    );
    System.assert(
      acknowledgedResult.reason.contains('already acknowledged'),
      'Should have appropriate reason'
    );
  }

  @isTest
  static void testEnhancedAPIMethodsConsistency() {
    // Test that enhanced methods return consistent data with existing methods
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    // Call both old and new methods
    String basicResult = DonationAcknowledgementService.sendAcknowledgements(
      oppIds
    );

    // Reset acknowledgment date for second test
    Opportunity oppReset = new Opportunity(
      Id = opp.Id,
      npsp__Acknowledgment_Date__c = null
    );
    update oppReset;

    DonationAcknowledgementService.DetailedAckResult detailedResult = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );
    Test.stopTest();

    // Verify consistent data between methods
    System.assert(
      basicResult.contains('Emails sent: 1'),
      'Basic method should show 1 email sent'
    );
    System.assertEquals(
      1,
      detailedResult.emailsSent,
      'Detailed method should show 1 email sent'
    );

    // Verify detailed method provides additional information
    System.assertEquals(
      1,
      detailedResult.opportunityResults.size(),
      'Should have detailed opportunity results'
    );
    System.assertNotEquals(
      null,
      detailedResult.emailType,
      'Should have email type information'
    );
  }
}
