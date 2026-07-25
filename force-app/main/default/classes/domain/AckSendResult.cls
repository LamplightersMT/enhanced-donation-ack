// Result of sending a single email message.
// We deliberately do NOT return Messaging.SendEmailResult from IEmailService because
// Apex tests cannot construct instances of that type, which would make mocking impossible.
public with sharing class AckSendResult {
  public Boolean success;
  public String errorMessage;

  private AckSendResult(Boolean success, String errorMessage) {
    this.success = success;
    this.errorMessage = errorMessage;
  }

  public static AckSendResult ok() {
    return new AckSendResult(true, null);
  }

  public static AckSendResult fail(String msg) {
    return new AckSendResult(false, msg);
  }
}
