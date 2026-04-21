import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

@Suite("PassageContext Integration Tests", .tags(.integration))
struct PassageContextIntegrationTests {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage and test routes for PassageContext
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

        // Route that tests request.passage.hasUser
        let authenticated = app.grouped(PassageBearerAuthenticator())
        authenticated.get("test-has-user") { req -> String in
            return req.passage.hasUser ? "has-user:true" : "has-user:false"
        }

        // Route that tests request.passage.user (requires user to be authenticated)
        authenticated.get("test-get-user") { req -> String in
            do {
                let user = try req.passage.user
                return "user-id:\(user.id ?? "nil")"
            } catch {
                return "error:\(error)"
            }
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

    // MARK: - hasUser Tests

    @Test("request.passage.hasUser returns true when authenticated")
    func hasUserReturnsTrueWhenAuthenticated() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app)
            let token = try await createAccessToken(app: app, userId: userId)

            try await app.testing().test(.GET, "test-has-user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "has-user:true")
            })
        }
    }

    @Test("request.passage.hasUser returns false when not authenticated")
    func hasUserReturnsFalseWhenNotAuthenticated() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "test-has-user", afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "has-user:false")
            })
        }
    }

    // MARK: - user Property Tests

    @Test("request.passage.user returns authenticated user")
    func userReturnsAuthenticatedUser() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app)
            let token = try await createAccessToken(app: app, userId: userId)

            try await app.testing().test(.GET, "test-get-user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "user-id:\(userId)")
            })
        }
    }

    @Test("request.passage.user throws when no user authenticated")
    func userThrowsWhenNotAuthenticated() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "test-get-user", afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body.contains("error:"))
            })
        }
    }

    // MARK: - Context Access Tests

    @Test("PassageContext is accessible via request.passage extension")
    func contextAccessibleViaRequestExtension() async throws {
        try await withApp(configure: configure) { app in
            // Just verify the route works - the route handler itself uses request.passage
            try await app.testing().test(.GET, "test-has-user", afterResponse: { res async in
                // Route should execute without crashing, proving request.passage is accessible
                #expect(res.status == .ok)
            })
        }
    }
}
