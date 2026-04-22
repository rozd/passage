import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration), .primeNIOSingletons)
struct `PassageBearerAuthenticator Integration Tests` {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage and custom test routes
    @Sendable private func configure(_ app: Application) async throws {
        // Add HMAC key for JWT signing
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        // Configure Passage with test services
        let store = Passage.OnlyForTest.InMemoryStore()
        let emailDelivery = Passage.OnlyForTest.MockEmailDelivery()
        let phoneDelivery = Passage.OnlyForTest.MockPhoneDelivery()

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
            verification: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            restoration: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            )
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )

        // Register test route with PassageBearerAuthenticator middleware
        let protected = app.grouped(PassageBearerAuthenticator())
        protected.get("test-auth") { req -> String in
            // Return the authenticated user's ID if available
            if let user = req.auth.get(Passage.OnlyForTest.InMemoryUser.self) {
                return "authenticated:\(user.id ?? "no-id")"
            }
            return "not-authenticated"
        }
    }

    /// Creates a test user and returns the user ID
    @Sendable private func createTestUser(
        app: Application,
        email: String = "user@example.com",
        password: String = "password123"
    ) async throws -> String {
        let store = app.passage.storage.services.store

        let passwordHash = try await app.password.async.hash(password)
        let identifier = Identifier.email(email)
        let credential = Credential.password(passwordHash)

        let user = try await store.users.create(identifier: identifier, with: credential)
        try await store.users.markEmailVerified(for: user)

        return user.id as! String
    }

    /// Creates a valid access token for a user
    @Sendable private func createAccessToken(
        app: Application,
        userId: String,
        expiresAt: Date = Date().addingTimeInterval(3600)
    ) async throws -> String {
        let payload = AccessToken(
            userId: userId,
            expiresAt: expiresAt,
            issuer: "test-issuer",
            audience: nil,
            scope: nil
        )

        let req = Request(application: app, on: app.eventLoopGroup.any())
        return try await req.jwt.sign(payload, kid: JWKIdentifier(string: "test-key"))
    }

    // MARK: - Authentication Success Tests

    @Test
    func `Authenticator authenticates valid JWT and logs in user`() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app)
            let token = try await createAccessToken(app: app, userId: userId)

            try await app.testing().test(.GET, "test-auth", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "authenticated:\(userId)")
            })
        }
    }

    @Test
    func `Authenticated user is accessible via request.auth.get()`() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app)
            let token = try await createAccessToken(app: app, userId: userId)

            try await app.testing().test(.GET, "test-auth", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body.contains("authenticated:"))
                #expect(body.contains(userId))
            })
        }
    }

    // MARK: - Authentication Failure Tests

    @Test
    func `Authenticator does not authenticate without token`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "test-auth", afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "not-authenticated")
            })
        }
    }

    @Test
    func `Authenticator does not authenticate with invalid JWT`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "test-auth", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: "invalid-token")
            }, afterResponse: { res async in
                // JWTAuthenticator throws unauthorized for invalid tokens
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Authenticator does not authenticate with expired JWT`() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app)
            // Create a token that expired 1 hour ago
            let expiredToken = try await createAccessToken(
                app: app,
                userId: userId,
                expiresAt: Date().addingTimeInterval(-3600)
            )

            try await app.testing().test(.GET, "test-auth", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: expiredToken)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Authenticator fails when user not found in store`() async throws {
        try await withApp(configure: configure) { app in
            // Create token for non-existent user
            let token = try await createAccessToken(app: app, userId: "non-existent-user-id")

            try await app.testing().test(.GET, "test-auth", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                // Should fail because user lookup fails
                #expect(res.status == .unauthorized || res.status == .notFound)
            })
        }
    }
}
