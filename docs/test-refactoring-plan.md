# Test Refactoring Plan: Focused Responsibility Assignment

## Executive Summary

The current test suite has grown organically, resulting in overlapping responsibilities, scope creep, and maintenance challenges. This plan refactors tests to follow the Single Responsibility Principle, with each test class focused solely on testing its associated class functionality.

## Current Issues Analysis

1. **Scope Creep**: Command tests are performing integration testing that belongs at the service level
2. **Test Duplication**: Similar scenarios are tested multiple times across different files
3. **Mixed Responsibilities**: Unit tests are mixed with integration tests within the same files
4. **Maintenance Burden**: Test failures cascade across multiple files for single functionality issues

## Test Responsibility Matrix

### Unit Tests (Command Level)

Commands should be tested in isolation with mocked dependencies, focusing only on their core logic.

| Test Class                         | Primary Responsibility                        | Should Test                                                                                                                  | Should NOT Test                                                                                                           |
| ---------------------------------- | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `DatabaseUpdateCommandTest`        | Database update logic and error handling      | ✅ Update mechanics<br>✅ Error handling<br>✅ Result tracking<br>✅ Empty list handling                                     | ❌ Transaction rollback scenarios<br>❌ End-to-end acknowledgment date verification<br>❌ Integration with other commands |
| `EmailPreparationCommandTest`      | Email message preparation and contact mapping | ✅ Message preparation logic<br>✅ Contact-to-opportunity mapping<br>✅ Configuration application<br>✅ Template ID handling | ❌ Actual template integration<br>❌ OrgWide email address lookups<br>❌ Complex multi-contact scenarios                  |
| `EmailSendCommandTest`             | Email sending mechanics with mocked services  | ✅ Mock email service interaction<br>✅ Send error handling<br>✅ Result tracking<br>✅ Batch processing logic               | ❌ Actual email delivery<br>❌ Database acknowledgment updates<br>❌ Template rendering                                   |
| `OpportunityValidationCommandTest` | Validation logic and filtering                | ✅ Business rule validation<br>✅ Filtering logic<br>✅ Edge case handling<br>✅ Error message generation                    | ❌ Database queries<br>❌ Bulk processing performance<br>❌ Contact relationship validation                               |
| `ResultAggregationCommandTest`     | Result aggregation and summary building       | ✅ Result compilation<br>✅ Summary message building<br>✅ Count calculations<br>✅ Error aggregation                        | ❌ Complex workflow scenarios<br>❌ Database state verification<br>❌ Integration scenarios                               |

### Integration Tests (Service Level)

Services orchestrate commands and should test end-to-end workflows.

| Test Class                               | Primary Responsibility                           | Should Test                                                                                                                                  | Should NOT Test                                         |
| ---------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `DonationAcknowledgementServiceImplTest` | Direct service implementation testing with mocks | ✅ Command orchestration<br>✅ Dependency injection<br>✅ Complex error scenarios<br>✅ Transaction behavior<br>✅ Bulk processing workflows | ❌ Facade delegation<br>❌ Invocable method mechanics   |
| `DonationAcknowledgementServiceTest`     | Facade behavior and backward compatibility       | ✅ Invocable method testing<br>✅ Facade delegation<br>✅ Backward compatibility<br>✅ Public API contracts                                  | ❌ Implementation details<br>❌ Detailed workflow logic |

### Support Classes

Utilities and mocks should enable testing without adding their own business logic tests.

| Class                      | Primary Responsibility                   | Should Contain                                                               | Should NOT Contain                                                                       |
| -------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `AcknowledgementTestUtils` | Test data creation and assertion helpers | ✅ Data factory methods<br>✅ Common assertion helpers<br>✅ Setup utilities | ❌ Business logic tests<br>❌ Complex scenario builders<br>❌ Integration test utilities |
| `MockEmailService`         | Email service test double                | ✅ Configurable responses<br>✅ Verification methods<br>✅ State tracking    | ❌ Business logic<br>❌ Actual email functionality                                       |
| `MockOrgWideEmailService`  | OrgWide email service test double        | ✅ Configurable responses<br>✅ Verification methods<br>✅ State tracking    | ❌ Business logic<br>❌ Actual OrgWide functionality                                     |

## Implementation Plan

### Phase A: Define Test Boundaries and Responsibilities

**Goal**: Establish clear testing guidelines and document current state

#### Deliverable 1: Create Test Responsibility Matrix ✅

**File**: `docs/test-refactoring-plan.md` (this file)

- Document clear boundaries for each test class
- Define what each test should and shouldn't cover
- Establish testing principles going forward

#### Deliverable 2: ~~Update package.xml~~ (Not Required)

Documentation files do not need to be included in the Salesforce package manifest.

### Phase B: Refactor Command Tests (Remove Integration Testing)

**Goal**: Focus command tests on unit-level testing only

#### Deliverable 1: Simplify DatabaseUpdateCommandTest

**File**: `force-app/main/default/classes/tests/commands/DatabaseUpdateCommandTest.cls`

**DELETE or MOVE these test methods:**

- `testUpdateDatabaseTransactionBehavior()` - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testUpdateDatabaseBulkProcessing()` - Complex bulk scenarios - **MOVE TO** `DonationAcknowledgementServiceImplTest`

**KEEP these test methods** (focused on database update mechanics only):

- `testUpdateDatabaseSuccessfulSingleOpportunity()`
- `testUpdateDatabaseSuccessfulMultipleOpportunities()`
- `testUpdateDatabaseEmptyList()`
- `testUpdateDatabaseWithDifferentAcknowledgmentDates()`
- `testUpdateDatabaseWithInvalidOpportunityId()`
- `testUpdateDatabaseOpportunityResultModification()`
- `testUpdateOutputStructure()`
- `testUpdateDatabaseWithNullAcknowledgmentDate()`

#### Deliverable 2: Simplify EmailPreparationCommandTest

**File**: `force-app/main/default/classes/tests/commands/EmailPreparationCommandTest.cls`

**DELETE or MOVE these test methods:**

- `testPrepareEmailsWithTemplateConfig()` - Template integration - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testPrepareEmailsMultipleContacts()` - Complex multi-contact scenarios - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testPrepareEmailsWithOrgWideEmailAddress()` - OrgWide integration - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testGetDefaultOrgWideEmailAddressId_DefaultExists()` - OrgWide service integration - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testGetDefaultOrgWideEmailAddressId_SelectionAndDefaultExists()` - OrgWide service integration - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testGetDefaultOrgWideEmailAddressId_NoDefaultExists()` - OrgWide service integration - **MOVE TO** `DonationAcknowledgementServiceImplTest`

**KEEP these test methods** (focused on email preparation mechanics only):

- `testPrepareEmailsWithStaticConfig()`
- `testPrepareEmailsMultipleOpportunities()` (simplified to focus on mapping logic)
- `testPrepareEmailsEmptyList()`
- `testPrepareEmailsSkipsOpportunitiesWithNullContact()`
- `testEmailConfigurationDetails()`

#### Deliverable 3: Simplify EmailSendCommandTest

**File**: `force-app/main/default/classes/tests/commands/EmailSendCommandTest.cls`

**DELETE or MOVE these test methods:**

- `testSendEmailsWithTemplateEmail()` - Template integration - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testEmailSendCommandWithDifferentEmailTypes()` - Complex type scenarios - **MOVE TO** `DonationAcknowledgementServiceImplTest`

**KEEP these test methods** (focused on email sending mechanics with mocked services):

- `testSendEmailsSuccessfulSingleEmail()`
- `testSendEmailsSuccessfulMultipleEmails()`
- `testSendEmailsEmptyList()`
- `testEmailSendingErrorHandling()`
- `testOpportunityResultStatusUpdates()`
- `testEmailSendOutputStructure()`

#### Deliverable 4: Simplify OpportunityValidationCommandTest

**File**: `force-app/main/default/classes/tests/commands/OpportunityValidationCommandTest.cls`

**DELETE or MOVE these test methods:**

- `testValidateOpportunitiesMixedScenarios()` - Complex scenarios - **MOVE TO** `DonationAcknowledgementServiceImplTest`
- `testValidateOpportunitiesBulkProcessing()` - Bulk processing - **MOVE TO** `DonationAcknowledgementServiceImplTest`

**KEEP these test methods** (focused on validation logic only):

- `testValidateOpportunitiesWithValidOpportunity()`
- `testValidateOpportunitiesWithAlreadyAcknowledged()`
- `testValidateOpportunitiesWithNoContact()`
- `testValidateOpportunitiesWithNoEmail()`
- `testValidateOpportunitiesEmptyList()`

#### Deliverable 5: Simplify ResultAggregationCommandTest

**File**: `force-app/main/default/classes/tests/commands/ResultAggregationCommandTest.cls`

**DELETE or MOVE these test methods:**

- `testAggregateResultsCommandIntegration()` - Integration scenarios - **MOVE TO** `DonationAcknowledgementServiceImplTest`

**KEEP these test methods** (focused on result aggregation logic only):

- `testAggregateResultsSuccessfulScenario()`
- `testAggregateResultsFailedScenario()`
- `testAggregateResultsMultipleOpportunities()`
- `testAggregateResultsWithExistingSkippedOpportunities()`
- `testAggregateResultsEmptyScenario()`
- `testAggregateResultsEmailTypeMetadata()`
- `testResultAggregationCommandNoReturnValue()`

### Phase C: Consolidate Service-Level Integration Testing

**Goal**: Move complex scenarios to appropriate service tests

#### Deliverable 1: Enhance DonationAcknowledgementServiceImplTest

**File**: `force-app/main/default/classes/tests/services/DonationAcknowledgementServiceImplTest.cls`

**ADD these test methods** (moved from command tests):

From `DatabaseUpdateCommandTest`:

- `testServiceTransactionBehavior()` (renamed from `testUpdateDatabaseTransactionBehavior`)
- `testServiceBulkProcessing()` (renamed from `testUpdateDatabaseBulkProcessing`)

From `EmailPreparationCommandTest`:

- `testServiceTemplateIntegration()` (renamed from `testPrepareEmailsWithTemplateConfig`)
- `testServiceMultipleContacts()` (renamed from `testPrepareEmailsMultipleContacts`)
- `testServiceOrgWideEmailAddress()` (renamed from `testPrepareEmailsWithOrgWideEmailAddress`)
- `testServiceOrgWideEmailDefaults()` (combined from the three OrgWide test methods)

From `EmailSendCommandTest`:

- `testServiceTemplateEmailSending()` (renamed from `testSendEmailsWithTemplateEmail`)
- `testServiceDifferentEmailTypes()` (renamed from `testEmailSendCommandWithDifferentEmailTypes`)

From `OpportunityValidationCommandTest`:

- `testServiceMixedValidationScenarios()` (renamed from `testValidateOpportunitiesMixedScenarios`)
- `testServiceBulkValidationProcessing()` (renamed from `testValidateOpportunitiesBulkProcessing`)

From `ResultAggregationCommandTest`:

- `testServiceCommandIntegration()` (renamed from `testAggregateResultsCommandIntegration`)

**EXISTING test methods remain** (implementation-specific tests):

- All existing service implementation tests

#### Deliverable 2: Streamline DonationAcknowledgementServiceTest

**File**: `force-app/main/default/classes/tests/DonationAcknowledgementServiceTest.cls`

**Focus on facade behavior**:

- Invocable method testing and parameter handling
- Facade delegation to implementation
- Backward compatibility verification
- Public API contract testing

**Remove**:

- Duplicate scenarios already covered in implementation tests
- Detailed workflow logic (belongs in implementation tests)

### Phase D: Utility Optimization ✅ **(Completed June 24, 2025)**

- [x] **Deliverable 1: Fix `createMixedScenarioOpportunities()` NullPointerException** - Added defensive Contact creation in `AcknowledgementTestUtils.cls`
- [x] **Deliverable 2: Refactor AcknowledgementTestUtils (additional optimizations)** - Removed methods that encourage over-testing, eliminated complex scenario builders, and retained only basic data creation and assertion helpers. Updated all affected tests to use only simple helpers and unique test data.
- [x] Validate all tests still pass after utility changes (100% pass rate)

### Phase E: Clean up issues noticed during implementation ✅ **(Completed June 25, 2025)**

- [x] **Deliverable 1: Fix EmailPreparationCommand.orgWideEmailService static variable** - Convert to instance variable for proper dependency injection
- [x] **Deliverable 2: Replace MockOrgWideEmailService System.StubProvider with direct interface implementation** - Follow project pattern used in MockEmailService
- [x] **Deliverable 3: Validate all tests still pass after cleanup changes**

### Phase F: Validation and Documentation

**Goal**: Ensure refactoring maintains functionality and documents new approach

#### Deliverable 1: Run Focused Test Validation

Execute tests after each phase to ensure:

- All tests pass after refactoring
- Code coverage remains at acceptable levels (75%+ for production deployment)
- No functionality gaps created by removing tests
- Test execution time is improved

#### Deliverable 2: Update Testing Documentation

**File**: `docs/testing-strategy.md`

Document the new testing approach:

- Clear boundaries between unit and integration tests
- Guidelines for when to test what and where
- Best practices for adding new tests
- Patterns to avoid (scope creep indicators)

## Expected Benefits

### Reduced Maintenance Overhead

- **Fewer Duplicate Test Scenarios**: Eliminate redundant testing across multiple files
- **Clearer Failure Points**: When tests break, it's immediately clear which component has the issue
- **Faster Test Execution**: Reduced test complexity and duplication leads to faster feedback loops

### Improved Test Clarity and Purpose

- **Single Responsibility**: Each test file has one clear, focused responsibility
- **Easier Debugging**: More focused test failures make root cause analysis simpler
- **Better Documentation**: Tests serve as clear documentation of component behavior

### Enhanced Development Velocity

- **Faster Feedback Loops**: Developers get quicker feedback on their changes
- **Reduced Test Maintenance**: Less time spent fixing overlapping test failures
- **Clearer Guidance**: New developers understand exactly where to add tests for new features

### Better Code Quality

- **Forced Modularity**: Good unit tests require well-designed, modular code
- **Dependency Injection**: Testable code promotes better architectural patterns
- **Clear Contracts**: Interface-based testing clarifies component responsibilities

## Migration Strategy and Principles

### Implementation Order

1. **Start with Command Tests** - They show the most scope creep and will provide immediate benefits
2. **Move Integration Scenarios Up** - Consolidate complex scenarios in service-level tests
3. **Validate Each Phase** - Ensure no coverage gaps after each deliverable
4. **Document New Patterns** - Prevent future scope creep through clear guidelines

### Testing Principles Going Forward

1. **Test One Thing**: Each test method should verify one specific behavior
2. **Mock Dependencies**: Unit tests should mock all external dependencies
3. **Test the Interface**: Test through public methods, not implementation details
4. **Keep Tests Simple**: Complex test setup often indicates complex production code
5. **Write Tests First**: TDD ensures tests stay focused on behavior, not implementation

### Success Metrics

- **Test Execution Time**: Target 20-30% reduction in total test execution time
- **Test Failure Isolation**: Single component changes should not break tests in multiple files
- **Code Coverage**: Maintain 75%+ coverage while reducing total lines of test code
- **Developer Productivity**: Faster feedback loops and easier debugging

## Risk Mitigation

### Potential Risks

1. **Coverage Gaps**: Removing tests might leave functionality untested
2. **Integration Issues**: Unit tests with mocks might miss real integration problems
3. **Over-Mocking**: Too much mocking might hide real dependency issues

### Mitigation Strategies

1. **Comprehensive Review**: Carefully review each test removal to ensure coverage is maintained elsewhere
2. **Integration Test Layer**: Maintain focused integration tests at the service level
3. **Mock Validation**: Ensure mocks accurately represent real dependency behavior
4. **Gradual Migration**: Implement changes incrementally with validation at each step

---

## Implementation Checklist

### Pre-Implementation

- [x] Review and approve this plan

### Phase A: Documentation ✅ **(Completed June 24, 2025)**

- [x] Create test responsibility matrix
- [x] ~~Update package.xml with new documentation file~~ (Not required)
- [x] **Fix NullPointerException in `createMixedScenarioOpportunities()`** - Added defensive Contact creation

### Phase B: Command Test Refactoring ✅ **(Completed June 24, 2025)**

- [x] Refactor DatabaseUpdateCommandTest
- [x] Refactor EmailPreparationCommandTest
- [x] Refactor EmailSendCommandTest
- [x] Refactor OpportunityValidationCommandTest
- [x] Refactor ResultAggregationCommandTest
- [x] Validate all command tests pass

### Phase C: Service Test Enhancement ✅ **(Completed June 24, 2025)**

- [x] Enhance DonationAcknowledgementServiceImplTest
- [x] Streamline DonationAcknowledgementServiceTest
- [x] Validate all service tests pass

### Phase D: Utility Optimization ✅ **(Completed June 24, 2025)**

- [x] **Deliverable 1: Fix `createMixedScenarioOpportunities()` NullPointerException** - Added defensive Contact creation in `AcknowledgementTestUtils.cls`
- [x] **Deliverable 2: Refactor AcknowledgementTestUtils (additional optimizations)** - Removed methods that encourage over-testing, eliminated complex scenario builders, and retained only basic data creation and assertion helpers. Updated all affected tests to use only simple helpers and unique test data.
- [x] Validate all tests still pass after utility changes (100% pass rate)

### Phase E: Clean up issues noticed during implementation ✅ **(Completed June 25, 2025)**

- [x] **Deliverable 1: Fix EmailPreparationCommand.orgWideEmailService static variable** - Convert to instance variable for proper dependency injection
- [x] **Deliverable 2: Replace MockOrgWideEmailService System.StubProvider with direct interface implementation** - Follow project pattern used in MockEmailService
- [x] **Deliverable 3: Validate all tests still pass after cleanup changes**

### Phase F: Final Validation ✅ **(Completed June 25, 2025)**

- [x] **Deliverable 1: Run complete test suite** - All 69 tests passing (100% pass rate) with 88% org-wide coverage
- [x] **Deliverable 2: Verify code coverage targets met** - Achieved 88% coverage (exceeding 75% target)
- [x] **Deliverable 3: Create testing strategy documentation** - Created `docs/testing-strategy.md`
- [x] **Deliverable 4: Document lessons learned and new patterns** - Created `docs/lessons-learned.md`

---

_This plan prioritizes clarity, maintainability, and development velocity while ensuring comprehensive test coverage through focused, responsibility-driven testing._

## Status Summary

**All phases (A-F) are complete** - The test refactoring initiative has been successfully completed:

- ✅ **Test Architecture:** Command tests focus exclusively on unit testing with proper isolation
- ✅ **Service Integration:** Service tests handle integration scenarios and complex workflows
- ✅ **Test Quality:** Test suite is stable and passing at 100% (69/69 tests) with 88% org-wide coverage
- ✅ **Clear Responsibilities:** Test method responsibilities are clearly separated per the test responsibility matrix
- ✅ **Architectural Consistency:** All dependency injection and test pattern issues resolved
- ✅ **Documentation:** Comprehensive testing strategy and lessons learned documented

**Project Complete** - The core refactoring objectives have been achieved with comprehensive documentation to guide future development. Test suite is production-ready with improved maintainability, faster feedback loops, and clear testing guidelines.
