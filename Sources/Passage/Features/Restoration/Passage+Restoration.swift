import Foundation
import Vapor

// MARK: - Restoration Namespace

public extension Passage {

    /// Core service for orchestrating password reset flows.
    /// Supports both synchronous delivery and async via Vapor Queues.
    struct Restoration: Sendable {
        let request: Request
        let config: Passage.Configuration.Restoration
    }

}

// MARK: - Service Accessors

extension Passage.Restoration {

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

    var restoration: Passage.Restoration {
        Passage.Restoration(
            request: self,
            config: configuration.restoration
        )
    }
}

// MARK: - Restoration Implementation

extension Passage.Restoration {

    /// Request password reset - send code based on identifier type
    func requestReset(for identifier: Identifier) async throws {
        // Find user by identifier
        guard let user = try await store.users.find(byIdentifier: identifier) else {
            throw AuthenticationError.restorationIdentifierNotFound
        }

        // Route to appropriate delivery based on identifier kind
        switch identifier.kind {
        case .email:
            try await sendPasswordResetCode(to: user, byEmail: identifier.value)
        case .phone:
            try await sendPasswordResetCode(to: user, byPhone: identifier.value)
        case .username:
            // Username requires fallback to preferred delivery channel
            try await sendResetCodeViaPreferredChannel(to: user)
        case .federated:
            try await sendResetCodeViaPreferredChannel(to: user)
        }
    }

    func verifyReset(form: any PasswordResetVerifyForm) async throws {
        let policy = request.configuration.passwordPolicy

        let newPassword = form.newPassword
        try policy.validate(password: newPassword)

        let newPasswordHash = try await request.password.async.hash(newPassword)

        let codeHash = random.hashOpaqueToken(token: form.code)

        switch form.identifier.kind {
        case .email:
            try await verifyPasswordResetCode(
                sentToEmail: form.identifier.value,
                codeHash: codeHash,
                newPasswordHash: newPasswordHash
            )
        case .phone:
            try await verifyPasswordResetCode(
                sentToPhone: form.identifier.value,
                codeHash: codeHash,
                newPasswordHash: newPasswordHash
            )
        default:
            throw AuthenticationError.restorationDeliveryNotAvailable
        }
    }

    /// Resend email reset code
    func resendPasswordResetCode(toEmail email: String) async throws {
        guard let user = try await store.users.find(byIdentifier: .email(email)) else {
            throw AuthenticationError.restorationIdentifierNotFound
        }
        try await sendPasswordResetCode(to: user, byEmail: email)
    }

    /// Resend phone reset code
    func resendPasswordResetCode(toPhone phone: String) async throws {
        guard let user = try await store.users.find(byIdentifier: .phone(phone)) else {
            throw AuthenticationError.restorationIdentifierNotFound
        }
        try await sendPasswordResetCode(to: user, byPhone: phone)
    }

    // MARK: - Private Methods

    private func sendPasswordResetCode(to user: any User, byEmail email: String) async throws {
        guard emailDelivery != nil else {
            throw PassageError.emailDeliveryNotConfigured
        }

        // Invalidate existing codes
        try await store.restorationCodes.invalidatePasswordResetCodes(forEmail: email)

        // Generate and store code
        let code = random.generateVerificationCode(length: config.email.codeLength)
        let hash = random.hashOpaqueToken(token: code)

        try await store.restorationCodes.createPasswordResetCode(
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
    }

    private func sendPasswordResetCode(to user: any User, byPhone phone: String) async throws {
        guard phoneDelivery != nil else {
            throw PassageError.phoneDeliveryNotConfigured
        }

        // Invalidate existing codes
        try await store.restorationCodes.invalidatePasswordResetCodes(forPhone: phone)

        // Generate and store code
        let code = random.generateVerificationCode(length: config.phone.codeLength)
        let hash = random.hashOpaqueToken(token: code)

        try await store.restorationCodes.createPasswordResetCode(
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
    }

    private func sendResetCodeViaPreferredChannel(to user: any User) async throws {
        switch config.preferredDelivery {
        case .email:
            guard let email = user.email else {
                throw AuthenticationError.emailNotSet
            }
            try await sendPasswordResetCode(to: user, byEmail: email)
        case .phone:
            guard let phone = user.phone else {
                throw AuthenticationError.phoneNotSet
            }
            try await sendPasswordResetCode(to: user, byPhone: phone)
        }
    }

    private func verifyPasswordResetCode(
        sentToEmail email: String,
        codeHash: String,
        newPasswordHash: String
    ) async throws {
        // Find the reset code
        guard let resetCode = try await store.restorationCodes.findPasswordResetCode(
            forEmail: email,
            codeHash: codeHash
        ) else {
            throw AuthenticationError.restorationCodeInvalid
        }

        // Check expiration
        if resetCode.isExpired {
            throw AuthenticationError.restorationCodeExpired
        }

        // Check max attempts
        if !resetCode.isValid(maxAttempts: config.email.maxAttempts) {
            throw AuthenticationError.restorationCodeMaxAttempts
        }

        // Update password
        try await store.users.setPassword(for: resetCode.user, passwordHash: newPasswordHash)

        // Invalidate all reset codes for this email
        try await store.restorationCodes.invalidatePasswordResetCodes(forEmail: email)

        // Revoke all refresh tokens (force re-login)
        try await request.tokens.revoke(for: resetCode.user)
    }

    private func verifyPasswordResetCode(
        sentToPhone phone: String,
        codeHash: String,
        newPasswordHash: String
    ) async throws {
        // Find the reset code
        guard let resetCode = try await store.restorationCodes.findPasswordResetCode(
            forPhone: phone,
            codeHash: codeHash
        ) else {
            throw AuthenticationError.restorationCodeInvalid
        }

        // Check expiration
        if resetCode.isExpired {
            throw AuthenticationError.restorationCodeExpired
        }

        // Check max attempts
        if !resetCode.isValid(maxAttempts: config.phone.maxAttempts) {
            throw AuthenticationError.restorationCodeMaxAttempts
        }

        // Update password
        try await store.users.setPassword(for: resetCode.user, passwordHash: newPasswordHash)

        // Invalidate all reset codes for this phone
        try await store.restorationCodes.invalidatePasswordResetCodes(forPhone: phone)

        // Revoke all refresh tokens (force re-login)
        try await request.tokens.revoke(for: resetCode.user)
    }

    // MARK: - Dispatch Methods

    private func dispatchEmailDelivery(email: String, code: String, userId: String) async throws {
        let resetURL = request.configuration.emailPasswordResetLinkURL(code: code, email: email)

        let payload = EmailPasswordResetCodePayload(
            email: email,
            userId: userId,
            resetURL: resetURL,
            resetCode: code
        )

        if config.useQueues {
            try await request.queue.dispatch(
                SendEmailPasswordResetCodeJob.self,
                payload,
                maxRetryCount: 3
            )
        } else {
            // Synchronous fallback
            guard let delivery = emailDelivery else { return }
            guard let user = try await store.users.find(byId: userId) else { return }
            try await delivery.sendPasswordResetEmail(
                to: email,
                user: user,
                passwordResetURL: resetURL,
                passwordResetCode: code,
            )
        }
    }

    private func dispatchPhoneDelivery(phone: String, code: String, userId: String) async throws {
        let payload = PhonePasswordResetCodePayload(phone: phone, code: code, userId: userId)

        if config.useQueues {
            try await request.queue.dispatch(
                SendPhonePasswordResetCodeJob.self,
                payload,
                maxRetryCount: 3
            )
        } else {
            guard let delivery = phoneDelivery else { return }
            guard let user = try await store.users.find(byId: userId) else { return }
            try await delivery.sendPasswordResetSMS(to: phone, code: code, user: user)
        }
    }
}
