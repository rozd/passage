import Testing
import Foundation
import Vapor
@testable import Passage
import PassageOnlyForTest

@Suite
struct `Delivery Protocols Tests` {

    // MARK: - Mock Implementations

    struct MockUser: User {
        typealias Id = UUID
        var id: UUID?
        var email: String?
        var phone: String?
        var username: String?
        var passwordHash: String?
        var isAnonymous: Bool
        var isEmailVerified: Bool
        var isPhoneVerified: Bool

        var sessionID: String {
            guard let id = id else {
                fatalError("MockUser must have an ID for session authentication")
            }
            return id.uuidString
        }
    }

    // MARK: - EmailDelivery Protocol Tests

    struct MockEmailDelivery: Passage.EmailDelivery {
        var sentEmails: [String] = []

        func sendEmailVerification(
            to email: String,
            user: any User,
            verificationURL: URL,
            verificationCode: String
        ) async throws {
            // Method signature test
        }

        func sendEmailVerificationConfirmation(
            to email: String,
            user: any User
        ) async throws {
            // Method signature test
        }

        func sendPasswordResetEmail(
            to email: String,
            user: any User,
            passwordResetURL: URL,
            passwordResetCode: String
        ) async throws {
            // Method signature test
        }

        func sendWelcomeEmail(
            to email: String,
            user: any User
        ) async throws {
            // Method signature test
        }

        func sendMagicLinkEmail(
            to email: String,
            user: (any User)?,
            magicLinkURL: URL
        ) async throws {
            // Method signature test
        }
    }

    @Test
    func `EmailDelivery protocol can be implemented`() {
        let delivery: any Passage.EmailDelivery = MockEmailDelivery()
        #expect(delivery is MockEmailDelivery)
    }

    @Test
    func `EmailDelivery protocol conforms to Sendable`() {
        let delivery: any Sendable = MockEmailDelivery()
        #expect(delivery is MockEmailDelivery)
    }

    @Test
    func `EmailDelivery has all required methods`() async throws {
        let delivery = MockEmailDelivery()
        let user = MockUser(
            id: UUID(),
            email: "test@example.com",
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        let url = URL(string: "https://example.com/verify")!

        // Verify all methods can be called
        try await delivery.sendEmailVerification(
            to: "test@example.com",
            user: user,
            verificationURL: url,
            verificationCode: "123456"
        )

        try await delivery.sendEmailVerificationConfirmation(
            to: "test@example.com",
            user: user
        )

        try await delivery.sendPasswordResetEmail(
            to: "test@example.com",
            user: user,
            passwordResetURL: url,
            passwordResetCode: "123456"
        )

        try await delivery.sendWelcomeEmail(
            to: "test@example.com",
            user: user
        )
    }

    // MARK: - PhoneDelivery Protocol Tests

    struct MockPhoneDelivery: Passage.PhoneDelivery {
        var sentMessages: [String] = []

        func sendPhoneVerification(
            to phone: String,
            code: String,
            user: any User
        ) async throws {
            // Method signature test
        }

        func sendVerificationConfirmation(
            to phone: String,
            user: any User
        ) async throws {
            // Method signature test
        }

        func sendPasswordResetSMS(
            to phone: String,
            code: String,
            user: any User
        ) async throws {
            // Method signature test
        }
    }

    @Test
    func `PhoneDelivery protocol can be implemented`() {
        let delivery: any Passage.PhoneDelivery = MockPhoneDelivery()
        #expect(delivery is MockPhoneDelivery)
    }

    @Test
    func `PhoneDelivery protocol conforms to Sendable`() {
        let delivery: any Sendable = MockPhoneDelivery()
        #expect(delivery is MockPhoneDelivery)
    }

    @Test
    func `PhoneDelivery has all required methods`() async throws {
        let delivery = MockPhoneDelivery()
        let user = MockUser(
            id: UUID(),
            email: nil,
            phone: "+1234567890",
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        // Verify all methods can be called
        try await delivery.sendPhoneVerification(
            to: "+1234567890",
            code: "123456",
            user: user
        )

        try await delivery.sendVerificationConfirmation(
            to: "+1234567890",
            user: user
        )

        try await delivery.sendPasswordResetSMS(
            to: "+1234567890",
            code: "123456",
            user: user
        )
    }

    // MARK: - FederatedLoginService Protocol Tests

    @Test
    func `FederatedLoginService protocol can be implemented`() {
        let service: any Passage.FederatedLoginService = Passage.OnlyForTest.MockFederatedLoginService()
        #expect(service is Passage.OnlyForTest.MockFederatedLoginService)
    }

    @Test
    func `FederatedLoginService protocol conforms to Sendable`() {
        let service: any Sendable = Passage.OnlyForTest.MockFederatedLoginService()
        #expect(service is Passage.OnlyForTest.MockFederatedLoginService)
    }

    // MARK: - Protocol Integration Tests

    @Test
    func `Multiple delivery protocols can coexist`() {
        let emailDelivery: any Passage.EmailDelivery = MockEmailDelivery()
        let phoneDelivery: any Passage.PhoneDelivery = MockPhoneDelivery()

        #expect(emailDelivery is MockEmailDelivery)
        #expect(phoneDelivery is MockPhoneDelivery)
    }

    @Test
    func `Delivery protocols are independent`() {
        let emailDelivery = MockEmailDelivery()
        let phoneDelivery = MockPhoneDelivery()

        // Both can be used independently
        #expect(emailDelivery is MockEmailDelivery)
        #expect(phoneDelivery is MockPhoneDelivery)
        #expect(!(emailDelivery is MockPhoneDelivery))
        #expect(!(phoneDelivery is MockEmailDelivery))
    }

    // MARK: - Custom Implementation Tests

    actor CustomEmailDelivery: Passage.EmailDelivery {
        var emailsSent: Int = 0

        func sendEmailVerification(
            to email: String,
            user: any User,
            verificationURL: URL,
            verificationCode: String
        ) async throws {
            emailsSent += 1
        }

        func sendEmailVerificationConfirmation(
            to email: String,
            user: any User
        ) async throws {
            emailsSent += 1
        }

        func sendPasswordResetEmail(
            to email: String,
            user: any User,
            passwordResetURL: URL,
            passwordResetCode: String
        ) async throws {
            emailsSent += 1
        }

        func sendWelcomeEmail(
            to email: String,
            user: any User
        ) async throws {
            emailsSent += 1
        }

        func sendMagicLinkEmail(
            to email: String,
            user: (any User)?,
            magicLinkURL: URL
        ) async throws {
            emailsSent += 1
        }
    }

    @Test
    func `Custom actor-based EmailDelivery implementation`() async throws {
        let delivery = CustomEmailDelivery()
        let user = MockUser(
            id: UUID(),
            email: "test@example.com",
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        let url = URL(string: "https://example.com")!

        try await delivery.sendEmailVerification(
            to: "test@example.com",
            user: user,
            verificationURL: url,
            verificationCode: "123456"
        )

        let count = await delivery.emailsSent
        #expect(count == 1)
    }

    // MARK: - Error Handling Tests

    struct FailingEmailDelivery: Passage.EmailDelivery {
        struct DeliveryError: Error {}

        func sendEmailVerification(
            to email: String,
            user: any User,
            verificationURL: URL,
            verificationCode: String
        ) async throws {
            throw DeliveryError()
        }

        func sendEmailVerificationConfirmation(
            to email: String,
            user: any User
        ) async throws {
            throw DeliveryError()
        }

        func sendPasswordResetEmail(
            to email: String,
            user: any User,
            passwordResetURL: URL,
            passwordResetCode: String
        ) async throws {
            throw DeliveryError()
        }

        func sendWelcomeEmail(
            to email: String,
            user: any User
        ) async throws {
            throw DeliveryError()
        }

        func sendMagicLinkEmail(
            to email: String,
            user: (any User)?,
            magicLinkURL: URL
        ) async throws {
            throw DeliveryError()
        }
    }

    @Test
    func `EmailDelivery can throw errors`() async {
        let delivery = FailingEmailDelivery()
        let user = MockUser(
            id: UUID(),
            email: "test@example.com",
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        let url = URL(string: "https://example.com")!

        await #expect(throws: FailingEmailDelivery.DeliveryError.self) {
            try await delivery.sendEmailVerification(
                to: "test@example.com",
                user: user,
                verificationURL: url,
                verificationCode: "123456"
            )
        }
    }
}
