public import Foundation

/// Base protocol for password reset codes with common properties
public protocol RestorationCode: Sendable {
    associatedtype AssociatedUser: User

    var user: AssociatedUser { get }
    var codeHash: String { get }
    var expiresAt: Date { get }
    var failedAttempts: Int { get }
}

/// Represents a stored email password reset code
public protocol EmailPasswordResetCode: RestorationCode {
    var email: String { get }
}

/// Represents a stored phone password reset code
public protocol PhonePasswordResetCode: RestorationCode {
    var phone: String { get }
}

// MARK: Helpers

public extension RestorationCode {

    /// Indicates whether the restoration code has expired
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// Indicates whether the restoration code is valid (not expired and within max attempts)
    func isValid(maxAttempts: Int) -> Bool {
        !isExpired && failedAttempts < maxAttempts
    }

}
