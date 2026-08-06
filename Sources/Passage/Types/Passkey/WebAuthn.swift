public import Foundation

// MARK: - Credential Descriptors and Parameters

/// The [PublicKeyCredentialEntity](https://www.w3.org/TR/webauthn-3/#dictionary-pkcredentialentity) dictionary describes a user account,
/// or a WebAuthn Relying Party, which a public key credential is associated with or scoped to, respectively.
public protocol PublicKeyCredentialEntity: Sendable, Codable, Equatable {
    /// The [name](https://www.w3.org/TR/webauthn-3/#dom-publickeycredentialentity-name) property is a human-palatable name for the entity.
    var name: String { get }
}

/// The [PublicKeyCredentialRpEntity](https://www.w3.org/TR/webauthn-3/#dictionary-rp-credential-params) dictionary is used to supply
/// additional Relying Party attributes when creating a new credential.
public struct PublicKeyCredentialRpEntity: PublicKeyCredentialEntity {
    public let name: String
    /// The [id](https://www.w3.org/TR/webauthn-3/#dom-publickeycredentialrpentity-id) property is a unique identifier for the Relying Party entity,
    /// which sets the [RP ID](https://www.w3.org/TR/webauthn-3/#rp-id)
    public let id: String

    public init(name: String, id: String) {
        self.name = name
        self.id = id
    }
}

public struct PublicKeyCredentialUserEntity: PublicKeyCredentialEntity {
    public let name: String
    /// The [id](https://www.w3.org/TR/webauthn-3/#dom-publickeycredentialuserentity-id) is a user handle of the user account.
    public let id: Data
    /// The [displayName](https://www.w3.org/TR/webauthn-3/#dom-publickeycredentialuserentity-displayname) is a human-palatable name
    /// for the user account, intended only for display.
    public let displayName: String

    public init(name: String, id: Data, displayName: String) {
        self.name = name
        self.id = id
        self.displayName = displayName
    }
}

extension PublicKeyCredentialUserEntity {

    private enum CodingKeys: String, CodingKey {
        case name, id, displayName
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(id.base64URLEncodedString(), forKey: .id)
        try container.encode(displayName, forKey: .displayName)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let idString = try container.decode(String.self, forKey: .id)
        guard let id = Data(base64URLEncoded: idString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "user.id is not valid base64url"
            )
        }
        let displayName = try container.decode(String.self, forKey: .displayName)
        self.init(name: name, id: id, displayName: displayName)
    }
}

// MARK: - Enums

/// The [COSEAlgorithmIdentifier](https://www.w3.org/TR/webauthn-3/#typedefdef-cosealgorithmidentifier)’s value is a number identifying
/// a cryptographic algorithm
public enum COSEAlgorithmIdentifier: Int, Sendable, Codable {
    case ES256  = -7
    case ESP256 = -9
    case ES384  = -35
    case ESP384 = -51
    case ES512  = -36
    case ESP512 = -52
    case EdDSA  = -8
    case RS256  = -257
    case RS384  = -258
    case RS512  = -259
    case RS1    = -65535
    case PS256  = -37
    case PS384  = -38
    case PS512  = -39
}

/// The [AuthenticatorTransport](https://www.w3.org/TR/webauthn-3/#enum-transport) enumeration defines hints as to how clients
/// might communicate with a particular authenticator in order to obtain an assertion for a specific credential.
public enum AuthenticatorTransport: RawRepresentable, Codable, Sendable, Equatable {
    case usb
    case nfc
    case ble
    case smartcard
    case `internal`
    case hybrid
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "usb"        : self = .usb
        case "nfc"        : self = .nfc
        case "ble"        : self = .ble
        case "smart-card" : self = .smartcard
        case "internal"   : self = .internal
        case "hybrid"     : self = .hybrid
        default           : self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .usb               : return "usb"
        case .nfc               : return "nfc"
        case .ble               : return "ble"
        case .smartcard         : return "smart-card"
        case .internal          : return "internal"
        case .hybrid            : return "hybrid"
        case .unknown(let value): return value
        }
    }
}

/// The [UserVerificationRequirement](https://www.w3.org/TR/webauthn-3/#enum-userverificationrequirement) enumeration defines the Relying Party’s requirements regarding user verification during credential creation or assertion generation.
public enum UserVerificationRequirement: RawRepresentable, Sendable, Codable, Equatable {
    case required
    case preferred
    case discouraged
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "required"    : self = .required
        case "preferred"   : self = .preferred
        case "discouraged" : self = .discouraged
        default            : self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .required          : return "required"
        case .preferred         : return "preferred"
        case .discouraged       : return "discouraged"
        case .unknown(let value): return value
        }
    }
}

/// The [AttestationConveyancePreference](https://www.w3.org/TR/webauthn-3/#enum-attestation-conveyance-preference) enumeration defines
/// the Relying Party’s preference regarding attestation conveyance during credential creation.
public enum AttestationConveyancePreference: RawRepresentable, Codable, Sendable, Equatable {
    case none
    case direct
    case indirect
    case enterprise
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "none"            : self = .none
        case "direct"          : self = .direct
        case "indirect"        : self = .indirect
        case "enterprise"      : self = .enterprise
        default                : self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .none              : return "none"
        case .direct            : return "direct"
        case .indirect          : return "indirect"
        case .enterprise        : return "enterprise"
        case .unknown(let value): return value
        }
    }
}

// MARK: - Authentication input (service ← core hint)

/// Descriptor of a previously-registered passkey, used to hint the browser's
/// credential picker during an authentication ceremony. In the discoverable
/// flow this list is `nil` (the authenticator decides); for a username-first
/// flow it is populated from ``StoredPasskeyCredential`` records for the
/// resolved user.
public struct PasskeyCredentialDescriptor: Sendable {
    public let credentialID: String
    public let transports: [AuthenticatorTransport]

    public init(credentialID: String, transports: [AuthenticatorTransport]) {
        self.credentialID = credentialID
        self.transports = transports
    }
}

