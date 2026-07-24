public with sharing class DonationAcknowledgementService {
  // Wrapper class for Invocable input
  public class OpportunityIdWrapper {
    @InvocableVariable(required=true)
    public List<Id> opportunityIds;
  }

  // Enhanced wrapper class for Invocable output with detailed results
  public class DetailedAckResultWrapper {
    @InvocableVariable
    public Integer totalOpportunities;
    @InvocableVariable
    public Integer emailsSent;
    @InvocableVariable
    public Integer alreadyAcknowledged;
    @InvocableVariable
    public Integer noValidContact;
    @InvocableVariable
    public Integer emailSendFailures;
    @InvocableVariable
    public String emailType;
    @InvocableVariable
    public String summaryMessage;
    @InvocableVariable
    public List<OpportunityResultWrapper> opportunityDetails;
  }

  // Individual opportunity results wrapper for Flow consumption
  public class OpportunityResultWrapper {
    @InvocableVariable
    public String opportunityId;
    @InvocableVariable
    public String opportunityName;
    @InvocableVariable
    public String status;
    @InvocableVariable
    public String reason;
    @InvocableVariable
    public String contactEmail;
    @InvocableVariable
    public String acknowledgmentDate;
    @InvocableVariable
    public Boolean isSuccess;
    @InvocableVariable
    public Boolean isSkipped;
    @InvocableVariable
    public Boolean isFailed;
  }

  // Facade delegates to implementation class for business logic
  // Instance variables for template devname and folder are now in implementation class

  // Static instance of implementation
  private static DonationAcknowledgementServiceImpl serviceInstance;

  static {
    resetServiceInstance();
  }

  // Test support methods for dependency injection
  @TestVisible
  public static void setServiceInstance(
    DonationAcknowledgementServiceImpl instance
  ) {
    serviceInstance = instance;
  }

  @TestVisible
  public static void resetServiceInstance() {
    serviceInstance = new DonationAcknowledgementServiceImpl();
  }

  /**
   * Invocable method for Flows and list view buttons with detailed results
   * @param inputList List of OpportunityIdWrapper
   * @return List of DetailedAckResultWrapper with comprehensive acknowledgement data
   */
  @InvocableMethod(
    label='Send Donation Acknowledgements (Enhanced)'
    description='Send acknowledgement emails for donations with detailed results for Flow processing'
  )
  public static List<DetailedAckResultWrapper> sendAcknowledgementsInvocable(
    List<OpportunityIdWrapper> inputList
  ) {
    List<Id> idList = serviceInstance.extractOpportunityIds(inputList);
    List<DetailedAckResultWrapper> results = new List<DetailedAckResultWrapper>();
    AckDetailedResult detailedResult = serviceInstance.sendAcknowledgementsDetailed(
      idList
    );
    DetailedAckResultWrapper flowResult = serviceInstance.convertToFlowWrapper(
      detailedResult
    );
    System.debug(LoggingLevel.INFO, flowResult.summaryMessage);
    results.add(flowResult);
    return results;
  }

  /**
   * Enhanced AuraEnabled method that returns detailed results for advanced consumers (LWC)
   * @param idList List of Opportunity IDs to process
   * @return DetailedAckResult with individual opportunity tracking and aggregated counts
   */
  @AuraEnabled
  public static AckDetailedResult sendAcknowledgementsDetailed(
    List<Id> idList
  ) {
    return serviceInstance.sendAcknowledgementsDetailed(idList);
  }

  /**
   * Method to get individual opportunity results for LWC consumption
   * @param idList List of Opportunity IDs to process
   * @return List of OpportunityResult with detailed status and reason for each opportunity
   */
  @AuraEnabled
  public static List<AckOpportunityResult> getOpportunityResults(
    List<Id> idList
  ) {
    AckDetailedResult detailedResult = serviceInstance.sendAcknowledgementsDetailed(
      idList
    );
    return detailedResult.opportunityResults;
  }
}
