import Testing
import Vapor
@testable import Passage

@Suite("Passage Error Tests")
struct PassageErrorTests {

    // MARK: - HTTP Status Code Tests

    @Test("PassageError HTTP status codes", arguments: [
        (PassageError.notConfigured, HTTPResponseStatus.internalServerError),
        (PassageError.storeNotConfigured, HTTPResponseStatus.internalServerError),
        (PassageError.jwksNotConfigured, HTTPResponseStatus.internalServerError),
        (PassageError.emailDeliveryNotConfigured, HTTPResponseStatus.internalServerError),
        (PassageError.phoneDeliveryNotConfigured, HTTPResponseStatus.internalServerError),
        (PassageError.emailMagicLinkNotConfigured, HTTPResponseStatus.internalServerError),
        (PassageError.passkeyNotConfigured, HTTPResponseStatus.internalServerError),
        (PassageError.passkeyServiceNotAvailable, HTTPResponseStatus.internalServerError),
        (PassageError.missingEnvironmentVariable(name: "TEST"), HTTPResponseStatus.internalServerError),
        (PassageError.unexpected(message: "test"), HTTPResponseStatus.internalServerError)
    ])
    func errorStatusCodes(error: PassageError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    // MARK: - Error Reason Tests

    @Test("PassageError notConfigured reason")
    func notConfiguredReason() {
        let error = PassageError.notConfigured
        #expect(error.reason == "Passage is not configured. Call app.passage.configure() during application setup.")
    }

    @Test("PassageError storeNotConfigured reason")
    func storeNotConfiguredReason() {
        let error = PassageError.storeNotConfigured
        #expect(error.reason == "Passage store is not configured. Call app.passage.configure() during application setup.")
    }

    @Test("PassageError jwksNotConfigured reason")
    func jwksNotConfiguredReason() {
        let error = PassageError.jwksNotConfigured
        #expect(error.reason == "Passage JWKS is not configured. Call app.passage.configure() during application setup.")
    }

    @Test("PassageError emailDeliveryNotConfigured reason")
    func emailDeliveryNotConfiguredReason() {
        let error = PassageError.emailDeliveryNotConfigured
        #expect(error.reason == "Email delivery is not configured. Provide deliveryEmail in app.passage.configure().")
    }

    @Test("PassageError phoneDeliveryNotConfigured reason")
    func phoneDeliveryNotConfiguredReason() {
        let error = PassageError.phoneDeliveryNotConfigured
        #expect(error.reason == "Phone delivery is not configured. Provide deliveryPhone in app.passage.configure().")
    }

    @Test("PassageError missingEnvironmentVariable reason with variable name")
    func missingEnvironmentVariableReason() {
        let error = PassageError.missingEnvironmentVariable(name: "JWKS_FILE_PATH")
        #expect(error.reason == "Missing environment variable: JWKS_FILE_PATH")
    }

    @Test("PassageError emailMagicLinkNotConfigured reason")
    func emailMagicLinkNotConfiguredReason() {
        let error = PassageError.emailMagicLinkNotConfigured
        #expect(error.reason == "Email magic link is not configured. Provide emailMagicLink in passwordless configuration.")
    }

    @Test("PassageError passkeyNotConfigured reason")
    func passkeyNotConfiguredReason() {
        let error = PassageError.passkeyNotConfigured
        #expect(error.reason == "Passkey is not configured. Provide passkey in app.passage.configure().")
    }

    @Test("PassageError passkeyServiceNotAvailable reason")
    func passkeyServiceNotAvailableReason() {
        let error = PassageError.passkeyServiceNotAvailable
        #expect(error.reason == "Passkey service is not available. Please ensure you have integrated a passkey service implementation.")
    }

    @Test("PassageError unexpected reason with custom message")
    func unexpectedReason() {
        let error = PassageError.unexpected(message: "Something went wrong")
        #expect(error.reason == "Something went wrong")
    }

    // MARK: - Error Protocol Conformance Tests

    @Test("PassageError conforms to Error protocol")
    func errorProtocolConformance() {
        let error: any Error = PassageError.notConfigured
        #expect(error is PassageError)
    }

    @Test("PassageError conforms to AbortError protocol")
    func abortErrorConformance() {
        let error: any AbortError = PassageError.notConfigured
        #expect(error.status == .internalServerError)
        #expect(!error.reason.isEmpty)
    }

    // MARK: - Associated Values Tests

    @Test("PassageError missingEnvironmentVariable preserves variable name", arguments: [
        "JWKS",
        "JWKS_FILE_PATH",
        "DATABASE_URL",
        "CUSTOM_VAR"
    ])
    func missingEnvironmentVariablePreservesName(variableName: String) {
        let error = PassageError.missingEnvironmentVariable(name: variableName)
        #expect(error.reason.contains(variableName))
    }

    @Test("PassageError unexpected preserves custom message", arguments: [
        "Database connection failed",
        "Invalid configuration",
        "Network timeout",
        "Unknown error occurred"
    ])
    func unexpectedPreservesMessage(message: String) {
        let error = PassageError.unexpected(message: message)
        #expect(error.reason == message)
    }

    // MARK: - Error Equality Tests

    @Test("PassageError cases are distinguishable")
    func errorCasesAreDistinguishable() {
        let error1 = PassageError.notConfigured
        let error2 = PassageError.storeNotConfigured

        // Errors should have different reasons
        #expect(error1.reason != error2.reason)
    }

    @Test("PassageError with same associated values have same reason")
    func sameAssociatedValuesHaveSameReason() {
        let error1 = PassageError.missingEnvironmentVariable(name: "TEST")
        let error2 = PassageError.missingEnvironmentVariable(name: "TEST")

        #expect(error1.reason == error2.reason)
    }

    @Test("PassageError with different associated values have different reasons")
    func differentAssociatedValuesHaveDifferentReasons() {
        let error1 = PassageError.missingEnvironmentVariable(name: "VAR1")
        let error2 = PassageError.missingEnvironmentVariable(name: "VAR2")

        #expect(error1.reason != error2.reason)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    /// If the type doesn't conform to Sendable, passing it to this function
    /// will cause a compile-time error.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test("PassageError conforms to Sendable")
    func conformsToSendable() {
        assertSendable(PassageError.notConfigured)
        assertSendable(PassageError.storeNotConfigured)
        assertSendable(PassageError.emailMagicLinkNotConfigured)
        assertSendable(PassageError.passkeyNotConfigured)
        assertSendable(PassageError.passkeyServiceNotAvailable)
        assertSendable(PassageError.missingEnvironmentVariable(name: "TEST"))
        assertSendable(PassageError.unexpected(message: "test"))
    }
}
