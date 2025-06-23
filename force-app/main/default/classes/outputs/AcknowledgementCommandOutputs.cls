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
    public List<DonationAcknowledgementService.OpportunityResult> validOpportunities;

    public EmailPrepOutput() {
      this.emails = new List<Messaging.SingleEmailMessage>();
      this.contactMap = new Map<Id, Contact>();
      this.validOpportunities = new List<DonationAcknowledgementService.OpportunityResult>();
    }
  }

  /**
   * Output from email sending command
   */
  public class SendOutput {
    public Boolean isSuccess;
    public String errorMessage;
    public List<DonationAcknowledgementService.OpportunityResult> successfulOpportunities;
    public List<DonationAcknowledgementService.OpportunityResult> failedOpportunities;

    public SendOutput() {
      this.isSuccess = false;
      this.successfulOpportunities = new List<DonationAcknowledgementService.OpportunityResult>();
      this.failedOpportunities = new List<DonationAcknowledgementService.OpportunityResult>();
    }

    public SendOutput setSuccess(
      List<DonationAcknowledgementService.OpportunityResult> successfulOpps
    ) {
      this.isSuccess = true;
      this.successfulOpportunities = successfulOpps;
      return this;
    }

    public SendOutput setFailure(
      String errorMessage,
      List<DonationAcknowledgementService.OpportunityResult> failedOpps
    ) {
      this.isSuccess = false;
      this.errorMessage = errorMessage;
      this.failedOpportunities = failedOpps;
      return this;
    }

    public SendOutput setPartialFailure(
      String errorMessage,
      List<DonationAcknowledgementService.OpportunityResult> successfulOpps,
      List<DonationAcknowledgementService.OpportunityResult> failedOpps
    ) {
      this.isSuccess = false;
      this.errorMessage = errorMessage;
      this.successfulOpportunities = successfulOpps;
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
