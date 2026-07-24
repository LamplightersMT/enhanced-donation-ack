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
   * Output from email sending command.
   * Both lists may be non-empty at once - a batch of emails can have some
   * messages succeed and others fail. There is no overall isSuccess flag;
   * callers should inspect the two lists directly.
   */
  public class SendOutput {
    public List<AckOpportunityResult> successfulOpportunities;
    public List<AckOpportunityResult> failedOpportunities;

    public SendOutput() {
      this.successfulOpportunities = new List<AckOpportunityResult>();
      this.failedOpportunities = new List<AckOpportunityResult>();
    }

    /**
     * Single completion setter - populates both lists directly.
     */
    public SendOutput setResults(
      List<AckOpportunityResult> successfulOpps,
      List<AckOpportunityResult> failedOpps
    ) {
      this.successfulOpportunities = successfulOpps;
      this.failedOpportunities = failedOpps;
      return this;
    }
  }

  /**
   * Output from database update command.
   * recordsFailed counts opportunities whose email sent successfully but whose
   * DML update failed (see AckStatus.ACK_UPDATE_FAILED).
   */
  public class UpdateOutput {
    public Integer recordsUpdated;
    public Integer recordsFailed;

    public UpdateOutput() {
      this.recordsUpdated = 0;
      this.recordsFailed = 0;
    }

    public UpdateOutput setCounts(
      Integer recordsUpdated,
      Integer recordsFailed
    ) {
      this.recordsUpdated = recordsUpdated;
      this.recordsFailed = recordsFailed;
      return this;
    }
  }
}
