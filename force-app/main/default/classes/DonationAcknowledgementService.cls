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
      SELECT Id, Name, Amount, StageName, CloseDate, AccountId, ContactId
      FROM Opportunity
      WHERE Id IN :idList
    ];
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
    Integer sentCount = 0;
    try {
      EmailTemplate tmpl = [
        SELECT Id
        FROM EmailTemplate
        WHERE
          DeveloperName = :donationAckTemplateDevName
          AND Folder.DeveloperName = :donationAckTemplateFolder
        LIMIT 1
      ];
      sentCount = sendEmailsForOpportunitiesWithTemplate(opps, tmpl.Id);
      return 'sendAcknowledgements called with ' +
        opps.size() +
        ' Opportunities. Emails sent: ' +
        sentCount +
        ' (Template used: ' +
        donationAckTemplateDevName +
        ')';
    } catch (Exception ex) {
      // FIXME: Test relies on this exception handling, which could catch too many errors
      System.debug(
        LoggingLevel.ERROR,
        'Template not found or error: ' + ex.getMessage()
      );
      String subject = 'Thank you for your donation!';
      String body = 'We appreciate your generous support.';
      sentCount = sendEmailsForOpportunities(opps, subject, body);
      return 'sendAcknowledgements called with ' +
        opps.size() +
        ' Opportunities. Emails sent: ' +
        sentCount +
        ' (Static content fallback)';
    }
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
   * Core email sending logic that handles both template and static content emails.
   * Ensures EmailMessage records are created and related via whatId.
   * Returns the number of emails sent.
   *
   * TODO: Enhance return value to include rich user feedback (template vs static, warnings, etc.)
   * Currently returns only Integer count - calling methods build user messages separately.
   */
  @TestVisible
  private static Integer sendEmailsCore(
    List<Opportunity> opps,
    EmailConfig config
  ) {
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    Integer sentCount = 0;
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

    List<Opportunity> oppsToUpdate = new List<Opportunity>();

    for (Opportunity opp : opps) {
      if (opp.ContactId != null) {
        Contact c = contactMap.get(opp.ContactId);
        if (c != null && c.Email != null) {
          oppsToUpdate.add(opp);

          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          config.configureEmail(mail, c, opp);
          if (orgWideEmailId != null) {
            mail.setOrgWideEmailAddressId(orgWideEmailId);
          }
          if (config.useTemplate) {
            System.debug(LoggingLevel.INFO, 'Prepared email: ' + mail);
          }
          emails.add(mail);
          sentCount++;
        } else if (c != null) {
          System.debug(LoggingLevel.WARN, 'Contact ' + c.Id + ' has no email.');
        } else {
          System.debug(
            LoggingLevel.WARN,
            'Contact not found for Opportunity ' + opp.Id
          );
        }
      } else {
        System.debug(
          LoggingLevel.WARN,
          'Opportunity ' + opp.Id + ' has no ContactId.'
        );
      }
    }

    if (!emails.isEmpty()) {
      try {
        Messaging.sendEmail(emails);
        updateAcknowledgementDates(oppsToUpdate);
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'Email sending failed: ' + e.getMessage()
        );
        // Don't update acknowledgment dates if sending failed
        throw new AuraHandledException(
          'Failed to send acknowledgement emails: ' + e.getMessage()
        );
      }
    }
    return sentCount;
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
