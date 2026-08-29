import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor

@Suite(.tags(.unit))
struct `Tokens Methods Unit Tests` {

    // MARK: - Helper Methods

    /// Configures a test Vapor application with Passage
    @Sendable private func configure(
        _ app: Application,
        tokenConcurrency: Passage.Configuration.Tokens.RefreshToken.Concurrency = .unlimited
    ) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: nil,
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
                refreshToken: .init(timeToLive: 86400, concurrency: tokenConcurrency)
            ),
            jwt: .init(jwks: .init(json: emptyJwks))
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    /// Creates a test user with the given parameters
    @Sendable private func createTestUser(
        app: Application,
        email: String? = nil,
        password: String = "password123"
    ) async throws -> any User {
        let store = app.passage.storage.services.store
        let passwordHash = try await app.password.async.hash(password)
        let identifier = Identifier.email(email ?? "test@example.com")
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        return user
    }

    /// Creates a refresh token for a user directly in the store
    @Sendable private func createRefreshToken(
        app: Application,
        user: any User,
        expiresAt: Date? = nil,
        sessionId: UUID = UUID()
    ) async throws -> String {
        let store = app.passage.storage.services.store
        let random = app.passage.storage.services.random

        let opaqueToken = random.generateOpaqueToken()
        let tokenHash = random.hashOpaqueToken(token: opaqueToken)

        let expiration = expiresAt ?? Date.now.addingTimeInterval(86400)
        try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: tokenHash,
            expiresAt: expiration,
            sessionId: sessionId
        )

        return opaqueToken
    }

    // MARK: - issue() Tests

    @Test
    func `issue creates access and refresh tokens for user`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        let authUser = try await tokens.issue(for: user, sessionId: UUID(), origin: .login)

        #expect(!authUser.accessToken.isEmpty)
        #expect(!authUser.refreshToken.isEmpty)
        #expect(authUser.tokenType == "Bearer")
        #expect(authUser.expiresIn == 3600)
        #expect(authUser.user.email == "user@example.com")
    }

    @Test
    func `issue revokes existing tokens with single concurrency`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app, tokenConcurrency: .single)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let existingToken = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        _ = try await tokens.issue(for: user, sessionId: UUID(), origin: .login)

        await #expect(throws: AuthenticationError.self) {
            try await tokens.refresh(using: existingToken)
        }
    }

    @Test
    func `issue keeps existing tokens with unlimited concurrency policy`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let existingToken = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        _ = try await tokens.issue(for: user, sessionId: UUID(), origin: .login)

        let authUser = try await tokens.refresh(using: existingToken)
        #expect(!authUser.accessToken.isEmpty)
    }

    @Test
    func `issue stores refresh token in database`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        let authUser = try await tokens.issue(for: user, sessionId: UUID(), origin: .login)

        // Verify refresh token is in store
        let store = app.passage.storage.services.store
        let random = app.passage.storage.services.random
        let hash = random.hashOpaqueToken(token: authUser.refreshToken)
        let storedToken = try await store.tokens.find(refreshTokenHash: hash)

        #expect(storedToken != nil)
        #expect(storedToken?.isValid == true)
    }

    // MARK: - refresh() Tests

    @Test
    func `refresh succeeds with valid token`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let refreshToken = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        let authUser = try await tokens.refresh(using: refreshToken)

        #expect(!authUser.accessToken.isEmpty)
        #expect(!authUser.refreshToken.isEmpty)
        #expect(authUser.refreshToken != refreshToken) // Should be a new token
        #expect(authUser.tokenType == "Bearer")
        let expectedUserId = try user.requiredIdAsString
        #expect(authUser.user.id == expectedUserId)
    }

    @Test
    func `refresh throws error when token not found`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        await #expect(throws: AuthenticationError.self) {
            try await tokens.refresh(using: "non-existent-token")
        }
    }

    @Test
    func `refresh throws error when token is expired`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let refreshToken = try await createRefreshToken(
            app: app,
            user: user,
            expiresAt: Date.now.addingTimeInterval(-3600), // Expired 1 hour ago
            sessionId: UUID()
        )

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        await #expect(throws: AuthenticationError.self) {
            try await tokens.refresh(using: refreshToken)
        }
    }

    @Test
    func `refresh succeeds after token rotation`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let originalToken = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        // Use the token once - creates a new token and marks original as replaced
        let authUser1 = try await tokens.refresh(using: originalToken)
        #expect(authUser1.refreshToken != originalToken)

        // The new token should work
        let authUser2 = try await tokens.refresh(using: authUser1.refreshToken)
        #expect(authUser2.refreshToken != authUser1.refreshToken)
        #expect(!authUser2.accessToken.isEmpty)
    }

    @Test
    func `refresh creates new token with correct expiration`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let refreshToken = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        let authUser = try await tokens.refresh(using: refreshToken)

        // Verify expiration time is set correctly (3600 seconds for access token)
        #expect(authUser.expiresIn == 3600)
    }

    // MARK: - revoke() Tests

    @Test
    func `revoke invalidates all refresh tokens for user`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let token1 = try await createRefreshToken(app: app, user: user)
        let token2 = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        // Revoke all tokens
        try await tokens.revoke(for: user)

        // Verify both tokens are revoked
        await #expect(throws: AuthenticationError.self) {
            try await tokens.refresh(using: token1)
        }

        await #expect(throws: AuthenticationError.self) {
            try await tokens.refresh(using: token2)
        }
    }

    @Test
    func `revoke succeeds when user has no tokens`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        // Should not throw
        try await tokens.revoke(for: user)
    }

    // MARK: - Request Extension Tests

    @Test
    func `Request.tokens returns Passage.Tokens instance`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.next())

        // Verify the extension returns a Tokens instance
        let tokens = request.tokens
        let typeName = String(describing: type(of: tokens))
        #expect(typeName == "Tokens")
    }

    @Test
    func `refresh never triggers eviction even under limit(1) policy`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app, tokenConcurrency: .limit(1))

        let user = try await createTestUser(app: app, email: "user@example.com")
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        let sessionId = UUID()
        let authUser1 = try await tokens.issue(for: user, sessionId: sessionId, origin: .login)

        let authUser2 = try await tokens.refresh(using: authUser1.refreshToken)
        #expect(!authUser2.refreshToken.isEmpty)

        let authUser3 = try await tokens.refresh(using: authUser2.refreshToken)
        #expect(!authUser3.refreshToken.isEmpty)

        let authUser4 = try await tokens.refresh(using: authUser3.refreshToken)
        #expect(!authUser4.refreshToken.isEmpty)
    }

    @Test
    func `limit(2) policy keeps two newest sessions and revokes oldest`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app, tokenConcurrency: .limit(2))

        let user = try await createTestUser(app: app, email: "user@example.com")
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let tokens = Passage.Tokens(request: request)

        let sessionId1 = UUID()
        let sessionId2 = UUID()
        let sessionId3 = UUID()

        let authUser1 = try await tokens.issue(for: user, sessionId: sessionId1, origin: .login)
        let authUser2 = try await tokens.issue(for: user, sessionId: sessionId2, origin: .login)
        let authUser3 = try await tokens.issue(for: user, sessionId: sessionId3, origin: .login)

        let store = app.passage.storage.services.store as! Passage.OnlyForTest.InMemoryStore
        let tokenStore = store.tokens as! Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore
        let refreshTokens = tokenStore.refreshTokens

        let session1Tokens = refreshTokens.filter { $0.sessionId == sessionId1 }
        let session2Tokens = refreshTokens.filter { $0.sessionId == sessionId2 }
        let session3Tokens = refreshTokens.filter { $0.sessionId == sessionId3 }

        #expect(!session1Tokens.isEmpty && session1Tokens.allSatisfy { $0.revokedAt != nil })
        #expect(!session2Tokens.isEmpty && session2Tokens.allSatisfy { $0.revokedAt == nil })
        #expect(!session3Tokens.isEmpty && session3Tokens.allSatisfy { $0.revokedAt == nil })

        let authUser2Refreshed = try await tokens.refresh(using: authUser2.refreshToken)
        #expect(!authUser2Refreshed.refreshToken.isEmpty)

        let authUser3Refreshed = try await tokens.refresh(using: authUser3.refreshToken)
        #expect(!authUser3Refreshed.refreshToken.isEmpty)

        await #expect(throws: AuthenticationError.self) {
            try await tokens.refresh(using: authUser1.refreshToken)
        }
    }
}
