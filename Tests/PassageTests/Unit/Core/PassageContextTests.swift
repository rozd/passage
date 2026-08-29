import Testing
import Vapor
@testable import Passage

@Suite
struct `PassageContext Tests` {

    // MARK: - Structure Tests

    @Test
    func `PassageContext type name is correct`() {
        let typeName = String(describing: PassageContext.self)
        #expect(typeName == "PassageContext")
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `PassageContext conforms to Sendable`() {
        // This test verifies at compile time that PassageContext is Sendable
        // If PassageContext didn't conform to Sendable, this would fail to compile
        func acceptsSendable<T: Sendable>(_ type: T.Type) {}
        acceptsSendable(PassageContext.self)
    }

    // MARK: - Public Interface Tests

    @Test
    func `PassageContext has user property`() {
        // Verify PassageContext has a user property that throws
        // This is a compile-time check - if the property doesn't exist, this won't compile
        func checkUserProperty(_ context: PassageContext) throws -> any User {
            try context.user
        }
        // Test passes if it compiles
    }

    @Test
    func `PassageContext has hasUser property`() {
        // Verify PassageContext has a hasUser bool property
        func checkHasUserProperty(_ context: PassageContext) -> Bool {
            context.hasUser
        }
        // Test passes if it compiles
    }

    @Test
    func `PassageContext has login method`() {
        // Verify PassageContext has a login method that accepts a User
        func checkLoginMethod(_ context: PassageContext, _ user: any User) async throws {
            _ = try await context.login(user, origin: .login, via: .bearer)
        }
        // Test passes if it compiles
    }

    @Test
    func `PassageContext has logout method`() {
        // Verify PassageContext has a logout method
        func checkLogoutMethod(_ context: PassageContext) {
            context.logout()
        }
        // Test passes if it compiles
    }
}
