/**
 * Test class for OpportunityValidationCommand
 * Tests opportunity validation logic, filtering, and error handling
 */
@isTest
private class OpportunityValidationCommandTest {
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

  /**
   * NOTE: This test class was refactored as part of the test responsibility plan.
   * See docs/test-refactoring-plan.md for details on which methods were moved or removed.
   */

  @isTest
  static void testValidateOpportunitiesWithValidOpportunity() {
    // Test validation with a valid opportunity
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity validOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Valid Opp',
      c,
      null, // No acknowledgment date
      100
    );

    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ validOpp.Id }
    );

    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    Test.startTest();
    OpportunityValidationCommand validationCmd = new OpportunityValidationCommand(
      opps,
      result
    );
    validationCmd.execute();
    List<Opportunity> validOpps = validationCmd.getValidOpportunities();
    Test.stopTest();

    // Verify valid opportunity is returned
    System.assertEquals(1, validOpps.size(), 'Should have 1 valid opportunity');
    System.assertEquals(
      validOpp.Id,
      validOpps[0].Id,
      'Should be the valid opportunity'
    );

    // Verify no skipped opportunities added to result
    System.assertEquals(
      0,
      result.opportunityResults.size(),
      'Should have no skipped results'
    );
  }

  @isTest
  static void testValidateOpportunitiesWithAlreadyAcknowledged() {
    // Test validation with already acknowledged opportunity
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Already Acknowledged Opp',
      c,
      Date.today().addDays(-1), // Already acknowledged
      200
    );

    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ acknowledgedOpp.Id }
    );

    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    Test.startTest();
    OpportunityValidationCommand validationCmd = new OpportunityValidationCommand(
      opps,
      result
    );
    validationCmd.execute();
    List<Opportunity> validOpps = validationCmd.getValidOpportunities();
    Test.stopTest();

    // Verify no valid opportunities returned
    System.assertEquals(
      0,
      validOpps.size(),
      'Should have no valid opportunities'
    );

    // Verify skipped opportunity added to result
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 skipped result'
    );
    DonationAcknowledgementService.OpportunityResult oppResult = result.opportunityResults[0];
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      oppResult.status,
      'Should be already acknowledged'
    );
    System.assert(
      oppResult.reason.contains('already acknowledged'),
      'Reason should mention already acknowledged'
    );
  }

  @isTest
  static void testValidateOpportunitiesWithNoContact() {
    // Test validation with opportunity that has no contact
    Opportunity noContactOpp = AcknowledgementTestUtils.createTestOpportunity(
      'No Contact Opp',
      null, // No contact
      null,
      150
    );

    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ noContactOpp.Id }
    );

    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    Test.startTest();
    OpportunityValidationCommand validationCmd = new OpportunityValidationCommand(
      opps,
      result
    );
    validationCmd.execute();
    List<Opportunity> validOpps = validationCmd.getValidOpportunities();
    Test.stopTest();

    // Verify no valid opportunities returned
    System.assertEquals(
      0,
      validOpps.size(),
      'Should have no valid opportunities'
    );

    // Verify skipped opportunity added to result
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 skipped result'
    );
    DonationAcknowledgementService.OpportunityResult oppResult = result.opportunityResults[0];
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.NO_CONTACT,
      oppResult.status,
      'Should be no contact'
    );
    System.assert(
      oppResult.reason.contains('no associated Contact'),
      'Reason should mention no contact'
    );
  }

  @isTest
  static void testValidateOpportunitiesWithNoEmail() {
    // Test validation with contact that has no email
    Contact noEmailContact = AcknowledgementTestUtils.createTestContactWithoutEmail();
    Opportunity noEmailOpp = AcknowledgementTestUtils.createTestOpportunity(
      'No Email Opp',
      noEmailContact,
      null,
      175
    );

    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ noEmailOpp.Id }
    );

    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    Test.startTest();
    OpportunityValidationCommand validationCmd = new OpportunityValidationCommand(
      opps,
      result
    );
    validationCmd.execute();
    List<Opportunity> validOpps = validationCmd.getValidOpportunities();
    Test.stopTest();

    // Verify no valid opportunities returned
    System.assertEquals(
      0,
      validOpps.size(),
      'Should have no valid opportunities'
    );

    // Verify skipped opportunity added to result
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 skipped result'
    );
    DonationAcknowledgementService.OpportunityResult oppResult = result.opportunityResults[0];
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.NO_EMAIL,
      oppResult.status,
      'Should be no email'
    );
    System.assert(
      oppResult.reason.contains('no email address'),
      'Reason should mention no email'
    );
  }

  @isTest
  static void testValidateOpportunitiesEmptyList() {
    // Test validation with empty opportunity list
    List<Opportunity> emptyOpps = new List<Opportunity>();
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    Test.startTest();
    OpportunityValidationCommand validationCmd = new OpportunityValidationCommand(
      emptyOpps,
      result
    );
    validationCmd.execute();
    List<Opportunity> validOpps = validationCmd.getValidOpportunities();
    Test.stopTest();

    // Verify empty results
    System.assertEquals(
      0,
      validOpps.size(),
      'Should have no valid opportunities'
    );
    System.assertEquals(
      0,
      result.opportunityResults.size(),
      'Should have no skipped results'
    );
  }

  @isTest
  static void testValidateOpportunitiesAcknowledgmentStatusUpdate() {
    // Test validation with acknowledgment date set (should be skipped as already acknowledged)
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    Opportunity acknowledgedOpp = AcknowledgementTestUtils.createTestOpportunity(
      'Acknowledged Opp',
      c,
      Date.today(), // Acknowledgment date set
      250
    );

    List<Opportunity> opps = AcknowledgementTestUtils.queryOpportunitiesFullFields(
      new List<Id>{ acknowledgedOpp.Id }
    );

    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    Test.startTest();
    OpportunityValidationCommand validationCmd = new OpportunityValidationCommand(
      opps,
      result
    );
    validationCmd.execute();
    List<Opportunity> validOpps = validationCmd.getValidOpportunities();
    Test.stopTest();

    // Verify no valid opportunities (already acknowledged should be skipped)
    System.assertEquals(
      0,
      validOpps.size(),
      'Should have 0 valid opportunities since it is already acknowledged'
    );

    // Verify the opportunity was marked as already acknowledged in the results
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 opportunity result'
    );
    DonationAcknowledgementService.OpportunityResult oppResult = result.opportunityResults[0];
    System.assertEquals(
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      oppResult.status,
      'Status should be ALREADY_ACKNOWLEDGED'
    );
    System.assertEquals(
      acknowledgedOpp.Id,
      oppResult.opportunityId,
      'Should be the acknowledged opportunity'
    );

    // Verify acknowledgment status remains set (no change needed as it's already acknowledged)
  }

  // The following test methods were moved to DonationAcknowledgementServiceImplTest as part of the test refactoring plan:
  // - testValidateOpportunitiesMixedScenarios
  // - testValidateOpportunitiesBulkProcessing
}
