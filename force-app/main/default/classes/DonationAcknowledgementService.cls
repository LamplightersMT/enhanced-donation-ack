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
  @InvocableMethod(
    label='Send Donation Acknowledgements'
    description='Sends acknowledgement emails for selected Opportunities and creates EmailMessage records.'
  )
  public static List<AckResultWrapper> sendAcknowledgementsInvocable(
    List<OpportunityIdWrapper> inputList
  ) {
    Set<Id> idSet = new Set<Id>();
    for (OpportunityIdWrapper w : inputList) {
      if (w != null && w.opportunityIds != null) {
        idSet.addAll(w.opportunityIds);
      }
    }
    // Call the AuraEnabled method to avoid code duplication
    String resultMsg = sendAcknowledgements(new List<Id>(idSet));

    List<AckResultWrapper> results = new List<AckResultWrapper>();
    AckResultWrapper res = new AckResultWrapper();
    res.result = resultMsg;

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

    // Static email content
    String subject = 'Thank you for your donation!';
    String body = 'We appreciate your generous support.';

    Integer sentCount = sendEmailsForOpportunities(opps, subject, body);

    return 'sendAcknowledgements called with ' +
      opps.size() +
      ' Opportunities. Emails sent: ' +
      sentCount;
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
    for (Opportunity opp : opps) {
      if (opp.ContactId != null) {
        Contact c = [
          SELECT Id, Email
          FROM Contact
          WHERE Id = :opp.ContactId
          LIMIT 1
        ];
        if (c.Email != null) {
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setToAddresses(new List<String>{ c.Email });
          mail.setSubject(subject);
          mail.setPlainTextBody(body);
          mail.setTargetObjectId(c.Id); // for compliance, but not required if using setToAddresses
          mail.setWhatId(opp.Id); // ensures EmailMessage is created and related
          emails.add(mail);
          sentCount++;
        } else {
          System.debug(LoggingLevel.WARN, 'Contact ' + c.Id + ' has no email.');
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
