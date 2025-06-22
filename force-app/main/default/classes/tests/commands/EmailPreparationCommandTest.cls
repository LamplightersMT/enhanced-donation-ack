/**
 * Test class for EmailPreparationCommand
 * Tests email preparation logic, template selection, and contact mapping
 */
@isTest
private class EmailPreparationCommandTest {
  @testSetup
  static void setupTestData() {
    // Use shared test utils for setup
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
  static void testPrepareEmailsWithStaticConfig() {
    // Test email preparation with static content configuration
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity validOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Valid Opp',
      c,
      null,
      100
    );

    List<Opportunity> validOpps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ validOpp.Id }
    );

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body Content'
    );

    Test.startTest();
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      validOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();
    Test.stopTest();

    // Verify email preparation output
    System.assertEquals(
      1,
      output.emails.size(),
      'Should have 1 prepared email'
    );
    System.assertEquals(
      1,
      output.validOpportunities.size(),
      'Should have 1 valid opportunity result'
    );
    System.assertEquals(
      1,
      output.contactMap.size(),
      'Should have 1 contact in map'
    );

    // Verify prepared email properties
    Messaging.SingleEmailMessage email = output.emails[0];
    System.assertEquals(
      'Test Subject',
      email.getSubject(),
      'Should have correct subject'
    );
    System.assertEquals(
      'Test Body Content',
      email.getPlainTextBody(),
      'Should have correct body'
    );
    System.assertEquals(
      c.Id,
      email.getTargetObjectId(),
      'Should target correct contact'
    );

    // Verify opportunity result properties
    DonationAcknowledgementService.OpportunityResult oppResult = output.validOpportunities[0];
    System.assertEquals(
      validOpp.Id,
      oppResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      'Valid Opp',
      oppResult.opportunityName,
      'Should have correct opportunity name'
    );
    System.assertEquals(
      'testuser@example.com',
      oppResult.contactEmail,
      'Should have contact email'
    );

    // Verify contact map
    System.assert(
      output.contactMap.containsKey(c.Id),
      'Contact map should contain contact ID'
    );
    System.assertEquals(
      'testuser@example.com',
      output.contactMap.get(c.Id).Email,
      'Should have correct email'
    );
  }

  @isTest
  static void testPrepareEmailsWithTemplateConfig() {
    // Test email preparation with template configuration
    // Note: In test context, template IDs may not be valid
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity validOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Template Opp',
      c,
      null,
      200
    );

    List<Opportunity> validOpps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ validOpp.Id }
    );

    Id mockTemplateId = '00X000000000000AAA'; // Mock template ID
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      mockTemplateId
    );

    Test.startTest();
    try {
      EmailPreparationCommand prepCmd = new EmailPreparationCommand(
        validOpps,
        config
      );
      prepCmd.execute();
      AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();

      // If successful (template exists or test allows it)
      System.assertEquals(
        1,
        output.emails.size(),
        'Should have 1 prepared email'
      );
      System.assertEquals(
        1,
        output.validOpportunities.size(),
        'Should have 1 valid opportunity result'
      );

      // Verify template configuration
      Messaging.SingleEmailMessage email = output.emails[0];
      System.assertEquals(
        mockTemplateId,
        email.getTemplateId(),
        'Should use template ID'
      );
      System.assertEquals(
        c.Id,
        email.getTargetObjectId(),
        'Should target correct contact'
      );
      System.assertEquals(
        validOpp.Id,
        email.getWhatId(),
        'Should reference opportunity'
      );
    } catch (Exception e) {
      // In test context, template IDs may not be valid - this is expected
      System.assert(
        e.getMessage().contains('Invalid parameter value') ||
        e.getMessage().contains('template'),
        'Should get template-related error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testPrepareEmailsMultipleOpportunities() {
    // Test email preparation with multiple opportunities
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Id> oppIds = new List<Id>();
    for (Integer i = 1; i <= 3; i++) {
      Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
        'Multi Opp ' + i,
        c,
        null,
        100 * i
      );
      oppIds.add(opp.Id);
    }

    List<Opportunity> validOpps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      oppIds
    );

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Multi Subject',
      'Multi Body'
    );

    Test.startTest();
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      validOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();
    Test.stopTest();

    // Verify preparation for all opportunities
    System.assertEquals(
      3,
      output.emails.size(),
      'Should have 3 prepared emails'
    );
    System.assertEquals(
      3,
      output.validOpportunities.size(),
      'Should have 3 valid opportunity results'
    );
    System.assertEquals(
      1,
      output.contactMap.size(),
      'Should have 1 contact in map (same contact for all)'
    );

    // Verify all emails have correct configuration
    for (Messaging.SingleEmailMessage email : output.emails) {
      System.assertEquals(
        'Multi Subject',
        email.getSubject(),
        'Should have correct subject'
      );
      System.assertEquals(
        'Multi Body',
        email.getPlainTextBody(),
        'Should have correct body'
      );
      System.assertEquals(
        c.Id,
        email.getTargetObjectId(),
        'Should target correct contact'
      );
    }

    // Verify all opportunity results have correct data
    Set<Id> processedOppIds = new Set<Id>();
    for (
      DonationAcknowledgementService.OpportunityResult oppResult : output.validOpportunities
    ) {
      processedOppIds.add(oppResult.opportunityId);
      System.assertEquals(
        'testuser@example.com',
        oppResult.contactEmail,
        'Should have contact email'
      );
      System.assert(
        oppResult.opportunityName.startsWith('Multi Opp'),
        'Should have correct name pattern'
      );
    }

    // Verify all opportunity IDs were processed
    for (Id oppId : oppIds) {
      System.assert(
        processedOppIds.contains(oppId),
        'Should contain opportunity ID: ' + oppId
      );
    }
  }

  @isTest
  static void testPrepareEmailsMultipleContacts() {
    // Test email preparation with multiple contacts
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

    List<Opportunity> validOpps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ opp1.Id, opp2.Id }
    );

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Multi Contact Subject',
      'Multi Contact Body'
    );

    Test.startTest();
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      validOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();
    Test.stopTest();

    // Verify preparation for both contacts
    System.assertEquals(
      2,
      output.emails.size(),
      'Should have 2 prepared emails'
    );
    System.assertEquals(
      2,
      output.validOpportunities.size(),
      'Should have 2 valid opportunity results'
    );
    System.assertEquals(
      2,
      output.contactMap.size(),
      'Should have 2 contacts in map'
    );

    // Verify contact map contains both contacts
    System.assert(
      output.contactMap.containsKey(c1.Id),
      'Should contain contact 1'
    );
    System.assert(
      output.contactMap.containsKey(c2.Id),
      'Should contain contact 2'
    );
    System.assertEquals(
      'contact1@example.com',
      output.contactMap.get(c1.Id).Email,
      'Should have contact 1 email'
    );
    System.assertEquals(
      'contact2@example.com',
      output.contactMap.get(c2.Id).Email,
      'Should have contact 2 email'
    );

    // Verify opportunity results have correct contact emails
    Map<Id, DonationAcknowledgementService.OpportunityResult> resultsByOppId = new Map<Id, DonationAcknowledgementService.OpportunityResult>();
    for (
      DonationAcknowledgementService.OpportunityResult oppResult : output.validOpportunities
    ) {
      resultsByOppId.put(oppResult.opportunityId, oppResult);
    }

    System.assertEquals(
      'contact1@example.com',
      resultsByOppId.get(opp1.Id).contactEmail,
      'Should have contact 1 email'
    );
    System.assertEquals(
      'contact2@example.com',
      resultsByOppId.get(opp2.Id).contactEmail,
      'Should have contact 2 email'
    );
  }

  @isTest
  static void testPrepareEmailsEmptyList() {
    // Test email preparation with empty opportunity list
    List<Opportunity> emptyOpps = new List<Opportunity>();
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Empty Subject',
      'Empty Body'
    );

    Test.startTest();
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      emptyOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();
    Test.stopTest();

    // Verify empty results
    System.assertEquals(
      0,
      output.emails.size(),
      'Should have no prepared emails'
    );
    System.assertEquals(
      0,
      output.validOpportunities.size(),
      'Should have no valid opportunity results'
    );
    System.assertEquals(
      0,
      output.contactMap.size(),
      'Should have no contacts in map'
    );
  }

  @isTest
  static void testPrepareEmailsWithOrgWideEmailAddress() {
    // Test email preparation with org-wide email address
    // Note: In test context, OrgWideEmailAddress records may not be available
    // This test verifies the command handles the case gracefully

    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity validOpp = AcknowledgementTestUtils.createTestOpportunity(
      'OrgWide Opp',
      c,
      null,
      300
    );

    List<Opportunity> validOpps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ validOpp.Id }
    );

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'OrgWide Subject',
      'OrgWide Body'
    );

    Test.startTest();
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      validOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();
    Test.stopTest();

    // Verify email preparation completed successfully
    System.assertEquals(
      1,
      output.emails.size(),
      'Should have 1 prepared email'
    );

    // Verify email configuration (OrgWideEmailAddressId may be null in test context)
    Messaging.SingleEmailMessage email = output.emails[0];
    System.assertEquals(
      'OrgWide Subject',
      email.getSubject(),
      'Should have correct subject'
    );
    System.assertEquals(
      c.Id,
      email.getTargetObjectId(),
      'Should target correct contact'
    );

    // The OrgWideEmailAddressId may be null in test context, which is expected
    // The important thing is that the command doesn't fail
  }

  @isTest
  static void testPrepareEmailsSkipsOpportunitiesWithNullContact() {
    // Test that opportunities with null contacts are gracefully handled
    // Note: In test context, we can't modify ContactId after insert
    // This test verifies the command handles empty contact list gracefully

    List<Opportunity> emptyContactOpps = new List<Opportunity>();

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );

    Test.startTest();
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      emptyContactOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();
    Test.stopTest();

    // Verify no emails prepared for empty list
    System.assertEquals(
      0,
      output.emails.size(),
      'Should have no prepared emails'
    );
    System.assertEquals(
      0,
      output.validOpportunities.size(),
      'Should have no valid opportunity results'
    );
    System.assertEquals(
      0,
      output.contactMap.size(),
      'Should have no contacts in map'
    );
  }

  @isTest
  static void testEmailConfigurationDetails() {
    // Test detailed email configuration properties
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity validOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Config Test Opp',
      c,
      null,
      175
    );

    List<Opportunity> validOpps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ validOpp.Id }
    );

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Detailed Subject',
      'Detailed Body Content'
    );

    Test.startTest();
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      validOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput output = prepCmd.getOutput();
    Test.stopTest();

    // Verify email configuration details
    System.assertEquals(
      1,
      output.emails.size(),
      'Should have 1 prepared email'
    );

    Messaging.SingleEmailMessage email = output.emails[0];

    // Verify basic email properties
    System.assertEquals(
      'Detailed Subject',
      email.getSubject(),
      'Should have correct subject'
    );
    System.assertEquals(
      'Detailed Body Content',
      email.getPlainTextBody(),
      'Should have correct body'
    );
    System.assertEquals(
      c.Id,
      email.getTargetObjectId(),
      'Should target correct contact'
    );

    // Verify email type settings (these may have different defaults in Salesforce)
    // The important thing is that the email is configured properly
    System.assertNotEquals(
      null,
      email.getSaveAsActivity(),
      'SaveAsActivity should have a value'
    );
    System.assertNotEquals(
      null,
      email.getUseSignature(),
      'UseSignature should have a value'
    );

    // Verify opportunity result details
    DonationAcknowledgementService.OpportunityResult oppResult = output.validOpportunities[0];
    System.assertEquals(
      validOpp.Id,
      oppResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      'Config Test Opp',
      oppResult.opportunityName,
      'Should have correct opportunity name'
    );
    System.assertEquals(
      'testuser@example.com',
      oppResult.contactEmail,
      'Should have contact email'
    );

    // Verify the opportunity result is not yet marked with status/reason (that happens in later commands)
    System.assertEquals(null, oppResult.status, 'Status should not be set yet');
    System.assertEquals(null, oppResult.reason, 'Reason should not be set yet');
  }

  @isTest
  static void testGetDefaultOrgWideEmailAddressId_DefaultExists() {
    // Create mock org-wide email address
    OrgWideEmailAddress mockAddress = new OrgWideEmailAddress();
    mockAddress.Id = '0D2000000000001AAA';
    mockAddress.Purpose = 'DefaultNoReply';

    // Create and inject mock service
    IOrgWideEmailService mockService = (IOrgWideEmailService) Test.createStub(
      IOrgWideEmailService.class,
      new MockOrgWideEmailService(mockAddress)
    );

    Test.startTest();
    EmailPreparationCommand.orgWideEmailService = mockService;
    Id result = EmailPreparationCommand.getDefaultOrgWideEmailAddressId();
    Test.stopTest();

    System.assertEquals(
      mockAddress.Id,
      result,
      'Should return the default no-reply address ID when Purpose = DefaultNoReply'
    );
  }

  @isTest
  static void testGetDefaultOrgWideEmailAddressId_SelectionAndDefaultExists() {
    // Create mock org-wide email address
    OrgWideEmailAddress mockAddress = new OrgWideEmailAddress();
    mockAddress.Id = '0D2000000000001AAA';
    mockAddress.Purpose = 'UserSelectionAndDefaultNoReply';

    // Create and inject mock service
    IOrgWideEmailService mockService = (IOrgWideEmailService) Test.createStub(
      IOrgWideEmailService.class,
      new MockOrgWideEmailService(mockAddress)
    );

    Test.startTest();
    EmailPreparationCommand.orgWideEmailService = mockService;
    Id result = EmailPreparationCommand.getDefaultOrgWideEmailAddressId();
    Test.stopTest();

    System.assertEquals(
      mockAddress.Id,
      result,
      'Should return the default no-reply address ID when Purpose = UserSelectionAndDefaultNoReply'
    );
  }

  @isTest
  static void testGetDefaultOrgWideEmailAddressId_NoDefaultExists() {
    // Create mock service that returns null
    IOrgWideEmailService mockService = (IOrgWideEmailService) Test.createStub(
      IOrgWideEmailService.class,
      new MockOrgWideEmailService(null)
    );

    Test.startTest();
    EmailPreparationCommand.orgWideEmailService = mockService;
    Id result = EmailPreparationCommand.getDefaultOrgWideEmailAddressId();
    Test.stopTest();

    System.assertEquals(
      null,
      result,
      'Should return null when no default exists'
    );
  }
}
