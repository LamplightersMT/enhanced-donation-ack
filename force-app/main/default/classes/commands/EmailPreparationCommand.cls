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
}
