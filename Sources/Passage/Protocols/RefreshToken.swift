public import Foundation

///
public protocol RefreshToken: Sendable {
    associatedtype Id: CustomStringConvertible, Codable, Hashable, Sendable
    associatedtype AssociatedUser: User

    var id: Id? { get }

    var user: AssociatedUser { get }

    var tokenHash: String { get }

    var expiresAt: Date { get }

    var revokedAt: Date? { get }

    var replacedBy: Id? { get }
}

// MARK:

public extension RefreshToken {

    /// Indicates whether the refresh token has expired
    var isExpired: Bool {
        expiresAt < .now
    }

    /// Indicates whether the refresh token has been revoked
    var isRevoked: Bool {
        revokedAt != nil
    }

    /// Indicates whether the refresh token is valid (not expired and not revoked)
    var isValid: Bool {
        !isExpired && !isRevoked
    }

}
