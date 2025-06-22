/**
 * Command to prepare email messages for sending
 * Returns EmailPrepOutput with prepared emails and contact mappings
 */
public with sharing class EmailPreparationCommand implements IAcknowledgementCommand {
  private List<Opportunity> validOpportunities;
  private DonationAcknowledgementService.EmailConfig config;
  private AcknowledgementCommandOutputs.EmailPrepOutput prepOutput;

  public EmailPreparationCommand(
    List<Opportunity> validOpportunities,
    DonationAcknowledgementService.EmailConfig config
  ) {
    this.validOpportunities = validOpportunities;
    this.config = config;
    this.prepOutput = new AcknowledgementCommandOutputs.EmailPrepOutput();
  }

  /**
   * Execute email preparation
   */
  public void execute() {
    Id orgWideEmailId = getDefaultOrgWideEmailAddressId();

    // Bulk query for all Contacts related to the valid Opportunities
    Set<Id> contactIds = new Set<Id>();
    for (Opportunity opp : validOpportunities) {
      if (opp.ContactId != null) {
        contactIds.add(opp.ContactId);
      }
    }
    prepOutput.contactMap = new Map<Id, Contact>(
      [SELECT Id, Email FROM Contact WHERE Id IN :contactIds]
    );

    // Prepare emails for each valid opportunity
    for (Opportunity opp : validOpportunities) {
      Contact contact = prepOutput.contactMap.get(opp.ContactId);
      if (contact != null) {
        DonationAcknowledgementService.OpportunityResult oppResult = new DonationAcknowledgementService.OpportunityResult(
          opp.Id,
          opp.Name
        );
        oppResult.contactEmail = contact.Email;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        config.configureEmail(mail, contact, opp);
        if (orgWideEmailId != null) {
          mail.setOrgWideEmailAddressId(orgWideEmailId);
        }

        prepOutput.emails.add(mail);
        prepOutput.validOpportunities.add(oppResult);

        if (config.useTemplate) {
          System.debug(LoggingLevel.INFO, 'Prepared email: ' + mail);
        }
      }
    }
  }

  /**
   * Get the email preparation output
   * @return EmailPrepOutput with prepared emails and metadata
   */
  public AcknowledgementCommandOutputs.EmailPrepOutput getOutput() {
    return prepOutput;
  }

  /**
   * Helper to get the org-wide email address Id set as the organization's Default No-Reply Address.
   * Returns null if none is configured as default.
   * See: https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_orgwideemailaddress.htm
   */
  private static Id getDefaultOrgWideEmailAddressId() {
    // First, try to find the address with Purpose containing 'DefaultNoReply'
    OrgWideEmailAddress[] defaultNoReply = [
      SELECT Id, Purpose
      FROM OrgWideEmailAddress
      WHERE Purpose IN ('UserSelectionAndDefaultNoReply', 'DefaultNoReply')
      ORDER BY Address ASC
      LIMIT 1
    ];
    if (defaultNoReply.isEmpty()) {
      System.debug(
        LoggingLevel.WARN,
        'No org-wide email address is configured as Default No-Reply Address.'
      );
      return null;
    }
    return defaultNoReply[0].Id;
  }
}
