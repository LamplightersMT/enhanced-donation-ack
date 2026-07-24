/**
 * Mock implementation of IOrgWideEmailService for testing
 */
public with sharing class MockOrgWideEmailService implements IOrgWideEmailService {
  private OrgWideEmailAddress mockAddress;
  private OrgWideEmailAddress mockAddressByAddress;
  private Integer callCount = 0;
  private Integer getByAddressCallCount = 0;
  private String lastRequestedAddress;

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
  /**
   * Configure the value returned by getByAddress(). Pass null to simulate no
   * OrgWideEmailAddress matching the configured address.
   */
  public MockOrgWideEmailService setAddressByAddressResult(
    OrgWideEmailAddress address
  ) {
    this.mockAddressByAddress = address;
    return this;
  }
  public MockOrgWideEmailService reset() {
    this.mockAddress = null;
    this.mockAddressByAddress = null;
    this.callCount = 0;
    this.getByAddressCallCount = 0;
    this.lastRequestedAddress = null;
    return this;
  }

  // Interface implementation
  public OrgWideEmailAddress getDefaultNoReplyAddress() {
    callCount++;
    return mockAddress;
  }

  public OrgWideEmailAddress getByAddress(String address) {
    getByAddressCallCount++;
    lastRequestedAddress = address;
    return mockAddressByAddress;
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
  public Integer getByAddressCallCount() {
    return getByAddressCallCount;
  }
  public String getLastRequestedAddress() {
    return lastRequestedAddress;
  }
}
