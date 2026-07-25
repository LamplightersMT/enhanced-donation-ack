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
   * Execute result aggregation
   */
  public void execute() {
    // Add successful opportunities to result
    if (sendOutput.isSuccess) {
      for (
        AckOpportunityResult oppResult : sendOutput.successfulOpportunities
      ) {
        result.addOpportunityResult(oppResult);
      }
    } else {
      // Add failed opportunities to result
      for (AckOpportunityResult oppResult : sendOutput.failedOpportunities) {
        result.addOpportunityResult(oppResult);
      }
    }

    // Set email type metadata
    result.emailType = emailType;
  }
}
