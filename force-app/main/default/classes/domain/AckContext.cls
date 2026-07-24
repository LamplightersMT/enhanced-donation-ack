/**
 * Pipeline state threaded through the donation acknowledgement send flow in
 * DonationAcknowledgementServiceImpl: validate -> prepareEmails -> sendEmails ->
 * updateRecords. Replaces the former per-step constructor-args/getOutput() output
 * plumbing with a single mutable context object.
 */
public with sharing class AckContext {
  // Opportunities being processed. validate() narrows this list in place down
  // to only the opportunities that passed validation, so downstream steps
  // (prepareEmails, sendEmails) can rely on every entry being valid.
  public List<Opportunity> opportunities;

  // Contacts keyed by Id, queried once in validate() for every opportunity's
  // npsp__Primary_Contact__c. Reused by prepareEmails() rather than re-queried.
  public Map<Id, Contact> contactMap;

  // Email configuration (template vs static) for this run.
  public AckEmailConfig config;

  // Prepared email messages, built by prepareEmails(). Index-aligned with
  // preparedResults - emails[i] corresponds to preparedResults[i].
  public List<Messaging.SingleEmailMessage> emails;

  // One AckOpportunityResult per valid opportunity, created by validate() and
  // index-aligned with both opportunities and emails. sendEmails() and
  // updateRecords() mutate these in place as the pipeline progresses.
  public List<AckOpportunityResult> preparedResults;

  // Final aggregated result. Skipped/failed-validation results are added
  // directly here by validate(); preparedResults are folded in at the end of
  // orchestration once their final status is known.
  public AckDetailedResult result;

  public AckContext(List<Opportunity> opportunities, AckEmailConfig config) {
    this.opportunities = opportunities;
    this.config = config;
    this.contactMap = new Map<Id, Contact>();
    this.emails = new List<Messaging.SingleEmailMessage>();
    this.preparedResults = new List<AckOpportunityResult>();
    this.result = new AckDetailedResult();
  }
}
