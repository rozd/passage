import Foundation
import Queues
import Vapor

// MARK: - Passwordless Namespace

public extension Passage {

    /// Core service for orchestrating passwordless authentication flows.
    /// Supports both synchronous delivery and async via Vapor Queues.
    struct Passwordless: Sendable {
        let request: Request
        let config: Passage.Configuration.Passwordless
    }

}

// MARK: - Service Accessors

extension Passage.Passwordless {

    var store: any Passage.Store {
        request.store
    }

    var random: any Passage.RandomGenerator {
        request.random
    }

    var emailDelivery: (any Passage.EmailDelivery)? {
        request.emailDelivery
    }

    var configuration: Passage.Configuration {
        request.configuration
    }

}

// MARK: - Request Extension

extension Request {

    var passwordless: Passage.Passwordless {
        Passage.Passwordless(
            request: self,
            config: configuration.passwordless
        )
    }

}

// MARK: - Session Key for Same-Browser Verification

private let magicLinkSessionTokenKey = "passage_magic_link_session_token"

// MARK: - Email Magic Link Request

extension Passage.Passwordless {

    /// Request an email magic link for passwordless authentication
    /// - Parameter email: The email address to send the magic link to
    func requestEmailMagicLink(email: String) async throws {
        guard emailDelivery != nil else {
            throw PassageError.emailDeliveryNotConfigured
        }

        guard let config = self.config.emailMagicLink else {
            throw PassageError.emailMagicLinkNotConfigured
        }

        // Find existing user (may be nil for new users)
        let identifier = Identifier.email(email)
        let user = try await store.users.find(byIdentifier: identifier)

        // If user doesn't exist and auto-create is disabled, throw error
        guard user != nil || config.autoCreateUser else {
            throw AuthenticationError.magicLinkEmailNotFound
        }

        // Invalidate existing magic links for this identifier
        try await store.magicLinkTokens.invalidateEmailMagicLinks(for: identifier)

        // Generate opaque token and hash it
        let token = random.generateOpaqueToken()
        let tokenHash = random.hashOpaqueToken(token: token)

        // Handle same-browser verification if enabled
        var sessionTokenHash: String? = nil
        if config.requireSameBrowser {
            let sessionToken = random.generateOpaqueToken()
            sessionTokenHash = random.hashOpaqueToken(token: sessionToken)
            // Store raw session token in Vapor Session
            request.session.data[magicLinkSessionTokenKey] = sessionToken
        }

        // Create magic link in store
        try await store.magicLinkTokens.createEmailMagicLink(
            for: user,
            identifier: identifier,
            tokenHash: tokenHash,
            sessionTokenHash: sessionTokenHash,
            expiresAt: .now.addingTimeInterval(config.linkExpiration)
        )

        // Dispatch email delivery
        try await dispatchEmailMagicLinkDelivery(
            email: email,
            token: token,
            userId: user?.id?.description
        )
    }

    /// Resend an email magic link
    /// - Parameter email: The email address to resend the magic link to
    func resendEmailMagicLink(email: String) async throws {
        // Delegate to requestEmailMagicLink which handles invalidation and recreation
        try await requestEmailMagicLink(email: email)
    }

}

// MARK: - Email Magic Link Verification

extension Passage.Passwordless {

    /// Verify an email magic link and authenticate the user
    /// - Parameter token: The magic link token from the URL
    /// - Returns: AuthUser containing access and refresh tokens
    func verifyEmailMagicLink(token: String) async throws -> AuthUser {
        guard let config = self.config.emailMagicLink else {
            throw PassageError.emailMagicLinkNotConfigured
        }

        // Hash the token and find the magic link
        let tokenHash = random.hashOpaqueToken(token: token)

        guard let magicLink = try await store.magicLinkTokens.findEmailMagicLink(tokenHash: tokenHash) else {
            throw AuthenticationError.magicLinkInvalid
        }

        // Check expiration
        if magicLink.isExpired {
            throw AuthenticationError.magicLinkExpired
        }

        // Check max attempts
        if !magicLink.isValid(maxAttempts: config.maxAttempts) {
            throw AuthenticationError.magicLinkMaxAttempts
        }

        // Same-browser verification if enabled
        if config.requireSameBrowser {
            try verifySameBrowser(magicLink: magicLink)
        }

        // Find or create user
        let user: any User
        if let existingUser = magicLink.user {
            user = existingUser
        } else if config.autoCreateUser {
            user = try await createUserWithEmailIdentifier(magicLink.identifier)
        } else {
            throw AuthenticationError.magicLinkEmailNotFound
        }

        // Mark email as verified if not already
        if !user.isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }

        // Invalidate the used magic link
        try await store.magicLinkTokens.invalidateEmailMagicLinks(for: magicLink.identifier)

        // Clear session token if same-browser verification was enabled
        if config.requireSameBrowser {
            request.session.data[magicLinkSessionTokenKey] = nil
        }

        request.passage.login(user)

        return try await request.tokens.issue(for: user, revokeExisting: self.config.revokeExistingTokens)
    }

    /// Verify that the magic link is being verified from the same browser
    private func verifySameBrowser(magicLink: any MagicLinkToken) throws {
        guard let storedSessionTokenHash = magicLink.sessionTokenHash else {
            // Session token hash not stored, skip verification
            return
        }

        guard let sessionToken = request.session.data[magicLinkSessionTokenKey] else {
            throw AuthenticationError.magicLinkDifferentBrowser
        }

        let currentSessionTokenHash = random.hashOpaqueToken(token: sessionToken)

        if currentSessionTokenHash != storedSessionTokenHash {
            throw AuthenticationError.magicLinkDifferentBrowser
        }
    }

}

// MARK: - User Creation Helpers

extension Passage.Passwordless {

    private func createUserWithEmailIdentifier(
        _ identifier: Identifier
    ) async throws -> any User {
        guard identifier.kind == .email else {
            throw AuthenticationError.magicLinkEmailNotFound
        }
        return try await store.users.createWithEmail(
            identifier.value,
            verified: true
        )
    }

}

// MARK: - Dispatch Methods

extension Passage.Passwordless {

    private func dispatchEmailMagicLinkDelivery(
        email: String,
        token: String,
        userId: String?
    ) async throws {
        guard let config = self.config.emailMagicLink,
              let magicLinkURL = configuration.emailMagicLinkURL(token: token) else {
            throw PassageError.emailMagicLinkNotConfigured
        }

        let payload = EmailMagicLinkPayload(
            email: email,
            userId: userId,
            magicLinkURL: magicLinkURL
        )

        if config.useQueues {
            try await request.queue.dispatch(
                SendEmailMagicLinkJob.self,
                payload,
                maxRetryCount: 3
            )
        } else {
            // Synchronous fallback
            guard let delivery = emailDelivery else { return }
            let user: (any User)? = if let userId = userId {
                try await store.users.find(byId: userId)
            } else {
                nil
            }
            try await delivery.sendMagicLinkEmail(
                to: email,
                user: user,
                magicLinkURL: magicLinkURL
            )
        }
    }

}
