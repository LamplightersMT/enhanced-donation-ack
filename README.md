# Enhanced Donation Acknowledgement

This Salesforce project automates email acknowledgements for donations, similar to the Nonprofit Success Pack (NPSP). It is designed to be modular and exstensible.

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
   - This must be the Default No-Reply Address for your organization, unless you configure
     a specific `Org-Wide Email Address` on the Ack Setting record below
   - If no Default No-Reply Address is set (and no Ack Setting org-wide address is
     configured, or it can't be found), the email will fall back to the individual user
1. Configure the acknowledgement email in `Setup > Custom Metadata Types > Ack Setting > Manage Records`
   - Edit the `Default` record (or create your own and mark it `Active`)
   - `Template Developer Name` / `Template Folder` - identify the EmailTemplate to send.
     The `Default` record ships pointing at `HTML_Donation_Acknowledgement` in the
     `EnhancedDonationAcknowledgements` folder
   - `Org-Wide Email Address` (optional) - the exact Address of an
     `Organization-Wide Address` to send from. Leave blank to use the org's Default
     No-Reply Address (the previous, and still default, behavior)
   - `Active` - only one `Ack_Setting__mdt` record should be Active at a time; the
     first Active record found is used. If no record is Active, the app falls back to
     the same hardcoded defaults the `Default` record ships with, so behavior is
     unchanged if you don't touch this
1. Make sure that the profiles that will be using this have the ability to execute Flows
   - In the profile: `App Permissions > Flow & Flow Orchestration > Run Flows`
1. Ensure that the `Enhanced Donation Acknowledgement` flow is enabled

### Missing Template Behavior

If the `Template Developer Name` / `Template Folder` configured on the active
`Ack_Setting__mdt` record don't resolve to an actual `EmailTemplate`, this is treated
as a hard configuration error: **no emails are sent and no Opportunities are updated**.
Every requested Opportunity is reported with status `CONFIG_ERROR` and a reason
explaining which template/folder was not found. This replaces an earlier behavior where
a missing template silently fell back to a generic static-content email - that fallback
has been removed so a misconfiguration is never mistaken for a successfully-sent,
on-brand acknowledgement. Check the Ack Setting configuration and the `EmailTemplate`'s
folder/deployment status to resolve it.

## Donor Contact Source

This app acknowledges the Opportunity's **NPSP Primary Contact** (`npsp__Primary_Contact__c`),
not the standard `Opportunity.ContactId` field. NPSP keeps these in sync via the primary
Contact Role on the Opportunity, but the two can diverge in orgs with customized Contact
Role automation. **Verify that `npsp__Primary_Contact__c` matches your organization's
expectations for "who gets acknowledged" before relying on this app in production.**

## Known Limitations

1. Only one email template can be configured at a time (via `Ack_Setting__mdt`) - there
   is no per-Opportunity or per-donor template selection

## Upcoming

### Roadmap

- Add resend feature
- Enhance output from flows to show which Opportunities succeeded/errored

## Future Roadmap

- Add option to edit email before sending
- Add option to select different email templates?
- Improvements to Lightning Web Components

### Technical To Do

- Enhance output from flows to show which Opportunities succeeded/errored

## Architecture

This project implements a **Facade + service-methods** architecture for processing donation acknowledgements, providing clean separation of concerns and robust error handling.

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

#### Send Pipeline

`DonationAcknowledgementServiceImpl.sendEmailsCoreDetailed()` orchestrates the send pipeline as private methods threading a single `AckContext` through each step (rather than a chain of single-use command objects):

1. **`validate(ctx)`** - Validates opportunities and filters out ineligible records (already acknowledged, missing contacts, etc.); queries Contacts once and builds each valid opportunity's result
2. **`prepareEmails(ctx)`** - Prepares email messages using templates or static content, reusing the Contact map from validation
3. **`sendEmails(ctx)`** - Handles actual email delivery via Salesforce Messaging API
4. **`updateRecords(ctx)`** - Updates opportunity records with acknowledgement dates in a single transaction

The final per-opportunity statuses are folded into the aggregated `AckDetailedResult` at the end of orchestration.

#### Supporting Classes

- **`AckContext`** - Mutable pipeline state (opportunities, Contact map, email config, prepared emails/results, aggregated result) passed between the steps above

### Data Flow

```
Opportunities → Validate → Prepare Emails → Send Emails → Update Records → Aggregate
     ↓              ↓            ↓              ↓              ↓             ↓
  AckContext   Filter invalid Create emails  Send emails   Update Acks   Final report
```

### Key Features

- **Transactional Integrity** - Database updates only occur after successful email sending
- **Comprehensive Error Handling** - Each pipeline step handles its specific error scenarios
- **Duplicate Prevention** - Validates against existing acknowledgement dates
- **Detailed Reporting** - Returns success/failure status for each opportunity
- **Admin-Editable Configuration** - Template, folder, and org-wide send address are
  configured via the `Ack_Setting__mdt` Custom Metadata Type (see
  [Setup](#setup)); no code changes needed to point at a different template
- **Hard Error On Missing Template** - A misconfigured/missing template is a
  `CONFIG_ERROR`, not a silent fallback (see [Missing Template Behavior](#missing-template-behavior))

### Test Architecture

The project includes comprehensive test coverage (91%) with:

- Orchestration-level tests in `DonationAcknowledgementServiceImplTest` covering the send pipeline with mocked email/org-wide services
- Shared test utilities (`AcknowledgementTestUtils`) for consistent data setup
- Facade-level tests in `DonationAcknowledgementServiceTest` covering invocable mechanics and public API contract

Run tests with: `scripts/run_all_tests.sh`

## Notes

- [How to use Flows for List View Records](https://www.accidentalcodersf.com/2020/07/use-flows-from-list-views-salesforce.html)
  - [a possible no-code approach](https://www.accidentalcodersf.com/2023/02/flow-list-view-pass-records.html)

## Recent Updates

### Admin-Editable Configuration & Hard Error on Missing Template (Phase D)

- Added the `Ack_Setting__mdt` Custom Metadata Type so admins can change the
  acknowledgement email template, its folder, and the org-wide send address without a
  deploy. See [Setup](#setup).
- `DonationAcknowledgementServiceImpl` loads the active `Ack_Setting__mdt` record once
  per instance (in the constructor) into its existing configuration fields; if no
  active record exists, the previous hardcoded defaults are used, so behavior is
  unchanged out of the box.
- Removed the silent static-content fallback that used to kick in when the configured
  template couldn't be found. A missing template is now a hard `AckStatus.CONFIG_ERROR`
  for every requested Opportunity - no emails are sent, nothing is updated, and the
  Flow/LWC/Aura callers are told exactly what's misconfigured instead of quietly
  sending a generic email. See [Missing Template Behavior](#missing-template-behavior).
- `IOrgWideEmailService` gained `getByAddress(String)`, so a configured org-wide
  address is honored when present; a configured address that can't be found falls back
  to the org's Default No-Reply Address (with a warning), rather than failing outright.

### Unified Error Handling (Phase B)

- Replaced exception-based control flow with result objects for all expected failure
  modes - email sends and database updates no longer throw for per-record failures.
- `IEmailService.sendEmail` now returns a per-message `AckSendResult` list (via
  `Messaging.sendEmail(emails, false)`), so a batch of acknowledgement emails can
  partially succeed instead of all-or-nothing.
- The database update step uses `Database.update(records, false)` so a DML failure
  on one record doesn't block the others.
- Added `AckStatus.ACK_UPDATE_FAILED` for the "email sent but the database update
  failed" case - these opportunities need manual attention to avoid a duplicate
  acknowledgement, and are surfaced via `AckDetailedResult.ackUpdateFailures` and in
  the LWC toast (which is never a plain success toast when this count is non-zero).
- Switched the donor/contact lookup from `Opportunity.ContactId` to
  `npsp__Primary_Contact__c` - see [Donor Contact Source](#donor-contact-source) above.

### Acknowledgment Status Field Update

- Added functionality to update the `npsp__Acknowledgment_Status__c` field to "Acknowledged" when acknowledgment emails are successfully sent.
- Enhanced validation logic to skip opportunities that are already acknowledged.
- Updated test utilities and integration tests to verify acknowledgment status updates.
- Improved error handling and backward compatibility for acknowledgment status updates.
