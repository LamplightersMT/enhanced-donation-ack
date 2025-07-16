/**
 * Command to update opportunity acknowledgment dates in the database
 * Returns UpdateOutput with update status
 */
public with sharing class DatabaseUpdateCommand implements IAcknowledgementCommand {
  private List<DonationAcknowledgementService.OpportunityResult> successfulOpportunities;
  private AcknowledgementCommandOutputs.UpdateOutput updateOutput;

  public DatabaseUpdateCommand(
    List<DonationAcknowledgementService.OpportunityResult> successfulOpportunities
  ) {
    this.successfulOpportunities = successfulOpportunities;
    this.updateOutput = new AcknowledgementCommandOutputs.UpdateOutput();
  }

  /**
   * Execute database update
   */
  public void execute() {
    if (successfulOpportunities.isEmpty()) {
      updateOutput = new AcknowledgementCommandOutputs.UpdateOutput()
        .setSuccess(0);
      return;
    }

    try {
      List<Opportunity> oppsToUpdate = new List<Opportunity>();

      for (
        DonationAcknowledgementService.OpportunityResult oppResult : successfulOpportunities
      ) {
        oppsToUpdate.add(
          new Opportunity(
            Id = oppResult.opportunityId,
            npsp__Acknowledgment_Date__c = oppResult.acknowledgmentDate,
            npsp__Acknowledgment_Status__c = 'Acknowledged' // New field update
          )
        );
      }

      update oppsToUpdate;
      updateOutput = new AcknowledgementCommandOutputs.UpdateOutput()
        .setSuccess(oppsToUpdate.size());
    } catch (DmlException de) {
      System.debug(
        LoggingLevel.ERROR,
        'Database update failed: ' + de.getMessage()
      );

      // Mark all opportunities as failed due to database update failure
      for (
        DonationAcknowledgementService.OpportunityResult oppResult : successfulOpportunities
      ) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
          'Database update failed: ' + de.getMessage()
        );
      }

      updateOutput = new AcknowledgementCommandOutputs.UpdateOutput()
        .setFailure(
          'Failed to update acknowledgement dates: ' + de.getMessage()
        );

      throw new AuraHandledException(
        'Failed to update acknowledgement dates: ' + de.getMessage()
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Unexpected error during database update: ' + e.getMessage()
      );

      // Mark all opportunities as failed due to unexpected error
      for (
        DonationAcknowledgementService.OpportunityResult oppResult : successfulOpportunities
      ) {
        oppResult.setStatus(
          DonationAcknowledgementService.AckStatus.EMAIL_SEND_FAILED,
          'Database update error: ' + e.getMessage()
        );
      }

      updateOutput = new AcknowledgementCommandOutputs.UpdateOutput()
        .setFailure(
          'Failed to update acknowledgement dates: ' + e.getMessage()
        );

      throw new AuraHandledException(
        'Failed to update acknowledgement dates: ' + e.getMessage()
      );
    }
  }

  /**
   * Get the database update output
   * @return UpdateOutput with update status
   */
  public AcknowledgementCommandOutputs.UpdateOutput getOutput() {
    return updateOutput;
  }
}
