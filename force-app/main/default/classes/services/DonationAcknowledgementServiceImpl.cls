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
 * - orgWideEmailAddress: Optional org-wide email address override
 * - emailService: Email service implementation for sending emails
 * - orgWideEmailService: Org-wide email address lookup implementation
 *
 * Configuration (template dev name/folder, org-wide address) is admin-editable via
 * the Ack_Setting__mdt Custom Metadata Type - see loadAckSettingConfig(). The active
 * record's values (if any) are loaded once per instance, in the constructor, into the
 * hardcoded defaults above. Tests cannot insert Custom Metadata records, so tests that
 * need a different configuration continue to override these fields directly after
 * construction - loadAckSettingConfig() runs before any such override, so it never
 * clobbers a test's explicit assignment.
 */
public with sharing class DonationAcknowledgementServiceImpl {
  // Instance variables for template configuration with default values. These defaults
  // match the shipped Ack_Setting.Default Custom Metadata record, so behavior is
  // unchanged for orgs that deploy it as-is.
  @TestVisible
  public String donationAckTemplateDevName = 'HTML_Donation_Acknowledgement';
  @TestVisible
  public String donationAckTemplateFolder = 'EnhancedDonationAcknowledgements';
  // Optional org-wide email address (as an Address string) to send from. Blank means
  // "use the org's Default No-Reply Address" - see getDefaultOrgWideEmailAddressId().
  @TestVisible
  public String orgWideEmailAddress = '';

  // Tracks whether loadAckSettingConfig() has already run for this instance, so the
  // Ack_Setting__mdt query only ever happens once per instance.
  @TestVisible
  private Boolean ackSettingConfigLoaded = false;

  // Mutable instance variables for dependency injection
  @TestVisible
  public IEmailService emailService = new EmailService();
  @TestVisible
  public IOrgWideEmailService orgWideEmailService = new OrgWideEmailService();

  /**
   * Default constructor initializes instance variables with default values, then loads
   * the active Ack_Setting__mdt record (if any) to override them.
   */
  public DonationAcknowledgementServiceImpl() {
    loadAckSettingConfig();
  }

  /**
   * Loads the active Ack_Setting__mdt record (Active__c = true) into this instance's
   * configuration fields, once per instance. Custom Metadata records are visible in
   * Apex tests without SeeAllData, so the shipped Ack_Setting.Default record is picked
   * up in tests too - but since its values match the hardcoded defaults above, this is
   * not observable. Blank fields on the CMT record are treated as "not configured" and
   * leave the corresponding default in place. If no active record exists, the hardcoded
   * defaults are kept as-is.
   *
   * Deliberately not WITH USER_MODE / no explicit CRUD/FLS check: Ack_Setting__mdt is
   * admin-configured setup metadata (Custom Metadata Type), not user data. End users who
   * lack Setup access to CMT records still need this configuration to resolve so they can
   * send acknowledgements - enforcing user mode here would silently break the feature for
   * non-admin users. Accepted PMD ApexCRUDViolation finding; see docs/ci-setup.md.
   */
  @TestVisible
  @SuppressWarnings('PMD.ApexCRUDViolation')
  private void loadAckSettingConfig() {
    if (ackSettingConfigLoaded) {
      return;
    }
    ackSettingConfigLoaded = true;

    List<Ack_Setting__mdt> settings = [
      SELECT
        Template_DeveloperName__c,
        Template_Folder__c,
        Org_Wide_Email_Address__c
      FROM Ack_Setting__mdt
      WHERE Active__c = TRUE
      LIMIT 1
    ];

    if (settings.isEmpty()) {
      return;
    }

    Ack_Setting__mdt activeSetting = settings[0];
    if (String.isNotBlank(activeSetting.Template_DeveloperName__c)) {
      donationAckTemplateDevName = activeSetting.Template_DeveloperName__c;
    }
    if (String.isNotBlank(activeSetting.Template_Folder__c)) {
      donationAckTemplateFolder = activeSetting.Template_Folder__c;
    }
    if (String.isNotBlank(activeSetting.Org_Wide_Email_Address__c)) {
      orgWideEmailAddress = activeSetting.Org_Wide_Email_Address__c;
    }
  }

  /**
   * Shared logic to process Opportunities by Ids.
   * Throws QueryException when the running user lacks read access to any selected field,
   * because WITH USER_MODE enforces field-level security - callers must catch it and
   * report a permission error rather than letting it escape as an unhandled exception.
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
      WITH USER_MODE
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
    flowResult.configErrors = detailedResult.configErrors;
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
    List<Opportunity> opps = new List<Opportunity>();
    try {
      opps = getOpportunitiesByIds(idList);
    } catch (QueryException e) {
      // WITH USER_MODE throws when the running user lacks read access to any selected
      // field. Report it as a per-opportunity permission error rather than letting it
      // escape to the facade, which would collapse the whole run into one generic
      // AuraHandledException (LWC) or a zeroed-out summary (Flow).
      return buildAccessErrorResult(idList, e);
    }
    if (opps.isEmpty()) {
      AckDetailedResult emptyResult = new AckDetailedResult();
      emptyResult.emailType = 'No opportunities provided';
      return emptyResult;
    }
    AckEmailConfig config = getEmailConfiguration();
    if (config == null) {
      // Hard error: the configured template could not be found. No emails are sent
      // and nothing is thrown - every requested opportunity is reported as
      // CONFIG_ERROR so callers (Flow, LWC) can surface it without a broken run.
      return buildConfigErrorResult(opps);
    }
    AckDetailedResult result = sendEmailsCoreDetailed(opps, config);
    result.emailType = config.emailType;
    return result;
  }

  /**
   * Build a result reporting every one of the given opportunities as CONFIG_ERROR.
   * Used when the configured email template cannot be found - no emails are prepared
   * or sent and no opportunities are updated.
   */
  private AckDetailedResult buildConfigErrorResult(List<Opportunity> opps) {
    String reason =
      'Email template ' +
      donationAckTemplateDevName +
      ' not found in folder ' +
      donationAckTemplateFolder +
      ' - no emails were sent. Check the Ack_Setting configuration.';

    AckDetailedResult result = new AckDetailedResult();
    for (Opportunity opp : opps) {
      AckOpportunityResult oppResult = new AckOpportunityResult(
        opp.Id,
        opp.Name
      );
      oppResult.setStatus(AckStatus.CONFIG_ERROR, reason);
      result.addOpportunityResult(oppResult);
    }
    result.emailType = 'Configuration error';
    return result;
  }

  /**
   * Build a result reporting every requested opportunity as CONFIG_ERROR because the
   * running user lacks the object- or field-level access that WITH USER_MODE enforces.
   * Ids are reported without names because the query that would have supplied the names
   * is the one that failed. No emails are sent and no records are updated.
   */
  private AckDetailedResult buildAccessErrorResult(
    List<Id> idList,
    Exception e
  ) {
    String reason =
      'Insufficient object or field permissions to read the donation records - ' +
      'no emails were sent. Ask your administrator to grant access. Details: ' +
      e.getMessage();

    AckDetailedResult result = new AckDetailedResult();
    for (Id oppId : idList) {
      AckOpportunityResult oppResult = new AckOpportunityResult(oppId, null);
      oppResult.setStatus(AckStatus.CONFIG_ERROR, reason);
      result.addOpportunityResult(oppResult);
    }
    result.emailType = 'Permission error';
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
    try {
      ctx.contactMap = new Map<Id, Contact>(
        [SELECT Id, Email FROM Contact WHERE Id IN :contactIds WITH USER_MODE]
      );
    } catch (QueryException e) {
      // Same WITH USER_MODE contract as getOpportunitiesByIds(): a missing FLS grant on
      // Contact.Email throws rather than nulling the field. No emails have been sent
      // yet, so report every opportunity as a permission error and stop the pipeline
      // cleanly - leaving contactMap empty instead would mislabel this as NO_CONTACT.
      String reason =
        'Insufficient object or field permissions to read the donor Contact records - ' +
        'no emails were sent. Ask your administrator to grant access. Details: ' +
        e.getMessage();
      for (Opportunity opp : ctx.opportunities) {
        AckOpportunityResult oppResult = new AckOpportunityResult(
          opp.Id,
          opp.Name
        );
        oppResult.setStatus(AckStatus.CONFIG_ERROR, reason);
        ctx.result.addOpportunityResult(oppResult);
      }
      ctx.opportunities = new List<Opportunity>();
      return;
    }

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
   *
   * Note that AccessLevel.USER_MODE enforces CRUD/FLS before the DML runs and throws for
   * the whole call rather than reporting per-record SaveResult errors, so that case is
   * caught separately and folded into the same ACK_UPDATE_FAILED reporting.
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

    List<Database.SaveResult> saveResults = new List<Database.SaveResult>();
    try {
      saveResults = Database.update(oppsToUpdate, false, AccessLevel.USER_MODE);
    } catch (Exception e) {
      // AccessLevel.USER_MODE enforces CRUD/FLS as a pre-flight check that throws for
      // the entire call regardless of allOrNothing=false, so no SaveResults come back
      // and no per-record error is available. The emails have already gone out by this
      // point, so every record still has to be reported as ACK_UPDATE_FAILED - letting
      // this escape would strand successfully emailed opportunities with no
      // acknowledgement date and no per-record signal, risking a duplicate send later.
      for (AckOpportunityResult oppResult : successfulResults) {
        System.debug(
          LoggingLevel.ERROR,
          'Database update failed under USER_MODE for Opportunity ' +
            oppResult.opportunityId +
            ': ' +
            e.getMessage()
        );
        oppResult.setStatus(
          AckStatus.ACK_UPDATE_FAILED,
          'Email was sent, but record update failed: ' +
            e.getMessage() +
            '. Record needs manual attention to prevent duplicate acknowledgement.'
        );
      }
      return;
    }

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
   * Helper to get the org-wide email address Id to send from. If orgWideEmailAddress is
   * configured (non-blank, e.g. via Ack_Setting__mdt.Org_Wide_Email_Address__c), looks it
   * up by address and uses it; if that lookup finds nothing, logs a WARN and falls back
   * to the organization's Default No-Reply Address. If orgWideEmailAddress is blank,
   * goes straight to the Default No-Reply Address. Returns null if no address can be
   * resolved either way.
   * See: https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_orgwideemailaddress.htm
   */
  @TestVisible
  private Id getDefaultOrgWideEmailAddressId() {
    if (String.isNotBlank(orgWideEmailAddress)) {
      OrgWideEmailAddress configured = orgWideEmailService.getByAddress(
        orgWideEmailAddress
      );
      if (configured != null) {
        return configured.Id;
      }
      System.debug(
        LoggingLevel.WARN,
        'Configured Org_Wide_Email_Address__c \'' +
          orgWideEmailAddress +
          '\' was not found as an OrgWideEmailAddress. Falling back to the Default No-Reply Address.'
      );
    }

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
   * Get email configuration for the configured template.
   * @return AckEmailConfig configured with the template, or null if the configured
   * template could not be found (or the lookup failed unexpectedly) - callers must
   * treat null as a hard configuration error, not fall back to any other content.
   *
   * Deliberately not WITH USER_MODE / no explicit CRUD/FLS check: EmailTemplate is setup
   * metadata that the running user does not need direct object access to in order to
   * trigger a send - Messaging.sendEmail resolves and renders the template on the user's
   * behalf. Enforcing user mode here would break sends for users without Setup access to
   * EmailTemplate. Accepted PMD ApexCRUDViolation finding; see docs/ci-setup.md.
   */
  @SuppressWarnings('PMD.ApexCRUDViolation')
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
      return null;
    } catch (System.Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Unexpected error accessing EmailTemplate: ' + ex.getMessage()
      );
      return null;
    }
  }
}
