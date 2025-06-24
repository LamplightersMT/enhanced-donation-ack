/**
 * NOTE: This test class is now focused on facade behavior and public API contract testing only.
 * Detailed workflow and integration logic is now covered in DonationAcknowledgementServiceImplTest per docs/test-refactoring-plan.md.
 */

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

  // ===== HELPER METHODS - NOW USING SHARED UTILS =====
  // All helper methods have been moved to AcknowledgementTestUtils
  // for reuse across multiple test classes
  // ===== END HELPER METHODS =====

  @isTest
  static void testSendAcknowledgementsWithTemplate() {
    // Instance-based injection setup
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    AcknowledgementTestUtils.injectServiceInstance(service);
    try {
      Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
      List<DonationAcknowledgementService.OpportunityIdWrapper> input = AcknowledgementTestUtils.createWrapperInput(
        new List<Id>{ opp.Id }
      );
      Test.startTest();
      List<DonationAcknowledgementService.DetailedAckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
        input
      );
      Test.stopTest();
      System.assertEquals(1, result.size());
      System.assertEquals(1, result[0].emailsSent);
      System.assertEquals(1, result[0].totalOpportunities);
      System.assert(result[0].summaryMessage.contains('Emails sent: 1'));
      // Verify acknowledgement date is set
      AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp.Id);
    } finally {
      AcknowledgementTestUtils.resetServiceInstance();
    }
  }

  @isTest
  static void testSendAcknowledgementsStaticFallback() {
    // Instance-based injection setup with fallback config
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    service.donationAckTemplateDevName = 'DoesNotExistTemplate';
    service.donationAckTemplateFolder = 'DoesNotExistFolder';
    AcknowledgementTestUtils.injectServiceInstance(service);
    try {
      Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
      List<DonationAcknowledgementService.OpportunityIdWrapper> input = AcknowledgementTestUtils.createWrapperInput(
        new List<Id>{ opp.Id }
      );
      Test.startTest();
      List<DonationAcknowledgementService.DetailedAckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
        input
      );
      Test.stopTest();
      System.assertEquals(1, result.size());
      System.assertEquals(1, result[0].emailsSent);
      System.assertEquals(1, result[0].totalOpportunities);
      System.assert(
        result[0].summaryMessage.contains('Static content fallback')
      );
      // Verify acknowledgement date is set
      AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp.Id);
    } finally {
      AcknowledgementTestUtils.resetServiceInstance();
    }
  }

  @isTest
  static void testNoOpportunities() {
    // Instance-based injection setup
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    AcknowledgementTestUtils.injectServiceInstance(service);
    try {
      List<DonationAcknowledgementService.OpportunityIdWrapper> input = AcknowledgementTestUtils.createWrapperInput(
        new List<Id>()
      );
      Test.startTest();
      List<DonationAcknowledgementService.DetailedAckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
        input
      );
      Test.stopTest();
      System.assertEquals(1, result.size());
      System.assertEquals(0, result[0].totalOpportunities);
      System.assertEquals(0, result[0].emailsSent);
      System.assert(
        result[0]
          .summaryMessage.contains(
            'sendAcknowledgements called with 0 Opportunities'
          )
      );
    } finally {
      AcknowledgementTestUtils.resetServiceInstance();
    }
  }

  @isTest
  static void testEmailSendingFailureDoesNotUpdateAcknowledgmentDate() {
    // This test verifies that if email sending fails, acknowledgment dates are not updated
    Opportunity opp = AcknowledgementTestUtils.queryOpportunityWithAckDate(
      [SELECT Id FROM Opportunity LIMIT 1].Id
    );

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
      DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
        oppIds
      );
      // If we get here, email sending succeeded (normal test behavior)
      System.assert(result.emailsSent > 0, 'Should indicate emails were sent');

      // Verify acknowledgment date was set on success
      AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp.Id);
    } catch (AuraHandledException e) {
      // If email sending failed (unlikely in test context), verify acknowledgment date was not set
      System.assert(
        e.getMessage().contains('Failed to send acknowledgement emails') ||
        e.getMessage().contains('Script-thrown exception'), // Re-thrown Aura Exceptions have this message for unknown reasons
        'Exception should indicate email sending failure. Actual: ' +
        e.getMessage()
      );

      Opportunity updatedOpp = AcknowledgementTestUtils.queryOpportunityWithAckDate(
        opp.Id
      );
      System.assertEquals(
        null,
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Acknowledgment date should not be set on failure'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testDuplicatePreventionSkipsAcknowledgedOpportunities() {
    // Create test data with one already acknowledged opportunity
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create two opportunities - one already acknowledged, one not
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Already Acknowledged Opp',
      c,
      Date.today().addDays(-1), // Already acknowledged
      200
    );

    Opportunity newOpp = AcknowledgementTestUtils.createTestOpportunity(
      'New Opp',
      c,
      null,
      100
    );

    List<Id> oppIds = new List<Id>{ acknowledgedOpp.Id, newOpp.Id };

    Test.startTest();
    AcknowledgementTestUtils.injectServiceWithMockEmail();

    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );

    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    // Verify result message shows correct counts
    System.assertEquals(
      2,
      result.totalOpportunities,
      'Should show 2 total opportunities'
    );
    System.assertEquals(
      1,
      result.emailsSent,
      'Should send 1 email (for new opp only)'
    );
    System.assertEquals(
      1,
      result.alreadyAcknowledged,
      'Should show 1 already acknowledged'
    );

    // Verify only the new opportunity got acknowledgment date updated
    List<Opportunity> updatedOpps = AcknowledgementTestUtils.queryOpportunitiesWithAckDate(
      oppIds
    );

    // Already acknowledged opp should keep its original date
    System.assertEquals(
      Date.today().addDays(-1),
      updatedOpps[0].npsp__Acknowledgment_Date__c,
      'Already acknowledged opp should keep original date'
    );

    // New opp should get today's date
    AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(
      updatedOpps[1].Id
    );
  }

  @isTest
  static void testDuplicatePreventionAllAlreadyAcknowledged() {
    // Test scenario where all opportunities are already acknowledged
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Already Acknowledged Opp',
      c,
      Date.today().addDays(-1), // Already acknowledged
      100
    );

    List<Id> oppIds = new List<Id>{ acknowledgedOpp.Id };

    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );
    Test.stopTest();

    // Verify no emails were sent but proper feedback provided
    System.assertEquals(
      1,
      result.totalOpportunities,
      'Should show 1 total opportunity'
    );
    System.assertEquals(0, result.emailsSent, 'Should send 0 emails');
    System.assertEquals(
      1,
      result.alreadyAcknowledged,
      'Should show 1 already acknowledged'
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

    Opportunity opp1 = AcknowledgementTestUtils.createTestOpportunity(
      'Success Opp 1',
      c,
      null,
      100
    );
    Opportunity opp2 = AcknowledgementTestUtils.createTestOpportunity(
      'Success Opp 2',
      c,
      null,
      200
    );

    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp1.Id, opp2.Id }
    );

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );

    Test.startTest();
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();

    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );

    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    // Verify detailed results
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 2, 2, 0, 0, 0);

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
    List<Opportunity> updatedOpps = AcknowledgementTestUtils.queryOpportunitiesWithAckDate(
      new List<Id>{ opp1.Id, opp2.Id }
    );

    for (Opportunity updatedOpp : updatedOpps) {
      AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(updatedOpp.Id);
    }
  }

  @isTest
  static void testSendEmailsCoreDetailedWithMixedScenarios() {
    // Inline creation of test opportunities for each scenario
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Contact noEmailContact = AcknowledgementTestUtils.createTestContactWithoutEmail();
    Opportunity successOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Success Opp',
      validContact,
      null,
      100
    );
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Already Acknowledged Opp',
      validContact,
      Date.today().addDays(-1),
      200
    );
    Opportunity noContactOpp = AcknowledgementTestUtils.createTestOpportunity(
      'No Contact Opp',
      null,
      null,
      150
    );
    Opportunity noEmailOpp = AcknowledgementTestUtils.createTestOpportunity(
      'No Email Opp',
      noEmailContact,
      null,
      75
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{
        successOpp.Id,
        acknowledgedOpp.Id,
        noContactOpp.Id,
        noEmailOpp.Id
      }
    );
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );
    // Instance-based: create and configure service with mock email
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 4, 1, 1, 2, 0);
    List<DonationAcknowledgementService.OpportunityResult> successfulResults = result.getSuccessfulResults();
    System.assertEquals(
      1,
      successfulResults.size(),
      'Should have one successful result'
    );
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
    AcknowledgementTestUtils.injectServiceWithMockEmail();

    DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );

    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    // Verify DetailedAckResult structure and content
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 1, 1, 0, 0, 0);
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
    AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp.Id);
  }

  @isTest
  static void testSendAcknowledgementsDetailedStaticFallback() {
    // Test the detailed method with static content fallback
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    service.donationAckTemplateDevName = 'DoesNotExistTemplate';
    service.donationAckTemplateFolder = 'DoesNotExistFolder';
    AcknowledgementTestUtils.injectServiceInstance(service);
    try {
      Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
      List<Id> oppIds = new List<Id>{ opp.Id };

      Test.startTest();
      DonationAcknowledgementService.DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
        oppIds
      );
      Test.stopTest();

      // Verify fallback to static content
      AcknowledgementTestUtils.assertDetailedResultCounts(
        result,
        1,
        1,
        0,
        0,
        0
      );
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
    } finally {
      AcknowledgementTestUtils.resetServiceInstance();
    }
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
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 0, 0, 0, 0, 0);
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
    Opportunity successOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Success Opp',
      c,
      null,
      100
    );
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Already Acknowledged Opp',
      c,
      Date.today().addDays(-1), // Already acknowledged
      200
    );

    List<Id> oppIds = new List<Id>{ successOpp.Id, acknowledgedOpp.Id };

    Test.startTest();
    AcknowledgementTestUtils.injectServiceWithMockEmail();

    List<DonationAcknowledgementService.OpportunityResult> results = DonationAcknowledgementService.getOpportunityResults(
      oppIds
    );

    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    // Verify LWC consumption compatibility
    System.assertEquals(2, results.size(), 'Should have 2 opportunity results');

    // Find results by opportunity name using helper
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      results
    );

    // Verify successful opportunity
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Success Opp',
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent successfully'
    );

    DonationAcknowledgementService.OpportunityResult successResult = resultsByName.get(
      'Success Opp'
    );
    System.assertEquals('testuser@example.com', successResult.contactEmail);

    // Verify already acknowledged opportunity
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Already Acknowledged Opp',
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      'already acknowledged'
    );
  }

  @isTest
  static void testEnhancedAPIMethodsConsistency() {
    // Test that enhanced methods return consistent data with invocable methods
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    AcknowledgementTestUtils.injectServiceWithMockEmail();

    // Call detailed method
    DonationAcknowledgementService.DetailedAckResult detailedResult = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );

    // Reset acknowledgment date for second test
    Opportunity oppReset = new Opportunity(
      Id = opp.Id,
      npsp__Acknowledgment_Date__c = null
    );
    update oppReset;

    // Call invocable method for comparison
    List<DonationAcknowledgementService.OpportunityIdWrapper> inputList = new List<DonationAcknowledgementService.OpportunityIdWrapper>();
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = oppIds;
    inputList.add(wrapper);

    List<DonationAcknowledgementService.DetailedAckResultWrapper> invocableResults = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      inputList
    );

    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    // Verify consistent data between methods
    System.assertEquals(
      1,
      detailedResult.emailsSent,
      'Detailed method should show 1 email sent. Actual: ' +
      String.valueOf(detailedResult.emailsSent)
    );
    System.assertEquals(
      1,
      invocableResults[0].emailsSent,
      'Invocable method should show 1 email sent. Actual: ' +
      String.valueOf(invocableResults[0].emailsSent)
    );

    // Verify detailed method provides additional information
    System.assertEquals(
      1,
      detailedResult.opportunityResults.size(),
      'Should have detailed opportunity results. Actual: ' +
      String.valueOf(detailedResult.opportunityResults.size())
    );
    System.assertNotEquals(
      null,
      detailedResult.emailType,
      'Should have email type information. Actual: ' +
      String.valueOf(detailedResult.emailType)
    );
  }
}
