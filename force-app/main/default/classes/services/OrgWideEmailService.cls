/**
 * Default implementation of IOrgWideEmailService
 */
public inherited sharing class OrgWideEmailService implements IOrgWideEmailService {
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
