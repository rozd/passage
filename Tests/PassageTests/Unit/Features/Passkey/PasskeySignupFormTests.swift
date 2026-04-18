import Testing
import Foundation
import Vapor
@testable import Passage

/// Exercises the `PasskeySignupForm` contract that the Begin-Signup
/// handler consumes before calling the service. These tests pin down the
/// identifier-extraction rules that drive the shape of the
/// `PublicKeyCredentialUserEntity` passed into `PasskeyService.beginRegistration`.
@Suite("Passkey Signup Form Tests", .tags(.unit, .passkey))
struct PasskeySignupFormTests {

    // MARK: - asIdentifier priority

    @Test("asIdentifier returns email when only email is set")
    func asIdentifierEmail() throws {
        let form = Passage.DefaultPasskeySignupForm(
            email: "alice@example.com",
            phone: nil,
            username: nil,
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .email)
        #expect(identifier.value == "alice@example.com")
    }

    @Test("asIdentifier returns phone when only phone is set")
    func asIdentifierPhone() throws {
        let form = Passage.DefaultPasskeySignupForm(
            email: nil,
            phone: "+15551234567",
            username: nil,
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .phone)
        #expect(identifier.value == "+15551234567")
    }

    @Test("asIdentifier returns username when only username is set")
    func asIdentifierUsername() throws {
        let form = Passage.DefaultPasskeySignupForm(
            email: nil,
            phone: nil,
            username: "alice",
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .username)
        #expect(identifier.value == "alice")
    }

    @Test("asIdentifier prefers email when multiple identifiers are present")
    func asIdentifierPriority() throws {
        // email > phone > username: begin-registration should never be
        // ambiguous when the client accidentally submits two identifiers.
        let form = Passage.DefaultPasskeySignupForm(
            email: "alice@example.com",
            phone: "+15551234567",
            username: "alice",
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .email)
        #expect(identifier.value == "alice@example.com")
    }

    @Test("asIdentifier throws identifierNotSpecified when all are nil")
    func asIdentifierThrowsWhenAllNil() throws {
        let form = Passage.DefaultPasskeySignupForm(
            email: nil,
            phone: nil,
            username: nil,
            displayName: "Alice"
        )

        #expect(throws: AuthenticationError.self) {
            _ = try form.asIdentifier()
        }

        // Verify the specific case too.
        do {
            _ = try form.asIdentifier()
            Issue.record("Expected asIdentifier to throw")
        } catch AuthenticationError.identifierNotSpecified {
            // ok
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Content decoding

    @Test("DefaultPasskeySignupForm decodes from url-encoded form body")
    func decodeFromFormBody() throws {
        // Validate the Content wiring that the Begin-Registration route uses:
        // a url-encoded POST body must decode into the default form with the
        // optional identifier fields untouched.
        let decoder = URLEncodedFormDecoder()
        let form = try decoder.decode(
            Passage.DefaultPasskeySignupForm.self,
            from: "email=alice%40example.com&displayName=Alice%20A"
        )

        #expect(form.email == "alice@example.com")
        #expect(form.displayName == "Alice A")
        #expect(form.phone == nil)
        #expect(form.username == nil)
    }

    @Test("Form validation rejects a malformed email value")
    func emailValidationRejectsGarbage() throws {
        var validations = Validations()
        Passage.DefaultPasskeySignupForm.validations(&validations)

        let result = try validations.validate(json: """
            { "email": "not-an-email", "displayName": "x" }
            """)

        // `.email || .nil` must fail on a present-but-invalid address.
        #expect(result.error != nil)
    }

    @Test("Form validation accepts a nil email when using phone or username")
    func emailValidationAllowsNil() throws {
        var validations = Validations()
        Passage.DefaultPasskeySignupForm.validations(&validations)

        let result = try validations.validate(json: """
            { "phone": "+15551234567", "displayName": "x" }
            """)

        #expect(result.error == nil)
    }
}

// MARK: - PublicKeyCredentialUserEntity entity building

/// The user entity passed to the WebAuthn library is assembled from the
/// `Identifier` and the form `displayName`. These checks pin down the rules
/// Passage uses — especially the `provider:value` shape for federated IDs and
/// the SHA-256-derived, stable-per-identifier `id` used when a signup user
/// doesn't exist yet.
@Suite("PublicKeyCredentialUserEntity Tests", .tags(.unit, .passkey))
struct PublicKeyCredentialUserEntityTests {

    @Test("Email identifier becomes user.name verbatim")
    func emailName() {
        let entity = PublicKeyCredentialUserEntity(
            for: .email("alice@example.com"),
            displayName: "Alice"
        )
        #expect(entity.name == "alice@example.com")
        #expect(entity.displayName == "Alice")
    }

    @Test("Phone identifier becomes user.name verbatim")
    func phoneName() {
        let entity = PublicKeyCredentialUserEntity(
            for: .phone("+15551234567"),
            displayName: "Alice"
        )
        #expect(entity.name == "+15551234567")
        #expect(entity.displayName == "Alice")
    }

    @Test("Username identifier becomes user.name verbatim")
    func usernameName() {
        let entity = PublicKeyCredentialUserEntity(
            for: .username("alice"),
            displayName: "Alice A."
        )
        #expect(entity.name == "alice")
        #expect(entity.displayName == "Alice A.")
    }

    @Test("Federated identifier name is formatted as \"provider:value\"")
    func federatedName() {
        let entity = PublicKeyCredentialUserEntity(
            for: .federated(.google, userId: "user-123"),
            displayName: "Alice"
        )
        // google:user-123 distinguishes provider-scoped IDs so the RP
        // does not mint colliding user handles across providers.
        #expect(entity.name == "google:user-123")
    }

    @Test("user.id is a 32-byte SHA-256 digest")
    func idIsSHA256SizedBlob() {
        let entity = PublicKeyCredentialUserEntity(
            for: .email("a@example.com"),
            displayName: "A"
        )
        #expect(entity.id.count == 32)
    }

    @Test("user.id is stable across calls for the same identifier")
    func idIsStable() {
        let a = PublicKeyCredentialUserEntity(for: .email("x@example.com"), displayName: "X")
        let b = PublicKeyCredentialUserEntity(for: .email("x@example.com"), displayName: "X")
        // Same input, same user handle — authenticators dedupe credentials by
        // user handle, so a second begin-signup for the same identifier must
        // match the first one's handle instead of minting a fresh random blob.
        #expect(a.id == b.id)
    }

    @Test("user.id differs across identifier kinds with the same value")
    func idNamespacedByKind() {
        let email = PublicKeyCredentialUserEntity(for: .email("alice"), displayName: "A")
        let username = PublicKeyCredentialUserEntity(for: .username("alice"), displayName: "A")
        #expect(email.id != username.id)
    }
}
