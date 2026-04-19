public struct Credential: Sendable {

    public enum Kind: String, Sendable {
        case password
        case passkey
    }

    public let kind: Kind
    public let secret: String
}

extension Credential {
    public static func password(_ passwordHash: String) -> Credential {
        return Credential(kind: .password, secret: passwordHash)
    }

    public static func passkey(_ passkey: String) -> Credential {
        return Credential(kind: .passkey, secret: passkey)
    }
}
