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

  @isTest
  static void testSendEmailsForOpportunities_basic() {
    // Arrange
    Account a = new Account(Name = 'Test Account');
    insert a;
    Contact c = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      Email = 'test@example.com',
      AccountId = a.Id
    );
    insert c;
    Opportunity o = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = a.Id,
      ContactId = c.Id
    );
    insert o;
    List<Opportunity> opps = new List<Opportunity>{ o };
    String subject = 'Test Subject';
    String body = 'Test Body';
    // Act
    Test.startTest();
    Integer sentCount = DonationAcknowledgementService.sendEmailsForOpportunities(
      opps,
      subject,
      body
    );
    Test.stopTest();
    // Assert
    System.assertEquals(1, sentCount, 'Should send one email');
    List<EmailMessage> messages = [
      SELECT Id, Subject, ToAddress, RelatedToId
      FROM EmailMessage
      WHERE RelatedToId = :o.Id
    ];
    System.assertEquals(1, messages.size(), 'Should create one EmailMessage');
    System.assertEquals(subject, messages[0].Subject);
    System.assertEquals('test@example.com', messages[0].ToAddress);
  }

  @isTest
  static void testSendEmailsForOpportunities_noContact() {
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
    List<Opportunity> opps = new List<Opportunity>{ o };
    String subject = 'Test Subject';
    String body = 'Test Body';
    // Act
    Test.startTest();
    Integer sentCount = DonationAcknowledgementService.sendEmailsForOpportunities(
      opps,
      subject,
      body
    );
    Test.stopTest();
    // Assert
    System.assertEquals(0, sentCount, 'Should not send email if no ContactId');
    List<EmailMessage> messages = [
      SELECT Id
      FROM EmailMessage
      WHERE RelatedToId = :o.Id
    ];
    System.assertEquals(0, messages.size(), 'Should not create EmailMessage');
  }

  @isTest
  static void testSendEmailsForOpportunities_noEmail() {
    // Arrange
    Account a = new Account(Name = 'Test Account');
    insert a;
    Contact c = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      AccountId = a.Id
    );
    insert c;
    Opportunity o = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = a.Id,
      ContactId = c.Id
    );
    insert o;
    List<Opportunity> opps = new List<Opportunity>{ o };
    String subject = 'Test Subject';
    String body = 'Test Body';
    // Act
    Test.startTest();
    Integer sentCount = DonationAcknowledgementService.sendEmailsForOpportunities(
      opps,
      subject,
      body
    );
    Test.stopTest();
    // Assert
    System.assertEquals(
      0,
      sentCount,
      'Should not send email if Contact has no email'
    );
    List<EmailMessage> messages = [
      SELECT Id
      FROM EmailMessage
      WHERE RelatedToId = :o.Id
    ];
    System.assertEquals(0, messages.size(), 'Should not create EmailMessage');
  }
}
