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
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    Contact testContact = new Contact(
      Id = [SELECT Id FROM Contact LIMIT 1]
      .Id,
      Email = 'testuser@example.com'
    );
    prepOutput.contactMap.put(testContact.Id, testContact);

    DonationAcknowledgementService.OpportunityResult prepResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000001AAA',
      'Success Opportunity'
    );
    prepResult.contactEmail = 'testuser@example.com';
    prepOutput.validOpportunities.add(prepResult);

    // Create successful send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    DonationAcknowledgementService.OpportunityResult successResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000001AAA',
      'Success Opportunity'
    );
    successResult.setStatus(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent successfully'
    );
    successResult.acknowledgmentDate = Date.today();

    sendOutput.setSuccess(
      new List<DonationAcknowledgementService.OpportunityResult>{
        successResult
      }
    );

    // Create successful update output
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setSuccess(1);

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
    DonationAcknowledgementService.OpportunityResult finalResult = result.opportunityResults[0];
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
      DonationAcknowledgementService.AckStatus.SUCCESS,
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
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    // Create failed send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    DonationAcknowledgementService.OpportunityResult failedResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000002AAA',
      'Failed Opportunity'
    );
    failedResult.setStatus(
      DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
      'Email sending failed'
    );

    sendOutput.setFailure(
      'Failed to send emails',
      new List<DonationAcknowledgementService.OpportunityResult>{ failedResult }
    );

    // Create update output (not used in failed scenario)
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();

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

    // Verify result aggregation for failed scenario
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
    DonationAcknowledgementService.OpportunityResult finalResult = result.opportunityResults[0];
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
      DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
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
  static void testAggregateResultsMultipleOpportunities() {
    // Test result aggregation with multiple opportunities (mixed success/failure)

    // Create initial DetailedAckResult
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    // Create mixed send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    // Create successful opportunity results
    List<DonationAcknowledgementService.OpportunityResult> successfulResults = new List<DonationAcknowledgementService.OpportunityResult>();

    for (Integer i = 1; i <= 2; i++) {
      DonationAcknowledgementService.OpportunityResult successResult = new DonationAcknowledgementService.OpportunityResult(
        '00600000000000' + i + 'AAA',
        'Success Opportunity ' + i
      );
      successResult.setStatus(
        DonationAcknowledgementService.AckStatus.SUCCESS,
        'Email sent successfully'
      );
      successResult.acknowledgmentDate = Date.today();
      successfulResults.add(successResult);
    }

    sendOutput.setSuccess(successfulResults);

    // Create update output
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setSuccess(2);

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
    for (
      DonationAcknowledgementService.OpportunityResult finalResult : result.opportunityResults
    ) {
      System.assertEquals(
        DonationAcknowledgementService.AckStatus.SUCCESS,
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
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    // Add some pre-existing skipped opportunities (from validation command)
    DonationAcknowledgementService.OpportunityResult skippedResult1 = new DonationAcknowledgementService.OpportunityResult(
      '006000000000003AAA',
      'Already Acknowledged Opp'
    );
    skippedResult1.setStatus(
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      'Already acknowledged'
    );
    result.addOpportunityResult(skippedResult1);

    DonationAcknowledgementService.OpportunityResult skippedResult2 = new DonationAcknowledgementService.OpportunityResult(
      '006000000000004AAA',
      'No Contact Opp'
    );
    skippedResult2.setStatus(
      DonationAcknowledgementService.AckStatus.NO_CONTACT,
      'No contact'
    );
    result.addOpportunityResult(skippedResult2);

    // Create email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    // Create successful send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    DonationAcknowledgementService.OpportunityResult successResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000005AAA',
      'New Success Opportunity'
    );
    successResult.setStatus(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent successfully'
    );
    successResult.acknowledgmentDate = Date.today();

    sendOutput.setSuccess(
      new List<DonationAcknowledgementService.OpportunityResult>{
        successResult
      }
    );

    // Create update output
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setSuccess(1);

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
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );

    // Check pre-existing skipped opportunities
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Already Acknowledged Opp',
      DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
      'Already acknowledged'
    );

    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'No Contact Opp',
      DonationAcknowledgementService.AckStatus.NO_CONTACT,
      'No contact'
    );

    // Check new successful opportunity
    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'New Success Opportunity',
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent successfully'
    );
  }

  @isTest
  static void testAggregateResultsEmptyScenario() {
    // Test result aggregation with empty inputs

    // Create initial DetailedAckResult
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    // Create empty outputs
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();
    sendOutput.setSuccess(
      new List<DonationAcknowledgementService.OpportunityResult>()
    );

    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setSuccess(0);

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
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    // Create minimal outputs
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();
    sendOutput.setSuccess(
      new List<DonationAcknowledgementService.OpportunityResult>()
    );

    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setSuccess(0);

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
    result = new DonationAcknowledgementService.DetailedAckResult();
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
  static void testAggregateResultsCommandIntegration() {
    // Test result aggregation as part of complete command flow simulation

    // Create initial DetailedAckResult with validation results
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

    // Simulate validation command results
    DonationAcknowledgementService.OpportunityResult validationSkipped = new DonationAcknowledgementService.OpportunityResult(
      '006000000000006AAA',
      'Validation Skipped Opp'
    );
    validationSkipped.setStatus(
      DonationAcknowledgementService.AckStatus.NO_EMAIL,
      'Contact has no email'
    );
    result.addOpportunityResult(validationSkipped);

    // Simulate email preparation output
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();

    Contact testContact = new Contact(
      Id = [SELECT Id FROM Contact LIMIT 1]
      .Id,
      Email = 'testuser@example.com'
    );
    prepOutput.contactMap.put(testContact.Id, testContact);

    DonationAcknowledgementService.OpportunityResult preparedOpp = new DonationAcknowledgementService.OpportunityResult(
      '006000000000007AAA',
      'Prepared Opportunity'
    );
    preparedOpp.contactEmail = 'testuser@example.com';
    prepOutput.validOpportunities.add(preparedOpp);

    // Simulate email send output
    AcknowledgementCommandOutputs.SendOutput sendOutput = new AcknowledgementCommandOutputs.SendOutput();

    DonationAcknowledgementService.OpportunityResult sentOpp = new DonationAcknowledgementService.OpportunityResult(
      '006000000000007AAA',
      'Prepared Opportunity'
    );
    sentOpp.setStatus(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent successfully'
    );
    sentOpp.acknowledgmentDate = Date.today();

    sendOutput.setSuccess(
      new List<DonationAcknowledgementService.OpportunityResult>{ sentOpp }
    );

    // Simulate database update output
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setSuccess(1);

    String emailType = 'Integration Test Template';

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

    // Verify complete result aggregation
    System.assertEquals(
      2,
      result.opportunityResults.size(),
      'Should have 2 total opportunity results'
    );
    System.assertEquals(
      emailType,
      result.emailType,
      'Should have correct email type'
    );

    // Verify both validation skipped and successfully sent opportunities are included
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = AcknowledgementTestUtils.createResultsByNameMap(
      result.opportunityResults
    );

    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Validation Skipped Opp',
      DonationAcknowledgementService.AckStatus.NO_EMAIL,
      'Contact has no email'
    );

    AcknowledgementTestUtils.assertOpportunityResult(
      resultsByName,
      'Prepared Opportunity',
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Email sent successfully'
    );

    // Verify acknowledgment date is set for successful opportunity
    DonationAcknowledgementService.OpportunityResult successResult = resultsByName.get(
      'Prepared Opportunity'
    );
    System.assertEquals(
      Date.today(),
      successResult.acknowledgmentDate,
      'Should have acknowledgment date'
    );
  }

  @isTest
  static void testResultAggregationCommandNoReturnValue() {
    // Test that ResultAggregationCommand modifies the DetailedAckResult directly
    // and doesn't return a value (implements command pattern correctly)

    // Create initial DetailedAckResult
    DonationAcknowledgementService.DetailedAckResult result = new DonationAcknowledgementService.DetailedAckResult();

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

    DonationAcknowledgementService.OpportunityResult testResult = new DonationAcknowledgementService.OpportunityResult(
      '006000000000008AAA',
      'Direct Modification Test'
    );
    testResult.setStatus(
      DonationAcknowledgementService.AckStatus.SUCCESS,
      'Test reason'
    );

    sendOutput.setSuccess(
      new List<DonationAcknowledgementService.OpportunityResult>{ testResult }
    );

    AcknowledgementCommandOutputs.UpdateOutput updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
    updateOutput.setSuccess(1);

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
    DonationAcknowledgementService.OpportunityResult addedResult = result.opportunityResults[0];
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
      DonationAcknowledgementService.AckStatus.SUCCESS,
      addedResult.status,
      'Should have correct status'
    );
  }
}
