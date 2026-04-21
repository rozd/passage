import Testing
@testable import Passage

@Suite
struct `Identifier Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Email identifier initialization`() {
        let identifier = Identifier(kind: .email, value: "test@example.com", provider: nil)

        #expect(identifier.kind == Identifier.Kind.email)
        #expect(identifier.value == "test@example.com")
        #expect(identifier.provider == nil)
    }

    @Test
    func `Phone identifier initialization`() {
        let identifier = Identifier(kind: .phone, value: "+1234567890", provider: nil)

        #expect(identifier.kind == Identifier.Kind.phone)
        #expect(identifier.value == "+1234567890")
        #expect(identifier.provider == nil)
    }

    @Test
    func `Username identifier initialization`() {
        let identifier = Identifier(kind: .username, value: "johndoe", provider: nil)

        #expect(identifier.kind == Identifier.Kind.username)
        #expect(identifier.value == "johndoe")
        #expect(identifier.provider == nil)
    }

    @Test
    func `Federated identifier initialization`() {
        let identifier = Identifier(kind: .federated, value: "oauth-user-123", provider: .google)

        #expect(identifier.kind == Identifier.Kind.federated)
        #expect(identifier.value == "oauth-user-123")
        #expect(identifier.provider?.description == "google")
    }

    // MARK: - Convenience Initializer Tests

    @Test
    func `Email convenience initializer`() {
        let identifier = Identifier.email("test@example.com")

        #expect(identifier.kind == Identifier.Kind.email)
        #expect(identifier.value == "test@example.com")
        #expect(identifier.provider == nil)
    }

    @Test
    func `Phone convenience initializer`() {
        let identifier = Identifier.phone("+1234567890")

        #expect(identifier.kind == Identifier.Kind.phone)
        #expect(identifier.value == "+1234567890")
        #expect(identifier.provider == nil)
    }

    @Test
    func `Username convenience initializer`() {
        let identifier = Identifier.username("johndoe")

        #expect(identifier.kind == Identifier.Kind.username)
        #expect(identifier.value == "johndoe")
        #expect(identifier.provider == nil)
    }

    @Test
    func `Federated convenience initializer`() {
        let identifier = Identifier.federated(.github, userId: "12345")

        #expect(identifier.kind == Identifier.Kind.federated)
        #expect(identifier.value == "12345")
        #expect(identifier.provider?.description == "github")
    }

    // MARK: - Error Support Tests

    @Test(arguments: [
        (Identifier.Kind.email, AuthenticationError.emailAlreadyRegistered),
        (Identifier.Kind.phone, AuthenticationError.phoneAlreadyRegistered),
        (Identifier.Kind.username, AuthenticationError.usernameAlreadyRegistered),
        (Identifier.Kind.federated, AuthenticationError.federatedAccountAlreadyLinked)
    ])
    func `Identifier error when already registered`(kind: Identifier.Kind, expected: AuthenticationError) {
        let identifier = Identifier(kind: kind, value: "test-value", provider: kind == .federated ? .named("test-provider") : nil)
        #expect(identifier.errorWhenIdentifierAlreadyRegistered == expected)
    }

    @Test(arguments: [
        (Identifier.Kind.email, AuthenticationError.invalidEmailOrPassword),
        (Identifier.Kind.phone, AuthenticationError.invalidPhoneOrPassword),
        (Identifier.Kind.username, AuthenticationError.invalidUsernameOrPassword),
        (Identifier.Kind.federated, AuthenticationError.federatedLoginFailed)
    ])
    func `Identifier error when invalid`(kind: Identifier.Kind, expected: AuthenticationError) {
        let identifier = Identifier(kind: kind, value: "test-value", provider: kind == .federated ? .named("test-provider") : nil)
        #expect(identifier.errorWhenIdentifierIsInvalid == expected)
    }

    // MARK: - Kind Enum Tests

    @Test(arguments: [
        (Identifier.Kind.email, "email"),
        (Identifier.Kind.phone, "phone"),
        (Identifier.Kind.username, "username"),
        (Identifier.Kind.federated, "federated")
    ])
    func `Identifier kind raw values`(kind: Identifier.Kind, expectedRawValue: String) {
        #expect(kind.rawValue == expectedRawValue)
    }

    @Test(arguments: [
        ("email", Identifier.Kind.email),
        ("phone", Identifier.Kind.phone),
        ("username", Identifier.Kind.username),
        ("federated", Identifier.Kind.federated)
    ])
    func `Identifier kind from raw value`(rawValue: String, expected: Identifier.Kind?) {
        #expect(Identifier.Kind(rawValue: rawValue) == expected)
    }

    @Test
    func `Identifier kind from invalid raw value`() {
        #expect(Identifier.Kind(rawValue: "invalid") == nil)
    }
}
