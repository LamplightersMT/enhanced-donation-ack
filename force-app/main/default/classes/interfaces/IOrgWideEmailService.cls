/**
 * Interface for org-wide email address service
 */
public interface IOrgWideEmailService {
  OrgWideEmailAddress getDefaultNoReplyAddress();
  OrgWideEmailAddress getByAddress(String address);
}
