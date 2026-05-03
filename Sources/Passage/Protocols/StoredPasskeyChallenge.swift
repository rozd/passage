public import Foundation

/// A single-use WebAuthn challenge as persisted by the Relying Party.
/// Modelled on ``ExchangeToken`` — hashed value, TTL, one-shot consumption.
///
/// Challenges are issued in `beginRegistration` / `beginAuthentication` and
/// persisted so that the corresponding `finishRegistration` /
/// `finishAuthentication` can prove freshness in a stateless, multi-node-safe
/// way (no session stickiness required).
public protocol StoredPasskeyChallenge: Sendable {
    associatedtype Id: CustomStringConvertible, Codable, Hashable, Sendable
    associatedtype AssociatedUser: User

    var id: Id? { get }
    var identifier: Identifier? { get }
    var user: AssociatedUser? { get }
    var kind: PasskeyChallengeKind { get }
    /// SHA-256 hex of the raw challenge bytes. Plain-text never stored.
    var challengeHash: String { get }
    var expiresAt: Date { get }
    /// Timestamp when the challenge was consumed (prevents reuse).
    var consumedAt: Date? { get }
    var createdAt: Date? { get }
}

// MARK: - Validation Helpers

public extension StoredPasskeyChallenge {
    /// Indicates whether the challenge has expired.
    var isExpired: Bool {
        expiresAt < .now
    }

    /// Indicates whether the challenge has been consumed.
    var isConsumed: Bool {
        consumedAt != nil
    }

    /// Indicates whether the challenge is valid (not expired and not consumed).
    var isValid: Bool {
        !isExpired && !isConsumed
    }
}
