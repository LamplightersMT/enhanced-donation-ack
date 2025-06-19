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
}
