import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration), .primeNIOSingletons)
struct `Current User (GET /me) Integration Tests` {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage
    @Sendable private func configure(_ app: Application) async throws {
        // Add HMAC key directly for testing (simpler than RSA)
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

        // Use empty JWKS since we're adding keys manually
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
                email: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                phone: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                useQueues: false
            ),
            restoration: .init(
                email: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                phone: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                useQueues: false
            )
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    /// Creates a test user with the given identifier and verification status
    @Sendable private func createTestUser(
        app: Application,
        email: String? = nil,
        phone: String? = nil,
        username: String? = nil,
        password: String = "password123",
        isEmailVerified: Bool = false,
        isPhoneVerified: Bool = false
    ) async throws {
        let store = app.passage.storage.services.store

        // Hash the password
        let passwordHash = try await app.password.async.hash(password)

        // Create identifier based on type
        let identifier: Identifier
        if let email = email {
            identifier = .email(email)
        } else if let phone = phone {
            identifier = .phone(phone)
        } else if let username = username {
            identifier = .username(username)
        } else {
            throw PassageError.unexpected(message: "At least one identifier must be provided")
        }

        // Create user
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        // Update verification status if needed
        if isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }
        if isPhoneVerified {
            try await store.users.markPhoneVerified(for: user)
        }
    }

    /// Logs in a user and returns the access token
    @Sendable private func loginAndGetAccessToken(
        app: Application,
        email: String? = nil,
        phone: String? = nil,
        username: String? = nil,
        password: String = "password123"
    ) async throws -> String {
        var accessToken = ""

        try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
            if let email = email {
                try req.content.encode([
                    "email": email,
                    "password": password
                ])
            } else if let phone = phone {
                try req.content.encode([
                    "phone": phone,
                    "password": password
                ])
            } else if let username = username {
                try req.content.encode([
                    "username": username,
                    "password": password
                ])
            }
        }, afterResponse: { res async throws in
            #expect(res.status == .ok)
            let authUser = try res.content.decode(AuthUser.self)
            accessToken = authUser.accessToken
        })

        return accessToken
    }

    // MARK: - Endpoint Existence Tests

    @Test
    func `GET /me endpoint exists`() async throws {
        try await withApp(configure: configure) { app in
            // Create and login user
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let accessToken = try await loginAndGetAccessToken(
                app: app,
                email: "user@example.com",
                password: "password123"
            )

            // Request GET /me with valid token
            try await app.testing().test(.GET, "me", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async in
                // Endpoint should exist - not return 404
                #expect(res.status != .notFound)
            })
        }
    }

    // MARK: - Authenticated User Tests

    @Test
    func `Authenticated user with email can get current user info`() async throws {
        try await withApp(configure: configure) { app in
            // Create and login user with email
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let accessToken = try await loginAndGetAccessToken(
                app: app,
                email: "user@example.com",
                password: "password123"
            )

            // Request GET /me
            try await app.testing().test(.GET, "/me", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let userInfo = try res.content.decode(AuthUser.User.self)
                #expect(userInfo.email == "user@example.com")
                #expect(!userInfo.id.isEmpty)
            })
        }
    }

    @Test
    func `Authenticated user with phone can get current user info`() async throws {
        try await withApp(configure: configure) { app in
            // Create and login user with phone
            try await createTestUser(
                app: app,
                phone: "+1234567890",
                password: "password123",
                isPhoneVerified: true
            )

            let accessToken = try await loginAndGetAccessToken(
                app: app,
                phone: "+1234567890",
                password: "password123"
            )

            // Request GET /me
            try await app.testing().test(.GET, "/me", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let userInfo = try res.content.decode(AuthUser.User.self)
                #expect(userInfo.phone == "+1234567890")
                #expect(!userInfo.id.isEmpty)
            })
        }
    }

    @Test
    func `Authenticated user with username can get current user info`() async throws {
        try await withApp(configure: configure) { app in
            // Create and login user with username
            try await createTestUser(
                app: app,
                username: "testuser",
                password: "password123"
            )

            let accessToken = try await loginAndGetAccessToken(
                app: app,
                username: "testuser",
                password: "password123"
            )

            // Request GET /me
            try await app.testing().test(.GET, "/me", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let userInfo = try res.content.decode(AuthUser.User.self)
                #expect(!userInfo.id.isEmpty)
            })
        }
    }

    // MARK: - Unauthenticated User Tests

    @Test
    func `Unauthenticated request to /me returns authentication error`() async throws {
        try await withApp(configure: configure) { app in
            // Request GET /me without any authorization header
            try await app.testing().test(.GET, "/me", afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Request with invalid token returns authentication error`() async throws {
        try await withApp(configure: configure) { app in
            // Request GET /me with an invalid token
            try await app.testing().test(.GET, "/me", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: "invalid-token")
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Request with malformed authorization header returns authentication error`() async throws {
        try await withApp(configure: configure) { app in
            // Request GET /me with malformed authorization
            try await app.testing().test(.GET, "/me", beforeRequest: { req in
                req.headers.add(name: .authorization, value: "NotBearer some-token")
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Request with expired token returns authentication error`() async throws {
        try await withApp(configure: configure) { app in
            // Create user
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            // Create an expired token manually
            let store = app.passage.storage.services.store
            let user = try await store.users.find(byIdentifier: .email("user@example.com"))
            #expect(user != nil)

            // Create an access token that's already expired
            let expiredPayload = AccessToken(
                userId: try user!.requiredIdAsString,
                issuedAt: Date().addingTimeInterval(-7200),
                expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
                issuer: "test-issuer",
                audience: nil,
                scope: nil
            )

            let req = Request(application: app, on: app.eventLoopGroup.any())
            let expiredToken = try await req.jwt.sign(expiredPayload, kid: JWKIdentifier(string: "test-key"))

            // Request GET /me with expired token
            try await app.testing().test(.GET, "/me", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: expiredToken)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }
}
