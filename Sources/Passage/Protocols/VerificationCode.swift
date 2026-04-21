public import Foundation

/// Base protocol for verification codes with common properties
public protocol VerificationCode: Sendable {
    associatedtype AssociatedUser: User

    var user: AssociatedUser { get }
    var codeHash: String { get }
    var expiresAt: Date { get }
    var failedAttempts: Int { get }
}

/// Represents a stored email verification code
public protocol EmailVerificationCode: VerificationCode {
    var email: String { get }
}

/// Represents a stored phone verification code
public protocol PhoneVerificationCode: VerificationCode {
    var phone: String { get }
}

// MARK: Helpers

extension VerificationCode {

    /// Indicates whether the verification code has expired
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// Indicates whether the verification code is valid (not expired and within allowed attempts)
    func isValid(maxAttempts: Int) -> Bool {
        !isExpired && failedAttempts < maxAttempts
    }

}
