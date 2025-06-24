/**
 * Mock implementation of IOrgWideEmailService for testing
 */
@isTest
public class MockOrgWideEmailService implements System.StubProvider {
  private OrgWideEmailAddress mockAddress;
  public MockOrgWideEmailService(OrgWideEmailAddress address) {
    this.mockAddress = address;
  }
  public Object handleMethodCall(
    Object stubbedObject,
    String stubbedMethodName,
    Type returnType,
    List<Type> listOfParamTypes,
    List<String> listOfParamNames,
    List<Object> listOfArgs
  ) {
    if (stubbedMethodName == 'getDefaultNoReplyAddress') {
      return mockAddress;
    }
    return null;
  }
}
