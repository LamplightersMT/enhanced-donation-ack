# Enhanced Donation Acknowledgement

This Salesforce project automates email acknowledgements for donations, similar to the Nonprofit Success Pack (NPSP). It is designed to be extensible for the addition of

## Features

- Feature parity for NPSP donation acknowledgement
  - Send acknowledgement using Classic HTML Template
  - Duplicate prevention - skips already acknowledged donations
- Logging of sent acknowledgements as Email Messages
  - Acknowledgements will show up in an Opportunity's "Activities" panel
- Apex classes and triggers for donation acknowledgement
- Enhanced error handling to prevent data integrity issues
- Detailed user feedback with counts and status information

## Setup

1. Deploy to your Salesforce org using the manifest in `manifest/package.xml`
1. Make sure that `Email > Deliverability` Access Level is "All Email"
1. Add buttons and panels to the Opportunity object
   1. Add `Mobile & Lightning Actions > Acknowledge Donation` button to the Opportunity page layout
   1. Add "Acknowledge Donations" button to `List View Buttons Layout > Opportunities List View`
   1. In `Opportunity > Lightning Record Pages > NPSP Opportunity Record Page`, add an "Activities" panel
1. Configure a default org-wide email address in `Setup > Email > Organization-Wide Addresses`
   - This must be the Default No-Reply Address for your organization
   - If no Default No-Reply Address is set, it will fall back to the individual user
1. Make sure that the profiles that will be using this have the ability to execute Flows
   - In the profile: `App Permissions > Flow & Flow Orchestration > Run Flows`

## Known Limitations

1. EDA can only send emails from the Default No-Reply Address for your organization

## Upcoming

### Roadmap

- Select org-wide email address to use
- Add resend feature
- Enhance output from flows to show which Opportunities succeeded/errored

## Future Roadmap

- Add option to edit email before sending
- Add option to select different email templates?
- Improvements to Lightning Web Components

### Technical To Do

- Enhance output from flows to show which Opportunities succeeded/errored
- Support partial email failures by collecting and examining individual Messaging.SendEmailResult objects for granular error handling

## Architecture

This project implements a **Command Pattern** architecture for processing donation acknowledgements, providing clean separation of concerns and robust error handling.

### Query Flow

#### Entry Points

- LWC Button 'Acknowledge Donation(s)' in `lwc/acknowledgeDonationButton`
  - Calls directly into apex `DonationAcknowledgementService`
- Quick Action 'Acknowledge Donation' for record views
  - Kicks off Flow 'Send_Acknowledgements' in `flows/Enhanced_Donation_Acknowledgement.flow-meta.xml`
- Mass Action Button 'Acknowledge Donations' for list views
  - Kicks off Flow 'Send_Acknowledgements' in `flows/Enhanced_Donation_Acknowledgement.flow-meta.xml`

### Core Components

#### Service Layer

- **`DonationAcknowledgementService`** - Main service class with static methods for external consumption
- **`DonationAcknowledgementServiceImpl`** - Implementation class containing the core business logic

#### Command Pattern Implementation

The system uses discrete command objects that implement `IAcknowledgementCommand` for each processing step:

1. **`OpportunityValidationCommand`** - Validates opportunities and filters out ineligible records (already acknowledged, missing contacts, etc.)
2. **`EmailPreparationCommand`** - Prepares email messages using templates or static content, maps contacts
3. **`EmailSendCommand`** - Handles actual email delivery via Salesforce Messaging API
4. **`DatabaseUpdateCommand`** - Updates opportunity records with acknowledgement dates in a single transaction
5. **`ResultAggregationCommand`** - Aggregates results from all commands into a comprehensive response

#### Supporting Classes

- **`AcknowledgementCommandOutputs`** - Contains output classes for each command with strongly-typed results
- **`IAcknowledgementCommand`** - Interface ensuring consistent command execution pattern

### Data Flow

```
Opportunities → Validation → Email Prep → Email Send → DB Update → Result Aggregation
     ↓                          ↓           ↓           ↓            ↓
  Filter invalid           Create emails Send emails Update Acks  Final report
```

### Key Features

- **Transactional Integrity** - Database updates only occur after successful email sending
- **Comprehensive Error Handling** - Each command handles its specific error scenarios
- **Duplicate Prevention** - Validates against existing acknowledgement dates
- **Detailed Reporting** - Returns success/failure status for each opportunity
- **Template Support** - Supports both Salesforce email templates and static content

### Test Architecture

The project includes comprehensive test coverage (91%) with:

- Individual test files for each command (`*CommandTest.cls`)
- Shared test utilities (`AcknowledgementTestUtils`) for consistent data setup
- Full integration tests in `DonationAcknowledgementServiceTest`

Run tests with: `scripts/run_all_tests.sh`

## Notes

- [How to use Flows for List View Records](https://www.accidentalcodersf.com/2020/07/use-flows-from-list-views-salesforce.html)
  - [a possible no-code approach](https://www.accidentalcodersf.com/2023/02/flow-list-view-pass-records.html)

## Recent Updates

### Acknowledgment Status Field Update

- Added functionality to update the `npsp__Acknowledgment_Status__c` field to "Acknowledged" when acknowledgment emails are successfully sent.
- Enhanced validation logic to skip opportunities that are already acknowledged.
- Updated test utilities and integration tests to verify acknowledgment status updates.
- Improved error handling and backward compatibility for acknowledgment status updates.
