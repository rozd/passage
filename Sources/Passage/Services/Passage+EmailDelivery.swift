public import Foundation

// MARK: - Email Delivery

public extension Passage {

    /// Protocol for sending verification emails.
    /// Implementations handle template selection and delivery.
    protocol EmailDelivery: Sendable {
        /// Send a verification code email
        func sendEmailVerification(
            to email: String,
            user: any User,
            verificationURL: URL,
            verificationCode: String,
        ) async throws

        /// Send email verification success confirmation
        func sendEmailVerificationConfirmation(
            to email: String,
            user: any User,
        ) async throws

        /// Send password reset email
        func sendPasswordResetEmail(
            to email: String,
            user: any User,
            passwordResetURL: URL,
            passwordResetCode: String,
        ) async throws

        /// Send welcome email after registration
        func sendWelcomeEmail(
            to email: String,
            user: any User,
        ) async throws

        /// Send magic link email for passwordless authentication
        /// - Parameters:
        ///   - email: The email address to send to
        ///   - user: The user requesting the magic link (nil for new users)
        ///   - magicLinkURL: The full URL containing the magic link token
        func sendMagicLinkEmail(
            to email: String,
            user: (any User)?,
            magicLinkURL: URL,
        ) async throws

    }

}
