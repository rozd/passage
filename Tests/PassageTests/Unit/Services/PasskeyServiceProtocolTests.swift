import Testing
import Foundation
import Vapor
@testable import Passage

/// Pins down the shape of the `PasskeyService` protocol + its two result
/// envelope types. These tests don't exercise any real WebAuthn verification —
/// that's the job of `WebAuthnPasskeyService` in `passage-webauthn`. Here we
/// only verify the protocol is expressible with library-agnostic primitives
/// (`Data`, `any AsyncResponseEncodable & Sendable`, core-owned DTOs) so
/// third-party conformances don't need to import any WebAuthn library.
@Suite("PasskeyService Protocol Tests", .tags(.unit))
struct PasskeyServiceProtocolTests {

    // MARK: - PasskeyBeginResult

    @Test("PasskeyBeginResult carries challenge + opaque body")
    func beginResultFields() {
        let body = StubEncodableBody(value: "ok")
        let challenge = PasskeyChallenge(
            bytes: Data([0xA1]), kind: .registration, expiresAt: Date()
        )
        let result = PasskeyBeginResult(challenge: challenge, body: body)

        #expect(result.challenge.bytes == Data([0xA1]))
        #expect(result.challenge.kind == .registration)
        #expect(result.body is StubEncodableBody)
    }

    @Test("PasskeyBeginResult is Sendable")
    func beginResultIsSendable() {
        let _: any Sendable = PasskeyBeginResult(
            challenge: PasskeyChallenge(bytes: Data(), kind: .registration, expiresAt: Date()),
            body: StubEncodableBody(value: "x")
        )
        #expect(Bool(true))
    }

    // MARK: - PasskeyFinishRegistrationResult

    @Test("PasskeyFinishRegistrationResult carries credential + matched challenge")
    func finishResultFields() {
        let credential = PasskeyCredential(
            credentialID: "id",
            publicKey: Data(),
            signCount: 0,
            uvInitialized: false,
            transports: [],
            backupEligible: false,
            isBackedUp: false,
            aaguid: nil,
            attestationFormat: nil
        )
        let storedChallenge = StubStoredChallenge(kind: .registration)
        let result = PasskeyFinishRegistrationResult(
            credential: credential, matchedChallenge: storedChallenge
        )
        #expect(result.credential.credentialID == "id")
        #expect(result.matchedChallenge.kind == .registration)
    }

    @Test("PasskeyFinishRegistrationResult is Sendable")
    func finishResultIsSendable() {
        let credential = PasskeyCredential(
            credentialID: "",
            publicKey: Data(),
            signCount: 0,
            uvInitialized: false,
            transports: [],
            backupEligible: false,
            isBackedUp: false,
            aaguid: nil,
            attestationFormat: nil
        )
        let _: any Sendable = PasskeyFinishRegistrationResult(
            credential: credential,
            matchedChallenge: StubStoredChallenge(kind: .registration)
        )
        #expect(Bool(true))
    }

    // MARK: - Protocol conformance

    @Test("PasskeyService protocol is implementable with library-agnostic primitives")
    func protocolIsImplementable() {
        let service: any Passage.PasskeyService = StubPasskeyService()
        #expect(service is StubPasskeyService)
    }

    @Test("PasskeyService is Sendable-required")
    func protocolIsSendable() {
        // If `PasskeyService` dropped its `: Sendable` requirement, this would
        // fail to compile. The runtime test simply records intent.
        let _: any Sendable = StubPasskeyService()
        #expect(Bool(true))
    }

    @Test("beginRegistration forwards PasskeyUser / Policy / challengeTTL verbatim")
    func beginForwardsArguments() async throws {
        let stub = StubPasskeyService()
        let user = PublicKeyCredentialUserEntity(
            name: "alice", id: Data([0x01]), displayName: "Alice"
        )
        let policy = Passage.Configuration.Passkey.Policy(timeout: .seconds(99))
        let result = try await stub.beginRegistration(
            with: user, policy: policy, challengeTTL: 120
        )

        #expect(result.challenge.bytes == Data([0xAA, 0xBB]))
        #expect(result.challenge.kind == .registration)
        #expect(stub.lastBeginUser?.name == "alice")
        #expect(stub.lastBeginTTL == 120)
    }

    @Test("finishRegistration consults lookupChallenge + confirmUnused closures")
    func finishInvokesClosures() async throws {
        let stub = StubPasskeyService()
        let storedChallenge = StubStoredChallenge(kind: .registration)

        let policy = Passage.Configuration.Passkey.Policy()
        let result = try await stub.finishRegistration(
            rawBody: Data(),
            policy: policy,
            lookupChallenge: { _ in storedChallenge },
            confirmUnused: { _ in true }
        )

        #expect(result.credential.credentialID == "stub-id")
        #expect(stub.finishLookupInvoked)
        #expect(stub.finishConfirmInvoked)
    }

    // MARK: - PasskeyCredentialDescriptor

    @Test("PasskeyCredentialDescriptor carries credentialID + transports verbatim")
    func descriptorFields() {
        let descriptor = PasskeyCredentialDescriptor(
            credentialID: "desc-id",
            transports: [.usb, .hybrid]
        )
        #expect(descriptor.credentialID == "desc-id")
        #expect(descriptor.transports == [.usb, .hybrid])
    }

    @Test("PasskeyCredentialDescriptor is Sendable")
    func descriptorIsSendable() {
        let _: any Sendable = PasskeyCredentialDescriptor(credentialID: "x", transports: [])
        #expect(Bool(true))
    }

    // MARK: - PasskeyFinishAuthenticationResult

    @Test("PasskeyFinishAuthenticationResult preserves all fields")
    func finishAuthenticationResultFields() {
        let credential = StubStoredCredential(credentialID: "c-1")
        let challenge = StubStoredChallenge(kind: .authentication)
        let result = PasskeyFinishAuthenticationResult(
            matchedCredential: credential,
            matchedChallenge: challenge,
            newSignCount: 42,
            credentialBackedUp: true,
            userHandle: Data([0x0A, 0x0B])
        )
        #expect(result.matchedCredential.credentialID == "c-1")
        #expect(result.matchedChallenge.kind == .authentication)
        #expect(result.newSignCount == 42)
        #expect(result.credentialBackedUp == true)
        #expect(result.userHandle == Data([0x0A, 0x0B]))
    }

    @Test("PasskeyFinishAuthenticationResult is Sendable")
    func finishAuthenticationResultIsSendable() {
        let _: any Sendable = PasskeyFinishAuthenticationResult(
            matchedCredential: StubStoredCredential(credentialID: ""),
            matchedChallenge: StubStoredChallenge(kind: .authentication),
            newSignCount: 0,
            credentialBackedUp: false,
            userHandle: nil
        )
        #expect(Bool(true))
    }

    // MARK: - Authentication ceremony methods

    @Test("beginAuthentication forwards allowCredentials + policy + TTL verbatim")
    func beginAuthenticationForwardsArguments() async throws {
        let stub = StubPasskeyService()
        let allow: [PasskeyCredentialDescriptor] = [
            .init(credentialID: "c1", transports: [.internal]),
            .init(credentialID: "c2", transports: [.hybrid]),
        ]
        let policy = Passage.Configuration.Passkey.Policy(timeout: .seconds(45))

        let result = try await stub.beginAuthentication(
            allowCredentials: allow,
            policy: policy,
            challengeTTL: 77
        )

        #expect(result.challenge.kind == .authentication)
        #expect(stub.lastBeginAuthAllow?.map(\.credentialID) == ["c1", "c2"])
        #expect(stub.lastBeginAuthTTL == 77)
    }

    @Test("beginAuthentication accepts nil allowCredentials (discoverable flow)")
    func beginAuthenticationSupportsDiscoverable() async throws {
        let stub = StubPasskeyService()
        let result = try await stub.beginAuthentication(
            allowCredentials: nil,
            policy: .init(),
            challengeTTL: 30
        )
        #expect(result.challenge.kind == .authentication)
        #expect(stub.lastBeginAuthAllow == nil)
    }

    @Test("finishAuthentication consults lookupChallenge + lookupCredential closures")
    func finishAuthenticationInvokesClosures() async throws {
        let stub = StubPasskeyService()
        let storedChallenge = StubStoredChallenge(kind: .authentication)
        let storedCredential = StubStoredCredential(credentialID: "stub-cred")

        let result = try await stub.finishAuthentication(
            rawBody: Data(),
            policy: .init(),
            lookupChallenge: { _ in storedChallenge },
            lookupCredential: { _ in storedCredential }
        )

        #expect(result.matchedCredential.credentialID == "stub-cred")
        #expect(result.matchedChallenge.kind == .authentication)
        #expect(stub.finishAuthLookupChallengeInvoked)
        #expect(stub.finishAuthLookupCredentialInvoked)
    }

    @Test("finishAuthentication surfaces invalidPasskeyChallenge when lookup returns nil")
    func finishAuthenticationThrowsOnMissingChallenge() async throws {
        let stub = StubPasskeyService()
        await #expect(throws: AuthenticationError.invalidPasskeyChallenge) {
            _ = try await stub.finishAuthentication(
                rawBody: Data(),
                policy: .init(),
                lookupChallenge: { _ in nil },
                lookupCredential: { _ in StubStoredCredential(credentialID: "x") }
            )
        }
    }

    @Test("finishAuthentication surfaces unknownPasskey when credential lookup returns nil")
    func finishAuthenticationThrowsOnUnknownCredential() async throws {
        let stub = StubPasskeyService()
        await #expect(throws: AuthenticationError.unknownPasskey) {
            _ = try await stub.finishAuthentication(
                rawBody: Data(),
                policy: .init(),
                lookupChallenge: { _ in StubStoredChallenge(kind: .authentication) },
                lookupCredential: { _ in nil }
            )
        }
    }
}

// MARK: - Stubs for this suite

private struct StubEncodableBody: AsyncResponseEncodable, Sendable {
    let value: String

    func encodeResponse(for request: Request) async throws -> Response {
        Response(status: .ok, body: .init(string: value))
    }
}

private struct StubUser: User {
    typealias Id = UUID
    var id: UUID?
    var email: String?
    var phone: String?
    var username: String?
    var passwordHash: String?
    var isAnonymous: Bool = false
    var isEmailVerified: Bool = false
    var isPhoneVerified: Bool = false
    var sessionID: String { id?.uuidString ?? "" }
}

private struct StubStoredChallenge: StoredPasskeyChallenge {
    typealias Id = UUID
    typealias AssociatedUser = StubUser

    var id: UUID?
    var user: StubUser?
    var kind: PasskeyChallengeKind
    var challengeHash: String = ""
    var expiresAt: Date = Date().addingTimeInterval(60)
    var consumedAt: Date?
    var createdAt: Date?

    init(kind: PasskeyChallengeKind) {
        self.id = UUID()
        self.kind = kind
    }
}

private struct StubStoredCredential: StoredPasskeyCredential {
    typealias Id = UUID
    typealias AssociatedUser = StubUser

    var id: UUID?
    var user: StubUser
    var credentialID: String
    var publicKey: Data
    var signCount: UInt32
    var uvInitialized: Bool
    var transports: [AuthenticatorTransport]
    var backupEligible: Bool
    var isBackedUp: Bool
    var aaguid: String?
    var attestationFormat: String?
    var createdAt: Date?
    var updatedAt: Date?

    init(credentialID: String) {
        self.id = UUID()
        self.user = StubUser(id: UUID())
        self.credentialID = credentialID
        self.publicKey = Data()
        self.signCount = 0
        self.uvInitialized = false
        self.transports = []
        self.backupEligible = false
        self.isBackedUp = false
    }
}

/// Exercises the protocol surface without any real WebAuthn verification.
private final class StubPasskeyService: Passage.PasskeyService, @unchecked Sendable {
    private(set) var lastBeginUser: PublicKeyCredentialUserEntity?
    private(set) var lastBeginTTL: TimeInterval?
    private(set) var finishLookupInvoked = false
    private(set) var finishConfirmInvoked = false

    private(set) var lastBeginAuthAllow: [PasskeyCredentialDescriptor]?
    private(set) var lastBeginAuthTTL: TimeInterval?
    private(set) var finishAuthLookupChallengeInvoked = false
    private(set) var finishAuthLookupCredentialInvoked = false

    func beginRegistration(
        with user: PublicKeyCredentialUserEntity,
        policy: Passage.Configuration.Passkey.Policy,
        challengeTTL: TimeInterval
    ) async throws -> PasskeyBeginResult {
        lastBeginUser = user
        lastBeginTTL = challengeTTL
        return PasskeyBeginResult(
            challenge: PasskeyChallenge(
                bytes: Data([0xAA, 0xBB]),
                kind: .registration,
                expiresAt: Date().addingTimeInterval(challengeTTL)
            ),
            body: StubEncodableBody(value: "stub")
        )
    }

    func finishRegistration(
        rawBody: Data,
        policy: Passage.Configuration.Passkey.Policy,
        lookupChallenge: @Sendable (_ challengeBytes: Data) async throws -> (any StoredPasskeyChallenge)?,
        confirmUnused: @Sendable (_ credentialID: String) async throws -> Bool
    ) async throws -> PasskeyFinishRegistrationResult {
        let stored = try await lookupChallenge(Data([0xAA, 0xBB]))
        finishLookupInvoked = true
        _ = try await confirmUnused("stub-id")
        finishConfirmInvoked = true

        guard let stored else {
            throw AuthenticationError.invalidPasskeyChallenge
        }

        return PasskeyFinishRegistrationResult(
            credential: PasskeyCredential(
                credentialID: "stub-id",
                publicKey: Data(),
                signCount: 0,
                uvInitialized: false,
                transports: [],
                backupEligible: false,
                isBackedUp: false,
                aaguid: nil,
                attestationFormat: nil
            ),
            matchedChallenge: stored
        )
    }

    func beginAuthentication(
        allowCredentials: [PasskeyCredentialDescriptor]?,
        policy: Passage.Configuration.Passkey.Policy,
        challengeTTL: TimeInterval
    ) async throws -> PasskeyBeginResult {
        lastBeginAuthAllow = allowCredentials
        lastBeginAuthTTL = challengeTTL
        return PasskeyBeginResult(
            challenge: PasskeyChallenge(
                bytes: Data([0xCC, 0xDD]),
                kind: .authentication,
                expiresAt: Date().addingTimeInterval(challengeTTL)
            ),
            body: StubEncodableBody(value: "stub-auth")
        )
    }

    func finishAuthentication(
        rawBody: Data,
        policy: Passage.Configuration.Passkey.Policy,
        lookupChallenge: @Sendable (_ challengeBytes: Data) async throws -> (any StoredPasskeyChallenge)?,
        lookupCredential: @Sendable (_ credentialID: String) async throws -> (any StoredPasskeyCredential)?
    ) async throws -> PasskeyFinishAuthenticationResult {
        finishAuthLookupChallengeInvoked = true
        let storedChallenge = try await lookupChallenge(Data([0xCC, 0xDD]))
        guard let storedChallenge else {
            throw AuthenticationError.invalidPasskeyChallenge
        }

        finishAuthLookupCredentialInvoked = true
        let storedCredential = try await lookupCredential("stub-cred")
        guard let storedCredential else {
            throw AuthenticationError.unknownPasskey
        }

        return PasskeyFinishAuthenticationResult(
            matchedCredential: storedCredential,
            matchedChallenge: storedChallenge,
            newSignCount: 1,
            credentialBackedUp: false,
            userHandle: nil
        )
    }
}
