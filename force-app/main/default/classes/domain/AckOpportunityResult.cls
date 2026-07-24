// Individual opportunity result with detailed tracking
// TODO: This is growing in importance, we might want to rename it
public with sharing class AckOpportunityResult {
  @AuraEnabled
  public Id opportunityId;
  @AuraEnabled
  public String opportunityName;
  @AuraEnabled
  public AckStatus status;
  @AuraEnabled
  public String reason;
  @AuraEnabled
  public String contactEmail;
  @AuraEnabled
  public Date acknowledgmentDate;

  public AckOpportunityResult(Id oppId, String oppName) {
    this.opportunityId = oppId;
    this.opportunityName = oppName;
  }

  public void setStatus(AckStatus status, String reason) {
    this.status = status;
    this.reason = reason;
  }

  public Boolean isSuccess() {
    return this.status == AckStatus.SUCCESS;
  }

  public Boolean isSkipped() {
    return this.status == AckStatus.ALREADY_ACKNOWLEDGED ||
      this.status == AckStatus.NO_CONTACT ||
      this.status == AckStatus.NO_EMAIL;
  }

  public Boolean isFailed() {
    return this.status == AckStatus.EMAIL_SEND_FAILED ||
      this.status == AckStatus.INVALID_OPPORTUNITY ||
      this.status == AckStatus.ACK_UPDATE_FAILED;
  }
}
