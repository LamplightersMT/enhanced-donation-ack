/**
 * Output classes for acknowledgement processing commands
 * Contains specific return types for commands in the hybrid approach
 */
public with sharing class AcknowledgementCommandOutputs {
  /**
   * Output from email preparation command
   */
  public class EmailPrepOutput {
    public List<Messaging.SingleEmailMessage> emails;
    public Map<Id, Contact> contactMap;
    public List<AckOpportunityResult> validOpportunities;

    public EmailPrepOutput() {
      this.emails = new List<Messaging.SingleEmailMessage>();
      this.contactMap = new Map<Id, Contact>();
      this.validOpportunities = new List<AckOpportunityResult>();
    }
  }

  /**
   * Output from email sending command
   */
  public class SendOutput {
    public Boolean isSuccess;
    public String errorMessage;
    public List<AckOpportunityResult> successfulOpportunities;
    public List<AckOpportunityResult> failedOpportunities;

    public SendOutput() {
      this.isSuccess = false;
      this.successfulOpportunities = new List<AckOpportunityResult>();
      this.failedOpportunities = new List<AckOpportunityResult>();
    }

    public SendOutput setSuccess(List<AckOpportunityResult> successfulOpps) {
      this.isSuccess = true;
      this.successfulOpportunities = successfulOpps;
      return this;
    }

    public SendOutput setFailure(
      String errorMessage,
      List<AckOpportunityResult> failedOpps
    ) {
      this.isSuccess = false;
      this.errorMessage = errorMessage;
      this.failedOpportunities = failedOpps;
      return this;
    }
  }

  /**
   * Output from database update command
   */
  public class UpdateOutput {
    public Boolean isSuccess;
    public String errorMessage;
    public Integer recordsUpdated;

    public UpdateOutput() {
      this.isSuccess = false;
      this.recordsUpdated = 0;
    }

    public UpdateOutput setSuccess(Integer recordsUpdated) {
      this.isSuccess = true;
      this.recordsUpdated = recordsUpdated;
      return this;
    }

    public UpdateOutput setFailure(String errorMessage) {
      this.isSuccess = false;
      this.errorMessage = errorMessage;
      return this;
    }
  }
}
