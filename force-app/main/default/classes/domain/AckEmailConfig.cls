// Email configuration class to eliminate code duplication
public with sharing class AckEmailConfig {
  public Id templateId;
  public String subject;
  public String body;
  public Boolean useTemplate;
  public String emailType;

  // Constructor for template-based emails
  public AckEmailConfig(Id templateId) {
    this.templateId = templateId;
    this.useTemplate = true;
  }

  // Constructor for static content emails
  public AckEmailConfig(String subject, String body) {
    this.subject = subject;
    this.body = body;
    this.useTemplate = false;
  }

  // Configure a SingleEmailMessage based on this config
  public void configureEmail(
    Messaging.SingleEmailMessage mail,
    Contact contact,
    Opportunity opp
  ) {
    if (useTemplate) {
      mail.setTemplateId(templateId);
      mail.setTargetObjectId(contact.Id);
    } else {
      mail.setToAddresses(new List<String>{ contact.Email });
      mail.setSubject(subject);
      mail.setPlainTextBody(body);
      mail.setTargetObjectId(contact.Id); // for compliance
    }
    mail.setWhatId(opp.Id); // ensures EmailMessage is created and related
  }
}
