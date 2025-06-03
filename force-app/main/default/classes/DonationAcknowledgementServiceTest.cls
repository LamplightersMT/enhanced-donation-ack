@isTest
private class DonationAcknowledgementServiceTest {
  @isTest
  static void testSendAcknowledgementsInvocable_emptyInput() {
    // Arrange
    List<DonationAcknowledgementService.OpportunityIdWrapper> inputList = new List<DonationAcknowledgementService.OpportunityIdWrapper>();
    // Act
    List<DonationAcknowledgementService.AckResultWrapper> results = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      inputList
    );
    // Assert
    System.assertEquals(1, results.size(), 'Should return one result');
    System.assertEquals('No Opportunity IDs provided.', results[0].result);
  }

  @isTest
  static void testSendAcknowledgementsInvocable_withIds() {
    // Arrange
    Account a = new Account(Name = 'Test Account');
    insert a;
    Opportunity o = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = a.Id
    );
    insert o;
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = new List<Id>{ o.Id };
    List<DonationAcknowledgementService.OpportunityIdWrapper> inputList = new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      wrapper
    };
    // Act
    List<DonationAcknowledgementService.AckResultWrapper> results = DonationAcknowledgementService.sendAcknowledgementsInvocable(
      inputList
    );
    // Assert
    System.assertEquals(1, results.size(), 'Should return one result');
    System.assert(
      results[0]
        .result.contains('sendAcknowledgements called with 1 Opportunities.')
    );
  }

  @isTest
  static void testSendAcknowledgements_emptyInput() {
    // Act
    String result = DonationAcknowledgementService.sendAcknowledgements(
      new List<Id>()
    );
    // Assert
    System.assertEquals('No Opportunity IDs provided.', result);
  }

  @isTest
  static void testSendAcknowledgements_withIds() {
    // Arrange
    Account a = new Account(Name = 'Test Account');
    insert a;
    Opportunity o = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = a.Id
    );
    insert o;
    // Act
    String result = DonationAcknowledgementService.sendAcknowledgements(
      new List<Id>{ o.Id }
    );
    // Assert
    System.assert(
      result.contains('sendAcknowledgements called with 1 Opportunities.')
    );
  }
}
