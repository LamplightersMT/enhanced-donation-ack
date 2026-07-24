/**
 * Command to update opportunity acknowledgment dates in the database.
 * Uses partial-success DML (Database.update with allOrNothing=false) so that a
 * DML failure on one record doesn't block the rest. A record whose email sent
 * successfully but whose DB update failed is marked ACK_UPDATE_FAILED rather
 * than being silently dropped - the email already went out, so this needs
 * manual attention to avoid a duplicate acknowledgement email later.
 * Returns UpdateOutput with update counts.
 */
public with sharing class DatabaseUpdateCommand implements IAcknowledgementCommand {
  private List<AckOpportunityResult> successfulOpportunities;
  private AcknowledgementCommandOutputs.UpdateOutput updateOutput;

  public DatabaseUpdateCommand(
    List<AckOpportunityResult> successfulOpportunities
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
        .setCounts(0, 0);
      return;
    }

    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    for (AckOpportunityResult oppResult : successfulOpportunities) {
      oppsToUpdate.add(
        new Opportunity(
          Id = oppResult.opportunityId,
          npsp__Acknowledgment_Date__c = oppResult.acknowledgmentDate,
          npsp__Acknowledgment_Status__c = 'Acknowledged'
        )
      );
    }

    List<Database.SaveResult> saveResults = Database.update(
      oppsToUpdate,
      false
    );

    Integer updatedCount = 0;
    Integer failedCount = 0;

    for (Integer i = 0; i < successfulOpportunities.size(); i++) {
      AckOpportunityResult oppResult = successfulOpportunities[i];
      Database.SaveResult saveResult = i < saveResults.size()
        ? saveResults[i]
        : null;

      if (saveResult != null && saveResult.isSuccess()) {
        updatedCount++;
      } else {
        failedCount++;
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

    updateOutput = new AcknowledgementCommandOutputs.UpdateOutput()
      .setCounts(updatedCount, failedCount);
  }

  /**
   * Get the database update output
   * @return UpdateOutput with update counts
   */
  public AcknowledgementCommandOutputs.UpdateOutput getOutput() {
    return updateOutput;
  }
}
