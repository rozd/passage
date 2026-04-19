import Testing
@testable import Passage

@Suite("Credential Tests")
struct CredentialTests {

    // MARK: - Credential Struct Tests

    @Test("Credential password initialization")
    func credentialPasswordInitialization() {
        let credential = Credential(kind: .password, secret: "hashed-password-123")

        #expect(credential.kind == Credential.Kind.password)
        #expect(credential.secret == "hashed-password-123")
    }

    @Test("Credential password convenience initializer")
    func credentialPasswordConvenienceInitializer() {
        let credential = Credential.password("hashed-password-456")

        #expect(credential.kind == Credential.Kind.password)
        #expect(credential.secret == "hashed-password-456")
    }

    @Test("Credential kind raw value")
    func credentialKindRawValue() {
        #expect(Credential.Kind.password.rawValue == "password")
    }

    @Test("Credential kind from raw value")
    func credentialKindFromRawValue() {
        #expect(Credential.Kind(rawValue: "password") == Credential.Kind.password)
        #expect(Credential.Kind(rawValue: "invalid") == nil)
    }

    @Test("Credential passkey convenience initializer")
    func credentialPasskeyConvenienceInitializer() {
        let credential = Credential.passkey("passkey-credential-data")
        #expect(credential.kind == Credential.Kind.passkey)
        #expect(credential.secret == "passkey-credential-data")
    }

    @Test("Credential passkey kind raw value")
    func credentialPasskeyKindRawValue() {
        #expect(Credential.Kind.passkey.rawValue == "passkey")
    }

    @Test("Credential kind passkey from raw value")
    func credentialKindPasskeyFromRawValue() {
        #expect(Credential.Kind(rawValue: "passkey") == Credential.Kind.passkey)
    }

    @Test("Credential conforms to Sendable")
    func credentialConformsToSendable() {
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(Credential.password("hash"))
        assertSendable(Credential.passkey("data"))
    }
}
