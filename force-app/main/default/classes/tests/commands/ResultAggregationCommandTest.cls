/**
 * Test class for ResultAggregationCommand
 * Tests result aggregation logic and final DetailedAckResult assembly
 */
@isTest
private class ResultAggregationCommandTest {
  @testSetup
  static void setupTestData() {
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
  static void testAggregateResultsSuccessfulScenario() {
    // Test result aggregation with successful email sending scenario

    // Create initial DetailedAckResult
    AckDetailedResult result = new AckDetailedResult();

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    Contact testContact = new Contact(
      Id = [SELECT Id FROM Contact LIMIT 1]
      .Id,
      Email = 'testuser@example.com'
    );
    prepOutput.contactMap.put(testContact.Id, testContact);

    AckOpportunityResult prepResult = new AckOpportunityResult(
      '006000000000001AAA',
      'Success Opportunity'
    );
    prepResult.contactEmail = 'testuser@example.com';
    prepOutput.validOpportunities.add(prepResult);

    // Create successful send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    AckOpportunityResult successResult = new AckOpportunityResult(
      '006000000000001AAA',
      'Success Opportunity'
    );
    successResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
    successResult.acknowledgmentDate = Date.today();

    sendOutput.setResults(
      new List<AckOpportunityResult>{ successResult },
      new List<AckOpportunityResult>()
    );

    // Create successful update output
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setCounts(1, 0);

    String emailType = 'Test Email Template';

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      emailType
    );
    aggregationCmd.execute();
    Test.stopTest();

    // Verify result aggregation
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 opportunity result'
    );
    System.assertEquals(
      emailType,
      result.emailType,
      'Should have correct email type'
    );

    // Verify opportunity result details
    AckOpportunityResult finalResult = result.opportunityResults[0];
    System.assertEquals(
      '006000000000001AAA',
      finalResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      'Success Opportunity',
      finalResult.opportunityName,
      'Should have correct opportunity name'
    );
    System.assertEquals(
      AckStatus.SUCCESS,
      finalResult.status,
      'Should have success status'
    );
    System.assertEquals(
      'Email sent successfully',
      finalResult.reason,
      'Should have success reason'
    );
    System.assertEquals(
      Date.today(),
      finalResult.acknowledgmentDate,
      'Should have acknowledgment date'
    );
  }

  @isTest
  static void testAggregateResultsFailedScenario() {
    // Test result aggregation with failed email sending scenario

    // Create initial DetailedAckResult
    AckDetailedResult result = new AckDetailedResult();

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    // Create failed send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    AckOpportunityResult failedResult = new AckOpportunityResult(
      '006000000000002AAA',
      'Failed Opportunity'
    );
    failedResult.setStatus(AckStatus.EMAIL_SEND_FAILED, 'Email sending failed');

    sendOutput.setResults(
      new List<AckOpportunityResult>(),
      new List<AckOpportunityResult>{ failedResult }
    );

    // Create update output (not used when there are no successful sends)
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = null;

    String emailType = 'Test Failed Template';

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      emailType
    );
    aggregationCmd.execute();
    Test.stopTest();

    // Verify result aggregation for failed scenario - failures are added just
    // like successes, unconditionally
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Should have 1 opportunity result'
    );
    System.assertEquals(
      emailType,
      result.emailType,
      'Should have correct email type'
    );

    // Verify failed opportunity result details
    AckOpportunityResult finalResult = result.opportunityResults[0];
    System.assertEquals(
      '006000000000002AAA',
      finalResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      'Failed Opportunity',
      finalResult.opportunityName,
      'Should have correct opportunity name'
    );
    System.assertEquals(
      AckStatus.EMAIL_SEND_FAILED,
      finalResult.status,
      'Should have failed status'
    );
    System.assertEquals(
      'Email sending failed',
      finalResult.reason,
      'Should have failure reason'
    );
  }

  @isTest
  static void testAggregateResultsMixedSuccessAndFailureBothAdded() {
    // Test that a batch with both successes and failures gets ALL results added,
    // not just one side - this is the core semantics change: there is no longer
    // an overall isSuccess flag that gates which list gets aggregated.
    AckDetailedResult result = new AckDetailedResult();
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    AckOpportunityResult successResult = new AckOpportunityResult(
      '006000000000009AAA',
      'Mixed Success Opportunity'
    );
    successResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
    successResult.acknowledgmentDate = Date.today();

    AckOpportunityResult failedResult = new AckOpportunityResult(
      '006000000000010AAA',
      'Mixed Failed Opportunity'
    );
    failedResult.setStatus(AckStatus.EMAIL_SEND_FAILED, 'Email sending failed');

    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();
    sendOutput.setResults(
      new List<AckOpportunityResult>{ successResult },
      new List<AckOpportunityResult>{ failedResult }
    );

    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setCounts(1, 0);

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      'Mixed Template'
    );
    aggregationCmd.execute();
    Test.stopTest();

    System.assertEquals(
      2,
      result.opportunityResults.size(),
      'Should include both the success and the failure'
    );
    System.assertEquals(1, result.emailsSent, 'Should count the success');
    System.assertEquals(
      1,
      result.emailSendFailures,
      'Should count the failure'
    );
  }

  @isTest
  static void testAggregateResultsMultipleOpportunities() {
    // Test result aggregation with multiple opportunities (mixed success/failure)

    // Create initial DetailedAckResult
    AckDetailedResult result = new AckDetailedResult();

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    // Create mixed send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    // Create successful opportunity results
    List<AckOpportunityResult> successfulResults = new List<AckOpportunityResult>();

    for (Integer i = 1; i <= 2; i++) {
      AckOpportunityResult successResult = new AckOpportunityResult(
        '00600000000000' + i + 'AAA',
        'Success Opportunity ' + i
      );
      successResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
      successResult.acknowledgmentDate = Date.today();
      successfulResults.add(successResult);
    }

    sendOutput.setResults(successfulResults, new List<AckOpportunityResult>());

    // Create update output
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setCounts(2, 0);

    String emailType = 'Test Multiple Template';

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      emailType
    );
    aggregationCmd.execute();
    Test.stopTest();

    // Verify result aggregation for multiple opportunities
    System.assertEquals(
      2,
      result.opportunityResults.size(),
      'Should have 2 opportunity results'
    );
    System.assertEquals(
      emailType,
      result.emailType,
      'Should have correct email type'
    );

    // Verify all opportunity results
    for (AckOpportunityResult finalResult : result.opportunityResults) {
      System.assertEquals(
        AckStatus.SUCCESS,
        finalResult.status,
        'Should have success status'
      );
      System.assertEquals(
        'Email sent successfully',
        finalResult.reason,
        'Should have success reason'
      );
      System.assertEquals(
        Date.today(),
        finalResult.acknowledgmentDate,
        'Should have acknowledgment date'
      );
      System.assert(
        finalResult.opportunityName.startsWith('Success Opportunity'),
        'Should have correct opportunity name pattern'
      );
    }
  }

  @isTest
  static void testAggregateResultsWithExistingSkippedOpportunities() {
    // Test result aggregation when DetailedAckResult already contains skipped opportunities

    // Create initial DetailedAckResult with existing skipped opportunities
    AckDetailedResult result = new AckDetailedResult();

    // Add some pre-existing skipped opportunities (from validation command)
    AckOpportunityResult skippedResult1 = new AckOpportunityResult(
      '006000000000003AAA',
      'Already Acknowledged Opp'
    );
    skippedResult1.setStatus(
      AckStatus.ALREADY_ACKNOWLEDGED,
      'Already acknowledged'
    );
    result.addOpportunityResult(skippedResult1);

    AckOpportunityResult skippedResult2 = new AckOpportunityResult(
      '006000000000004AAA',
      'No Contact Opp'
    );
    skippedResult2.setStatus(AckStatus.NO_CONTACT, 'No contact');
    result.addOpportunityResult(skippedResult2);

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    // Create successful send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    AckOpportunityResult successResult = new AckOpportunityResult(
      '006000000000005AAA',
      'New Success Opportunity'
    );
    successResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
    successResult.acknowledgmentDate = Date.today();

    sendOutput.setResults(
      new List<AckOpportunityResult>{ successResult },
      new List<AckOpportunityResult>()
    );

    // Create update output
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setCounts(1, 0);

    String emailType = 'Test Mixed Template';

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      emailType
    );
    aggregationCmd.execute();
    Test.stopTest();

    // Verify result aggregation includes both existing and new results
    System.assertEquals(
      3,
      result.opportunityResults.size(),
      'Should have 3 total opportunity results'
    );
    System.assertEquals(
      emailType,
      result.emailType,
      'Should have correct email type'
    );

    // Verify result contains all expected opportunities
    Map<String, AckOpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );

    // Check pre-existing skipped opportunities
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Already Acknowledged Opp',
      AckStatus.ALREADY_ACKNOWLEDGED,
      'Already acknowledged'
    );

    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'No Contact Opp',
      AckStatus.NO_CONTACT,
      'No contact'
    );

    // Check new successful opportunity
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'New Success Opportunity',
      AckStatus.SUCCESS,
      'Email sent successfully'
    );
  }

  @isTest
  static void testAggregateResultsEmptyScenario() {
    // Test result aggregation with empty inputs

    // Create initial DetailedAckResult
    AckDetailedResult result = new AckDetailedResult();

    // Create empty outputs
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();
    sendOutput.setResults(
      new List<AckOpportunityResult>(),
      new List<AckOpportunityResult>()
    );

    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setCounts(0, 0);

    String emailType = 'Test Empty Template';

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      emailType
    );
    aggregationCmd.execute();
    Test.stopTest();

    // Verify result aggregation for empty scenario
    System.assertEquals(
      0,
      result.opportunityResults.size(),
      'Should have 0 opportunity results'
    );
    System.assertEquals(
      emailType,
      result.emailType,
      'Should have correct email type'
    );
  }

  @isTest
  static void testAggregateResultsEmailTypeMetadata() {
    // Test that email type metadata is properly set

    // Create initial DetailedAckResult
    AckDetailedResult result = new AckDetailedResult();

    // Create minimal outputs
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();
    sendOutput.setResults(
      new List<AckOpportunityResult>(),
      new List<AckOpportunityResult>()
    );

    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setCounts(0, 0);

    // Test with a single email type value (avoiding Test.startTest() in loop)
    String emailType = 'Template used: HTML_Donation_Acknowledgement';

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      emailType
    );
    aggregationCmd.execute();
    Test.stopTest();

    // Verify email type is set correctly
    System.assertEquals(
      emailType,
      result.emailType,
      'Should have correct email type: ' + emailType
    );

    // Test null email type case without Test.startTest()
    result = new AckDetailedResult();
    ResultAggregationCommand nullCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      null
    );
    nullCmd.execute();
    System.assertEquals(
      null,
      result.emailType,
      'Should handle null email type'
    );
  }

  @isTest
  static void testResultAggregationCommandNoReturnValue() {
    // Test that ResultAggregationCommand modifies the DetailedAckResult directly
    // and doesn't return a value (implements command pattern correctly)

    // Create initial DetailedAckResult
    AckDetailedResult result = new AckDetailedResult();

    // Verify initial state
    System.assertEquals(
      0,
      result.opportunityResults.size(),
      'Should start with 0 results'
    );
    System.assertEquals(
      null,
      result.emailType,
      'Should start with null email type'
    );

    // Create minimal outputs
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    AckOpportunityResult testResult = new AckOpportunityResult(
      '006000000000008AAA',
      'Direct Modification Test'
    );
    testResult.setStatus(AckStatus.SUCCESS, 'Test reason');

    sendOutput.setResults(
      new List<AckOpportunityResult>{ testResult },
      new List<AckOpportunityResult>()
    );

    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setCounts(1, 0);

    String emailType = 'Direct Modification Template';

    Test.startTest();
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      result,
      prepOutput,
      sendOutput,
      updateOutput,
      emailType
    );

    // Execute command (no return value)
    aggregationCmd.execute();
    Test.stopTest();

    // Verify the original DetailedAckResult object was modified directly
    System.assertEquals(
      1,
      result.opportunityResults.size(),
      'Original result should be modified'
    );
    System.assertEquals(
      emailType,
      result.emailType,
      'Original result should have email type set'
    );

    // Verify the opportunity result was added
    AckOpportunityResult addedResult = result.opportunityResults[0];
    System.assertEquals(
      '006000000000008AAA',
      addedResult.opportunityId,
      'Should have correct opportunity ID'
    );
    System.assertEquals(
      'Direct Modification Test',
      addedResult.opportunityName,
      'Should have correct name'
    );
    System.assertEquals(
      AckStatus.SUCCESS,
      addedResult.status,
      'Should have correct status'
    );
  }

  /**
   * NOTE: This test class was refactored as part of the test responsibility plan.
   * See docs/test-refactoring-plan.md for details on which methods were moved or removed.
   */
  // The following test method was moved to DonationAcknowledgementServiceImplTest as part of the test refactoring plan:
  // - testAggregateResultsCommandIntegration
}
