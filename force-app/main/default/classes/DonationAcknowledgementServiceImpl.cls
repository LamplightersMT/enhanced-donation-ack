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
   */
  @TestVisible
  public static DonationAcknowledgementService.DetailedAckResult sendEmailsCoreDetailed(
    List<Opportunity> opps,
    DonationAcknowledgementService.EmailConfig config
  ) {
    DonationAcknowledgementService.DetailedAckResult detailedResult = new DonationAcknowledgementService.DetailedAckResult();

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<DonationAcknowledgementService.OpportunityResult> successfulOpps = new List<DonationAcknowledgementService.OpportunityResult>();
    Id orgWideEmailId = getDefaultOrgWideEmailAddressId();

    // Bulk query for all Contacts related to the Opportunities
    Set<Id> contactIds = new Set<Id>();
    for (Opportunity opp : opps) {
      if (opp.ContactId != null) {
        contactIds.add(opp.ContactId);
      }
    }
    Map<Id, Contact> contactMap = new Map<Id, Contact>(
      [SELECT Id, Email FROM Contact WHERE Id IN :contactIds]
    );

    // Process each opportunity individually with detailed tracking
    for (Opportunity opp : opps) {
      DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
        opp.Id,
        opp.Name
      );

      // Check if already acknowledged
      if (opp.npsp__Acknowledgment_Date__c != null) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.ALREADY_ACKNOWLEDGED,
          'Opportunity already acknowledged on ' +
          opp.npsp__Acknowledgment_Date__c.format()
        );
        detailedResult.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.INFO,
          'Skipping already acknowledged opportunity: ' + opp.Name
        );
        continue;
      }

      // Check if has contact
      if (opp.ContactId == null) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.NO_CONTACT,
          'Opportunity has no associated Contact'
        );
        detailedResult.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Opportunity ' + opp.Id + ' has no ContactId.'
        );
        continue;
      }

      Contact contact = contactMap.get(opp.ContactId);
      if (contact == null) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.NO_CONTACT,
          'Contact not found'
        );
        detailedResult.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Contact not found for Opportunity ' + opp.Id
        );
        continue;
      }

      // Check if contact has email
      if (String.isBlank(contact.Email)) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.NO_EMAIL,
          'Contact has no email address'
        );
        detailedResult.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Contact ' + contact.Id + ' has no email.'
        );
        continue;
      }

      // Prepare email for sending
      oppResult.contactEmail = contact.Email;
      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      config.configureEmail(mail, contact, opp);
      if (orgWideEmailId != null) {
        mail.setOrgWideEmailAddressId(orgWideEmailId);
      }

      emails.add(mail);
      successfulOpps.add(oppResult);

      if (config.useTemplate) {
        System.debug(LoggingLevel.INFO, 'Prepared email: ' + mail);
      }
    }

    // Send emails if any are prepared
    if (!emails.isEmpty()) {
      try {
        Messaging.sendEmail(emails);

        // Mark all prepared opportunities as successful and update acknowledgment dates
        Date today = Date.today();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (
          DonationAcknowledgementService.OpportunityResult oppResult : successfulOpps
        ) {
          oppResult.setStatus(
            DonationAcknowledgementService.AckStatus.SUCCESS,
            'Email sent successfully'
          );
          oppResult.acknowledgmentDate = today;
          detailedResult.addOpportunityResult(oppResult);

          oppsToUpdate.add(
            new Opportunity(
              Id = oppResult.opportunityId,
              npsp__Acknowledgment_Date__c = today
            )
          );
        }

        if (!oppsToUpdate.isEmpty()) {
          update oppsToUpdate;
        }
      } catch (EmailException ee) {
        System.debug(
          LoggingLevel.ERROR,
          'Email sending failed: ' + ee.getMessage()
        );

        // Mark all prepared opportunities as failed
        for (
          DonationAcknowledgementService.OpportunityResult oppResult : successfulOpps
        ) {
          oppResult.setStatus(
            DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
            'Email sending failed: ' + ee.getMessage()
          );
          detailedResult.addOpportunityResult(oppResult);
        }

        throw new AuraHandledException(
          'Failed to send acknowledgement emails: ' + ee.getMessage()
        );
      } catch (DmlException de) {
        System.debug(
          LoggingLevel.ERROR,
          'Database update failed: ' + de.getMessage()
        );

        // Mark all prepared opportunities as failed
        for (
          DonationAcknowledgementService.OpportunityResult oppResult : successfulOpps
        ) {
          oppResult.setStatus(
            DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
            'Database update failed: ' + de.getMessage()
          );
          detailedResult.addOpportunityResult(oppResult);
        }

        throw new AuraHandledException(
          'Failed to update acknowledgement dates: ' + de.getMessage()
        );
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'Unexpected error during email processing: ' + e.getMessage()
        );

        // Mark all prepared opportunities as failed
        for (
          DonationAcknowledgementService.OpportunityResult oppResult : successfulOpps
        ) {
          oppResult.setStatus(
            DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
            'Unexpected error: ' + e.getMessage()
          );
          detailedResult.addOpportunityResult(oppResult);
        }

        throw new AuraHandledException(
          'Failed to send acknowledgement emails: ' + e.getMessage()
        );
      }
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
