/**
 * Implementation class for donation acknowledgement business logic.
 * This class contains the core functionality that was previously in DonationAcknowledgementService.
 * Part of Facade + Command pattern implementation.
 */
public with sharing class DonationAcknowledgementServiceImpl {
  // Instance variables for template devname and folder, default to current values
  @TestVisible
  public static String donationAckTemplateDevName = 'HTML_Donation_Acknowledgement';
  @TestVisible
  public static String donationAckTemplateFolder = 'EnhancedDonationAcknowledgements';

  /**
   * Shared logic to process Opportunities by Ids
   */
  public static List<Opportunity> getOpportunitiesByIds(List<Id> idList) {
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
        ContactId,
        npsp__Acknowledgment_Date__c
      FROM Opportunity
      WHERE Id IN :idList
    ];
  }

  /**
   * Helper to extract opportunity IDs from wrapper input, flattening and filtering nulls
   */
  public static List<Id> extractOpportunityIds(
    List<DonationAcknowledgementService.OpportunityIdWrapper> inputList
  ) {
    List<Id> idList = new List<Id>();

    // Flatten all Opportunity Ids from the input wrappers, ignoring nulls
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
  public static DonationAcknowledgementService.DetailedAckResultWrapper convertToFlowWrapper(
    DonationAcknowledgementService.DetailedAckResult detailedResult
  ) {
    DonationAcknowledgementService.DetailedAckResultWrapper flowResult = new DonationAcknowledgementService.DetailedAckResultWrapper();

    // Copy aggregate data
    flowResult.totalOpportunities = detailedResult.totalOpportunities;
    flowResult.emailsSent = detailedResult.emailsSent;
    flowResult.alreadyAcknowledged = detailedResult.alreadyAcknowledged;
    flowResult.noValidContact = detailedResult.noValidContact;
    flowResult.emailSendFailures = detailedResult.emailSendFailures;
    flowResult.emailType = detailedResult.emailType;
    flowResult.summaryMessage = detailedResult.buildSummaryMessage();

    // Convert individual opportunity results
    flowResult.opportunityDetails = new List<DonationAcknowledgementService.OpportunityResultWrapper>();
    for (
      DonationAcknowledgementService.OpportunityResult oppResult : detailedResult.opportunityResults
    ) {
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
  public static DonationAcknowledgementService.DetailedAckResult sendAcknowledgementsDetailed(
    List<Id> idList
  ) {
    List<Opportunity> opps = getOpportunitiesByIds(idList);
    if (opps.isEmpty()) {
      DonationAcknowledgementService.DetailedAckResult emptyResult = new DonationAcknowledgementService.DetailedAckResult();
      emptyResult.emailType = 'No opportunities provided';
      return emptyResult;
    }

    DonationAcknowledgementService.DetailedAckResult result;
    DonationAcknowledgementService.EmailConfig config = getEmailConfiguration();
    result = sendEmailsCoreDetailed(opps, config);
    result.emailType = config.emailType;
    return result;
  }

  /**
   * Helper to get the default org-wide email address Id (first active one, or null if none found)
   */
  private static Id getDefaultOrgWideEmailAddressId() {
    // TODO: Is there a way to configure or identify this?
    OrgWideEmailAddress[] orgWideEmails = [
      SELECT Id
      FROM OrgWideEmailAddress
      ORDER BY Address ASC
      LIMIT 1
    ];
    return orgWideEmails.isEmpty() ? null : orgWideEmails[0].Id;
  }

  /**
   * Core email sending logic with detailed individual opportunity tracking.
   * Returns DetailedAckResult with specific status and reason codes for each opportunity.
   * Now implemented using Command pattern for better separation of concerns.
   */
  @TestVisible
  public static DonationAcknowledgementService.DetailedAckResult sendEmailsCoreDetailed(
    List<Opportunity> opps,
    DonationAcknowledgementService.EmailConfig config
  ) {
    DonationAcknowledgementService.DetailedAckResult detailedResult = new DonationAcknowledgementService.DetailedAckResult();

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
    sendCmd.execute();
    AcknowledgementCommandOutputs.SendOutput sendOutput = sendCmd.getOutput();

    // 4. Update database with acknowledgment dates for successful sends
    if (sendOutput.isSuccess && !sendOutput.successfulOpportunities.isEmpty()) {
      DatabaseUpdateCommand updateCmd = new DatabaseUpdateCommand(
        sendOutput.successfulOpportunities
      );
      updateCmd.execute();
      AcknowledgementCommandOutputs.UpdateOutput updateOutput = updateCmd.getOutput();

      // 5. Aggregate all results into final DetailedAckResult
      ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
        detailedResult,
        prepOutput,
        sendOutput,
        updateOutput,
        config.emailType
      );
      aggregationCmd.execute();
    } else {
      // Handle failed sends - still need to aggregate results
      ResultAggregationCommand aggregationCmd = new ResultAggregationCommand(
        detailedResult,
        prepOutput,
        sendOutput,
        null,
        config.emailType
      );
      aggregationCmd.execute();
    }

    return detailedResult;
  }

  /**
   * Get email configuration with proper exception handling for template lookup
   * @return EmailConfig configured with template or static fallback
   */
  private static DonationAcknowledgementService.EmailConfig getEmailConfiguration() {
    try {
      EmailTemplate tmpl = [
        SELECT Id
        FROM EmailTemplate
        WHERE
          DeveloperName = :donationAckTemplateDevName
          AND Folder.DeveloperName = :donationAckTemplateFolder
        LIMIT 1
      ];
      DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
        tmpl.Id
      );
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
  private static DonationAcknowledgementService.EmailConfig getStaticEmailConfiguration() {
    String subject = 'Thank you for your donation!';
    String body = 'We appreciate your generous support.';
    DonationAcknowledgementService.EmailConfig config = new DonationAcknowledgementService.EmailConfig(
      subject,
      body
    );
    config.emailType = 'Static content fallback';
    return config;
  }
}
