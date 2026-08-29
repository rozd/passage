public import Foundation

public struct CredentialIssuance: Sendable {

    public enum Kind: Sendable, Equatable {
        case bearer
        case browser
    }

    public enum Origin: Sendable, Equatable {
        case login
        case magicLink
        case refresh
        case exchange
        case federatedLogin
        case passkey
        case accountLinking
    }

    public let kind: Kind
    public let origin: Origin
    public let user: any User
    public let sessionId: UUID
    public let accessToken: String?
    public let accessTokenExpiresAt: Date?
    public let refreshTokenExpiresAt: Date?
    public let revokedSessionIds: [UUID]
    public let store: any Passage.Store

    public init(
        kind: Kind,
        origin: Origin,
        user: any User,
        sessionId: UUID,
        accessToken: String? = nil,
        accessTokenExpiresAt: Date? = nil,
        refreshTokenExpiresAt: Date? = nil,
        revokedSessionIds: [UUID] = [],
        store: any Passage.Store
    ) {
        self.kind = kind
        self.origin = origin
        self.user = user
        self.sessionId = sessionId
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.revokedSessionIds = revokedSessionIds
        self.store = store
    }
}
