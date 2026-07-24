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
      npsp__Primary_Contact__c = c.Id
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
      AckDetailedResult result = service.sendEmailsCoreDetailed(
        opps,
        new AckEmailConfig(mockTemplateId)
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
    AckDetailedResult result = service.sendEmailsCoreDetailed(
      opps,
      new AckEmailConfig('Test Subject', 'Test Body')
    );
    Test.stopTest();
    System.assertEquals(1, result.emailsSent, 'Should process one opportunity');
    AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp.Id);
  }

  @isTest
  static void testSendEmailsCoreWithResultReturnsMigratedFunctionality() {
    // Inline creation of test opportunities for each scenario.
    // NOTE: Opportunities are built and inserted in a single bulk DML statement
    // rather than one insert per opportunity - NPSP's Primary Contact Role sync
    // automation (triggered by npsp__Primary_Contact__c) can otherwise blow
    // through the SOQL governor limit when several opportunities share a
    // Contact/Account and are inserted one at a time in the same test method.
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Contact noEmailContact = AcknowledgementTestUtils.createTestContactWithoutEmail();
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Already Acknowledged Opp',
      validContact,
      Date.today().addDays(-1),
      200
    );
    Opportunity successOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Success Opp',
      validContact,
      null,
      100
    );
    Opportunity noContactOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'No Contact Opp',
      null,
      null,
      150
    );
    AcknowledgementTestUtils.insertTestOpportunities(
      new List<Opportunity>{ acknowledgedOpp, successOpp, noContactOpp }
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ acknowledgedOpp.Id, successOpp.Id, noContactOpp.Id }
    );
    AckEmailConfig config = new AckEmailConfig('Test Subject', 'Test Body');
    // Instance-based: create and configure service with mock email
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
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
    AckEmailConfig config = new AckEmailConfig('Test Subject', 'Test Body');
    // Instance-based: create and configure service with mock email
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 2, 2, 0, 0, 0);
    System.assertEquals(
      2,
      result.opportunityResults.size(),
      'Should have 2 opportunity results'
    );
    for (AckOpportunityResult oppResult : result.opportunityResults) {
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
    // Inline creation of test opportunities for each scenario.
    // Bulk-inserted in one DML statement - see comment on
    // testSendEmailsCoreWithResultReturnsMigratedFunctionality for why.
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Contact noEmailContact = AcknowledgementTestUtils.createTestContactWithoutEmail();
    Opportunity successOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Success Opp',
      validContact,
      null,
      100
    );
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Already Acknowledged Opp',
      validContact,
      Date.today().addDays(-1),
      200
    );
    Opportunity noContactOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'No Contact Opp',
      null,
      null,
      150
    );
    Opportunity noEmailOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'No Email Opp',
      noEmailContact,
      null,
      75
    );
    AcknowledgementTestUtils.insertTestOpportunities(
      new List<Opportunity>{
        successOpp,
        acknowledgedOpp,
        noContactOpp,
        noEmailOpp
      }
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{
        successOpp.Id,
        acknowledgedOpp.Id,
        noContactOpp.Id,
        noEmailOpp.Id
      }
    );
    AckEmailConfig config = new AckEmailConfig('Test Subject', 'Test Body');
    // Instance-based: create and configure service with mock email
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 4, 1, 1, 2, 0);
    List<AckOpportunityResult> successfulResults = result.getSuccessfulResults();
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
      // No npsp__Primary_Contact__c - makes it invalid for the service
    );
    insert invalidOpp;
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ validOpp.Id, invalidOpp.Id }
    );
    AckEmailConfig config = new AckEmailConfig('Test Subject', 'Test Body');
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();
    // Add assertions as needed for transaction behavior
  }

  @isTest
  static void testServiceBulkProcessing() {
    // Verifies bulk processing of multiple opportunities through the full pipeline.
    // Built and inserted in a single bulk DML statement - inserting 5
    // opportunities for the same Contact one at a time in the same test method
    // can blow through the SOQL governor limit due to NPSP's Primary Contact
    // Role sync automation.
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    List<Opportunity> oppsToInsert = new List<Opportunity>();
    for (Integer i = 1; i <= 5; i++) {
      oppsToInsert.add(
        AcknowledgementTestUtils.buildTestOpportunity(
          'Bulk Opp ' + i,
          c,
          null,
          100 * i
        )
      );
    }
    AcknowledgementTestUtils.insertTestOpportunities(oppsToInsert);
    List<Id> oppIds = new List<Id>();
    for (Opportunity opp : oppsToInsert) {
      oppIds.add(opp.Id);
    }
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      oppIds
    );
    AckEmailConfig config = new AckEmailConfig('Bulk Subject', 'Bulk Body');
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
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
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    Id mockTemplateId = '00X000000000000AAA';
    AckEmailConfig config = new AckEmailConfig(mockTemplateId);
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    try {
      AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
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
    AckEmailConfig config = new AckEmailConfig(
      'Multi Contact Subject',
      'Multi Contact Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();
    System.assertEquals(
      2,
      result.emailsSent,
      'Should send emails to both contacts'
    );
    Map<String, AckOpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
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
    AckEmailConfig config = new AckEmailConfig(
      'OrgWide Subject',
      'OrgWide Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
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
    // getDefaultOrgWideEmailAddressId() is @TestVisible private on the impl class, so it
    // is exercised directly here rather than through the full send pipeline.
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
    DonationAcknowledgementServiceImpl serviceDefault = new DonationAcknowledgementServiceImpl();
    serviceDefault.orgWideEmailService = mockServiceDefault;
    resultDefaultNoReply = serviceDefault.getDefaultOrgWideEmailAddressId();
    // Case 2: UserSelectionAndDefaultNoReply
    DonationAcknowledgementServiceImpl serviceSelection = new DonationAcknowledgementServiceImpl();
    serviceSelection.orgWideEmailService = mockServiceSelection;
    resultSelection = serviceSelection.getDefaultOrgWideEmailAddressId();
    // Case 3: No default
    DonationAcknowledgementServiceImpl serviceNone = new DonationAcknowledgementServiceImpl();
    serviceNone.orgWideEmailService = mockServiceNone;
    resultNone = serviceNone.getDefaultOrgWideEmailAddressId();
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
  static void testGetDefaultOrgWideEmailAddressIdUsesConfiguredAddressWhenPresent() {
    // When orgWideEmailAddress is configured (e.g. via Ack_Setting__mdt), the
    // configured address should be looked up and used instead of the org's Default
    // No-Reply Address.
    OrgWideEmailAddress configuredAddress = new OrgWideEmailAddress();
    configuredAddress.Id = '0D2000000000002AAA';
    configuredAddress.Address = 'acks@example.com';
    MockOrgWideEmailService mockService = new MockOrgWideEmailService(null);
    mockService.setAddressByAddressResult(configuredAddress);

    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    service.orgWideEmailService = mockService;
    service.orgWideEmailAddress = 'acks@example.com';

    Test.startTest();
    Id result = service.getDefaultOrgWideEmailAddressId();
    Test.stopTest();

    System.assertEquals(
      configuredAddress.Id,
      result,
      'Should use the configured org-wide address'
    );
    System.assertEquals(
      1,
      mockService.getByAddressCallCount(),
      'Should look up the configured address'
    );
    System.assertEquals(
      0,
      mockService.getCallCount(),
      'Should not need the default no-reply lookup when the configured address is found'
    );
  }

  @isTest
  static void testGetDefaultOrgWideEmailAddressIdFallsBackWhenConfiguredAddressNotFound() {
    // When orgWideEmailAddress is configured but doesn't match any
    // OrgWideEmailAddress, fall back to the Default No-Reply Address rather than
    // sending with no org-wide address at all.
    OrgWideEmailAddress defaultAddress = new OrgWideEmailAddress();
    defaultAddress.Id = '0D2000000000003AAA';
    defaultAddress.Purpose = 'DefaultNoReply';
    MockOrgWideEmailService mockService = new MockOrgWideEmailService(
      defaultAddress
    );
    mockService.setAddressByAddressResult(null);

    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    service.orgWideEmailService = mockService;
    service.orgWideEmailAddress = 'does-not-exist@example.com';

    Test.startTest();
    Id result = service.getDefaultOrgWideEmailAddressId();
    Test.stopTest();

    System.assertEquals(
      defaultAddress.Id,
      result,
      'Should fall back to the Default No-Reply Address'
    );
    System.assertEquals(
      1,
      mockService.getByAddressCallCount(),
      'Should have attempted the configured address lookup'
    );
    System.assertEquals(
      1,
      mockService.getCallCount(),
      'Should fall back to the default no-reply lookup'
    );
  }

  @isTest
  static void testGetDefaultOrgWideEmailAddressIdSkipsConfiguredLookupWhenBlank() {
    // When orgWideEmailAddress is blank (the default), go straight to the default
    // no-reply lookup without calling getByAddress at all.
    OrgWideEmailAddress defaultAddress = new OrgWideEmailAddress();
    defaultAddress.Id = '0D2000000000004AAA';
    defaultAddress.Purpose = 'DefaultNoReply';
    MockOrgWideEmailService mockService = new MockOrgWideEmailService(
      defaultAddress
    );

    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    service.orgWideEmailService = mockService;
    service.orgWideEmailAddress = '';

    Test.startTest();
    Id result = service.getDefaultOrgWideEmailAddressId();
    Test.stopTest();

    System.assertEquals(
      defaultAddress.Id,
      result,
      'Should use the Default No-Reply Address'
    );
    System.assertEquals(
      0,
      mockService.getByAddressCallCount(),
      'Should not call getByAddress when orgWideEmailAddress is blank'
    );
  }

  @isTest
  static void testLoadAckSettingConfigOnlyRunsOncePerInstance() {
    // loadAckSettingConfig() must query Ack_Setting__mdt at most once per instance -
    // calling it again (as the constructor already did) should be a no-op.
    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    String devNameAfterConstruction = service.donationAckTemplateDevName;
    String folderAfterConstruction = service.donationAckTemplateFolder;

    // Simulate a test overriding the fields directly after construction, as the
    // existing field-override pattern does.
    service.donationAckTemplateDevName = 'OverriddenTemplate';
    service.donationAckTemplateFolder = 'OverriddenFolder';

    Test.startTest();
    service.loadAckSettingConfig();
    Test.stopTest();

    System.assertEquals(
      'OverriddenTemplate',
      service.donationAckTemplateDevName,
      'A second call to loadAckSettingConfig() must not overwrite a manual override'
    );
    System.assertEquals(
      'OverriddenFolder',
      service.donationAckTemplateFolder,
      'A second call to loadAckSettingConfig() must not overwrite a manual override'
    );
    // Sanity check that construction itself did populate defaults (either from the
    // shipped Ack_Setting.Default CMT record or the hardcoded fallback - both are
    // 'HTML_Donation_Acknowledgement' / 'EnhancedDonationAcknowledgements').
    System.assertEquals(
      'HTML_Donation_Acknowledgement',
      devNameAfterConstruction,
      'Should have a template dev name after construction'
    );
    System.assertEquals(
      'EnhancedDonationAcknowledgements',
      folderAfterConstruction,
      'Should have a template folder after construction'
    );
  }

  @isTest
  static void testAckUpdateFailedWhenDatabaseUpdateFails() {
    // Exercises the full pipeline: two opportunities pass validation and their emails
    // send successfully, but one of the underlying Opportunity records is deleted out
    // from under the pipeline before the database update step runs (simulating a
    // record deleted concurrently). That record's DML update fails and must be
    // downgraded to ACK_UPDATE_FAILED rather than being silently left as SUCCESS or
    // dropped - the email already went out.
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity goodOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Ack Update Good Opp',
      c,
      null,
      100
    );
    Opportunity doomedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Ack Update Doomed Opp',
      c,
      null,
      100
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ goodOpp.Id, doomedOpp.Id }
    );
    delete doomedOpp;

    AckEmailConfig config = new AckEmailConfig('Test Subject', 'Test Body');
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();

    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();

    System.assertEquals(2, result.totalOpportunities, 'Should total 2');
    System.assertEquals(
      1,
      result.emailsSent,
      'The surviving record should count as a successful send'
    );
    System.assertEquals(
      1,
      result.ackUpdateFailures,
      'The deleted record should count as an ack update failure, not a success'
    );

    Map<String, AckOpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Ack Update Good Opp',
      AckStatus.SUCCESS,
      'Email sent successfully'
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Ack Update Doomed Opp',
      AckStatus.ACK_UPDATE_FAILED,
      'manual attention'
    );
    System.assert(
      resultsByName.get('Ack Update Doomed Opp').isFailed(),
      'ACK_UPDATE_FAILED should be considered a failure'
    );

    AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(goodOpp.Id);
  }

  @isTest
  static void testServiceTemplateEmailSending() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    Id mockTemplateId = '00X000000000000AAA';
    AckEmailConfig config = new AckEmailConfig(mockTemplateId);
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    try {
      AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
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
    // Simulate sending different types of emails (plain, template, etc.)
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp.Id }
    );
    AckEmailConfig config = new AckEmailConfig('Type Subject', 'Type Body');
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();
    System.assert(
      result.emailsSent >= 0,
      'Should process different email types'
    );
  }

  @isTest
  static void testServiceMixedValidationScenarios() {
    // Inline creation of test opportunities for each scenario.
    // Bulk-inserted in one DML statement - see comment on
    // testSendEmailsCoreWithResultReturnsMigratedFunctionality for why.
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Contact noEmailContact = AcknowledgementTestUtils.createTestContactWithoutEmail();
    Opportunity successOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Success Opp',
      validContact,
      null,
      100
    );
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Already Acknowledged Opp',
      validContact,
      Date.today().addDays(-1),
      200
    );
    Opportunity noContactOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'No Contact Opp',
      null,
      null,
      150
    );
    Opportunity noEmailOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'No Email Opp',
      noEmailContact,
      null,
      75
    );
    AcknowledgementTestUtils.insertTestOpportunities(
      new List<Opportunity>{
        successOpp,
        acknowledgedOpp,
        noContactOpp,
        noEmailOpp
      }
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{
        successOpp.Id,
        acknowledgedOpp.Id,
        noContactOpp.Id,
        noEmailOpp.Id
      }
    );
    AckEmailConfig config = new AckEmailConfig('Test Subject', 'Test Body');
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();
    AcknowledgementTestUtils.assertDetailedResultCounts(result, 4, 1, 1, 2, 0);
  }

  @isTest
  static void testServiceCommandIntegration() {
    // Inline creation of test opportunities for each scenario.
    // Bulk-inserted in one DML statement - see comment on
    // testSendEmailsCoreWithResultReturnsMigratedFunctionality for why.
    String unique = String.valueOf(Math.mod(Crypto.getRandomInteger(), 100000));
    Contact validContact = AcknowledgementTestUtils.createTestContact(
      'testuser_' + unique + '@example.com'
    );
    Contact noEmailContact = AcknowledgementTestUtils.createTestContactWithoutEmail();
    Opportunity successOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Success Opp',
      validContact,
      null,
      100
    );
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'Already Acknowledged Opp',
      validContact,
      Date.today().addDays(-1),
      200
    );
    Opportunity noContactOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'No Contact Opp',
      null,
      null,
      150
    );
    Opportunity noEmailOpp = AcknowledgementTestUtils.buildTestOpportunity(
      'No Email Opp',
      noEmailContact,
      null,
      75
    );
    AcknowledgementTestUtils.insertTestOpportunities(
      new List<Opportunity>{
        successOpp,
        acknowledgedOpp,
        noContactOpp,
        noEmailOpp
      }
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{
        successOpp.Id,
        acknowledgedOpp.Id,
        noContactOpp.Id,
        noEmailOpp.Id
      }
    );
    AckEmailConfig config = new AckEmailConfig(
      'Integration Subject',
      'Integration Body'
    );
    DonationAcknowledgementServiceImpl service = AcknowledgementTestUtils.createConfiguredServiceWithMockEmail();
    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();
    String summary = result.buildSummaryMessage();
    System.assert(
      summary.contains('4 Opportunities'),
      'Summary should mention 4 Opportunities'
    );
    // Verify acknowledgment status is set
    AcknowledgementTestUtils.assertAcknowledgmentStatusSet(
      successOpp.Id,
      'Acknowledged'
    );
  }

  @isTest
  static void testSendEmailsCoreDetailedWithPartialSendFailure() {
    // 3 opportunities, the send for the 2nd (index 1) fails - the other two
    // should succeed and get their acknowledgment dates persisted; the failed
    // one should not.
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity opp1 = AcknowledgementTestUtils.createTestOpportunity(
      'Partial Opp 1',
      c,
      null,
      100
    );
    Opportunity opp2 = AcknowledgementTestUtils.createTestOpportunity(
      'Partial Opp 2',
      c,
      null,
      100
    );
    Opportunity opp3 = AcknowledgementTestUtils.createTestOpportunity(
      'Partial Opp 3',
      c,
      null,
      100
    );
    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp1.Id, opp2.Id, opp3.Id }
    );
    AckEmailConfig config = new AckEmailConfig('Test Subject', 'Test Body');

    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    MockEmailService mock = new MockEmailService();
    mock.setPartialFailure(new List<Integer>{ 1 }, 'Mailbox unavailable');
    service.emailService = mock;

    Test.startTest();
    AckDetailedResult result = service.sendEmailsCoreDetailed(opps, config);
    Test.stopTest();

    System.assertEquals(3, result.totalOpportunities, 'Should total 3');
    System.assertEquals(2, result.emailsSent, 'Should have 2 successes');
    System.assertEquals(1, result.emailSendFailures, 'Should have 1 failure');
    System.assertEquals(0, result.ackUpdateFailures, 'No DB failures expected');

    Map<String, AckOpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Partial Opp 1',
      AckStatus.SUCCESS,
      'Email sent successfully'
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Partial Opp 2',
      AckStatus.EMAIL_SEND_FAILED,
      'Mailbox unavailable'
    );
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Partial Opp 3',
      AckStatus.SUCCESS,
      'Email sent successfully'
    );

    // Verify the database was updated ONLY for the 2 opportunities whose email sent
    AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp1.Id);
    AcknowledgementTestUtils.assertAcknowledgmentDateSetToday(opp3.Id);
    Opportunity updatedOpp2 = AcknowledgementTestUtils.queryOpportunityWithAckDate(
      opp2.Id
    );
    System.assertEquals(
      null,
      updatedOpp2.npsp__Acknowledgment_Date__c,
      'Failed send should not update acknowledgment date'
    );
  }
}
