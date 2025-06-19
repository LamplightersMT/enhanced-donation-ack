import { LightningElement, api } from "lwc";
import sendAcknowledgements from "@salesforce/apex/DonationAcknowledgementService.sendAcknowledgements";
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
      const result = await sendAcknowledgements({ idList: idsToProcess });
      console.log(result);

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: result,
          variant: "success"
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
