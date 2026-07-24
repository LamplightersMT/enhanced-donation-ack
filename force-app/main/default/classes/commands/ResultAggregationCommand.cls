/**
 * Command to aggregate all command outputs into final DetailedAckResult
 * Modifies the DetailedAckResult directly - no return value
 */
public with sharing class ResultAggregationCommand implements IAcknowledgementCommand {
  private AckDetailedResult result;
  private AcknowledgementCommandOutputs.EmailPrepOutput prepOutput;
  private AcknowledgementCommandOutputs.SendOutput sendOutput;
  private AcknowledgementCommandOutputs.UpdateOutput updateOutput;
  private String emailType;

  public ResultAggregationCommand(
    AckDetailedResult result,
    AcknowledgementCommandOutputs.EmailPrepOutput prepOutput,
    AcknowledgementCommandOutputs.SendOutput sendOutput,
    AcknowledgementCommandOutputs.UpdateOutput updateOutput,
    String emailType
  ) {
    this.result = result;
    this.prepOutput = prepOutput;
    this.sendOutput = sendOutput;
    this.updateOutput = updateOutput;
    this.emailType = emailType;
  }

  /**
   * Execute result aggregation.
   * Adds ALL results unconditionally - both successes and failures. By this point
   * each AckOpportunityResult's status is already final (EmailSendCommand and, if it
   * ran, DatabaseUpdateCommand have already mutated status in place), so there is no
   * need to branch on an overall success flag here.
   */
  public void execute() {
    for (AckOpportunityResult oppResult : sendOutput.successfulOpportunities) {
      result.addOpportunityResult(oppResult);
    }
    for (AckOpportunityResult oppResult : sendOutput.failedOpportunities) {
      result.addOpportunityResult(oppResult);
    }

    // Set email type metadata
    result.emailType = emailType;
  }
}
