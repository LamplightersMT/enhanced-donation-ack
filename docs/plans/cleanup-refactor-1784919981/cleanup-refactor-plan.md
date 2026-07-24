# Cleanup and Refactor Plan: Enhanced Donation Acknowledgement

Goal: fix the correctness bugs found in the July 2026 review, remove the architectural friction that makes the codebase hard to extend, and put configuration and CI in place so the roadmap features (template selection, org-wide address selection, resend, edit-before-send) can be built on a clean foundation.

Ordering rationale: Phase A is mechanical and unblocks everything after it. Phase B fixes the user-facing bugs and is the highest-value change. Phase C deletes code and tests made redundant by A and B. Phase D is the feature enabler. Phase E is infrastructure and can run in parallel with D.

Each phase should end with all tests passing (`scripts/run_all_tests.sh`) and a working end-to-end check of the three entry points (LWC button, quick action, list view button) in a scratch org.

---

## Phase A: Extract DTOs into top-level classes

Goal: break the circular coupling between the facade and the implementation layer. Today `OpportunityResult`, `DetailedAckResult`, `AckStatus`, and `EmailConfig` are inner classes of `DonationAcknowledgementService`, forcing the impl and every command to reference back into the facade.

Constraints:

- The `@InvocableVariable` wrapper classes (`OpportunityIdWrapper`, `DetailedAckResultWrapper`, `OpportunityResultWrapper`) must stay in the class that holds the `@InvocableMethod`. Do not move them.
- Moving `@AuraEnabled` types changes the shape names the LWC receives. Field names are unchanged, so `acknowledgeDonationButton.js` needs no edits, but verify the wire format end-to-end in a scratch org before merging.

### Deliverables

1. Create `force-app/main/default/classes/domain/` with top-level classes: `AckStatus` (enum), `AckOpportunityResult` (from `OpportunityResult`), `AckDetailedResult` (from `DetailedAckResult`), `AckEmailConfig` (from `EmailConfig`). Preserve method bodies as-is; use `git mv` where a file rename applies. Add meta XML files and update `manifest/package.xml`.
2. Update all references in facade, impl, commands, outputs class, tests, and test utils. This is a find-and-replace pass; no behavior change.
3. Delete the now-empty inner classes from `DonationAcknowledgementService`. Run full test suite; deploy to scratch org; click through all three entry points.

---

## Phase B: Unify error handling and fix send/update correctness

Goal: one error channel (result objects, not exceptions), per-message send results, and correct handling of the send-succeeded-but-update-failed case. This fixes the three user-facing bugs:

- Commands build detailed failure results and then throw `AuraHandledException`, so the failure results never reach the caller and the Flow faults instead of showing a summary.
- `Messaging.sendEmail(emails)` is all-or-nothing: one bad address fails the whole batch.
- A DML failure after a successful send mislabels results as `EMAIL_SEND_FAILED` and leaves `npsp__Acknowledgment_Date__c` null, allowing donors to be re-emailed.

### Deliverables

1. Change `IEmailService.sendEmail` to return `List<Messaging.SendEmailResult>` instead of `void`/throw. `EmailService` calls `Messaging.sendEmail(emails, false)` (allOrNothing = false) and returns the results unfiltered. Update `MockEmailService` to support per-message success/failure configuration (add `setPartialFailure(List<Integer> failingIndexes)` alongside the existing helpers).
2. Rework `EmailSendCommand`: map each `SendEmailResult` back to its opportunity by index (results are returned in input order). Successful messages get `SUCCESS`; failed messages get `EMAIL_SEND_FAILED` with the per-message error text. Remove both `throw new AuraHandledException(...)` statements. `SendOutput` gains genuinely mixed success/failure lists.
3. Rework `DatabaseUpdateCommand`: use `Database.update(oppsToUpdate, false)` and map per-record results. Add a new `AckStatus.ACK_UPDATE_FAILED` for records whose email sent but whose update failed, with a reason that makes clear the email DID send and the record needs manual attention. Remove the `AuraHandledException` throws. Only opportunities whose email actually sent are passed to this command.
4. Update aggregation and counters: `AckDetailedResult` gains an `ackUpdateFailures` count; `buildSummaryMessage` and the Flow wrapper expose it; the LWC toast logic surfaces it as a warning distinct from send failures ("emails sent but N records could not be updated").
5. Delete `getOpportunityResults` from the facade (a getter-named method that sends emails; unused by the LWC). Remove its tests.
6. Switch the donor lookup from standard `Opportunity.ContactId` to `npsp__Primary_Contact__c` for NPSP parity (decided 2026-07-24). Note the decision in the README. IMPORTANT: this changes which contact receives emails for some records; must be validated against real org data in a sandbox before any production deploy.
7. Exception policy cleanup: `sendEmailsCoreDetailed` and below never throw for expected failures. The `@AuraEnabled` facade methods wrap only truly unexpected exceptions in `AuraHandledException`. The invocable method never throws; it always returns a wrapper. Add tests: Flow path with a failed send returns a summary (does not fault); LWC path with partial failure returns mixed results.

---

## Phase C: Collapse the command layer

Goal: remove ceremony that costs more than it earns. The five commands are single-use, run in a fixed order, and communicate through a mix of constructor args, `getOutput()`, a mutated shared result, and inconsistent field injection. Collapse them into private methods on `DonationAcknowledgementServiceImpl` threading a single context object. Keep the facade, keep `IEmailService`/`IOrgWideEmailService` injection.

### Deliverables

1. Create an `AckContext` class (in `domain/`) holding: opportunities, contact map, email config, prepared emails, per-opportunity results, and the running `AckDetailedResult`. This replaces `AcknowledgementCommandOutputs`.
2. Move command logic into private impl methods: `validate(ctx)`, `prepareEmails(ctx)`, `sendEmails(ctx)`, `updateRecords(ctx)`. Fix the duplication while moving: query Contacts once (validation keeps the contact map in the context; preparation reuses it), and build each `AckOpportunityResult` once. Make `orgWideEmailService` an injectable instance field on the impl, matching `emailService`.
3. Set `acknowledgmentDate` only after a confirmed successful send for that message (currently stamped optimistically before send).
4. Delete the five command classes, `IAcknowledgementCommand`, and `AcknowledgementCommandOutputs`, plus their meta XML and `package.xml` entries.
5. Fold the command test classes into `DonationAcknowledgementServiceImplTest`, keeping one test per behavior per the testing strategy doc (docs/testing-strategy.md). Target: the surviving scenarios from the five command test classes covered at the impl level with mocks; delete duplicated coverage in the facade test. The facade test keeps only invocable mechanics, delegation, and API-contract tests.

---

## Phase D: Configuration via Custom Metadata and fail-loudly template handling

Goal: make template and sender configuration admin-editable and packageable, and stop silently sending the static fallback email to real donors.

### Deliverables

1. Create `Ack_Setting__mdt` custom metadata type with fields: `Template_DeveloperName__c`, `Template_Folder__c`, `Org_Wide_Email_Address__c` (address string; empty means use default no-reply), `Active__c`. Ship one default record matching current behavior. Add object, fields, and record metadata plus `package.xml` entries.
2. Impl reads config from `Ack_Setting__mdt` (instance field allows test override, as today with the template dev name fields).
3. Replace the silent static-content fallback: if the configured template is not found, return a failed result with a clear admin-facing message ("Email template X not found in folder Y — no emails were sent") instead of sending a plain-text stub to donors. Remove `getStaticEmailConfiguration` and the static-content path entirely (decided 2026-07-24: hard error, no static mode).
4. `OrgWideEmailService` honors the configured address when present, falling back to default no-reply. Change class declaration to `inherited sharing`. This delivers the "select org-wide email address" roadmap item.
5. Update README setup instructions for the new configuration story.

---

## Phase E: CI, static analysis, and housekeeping

Goal: automated checks on every PR and cleanup of small inconsistencies. Can proceed in parallel with Phase D.

### Deliverables

1. GitHub Actions workflow (`.github/workflows/ci.yml`): on PR and push to main, run `npm ci`, `npm run prettier:verify`, `npm run lint`, `npm run test:unit:coverage`.
2. Add Salesforce Code Analyzer to CI (`sf code-analyzer run` or the official GitHub Action); fix or baseline the initial findings.
3. Scratch-org Apex test job using CumulusCI (decided 2026-07-24): `cumulusci.yml` defining the org shape, NPSP dependency install, deploy, and Apex test run; wired into the GitHub Actions workflow with JWT auth to the DevHub stored in repo secrets.
4. Housekeeping: bump `sourceApiVersion` and all metadata API versions to one current version; add `WITH USER_MODE` (or `Security.stripInaccessible`) to the Opportunity query and update paths; confirm every class has an explicit sharing declaration.
5. Optional: adopt Nebula Logger (or a minimal logging wrapper) to replace `System.debug` so production send failures are queryable. If deferred, record as a roadmap item.

---

## Out of scope (deliberately)

- Roadmap features themselves (resend, edit-before-send, template selection UI). Phase D makes template/address selection mostly configuration work.
- Batching/Queueable for very large selections. Note in README as a known limit; revisit when resend lands.
- Packaging as an unlocked package. Worth considering if this will ever deploy to more than one org.

## Decisions (2026-07-24)

1. Donor lookup: `npsp__Primary_Contact__c` (NPSP parity). Must be validated against real org data in a sandbox before production deploy.
2. Missing template: hard error, send nothing. No static-content mode.
3. CI org automation: CumulusCI.
4. Verification workflow: Apex tests run in a re-authenticated sandbox (`ackdev25` or similar) before each phase PR merges. Local checks (prettier, eslint, jest, Code Analyzer) run on every change.

## Execution workflow

- One feature branch per phase off the previous phase's branch (stacked): `refactor/phase-a-dtos`, `refactor/phase-b-error-handling`, etc.
- One PR per phase. A PR merges only after: local checks pass, Apex tests pass in the sandbox, and the diff is reviewed.
- Subagents do the mechanical work; the orchestrator reviews every diff before commit.
