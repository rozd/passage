import Foundation
import Vapor
@testable import Passage

// MARK: - Capturing Logger for Testing

/// Mock logger that captures logged messages for testing
final class CapturingLogger: LogHandler, @unchecked Sendable {
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace

    private(set) var warnings: [String] = []
    private(set) var errors: [String] = []

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let messageString = message.description
        switch level {
        case .warning:
            warnings.append(messageString)
        case .error, .critical:
            errors.append(messageString)
        default:
            break
        }
    }
}


// MARK: - Failing Delivery Implementations for Testing

/// Mock error for testing error handling
struct MockDeliveryError: Error, Equatable {
    let message: String
}

/// Email delivery that always throws an error
struct FailingEmailDelivery: Passage.EmailDelivery, Sendable {
    let error: Error

    init(error: Error = MockDeliveryError(message: "Email delivery failed")) {
        self.error = error
    }

    func sendEmailVerification(
        to email: String,
        user: any User,
        verificationURL: URL,
        verificationCode: String
    ) async throws {
        throw error
    }

    func sendEmailVerificationConfirmation(to email: String, user: any User) async throws {
        throw error
    }

    func sendPasswordResetEmail(
        to email: String,
        user: any User,
        passwordResetURL: URL,
        passwordResetCode: String
    ) async throws {
        throw error
    }

    func sendWelcomeEmail(to email: String, user: any User) async throws {
        throw error
    }

    func sendMagicLinkEmail(to email: String, user: (any User)?, magicLinkURL: URL) async throws {
        throw error
    }
}

/// Phone delivery that always throws an error
struct FailingPhoneDelivery: Passage.PhoneDelivery, Sendable {
    let error: Error

    init(error: Error = MockDeliveryError(message: "Phone delivery failed")) {
        self.error = error
    }

    func sendPhoneVerification(to phone: String, code: String, user: any User) async throws {
        throw error
    }

    func sendVerificationConfirmation(to phone: String, user: any User) async throws {
        throw error
    }

    func sendPasswordResetSMS(to phone: String, code: String, user: any User) async throws {
        throw error
    }
}

// MARK: - Mock Passkey Service for Testing

/// `PasskeyService` that records every ceremony call and returns deterministic
/// fixtures. Use this to test the orchestration + route handlers without
/// pulling in a real WebAuthn manager.
///
/// Defaults are chosen so that begin + finish wire up cleanly without further
/// configuration — the challenge bytes emitted by `beginRegistration` /
/// `beginAuthentication` match the ones the mock "extracts" from a finish body
/// (so `lookupChallenge` closures seeded with `sharedChallengeBytes` resolve
/// correctly in both ceremonies).
final class MockPasskeyService: Passage.PasskeyService, @unchecked Sendable {

    /// Shared challenge bytes used by both ceremonies' default builders. Tests
    /// seed their stored-challenge store with this value so begin → finish
    /// wires up without bespoke mocking.
    static let sharedChallengeBytes = Data([0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8])

    // MARK: Call records

    struct BeginCall {
        let user: PublicKeyCredentialUserEntity
        let policy: Passage.Configuration.Passkey.Policy
        let challengeTTL: TimeInterval
    }

    struct FinishCall {
        let rawBody: Data
        let policy: Passage.Configuration.Passkey.Policy
    }

    struct BeginAuthenticationCall {
        let allowCredentials: [PasskeyCredentialDescriptor]?
        let policy: Passage.Configuration.Passkey.Policy
        let challengeTTL: TimeInterval
    }

    struct FinishAuthenticationCall {
        let rawBody: Data
        let policy: Passage.Configuration.Passkey.Policy
    }

    // MARK: Behavior knobs

    /// What the mock extracts from the raw finish body when asked to look up
    /// the challenge. Same bytes are used by both ceremonies so a single seeded
    /// stored challenge satisfies both begin + finish flows by default.
    typealias ChallengeBytesSupplier = @Sendable (Data) -> Data

    /// How the mock fabricates a verified credential from the raw registration body.
    typealias FinishBuilder = @Sendable (Data) -> PasskeyCredential

    /// How the mock extracts a credential ID from the raw authentication body.
    /// Returning `nil` forces the orchestration to throw `unknownPasskey`.
    typealias CredentialIDSupplier = @Sendable (Data) -> String?

    // MARK: State

    private let lock = NSLock()
    private var _beginCalls: [BeginCall] = []
    private var _finishCalls: [FinishCall] = []
    private var _beginAuthenticationCalls: [BeginAuthenticationCall] = []
    private var _finishAuthenticationCalls: [FinishAuthenticationCall] = []

    private let beginError: (any Error)?
    private let finishError: (any Error)?
    private let beginAuthenticationError: (any Error)?
    private let finishAuthenticationError: (any Error)?

    private let challengeBytesForFinish: ChallengeBytesSupplier
    private let challengeBytesForFinishAuthentication: ChallengeBytesSupplier
    private let credentialIDForFinishAuthentication: CredentialIDSupplier
    private let finishBuilder: FinishBuilder
    private let confirmUnusedResult: Bool
    private let newSignCount: UInt32
    private let credentialBackedUp: Bool

    var calls: [BeginCall] {
        lock.withLock { _beginCalls }
    }

    var finishCalls: [FinishCall] {
        lock.withLock { _finishCalls }
    }

    var beginAuthenticationCalls: [BeginAuthenticationCall] {
        lock.withLock { _beginAuthenticationCalls }
    }

    var finishAuthenticationCalls: [FinishAuthenticationCall] {
        lock.withLock { _finishAuthenticationCalls }
    }

    // MARK: Init

    init(
        error: (any Error)? = nil,
        finishError: (any Error)? = nil,
        beginAuthenticationError: (any Error)? = nil,
        finishAuthenticationError: (any Error)? = nil,
        challengeBytesForFinish: @escaping ChallengeBytesSupplier = { _ in
            MockPasskeyService.sharedChallengeBytes
        },
        challengeBytesForFinishAuthentication: @escaping ChallengeBytesSupplier = { _ in
            MockPasskeyService.sharedChallengeBytes
        },
        credentialIDForFinishAuthentication: @escaping CredentialIDSupplier = { _ in
            "credential-id-mock"
        },
        finishBuilder: @escaping FinishBuilder = { _ in
            PasskeyCredential(
                credentialID: "credential-id-mock",
                publicKey: Data([0x30, 0x59, 0x30, 0x13]),
                signCount: 0,
                uvInitialized: false,
                transports: [.internal],
                backupEligible: false,
                isBackedUp: false,
                aaguid: nil,
                attestationFormat: nil
            )
        },
        confirmUnusedResult: Bool = true,
        newSignCount: UInt32 = 1,
        credentialBackedUp: Bool = false
    ) {
        self.beginError = error
        self.finishError = finishError
        self.beginAuthenticationError = beginAuthenticationError
        self.finishAuthenticationError = finishAuthenticationError
        self.challengeBytesForFinish = challengeBytesForFinish
        self.challengeBytesForFinishAuthentication = challengeBytesForFinishAuthentication
        self.credentialIDForFinishAuthentication = credentialIDForFinishAuthentication
        self.finishBuilder = finishBuilder
        self.confirmUnusedResult = confirmUnusedResult
        self.newSignCount = newSignCount
        self.credentialBackedUp = credentialBackedUp
    }

    // MARK: Registration

    func beginRegistration(
        with user: PublicKeyCredentialUserEntity,
        policy: Passage.Configuration.Passkey.Policy,
        challengeTTL: TimeInterval
    ) async throws -> PasskeyBeginResult {
        lock.withLock { _beginCalls.append(BeginCall(user: user, policy: policy, challengeTTL: challengeTTL)) }
        if let beginError { throw beginError }
        let challengeBytes = Self.sharedChallengeBytes
        let body = MockBeginRegistrationBody(
            rp: .init(name: "Test RP", id: "example.com"),
            user: user,
            challenge: Self.base64URL(challengeBytes)
        )
        let challenge = PasskeyChallenge(
            bytes: challengeBytes,
            kind: .registration,
            expiresAt: Date().addingTimeInterval(challengeTTL)
        )
        return PasskeyBeginResult(challenge: challenge, body: body)
    }

    func finishRegistration(
        rawBody: Data,
        policy: Passage.Configuration.Passkey.Policy,
        lookupChallenge: @Sendable (Data) async throws -> (any StoredPasskeyChallenge)?,
        confirmUnused: @Sendable (String) async throws -> Bool
    ) async throws -> PasskeyFinishRegistrationResult {
        lock.withLock { _finishCalls.append(FinishCall(rawBody: rawBody, policy: policy)) }
        if let finishError { throw finishError }

        let challengeBytes = challengeBytesForFinish(rawBody)
        guard let stored = try await lookupChallenge(challengeBytes) else {
            throw AuthenticationError.invalidPasskeyChallenge
        }

        let credential = finishBuilder(rawBody)
        let ok = try await confirmUnused(credential.credentialID)
        if !ok && confirmUnusedResult {
            // If the real credential is in the store and the policy says
            // no duplicates, swift-webauthn throws — replicate that.
            throw AuthenticationError.invalidPasskeyChallenge
        }

        return PasskeyFinishRegistrationResult(
            credential: credential,
            matchedChallenge: stored
        )
    }

    // MARK: Authentication

    func beginAuthentication(
        allowCredentials: [PasskeyCredentialDescriptor]?,
        policy: Passage.Configuration.Passkey.Policy,
        challengeTTL: TimeInterval
    ) async throws -> PasskeyBeginResult {
        lock.withLock {
            _beginAuthenticationCalls.append(
                BeginAuthenticationCall(
                    allowCredentials: allowCredentials,
                    policy: policy,
                    challengeTTL: challengeTTL
                )
            )
        }
        if let beginAuthenticationError { throw beginAuthenticationError }
        let challengeBytes = Self.sharedChallengeBytes
        let body = MockBeginAuthenticationBody(
            rpId: "example.com",
            challenge: Self.base64URL(challengeBytes),
            allowCredentials: allowCredentials?.map { $0.credentialID } ?? []
        )
        let challenge = PasskeyChallenge(
            bytes: challengeBytes,
            kind: .authentication,
            expiresAt: Date().addingTimeInterval(challengeTTL)
        )
        return PasskeyBeginResult(challenge: challenge, body: body)
    }

    func finishAuthentication(
        rawBody: Data,
        policy: Passage.Configuration.Passkey.Policy,
        lookupChallenge: @Sendable (Data) async throws -> (any StoredPasskeyChallenge)?,
        lookupCredential: @Sendable (String) async throws -> (any StoredPasskeyCredential)?
    ) async throws -> PasskeyFinishAuthenticationResult {
        lock.withLock {
            _finishAuthenticationCalls.append(
                FinishAuthenticationCall(rawBody: rawBody, policy: policy)
            )
        }
        if let finishAuthenticationError { throw finishAuthenticationError }

        let challengeBytes = challengeBytesForFinishAuthentication(rawBody)
        guard let storedChallenge = try await lookupChallenge(challengeBytes) else {
            throw AuthenticationError.invalidPasskeyChallenge
        }

        guard let credentialID = credentialIDForFinishAuthentication(rawBody) else {
            throw AuthenticationError.unknownPasskey
        }

        guard let storedCredential = try await lookupCredential(credentialID) else {
            throw AuthenticationError.unknownPasskey
        }

        return PasskeyFinishAuthenticationResult(
            matchedCredential: storedCredential,
            matchedChallenge: storedChallenge,
            newSignCount: newSignCount,
            credentialBackedUp: credentialBackedUp,
            userHandle: nil
        )
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct MockBeginRegistrationBody: Content {
    struct RP: Codable, Sendable {
        let name: String
        let id: String
    }
    let rp: RP
    let user: PublicKeyCredentialUserEntity
    let challenge: String
}

struct MockBeginAuthenticationBody: Content {
    let rpId: String
    let challenge: String
    let allowCredentials: [String]
}
