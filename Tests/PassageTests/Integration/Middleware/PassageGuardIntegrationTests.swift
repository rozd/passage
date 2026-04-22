import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration), .primeNIOSingletons)
struct `PassageGuard Integration Tests` {

    // MARK: - Configuration Helpers

    /// Configures a test Vapor application with Passage and guarded routes
    @Sendable private func configure(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

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

        // Route with default PassageGuard (401 unauthorized)
        let guardedDefault = app.grouped(PassageBearerAuthenticator()).grouped(PassageGuard())
        guardedDefault.get("guarded-default") { req -> String in
            return "access-granted"
        }

        // Route with custom error PassageGuard (403 forbidden)
        let customError = Abort(.forbidden, reason: "Custom forbidden message")
        let guardedCustom = app.grouped(PassageBearerAuthenticator()).grouped(PassageGuard(throwing: customError))
        guardedCustom.get("guarded-custom") { req -> String in
            return "access-granted"
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
        userId: String
    ) async throws -> String {
        let payload = AccessToken(
            userId: userId,
            expiresAt: Date().addingTimeInterval(3600),
            issuer: "test-issuer",
            audience: nil,
            scope: nil
        )

        let req = Request(application: app, on: app.eventLoopGroup.any())
        return try await req.jwt.sign(payload, kid: JWKIdentifier(string: "test-key"))
    }

    // MARK: - Authenticated User Tests

    @Test
    func `Guard allows authenticated requests through`() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app)
            let token = try await createAccessToken(app: app, userId: userId)

            try await app.testing().test(.GET, "guarded-default", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "access-granted")
            })
        }
    }

    @Test
    func `Guard allows authenticated requests through with custom error config`() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app)
            let token = try await createAccessToken(app: app, userId: userId)

            try await app.testing().test(.GET, "guarded-custom", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "access-granted")
            })
        }
    }

    // MARK: - Unauthenticated User Tests

    @Test
    func `Guard blocks unauthenticated requests with default 401 error`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "guarded-default", afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Guard blocks unauthenticated requests with custom error`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "guarded-custom", afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
        }
    }

    @Test
    func `Guard default error includes helpful reason message`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "guarded-default", afterResponse: { res async throws in
                #expect(res.status == .unauthorized)

                // Check the error response contains the reason
                let body = String(buffer: res.body)
                #expect(body.contains("User not authenticated") || body.contains("unauthorized"))
            })
        }
    }

    @Test
    func `Guard custom error includes custom reason message`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "guarded-custom", afterResponse: { res async throws in
                #expect(res.status == .forbidden)

                let body = String(buffer: res.body)
                #expect(body.contains("Custom forbidden message") || body.contains("forbidden"))
            })
        }
    }

    // MARK: - Integration with PassageAuthenticator

    @Test
    func `Guard integrates properly with PassageAuthenticator chain`() async throws {
        try await withApp(configure: configure) { app in
            // First verify unauthenticated is blocked
            try await app.testing().test(.GET, "guarded-default", afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })

            // Then authenticate and verify access is granted
            let userId = try await createTestUser(app: app)
            let token = try await createAccessToken(app: app, userId: userId)

            try await app.testing().test(.GET, "guarded-default", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }
}
