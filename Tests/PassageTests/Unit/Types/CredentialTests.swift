import Testing
@testable import Passage

@Suite
struct `Credential Tests` {

    // MARK: - Credential Struct Tests

    @Test
    func `Credential password initialization`() {
        let credential = Credential(kind: .password, secret: "hashed-password-123")

        #expect(credential.kind == Credential.Kind.password)
        #expect(credential.secret == "hashed-password-123")
    }

    @Test
    func `Credential password convenience initializer`() {
        let credential = Credential.password("hashed-password-456")

        #expect(credential.kind == Credential.Kind.password)
        #expect(credential.secret == "hashed-password-456")
    }

    @Test
    func `Credential kind raw value`() {
        #expect(Credential.Kind.password.rawValue == "password")
    }

    @Test
    func `Credential kind from raw value`() {
        #expect(Credential.Kind(rawValue: "password") == Credential.Kind.password)
        #expect(Credential.Kind(rawValue: "invalid") == nil)
    }

    @Test
    func `Credential passkey convenience initializer`() {
        let credential = Credential.passkey("passkey-credential-data")
        #expect(credential.kind == Credential.Kind.passkey)
        #expect(credential.secret == "passkey-credential-data")
    }

    @Test
    func `Credential passkey kind raw value`() {
        #expect(Credential.Kind.passkey.rawValue == "passkey")
    }

    @Test
    func `Credential kind passkey from raw value`() {
        #expect(Credential.Kind(rawValue: "passkey") == Credential.Kind.passkey)
    }

    @Test
    func `Credential conforms to Sendable`() {
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(Credential.password("hash"))
        assertSendable(Credential.passkey("data"))
    }
}
