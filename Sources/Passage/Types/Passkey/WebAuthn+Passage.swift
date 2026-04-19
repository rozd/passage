import Vapor
import CryptoKit

// MARK: PublicKeyCredentialUserEntity

extension PublicKeyCredentialUserEntity {
    /// Derive a WebAuthn user entity for a known user. The user handle is a
    /// namespaced SHA-256 of `user.id` — stable across every registration for
    /// the same account so platform authenticators can dedupe credentials by
    /// user handle, and opaque enough not to leak the underlying ID shape.
    init(
        for user: any User,
        displayName: String,
    ) {
        let name = user.username ?? user.email ?? user.phone ?? displayName
        self.init(
            name: name,
            id: Self.userHandle(forUserId: String(describing: user.id)),
            displayName: displayName,
        )
    }

    /// Derive a WebAuthn user entity for a not-yet-created signup user. The
    /// handle is derived from the identifier so repeated begin-signup calls
    /// for the same identifier produce the same handle (authenticator dedup).
    /// Once the user is persisted and future registrations go through the
    /// authenticated path, those will use the `user.id`-derived handle — a
    /// known consequence of not persisting the handle on the user record.
    init(
        for identifier: Identifier,
        displayName: String,
    ) {
        self.init(
            name: identifier.passkeyUserEntityName,
            id: Self.userHandle(forIdentifier: identifier),
            displayName: displayName,
        )
    }

    private static func userHandle(forUserId id: String) -> Data {
        let source = "passage:user:" + id
        return Data(SHA256.hash(data: Data(source.utf8)))
    }

    private static func userHandle(forIdentifier identifier: Identifier) -> Data {
        let kind = identifier.kind.rawValue
        let provider = identifier.provider?.description ?? ""
        let source = "passage:identifier:\(kind):\(provider):\(identifier.value)"
        return Data(SHA256.hash(data: Data(source.utf8)))
    }
}

private extension Identifier {
    var passkeyUserEntityName: String {
        switch kind {
        case .email:
            return value
        case .phone:
            return value
        case .username:
            return value
        case .federated:
            if let provider = provider {
                return "\(provider):\(value)"
            } else {
                return value
            }
        }
    }
}
