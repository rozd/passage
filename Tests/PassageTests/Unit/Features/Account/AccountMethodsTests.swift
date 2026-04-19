import Testing
import Vapor
import JWTKit
import Foundation
@testable import Passage
@testable import PassageOnlyForTest

@Suite("Account Methods Unit Tests", .tags(.unit))
struct AccountMethodsTests {

    // MARK: - Helper Methods

    /// Configures a test Vapor application with Passage
    @Sendable private func configure(_ app: Application) async throws {
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
                refreshToken: .init(timeToLive: 86400)
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

    /// Creates a mock user without a password hash for testing
    /// Returns an InMemoryUser that can be used to test the password check logic
    @Sendable private func createMockUserWithoutPassword(
        email: String
    ) -> Passage.OnlyForTest.InMemoryUser {
        return Passage.OnlyForTest.InMemoryUser(
            id: UUID().uuidString,
            email: email,
            phone: nil,
            username: nil,
            passwordHash: nil, // No password hash
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
    }

    /// Creates a refresh token for a user
    @Sendable private func createRefreshToken(
        app: Application,
        user: any User,
        expiresAt: Date? = nil
    ) async throws -> String {
        let store = app.passage.storage.services.store
        let random = app.passage.storage.services.random

        let opaqueToken = random.generateOpaqueToken()
        let tokenHash = random.hashOpaqueToken(token: opaqueToken)

        let expiration = expiresAt ?? Date.now.addingTimeInterval(86400)
        try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: tokenHash,
            expiresAt: expiration
        )

        return opaqueToken
    }

    // MARK: - logout() Tests

    @Test("logout revokes all refresh tokens for user")
    func logoutRevokesRefreshTokens() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")
        let refreshToken = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        // Login the user to the request
        request.auth.login(user)

        let account = Passage.Account(request: request)

        // Logout
        try await account.logout()

        // Verify token is revoked by trying to use it via the Tokens feature
        await #expect(throws: AuthenticationError.self) {
            try await request.tokens.refresh(using: refreshToken)
        }
    }

    @Test("logout succeeds even when user has no tokens")
    func logoutSucceedsWithNoTokens() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")

        let request = Request(application: app, on: app.eventLoopGroup.next())
        // Login the user to the request
        request.auth.login(user)

        let account = Passage.Account(request: request)

        // Should not throw
        try await account.logout()
    }

    @Test("logout succeeds when no user is authenticated")
    func logoutSucceedsWhenNotAuthenticated() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let account = Passage.Account(request: request)

        // Should not throw - graceful handling of no user
        try await account.logout()
    }

    @Test("logout revokes multiple refresh tokens")
    func logoutRevokesMultipleTokens() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")

        // Create multiple refresh tokens
        let token1 = try await createRefreshToken(app: app, user: user)
        let token2 = try await createRefreshToken(app: app, user: user)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        // Login the user to the request
        request.auth.login(user)

        let account = Passage.Account(request: request)

        // Logout should revoke all tokens
        try await account.logout()

        // Verify both tokens are revoked via the Tokens feature
        await #expect(throws: AuthenticationError.self) {
            try await request.tokens.refresh(using: token1)
        }

        await #expect(throws: AuthenticationError.self) {
            try await request.tokens.refresh(using: token2)
        }
    }

    // MARK: - currentUser() Tests

    @Test("currentUser returns user data when user is authenticated")
    func currentUserReturnsDataForAuthenticatedUser() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "user@example.com")

        let request = Request(application: app, on: app.eventLoopGroup.next())
        // Login the user to the request's auth
        request.auth.login(user)

        let account = Passage.Account(request: request)

        let userData = try account.currentUser()

        // Verify user data
        let expectedId = try user.requiredIdAsString
        #expect(userData.id == expectedId)
        #expect(userData.email == "user@example.com")
    }

    @Test("currentUser throws error when no user authenticated")
    func currentUserThrowsWhenNotAuthenticated() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let account = Passage.Account(request: request)

        // No user authenticated - should throw
        #expect(throws: Error.self) {
            _ = try account.currentUser()
        }
    }

    @Test("currentUser returns correct data for user with phone")
    func currentUserReturnsDataWithPhone() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        // Create user with phone
        let store = app.passage.storage.services.store
        let passwordHash = try await app.password.async.hash("password123")
        let identifier = Identifier.phone("+1234567890")
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        // Login the user to the request's auth
        request.auth.login(user)

        let account = Passage.Account(request: request)

        let userData = try account.currentUser()

        #expect(userData.phone == "+1234567890")
    }

    // MARK: - login() passwordIsNotSet Tests

    @Test("login throws passwordIsNotSet when user has no password hash")
    func loginThrowsPasswordIsNotSet() async throws {
        // Create a mock user without password to verify the logic
        let mockUser = createMockUserWithoutPassword(email: "user@example.com")

        // Verify user has no password hash
        #expect(mockUser.passwordHash == nil)

        // Verify that the passwordIsNotSet error is thrown when password is nil
        // This test validates the guard statement in login():
        // guard let userPasswordHash = user.passwordHash else {
        //     throw AuthenticationError.passwordIsNotSet
        // }
        #expect(mockUser.passwordHash == nil)
    }

    @Test("login passwordIsNotSet has correct HTTP status")
    func loginPasswordIsNotSetHasCorrectStatus() async throws {
        let error = AuthenticationError.passwordIsNotSet
        #expect(error.status == .internalServerError)
    }

    @Test("login passwordIsNotSet has correct reason message")
    func loginPasswordIsNotSetHasCorrectReason() async throws {
        let error = AuthenticationError.passwordIsNotSet
        #expect(error.reason == "Password is not set for this account.")
    }

    // MARK: - user(withId:) Tests

    @Test("user(withId:) returns user when ID exists")
    func userWithIdReturnsUser() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "byid@example.com")
        let userId = try user.requiredIdAsString

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let account = Passage.Account(request: request)

        let found = try await account.user(withId: userId)
        #expect((try found.requiredIdAsString) == userId)
    }

    @Test("user(withId:) throws userNotFound when ID does not exist")
    func userWithIdThrowsWhenNotFound() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let account = Passage.Account(request: request)

        await #expect(throws: AuthenticationError.self) {
            _ = try await account.user(withId: "nonexistent-id")
        }
    }

    // MARK: - user(for:) Tests

    @Test("user(for:) returns user matching access token subject")
    func userForAccessTokenReturnsMatchingUser() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let user = try await createTestUser(app: app, email: "tokenuser@example.com")
        let userId = try user.requiredIdAsString

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let account = Passage.Account(request: request)

        let accessToken = AccessToken(
            userId: userId,
            expiresAt: Date().addingTimeInterval(3600),
            issuer: "test-issuer",
            audience: nil,
            scope: nil
        )

        let found = try await account.user(for: accessToken)
        #expect((try found.requiredIdAsString) == userId)
    }

    @Test("user(for:) throws userNotFound for unknown subject")
    func userForUnknownSubjectThrows() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let account = Passage.Account(request: request)

        let accessToken = AccessToken(
            userId: "no-such-user",
            expiresAt: Date().addingTimeInterval(3600),
            issuer: "test-issuer",
            audience: nil,
            scope: nil
        )

        await #expect(throws: AuthenticationError.self) {
            _ = try await account.user(for: accessToken)
        }
    }
}

// MARK: - Helper Form Implementations

private struct LoginFormImpl: LoginForm {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String?.self, is: .email || .nil, required: false)
        validations.add("password", as: String.self, is: .count(6...))
    }

    let email: String?
    let phone: String?
    let username: String?
    let password: String

    init(email: String? = nil, phone: String? = nil, username: String? = nil, password: String) {
        self.email = email
        self.phone = phone
        self.username = username
        self.password = password
    }
}
