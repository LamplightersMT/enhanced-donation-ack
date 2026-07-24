/**
 * Default implementation of IEmailService that uses the Salesforce Messaging class
 */
public with sharing class EmailService implements IEmailService {
  /**
   * Send email messages using the standard Salesforce Messaging class.
   * Uses allOrNothing=false so a single bad message doesn't block delivery of the rest.
   * Never throws for per-message failures - each input email produces exactly one
   * AckSendResult, in the same order.
   * @param emails List of email messages to send
   * @return List of AckSendResult, one per input email, same order
   */
  public List<AckSendResult> sendEmail(
    List<Messaging.SingleEmailMessage> emails
  ) {
    List<AckSendResult> sendResults = new List<AckSendResult>();
    try {
      List<Messaging.SendEmailResult> results = Messaging.sendEmail(
        emails,
        false
      );
      for (Messaging.SendEmailResult result : results) {
        if (result.isSuccess()) {
          sendResults.add(AckSendResult.ok());
        } else {
          List<String> errors = new List<String>();
          for (Messaging.SendEmailError err : result.getErrors()) {
            errors.add(err.getMessage());
          }
          sendResults.add(AckSendResult.fail(String.join(errors, '; ')));
        }
      }
    } catch (Exception e) {
      // Org-level problem (e.g. deliverability disabled) - Messaging.sendEmail
      // threw before returning per-message results. Treat every message as failed.
      System.debug(
        LoggingLevel.ERROR,
        'Messaging.sendEmail threw an exception: ' + e.getMessage()
      );
      sendResults = new List<AckSendResult>();
      for (Integer i = 0; i < emails.size(); i++) {
        sendResults.add(AckSendResult.fail(e.getMessage()));
      }
    }
    return sendResults;
  }
}
