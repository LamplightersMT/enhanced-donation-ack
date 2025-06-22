# Enhanced Donation Acknowledgement

This Salesforce project automates email acknowledgements for donations, similar to the Nonprofit Success Pack (NPSP).

## Features

- Apex classes and triggers for donation acknowledgement
- Email template support
- Logging of sent acknowledgements
- Enhanced error handling to prevent data integrity issues
- Duplicate prevention - skips already acknowledged donations
- Detailed user feedback with counts and status information

## Setup

1. Deploy metadata to your Salesforce org
1. Make sure that `Email > Deliverability` Access Level is "All Email"
1. Add buttons and panels to the Opportunity object
   1. Add `Mobile & Lightning Actions > Email Acknowledgement` button to the Opportunity page layout
   1. Add "Email Acknowledgements" button to `List View Buttons Layout > Opportunities List View`
   1. In `Opportunity > Lightning Record Pages > NPSP Opportunity Record Page`, add an "Activities" panel to the "Related" tab

## Next Steps

- Add resend feature
- Enhance output from flows to show which Opportunities succeeded/errored
- Enhanced email delivery error checking ✅ **IMPLEMENTED**
- Check whether an opportunity has already been acknowledged ✅ **IMPLEMENTED**
- Support partial email failures by collecting and examining individual Messaging.SendEmailResult objects for granular error handling

## Future Roadmap

- Add option to edit email before sending
- Add option to select different email templates
- Improvements to Lightning Web Components

## Notes

- [How to use Flows for List View Records](https://www.accidentalcodersf.com/2020/07/use-flows-from-list-views-salesforce.html)
  - [a possible no-code approach](https://www.accidentalcodersf.com/2023/02/flow-list-view-pass-records.html)
