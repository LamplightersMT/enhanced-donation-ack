# Instance-Based Refactor Plan: DonationAcknowledgementService Architecture Migration

**Created:** June 23, 2025  
**Status:** Planning Phase  
**Goal:** Convert static method-based service architecture to instance-based architecture with proper dependency injection

## Problem Analysis

### Current Issues with Static Architecture

1. **Static State Management**: Template configuration requires setting/resetting static variables (`donationAckTemplateDevName`, `donationAckTemplateFolder`)
2. **Test Isolation Problems**: Static variables create potential side effects between tests
3. **Dependency Injection Complexity**: Static methods make it harder to inject mock dependencies
4. **Violation of OOP Principles**: Using classes as namespaces rather than true objects
5. **Maintenance Burden**: Static state requires careful cleanup in test scenarios

### Current Architecture

```
DonationAcknowledgementService (Facade)
├── Static properties for template configuration
├── @InvocableMethod and @AuraEnabled static methods
└── Delegates to static methods in DonationAcknowledgementServiceImpl

DonationAcknowledgementServiceImpl (Implementation)
├── All static methods
├── Static variables for configuration
└── Creates EmailSendCommand instances internally
```

### Target Architecture

```
DonationAcknowledgementService (Facade)
├── Static instance of DonationAcknowledgementServiceImpl
├── Static methods for dependency injection (testing)
├── Public static properties for template configuration
├── @InvocableMethod and @AuraEnabled methods delegate to instance
└── Maintains backward compatibility

DonationAcknowledgementServiceImpl (Implementation)
├── Instance variables for configuration
├── Mutable instance variables for dependency injection
└── Instance methods for all business logic
```

## Implementation Plan

### Phase A: Create Instance-Based DonationAcknowledgementServiceImpl ✅ **(Completed June 23, 2025)**

#### Deliverable 1: Refactor DonationAcknowledgementServiceImpl to use instance methods ✅

**File:** `force-app/main/default/classes/services/DonationAcknowledgementServiceImpl.cls`

**Status:** Complete. All static methods and variables converted to instance methods and instance variables. Mutable instance variable for dependency injection added. No constructor-based injection remains.

**Changes:**

- Convert all static methods to instance methods
- Convert static variables to instance variables with default initialization
- Add mutable instance variables for dependency injection
- Remove constructor-based dependency injection in favor of mutable instance variables

**New Instance Variable Pattern:**

```apex
public with sharing class DonationAcknowledgementServiceImpl {
  private String donationAckTemplateDevName = 'Donation_Acknowledgement_Template';
  private String donationAckTemplateFolder = 'Lamplighters_Templates';

  // Mutable instance variable for dependency injection
  @TestVisible
  private IEmailService emailService = new EmailService();

  // Default constructor
  public DonationAcknowledgementServiceImpl() {
    // Instance variables initialized with defaults above
  }

  // Instance methods (converted from static)
  public DetailedAckResult sendAcknowledgementsDetailed(List<Id> idList) {
    // Implementation using instance variables
    // Can inject emailService for testing: instance.emailService = mockService;
  }

  // ... other methods converted to instance methods
}
```

### Phase B: Update DonationAcknowledgementService Facade ✅ **(Completed June 23, 2025)**

#### Deliverable 1: Refactor DonationAcknowledgementService to use instance delegation ✅

**File:** `force-app/main/default/classes/DonationAcknowledgementService.cls`

**Status:** Complete. Facade now delegates to a static instance of the implementation. All static configuration properties removed; configuration is managed on the instance. Dependency injection methods implemented. All public static methods delegate to the instance.

**Changes:**

- Create static instance of DonationAcknowledgementServiceImpl
- Add static methods for dependency injection (testing)
- Update all facade methods to delegate to instance methods
- Keep static properties publicly accessible and mutable for configuration
- Maintain backward compatibility with @InvocableMethod and @AuraEnabled

**Service Instance Pattern:**

```apex
public with sharing class DonationAcknowledgementService {
  private static DonationAcknowledgementServiceImpl serviceInstance;

  // Public static properties for template configuration
  @TestVisible
  public static String donationAckTemplateDevName = 'Donation_Acknowledgement_Template';
  @TestVisible
  public static String donationAckTemplateFolder = 'Lamplighters_Templates';

  static {
    // Initialize with default configuration
    serviceInstance = new DonationAcknowledgementServiceImpl();
    // Configure instance with static properties
    serviceInstance.donationAckTemplateDevName = donationAckTemplateDevName;
    serviceInstance.donationAckTemplateFolder = donationAckTemplateFolder;
  }

  // Test support methods
  @TestVisible
  public static void setServiceInstance(
    DonationAcknowledgementServiceImpl instance
  ) {
    serviceInstance = instance;
  }

  @TestVisible
  public static void resetServiceInstance() {
    serviceInstance = new DonationAcknowledgementServiceImpl();
    serviceInstance.donationAckTemplateDevName = donationAckTemplateDevName;
    serviceInstance.donationAckTemplateFolder = donationAckTemplateFolder;
  }

  // Existing methods delegate to instance
  @AuraEnabled
  public static DetailedAckResult sendAcknowledgementsDetailed(
    List<Id> idList
  ) {
    return serviceInstance.sendAcknowledgementsDetailed(idList);
  }

  @InvocableMethod(
    label='Send Donation Acknowledgements (Enhanced)'
    description='Send acknowledgement emails for donations with detailed results for Flow processing'
  )
  public static List<DetailedAckResultWrapper> sendAcknowledgementsInvocable(
    List<OpportunityIdWrapper> inputList
  ) {
    List<Id> idList = serviceInstance.extractOpportunityIds(inputList);
    DetailedAckResult detailedResult = serviceInstance.sendAcknowledgementsDetailed(
      idList
    );
    DetailedAckResultWrapper flowResult = serviceInstance.convertToFlowWrapper(
      detailedResult
    );
    System.debug(LoggingLevel.INFO, flowResult.summaryMessage);
    return new List<DetailedAckResultWrapper>{ flowResult };
  }

  // ... other methods updated to use serviceInstance
}
```

#### Deliverable 2: Update template configuration access ✅

**Status:** Complete. Static configuration properties removed from the facade. All configuration is now managed on the implementation instance. No static property mutation or leakage remains. Backward compatibility maintained for all static entry points.

**Changes:**

- Keep `donationAckTemplateDevName` and `donationAckTemplateFolder` as public static properties
- Ensure static properties are mutable for easy configuration
- Update service instance when static properties change
- Maintain backward compatibility for existing configuration approaches

### Phase C: Update EmailSendCommand Integration ✅ **(Completed June 23, 2025)**

#### Deliverable 1: Verify EmailSendCommand compatibility ✅

**Status:** Complete. DonationAcknowledgementServiceImpl always injects its emailService instance into EmailSendCommand. All dependency injection flows are robust for both production and test scenarios. No static calls remain.

**File:** `force-app/main/default/classes/commands/EmailSendCommand.cls`

**Verification Tasks:**

- Ensure EmailSendCommand continues to work with instance-based service
- Verify existing email service injection still works
- Confirm no changes needed for EmailSendCommand itself

#### Deliverable 2: Update service-to-command integration ✅

**Status:** Complete. DonationAcknowledgementServiceImpl always injects its emailService instance into EmailSendCommand. All dependency injection flows are robust for both production and test scenarios. No static calls remain.

### Phase D: Update All Test Classes

#### Deliverable 1: Update DonationAcknowledgementServiceTest

**File:** `force-app/main/default/classes/tests/DonationAcknowledgementServiceTest.cls`

**New Test Pattern:**

```apex
@isTest
static void testMethodName() {
    // Setup test data...

    // Create service with test configuration using mutable instance variables
    DonationAcknowledgementServiceImpl testService = new DonationAcknowledgementServiceImpl();
    testService.donationAckTemplateDevName = 'Test_Template';
    testService.donationAckTemplateFolder = 'Test_Folder';
    testService.emailService = new MockEmailService().setSuccessful();

    // Inject into facade for integration testing
    DonationAcknowledgementService.setServiceInstance(testService);

    Test.startTest();
    // Execute facade methods (which delegate to instance)
    DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(opportunityIds);
    Test.stopTest();

    // Verify results
    System.assertEquals(expectedValue, result.property, 'Should have expected result');

    // Verify mock interactions
    ((MockEmailService)testService.emailService).verifyEmailCount(expectedCount);

    // Cleanup
    DonationAcknowledgementService.resetServiceInstance();
}
```

**Tests to Update:**

- `testDuplicatePreventionSkipsAcknowledgedOpportunities`
- `testEmailSendingFailureDoesNotUpdateAcknowledgmentDate`
- `testEnhancedAPIMethodsConsistency`
- `testGetOpportunityResults`
- `testSendAcknowledgementsDetailedStaticFallback`
- `testSendAcknowledgementsDetailedWithTemplate`
- `testSendAcknowledgementsStaticFallback`
- `testSendAcknowledgementsWithTemplate`
- `testSendEmailsCoreDetailedWithMixedScenarios`
- `testSendEmailsCoreDetailedWithSuccessfulOpportunities`

#### Deliverable 2: Update DonationAcknowledgementServiceImplTest

**File:** `force-app/main/default/classes/tests/services/DonationAcknowledgementServiceImplTest.cls`

**New Test Pattern:**

```apex
@isTest
static void testMethodName() {
    // Setup test data...

    // Create service instance directly with test configuration using mutable variables
    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    service.donationAckTemplateDevName = 'Test_Template';
    service.donationAckTemplateFolder = 'Test_Folder';
    service.emailService = new MockEmailService().setSuccessful();

    Test.startTest();
    // Call instance methods directly
    DetailedAckResult result = service.sendAcknowledgementsDetailed(opportunityIds);
    Test.stopTest();

    // Verify results
    System.assertEquals(expectedValue, result.property, 'Should have expected result');

    // Verify mock interactions
    ((MockEmailService)service.emailService).verifyEmailCount(expectedCount);

    // No cleanup needed - instance scope automatically isolates tests
}
```

**Tests to Update:**

- `testSendEmailsCoreDetailedWithMixedScenarios`
- `testSendEmailsCoreDetailedWithSuccessfulOpportunities`
- `testSendEmailsCoreWithResultReturnsMigratedFunctionality`
- `testSendEmailsCoreWithStaticConfig`

#### Deliverable 3: Update AcknowledgementTestUtils

**File:** `force-app/main/default/classes/tests/utils/AcknowledgementTestUtils.cls`

**New Helper Methods:**

```apex
/**
 * Create a test service instance with successful email service
 * @param templateDevName Custom template developer name for testing
 * @param templateFolder Custom template folder for testing
 * @return Configured service instance ready for testing
 */
public static DonationAcknowledgementServiceImpl createTestServiceInstance(
    String templateDevName,
    String templateFolder
) {
    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
    service.donationAckTemplateDevName = templateDevName;
    service.donationAckTemplateFolder = templateFolder;
    service.emailService = new MockEmailService().setSuccessful();
    return service;
}

/**
 * Create a test service instance with default configuration and successful email service
 * @return Configured service instance with default settings
 */
public static DonationAcknowledgementServiceImpl createDefaultTestServiceInstance() {
    return createTestServiceInstance('Test_Template', 'Test_Folder');
}

/**
 * Setup integration testing by injecting test service into facade
 * @param service The service instance to inject
 * @return The same service instance for fluent usage
 */
public static DonationAcknowledgementServiceImpl setupIntegrationTestService(
    DonationAcknowledgementServiceImpl service
) {
    DonationAcknowledgementService.setServiceInstance(service);
    return service;
}

/**
 * Reset facade to default state after integration tests
 */
public static void resetIntegrationTestService() {
    DonationAcknowledgementService.resetServiceInstance();
}

/**
 * Create and setup a test service for integration testing with one call
 * @return MockEmailService for verification in tests
 */
public static MockEmailService setupIntegrationTestWithMockEmail() {
    DonationAcknowledgementServiceImpl testService = new DonationAcknowledgementServiceImpl();
    testService.donationAckTemplateDevName = 'Test_Template';
    testService.donationAckTemplateFolder = 'Test_Folder';
    MockEmailService mockEmailService = new MockEmailService().setSuccessful();
    testService.emailService = mockEmailService;
    setupIntegrationTestService(testService);
    return mockEmailService;
}
```

### Phase E: Validation and Cleanup

#### Deliverable 1: Validation Testing Schedule

**Step 1: Unit Test Validation**

```bash
# Test individual classes
sf apex run test --test-class-names EmailSendCommandTest --result-format human --synchronous
sf apex run test --test-class-names DonationAcknowledgementServiceImplTest --result-format human --synchronous
```

**Step 2: Integration Test Validation**

```bash
# Test facade integration
sf apex run test --test-class-names DonationAcknowledgementServiceTest --result-format human --synchronous
```

**Step 3: Full Test Suite Validation**

```bash
# Run all tests
./scripts/run_all_tests.sh
```

**Success Criteria:**

- 100% test pass rate
- No static variable manipulation in any test
- All tests properly isolated
- Existing @InvocableMethod and @AuraEnabled functionality unchanged

#### Deliverable 2: Documentation Updates

**Code Comments to Add:**

```apex
/**
 * DonationAcknowledgementService supports two dependency injection patterns:
 *
 * 1. Direct instance creation (for unit tests):
 *    DonationAcknowledgementServiceImpl service = new DonationAcknowledgementServiceImpl();
 *    service.donationAckTemplateDevName = 'Test_Template';
 *    service.emailService = mockEmailService;
 *    DetailedAckResult result = service.sendAcknowledgementsDetailed(ids);
 *
 * 2. Facade injection (for integration tests):
 *    DonationAcknowledgementService.setServiceInstance(configuredInstance);
 *    DetailedAckResult result = DonationAcknowledgementService.sendAcknowledgementsDetailed(ids);
 *    DonationAcknowledgementService.resetServiceInstance(); // Cleanup
 *
 * The facade maintains full backward compatibility with existing @InvocableMethod
 * and @AuraEnabled integrations while enabling proper dependency injection for testing.
 */
```

## Expected Benefits

### Technical Benefits

1. **True Object-Oriented Design**: Instances with state and behavior
2. **Improved Test Isolation**: No shared static state between tests
3. **Cleaner Dependency Injection**: Mutable instance variable injection
4. **Better Maintainability**: Configuration through instance variables
5. **Enhanced Extensibility**: Easy to add new implementations without interfaces

### Testing Benefits

1. **No Static State Manipulation**: Tests don't need to set/reset class variables
2. **Proper Isolation**: Each test creates its own service instance
3. **Comprehensive Mocking**: Full control over service behavior in tests
4. **Integration Testing**: Clean facade injection for end-to-end testing
5. **Deterministic Results**: No side effects between test runs

### Development Benefits

1. **Backward Compatibility**: Existing integrations continue to work unchanged
2. **Migration Safety**: Facade pattern ensures smooth transition
3. **Future Flexibility**: Easy to add new service implementations
4. **Clean Architecture**: Clear separation of concerns and dependencies

## Migration Strategy

### Development Approach

- **Phase A & B**: Core architecture changes (can be done independently)
- **Phase C**: Integration verification (minimal changes expected)
- **Phase D**: Test updates (incremental, can be done per test class)
- **Phase E**: Final validation and cleanup

### Risk Mitigation

- **Backward Compatibility**: Facade maintains all existing public interfaces
- **Incremental Testing**: Each phase can be validated independently
- **Rollback Strategy**: Static methods remain until full migration is verified
- **Gradual Migration**: Tests can be updated one class at a time

### Success Metrics

- [ ] 100% test pass rate after migration
- [ ] No static variable manipulation in any test
- [ ] All @InvocableMethod and @AuraEnabled methods function identically
- [ ] Performance characteristics unchanged
- [ ] Code coverage maintained or improved

## Notes

- All inner classes (OpportunityResult, DetailedAckResult, etc.) remain in DonationAcknowledgementService for backward compatibility
- Email configuration and sending logic remains in respective classes
- Mutable instance variables enable flexible dependency injection without constructor complexity
- Factory patterns can be added later if multiple service implementations are needed

---

**Next Steps:**

1. Begin with Phase A - DonationAcknowledgementServiceImpl refactor
2. Update implementation to use instance methods and mutable instance variables
3. Proceed through phases sequentially with testing at each step
4. Document patterns and update team on new testing approaches

## TODOs / Questions from implementation

We will discuss these after implementation is complete

- Do I prefer injecting via constructor? I might
