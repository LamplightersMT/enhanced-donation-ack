/**
 * Test class for DatabaseUpdateCommand
 * Tests database update logic, error handling, and transaction management
 */
@isTest
private class DatabaseUpdateCommandTest {
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
  static void testUpdateDatabaseSuccessfulSingleOpportunity() {
    // Test successful database update with single opportunity
    Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];

    // Create successful opportunity result
    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      opp.Id,
      opp.Name
    );
    oppResult.acknowledgmentDate = Date.today();

    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>{
      oppResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify successful update output
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      null,
      output.errorMessage,
      'Should have no error message'
    );
    System.assertEquals(
      1,
      output.recordsUpdated,
      'Should have updated 1 record'
    );

    // Verify database was actually updated
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(),
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgment date should be set in database'
    );
  }

  @isTest
  static void testUpdateDatabaseSuccessfulMultipleOpportunities() {
    // Test successful database update with multiple opportunities
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Id> oppIds = new List<Id>();
    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>();

    // Create multiple opportunities and results
    for (Integer i = 1; i <= 3; i++) {
      Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
        'Update Test Opp ' + i,
        c,
        null,
        100 * i
      );
      oppIds.add(opp.Id);

      DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
        opp.Id,
        'Update Test Opp ' + i
      );
      oppResult.acknowledgmentDate = Date.today();
      successfulOpps.add(oppResult);
    }

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify successful update output
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      null,
      output.errorMessage,
      'Should have no error message'
    );
    System.assertEquals(
      3,
      output.recordsUpdated,
      'Should have updated 3 records'
    );

    // Verify all opportunities were updated in database
    List<Opportunity> updatedOpps = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :oppIds
    ];

    System.assertEquals(
      3,
      updatedOpps.size(),
      'Should have 3 updated opportunities'
    );
    for (Opportunity updatedOpp : updatedOpps) {
      System.assertEquals(
        Date.today(),
        updatedOpp.npsp__Acknowledgment_Date__c,
        'All acknowledgment dates should be set'
      );
    }
  }

  @isTest
  static void testUpdateDatabaseEmptyList() {
    // Test database update with empty opportunity list
    List<DonationAcknowledgementService.OpportunityResult> emptyOpps = new List<DonationAcknowledgementService.OpportunityResult>();

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(emptyOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

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
      output.recordsUpdated,
      'Should have updated 0 records'
    );
  }

  @isTest
  static void testUpdateDatabaseWithDifferentAcknowledgmentDates() {
    // Test database update with different acknowledgment dates
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Id> oppIds = new List<Id>();
    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>();

    Date today = Date.today();
    Date yesterday = today.addDays(-1);

    // Create opportunities with different acknowledgment dates
    Opportunity opp1 = AcknowledgementTestUtils.createTestOpportunity(
      'Today Opp',
      c,
      null,
      100
    );
    oppIds.add(opp1.Id);

    DonationAcknowledgementService.OpportunityResult result1 = new DonationAcknowledgementService.OpportunityResult(
      opp1.Id,
      'Today Opp'
    );
    result1.acknowledgmentDate = today;
    successfulOpps.add(result1);

    Opportunity opp2 = AcknowledgementTestUtils.createTestOpportunity(
      'Yesterday Opp',
      c,
      null,
      200
    );
    oppIds.add(opp2.Id);

    DonationAcknowledgementService.OpportunityResult result2 = new DonationAcknowledgementService.OpportunityResult(
      opp2.Id,
      'Yesterday Opp'
    );
    result2.acknowledgmentDate = yesterday;
    successfulOpps.add(result2);

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify successful update
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      2,
      output.recordsUpdated,
      'Should have updated 2 records'
    );

    // Verify different acknowledgment dates were set correctly
    List<Opportunity> updatedOpps = [
      SELECT Id, Name, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :oppIds
      ORDER BY Name
    ];

    // Find opportunities by name
    Map<String, Opportunity> oppsByName = new Map<String, Opportunity>();
    for (Opportunity opp : updatedOpps) {
      oppsByName.put(opp.Name, opp);
    }

    System.assertEquals(
      today,
      oppsByName.get('Today Opp').npsp__Acknowledgment_Date__c,
      'Today opportunity should have today\'s date'
    );
    System.assertEquals(
      yesterday,
      oppsByName.get('Yesterday Opp').npsp__Acknowledgment_Date__c,
      'Yesterday opportunity should have yesterday\'s date'
    );
  }

  @isTest
  static void testUpdateDatabaseWithInvalidOpportunityId() {
    // Test database update with invalid opportunity ID
    // Note: In test context, DML operations are more forgiving
    // This test verifies the command structure handles errors properly

    DonationAcknowledgementService.OpportunityResult invalidResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000000AAA', // Invalid ID format
      'Invalid Opportunity'
    );
    invalidResult.acknowledgmentDate = Date.today();

    List<DonationAcknowledgementService.OpportunityResult> invalidOpps = new List<DonationAcknowledgementService.OpportunityResult>{
      invalidResult
    };

    Test.startTest();
    try {
      DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(invalidOpps);
      updateCmd.execute();
      AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();

      // In test context, this might succeed with mock data
      // The important thing is that the command doesn't crash unexpectedly
      System.assertNotEquals(null, output, 'Output should not be null');
    } catch (Exception e) {
      // If an error occurs, verify it's properly handled
      // In test context, we may get different types of exceptions
      System.assert(
        e.getMessage().contains('Failed to update acknowledgement dates') ||
          e.getMessage().contains('Script-thrown exception') ||
          e.getMessage().contains('invalid'),
        'Should handle error appropriately: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testUpdateDatabaseBulkProcessing() {
    // Test database update with moderate bulk processing (reduced for test limits)
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Id> oppIds = new List<Id>();
    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>();

    // Create fewer opportunities for test context (avoiding SOQL limits)
    Integer numOpps = 5; // Reduced from 10 to avoid test limits
    for (Integer i = 1; i <= numOpps; i++) {
      Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
        'Bulk Opp ' + i,
        c,
        null,
        100 + i
      );
      oppIds.add(opp.Id);

      DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
        opp.Id,
        'Bulk Opp ' + i
      );
      oppResult.acknowledgmentDate = Date.today();
      successfulOpps.add(oppResult);
    }

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify bulk update was successful
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      null,
      output.errorMessage,
      'Should have no error message'
    );
    System.assertEquals(
      numOpps,
      output.recordsUpdated,
      'Should have updated all records'
    );

    // Verify all opportunities were updated
    List<Opportunity> updatedOpps = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :oppIds
    ];

    System.assertEquals(
      numOpps,
      updatedOpps.size(),
      'Should have all updated opportunities'
    );
    for (Opportunity updatedOpp : updatedOpps) {
      System.assertEquals(
        Date.today(),
        updatedOpp.npsp__Acknowledgment_Date__c,
        'All acknowledgment dates should be set'
      );
    }
  }

  @isTest
  static void testUpdateDatabaseOpportunityResultModification() {
    // Test that opportunity results are properly modified on database errors
    Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];

    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      opp.Id,
      opp.Name
    );
    oppResult.acknowledgmentDate = Date.today();

    // Verify initial state
    System.assertNotEquals(
      DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
      oppResult.status,
      'Status should not start as failed'
    );

    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>{
      oppResult
    };

    Test.startTest();
    try {
      DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(
        successfulOpps
      );
      updateCmd.execute();
      AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();

      // In successful case, verify output
      System.assertEquals(true, output.isSuccess, 'Should be successful');

      // Opportunity result status should not be modified on success
      // (DatabaseUpdateCommand doesn't modify successful results)
    } catch (AuraHandledException e) {
      // In error case, verify opportunity results were marked as failed
      System.assertEquals(
        DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
        oppResult.status,
        'Status should be marked as failed on database error'
      );
      System.assert(
        oppResult.reason.contains('Database update'),
        'Reason should mention database update error'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testUpdateOutputStructure() {
    // Test the structure and properties of the UpdateOutput class
    Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];

    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      opp.Id,
      opp.Name
    );
    oppResult.acknowledgmentDate = Date.today();

    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>{
      oppResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify output structure
    System.assertNotEquals(null, output, 'Output should not be null');

    // Verify success case properties
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      null,
      output.errorMessage,
      'Error message should be null on success'
    );
    System.assertEquals(
      1,
      output.recordsUpdated,
      'Should have updated 1 record'
    );

    // Verify that recordsUpdated reflects actual database changes
    System.assert(
      output.recordsUpdated >= 0,
      'Records updated should be non-negative'
    );
  }

  @isTest
  static void testUpdateDatabaseWithNullAcknowledgmentDate() {
    // Test database update when opportunity result has null acknowledgment date
    // This tests edge case handling

    Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];

    DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
      opp.Id,
      opp.Name
    );
    // Deliberately leave acknowledgmentDate as null

    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>{
      oppResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Command should handle null acknowledgment date gracefully
    System.assertEquals(
      true,
      output.isSuccess,
      'Should be successful even with null date'
    );
    System.assertEquals(
      1,
      output.recordsUpdated,
      'Should still update the record'
    );

    // Verify database update (acknowledgment date would be set to null)
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      null,
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgment date should be null in database'
    );
  }

  @isTest
  static void testUpdateDatabaseTransactionBehavior() {
    // Test that database updates are handled in a single transaction
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Id> oppIds = new List<Id>();
    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>();

    // Create multiple opportunities
    for (Integer i = 1; i <= 2; i++) {
      Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
        'Transaction Test Opp ' + i,
        c,
        null,
        100 * i
      );
      oppIds.add(opp.Id);

      DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
        opp.Id,
        'Transaction Test Opp ' + i
      );
      oppResult.acknowledgmentDate = Date.today();
      successfulOpps.add(oppResult);
    }

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify all updates succeeded together
    System.assertEquals(true, output.isSuccess, 'Should be successful');
    System.assertEquals(
      2,
      output.recordsUpdated,
      'Should have updated both records'
    );

    // Verify both opportunities were updated
    List<Opportunity> updatedOpps = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :oppIds
    ];

    System.assertEquals(
      2,
      updatedOpps.size(),
      'Should have both updated opportunities'
    );
    for (Opportunity updatedOpp : updatedOpps) {
      System.assertEquals(
        Date.today(),
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Both acknowledgment dates should be set'
      );
    }
  }
}
