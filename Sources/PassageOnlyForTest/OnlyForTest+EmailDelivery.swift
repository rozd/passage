public import Foundation
public import Passage

// MARK: - OnlyForTest Email Delivery Mock

public extension Passage.OnlyForTest {

    struct MockEmailDelivery: Sendable, Passage.EmailDelivery {

        public struct EphemeralEmail: Sendable {
            public let to: String
            public let user: String? // user ID
            public let type: EmailType
            public let verificationURL: URL?
            public let verificationCode: String?
            public let passwordResetURL: URL?
            public let passwordResetCode: String?
            public let magicLinkURL: URL?

            public enum EmailType: String, Sendable {
                case verification
                case verificationConfirmation
                case passwordReset
                case welcome
                case magicLink
            }
        }

        let callback: (@Sendable (EphemeralEmail) -> Void)?

        public init(
            callback: (@Sendable (EphemeralEmail) -> Void)? = nil
        ) {
            self.callback = callback
        }

        public func sendEmailVerification(
            to email: String,
            user: any User,
            verificationURL: URL,
            verificationCode: String
        ) async throws {
            let ephemeralEmail = EphemeralEmail(
                to: email,
                user: user.id?.description,
                type: .verification,
                verificationURL: verificationURL,
                verificationCode: verificationCode,
                passwordResetURL: nil,
                passwordResetCode: nil,
                magicLinkURL: nil
            )
            callback?(ephemeralEmail)
        }

        public func sendEmailVerificationConfirmation(
            to email: String,
            user: any User
        ) async throws {
            let ephemeralEmail = EphemeralEmail(
                to: email,
                user: user.id?.description,
                type: .verificationConfirmation,
                verificationURL: nil,
                verificationCode: nil,
                passwordResetURL: nil,
                passwordResetCode: nil,
                magicLinkURL: nil
            )
            callback?(ephemeralEmail)
        }

        public func sendPasswordResetEmail(
            to email: String,
            user: any User,
            passwordResetURL: URL,
            passwordResetCode: String
        ) async throws {
            let ephemeralEmail = EphemeralEmail(
                to: email,
                user: user.id?.description,
                type: .passwordReset,
                verificationURL: nil,
                verificationCode: nil,
                passwordResetURL: passwordResetURL,
                passwordResetCode: passwordResetCode,
                magicLinkURL: nil
            )
            callback?(ephemeralEmail)
        }

        public func sendWelcomeEmail(
            to email: String,
            user: any User
        ) async throws {
            let ephemeralEmail = EphemeralEmail(
                to: email,
                user: user.id?.description,
                type: .welcome,
                verificationURL: nil,
                verificationCode: nil,
                passwordResetURL: nil,
                passwordResetCode: nil,
                magicLinkURL: nil
            )
            callback?(ephemeralEmail)
        }

        public func sendMagicLinkEmail(
            to email: String,
            user: (any User)?,
            magicLinkURL: URL
        ) async throws {
            let ephemeralEmail = EphemeralEmail(
                to: email,
                user: user?.id?.description,
                type: .magicLink,
                verificationURL: nil,
                verificationCode: nil,
                passwordResetURL: nil,
                passwordResetCode: nil,
                magicLinkURL: magicLinkURL
            )
            callback?(ephemeralEmail)
        }
    }

}
