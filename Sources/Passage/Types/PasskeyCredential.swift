import Foundation

/// Passage's representation of a W3C [credential record](https://www.w3.org/TR/webauthn-3/#credential-record)
/// — the Relying Party's database entry for a registered passkey. Produced by
/// ``Passage/PasskeyService/finishRegistration(rawBody:policy:lookupChallenge:confirmUnused:)``
/// and persisted via `PasskeyCredentialStore`.
///
/// Fields are aggregated from three WebAuthn structures returned by the
/// authenticator: the [authenticator data](https://www.w3.org/TR/webauthn-3/#sctn-authenticator-data) (§6.1),
/// the [attested credential data](https://www.w3.org/TR/webauthn-3/#sctn-attested-credential-data) (§6.5.1),
/// and the [attestation statement format](https://www.w3.org/TR/webauthn-3/#sctn-attestation-formats) (§6.5.2).
public struct PasskeyCredential: Sendable {
    /// `id` — base64url-encoded credential ID; primary key in storage.
    public let credentialID: String
    /// `publicKey` — COSE_Key bytes (re-used verbatim during authentication).
    public let publicKey: Data
    /// `signCount` — initial sign count (may be 0 for synced passkeys).
    public let signCount: UInt32
    /// `uvInitialized` — value of `authData.flags.UV` at registration.
    /// Used to enforce user verification during later authentications.
    public let uvInitialized: Bool
    /// `transports` — hints supplied by the authenticator via
    /// `AuthenticatorAttestationResponse.getTransports()`.
    public let transports: [AuthenticatorTransport]
    /// `backupEligible` — `authData.flags.BE`; credential CAN be backed up / synced.
    public let backupEligible: Bool
    /// `backupState` — `authData.flags.BS`; credential IS currently backed up.
    public let isBackedUp: Bool
    /// AAGUID from the attested credential data; nil for `"none"` attestation.
    /// Passage extension — not part of the W3C credential record, commonly
    /// stored for device-name resolution.
    public let aaguid: String?
    /// Attestation statement format name (`"none"`, `"packed"`, `"apple"`, …).
    /// Passage extension — not part of the W3C credential record, useful for audit.
    public let attestationFormat: String?

    public init(
        credentialID: String,
        publicKey: Data,
        signCount: UInt32,
        uvInitialized: Bool,
        transports: [AuthenticatorTransport],
        backupEligible: Bool,
        isBackedUp: Bool,
        aaguid: String?,
        attestationFormat: String?
    ) {
        self.credentialID = credentialID
        self.publicKey = publicKey
        self.signCount = signCount
        self.uvInitialized = uvInitialized
        self.transports = transports
        self.backupEligible = backupEligible
        self.isBackedUp = isBackedUp
        self.aaguid = aaguid
        self.attestationFormat = attestationFormat
    }
}
