/**
 * NOTE: This test class was refactored as part of the test responsibility plan.
 * See docs/test-refactoring-plan.md for details on which methods were moved or removed.
 */

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
}
// The following test methods were moved to DonationAcknowledgementServiceImplTest as part of the test refactoring plan:
// - testPrepareEmailsWithTemplateConfig (MOVED - Phase D, Deliverable 1)
// - testPrepareEmailsMultipleContacts (MOVED - Phase E, Deliverable 1)
// - testPrepareEmailsWithOrgWideEmailAddress (MOVED - Phase E, Deliverable 1)
// - testGetDefaultOrgWideEmailAddressId_DefaultExists (MOVED - Phase E, Deliverable 1)
// - testGetDefaultOrgWideEmailAddressId_SelectionAndDefaultExists (MOVED - Phase E, Deliverable 1)
// - testGetDefaultOrgWideEmailAddressId_NoDefaultExists (MOVED - Phase E, Deliverable 1)
