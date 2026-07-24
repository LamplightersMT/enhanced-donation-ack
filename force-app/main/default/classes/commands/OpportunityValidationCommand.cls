/**
 * Command to validate opportunities and filter out those that should be skipped
 * Accumulates skipped opportunities directly into the DetailedAckResult
 */
public with sharing class OpportunityValidationCommand implements IAcknowledgementCommand {
  private List<Opportunity> opportunities;
  private AckDetailedResult result;
  private List<Opportunity> validOpportunities;

  public OpportunityValidationCommand(
    List<Opportunity> opportunities,
    AckDetailedResult result
  ) {
    this.opportunities = opportunities;
    this.result = result;
    this.validOpportunities = new List<Opportunity>();
  }

  /**
   * Execute validation and store valid opportunities
   * Skipped opportunities are added directly to the DetailedAckResult
   */
  public void execute() {
    // Bulk query for all Contacts related to the Opportunities
    Set<Id> contactIds = new Set<Id>();
    for (Opportunity opp : opportunities) {
      if (opp.npsp__Primary_Contact__c != null) {
        contactIds.add(opp.npsp__Primary_Contact__c);
      }
    }
    Map<Id, Contact> contactMap = new Map<Id, Contact>(
      [SELECT Id, Email FROM Contact WHERE Id IN :contactIds]
    );

    // Process each opportunity individually with detailed tracking
    for (Opportunity opp : opportunities) {
      // QUESTION: Should OpportunityResult be defined in this class or in DonationAcknowledgementService?
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
        result.addOpportunityResult(oppResult);
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
        result.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Opportunity ' + opp.Id + ' has no npsp__Primary_Contact__c.'
        );
        continue;
      }

      Contact contact = contactMap.get(opp.npsp__Primary_Contact__c);
      if (contact == null) {
        oppResult.setStatus(AckStatus.NO_CONTACT, 'Contact not found');
        result.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Contact not found for Opportunity ' + opp.Id
        );
        continue;
      }

      // Check if contact has email
      if (String.isBlank(contact.Email)) {
        oppResult.setStatus(AckStatus.NO_EMAIL, 'Contact has no email address');
        result.addOpportunityResult(oppResult);
        System.debug(
          LoggingLevel.WARN,
          'Contact ' + contact.Id + ' has no email.'
        );
        continue;
      }

      // Opportunity passed validation
      oppResult.contactEmail = contact.Email;
      validOpportunities.add(opp);
    }
  }

  /**
   * Get the list of opportunities that passed validation
   * @return List of valid opportunities
   */
  public List<Opportunity> getValidOpportunities() {
    return validOpportunities;
  }
}
