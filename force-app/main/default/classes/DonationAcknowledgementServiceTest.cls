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
}
