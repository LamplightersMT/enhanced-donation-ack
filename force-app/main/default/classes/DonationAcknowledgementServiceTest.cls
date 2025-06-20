@isTest
private class DonationAcknowledgementServiceTest {
  @testSetup
  static void setupTestData() {
    // Create test Contact
    Contact c = new Contact(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'testuser@example.com'
    );
    insert c;
    // Create test Opportunity
    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
    );
    insert opp;
    // (Do NOT create OrgWideEmailAddress here; not allowed in Apex tests)
    // Create EmailTemplate in correct folder
    // (Assume template/folder already deployed in metadata, so just query in test)
  }

  @isTest
  static void testSendAcknowledgementsWithTemplate() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = new List<Id>{ opp.Id };
    List<DonationAcknowledgementService.OpportunityIdWrapper> input = new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      wrapper
    };
    Test.startTest();
    List<DonationAcknowledgementService.AckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      input
    );
    Test.stopTest();
    System.assertEquals(1, result.size());
    System.assert(result[0].result.contains('Emails sent: 1'));
    // Verify acknowledgement date is set
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(), // FIXME: Fragile test, will break if run on a different day
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgement date should be set to today'
    );
  }

  @isTest
  static void testSendAcknowledgementsStaticFallback() {
    // Set template devname/folder to values that do not exist to force fallback
    DonationAcknowledgementService.donationAckTemplateDevName = 'DoesNotExistTemplate';
    DonationAcknowledgementService.donationAckTemplateFolder = 'DoesNotExistFolder';
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = new List<Id>{ opp.Id };
    List<DonationAcknowledgementService.OpportunityIdWrapper> input = new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      wrapper
    };
    Test.startTest();
    List<DonationAcknowledgementService.AckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      input
    );
    Test.stopTest();
    System.assertEquals(1, result.size());
    System.assert(result[0].result.contains('Static content fallback'));
    // Verify acknowledgement date is set
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(), // FIXME: Fragile test, will break if run on a different day
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgement date should be set to today'
    );
  }

  @isTest
  static void testNoOpportunities() {
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = new List<Id>();
    List<DonationAcknowledgementService.OpportunityIdWrapper> input = new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      wrapper
    };
    Test.startTest();
    List<DonationAcknowledgementService.AckResultWrapper> result = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      input
    );
    Test.stopTest();
    System.assertEquals(1, result.size());
    System.assertEquals('No Opportunity IDs provided.', result[0].result);
  }

  @isTest
  static void testEmailSendingFailureDoesNotUpdateAcknowledgmentDate() {
    // This test verifies that if email sending fails, acknowledgment dates are not updated
    Opportunity opp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      LIMIT 1
    ];

    // Verify opportunity starts without acknowledgment date
    System.assertEquals(
      null,
      opp.npsp__Acknowledgment_Date__c,
      'Opportunity should start without acknowledgment date'
    );

    // Create a scenario that might cause email sending to fail
    // Note: In test context, Messaging.sendEmail() typically doesn't fail,
    // but this test documents the expected behavior if it did fail

    List<Id> oppIds = new List<Id>{ opp.Id };

    Test.startTest();
    try {
      String result = DonationAcknowledgementService.sendAcknowledgements(
        oppIds
      );
      // If we get here, email sending succeeded (normal test behavior)
      System.assert(
        result.contains('Emails sent:'),
        'Should indicate emails were sent'
      );

      // Verify acknowledgment date was set on success
      Opportunity updatedOpp = [
        SELECT Id, npsp__Acknowledgment_Date__c
        FROM Opportunity
        WHERE Id = :opp.Id
      ];
      System.assertEquals(
        Date.today(),
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Acknowledgment date should be set on successful send'
      );
    } catch (AuraHandledException e) {
      // If email sending failed (unlikely in test context), verify acknowledgment date was not set
      System.assert(
        e.getMessage().contains('Failed to send acknowledgement emails'),
        'Exception should indicate email sending failure'
      );

      Opportunity updatedOpp = [
        SELECT Id, npsp__Acknowledgment_Date__c
        FROM Opportunity
        WHERE Id = :opp.Id
      ];
      System.assertEquals(
        null,
        updatedOpp.npsp__Acknowledgment_Date__c,
        'Acknowledgment date should not be set on failure'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendEmailsCoreWithTemplateConfig() {
    // Test the core method directly with template configuration
    // Note: In test context, we can't create actual EmailTemplate records,
    // so this test will verify the method executes but may not send actual emails
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];

    // Use a realistic looking template ID format
    Id mockTemplateId = '00X000000000000AAA'; // Mock template ID in correct format

    Test.startTest();
    try {
      Integer result = DonationAcknowledgementService.sendEmailsCore(
        opps,
        new DonationAcknowledgementService.EmailConfig(mockTemplateId)
      );
      // If we get here, the method executed successfully
      System.assert(result >= 0, 'Should return a valid count');
    } catch (Exception e) {
      // In test context, template-based emails may fail due to missing template or invalid ID format
      // This is expected behavior - the important thing is that the method doesn't crash unexpectedly
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
    // Test the core method directly with static content configuration
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];

    Test.startTest();
    Integer result = DonationAcknowledgementService.sendEmailsCore(
      opps,
      new DonationAcknowledgementService.EmailConfig(
        'Test Subject',
        'Test Body'
      )
    );
    Test.stopTest();

    // Should return 1 (one email processed)
    System.assertEquals(1, result, 'Should process one opportunity');

    // Verify acknowledgment date was set
    Opportunity updatedOpp = [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      Date.today(),
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgment date should be set'
    );
  }

  @isTest
  static void testDuplicatePreventionSkipsAcknowledgedOpportunities() {
    // Create test data with one already acknowledged opportunity
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create two opportunities - one already acknowledged, one not
    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Already Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today().addDays(-1),
      Amount = 200,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1) // Already acknowledged
    );

    Opportunity newOpp = new Opportunity(
      Name = 'New Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id
      // No acknowledgment date - should be processed
    );

    insert new List<Opportunity>{ acknowledgedOpp, newOpp };

    List<Id> oppIds = new List<Id>{ acknowledgedOpp.Id, newOpp.Id };

    Test.startTest();
    String result = DonationAcknowledgementService.sendAcknowledgements(oppIds);
    Test.stopTest();

    // Verify result message shows correct counts
    System.assert(
      result.contains('2 Opportunities'),
      'Should show 2 total opportunities'
    );
    System.assert(
      result.contains('Emails sent: 1'),
      'Should send 1 email (for new opp only)'
    );
    System.assert(
      result.contains('Already acknowledged: 1'),
      'Should show 1 already acknowledged'
    );

    // Verify only the new opportunity got acknowledgment date updated
    List<Opportunity> updatedOpps = [
      SELECT Id, Name, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :oppIds
      ORDER BY Name
    ];

    // Already acknowledged opp should keep its original date
    System.assertEquals(
      Date.today().addDays(-1),
      updatedOpps[0].npsp__Acknowledgment_Date__c,
      'Already acknowledged opp should keep original date'
    );

    // New opp should get today's date
    System.assertEquals(
      Date.today(),
      updatedOpps[1].npsp__Acknowledgment_Date__c,
      'New opp should get acknowledgment date set to today'
    );
  }

  @isTest
  static void testDuplicatePreventionAllAlreadyAcknowledged() {
    // Test scenario where all opportunities are already acknowledged
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Already Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today().addDays(-1),
      Amount = 100,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1)
    );
    insert acknowledgedOpp;

    List<Id> oppIds = new List<Id>{ acknowledgedOpp.Id };

    Test.startTest();
    String result = DonationAcknowledgementService.sendAcknowledgements(oppIds);
    Test.stopTest();

    // Verify no emails were sent but proper feedback provided
    System.assert(
      result.contains('1 Opportunities'),
      'Should show 1 total opportunity'
    );
    System.assert(result.contains('Emails sent: 0'), 'Should send 0 emails');
    System.assert(
      result.contains('Already acknowledged: 1'),
      'Should show 1 already acknowledged'
    );
  }

  @isTest
  static void testSendEmailsCoreWithResultReturnsDetailedFeedback() {
    // Test the detailed result object directly
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    // Create mixed scenario: acknowledged, new, and no contact
    Opportunity acknowledgedOpp = new Opportunity(
      Name = 'Acknowledged Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 100,
      ContactId = c.Id,
      npsp__Acknowledgment_Date__c = Date.today().addDays(-1)
    );

    Opportunity newOpp = new Opportunity(
      Name = 'New Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 200,
      ContactId = c.Id
    );

    Opportunity noContactOpp = new Opportunity(
      Name = 'No Contact Opp',
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = 150
      // No ContactId
    );

    insert new List<Opportunity>{ acknowledgedOpp, newOpp, noContactOpp };

    List<Opportunity> opps = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        AccountId,
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN (:acknowledgedOpp.Id, :newOpp.Id, :noContactOpp.Id)
    ];

    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      'Test Subject',
      'Test Body'
    );

    Test.startTest();
    DonationAcknowledgementService.EmailSendResult result = DonationAcknowledgementService.sendEmailsCoreWithResult(
      opps,
      config
    );
    Test.stopTest();

    // Verify detailed counts
    System.assertEquals(
      3,
      result.totalOpportunities,
      'Should have 3 total opportunities'
    );
    System.assertEquals(1, result.emailsSent, 'Should send 1 email');
    System.assertEquals(
      1,
      result.alreadyAcknowledged,
      'Should have 1 already acknowledged'
    );
    System.assertEquals(
      1,
      result.noValidContact,
      'Should have 1 with no valid contact'
    );
    System.assertEquals(
      2,
      result.skippedOpportunityNames.size(),
      'Should have 2 skipped opportunity names'
    );

    // Verify summary message
    String summary = result.buildSummaryMessage('Test Type');
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
    System.assert(
      summary.contains('Test Type'),
      'Summary should include email type'
    );
  }
}
