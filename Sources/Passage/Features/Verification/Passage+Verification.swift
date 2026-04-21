import Foundation
import Queues

// MARK: - Verification Namespace

public extension Passage {

    /// Core service for orchestrating verification flows.
    /// Supports both synchronous delivery and async via Vapor Queues.
    struct Verification: Sendable {
        let request: Request
        let config: Passage.Configuration.Verification
    }

}

// MARK: - Service Accessors

extension Passage.Verification {

    var store: any Passage.Store {
        request.store
    }

    var random: any Passage.RandomGenerator {
        request.random
    }

    var emailDelivery: (any Passage.EmailDelivery)? {
        request.emailDelivery
    }

    var phoneDelivery: (any Passage.PhoneDelivery)? {
        request.phoneDelivery
    }

}

extension Request {

    var verification: Passage.Verification {
        Passage.Verification(
            request: self,
            config: configuration.verification
        )
    }
}

// MARK: - Verification Implementation

import Vapor

extension Passage.Verification {

    /// Send email verification code to a user.
    /// Code is generated and stored synchronously.
    /// Delivery is dispatched to queue if available, otherwise sent synchronously.
    @discardableResult
    func sendEmailCode(to user: any User) async throws -> String {
        guard emailDelivery != nil else {
            throw PassageError.emailDeliveryNotConfigured
        }

        guard let email = user.email else {
            throw AuthenticationError.emailNotSet
        }

        // Invalidate existing codes
        try await store.verificationCodes.invalidateEmailCodes(forEmail: email)

        // Generate and store code (synchronous - needed before response)
        let code = random.generateVerificationCode(length: config.email.codeLength)
        let hash = random.hashOpaqueToken(token: code)

        try await store.verificationCodes.createEmailCode(
            for: user,
            email: email,
            codeHash: hash,
            expiresAt: Date().addingTimeInterval(config.email.codeExpiration)
        )

        // Dispatch delivery (queue or sync)
        try await dispatchEmailDelivery(
            email: email,
            code: code,
            userId: try user.requiredIdAsString
        )

        return code
    }

    /// Send email verification code to an email address and return the code.
    /// Used for account linking verification where we need the plain text code.
    /// - Parameter email: The email address to send the code to
    /// - Returns: The plain text verification code sent
    func sendEmailCode(toEmail email: String) async throws -> String {
        guard emailDelivery != nil else {
            throw PassageError.emailDeliveryNotConfigured
        }

        // Find user by email
        guard let user = try await store.users.find(byIdentifier: .email(email)) else {
            throw AuthenticationError.emailNotSet
        }

        return try await sendEmailCode(to: user)
    }

    /// Send phone verification code to a user.
    @discardableResult
    func sendPhoneCode(to user: any User) async throws -> String {
        guard phoneDelivery != nil else {
            throw PassageError.phoneDeliveryNotConfigured
        }

        guard let phone = user.phone else {
            throw AuthenticationError.phoneNotSet
        }

        // Invalidate existing codes
        try await store.verificationCodes.invalidatePhoneCodes(forPhone: phone)

        // Generate and store code
        let code = random.generateVerificationCode(length: config.phone.codeLength)
        let hash = random.hashOpaqueToken(token: code)

        try await store.verificationCodes.createPhoneCode(
            for: user,
            phone: phone,
            codeHash: hash,
            expiresAt: Date().addingTimeInterval(config.phone.codeExpiration)
        )

        // Dispatch delivery (queue or sync)
        try await dispatchPhoneDelivery(
            phone: phone,
            code: code,
            userId: try user.requiredIdAsString
        )

        return code
    }

    func sendPhoneCode(toPhone phone: String) async throws -> String {
        guard phoneDelivery != nil else {
            throw PassageError.phoneDeliveryNotConfigured
        }

        // Find user by phone
        guard let user = try await store.users.find(byIdentifier: .phone(phone)) else {
            throw AuthenticationError.phoneNotSet
        }

        return try await sendPhoneCode(to: user)
    }

    /// Send verification code based on identifier kind.
    func sendVerificationCode(for user: any User, identifierKind: Identifier.Kind) async throws {
        switch identifierKind {
        case .email:
            try await sendEmailCode(to: user)
        case .phone:
            try await sendPhoneCode(to: user)
        case .username:
            break // Username doesn't require verification
        case .federated:
            break // Federated accounts don't require verification
        }
    }

    // MARK: - Private Dispatch Methods

    private func dispatchEmailDelivery(email: String, code: String, userId: String) async throws {

        let verificationURL = request.configuration.emailVerificationURL
            .appending(
                queryItems: [
                    .init(name: "code", value: code),
                    .init(name: "email", value: email),
                ]
            )

        let payload = SendEmailCodePayload(
            email: email,
            userId: userId,
            verificationURL: verificationURL,
            verificationCode: code
        )

        if config.useQueues {
            try await request.queue.dispatch(
                SendEmailCodeJob.self,
                payload,
                maxRetryCount: 3
            )
        } else {
            // Synchronous fallback
            guard let delivery = emailDelivery else { return }
            guard let user = try await store.users.find(byId: userId) else { return }
            try await delivery.sendEmailVerification(
                to: email,
                user: user,
                verificationURL: verificationURL,
                verificationCode: code
            )
        }
    }

    private func dispatchPhoneDelivery(phone: String, code: String, userId: String) async throws {
        let payload = SendPhoneCodePayload(phone: phone, code: code, userId: userId)

        if config.useQueues {
            try await request.queue.dispatch(
                SendPhoneCodeJob.self,
                payload,
                maxRetryCount: 3
            )
        } else {
            guard let delivery = phoneDelivery else { return }
            guard let user = try await store.users.find(byId: userId) else { return }
            try await delivery.sendPhoneVerification(to: phone, code: code, user: user)
        }
    }
}
