public import Foundation

/// Base protocol for magic link codes with common properties
public protocol MagicLinkToken: Sendable {
    associatedtype AssociatedUser: User

    /// The user associated with this magic link (nil for new users)
    var user: AssociatedUser? { get }
    /// The identifier where the magic link was sent (email, phone, etc.)
    var identifier: Identifier { get }
    /// SHA256 hash of the token
    var tokenHash: String { get }
    /// SHA256 hash of the session token for same-browser verification (nil if not required)
    var sessionTokenHash: String? { get }
    /// Expiration date of the magic link
    var expiresAt: Date { get }
    /// Number of failed verification attempts
    var failedAttempts: Int { get }
}

// MARK: - Helpers

extension MagicLinkToken {

    /// Indicates whether the magic link has expired
    public var isExpired: Bool {
        Date() > expiresAt
    }

    /// Indicates whether the magic link is valid (not expired and within allowed attempts)
    public func isValid(maxAttempts: Int) -> Bool {
        !isExpired && failedAttempts < maxAttempts
    }

}
