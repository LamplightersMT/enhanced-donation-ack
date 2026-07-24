/**
 * Test class for DatabaseUpdateCommand
 * Tests database update logic, per-record partial-failure handling, and transaction management
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
    AckOpportunityResult oppResult = new AckOpportunityResult(opp.Id, opp.Name);
    oppResult.acknowledgmentDate = Date.today();

    List<AckOpportunityResult> successfulOpps = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify successful update output
    System.assertEquals(
      1,
      output.recordsUpdated,
      'Should have updated 1 record'
    );
    System.assertEquals(
      0,
      output.recordsFailed,
      'Should have 0 failed records'
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
    List<AckOpportunityResult> successfulOpps = new List<AckOpportunityResult>();

    // Create multiple opportunities and results
    for (Integer i = 1; i <= 3; i++) {
      Opportunity opp = AcknowledgementTestUtils.createTestOpportunity(
        'Update Test Opp ' + i,
        c,
        null,
        100 * i
      );
      oppIds.add(opp.Id);

      AckOpportunityResult oppResult = new AckOpportunityResult(
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
    System.assertEquals(
      3,
      output.recordsUpdated,
      'Should have updated 3 records'
    );
    System.assertEquals(
      0,
      output.recordsFailed,
      'Should have 0 failed records'
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
    List<AckOpportunityResult> emptyOpps = new List<AckOpportunityResult>();

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(emptyOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify empty list handling
    System.assertEquals(
      0,
      output.recordsUpdated,
      'Should have updated 0 records'
    );
    System.assertEquals(
      0,
      output.recordsFailed,
      'Should have 0 failed records'
    );
  }

  @isTest
  static void testUpdateDatabaseWithDifferentAcknowledgmentDates() {
    // Test database update with different acknowledgment dates
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    List<Id> oppIds = new List<Id>();
    List<AckOpportunityResult> successfulOpps = new List<AckOpportunityResult>();

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

    AckOpportunityResult result1 = new AckOpportunityResult(
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

    AckOpportunityResult result2 = new AckOpportunityResult(
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
  static void testUpdateDatabasePartialFailureMarksAckUpdateFailed() {
    // Test that a DML failure on one record (email already sent) does not block
    // the others, and marks the failed record's opportunity result as
    // ACK_UPDATE_FAILED rather than throwing.
    Opportunity goodOpp = [SELECT Id, Name FROM Opportunity LIMIT 1];

    Opportunity docToDelete = AcknowledgementTestUtils.createTestOpportunity(
      'Will Be Deleted Opp',
      null,
      null,
      50
    );
    Id deletedOppId = docToDelete.Id;
    delete docToDelete;

    AckOpportunityResult goodResult = new AckOpportunityResult(
      goodOpp.Id,
      goodOpp.Name
    );
    goodResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
    goodResult.acknowledgmentDate = Date.today();

    AckOpportunityResult badResult = new AckOpportunityResult(
      deletedOppId,
      'Will Be Deleted Opp'
    );
    badResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
    badResult.acknowledgmentDate = Date.today();

    List<AckOpportunityResult> successfulOpps = new List<AckOpportunityResult>{
      goodResult,
      badResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // The command must not throw, and must report the partial failure via counts
    System.assertEquals(
      1,
      output.recordsUpdated,
      'Should have updated the 1 record that still exists'
    );
    System.assertEquals(
      1,
      output.recordsFailed,
      'Should have failed to update the 1 deleted record'
    );

    // The good record keeps its SUCCESS status
    System.assertEquals(
      AckStatus.SUCCESS,
      goodResult.status,
      'Successful DB update should not change the SUCCESS status'
    );

    // The bad record is downgraded to ACK_UPDATE_FAILED - the email already went
    // out, so this needs manual attention rather than silently vanishing.
    System.assertEquals(
      AckStatus.ACK_UPDATE_FAILED,
      badResult.status,
      'Record whose DB update failed should be marked ACK_UPDATE_FAILED'
    );
    System.assert(
      badResult.reason.contains('Email was sent, but record update failed'),
      'Reason should explain the email/DB mismatch. Actual: ' + badResult.reason
    );
    System.assert(
      badResult.reason.contains('manual attention'),
      'Reason should call out that manual attention is needed. Actual: ' +
      badResult.reason
    );
    System.assert(
      badResult.isFailed(),
      'ACK_UPDATE_FAILED should be considered a failure'
    );
    System.assert(
      !badResult.isSuccess(),
      'ACK_UPDATE_FAILED should not be considered a success, even though the email sent'
    );
  }

  @isTest
  static void testUpdateOutputStructure() {
    // Test the structure and properties of the UpdateOutput class
    Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];

    AckOpportunityResult oppResult = new AckOpportunityResult(opp.Id, opp.Name);
    oppResult.acknowledgmentDate = Date.today();

    List<AckOpportunityResult> successfulOpps = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify output structure
    System.assertNotEquals(null, output, 'Output should not be null');
    System.assertEquals(
      1,
      output.recordsUpdated,
      'Should have updated 1 record'
    );
    System.assertEquals(
      0,
      output.recordsFailed,
      'Should have 0 failed records'
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

    AckOpportunityResult oppResult = new AckOpportunityResult(opp.Id, opp.Name);
    // Deliberately leave acknowledgmentDate as null

    List<AckOpportunityResult> successfulOpps = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Command should handle null acknowledgment date gracefully
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
  static void testUpdateDatabaseAcknowledgmentStatus() {
    // Test acknowledgment status update
    Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];

    // Create successful opportunity result
    AckOpportunityResult oppResult = new AckOpportunityResult(opp.Id, opp.Name);
    oppResult.acknowledgmentDate = Date.today();

    List<AckOpportunityResult> successfulOpps = new List<AckOpportunityResult>{
      oppResult
    };

    Test.startTest();
    DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(successfulOpps);
    updateCmd.execute();
    AcknowledgementCommandOutputs.UpdateOutput output = updateCmd.getOutput();
    Test.stopTest();

    // Verify acknowledgment status update
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Status__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      'Acknowledged',
      updatedOpp.npsp__Acknowledgment_Status__c,
      'Acknowledgment status should be set to "Acknowledged"'
    );
  }

  /**
   * NOTE: This test class was refactored as part of the test responsibility plan.
   * See docs/test-refactoring-plan.md for details on which methods were moved or removed.
   */

  // The following test methods were moved to DonationAcknowledgementServiceImplTest as part of the test refactoring plan:
  // - testUpdateDatabaseTransactionBehavior
  // - testUpdateDatabaseBulkProcessing
}
