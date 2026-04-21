import Foundation
public import Passage

// MARK: - OnlyForTest Phone Delivery Mock

public extension Passage.OnlyForTest {

    struct MockPhoneDelivery: Sendable, Passage.PhoneDelivery {

        public struct EphemeralSMS: Sendable {
            public let to: String
            public let user: String? // user ID
            public let type: SMSType
            public let code: String?

            public enum SMSType: String, Sendable {
                case verification
                case verificationConfirmation
                case passwordReset
            }
        }

        let callback: (@Sendable (EphemeralSMS) -> Void)?

        public init(
            callback: (@Sendable (EphemeralSMS) -> Void)? = nil
        ) {
            self.callback = callback
        }

        public func sendPhoneVerification(
            to phone: String,
            code: String,
            user: any User
        ) async throws {
            let ephemeralSMS = EphemeralSMS(
                to: phone,
                user: user.id?.description,
                type: .verification,
                code: code
            )
            callback?(ephemeralSMS)
        }

        public func sendVerificationConfirmation(
            to phone: String,
            user: any User
        ) async throws {
            let ephemeralSMS = EphemeralSMS(
                to: phone,
                user: user.id?.description,
                type: .verificationConfirmation,
                code: nil
            )
            callback?(ephemeralSMS)
        }

        public func sendPasswordResetSMS(
            to phone: String,
            code: String,
            user: any User
        ) async throws {
            let ephemeralSMS = EphemeralSMS(
                to: phone,
                user: user.id?.description,
                type: .passwordReset,
                code: code
            )
            callback?(ephemeralSMS)
        }
    }

}
