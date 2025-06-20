import { createElement } from "lwc";
import AcknowledgeDonationButton from "../acknowledgeDonationButton";
import sendAcknowledgementsDetailed from "@salesforce/apex/DonationAcknowledgementService.sendAcknowledgementsDetailed";

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
});
