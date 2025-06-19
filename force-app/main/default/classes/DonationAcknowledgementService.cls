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

  // Instance variables for template devname and folder, default to current values
  @TestVisible
  static String donationAckTemplateDevName = 'TempDonationAck';
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
   * Sends emails using a templateId to the Contacts related to the given Opportunities.
   * Ensures EmailMessage records are created and related via whatId.
   * Returns the number of emails sent.
   */
  @TestVisible
  private static Integer sendEmailsForOpportunitiesWithTemplate(
    List<Opportunity> opps,
    Id templateId
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

    for (Opportunity opp : opps) {
      if (opp.ContactId != null) {
        Contact c = contactMap.get(opp.ContactId);
        if (c != null && c.Email != null) {
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTemplateId(templateId);
          mail.setTargetObjectId(c.Id);
          mail.setWhatId(opp.Id);
          if (orgWideEmailId != null) {
            mail.setOrgWideEmailAddressId(orgWideEmailId);
          }
          System.debug(LoggingLevel.INFO, 'Prepared email: ' + mail);
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
      Messaging.sendEmail(emails);
    }
    return sentCount;
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
    for (Opportunity opp : opps) {
      if (opp.ContactId != null) {
        Contact c = contactMap.get(opp.ContactId);
        if (c != null && c.Email != null) {
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setToAddresses(new List<String>{ c.Email });
          mail.setSubject(subject);
          mail.setPlainTextBody(body);
          mail.setTargetObjectId(c.Id); // for compliance, but not required if using setToAddresses
          mail.setWhatId(opp.Id); // ensures EmailMessage is created and related
          if (orgWideEmailId != null) {
            mail.setOrgWideEmailAddressId(orgWideEmailId);
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
      Messaging.sendEmail(emails);
    }
    return sentCount;
  }
}
