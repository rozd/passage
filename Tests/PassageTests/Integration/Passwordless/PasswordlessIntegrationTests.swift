import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting
import XCTQueues

@Suite(.tags(.integration, .passwordless))
struct `Passwordless Authentication Integration Tests` {

    // MARK: - Helpers

    /// Helper class to capture sent emails and SMS
    final class CapturedMessages: @unchecked Sendable {
        var emails: [Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail] = []
        var sms: [Passage.OnlyForTest.MockPhoneDelivery.EphemeralSMS] = []
    }

    // MARK: - Configuration Helpers

    /// Configures a test Vapor application with Passage and passwordless support
    @Sendable private func configure(_ app: Application) async throws {
        try await configureWithCapture(app, captured: nil, linkExpiration: 600, autoCreateUser: true)
    }

    /// Configures a test Vapor application with Passage and optional message capture
    @Sendable private func configureWithCapture(
        _ app: Application,
        captured: CapturedMessages? = nil,
        linkExpiration: TimeInterval = 600,
        autoCreateUser: Bool = true,
        revokeExistingTokens: Bool = true,
        useQueues: Bool = true,
        requireSameBrowser: Bool = false
    ) async throws {
        // Add HMAC key directly for testing
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        app.queues.use(.asyncTest)

        // Configure Passage with test services
        let store = Passage.OnlyForTest.InMemoryStore()

        let emailCallback: (@Sendable (Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail) -> Void)? =
            captured != nil ? { @Sendable in captured!.emails.append($0) } : nil
        let phoneCallback: (@Sendable (Passage.OnlyForTest.MockPhoneDelivery.EphemeralSMS) -> Void)? =
            captured != nil ? { @Sendable in captured!.sms.append($0) } : nil

        let emailDelivery = Passage.OnlyForTest.MockEmailDelivery(callback: emailCallback)
        let phoneDelivery = Passage.OnlyForTest.MockPhoneDelivery(callback: phoneCallback)

        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
            phoneDelivery: phoneDelivery,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks)),
            passwordless: .init(
                revokeExistingTokens: revokeExistingTokens,
                emailMagicLink: .email(
                    useQueues: useQueues,
                    linkExpiration: linkExpiration,
                    maxAttempts: 3,
                    autoCreateUser: autoCreateUser,
                    requireSameBrowser: requireSameBrowser
                )
            ),
            verification: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: true
            ),
            restoration: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 3),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 3),
                useQueues: true
            )
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    /// Creates a test user directly in the store (for existing user tests)
    @Sendable private func createTestUser(
        app: Application,
        email: String? = nil,
        phone: String? = nil,
        password: String = "password123",
        isEmailVerified: Bool = false,
        isPhoneVerified: Bool = false
    ) async throws {
        let store = app.passage.storage.services.store
        let passwordHash = try await app.password.async.hash(password)

        let identifier: Identifier
        if let email = email {
            identifier = .email(email)
        } else if let phone = phone {
            identifier = .phone(phone)
        } else {
            fatalError("Must provide email or phone")
        }

        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        if isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }
        if isPhoneVerified {
            try await store.users.markPhoneVerified(for: user)
        }
    }

    /// Helper to extract token from magic link URL (returns percent-encoded token for URL construction)
    private func extractToken(from magicLinkURL: URL) throws -> String {
        guard let components = URLComponents(url: magicLinkURL, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            throw TestError.missingToken
        }
        // The token needs to be percent-encoded for use in URL strings
        // because it may contain characters like +, /, = which have special meaning in URLs
        // Note: + is not in urlQueryAllowed by default, but we also need to encode / and =
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+/=")
        guard let encodedToken = token.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw TestError.missingToken
        }
        return encodedToken
    }

    enum TestError: Error {
        case missingToken
    }

    // MARK: - Email Magic Link Request Tests

    @Test
    func `Request magic link via email succeeds for new user`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "newuser@example.com"

            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            #expect(captured.emails.count == 1)

            let sentEmail = try #require(captured.emails.first)
            #expect(sentEmail.to == email)
            #expect(sentEmail.type == .magicLink)
            #expect(sentEmail.magicLinkURL != nil)
        }
    }

    @Test
    func `Request magic link via email succeeds for existing user`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "existing@example.com"

            // Create existing user
            try await createTestUser(app: app, email: email, isEmailVerified: true)

            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            #expect(captured.emails.count == 1)

            let sentEmail = try #require(captured.emails.first)
            #expect(sentEmail.to == email)
            #expect(sentEmail.magicLinkURL != nil)
        }
    }

    @Test
    func `Request magic link fails when auto-create disabled and user doesn't exist`() async throws {
        try await withApp(configure: { app in
            try await configureWithCapture(app, captured: nil, autoCreateUser: false)
        }) { app in
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": "nonexistent@example.com"])
            }, afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test
    func `Request magic link fails with invalid email format`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": "invalid-email"])
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Request magic link fails with missing email`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode([:] as [String: String])
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })
        }
    }

    // MARK: - Email Magic Link Verify Tests

    @Test
    func `Verify magic link succeeds and returns tokens for new user`() async throws {
        let captured = CapturedMessages()
        let email = "newuser@example.com"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Step 1: Request magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            // Step 2: Verify magic link and get tokens
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)", afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(authUser.user.email == email)
                #expect(!authUser.accessToken.isEmpty)
                #expect(!authUser.refreshToken.isEmpty)
            })

            // Verify user was created
            let store = app.passage.storage.services.store
            let user = try await store.users.find(byIdentifier: Identifier.email(email))
            #expect(user != nil)
            #expect(user?.isEmailVerified == true)
        }
    }

    @Test
    func `Verify magic link succeeds for existing user and marks email verified`() async throws {
        let captured = CapturedMessages()
        let email = "existing@example.com"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Create existing user with unverified email
            try await createTestUser(app: app, email: email, isEmailVerified: false)

            // Request magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            // Verify magic link
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)", afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Verify email is now verified
            let store = app.passage.storage.services.store
            let user = try await store.users.find(byIdentifier: Identifier.email(email))
            #expect(user?.isEmailVerified == true)
        }
    }

    @Test
    func `Verify magic link fails with invalid token`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=invalid-token", afterResponse: { res in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Verify magic link fails when token is expired`() async throws {
        let captured = CapturedMessages()
        let email = "expired@example.com"

        try await withApp(configure: { app in
            // Use very short expiration
            try await configureWithCapture(app, captured: captured, linkExpiration: 0.001)
        }) { app in
            // Request magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            // Wait for token to expire
            try await Task.sleep(for: .milliseconds(10))

            // Verify should fail
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)", afterResponse: { res in
                #expect(res.status == .gone)
            })
        }
    }

    @Test
    func `Magic link can only be used once`() async throws {
        let captured = CapturedMessages()
        let email = "onetime@example.com"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Request magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            // First use should succeed
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)", afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Second use should fail
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)", afterResponse: { res in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Resend Tests

    @Test
    func `Resend magic link succeeds and invalidates previous link`() async throws {
        let captured = CapturedMessages()
        let email = "resend@example.com"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Request first magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let firstMagicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let firstToken = try extractToken(from: firstMagicLinkURL)

            // Resend magic link
            try await app.testing().test(.POST, "/auth/magic-link/email/resend", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            #expect(captured.emails.count == 2)

            let secondMagicLinkURL = try #require(captured.emails.last?.magicLinkURL)
            let secondToken = try extractToken(from: secondMagicLinkURL)

            // First token should be invalidated
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(firstToken)", afterResponse: { res in
                #expect(res.status == .unauthorized)
            })

            // Second token should work
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(secondToken)", afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    // MARK: - Token Revocation Tests

    @Test
    func `Magic link verification revokes existing tokens when configured`() async throws {
        let captured = CapturedMessages()
        let email = "revoke@example.com"

        try await withApp(configure: { app in
            try await configureWithCapture(app, captured: captured, revokeExistingTokens: true)
        }) { app in
            // Create user and login normally first
            try await createTestUser(app: app, email: email, password: "password123", isEmailVerified: true)

            var firstRefreshToken = ""
            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                let authUser = try res.content.decode(AuthUser.self)
                firstRefreshToken = authUser.refreshToken
            })

            // Request and verify magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)")

            // Original refresh token should be revoked
            try await app.testing().test(.POST, "/auth/refresh-token", beforeRequest: { req in
                try req.content.encode(["refreshToken": firstRefreshToken])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - User Creation Tests

    @Test
    func `Passwordless user has no password set by default`() async throws {
        let captured = CapturedMessages()
        let email = "nopassword@example.com"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Request magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            // Verify magic link
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)")

            // Verify user has no password
            let store = app.passage.storage.services.store
            let user = try await store.users.find(byIdentifier: Identifier.email(email))
            #expect(user != nil)
            #expect(user?.passwordHash == nil)

            // Attempting password login should fail with passwordIsNotSet
            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "password": "anypassword"
                ])
            }, afterResponse: { res in
                #expect(res.status == .internalServerError) // passwordIsNotSet error
            })
        }
    }

    @Test
    func `Magic link creates user with verified email`() async throws {
        let captured = CapturedMessages()
        let email = "verified@example.com"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Request and verify magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)")

            // Verify user email is marked as verified
            let store = app.passage.storage.services.store
            let user = try await store.users.find(byIdentifier: Identifier.email(email))
            #expect(user != nil)
            #expect(user?.isEmailVerified == true)
        }
    }

    // MARK: - Full Flow Tests

    @Test
    func `Full flow: request magic link -> verify -> use access token`() async throws {
        let captured = CapturedMessages()
        let email = "fullflow@example.com"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Step 1: Request magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let token = try extractToken(from: magicLinkURL)

            var accessToken = ""
            var refreshToken = ""

            // Step 2: Verify magic link
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(token)", afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                refreshToken = authUser.refreshToken
                #expect(authUser.user.email == email)
            })

            // Step 3: Use access token to access protected resource
            try await app.testing().test(.GET, "/me", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let user = try res.content.decode(AuthUser.User.self)
                #expect(user.email == email)
            })

            // Step 4: Refresh the token
            try await app.testing().test(.POST, "/auth/refresh-token", beforeRequest: { req in
                try req.content.encode(["refreshToken": refreshToken])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

}
