/**
 * Implementation class for donation acknowledgement business logic.
 * This class contains the core functionality that was previously in DonationAcknowledgementService.
 * Part of the Facade pattern implementation - DonationAcknowledgementService delegates here.
 *
 * The send pipeline (validate -> prepareEmails -> sendEmails -> updateRecords) is
 * implemented as private methods threading a single AckContext through each step,
 * rather than a chain of single-use command objects.
 *
 * Supports dependency injection through mutable instance variables:
 * - donationAckTemplateDevName: Template developer name for email templates
 * - donationAckTemplateFolder: Folder developer name for email templates
 * - emailService: Email service implementation for sending emails
 * - orgWideEmailService: Org-wide email address lookup implementation
 */
public with sharing class DonationAcknowledgementServiceImpl {
  // Instance variables for template configuration with default values
  @TestVisible
  public String donationAckTemplateDevName = 'HTML_Donation_Acknowledgement';
  @TestVisible
  public String donationAckTemplateFolder = 'EnhancedDonationAcknowledgements';

  // Mutable instance variables for dependency injection
  @TestVisible
  public IEmailService emailService = new EmailService();
  @TestVisible
  public IOrgWideEmailService orgWideEmailService = new OrgWideEmailService();

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
   *
   * Orchestrates the pipeline by threading a single AckContext through each stage:
   * validate -> prepareEmails -> sendEmails -> updateRecords, then folds the final
   * per-opportunity statuses into the aggregated result.
   */
  @TestVisible
  public AckDetailedResult sendEmailsCoreDetailed(
    List<Opportunity> opps,
    AckEmailConfig config
  ) {
    AckContext ctx = new AckContext(opps, config);

    validate(ctx);
    prepareEmails(ctx);
    sendEmails(ctx);
    updateRecords(ctx);

    // Aggregate all results (successes AND failures) into the final DetailedAckResult.
    // By this point each AckOpportunityResult's status is final - sendEmails() and,
    // if it ran, updateRecords() have already mutated status in place - so there is
    // no need to branch on an overall success flag here.
    for (AckOpportunityResult oppResult : ctx.preparedResults) {
      ctx.result.addOpportunityResult(oppResult);
    }
    ctx.result.emailType = config.emailType;

    return ctx.result;
  }

  /**
   * Validate opportunities and filter out those that should be skipped.
   * Queries Contacts once for every opportunity's npsp__Primary_Contact__c and
   * stores the map on ctx for reuse by prepareEmails(). For each opportunity that
   * passes validation, builds its AckOpportunityResult (with contactEmail set) and
   * appends it to ctx.preparedResults; ctx.opportunities is narrowed in place to
   * just the valid opportunities, index-aligned with ctx.preparedResults. Skipped
   * opportunities are added directly to ctx.result.
   */
  private void validate(AckContext ctx) {
    Set<Id> contactIds = new Set<Id>();
    for (Opportunity opp : ctx.opportunities) {
      if (opp.npsp__Primary_Contact__c != null) {
        contactIds.add(opp.npsp__Primary_Contact__c);
      }
    }
    ctx.contactMap = new Map<Id, Contact>(
      [SELECT Id, Email FROM Contact WHERE Id IN :contactIds]
    );

    List<Opportunity> validOpportunities = new List<Opportunity>();

    for (Opportunity opp : ctx.opportunities) {
      AckOpportunityResult oppResult = new AckOpportunityResult(
        opp.Id,
        opp.Name
      );

      // Check if already acknowledged
      if (opp.npsp__Acknowledgment_Date__c != null) {
        oppResult.setStatus(
          AckStatus.ALREADY_ACKNOWLEDGED,
          'Opportunity already acknowledged on ' +
          opp.npsp__Acknowledgment_Date__c.format()
        );
        ctx.result.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.INFO,
          'Skipping already acknowledged opportunity: ' + opp.Name
        );
        continue;
      }

      // Check if has contact
      if (opp.npsp__Primary_Contact__c == null) {
        oppResult.setStatus(
          AckStatus.NO_CONTACT,
          'Opportunity has no associated Contact'
        );
        ctx.result.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Opportunity ' + opp.Id + ' has no npsp__Primary_Contact__c.'
        );
        continue;
      }

      Contact contact = ctx.contactMap.get(opp.npsp__Primary_Contact__c);
      if (contact == null) {
        oppResult.setStatus(AckStatus.NO_CONTACT, 'Contact not found');
        ctx.result.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Contact not found for Opportunity ' + opp.Id
        );
        continue;
      }

      // Check if contact has email
      if (String.isBlank(contact.Email)) {
        oppResult.setStatus(AckStatus.NO_EMAIL, 'Contact has no email address');
        ctx.result.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Contact ' + contact.Id + ' has no email.'
        );
        continue;
      }

      // Opportunity passed validation
      oppResult.contactEmail = contact.Email;
      validOpportunities.add(opp);
      ctx.preparedResults.add(oppResult);
    }

    ctx.opportunities = validOpportunities;
  }

  /**
   * Prepare email messages for the valid opportunities left on ctx by validate().
   * Reuses ctx.contactMap rather than re-querying Contacts. ctx.opportunities and
   * ctx.preparedResults are index-aligned, so each prepared email is appended to
   * ctx.emails at the same index as its corresponding AckOpportunityResult.
   */
  private void prepareEmails(AckContext ctx) {
    Id orgWideEmailId = getDefaultOrgWideEmailAddressId();

    for (Integer i = 0; i < ctx.opportunities.size(); i++) {
      Opportunity opp = ctx.opportunities[i];
      Contact contact = ctx.contactMap.get(opp.npsp__Primary_Contact__c);

      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      ctx.config.configureEmail(mail, contact, opp);
      if (orgWideEmailId != null) {
        mail.setOrgWideEmailAddressId(orgWideEmailId);
      }

      ctx.emails.add(mail);

      if (ctx.config.useTemplate) {
        System.debug(LoggingLevel.INFO, 'Prepared email: ' + mail);
      }
    }
  }

  /**
   * Send the prepared emails. Never throws for expected failures - each message's
   * success/failure is tracked individually via AckSendResult and reflected back
   * onto the corresponding ctx.preparedResults entry by index (ctx.emails and
   * ctx.preparedResults are index-aligned by construction).
   */
  private void sendEmails(AckContext ctx) {
    if (ctx.emails.isEmpty()) {
      return;
    }

    List<AckSendResult> results = emailService.sendEmail(ctx.emails);
    Date today = Date.today();

    for (Integer i = 0; i < ctx.preparedResults.size(); i++) {
      AckOpportunityResult oppResult = ctx.preparedResults[i];
      AckSendResult sendResult = i < results.size()
        ? results[i]
        : AckSendResult.fail('No send result returned for this message');

      if (sendResult.success) {
        oppResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
        oppResult.acknowledgmentDate = today;
      } else {
        oppResult.setStatus(
          AckStatus.EMAIL_SEND_FAILED,
          'Email sending failed: ' + sendResult.errorMessage
        );
      }
    }
  }

  /**
   * Update opportunity acknowledgment dates in the database for any successfully-sent
   * emails. Runs whenever there is at least one successful send, regardless of whether
   * other messages in the same batch failed. Uses partial-success DML
   * (Database.update with allOrNothing=false) so a DML failure on one record doesn't
   * block the rest. A record whose email sent successfully but whose DB update failed
   * is marked ACK_UPDATE_FAILED rather than being silently left as SUCCESS - the email
   * already went out, so this needs manual attention to avoid a duplicate
   * acknowledgement email later.
   */
  private void updateRecords(AckContext ctx) {
    List<AckOpportunityResult> successfulResults = new List<AckOpportunityResult>();
    for (AckOpportunityResult oppResult : ctx.preparedResults) {
      if (oppResult.isSuccess()) {
        successfulResults.add(oppResult);
      }
    }

    if (successfulResults.isEmpty()) {
      return;
    }

    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    for (AckOpportunityResult oppResult : successfulResults) {
      oppsToUpdate.add(
        new Opportunity(
          Id = oppResult.opportunityId,
          npsp__Acknowledgment_Date__c = oppResult.acknowledgmentDate,
          npsp__Acknowledgment_Status__c = 'Acknowledged'
        )
      );
    }

    List<Database.SaveResult> saveResults = Database.update(
      oppsToUpdate,
      false
    );

    for (Integer i = 0; i < successfulResults.size(); i++) {
      AckOpportunityResult oppResult = successfulResults[i];
      Database.SaveResult saveResult = i < saveResults.size()
        ? saveResults[i]
        : null;

      if (saveResult != null && saveResult.isSuccess()) {
        continue;
      }

      List<String> errors = new List<String>();
      if (saveResult != null) {
        for (Database.Error err : saveResult.getErrors()) {
          errors.add(err.getMessage());
        }
      }
      String errorText = errors.isEmpty()
        ? 'Unknown error'
        : String.join(errors, '; ');

      System.debug(
        LoggingLevel.ERROR,
        'Database update failed for Opportunity ' +
          oppResult.opportunityId +
          ': ' +
          errorText
      );

      oppResult.setStatus(
        AckStatus.ACK_UPDATE_FAILED,
        'Email was sent, but record update failed: ' +
          errorText +
          '. Record needs manual attention to prevent duplicate acknowledgement.'
      );
    }
  }

  /**
   * Helper to get the org-wide email address Id set as the organization's Default No-Reply Address.
   * Returns null if none is configured as default.
   * See: https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_orgwideemailaddress.htm
   */
  @TestVisible
  private Id getDefaultOrgWideEmailAddressId() {
    OrgWideEmailAddress defaultNoReply = orgWideEmailService.getDefaultNoReplyAddress();
    if (defaultNoReply == null) {
      System.debug(
        LoggingLevel.WARN,
        'No org-wide email address is configured as Default No-Reply Address.'
      );
      return null;
    }
    return defaultNoReply.Id;
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
