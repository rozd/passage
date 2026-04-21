public import Foundation

/// Temporary, single-use token for OAuth code exchange flow.
/// Exchange tokens allow OAuth flows to return a short-lived code in redirect URLs
/// that clients can exchange for JWT tokens via API.
public protocol ExchangeToken: Sendable {
    associatedtype Id: CustomStringConvertible, Codable, Hashable, Sendable
    associatedtype AssociatedUser: User

    var id: Id? { get }

    var user: AssociatedUser { get }

    /// Hashed version of the exchange code (plain-text never stored)
    var tokenHash: String { get }

    var expiresAt: Date { get }

    /// Timestamp when the code was consumed (prevents reuse)
    var consumedAt: Date? { get }

    var createdAt: Date? { get }
}

// MARK: - Validation Helpers

public extension ExchangeToken {

    /// Indicates whether the exchange token has expired
    var isExpired: Bool {
        expiresAt < .now
    }

    /// Indicates whether the exchange token has been consumed
    var isConsumed: Bool {
        consumedAt != nil
    }

    /// Indicates whether the exchange token is valid (not expired and not consumed)
    var isValid: Bool {
        !isExpired && !isConsumed
    }
}
