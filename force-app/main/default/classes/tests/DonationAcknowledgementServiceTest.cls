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
      npsp__Primary_Contact__c = c.Id
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
      // Verify acknowledgment status is set
      AcknowledgementTestUtils.assertAcknowledgmentStatusSet(
        opp.Id,
        'Acknowledged'
      );
    } finally {
      AcknowledgementTestUtils.resetServiceInstance();
    }
  }

  @isTest
  static void testSendAcknowledgementsConfigErrorWhenTemplateMissing() {
    // When the configured template cannot be found, this is a hard configuration
    // error: no emails are sent, nothing is updated, and every requested opportunity
    // is reported as CONFIG_ERROR - there is no more silent static-content fallback.
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
      System.assertEquals(
        0,
        result[0].emailsSent,
        'No emails should be sent when the configured template is missing'
      );
      System.assertEquals(1, result[0].totalOpportunities);
      System.assertEquals(
        1,
        result[0].configErrors,
        'Should report 1 configuration error'
      );
      System.assert(
        result[0].summaryMessage.contains('Configuration errors: 1'),
        'Summary should mention the configuration error: ' +
        result[0].summaryMessage
      );
      System.assertEquals(
        1,
        result[0].opportunityDetails.size(),
        'Should have 1 opportunity detail'
      );
      System.assertEquals(
        String.valueOf(AckStatus.CONFIG_ERROR),
        result[0].opportunityDetails[0].status,
        'Opportunity should be reported as CONFIG_ERROR'
      );
      System.assert(
        result[0].opportunityDetails[0].reason.contains('not found in folder'),
        'Reason should explain the missing template'
      );
      // Verify acknowledgement date is NOT set - nothing was sent or updated
      Opportunity updatedOpp = AcknowledgementTestUtils.queryOpportunityWithAckDate(
        opp.Id
      );
      System.assertEquals(
        null,
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Acknowledgment date should not be set when configuration errors out'
      );
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
    // This test verifies that if email sending fails, acknowledgment dates are not
    // updated, and that the facade never throws for this expected failure - it is
    // reported as a per-opportunity EMAIL_SEND_FAILED status instead.
    Opportunity opp = AcknowledgementTestUtils.queryOpportunityWithAckDate(
      [SELECT Id FROM Opportunity LIMIT 1].Id
    );

    // Verify opportunity starts without acknowledgment date
    System.assertEquals(
      null,
      opp.npsp__Acknowledgment_Date__c,
      'Opportunity should start without acknowledgment date'
    );

    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    MockEmailService mock = (MockEmailService) service.emailService;
    mock.setFailure('Simulated total send failure');
    AcknowledgementTestUtils.injectServiceInstance(service);

    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    AckDetailedResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );
    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    // Verify the failure was reported without throwing
    System.assertEquals(
      0,
      result.emailsSent,
      'Should not indicate any emails were sent'
    );
    System.assertEquals(
      1,
      result.emailSendFailures,
      'Should indicate 1 email send failure'
    );

    // Verify acknowledgment date was NOT set on failure
    Opportunity updatedOpp = AcknowledgementTestUtils.queryOpportunityWithAckDate(
      opp.Id
    );
    System.assertEquals(
      null,
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgment date should not be set on failure'
    );
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

    AckDetailedResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
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
    AckDetailedResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
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

    AckOpportunityResult oppResult = new AckOpportunityResult(
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
    oppResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
    System.assertEquals(
      AckStatus.SUCCESS,
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
    oppResult.setStatus(AckStatus.ALREADY_ACKNOWLEDGED, 'Already acknowledged');
    System.assert(!oppResult.isSuccess(), 'Should not identify as success');
    System.assert(oppResult.isSkipped(), 'Should identify as skipped');
    System.assert(!oppResult.isFailed(), 'Should not identify as failed');

    // Test setting failed status
    oppResult.setStatus(AckStatus.EMAIL_SEND_FAILED, 'Send failed');
    System.assert(!oppResult.isSuccess(), 'Should not identify as success');
    System.assert(!oppResult.isSkipped(), 'Should not identify as skipped');
    System.assert(oppResult.isFailed(), 'Should identify as failed');
  }

  @isTest
  static void testDetailedAckResultAggregation() {
    // Test DetailedAckResult class functionality
    AckDetailedResult detailedResult = new AckDetailedResult();

    // Create various OpportunityResults to test aggregation
    AckOpportunityResult successResult = new AckOpportunityResult(
      '006000000000001AAA',
      'Success Opp'
    );
    successResult.setStatus(AckStatus.SUCCESS, 'Email sent');

    AckOpportunityResult acknowledgedResult = new AckOpportunityResult(
      '006000000000002AAA',
      'Acknowledged Opp'
    );
    acknowledgedResult.setStatus(
      AckStatus.ALREADY_ACKNOWLEDGED,
      'Already done'
    );

    AckOpportunityResult noContactResult = new AckOpportunityResult(
      '006000000000003AAA',
      'No Contact Opp'
    );
    noContactResult.setStatus(AckStatus.NO_CONTACT, 'No contact');

    AckOpportunityResult failedResult = new AckOpportunityResult(
      '006000000000004AAA',
      'Failed Opp'
    );
    failedResult.setStatus(AckStatus.EMAIL_SEND_FAILED, 'Send failed');

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
    List<AckOpportunityResult> successful = detailedResult.getSuccessfulResults();
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

    List<AckOpportunityResult> skipped = detailedResult.getSkippedResults();
    System.assertEquals(2, skipped.size(), 'Should have 2 skipped results');

    List<AckOpportunityResult> failed = detailedResult.getFailedResults();
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

  // NOTE: testSendEmailsCoreDetailedWithSuccessfulOpportunities and
  // testSendEmailsCoreDetailedWithMixedScenarios were removed from this file -
  // they called DonationAcknowledgementServiceImpl.sendEmailsCoreDetailed()
  // directly (impl-level, not through the facade) and duplicated
  // identically-named tests in DonationAcknowledgementServiceImplTest.

  @isTest
  static void testAckStatusEnumValues() {
    // Test that all expected enum values exist
    System.assertNotEquals(null, AckStatus.SUCCESS);
    System.assertNotEquals(null, AckStatus.ALREADY_ACKNOWLEDGED);
    System.assertNotEquals(null, AckStatus.NO_CONTACT);
    System.assertNotEquals(null, AckStatus.NO_EMAIL);
    System.assertNotEquals(null, AckStatus.EMAIL_SEND_FAILED);
    System.assertNotEquals(null, AckStatus.INVALID_OPPORTUNITY);
    System.assertNotEquals(null, AckStatus.ACK_UPDATE_FAILED);
    System.assertNotEquals(null, AckStatus.CONFIG_ERROR);
  }

  @isTest
  static void testSendAcknowledgementsDetailedWithTemplate() {
    // Test the new detailed AuraEnabled method with template
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    AcknowledgementTestUtils.injectServiceWithMockEmail();

    AckDetailedResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
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
    AckOpportunityResult oppResult = result.opportunityResults[0];
    System.assertEquals(
      opp.Id,
      oppResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      AckStatus.SUCCESS,
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
  static void testSendAcknowledgementsDetailedConfigErrorWhenTemplateMissing() {
    // Test the detailed method's hard-error behavior when the configured template
    // cannot be found - no more silent fallback to static content.
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    service.donationAckTemplateDevName = 'DoesNotExistTemplate';
    service.donationAckTemplateFolder = 'DoesNotExistFolder';
    AcknowledgementTestUtils.injectServiceInstance(service);
    try {
      Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
      List<Id> oppIds = new List<Id>{ opp.Id };

      Test.startTest();
      AckDetailedResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
        oppIds
      );
      Test.stopTest();

      // Verify hard error: nothing sent, one configuration error
      AcknowledgementTestUtils.assertDetailedResultCounts(
        result,
        1,
        0,
        0,
        0,
        0
      );
      System.assertEquals(
        1,
        result.configErrors,
        'Should report 1 configuration error'
      );
      System.assert(
        result.emailType.contains('Configuration error'),
        'Should indicate a configuration error'
      );

      // Verify individual opportunity result
      System.assertEquals(
        1,
        result.opportunityResults.size(),
        'Should have 1 opportunity result'
      );
      AckOpportunityResult oppResult = result.opportunityResults[0];
      System.assertEquals(
        AckStatus.CONFIG_ERROR,
        oppResult.status,
        'Should be a configuration error'
      );
      System.assert(
        oppResult.isFailed(),
        'CONFIG_ERROR should be considered a failure'
      );
      System.assert(
        oppResult.reason.contains('not found in folder'),
        'Reason should explain the missing template'
      );

      // Verify nothing was updated in the database
      Opportunity updatedOpp = AcknowledgementTestUtils.queryOpportunityWithAckDate(
        opp.Id
      );
      System.assertEquals(
        null,
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Acknowledgment date should not be set when configuration errors out'
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
    AckDetailedResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
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
  static void testEnhancedAPIMethodsConsistency() {
    // Test that enhanced methods return consistent data with invocable methods
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    AcknowledgementTestUtils.injectServiceWithMockEmail();

    // Call detailed method
    AckDetailedResult detailedResult = DonationAcknowledgementService.sendAcknowledgementsDetailed(
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

  @isTest
  static void testInvocableWithTotalSendFailureDoesNotThrow() {
    // Verify sendAcknowledgementsInvocable never throws, even when every email
    // send fails - Flow invocable methods must not throw or they break the
    // running Flow interview.
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity opp1 = AcknowledgementTestUtils.createTestOpportunity(
      'Invocable Fail Opp 1',
      c,
      null,
      100
    );
    Opportunity opp2 = AcknowledgementTestUtils.createTestOpportunity(
      'Invocable Fail Opp 2',
      c,
      null,
      100
    );

    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    MockEmailService mock = (MockEmailService) service.emailService;
    mock.setFailure('Total send outage');
    AcknowledgementTestUtils.injectServiceInstance(service);

    List<DonationAcknowledgementService.OpportunityIdWrapper> input = AcknowledgementTestUtils.createWrapperInput(
      new List<Id>{ opp1.Id, opp2.Id }
    );

    Test.startTest();
    List<DonationAcknowledgementService.DetailedAckResultWrapper> results = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      input
    );
    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return exactly 1 wrapper');
    System.assertEquals(
      2,
      results[0].emailSendFailures,
      'Should report both opportunities as email send failures'
    );
    System.assertEquals(
      0,
      results[0].emailsSent,
      'Should report 0 emails sent'
    );
    System.assertNotEquals(
      null,
      results[0].summaryMessage,
      'Should have a summary message'
    );
  }

  @isTest
  static void testSendAcknowledgementsDetailedWithMixedResultsDoesNotThrow() {
    // Verify the AuraEnabled sendAcknowledgementsDetailed method returns mixed
    // per-opportunity statuses (some succeed, some fail) without throwing.
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Opportunity successOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Mixed Success Opp',
      validContact,
      null,
      100
    );
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Mixed Already Acknowledged Opp',
      validContact,
      Date.today().addDays(-1),
      200
    );
    Opportunity noContactOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Mixed No Contact Opp',
      null,
      null,
      150
    );

    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    AcknowledgementTestUtils.injectServiceInstance(service);

    List<Id> oppIds = new List<Id>{
      successOpp.Id,
      acknowledgedOpp.Id,
      noContactOpp.Id
    };

    Test.startTest();
    AckDetailedResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(
      oppIds
    );
    AcknowledgementTestUtils.resetServiceInstance();
    Test.stopTest();

    System.assertEquals(
      3,
      result.totalOpportunities,
      'Should process all 3 opportunities'
    );
    Map<String, AckOpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Mixed Success Opp',
      AckStatus.SUCCESS,
      'Email sent successfully'
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Mixed Already Acknowledged Opp',
      AckStatus.ALREADY_ACKNOWLEDGED,
      null
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Mixed No Contact Opp',
      AckStatus.NO_CONTACT,
      null
    );
  }
}
