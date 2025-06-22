/**
 * Default implementation of IOrgWideEmailService
 */
public class OrgWideEmailService implements IOrgWideEmailService {
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
}
