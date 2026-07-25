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

      // Ensure we have valid numbers (handle undefined/null cases)
      const emailsSent = detailedResult.emailsSent || 0;
      const alreadyAcknowledged = detailedResult.alreadyAcknowledged || 0;
      const noValidContact = detailedResult.noValidContact || 0;
      const emailSendFailures = detailedResult.emailSendFailures || 0;
      const ackUpdateFailures = detailedResult.ackUpdateFailures || 0;
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
      if (ackUpdateFailures > 0) {
        message += `, ${ackUpdateFailures} sent but record update failed`;
      }

      // Severity ladder: the WORST condition present wins, so this is ordered
      // most severe first. Since sends became partial-success, several of these
      // counters can be non-zero in the same run (e.g. some emails sent, one
      // address failed), so a first-match-wins chain on the happy path would
      // report a green success while a donor silently went unacknowledged.
      // Two failure conditions must never be reported as plain success:
      //   emailSendFailures - the donor was never emailed
      //   ackUpdateFailures - the donor WAS emailed but nothing was recorded,
      //     which risks a duplicate acknowledgement later. Note these records
      //     are excluded from emailsSent, so this can be the only signal.
      let title;
      let variant;

      if (emailSendFailures > 0 && emailsSent === 0) {
        // Nothing reached a donor.
        title = "Email Send Failed";
        variant = "error";
      } else if (emailSendFailures > 0 || ackUpdateFailures > 0) {
        // Partly worked, partly needs manual attention.
        title = "Completed With Issues";
        variant = "warning";
      } else if (emailsSent > 0) {
        title = "Success";
        variant = "success";
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
