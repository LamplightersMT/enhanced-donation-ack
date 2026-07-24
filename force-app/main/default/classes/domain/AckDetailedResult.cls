// Detailed acknowledgement result with individual opportunity tracking
public with sharing class AckDetailedResult {
  @AuraEnabled
  public Integer totalOpportunities;
  @AuraEnabled
  public Integer emailsSent;
  @AuraEnabled
  public Integer alreadyAcknowledged;
  @AuraEnabled
  public Integer noValidContact;
  @AuraEnabled
  public Integer emailSendFailures;
  @AuraEnabled
  public Integer ackUpdateFailures;
  @AuraEnabled
  public List<AckOpportunityResult> opportunityResults;
  @AuraEnabled
  public String emailType;

  public AckDetailedResult() {
    this.totalOpportunities = 0;
    this.emailsSent = 0;
    this.alreadyAcknowledged = 0;
    this.noValidContact = 0;
    this.emailSendFailures = 0;
    this.ackUpdateFailures = 0;
    this.opportunityResults = new List<AckOpportunityResult>();
  }

  public void addOpportunityResult(AckOpportunityResult oppResult) {
    this.opportunityResults.add(oppResult);
    this.totalOpportunities++;

    // NOTE: results are added to this aggregate AFTER the database update step has
    // run, so status is final by this point - a result whose email sent but whose DB
    // update failed will already carry ACK_UPDATE_FAILED, not SUCCESS.
    if (oppResult.status == AckStatus.ACK_UPDATE_FAILED) {
      this.ackUpdateFailures++;
    } else if (oppResult.isSuccess()) {
      this.emailsSent++;
    } else if (oppResult.status == AckStatus.ALREADY_ACKNOWLEDGED) {
      this.alreadyAcknowledged++;
    } else if (
      oppResult.status == AckStatus.NO_CONTACT ||
      oppResult.status == AckStatus.NO_EMAIL
    ) {
      this.noValidContact++;
    } else if (oppResult.status == AckStatus.EMAIL_SEND_FAILED) {
      this.emailSendFailures++;
    }
  }

  public String buildSummaryMessage() {
    String message =
      'sendAcknowledgements called with ' +
      totalOpportunities +
      ' Opportunities. ';
    message += 'Emails sent: ' + emailsSent;

    if (alreadyAcknowledged > 0) {
      message += ', Already acknowledged: ' + alreadyAcknowledged;
    }

    if (noValidContact > 0) {
      message += ', No valid contact: ' + noValidContact;
    }

    if (emailSendFailures > 0) {
      message += ', Email send failures: ' + emailSendFailures;
    }

    if (ackUpdateFailures > 0) {
      message += ', Sent but record update failed: ' + ackUpdateFailures;
    }

    if (emailType != null) {
      message += ' (' + emailType + ')';
    }

    return message;
  }

  public List<AckOpportunityResult> getSuccessfulResults() {
    List<AckOpportunityResult> successful = new List<AckOpportunityResult>();
    for (AckOpportunityResult result : opportunityResults) {
      if (result.isSuccess()) {
        successful.add(result);
      }
    }
    return successful;
  }

  public List<AckOpportunityResult> getSkippedResults() {
    List<AckOpportunityResult> skipped = new List<AckOpportunityResult>();
    for (AckOpportunityResult result : opportunityResults) {
      if (result.isSkipped()) {
        skipped.add(result);
      }
    }
    return skipped;
  }

  public List<AckOpportunityResult> getFailedResults() {
    List<AckOpportunityResult> failed = new List<AckOpportunityResult>();
    for (AckOpportunityResult result : opportunityResults) {
      if (result.isFailed()) {
        failed.add(result);
      }
    }
    return failed;
  }
}
