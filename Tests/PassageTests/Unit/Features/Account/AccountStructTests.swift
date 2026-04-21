import Testing
@testable import Passage

@Suite(.tags(.unit))
struct `Account Struct Tests` {

    // MARK: - Structure Tests

    @Test
    func `Account struct is properly namespaced in Passage`() {
        // Verify the Account struct type name
        let typeName = String(describing: Passage.Account.self)
        #expect(typeName == "Account")
    }

    // MARK: - Feature Organization Tests

    @Test
    func `Account feature is properly namespaced`() {
        // Verify Account is correctly nested within Passage namespace
        let typeName = String(reflecting: Passage.Account.self)
        #expect(typeName.contains("Passage.Account"))
    }
}
