public import Vapor

/// Optional JSON body for `POST /auth/passkey/register/begin`. The authenticated
/// user is resolved from the session/bearer, so the body only carries
/// presentation hints — today just an optional display name. Clients may POST
/// no body at all.
public struct PasskeyRegisterRequest: Content {
    public let displayName: String?

    public init(displayName: String? = nil) {
        self.displayName = displayName
    }
}
