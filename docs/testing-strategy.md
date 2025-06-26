# Testing Strategy: Focused Responsibility Assignment

## Overview

This document establishes testing guidelines and best practices for the Enhanced Donation Acknowledgements project, following the principle of focused responsibility assignment. Each test class has a single, well-defined responsibility that aligns with the component it tests.

## Testing Principles

### 1. Test One Thing

Each test method should verify one specific behavior or scenario. Avoid testing multiple unrelated behaviors in a single test method.

**Example:**

```apex
// Good - focused on one behavior
@isTest
static void testValidateOpportunitiesWithNoContact() {
  // Tests only the "no contact" validation scenario
}

// Avoid - testing multiple scenarios
@isTest
static void testValidateOpportunitiesAllScenarios() {
  // Tests no contact, no email, already acknowledged, etc.
}
```

### 2. Mock Dependencies

Unit tests should mock all external dependencies to ensure isolation and predictable behavior.

**Example:**

```apex
// Good - using mocked dependencies
MockEmailService mockEmailService = new MockEmailService();
mockEmailService.setSuccessful();
EmailSendCommand command = new EmailSendCommand(emails, oppResults);
command.setEmailService(mockEmailService);

// Avoid - using real services in unit tests
EmailSendCommand command = new EmailSendCommand(emails, oppResults);
// Uses real EmailService, making test dependent on external factors
```

### 3. Test the Interface

Test through public methods and verify observable outcomes, not implementation details.

**Example:**

```apex
// Good - testing observable behavior
EmailPreparationCommand command = new EmailPreparationCommand(opps, config);
command.execute();
EmailPrepOutput output = command.getOutput();
System.assertEquals(1, output.emails.size());

// Avoid - testing internal state
System.assertEquals('expected value', command.internalField);
```

### 4. Keep Tests Simple

Complex test setup often indicates complex production code. Prefer simple, focused tests over elaborate test scenarios.

### 5. Use Descriptive Test Names

Test method names should clearly describe what is being tested and the expected outcome.

**Example:**

```apex
// Good - descriptive names
testValidateOpportunitiesWithNoContact()
testSendEmailsSuccessfulSingleEmail()
testAggregateResultsEmptyScenario()

// Avoid - vague names
testValidation()
testEmails()
testResults()
```

## Test Responsibility Matrix

### Unit Tests (Command Level)

Commands should be tested in isolation with mocked dependencies, focusing only on their core logic.

#### EmailPreparationCommandTest

**What to Test:**

- Message preparation logic and contact mapping
- Configuration application and template ID handling
- Edge cases (empty lists, null contacts)
- Error scenarios

**What NOT to Test:**

- Actual template integration (belongs in service tests)
- OrgWide email address lookups (mocked dependency)
- Complex multi-contact scenarios (belongs in service tests)

#### EmailSendCommandTest

**What to Test:**

- Mock email service interaction
- Send error handling and result tracking
- Batch processing logic
- Output structure validation

**What NOT to Test:**

- Actual email delivery (mocked)
- Database acknowledgment updates (separate command)
- Template rendering (service responsibility)

#### OpportunityValidationCommandTest

**What to Test:**

- Business rule validation and filtering logic
- Edge case handling and error message generation
- Input validation scenarios

**What NOT to Test:**

- Database queries (use test data)
- Bulk processing performance (belongs in service tests)
- Contact relationship validation (separate concern)

#### DatabaseUpdateCommandTest

**What to Test:**

- Update mechanics and error handling
- Result tracking and empty list handling
- Individual record update logic

**What NOT to Test:**

- Transaction rollback scenarios (service responsibility)
- End-to-end acknowledgment date verification (integration test)
- Complex bulk scenarios (service responsibility)

#### ResultAggregationCommandTest

**What to Test:**

- Result compilation and summary message building
- Count calculations and error aggregation
- Output formatting

**What NOT to Test:**

- Complex workflow scenarios (service responsibility)
- Database state verification (integration concern)
- Command orchestration (service responsibility)

### Integration Tests (Service Level)

Services orchestrate commands and should test end-to-end workflows with mocked external dependencies.

#### DonationAcknowledgementServiceImplTest

**What to Test:**

- Command orchestration and workflow coordination
- Dependency injection and configuration
- Complex error scenarios and transaction behavior
- Bulk processing workflows
- Template integration scenarios
- Multi-contact acknowledgment workflows
- OrgWide email address integration

**What NOT to Test:**

- Facade delegation (belongs in facade tests)
- Invocable method mechanics (belongs in facade tests)

#### DonationAcknowledgementServiceTest

**What to Test:**

- Invocable method testing and parameter handling
- Facade delegation to implementation
- Backward compatibility verification
- Public API contract testing

**What NOT to Test:**

- Implementation details (belongs in implementation tests)
- Detailed workflow logic (belongs in implementation tests)

### Support Classes

#### AcknowledgementTestUtils

**Purpose:** Provide simple data creation and assertion helpers

**What to Include:**

- Basic data factory methods (`createTestContact`, `createTestOpportunity`)
- Common assertion helpers
- Simple setup utilities

**What NOT to Include:**

- Business logic tests
- Complex scenario builders
- Integration test utilities

#### Mock Classes (MockEmailService, MockOrgWideEmailService)

**Purpose:** Provide configurable test doubles for external dependencies

**Pattern to Follow:**

```apex
@isTest
public class MockEmailService implements IEmailService {
  private Boolean shouldSucceed = true;
  private Integer callCount = 0;

  // Configuration methods
  public MockEmailService setSuccessful() {
    this.shouldSucceed = true;
    return this;
  }
  public MockEmailService setFailure() {
    this.shouldSucceed = false;
    return this;
  }
  public MockEmailService reset() {
    this.callCount = 0;
    return this;
  }

  // Interface implementation
  public Messaging.SendEmailResult[] sendEmail(Messaging.Email[] emails) {
    callCount++;
    // Return configured response
  }

  // Verification methods
  public void verifyEmailsSent(Integer expectedCount) {
    /* assertion logic */
  }
  public Integer getCallCount() {
    return callCount;
  }
}
```

## Testing Guidelines by Scenario

### Adding New Features

1. **Start with the command test** - Focus on the core logic in isolation
2. **Add service integration test** - Test the orchestration with other commands
3. **Update facade test if needed** - Only if public API changes

### Fixing Bugs

1. **Identify the appropriate test level** - Is this a unit issue or integration issue?
2. **Write a failing test first** - Reproduce the bug in the correct test class
3. **Fix the bug** - Make the test pass
4. **Verify no regressions** - Run related test suites

### Refactoring Code

1. **Ensure tests pass before refactoring** - Green bar first
2. **Refactor production code** - Keep tests unchanged if possible
3. **Update tests only if interfaces change** - Avoid testing implementation details

## Anti-Patterns to Avoid

### Test Scope Creep

- **Problem:** Command tests testing service-level concerns
- **Solution:** Move integration scenarios to service tests

### Test Duplication

- **Problem:** Same scenarios tested in multiple files
- **Solution:** Test each scenario at the appropriate level only

### Over-Mocking

- **Problem:** Mocking everything, including value objects
- **Solution:** Mock external dependencies only, use real value objects

### Testing Implementation Details

- **Problem:** Tests break when internal implementation changes
- **Solution:** Test through public interfaces and observable behavior

### Complex Test Setup

- **Problem:** Tests require elaborate setup with many dependencies
- **Solution:** Simplify the production code or split into smaller tests

## Test Execution Strategy

### Development Workflow

1. **Run focused tests** during development (`sf apex run test --tests ClassName`)
2. **Run full command test suite** before committing command changes
3. **Run full test suite** before merging to main branch

### Continuous Integration

1. **Unit tests first** - Fast feedback on basic functionality
2. **Integration tests second** - Verify component interactions
3. **Code coverage validation** - Ensure minimum 75% coverage maintained

### Performance Considerations

- **Mock external dependencies** to avoid timeouts
- **Use minimal test data** for faster execution
- **Parallelize test execution** when possible
- **Focus on fast feedback loops** during development

## Success Metrics

### Quantitative Metrics

- **Test Execution Time:** Target <1 minute for full test suite
- **Test Failure Isolation:** Single component changes should affect ≤2 test classes
- **Code Coverage:** Maintain ≥75% org-wide coverage
- **Test Count Efficiency:** Fewer total tests with better coverage distribution

### Qualitative Metrics

- **Test Clarity:** New developers can understand test purpose within 30 seconds
- **Debugging Speed:** Test failures point directly to the problematic component
- **Maintenance Burden:** Test updates required only when related functionality changes
- **Development Confidence:** Developers trust tests to catch regressions

## Future Considerations

### When to Add New Test Classes

- **New commands:** Each command gets its own focused test class
- **New services:** Each service gets implementation and facade test classes
- **New utilities:** Only if they contain logic worth testing

### When to Split Existing Tests

- **Test class >500 lines:** Consider splitting by functional area
- **Setup method >50 lines:** Extract to utility methods or split scenarios
- **Test method >30 lines:** Split into multiple focused tests

### When to Remove Tests

- **Duplicate coverage:** Remove tests that duplicate coverage at different levels
- **Testing framework code:** Remove tests of Salesforce platform functionality
- **Implementation details:** Remove tests tied to internal implementation

---

This testing strategy ensures maintainable, focused tests that provide reliable feedback while supporting rapid development and confident refactoring.
