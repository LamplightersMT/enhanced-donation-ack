/**
 * Shared test utilities for donation acknowledgement tests
 * Provides common test data creation, query helpers, and assertion methods across all test classes
 */
@isTest
public class AcknowledgementTestUtils {
  // ===== TEST DATA CREATION METHODS =====

  /**
   * Create a test contact with specified email (or default test email)
   */
  public static Contact createTestContact(String email) {
    if (String.isBlank(email)) {
      email = 'testuser@example.com';
    }
    Contact c = new Contact(
      FirstName = 'Test',
      LastName = 'User',
      Email = email
    );
    insert c;
    return c;
  }

  /**
   * Create a test contact with no email address
   */
  public static Contact createTestContactWithoutEmail() {
    Contact c = new Contact(
      FirstName = 'No Email',
      LastName = 'Contact'
      // No Email field
    );
    insert c;
    return c;
  }

  /**
   * Create a test opportunity with specified parameters
   */
  public static Opportunity createTestOpportunity(
    String name,
    Contact contact,
    Date ackDate,
    Decimal amount
  ) {
    Opportunity opp = new Opportunity(
      Name = name,
      StageName = 'Closed Won',
      CloseDate = Date.today(),
      Amount = amount != null ? amount : 100,
      ContactId = contact != null ? contact.Id : null
    );
    if (ackDate != null) {
      opp.npsp__Acknowledgment_Date__c = ackDate;
    }
    insert opp;
    return opp;
  }

  /**
   * Create an OpportunityIdWrapper for invocable tests
   */
  public static DonationAcknowledgementService.OpportunityIdWrapper createWrapper(
    List<Id> oppIds
  ) {
    DonationAcknowledgementService.OpportunityIdWrapper wrapper = new DonationAcknowledgementService.OpportunityIdWrapper();
    wrapper.opportunityIds = oppIds;
    return wrapper;
  }

  /**
   * Create a list of wrapper inputs for invocable tests
   */
  public static List<DonationAcknowledgementService.OpportunityIdWrapper> createWrapperInput(
    List<Id> oppIds
  ) {
    return new List<DonationAcknowledgementService.OpportunityIdWrapper>{
      createWrapper(oppIds)
    };
  }

  // ===== QUERY HELPER METHODS =====

  /**
   * Query opportunity with acknowledgment date field
   */
  public static Opportunity queryOpportunityWithAckDate(Id oppId) {
    return [
      SELECT Id, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id = :oppId
      LIMIT 1
    ];
  }

  /**
   * Query opportunities with acknowledgment date field
   */
  public static List<Opportunity> queryOpportunitiesWithAckDate(
    List<Id> oppIds
  ) {
    return [
      SELECT Id, Name, npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :oppIds
      ORDER BY Name
    ];
  }

  /**
   * Query opportunities with all fields needed for service calls
   */
  public static List<Opportunity> queryOpportunitiesFullFields(
    List<Id> oppIds
  ) {
    return [
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
      WHERE Id IN :oppIds
    ];
  }

  // ===== ASSERTION HELPER METHODS =====

  /**
   * Assert that acknowledgment date is set to a specific date (captures test execution date)
   */
  public static void assertAcknowledgmentDateSet(Id oppId, Date expectedDate) {
    Opportunity updatedOpp = queryOpportunityWithAckDate(oppId);
    System.assertEquals(
      expectedDate,
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgment date should be set to expected date'
    );
  }

  /**
   * Assert that acknowledgment date is set to today (using test execution date)
   */
  public static void assertAcknowledgmentDateSetToday(Id oppId) {
    Opportunity updatedOpp = queryOpportunityWithAckDate(oppId);
    System.assertNotEquals(
      null,
      updatedOpp.npsp__Acknowledgment_Date__c,
      'Acknowledgment date should be set'
    );

    // Check that the date is within a reasonable range (today or yesterday to handle midnight edge cases)
    Date ackDate = updatedOpp.npsp__Acknowledgment_Date__c;
    Date today = Date.today();
    Date yesterday = today.addDays(-1);

    System.assert(
      ackDate == today || ackDate == yesterday,
      'Acknowledgment date should be set to today or yesterday (for midnight edge cases). Expected: ' +
        today +
        ' or ' +
        yesterday +
        ', Actual: ' +
        ackDate
    );
  }

  /**
   * Assert common detailed result counts
   */
  public static void assertDetailedResultCounts(
    DonationAcknowledgementService.DetailedAckResult result,
    Integer expectedTotal,
    Integer expectedSent,
    Integer expectedAcknowledged,
    Integer expectedNoContact,
    Integer expectedFailures
  ) {
    System.assertEquals(
      expectedTotal,
      result.totalOpportunities,
      'Should have expected total opportunities'
    );
    System.assertEquals(
      expectedSent,
      result.emailsSent,
      'Should have expected emails sent'
    );
    System.assertEquals(
      expectedAcknowledged,
      result.alreadyAcknowledged,
      'Should have expected already acknowledged'
    );
    System.assertEquals(
      expectedNoContact,
      result.noValidContact,
      'Should have expected no valid contact'
    );
    System.assertEquals(
      expectedFailures,
      result.emailSendFailures,
      'Should have expected email failures'
    );
  }

  /**
   * Create a map of opportunity results by name for easy lookup in tests
   */
  public static Map<String, DonationAcknowledgementService.OpportunityResult> createResultsByNameMap(
    List<DonationAcknowledgementService.OpportunityResult> results
  ) {
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName = new Map<String, DonationAcknowledgementService.OpportunityResult>();
    for (DonationAcknowledgementService.OpportunityResult result : results) {
      resultsByName.put(result.opportunityName, result);
    }
    return resultsByName;
  }

  /**
   * Assert opportunity result by name with expected status and partial reason match
   */
  public static void assertOpportunityResult(
    Map<String, DonationAcknowledgementService.OpportunityResult> resultsByName,
    String oppName,
    DonationAcknowledgementService.AckStatus expectedStatus,
    String reasonContains
  ) {
    DonationAcknowledgementService.OpportunityResult result = resultsByName.get(
      oppName
    );
    System.assertNotEquals(null, result, 'Should have result for ' + oppName);
    System.assertEquals(
      expectedStatus,
      result.status,
      'Should have expected status for ' + oppName
    );
    if (String.isNotBlank(reasonContains)) {
      System.assert(
        result.reason.contains(reasonContains),
        'Reason should contain expected text for ' + oppName
      );
    }
  }

  // ===== SERVICE INJECTION/CONFIG HELPERS FOR INSTANCE-BASED TESTING =====

  /**
   * Create a DonationAcknowledgementServiceImpl with test config and a mock email service
   */
  public static DonationAcknowledgementServiceImpl createConfiguredServiceWithMockEmail() {
    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    service.emailService = new MockEmailService();

    return service;
  }

  public static void injectServiceWithMockEmail() {
    injectServiceInstance(createConfiguredServiceWithMockEmail());
  }

  /**
   * Inject a service instance into the DonationAcknowledgementService facade
   */
  public static void injectServiceInstance(
    DonationAcknowledgementServiceImpl service
  ) {
    DonationAcknowledgementService.setServiceInstance(service);
  }

  /**
   * Reset the DonationAcknowledgementService facade to its default instance
   */
  public static void resetServiceInstance() {
    DonationAcknowledgementService.resetServiceInstance();
  }
}
