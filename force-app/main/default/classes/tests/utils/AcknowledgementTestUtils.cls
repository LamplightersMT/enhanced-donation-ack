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
   * Build (but do not insert) a test opportunity with specified parameters.
   * Use this together with insertTestOpportunities() to bulk-insert several
   * opportunities in a single DML statement. NPSP's Primary Contact Role sync
   * automation (triggered by writing npsp__Primary_Contact__c) recalculates
   * rollups per DML statement rather than per record - inserting several
   * opportunities for the same Contact/Account one at a time (multiple
   * individual `insert opp;` statements in one test method) can blow through
   * the 100 SOQL query governor limit. Bulk-inserting avoids that.
   */
  public static Opportunity buildTestOpportunity(
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
      npsp__Primary_Contact__c = contact != null ? contact.Id : null
    );
    if (ackDate != null) {
      opp.npsp__Acknowledgment_Date__c = ackDate;
    }
    return opp;
  }

  /**
   * Bulk-insert a list of opportunities built with buildTestOpportunity().
   * See buildTestOpportunity() for why this matters with NPSP installed.
   */
  public static List<Opportunity> insertTestOpportunities(
    List<Opportunity> opps
  ) {
    insert opps;
    return opps;
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
    Opportunity opp = buildTestOpportunity(name, contact, ackDate, amount);
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
        npsp__Primary_Contact__c,
        npsp__Acknowledgment_Date__c,
        npsp__Acknowledgment_Status__c
      FROM Opportunity
      WHERE Id IN :oppIds
    ];
  }

  /**
   * Query opportunity with acknowledgment status field
   */
  public static Opportunity queryOpportunityWithAckStatus(Id oppId) {
    return [
      SELECT Id, npsp__Acknowledgment_Status__c
      FROM Opportunity
      WHERE Id = :oppId
      LIMIT 1
    ];
  }

  /**
   * Query opportunities with acknowledgment status field
   */
  public static List<Opportunity> queryOpportunitiesWithAckStatus(
    List<Id> oppIds
  ) {
    return [
      SELECT Id, Name, npsp__Acknowledgment_Status__c
      FROM Opportunity
      WHERE Id IN :oppIds
      ORDER BY Name
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
   * Assert that acknowledgment status is set to a specific value
   */
  public static void assertAcknowledgmentStatusSet(
    Id oppId,
    String expectedStatus
  ) {
    Opportunity updatedOpp = queryOpportunityWithAckStatus(oppId);
    System.assertEquals(
      expectedStatus,
      updatedOpp.npsp__Acknowledgment_Status__c,
      'Acknowledgment status should be set to expected value'
    );
  }

  /**
   * Assert common detailed result counts
   */
  public static void assertDetailedResultCounts(
    AckDetailedResult result,
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
  public static Map<String, AckOpportunityResult> createResultsByNameMap(
    List<AckOpportunityResult> results
  ) {
    Map<String, AckOpportunityResult> resultsByName = new Map<String, AckOpportunityResult>();
    for (AckOpportunityResult result : results) {
      resultsByName.put(result.opportunityName, result);
    }
    return resultsByName;
  }

  /**
   * Assert opportunity result by name with expected status and partial reason match
   */
  public static void assertOpportunityResult(
    Map<String, AckOpportunityResult> resultsByName,
    String oppName,
    AckStatus expectedStatus,
    String reasonContains
  ) {
    AckOpportunityResult result = resultsByName.get(oppName);
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
