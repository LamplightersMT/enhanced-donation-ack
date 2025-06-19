import { createElement } from "lwc";
import AcknowledgeDonationButton from "../acknowledgeDonationButton";

describe("c-acknowledge-donation-button", () => {
  afterEach(() => {
    // Clean up DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders without error", () => {
    const element = createElement("c-acknowledge-donation-button", {
      is: AcknowledgeDonationButton
    });
    document.body.appendChild(element);
    expect(element).toBeDefined();
  });
});
