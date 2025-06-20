public with sharing class DonationAcknowledgementService {
  // Wrapper class for Invocable input
  public class OpportunityIdWrapper {
    @InvocableVariable(required=true)
    public List<Id> opportunityIds;
  }

  // Wrapper class for Invocable output
  public class AckResultWrapper {
    @InvocableVariable
    public String result;
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
  @TestVisible
  public class OpportunityResult {
    public Id opportunityId;
    public String opportunityName;
    public AckStatus status;
    public String reason;
    public String contactEmail;
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
    public Integer totalOpportunities;
    public Integer emailsSent;
    public Integer alreadyAcknowledged;
    public Integer noValidContact;
    public Integer emailSendFailures;
    public List<OpportunityResult> opportunityResults;
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

  // Instance variables for template devname and folder, default to current values
  @TestVisible
  static String donationAckTemplateDevName = 'HTML_Donation_Acknowledgement';
  @TestVisible
  static String donationAckTemplateFolder = 'EnhancedDonationAcknowledgements';

  /**
   * Shared logic to process Opportunities by Ids
   */
  private static List<Opportunity> getOpportunitiesByIds(List<Id> idList) {
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
  private static List<Id> extractOpportunityIds(
    List<OpportunityIdWrapper> inputList
  ) {
    List<Id> idList = new List<Id>();

    // Flatten all Opportunity Ids from the input wrappers, ignoring nulls
    for (OpportunityIdWrapper w : inputList) {
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
   * Invocable method for Flows and list view buttons
   * @param inputList List of OpportunityIdWrapper
   * @return List of AckResultWrapper with status messages
   */
  @InvocableMethod
  public static List<AckResultWrapper> sendAcknowledgementsInvocable(
    List<OpportunityIdWrapper> inputList
  ) {
    List<Id> idList = extractOpportunityIds(inputList);

    List<AckResultWrapper> results = new List<AckResultWrapper>();
    AckResultWrapper res = new AckResultWrapper();
    res.result = sendAcknowledgements(idList);
    System.debug(LoggingLevel.INFO, res.result);
    results.add(res);
    return results;
  }

  /**
   * AuraEnabled method for LWC/Aura use
   */
  @AuraEnabled
  public static String sendAcknowledgements(List<Id> idList) {
    List<Opportunity> opps = getOpportunitiesByIds(idList);
    if (opps.isEmpty()) {
      return 'No Opportunity IDs provided.';
    }

    DetailedAckResult result;
    try {
      EmailTemplate tmpl = [
        SELECT Id
        FROM EmailTemplate
        WHERE
          DeveloperName = :donationAckTemplateDevName
          AND Folder.DeveloperName = :donationAckTemplateFolder
        LIMIT 1
      ];
      EmailConfig config = new EmailConfig(tmpl.Id);
      result = sendEmailsCoreDetailed(opps, config);
      result.emailType = 'Template used: ' + donationAckTemplateDevName;
    } catch (Exception ex) {
      // FIXME: Test relies on this exception handling, which could catch too many errors
      System.debug(
        LoggingLevel.ERROR,
        'Template not found or error: ' + ex.getMessage()
      );
      String subject = 'Thank you for your donation!';
      String body = 'We appreciate your generous support.';
      EmailConfig config = new EmailConfig(subject, body);
      result = sendEmailsCoreDetailed(opps, config);
      result.emailType = 'Static content fallback';
    }
    return result.buildSummaryMessage();
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
    List<Opportunity> opps = getOpportunitiesByIds(idList);
    if (opps.isEmpty()) {
      DetailedAckResult emptyResult = new DetailedAckResult();
      emptyResult.emailType = 'No opportunities provided';
      return emptyResult;
    }

    DetailedAckResult result;
    try {
      EmailTemplate tmpl = [
        SELECT Id
        FROM EmailTemplate
        WHERE
          DeveloperName = :donationAckTemplateDevName
          AND Folder.DeveloperName = :donationAckTemplateFolder
        LIMIT 1
      ];
      EmailConfig config = new EmailConfig(tmpl.Id);
      result = sendEmailsCoreDetailed(opps, config);
      result.emailType = 'Template used: ' + donationAckTemplateDevName;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Template not found or error: ' + ex.getMessage()
      );
      String subject = 'Thank you for your donation!';
      String body = 'We appreciate your generous support.';
      EmailConfig config = new EmailConfig(subject, body);
      result = sendEmailsCoreDetailed(opps, config);
      result.emailType = 'Static content fallback';
    }
    return result;
  }

  /**
   * Method to get individual opportunity results for LWC consumption
   * @param idList List of Opportunity IDs to process
   * @return List of OpportunityResult with detailed status and reason for each opportunity
   */
  @AuraEnabled
  public static List<OpportunityResult> getOpportunityResults(List<Id> idList) {
    DetailedAckResult detailedResult = sendAcknowledgementsDetailed(idList);
    return detailedResult.opportunityResults;
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
  private static DetailedAckResult sendEmailsCoreDetailed(
    List<Opportunity> opps,
    EmailConfig config
  ) {
    DetailedAckResult detailedResult = new DetailedAckResult();

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<OpportunityResult> successfulOpps = new List<OpportunityResult>();
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
      OpportunityResult oppResult = new OpportunityResult(opp.Id, opp.Name);

      // Check if already acknowledged
      if (opp.npsp__Acknowledgment_Date__c != null) {
        oppResult.setStatus(
          AckStatus.ALREADY_ACKNOWLEDGED,
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
          AckStatus.NO_CONTACT,
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
        oppResult.setStatus(AckStatus.NO_CONTACT, 'Contact not found');
        detailedResult.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Contact not found for Opportunity ' + opp.Id
        );
        continue;
      }

      // Check if contact has email
      if (String.isBlank(contact.Email)) {
        oppResult.setStatus(AckStatus.NO_EMAIL, 'Contact has no email address');
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

        for (OpportunityResult oppResult : successfulOpps) {
          oppResult.setStatus(AckStatus.SUCCESS, 'Email sent successfully');
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
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'Email sending failed: ' + e.getMessage()
        );

        // Mark all prepared opportunities as failed
        for (OpportunityResult oppResult : successfulOpps) {
          oppResult.setStatus(
            AckStatus.EMAIL_SEND_FAILED,
            'Email sending failed: ' + e.getMessage()
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
   * Core email sending logic that handles both template and static content emails.
   * Ensures EmailMessage records are created and related via whatId.
   * Returns the number of emails sent.
   *
   * @deprecated Use sendEmailsCoreDetailed() for richer functionality
   */
  @TestVisible
  private static Integer sendEmailsCore(
    List<Opportunity> opps,
    EmailConfig config
  ) {
    DetailedAckResult result = sendEmailsCoreDetailed(opps, config);
    return result.emailsSent;
  }

  /**
   * Sends emails using a templateId to the Contacts related to the given Opportunities.
   * Ensures EmailMessage records are created and related via whatId.
   * Returns the number of emails sent.
   */
  @TestVisible
  private static Integer sendEmailsForOpportunitiesWithTemplate(
    List<Opportunity> opps,
    Id templateId
  ) {
    EmailConfig config = new EmailConfig(templateId);
    return sendEmailsCore(opps, config);
  }

  /**
   * Sends emails to the Contacts related to the given Opportunities.
   * Ensures EmailMessage records are created and related via whatId.
   * Returns the number of emails sent.
   */
  @TestVisible
  private static Integer sendEmailsForOpportunities(
    List<Opportunity> opps,
    String subject,
    String body
  ) {
    EmailConfig config = new EmailConfig(subject, body);
    return sendEmailsCore(opps, config);
  }

  /**
   * Helper to update npsp__Acknowledgment_Date__c for Opportunities that were actually emailed
   */
  private static void updateAcknowledgementDates(List<Opportunity> opps) {
    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    Date today = Date.today();
    for (Opportunity opp : opps) {
      Opportunity oppUpdate = new Opportunity(
        Id = opp.Id,
        npsp__Acknowledgment_Date__c = today
      );
      oppsToUpdate.add(oppUpdate);
    }
    if (!oppsToUpdate.isEmpty()) {
      update oppsToUpdate;
    }
  }
}
