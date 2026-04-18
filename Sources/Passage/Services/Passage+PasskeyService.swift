import Foundation
import Vapor

public extension Passage {

    protocol PasskeyService: Sendable {

        /// Produce a registration challenge and an opaque response body for the
        /// browser. The returned ``PasskeyBeginResult/body`` is encoded directly
        /// into the HTTP response; Passage core does not inspect its shape,
        /// which keeps the core package free of any WebAuthn-library types.
        ///
        /// `challenge.bytes` is the raw challenge the service will later expect
        /// to see echoed back via `clientDataJSON` during
        /// ``finishRegistration(rawBody:policy:lookupChallenge:confirmUnused:)``.
        func beginRegistration(
            with user: PublicKeyCredentialUserEntity,
            policy: Passage.Configuration.Passkey.Policy,
            challengeTTL: TimeInterval
        ) async throws -> PasskeyBeginResult

        /// Verify the browser-posted credential and return a persistable record
        /// plus the stored challenge the service matched against.
        ///
        /// The service parses `rawBody` as the WebAuthn
        /// `PublicKeyCredential` JSON, extracts the challenge from
        /// `clientDataJSON`, and asks the caller to resolve it via
        /// `lookupChallenge`. `confirmUnused` is forwarded verbatim to
        /// `swift-webauthn`'s `confirmCredentialIDNotRegisteredYet:` API.
        func finishRegistration(
            rawBody: Data,
            policy: Passage.Configuration.Passkey.Policy,
            lookupChallenge: @Sendable (_ challengeBytes: Data) async throws -> (any StoredPasskeyChallenge)?,
            confirmUnused: @Sendable (_ credentialID: String) async throws -> Bool
        ) async throws -> PasskeyFinishRegistrationResult

        /// Produce an authentication challenge and an opaque response body for
        /// the browser. When `allowCredentials` is `nil` the implementation
        /// emits options that drive the discoverable (usernameless) ceremony;
        /// otherwise the descriptors are forwarded as the `allowCredentials`
        /// hint. `challenge.bytes` is the raw challenge the service will later
        /// expect echoed back via `clientDataJSON` during
        /// ``finishAuthentication(rawBody:policy:lookupChallenge:lookupCredential:)``.
        func beginAuthentication(
            allowCredentials: [PasskeyCredentialDescriptor]?,
            policy: Passage.Configuration.Passkey.Policy,
            challengeTTL: TimeInterval
        ) async throws -> PasskeyBeginResult

        /// Verify the browser-posted assertion and return the matched records
        /// plus the verification outputs the caller uses to update storage.
        ///
        /// The service parses `rawBody` as the WebAuthn `PublicKeyCredential`
        /// JSON, extracts the challenge from `clientDataJSON`, and asks the
        /// caller to resolve both the stored challenge (via `lookupChallenge`)
        /// and the stored credential (via `lookupCredential`, used to obtain
        /// the public key and current sign count required by the crypto
        /// check).
        func finishAuthentication(
            rawBody: Data,
            policy: Passage.Configuration.Passkey.Policy,
            lookupChallenge: @Sendable (_ challengeBytes: Data) async throws -> (any StoredPasskeyChallenge)?,
            lookupCredential: @Sendable (_ credentialID: String) async throws -> (any StoredPasskeyCredential)?
        ) async throws -> PasskeyFinishAuthenticationResult
    }
}

/// Result of ``Passage/PasskeyService/beginRegistration(with:policy:challengeTTL:)``.
///
/// Carries the raw challenge (for the caller to persist via
/// ``Passage/PasskeyChallengeStore/createPasskeyChallenge(for:from:)``) and the
/// opaque HTTP response body, which is typically the WebAuthn
/// implementation's native `PublicKeyCredentialCreationOptions` value. Core
/// treats it as ``any AsyncResponseEncodable & Sendable`` so it never has to name the
/// type.
public struct PasskeyBeginResult: Sendable {
    public let challenge: PasskeyChallenge
    public let body: any AsyncResponseEncodable & Sendable

    public init(challenge: PasskeyChallenge, body: any AsyncResponseEncodable & Sendable) {
        self.challenge = challenge
        self.body = body
    }
}

/// Result of ``Passage/PasskeyService/finishRegistration(rawBody:policy:lookupChallenge:confirmUnused:)``.
///
/// Returns the verified credential DTO for persistence via
/// ``Passage/PasskeyCredentialStore/createPasskeyCredential(for:from:)`` and
/// the stored challenge the service matched against so the caller can consume
/// it afterwards in the same transaction boundary.
public struct PasskeyFinishRegistrationResult: Sendable {
    public let credential: PasskeyCredential
    public let matchedChallenge: any StoredPasskeyChallenge

    public init(credential: PasskeyCredential, matchedChallenge: any StoredPasskeyChallenge) {
        self.credential = credential
        self.matchedChallenge = matchedChallenge
    }
}

/// Result of ``Passage/PasskeyService/finishAuthentication(rawBody:policy:lookupChallenge:lookupCredential:)``.
///
/// Carries both the resolved stored records (for user lookup and post-auth
/// bookkeeping) and the fresh verification outputs the caller persists via
/// ``Passage/PasskeyCredentialStore/updatePasskeyCredentialAfterAuthentication(forCredentialID:newSignCount:isBackedUp:)``
/// and ``Passage/PasskeyChallengeStore/consume(passkeyChallenge:)``.
public struct PasskeyFinishAuthenticationResult: Sendable {
    public let matchedCredential: any StoredPasskeyCredential
    public let matchedChallenge: any StoredPasskeyChallenge
    public let newSignCount: UInt32
    public let credentialBackedUp: Bool
    public let userHandle: Data?

    public init(
        matchedCredential: any StoredPasskeyCredential,
        matchedChallenge: any StoredPasskeyChallenge,
        newSignCount: UInt32,
        credentialBackedUp: Bool,
        userHandle: Data?
    ) {
        self.matchedCredential = matchedCredential
        self.matchedChallenge = matchedChallenge
        self.newSignCount = newSignCount
        self.credentialBackedUp = credentialBackedUp
        self.userHandle = userHandle
    }
}
