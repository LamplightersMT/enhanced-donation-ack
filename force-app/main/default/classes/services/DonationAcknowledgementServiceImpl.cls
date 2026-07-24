/**
 * Implementation class for donation acknowledgement business logic.
 * This class contains the core functionality that was previously in DonationAcknowledgementService.
 * Part of Facade + Command pattern implementation.
 *
 * Supports dependency injection through mutable instance variables:
 * - donationAckTemplateDevName: Template developer name for email templates
 * - donationAckTemplateFolder: Folder developer name for email templates
 * - emailService: Email service implementation for sending emails
 */
public with sharing class DonationAcknowledgementServiceImpl {
  // Instance variables for template configuration with default values
  @TestVisible
  public String donationAckTemplateDevName = 'HTML_Donation_Acknowledgement';
  @TestVisible
  public String donationAckTemplateFolder = 'EnhancedDonationAcknowledgements';

  // Mutable instance variable for dependency injection
  @TestVisible
  public IEmailService emailService = new EmailService();

  /**
   * Default constructor initializes instance variables with default values
   */
  public DonationAcknowledgementServiceImpl() {
    // Instance variables are initialized with defaults above
  }

  /**
   * Shared logic to process Opportunities by Ids
   */
  public List<Opportunity> getOpportunitiesByIds(List<Id> idList) {
    if (idList == null || idList.isEmpty()) {
      return new List<Opportunity>();
    }
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
        npsp__Acknowledgment_Status__c // Added field
      FROM Opportunity
      WHERE Id IN :idList
    ];
  }

  /**
   * Helper to extract opportunity IDs from wrapper input, flattening and filtering nulls
   */
  public List<Id> extractOpportunityIds(
    List<DonationAcknowledgementService.OpportunityIdWrapper> inputList
  ) {
    List<Id> idList = new List<Id>();
    for (DonationAcknowledgementService.OpportunityIdWrapper w : inputList) {
      if (w != null && w.opportunityIds != null) {
        for (Id idVal : w.opportunityIds) {
          if (idVal != null) {
            idList.add(idVal);
          }
        }
      }
    }
    return idList;
  }

  /**
   * Convert DetailedAckResult to Flow-compatible DetailedAckResultWrapper
   */
  public DonationAcknowledgementService.DetailedAckResultWrapper convertToFlowWrapper(
    AckDetailedResult detailedResult
  ) {
    DonationAcknowledgementService.DetailedAckResultWrapper flowResult = new DonationAcknowledgementService.DetailedAckResultWrapper();

    // Copy aggregate data
    flowResult.totalOpportunities = detailedResult.totalOpportunities;
    flowResult.emailsSent = detailedResult.emailsSent;
    flowResult.alreadyAcknowledged = detailedResult.alreadyAcknowledged;
    flowResult.noValidContact = detailedResult.noValidContact;
    flowResult.emailSendFailures = detailedResult.emailSendFailures;
    flowResult.ackUpdateFailures = detailedResult.ackUpdateFailures;
    flowResult.emailType = detailedResult.emailType;
    flowResult.summaryMessage = detailedResult.buildSummaryMessage();

    // Convert individual opportunity results
    flowResult.opportunityDetails = new List<DonationAcknowledgementService.OpportunityResultWrapper>();
    for (AckOpportunityResult oppResult : detailedResult.opportunityResults) {
      DonationAcknowledgementService.OpportunityResultWrapper flowOppResult = new DonationAcknowledgementService.OpportunityResultWrapper();
      flowOppResult.opportunityId = String.valueOf(oppResult.opportunityId);
      flowOppResult.opportunityName = oppResult.opportunityName;
      flowOppResult.status = String.valueOf(oppResult.status);
      flowOppResult.reason = oppResult.reason;
      flowOppResult.contactEmail = oppResult.contactEmail;
      flowOppResult.acknowledgmentDate = oppResult.acknowledgmentDate != null
        ? oppResult.acknowledgmentDate.format()
        : null;
      flowOppResult.isSuccess = oppResult.isSuccess();
      flowOppResult.isSkipped = oppResult.isSkipped();
      flowOppResult.isFailed = oppResult.isFailed();

      flowResult.opportunityDetails.add(flowOppResult);
    }

    return flowResult;
  }

  /**
   * Enhanced implementation that returns detailed results for advanced consumers (LWC)
   * @param idList List of Opportunity IDs to process
   * @return DetailedAckResult with individual opportunity tracking and aggregated counts
   */
  public AckDetailedResult sendAcknowledgementsDetailed(List<Id> idList) {
    List<Opportunity> opps = getOpportunitiesByIds(idList);
    if (opps.isEmpty()) {
      AckDetailedResult emptyResult = new AckDetailedResult();
      emptyResult.emailType = 'No opportunities provided';
      return emptyResult;
    }
    AckDetailedResult result;
    AckEmailConfig config = getEmailConfiguration();
    result = sendEmailsCoreDetailed(opps, config);
    result.emailType = config.emailType;
    return result;
  }

  /**
   * Core email sending logic with detailed individual opportunity tracking.
   * Returns DetailedAckResult with specific status and reason codes for each opportunity.
   * Now implemented using Command pattern for better separation of concerns.
   */
  @TestVisible
  public AckDetailedResult sendEmailsCoreDetailed(
    List<Opportunity> opps,
    AckEmailConfig config
  ) {
    AckDetailedResult detailedResult = new AckDetailedResult();

    // Command orchestration - each command handles a specific responsibility

    // 1. Validate opportunities and filter out those that should be skipped
    OpportunityValidationCommand validationCmd = new OpportunityValidationCommand(
      opps,
      detailedResult
    );
    validationCmd.execute();
    List<Opportunity> validOpps = validationCmd.getValidOpportunities();

    // 2. Prepare emails for valid opportunities
    EmailPreparationCommand prepCmd = new EmailPreparationCommand(
      validOpps,
      config
    );
    prepCmd.execute();
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput = prepCmd.getOutput();

    // 3. Send prepared emails
    EmailSendCommand sendCmd = new EmailSendCommand(
      prepOutput.emails,
      prepOutput.validOpportunities
    );
    // Inject emailService for testing
    sendCmd.emailService = this.emailService;
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput sendOutput = sendCmd.getOutput();

    // 4. Update database with acknowledgment dates for any successfully-sent emails.
    // Runs whenever there is at least one successful send, regardless of whether
    // other messages in the same batch failed.
    AcknowledgementCommandOutputs.UpdateOutput updateOutput = null;
    if (!sendOutput.successfulOpportunities.isEmpty()) {
      DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(
        sendOutput.successfulOpportunities
      );
      updateCmd.execute();
      updateOutput = updateCmd.getOutput();
    }

    // 5. Aggregate all results (successes AND failures) into final DetailedAckResult
    ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
      detailedResult,
      prepOutput,
      sendOutput,
      updateOutput,
      config.emailType
    );
    aggregationCmd.execute();

    return detailedResult;
  }

  /**
   * Get email configuration with proper exception handling for template lookup
   * @return EmailConfig configured with template or static fallback
   */
  private AckEmailConfig getEmailConfiguration() {
    try {
      EmailTemplate tmpl = [
        SELECT Id
        FROM EmailTemplate
        WHERE
          DeveloperName = :donationAckTemplateDevName
          AND Folder.DeveloperName = :donationAckTemplateFolder
        LIMIT 1
      ];
      AckEmailConfig config = new AckEmailConfig(tmpl.Id);
      config.emailType = 'Template used: ' + donationAckTemplateDevName;
      return config;
    } catch (QueryException qe) {
      System.debug(
        LoggingLevel.WARN,
        'EmailTemplate not found: ' + qe.getMessage()
      );
      return getStaticEmailConfiguration();
    } catch (System.Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Unexpected error accessing EmailTemplate: ' + ex.getMessage()
      );
      return getStaticEmailConfiguration();
    }
  }

  /**
   * Get static email configuration as fallback
   * @return EmailConfig with static content
   */
  private AckEmailConfig getStaticEmailConfiguration() {
    String subject = 'Thank you for your donation!';
    String body = 'We appreciate your generous support.';
    AckEmailConfig config = new AckEmailConfig(subject, body);
    config.emailType = 'Static content fallback';
    return config;
  }
}
