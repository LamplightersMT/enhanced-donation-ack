/**
 * Mock implementation of IOrgWideEmailService for testing
 */
public class MockOrgWideEmailService implements IOrgWideEmailService {
  private OrgWideEmailAddress mockAddress;
  private Integer callCount = 0;

  public MockOrgWideEmailService(OrgWideEmailAddress address) {
    this.mockAddress = address;
  }

  // Configuration methods
  public MockOrgWideEmailService setDefaultAddress(
    OrgWideEmailAddress address
  ) {
    this.mockAddress = address;
    return this;
  }
  public MockOrgWideEmailService setNoDefault() {
    this.mockAddress = null;
    return this;
  }
  public MockOrgWideEmailService reset() {
    this.mockAddress = null;
    this.callCount = 0;
    return this;
  }

  // Interface implementation
  public OrgWideEmailAddress getDefaultNoReplyAddress() {
    callCount++;
    return mockAddress;
  }

  // Verification methods
  public void verifyGetDefaultCalled(Integer expectedCount) {
    System.assertEquals(
      expectedCount,
      callCount,
      'Expected getDefaultNoReplyAddress to be called ' +
        expectedCount +
        ' times, but was called ' +
        callCount
    );
  }
  public Integer getCallCount() {
    return callCount;
  }
}
