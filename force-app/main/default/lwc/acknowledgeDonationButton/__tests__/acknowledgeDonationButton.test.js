import { createElement } from "lwc";
import AcknowledgeDonationButton from "../acknowledgeDonationButton";
import sendAcknowledgementsDetailed from "@salesforce/apex/DonationAcknowledgementService.sendAcknowledgementsDetailed";

// Event name dispatched by lightning/platformShowToastEvent's ShowToastEvent
const SHOW_TOAST_EVENT_NAME = "lightning__showtoast";

// Mock the Apex method
jest.mock(
  "@salesforce/apex/DonationAcknowledgementService.sendAcknowledgementsDetailed",
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

describe("c-acknowledge-donation-button", () => {
  afterEach(() => {
    // Clean up DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    // Clear all mocks
    jest.clearAllMocks();
  });

  it("renders without error", () => {
    const element = createElement("c-acknowledge-donation-button", {
      is: AcknowledgeDonationButton
    });
    document.body.appendChild(element);

    const button = element.shadowRoot.querySelector("lightning-button");
    expect(button).toBeTruthy();
    expect(button.label).toBe("Acknowledge Donation(s)");
  });

  it("handles successful acknowledgement with detailed results", async () => {
    // Mock successful response with detailed results
    const mockDetailedResult = {
      totalOpportunities: 2,
      emailsSent: 1,
      alreadyAcknowledged: 1,
      noValidContact: 0,
      emailSendFailures: 0
    };
    sendAcknowledgementsDetailed.mockResolvedValue(mockDetailedResult);

    const element = createElement("c-acknowledge-donation-button", {
      is: AcknowledgeDonationButton
    });
    element.recordId = "006000000000001AAA";
    document.body.appendChild(element);

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    // Wait for async operation
    await Promise.resolve();

    expect(sendAcknowledgementsDetailed).toHaveBeenCalledWith({
      idList: ["006000000000001AAA"]
    });
  });

  it("handles multiple selected records", async () => {
    const mockDetailedResult = {
      totalOpportunities: 3,
      emailsSent: 3,
      alreadyAcknowledged: 0,
      noValidContact: 0,
      emailSendFailures: 0
    };
    sendAcknowledgementsDetailed.mockResolvedValue(mockDetailedResult);

    const element = createElement("c-acknowledge-donation-button", {
      is: AcknowledgeDonationButton
    });
    element.selectedRecordIds = [
      "006000000000001AAA",
      "006000000000002AAA",
      "006000000000003AAA"
    ];
    document.body.appendChild(element);

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await Promise.resolve();

    expect(sendAcknowledgementsDetailed).toHaveBeenCalledWith({
      idList: ["006000000000001AAA", "006000000000002AAA", "006000000000003AAA"]
    });
  });

  it("shows a warning (not success) toast when emails sent but a record update failed", async () => {
    const mockDetailedResult = {
      totalOpportunities: 2,
      emailsSent: 2,
      alreadyAcknowledged: 0,
      noValidContact: 0,
      emailSendFailures: 0,
      ackUpdateFailures: 1
    };
    sendAcknowledgementsDetailed.mockResolvedValue(mockDetailedResult);

    const element = createElement("c-acknowledge-donation-button", {
      is: AcknowledgeDonationButton
    });
    element.recordId = "006000000000001AAA";
    document.body.appendChild(element);

    const toastHandler = jest.fn();
    element.addEventListener(SHOW_TOAST_EVENT_NAME, toastHandler);

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await Promise.resolve();
    await Promise.resolve();

    expect(toastHandler).toHaveBeenCalledTimes(1);
    const toastEvent = toastHandler.mock.calls[0][0];
    expect(toastEvent.detail.variant).toBe("warning");
    expect(toastEvent.detail.message).toContain(
      "1 sent but record update failed"
    );
  });

  it("never shows a plain success toast when ackUpdateFailures > 0, even with 0 email failures", async () => {
    const mockDetailedResult = {
      totalOpportunities: 1,
      emailsSent: 1,
      alreadyAcknowledged: 0,
      noValidContact: 0,
      emailSendFailures: 0,
      ackUpdateFailures: 1
    };
    sendAcknowledgementsDetailed.mockResolvedValue(mockDetailedResult);

    const element = createElement("c-acknowledge-donation-button", {
      is: AcknowledgeDonationButton
    });
    element.recordId = "006000000000001AAA";
    document.body.appendChild(element);

    const toastHandler = jest.fn();
    element.addEventListener(SHOW_TOAST_EVENT_NAME, toastHandler);

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await Promise.resolve();
    await Promise.resolve();

    const toastEvent = toastHandler.mock.calls[0][0];
    expect(toastEvent.detail.variant).not.toBe("success");
  });

  it("shows a success toast with no ackUpdateFailures message when there are no update failures", async () => {
    const mockDetailedResult = {
      totalOpportunities: 1,
      emailsSent: 1,
      alreadyAcknowledged: 0,
      noValidContact: 0,
      emailSendFailures: 0,
      ackUpdateFailures: 0
    };
    sendAcknowledgementsDetailed.mockResolvedValue(mockDetailedResult);

    const element = createElement("c-acknowledge-donation-button", {
      is: AcknowledgeDonationButton
    });
    element.recordId = "006000000000001AAA";
    document.body.appendChild(element);

    const toastHandler = jest.fn();
    element.addEventListener(SHOW_TOAST_EVENT_NAME, toastHandler);

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await Promise.resolve();
    await Promise.resolve();

    const toastEvent = toastHandler.mock.calls[0][0];
    expect(toastEvent.detail.variant).toBe("success");
    expect(toastEvent.detail.message).not.toContain("record update failed");
  });
});
