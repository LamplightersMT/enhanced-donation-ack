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

  // Enum for acknowledgement status codes
  public enum AckStatus {
    SUCCESS,
    ALREADY_ACKNOWLEDGED,
    NO_CONTACT,
    NO_EMAIL,
    EMAIL_SEND_FAILED,
    INVALID_OPPORTUNITY
  }

  // Individual opportunity result with detailed tracking
  // TODO: This is growing in importance, we might want to rename it
  @TestVisible
  public class OpportunityResult {
    @AuraEnabled
    public Id opportunityId;
    @AuraEnabled
    public String opportunityName;
    @AuraEnabled
    public AckStatus status;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public String contactEmail;
    @AuraEnabled
    public Date acknowledgmentDate;

    public OpportunityResult(Id oppId, String oppName) {
      this.opportunityId = oppId;
      this.opportunityName = oppName;
    }

    public void setStatus(AckStatus status, String reason) {
      this.status = status;
      this.reason = reason;
    }

    public Boolean isSuccess() {
      return this.status == AckStatus.SUCCESS;
    }

    public Boolean isSkipped() {
      return this.status == AckStatus.ALREADY_ACKNOWLEDGED ||
        this.status == AckStatus.NO_CONTACT ||
        this.status == AckStatus.NO_EMAIL;
    }

    public Boolean isFailed() {
      return this.status == AckStatus.EMAIL_SEND_FAILED ||
        this.status == AckStatus.INVALID_OPPORTUNITY;
    }
  }

  // Detailed acknowledgement result with individual opportunity tracking
  @TestVisible
  public class DetailedAckResult {
    @AuraEnabled
    public Integer totalOpportunities;
    @AuraEnabled
    public Integer emailsSent;
    @AuraEnabled
    public Integer alreadyAcknowledged;
    @AuraEnabled
    public Integer noValidContact;
    @AuraEnabled
    public Integer emailSendFailures;
    @AuraEnabled
    public List<OpportunityResult> opportunityResults;
    @AuraEnabled
    public String emailType;

    public DetailedAckResult() {
      this.totalOpportunities = 0;
      this.emailsSent = 0;
      this.alreadyAcknowledged = 0;
      this.noValidContact = 0;
      this.emailSendFailures = 0;
      this.opportunityResults = new List<OpportunityResult>();
    }

    public void addOpportunityResult(OpportunityResult oppResult) {
      this.opportunityResults.add(oppResult);
      this.totalOpportunities++;

      if (oppResult.isSuccess()) {
        this.emailsSent++;
      } else if (oppResult.status == AckStatus.ALREADY_ACKNOWLEDGED) {
        this.alreadyAcknowledged++;
      } else if (
        oppResult.status == AckStatus.NO_CONTACT ||
        oppResult.status == AckStatus.NO_EMAIL
      ) {
        this.noValidContact++;
      } else if (oppResult.status == AckStatus.EMAIL_SEND_FAILED) {
        this.emailSendFailures++;
      }
    }

    public String buildSummaryMessage() {
      String message =
        'sendAcknowledgements called with ' +
        totalOpportunities +
        ' Opportunities. ';
      message += 'Emails sent: ' + emailsSent;

      if (alreadyAcknowledged > 0) {
        message += ', Already acknowledged: ' + alreadyAcknowledged;
      }

      if (noValidContact > 0) {
        message += ', No valid contact: ' + noValidContact;
      }

      if (emailSendFailures > 0) {
        message += ', Email send failures: ' + emailSendFailures;
      }

      if (emailType != null) {
        message += ' (' + emailType + ')';
      }

      return message;
    }

    public List<OpportunityResult> getSuccessfulResults() {
      List<OpportunityResult> successful = new List<OpportunityResult>();
      for (OpportunityResult result : opportunityResults) {
        if (result.isSuccess()) {
          successful.add(result);
        }
      }
      return successful;
    }

    public List<OpportunityResult> getSkippedResults() {
      List<OpportunityResult> skipped = new List<OpportunityResult>();
      for (OpportunityResult result : opportunityResults) {
        if (result.isSkipped()) {
          skipped.add(result);
        }
      }
      return skipped;
    }

    public List<OpportunityResult> getFailedResults() {
      List<OpportunityResult> failed = new List<OpportunityResult>();
      for (OpportunityResult result : opportunityResults) {
        if (result.isFailed()) {
          failed.add(result);
        }
      }
      return failed;
    }
  }

  // Email configuration class to eliminate code duplication
  @TestVisible
  public class EmailConfig {
    public Id templateId;
    public String subject;
    public String body;
    public Boolean useTemplate;
    public String emailType;

    // Constructor for template-based emails
    public EmailConfig(Id templateId) {
      this.templateId = templateId;
      this.useTemplate = true;
    }

    // Constructor for static content emails
    public EmailConfig(String subject, String body) {
      this.subject = subject;
      this.body = body;
      this.useTemplate = false;
    }

    // Configure a SingleEmailMessage based on this config
    public void configureEmail(
      Messaging.SingleEmailMessage mail,
      Contact contact,
      Opportunity opp
    ) {
      if (useTemplate) {
        mail.setTemplateId(templateId);
        mail.setTargetObjectId(contact.Id);
      } else {
        mail.setToAddresses(new List<String>{ contact.Email });
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        mail.setTargetObjectId(contact.Id); // for compliance
      }
      mail.setWhatId(opp.Id); // ensures EmailMessage is created and related
    }
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
    DetailedAckResult detailedResult = serviceInstance.sendAcknowledgementsDetailed(
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
  public static DetailedAckResult sendAcknowledgementsDetailed(
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
  public static List<OpportunityResult> getOpportunityResults(List<Id> idList) {
    DetailedAckResult detailedResult = serviceInstance.sendAcknowledgementsDetailed(
      idList
    );
    return detailedResult.opportunityResults;
  }
}
