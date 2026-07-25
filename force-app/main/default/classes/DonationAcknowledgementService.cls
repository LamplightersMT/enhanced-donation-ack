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
    public Integer ackUpdateFailures;
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
    List<DetailedAckResultWrapper> results = new List<DetailedAckResultWrapper>();
    DetailedAckResultWrapper flowResult;
    try {
      List<Id> idList = serviceInstance.extractOpportunityIds(inputList);
      AckDetailedResult detailedResult = serviceInstance.sendAcknowledgementsDetailed(
        idList
      );
      flowResult = serviceInstance.convertToFlowWrapper(detailedResult);
    } catch (Exception e) {
      // This method must never throw - Flow invocable methods that throw break
      // the running Flow interview. Report the failure in the wrapper instead.
      System.debug(
        LoggingLevel.ERROR,
        'Unexpected error in sendAcknowledgementsInvocable: ' + e.getMessage()
      );
      flowResult = new DetailedAckResultWrapper();
      flowResult.totalOpportunities = 0;
      flowResult.emailsSent = 0;
      flowResult.alreadyAcknowledged = 0;
      flowResult.noValidContact = 0;
      flowResult.emailSendFailures = 0;
      flowResult.ackUpdateFailures = 0;
      flowResult.opportunityDetails = new List<OpportunityResultWrapper>();
      flowResult.summaryMessage =
        'Unexpected error processing donation acknowledgements: ' +
        e.getMessage();
    }
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
    try {
      return serviceInstance.sendAcknowledgementsDetailed(idList);
    } catch (Exception e) {
      // Expected failures (validation, send, DB update) are already captured as
      // per-opportunity statuses on the result object by the underlying commands
      // and never reach this catch. Only truly unexpected exceptions land here.
      System.debug(
        LoggingLevel.ERROR,
        'Unexpected error in sendAcknowledgementsDetailed: ' + e.getMessage()
      );
      throw new AuraHandledException(e.getMessage());
    }
  }
}
