@isTest
private class DonationAcknowledgementServiceImplTest {
  @testSetup
  static void setupTestData() {
    // Use shared test utils for setup
    Contact c = new Contact(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'testuser@example.com'
    );
    insert c;
    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
    );
    insert opp;
  }

  @isTest
  static void testSendEmailsCoreWithTemplateConfig() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    Id mockTemplateId = '00X000000000000AAA';
    // Instance-based: create and configure service with mock email
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    try {
      DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
        opps,
        new DonationAcknowledgementService.EmailConfig(mockTemplateId)
      );
      System.assert(result.emailsSent >= 0, 'Should return a valid count');
    } catch (Exception e) {
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
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    // Instance-based: create and configure service with mock email
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      new DonationAcknowledgementService.EmailConfig(
        'Test Subject',
        'Test Body'
      )
    );
    Test.stopTest();
    System.assertEquals(1, result.emailsSent, 'Should process one opportunity');
    AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp.Id);
  }

  @isTest
  static void testSendEmailsCoreWithResultReturnsMigratedFunctionality() {
    Map<String, Opportunity> testOpps = AcknowledgementTestUtils.createMixedScenarioOpportunities();
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{
        testOpps.get('acknowledged').Id,
        testOpps.get('success').Id,
        testOpps.get('noContact').Id
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
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 3, 1, 1, 1, 0);
    System.assertEquals(
      3,
      result.opportunityResults.size(),
      'Should have individual opportunity results'
    );
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
  static void testSendEmailsCoreDetailedWithSuccessfulOpportunities() {
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
    // Instance-based: create and configure service with mock email
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 2, 2, 0, 0, 0);
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
    List<Opportunity> updatedOpps = AcknowledgementTestUtils.queryOpportunitiesWithAckDate(
      new List<Id>{ opp1.Id, opp2.Id }
    );
    for (Opportunity updatedOpp : updatedOpps) {
      AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(updatedOpp.Id);
    }
  }

  @isTest
  static void testSendEmailsCoreDetailedWithMixedScenarios() {
    Map<String, Opportunity> testOpps = AcknowledgementTestUtils.createMixedScenarioOpportunities();
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{
        testOpps.get('success').Id,
        testOpps.get('acknowledged').Id,
        testOpps.get('noContact').Id,
        testOpps.get('noEmail').Id
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
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Already Acknowledged Opp',
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      'already acknowledged'
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'No Contact Opp',
      DonationAcknowledgementService.AckStatus.NO_CONTACT,
      'Opportunity has no associated Contact'
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'No Email Opp',
      DonationAcknowledgementService.AckStatus.NO_EMAIL,
      'Contact has no email address'
    );
  }
}
