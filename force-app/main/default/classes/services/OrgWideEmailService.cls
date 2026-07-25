/**
 * Default implementation of IOrgWideEmailService
 */
public inherited sharing class OrgWideEmailService implements IOrgWideEmailService {
  /**
   * Deliberately not WITH USER_MODE / no explicit CRUD/FLS check: OrgWideEmailAddress is
   * org setup metadata, not user data - end users legitimately lack direct object access
   * to it but still need this lookup to resolve so acknowledgement emails can be sent
   * from the org-wide address. Enforcing user mode here would break sends for non-admin
   * users. Accepted PMD ApexCRUDViolation finding; see docs/ci-setup.md.
   */
  @SuppressWarnings('PMD.ApexCRUDViolation')
  public OrgWideEmailAddress getDefaultNoReplyAddress() {
    List<OrgWideEmailAddress> addresses = [
      SELECT Id, Purpose
      FROM OrgWideEmailAddress
      WHERE Purpose IN ('UserSelectionAndDefaultNoReply', 'DefaultNoReply')
      ORDER BY Address ASC
      LIMIT 1
    ];
    return addresses.isEmpty() ? null : addresses[0];
  }

  /**
   * Look up an OrgWideEmailAddress by its exact Address value, as configured via
   * Ack_Setting__mdt.Org_Wide_Email_Address__c. Returns null if no such address exists.
   */
  /**
   * Deliberately not WITH USER_MODE / no explicit CRUD/FLS check: see
   * getDefaultNoReplyAddress() above - same rationale applies to this lookup. Accepted
   * PMD ApexCRUDViolation finding; see docs/ci-setup.md.
   */
  @SuppressWarnings('PMD.ApexCRUDViolation')
  public OrgWideEmailAddress getByAddress(String address) {
    if (String.isBlank(address)) {
      return null;
    }
    List<OrgWideEmailAddress> addresses = [
      SELECT Id, Address, Purpose
      FROM OrgWideEmailAddress
      WHERE Address = :address
      LIMIT 1
    ];
    return addresses.isEmpty() ? null : addresses[0];
  }
}
