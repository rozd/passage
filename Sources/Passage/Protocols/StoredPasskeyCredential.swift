import Foundation

/// A passkey credential as persisted by the Relying Party. Concrete storage
/// backends (Fluent, in-memory, third-party) implement this protocol by
/// flattening the W3C credential-record fields (``credentialID``, ``publicKey``,
/// …) into their natural schema plus identity and audit fields.
///
/// Produced from ``PasskeyCredential`` by
/// ``Passage/PasskeyCredentialStore/createPasskeyCredential(for:from:)``.
///
/// See [W3C WebAuthn L3 §4 "credential record"](https://www.w3.org/TR/webauthn-3/#credential-record)
/// for the canonical definition of each field.
public protocol StoredPasskeyCredential: Sendable {
    associatedtype Id: CustomStringConvertible, Codable, Hashable, Sendable
    associatedtype AssociatedUser: User

    var id: Id? { get }
    var user: AssociatedUser { get }

    /// base64url-encoded credential ID; primary lookup key.
    var credentialID: String { get }
    /// COSE_Key bytes re-used verbatim during authentication.
    var publicKey: Data { get }
    /// Monotonic counter (may be 0 for synced passkeys).
    var signCount: UInt32 { get }
    /// `authData.flags.UV` at registration — enforces UV during later auth.
    var uvInitialized: Bool { get }
    var transports: [AuthenticatorTransport] { get }
    /// `authData.flags.BE` — credential CAN be backed up / synced.
    var backupEligible: Bool { get }
    /// `authData.flags.BS` — credential IS currently backed up.
    var isBackedUp: Bool { get }
    /// AAGUID from the attested credential data; nil for `"none"` attestation.
    var aaguid: String? { get }
    /// Attestation statement format name (`"none"`, `"packed"`, `"apple"`, …).
    var attestationFormat: String? { get }

    var createdAt: Date? { get }
    var updatedAt: Date? { get }
}
