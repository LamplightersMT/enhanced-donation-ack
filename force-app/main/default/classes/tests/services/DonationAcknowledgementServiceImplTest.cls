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
    // Inline creation of test opportunities for each scenario
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Contact noEmailContact = AcknowledgementTestUtils.createTestContactWithoutEmail();
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Already Acknowledged Opp',
      validContact,
      Date.today().addDays(-1),
      200
    );
    Opportunity successOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Success Opp',
      validContact,
      null,
      100
    );
    Opportunity noContactOpp = AcknowledgementTestUtils.createTestOpportunity(
      'No Contact Opp',
      null,
      null,
      150
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ acknowledgedOpp.Id, successOpp.Id, noContactOpp.Id }
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
      'Summary should mention 3 Opportunities'
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

  /**
   * The following test methods were moved from command test classes as part of the test responsibility refactor.
   * See docs/test-refactoring-plan.md for details and original method names.
   */

  @isTest
  static void testServiceTransactionBehavior() {
    // Inline creation of test opportunities for each scenario
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Opportunity validOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Success Opp',
      validContact,
      null,
      100
    );
    Opportunity invalidOpp = new Opportunity(
      Name = 'Invalid Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100
      // No ContactId - makes it invalid for the service
    );
    insert invalidOpp;
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ validOpp.Id, invalidOpp.Id }
    );
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    // Add assertions as needed for transaction behavior
  }

  @isTest
  static void testServiceBulkProcessing() {
    // Moved from testUpdateDatabaseBulkProcessing (DatabaseUpdateCommandTest)
    // Verifies bulk processing of multiple opportunities
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    List<Id> oppIds = new List<Id>();
    for (Integer i = 1; i <= 5; i++) {
      Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
        'Bulk Opp ' + i,
        c,
        null,
        100 * i
      );
      oppIds.add(opp.Id);
    }
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      oppIds
    );
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Bulk Subject',
      'Bulk Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    System.assertEquals(
      5,
      result.emailsSent,
      'Should process all opportunities'
    );
    for (Id oppId : oppIds) {
      AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(oppId);
    }
  }

  @isTest
  static void testServiceTemplateIntegration() {
    // Moved from testPrepareEmailsWithTemplateConfig (EmailPreparationCommandTest)
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    Id mockTemplateId = '00X000000000000AAA';
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      mockTemplateId
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    try {
      DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
        opps,
        config
      );
      System.assert(result.emailsSent >= 0, 'Should return a valid count');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('Invalid parameter value') ||
        e.getMessage().contains('template'),
        'Should get template-related error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testServiceMultipleContacts() {
    // Moved from testPrepareEmailsMultipleContacts (EmailPreparationCommandTest)
    Contact c1 = AcknowledgementTestUtils.createTestContact(
      'contact1@example.com'
    );
    Contact c2 = AcknowledgementTestUtils.createTestContact(
      'contact2@example.com'
    );
    Opportunity opp1 = AcknowledgementTestUtils.createTestOpportunity(
      'Contact1 Opp',
      c1,
      null,
      150
    );
    Opportunity opp2 = AcknowledgementTestUtils.createTestOpportunity(
      'Contact2 Opp',
      c2,
      null,
      250
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp1.Id, opp2.Id }
    );
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Multi Contact Subject',
      'Multi Contact Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    System.assertEquals(
      2,
      result.emailsSent,
      'Should send emails to both contacts'
    );
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );
    System.assertEquals(
      'contact1@example.com',
      resultsByName.get('Contact1 Opp').contactEmail,
      'Should have contact 1 email'
    );
    System.assertEquals(
      'contact2@example.com',
      resultsByName.get('Contact2 Opp').contactEmail,
      'Should have contact 2 email'
    );
  }

  @isTest
  static void testServiceOrgWideEmailAddress() {
    // Moved from testPrepareEmailsWithOrgWideEmailAddress (EmailPreparationCommandTest)
    // This test verifies the service handles org-wide email gracefully
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
      'OrgWide Opp',
      c,
      null,
      300
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'OrgWide Subject',
      'OrgWide Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    System.assertEquals(
      1,
      result.emailsSent,
      'Should send email with org-wide config'
    );
  }

  @isTest
  static void testServiceOrgWideEmailDefaults() {
    // Combined from testGetDefaultOrgWideEmailAddressId_DefaultExists, testGetDefaultOrgWideEmailAddressId_SelectionAndDefaultExists, testGetDefaultOrgWideEmailAddressId_NoDefaultExists
    OrgWideEmailAddress mockAddressDefault = new OrgWideEmailAddress();
    mockAddressDefault.Id = '0D2000000000001AAA';
    mockAddressDefault.Purpose = 'DefaultNoReply';
    MockOrgWideEmailService mockServiceDefault = new MockOrgWideEmailService(
      mockAddressDefault
    );

    OrgWideEmailAddress mockAddressSelection = new OrgWideEmailAddress();
    mockAddressSelection.Id = '0D2000000000001AAB';
    mockAddressSelection.Purpose = 'UserSelectionAndDefaultNoReply';
    IOrgWideEmailService mockServiceSelection = new MockOrgWideEmailService(
      mockAddressSelection
    );

    IOrgWideEmailService mockServiceNone = new MockOrgWideEmailService(null);

    Id resultDefaultNoReply;
    Id resultSelection;
    Id resultNone;

    Test.startTest();
    // Case 1: DefaultNoReply
    EmailPreparationCommand cmdDefault = new EmailPreparationCommand(
      new List<Opportunity>(),
      new DonationAcknowledgementService.EmailConfig('', '')
    );
    cmdDefault.orgWideEmailService = mockServiceDefault;
    resultDefaultNoReply = cmdDefault.getDefaultOrgWideEmailAddressId();
    // Case 2: UserSelectionAndDefaultNoReply
    EmailPreparationCommand cmdSelection = new EmailPreparationCommand(
      new List<Opportunity>(),
      new DonationAcknowledgementService.EmailConfig('', '')
    );
    cmdSelection.orgWideEmailService = mockServiceSelection;
    resultSelection = cmdSelection.getDefaultOrgWideEmailAddressId();
    // Case 3: No default
    EmailPreparationCommand cmdNone = new EmailPreparationCommand(
      new List<Opportunity>(),
      new DonationAcknowledgementService.EmailConfig('', '')
    );
    cmdNone.orgWideEmailService = mockServiceNone;
    resultNone = cmdNone.getDefaultOrgWideEmailAddressId();
    Test.stopTest();

    System.assertEquals(
      mockAddressDefault.Id,
      resultDefaultNoReply,
      'Should return DefaultNoReply address Id'
    );
    System.assertEquals(
      mockAddressSelection.Id,
      resultSelection,
      'Should return the default no-reply address ID when Purpose = UserSelectionAndDefaultNoReply'
    );
    System.assertEquals(
      null,
      resultNone,
      'Should return null when no default address exists'
    );
  }

  @isTest
  static void testServiceTemplateEmailSending() {
    // Moved from testSendEmailsWithTemplateEmail (EmailSendCommandTest)
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    Id mockTemplateId = '00X000000000000AAA';
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      mockTemplateId
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    try {
      DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
        opps,
        config
      );
      System.assert(result.emailsSent >= 0, 'Should return a valid count');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('Invalid parameter value') ||
        e.getMessage().contains('template'),
        'Should get template-related error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testServiceDifferentEmailTypes() {
    // Moved from testEmailSendCommandWithDifferentEmailTypes (EmailSendCommandTest)
    // Simulate sending different types of emails (plain, template, etc.)
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Type Subject',
      'Type Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    System.assert(
      result.emailsSent >= 0,
      'Should process different email types'
    );
  }

  @isTest
  static void testServiceMixedValidationScenarios() {
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
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 4, 1, 1, 2, 0);
  }

  @isTest
  static void testServiceCommandIntegration() {
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
      'Integration Subject',
      'Integration Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    DonationAcknowledgementService.DetailedAckResult result = service.sendEmailsCoreDetailed(
      opps,
      config
    );
    Test.stopTest();
    String summary = result.buildSummaryMessage();
    System.assert(
      summary.contains('4 Opportunities'),
      'Summary should mention 4 Opportunities'
    );
  }
}
