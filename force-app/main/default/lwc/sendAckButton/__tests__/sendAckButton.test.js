import { createElement } from "lwc";
import SendAckButton from "../sendAckButton";

describe("c-send-ack-button", () => {
  afterEach(() => {
    // Clean up DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders without error", () => {
    const element = createElement("c-send-ack-button", {
      is: SendAckButton
    });
    document.body.appendChild(element);
    expect(element).toBeDefined();
  });
});
