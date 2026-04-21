import Testing
import Vapor
import JWT
@testable import Passage

@Suite
struct `PassageBearerAuthenticator Tests` {

    // MARK: - Structure Tests

    @Test
    func `PassageBearerAuthenticator can be initialized`() {
        let authenticator = PassageBearerAuthenticator()
        #expect(authenticator != nil)
    }

    @Test
    func `PassageBearerAuthenticator type name is correct`() {
        let typeName = String(describing: PassageBearerAuthenticator.self)
        #expect(typeName == "PassageBearerAuthenticator")
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `PassageBearerAuthenticator conforms to JWTAuthenticator`() {
        let authenticator = PassageBearerAuthenticator()
        #expect(authenticator is any JWTAuthenticator)
    }

    @Test
    func `PassageBearerAuthenticator Payload typealias is AccessToken`() {
        // Verify the Payload typealias by checking the type
        let payloadType = PassageBearerAuthenticator.Payload.self
        #expect(payloadType == AccessToken.self)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `PassageBearerAuthenticator conforms to Sendable`() {
        assertSendable(PassageBearerAuthenticator())
    }
}

@Suite
struct `PassageSessionAuthenticator Tests` {

    // MARK: - Structure Tests

    @Test
    func `PassageSessionAuthenticator can be initialized`() {
        let authenticator = PassageSessionAuthenticator()
        #expect(authenticator != nil)
    }

    @Test
    func `PassageSessionAuthenticator type name is correct`() {
        let typeName = String(describing: PassageSessionAuthenticator.self)
        #expect(typeName == "PassageSessionAuthenticator")
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `PassageSessionAuthenticator conforms to AsyncAuthenticator`() {
        let authenticator = PassageSessionAuthenticator()
        #expect(authenticator is any AsyncAuthenticator)
    }

    @Test
    func `PassageSessionAuthenticator conforms to AsyncMiddleware`() {
        let authenticator = PassageSessionAuthenticator()
        #expect(authenticator is any AsyncMiddleware)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `PassageSessionAuthenticator conforms to Sendable`() {
        assertSendable(PassageSessionAuthenticator())
    }
}
