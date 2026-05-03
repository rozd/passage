import Testing
import Foundation
import Vapor
@testable import Passage

/// Exercises the `PasskeyGuestRegistrationForm` contract that the Begin-GuestRegistration
/// handler consumes before calling the service. These tests pin down the
/// identifier-extraction rules that drive the shape of the
/// `PublicKeyCredentialUserEntity` passed into `PasskeyService.beginRegistration`.
@Suite(.tags(.unit, .passkey))
struct `Passkey GuestRegistration Form Tests` {

    // MARK: - asIdentifier priority

    @Test
    func `asIdentifier returns email when only email is set`() throws {
        let form = Passage.DefaultPasskeyGuestRegistrationForm(
            email: "alice@example.com",
            phone: nil,
            username: nil,
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .email)
        #expect(identifier.value == "alice@example.com")
    }

    @Test
    func `asIdentifier returns phone when only phone is set`() throws {
        let form = Passage.DefaultPasskeyGuestRegistrationForm(
            email: nil,
            phone: "+15551234567",
            username: nil,
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .phone)
        #expect(identifier.value == "+15551234567")
    }

    @Test
    func `asIdentifier returns username when only username is set`() throws {
        let form = Passage.DefaultPasskeyGuestRegistrationForm(
            email: nil,
            phone: nil,
            username: "alice",
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .username)
        #expect(identifier.value == "alice")
    }

    @Test
    func `asIdentifier prefers email when multiple identifiers are present`() throws {
        // email > phone > username: begin-registration should never be
        // ambiguous when the client accidentally submits two identifiers.
        let form = Passage.DefaultPasskeyGuestRegistrationForm(
            email: "alice@example.com",
            phone: "+15551234567",
            username: "alice",
            displayName: "Alice"
        )

        let identifier = try form.asIdentifier()

        #expect(identifier.kind == .email)
        #expect(identifier.value == "alice@example.com")
    }

    @Test
    func `asIdentifier throws identifierNotSpecified when all are nil`() throws {
        let form = Passage.DefaultPasskeyGuestRegistrationForm(
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

    @Test
    func `DefaultPasskeyGuestRegistrationForm decodes from url-encoded form body`() throws {
        // Validate the Content wiring that the Begin-Registration route uses:
        // a url-encoded POST body must decode into the default form with the
        // optional identifier fields untouched.
        let decoder = URLEncodedFormDecoder()
        let form = try decoder.decode(
            Passage.DefaultPasskeyGuestRegistrationForm.self,
            from: "email=alice%40example.com&displayName=Alice%20A"
        )

        #expect(form.email == "alice@example.com")
        #expect(form.displayName == "Alice A")
        #expect(form.phone == nil)
        #expect(form.username == nil)
    }

    @Test
    func `Form validation rejects a malformed email value`() throws {
        var validations = Validations()
        Passage.DefaultPasskeyGuestRegistrationForm.validations(&validations)

        let result = try validations.validate(json: """
            { "email": "not-an-email", "displayName": "x" }
            """)

        // `.email || .nil` must fail on a present-but-invalid address.
        #expect(result.error != nil)
    }

    @Test
    func `Form validation accepts a nil email when using phone or username`() throws {
        var validations = Validations()
        Passage.DefaultPasskeyGuestRegistrationForm.validations(&validations)

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
@Suite(.tags(.unit, .passkey))
struct `PublicKeyCredentialUserEntity Tests` {

    @Test
    func `Email identifier becomes user.name verbatim`() {
        let entity = PublicKeyCredentialUserEntity(
            for: .email("alice@example.com"),
            displayName: "Alice"
        )
        #expect(entity.name == "alice@example.com")
        #expect(entity.displayName == "Alice")
    }

    @Test
    func `Phone identifier becomes user.name verbatim`() {
        let entity = PublicKeyCredentialUserEntity(
            for: .phone("+15551234567"),
            displayName: "Alice"
        )
        #expect(entity.name == "+15551234567")
        #expect(entity.displayName == "Alice")
    }

    @Test
    func `Username identifier becomes user.name verbatim`() {
        let entity = PublicKeyCredentialUserEntity(
            for: .username("alice"),
            displayName: "Alice A."
        )
        #expect(entity.name == "alice")
        #expect(entity.displayName == "Alice A.")
    }

    @Test
    func `Federated identifier name is formatted as "provider:value"`() {
        let entity = PublicKeyCredentialUserEntity(
            for: .federated(.google, userId: "user-123"),
            displayName: "Alice"
        )
        // google:user-123 distinguishes provider-scoped IDs so the RP
        // does not mint colliding user handles across providers.
        #expect(entity.name == "google:user-123")
    }

    @Test
    func `user.id is a 32-byte SHA-256 digest`() {
        let entity = PublicKeyCredentialUserEntity(
            for: .email("a@example.com"),
            displayName: "A"
        )
        #expect(entity.id.count == 32)
    }

    @Test
    func `user.id is stable across calls for the same identifier`() {
        let a = PublicKeyCredentialUserEntity(for: .email("x@example.com"), displayName: "X")
        let b = PublicKeyCredentialUserEntity(for: .email("x@example.com"), displayName: "X")
        // Same input, same user handle — authenticators dedupe credentials by
        // user handle, so a second begin-signup for the same identifier must
        // match the first one's handle instead of minting a fresh random blob.
        #expect(a.id == b.id)
    }

    @Test
    func `user.id differs across identifier kinds with the same value`() {
        let email = PublicKeyCredentialUserEntity(for: .email("alice"), displayName: "A")
        let username = PublicKeyCredentialUserEntity(for: .username("alice"), displayName: "A")
        #expect(email.id != username.id)
    }
}
