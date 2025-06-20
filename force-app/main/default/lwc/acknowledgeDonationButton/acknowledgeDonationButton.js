import { LightningElement, api } from "lwc";
import sendAcknowledgementsDetailed from "@salesforce/apex/DonationAcknowledgementService.sendAcknowledgementsDetailed";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class AcknowledgeDonationButton extends LightningElement {
  @api recordId;
  @api selectedRecordIds; // For mass actions

  async handleClick() {
    let idsToProcess = [];
    if (this.selectedRecordIds && this.selectedRecordIds.length > 0) {
      idsToProcess = this.selectedRecordIds;
    } else if (this.recordId) {
      idsToProcess = [this.recordId];
    }
    if (idsToProcess.length === 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "No records selected.",
          variant: "error"
        })
      );
      return;
    }
    try {
      const detailedResult = await sendAcknowledgementsDetailed({
        idList: idsToProcess
      });
      console.log("Detailed acknowledgement result:", detailedResult);
      console.log("Keys in result:", Object.keys(detailedResult));
      console.log("emailsSent value:", detailedResult.emailsSent);

      // Ensure we have valid numbers (handle undefined/null cases)
      const emailsSent = detailedResult.emailsSent || 0;
      const alreadyAcknowledged = detailedResult.alreadyAcknowledged || 0;
      const noValidContact = detailedResult.noValidContact || 0;
      const emailSendFailures = detailedResult.emailSendFailures || 0;
      const totalOpportunities = detailedResult.totalOpportunities || 0;

      // Create enhanced success message with detailed counts
      let message = `${emailsSent} email(s) sent successfully`;
      if (alreadyAcknowledged > 0) {
        message += `, ${alreadyAcknowledged} already acknowledged`;
      }
      if (noValidContact > 0) {
        message += `, ${noValidContact} without valid contact`;
      }
      if (emailSendFailures > 0) {
        message += `, ${emailSendFailures} failed`;
      }

      // Determine appropriate title and variant based on results
      let title;
      let variant;

      if (emailsSent > 0) {
        title = "Success";
        variant = "success";
      } else if (emailSendFailures > 0) {
        title = "Email Send Failed";
        variant = "error";
      } else if (
        alreadyAcknowledged > 0 &&
        alreadyAcknowledged === totalOpportunities
      ) {
        title = "Already Acknowledged";
        variant = "info";
      } else if (noValidContact > 0) {
        title = "No Valid Contacts";
        variant = "warning";
      } else {
        title = "Processing Complete";
        variant = "info";
      }

      this.dispatchEvent(
        new ShowToastEvent({
          title: title,
          message: message,
          variant: variant
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message:
            error.body && error.body.message
              ? error.body.message
              : "Failed to send acknowledgement.",
          variant: "error"
        })
      );
    }
  }
}
