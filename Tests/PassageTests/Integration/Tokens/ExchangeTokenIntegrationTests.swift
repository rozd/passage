import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .exchangeCode), .primeNIOSingletons)
struct `Exchange Token Integration Tests` {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage
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
    ) async throws -> any User {
        let store = app.passage.storage.services.store

        let passwordHash = try await app.password.async.hash(password)

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

        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        if isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }
        if isPhoneVerified {
            try await store.users.markPhoneVerified(for: user)
        }

        return user
    }

    // MARK: - Successful Exchange Tests

    @Test
    func `Exchange code endpoint returns tokens for valid code`() async throws {
        try await withApp(configure: configure) { app in
            // Create a user
            let user = try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            // Generate exchange code directly (simulating OAuth callback)
            let store = app.passage.storage.services.store
            let random = app.passage.storage.services.random
            let code = random.generateOpaqueToken()
            let hash = random.hashOpaqueToken(token: code)

            try await store.exchangeTokens.createExchangeToken(
                for: user,
                tokenHash: hash,
                expiresAt: Date().addingTimeInterval(60)
            )

            // Exchange the code
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(!authUser.accessToken.isEmpty)
                #expect(!authUser.refreshToken.isEmpty)
                #expect(authUser.tokenType == "Bearer")
                #expect(authUser.expiresIn == 3600)
                #expect(authUser.user.email == "user@example.com")
            })
        }
    }

    @Test
    func `Exchange code returns valid access token`() async throws {
        try await withApp(configure: configure) { app in
            let user = try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let store = app.passage.storage.services.store
            let random = app.passage.storage.services.random
            let code = random.generateOpaqueToken()
            let hash = random.hashOpaqueToken(token: code)

            try await store.exchangeTokens.createExchangeToken(
                for: user,
                tokenHash: hash,
                expiresAt: Date().addingTimeInterval(60)
            )

            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)

                // Verify the access token
                let req = Request(application: app, on: app.eventLoopGroup.any())
                let payload = try await req.jwt.verify(authUser.accessToken, as: AccessToken.self)

                #expect(payload.issuer?.value == "test-issuer")
                #expect(!payload.subject.value.isEmpty)
                #expect(payload.expiration.value > Date())
            })
        }
    }

    // MARK: - Error Cases

    @Test
    func `Exchange fails with invalid code`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": "invalid-code-that-does-not-exist"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Exchange fails with empty code`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": ""
                ])
            }, afterResponse: { res async in
                // Should fail - either bad request or unauthorized
                #expect(res.status == .badRequest || res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Exchange fails without code in request`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([String: String]())
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Exchange fails with expired code`() async throws {
        try await withApp(configure: configure) { app in
            let user = try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let store = app.passage.storage.services.store
            let random = app.passage.storage.services.random
            let code = random.generateOpaqueToken()
            let hash = random.hashOpaqueToken(token: code)

            // Create exchange token that's already expired
            try await store.exchangeTokens.createExchangeToken(
                for: user,
                tokenHash: hash,
                expiresAt: Date().addingTimeInterval(-60) // expired 1 minute ago
            )

            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Single-Use Enforcement Tests

    @Test
    func `Exchange code cannot be used twice`() async throws {
        try await withApp(configure: configure) { app in
            let user = try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let store = app.passage.storage.services.store
            let random = app.passage.storage.services.random
            let code = random.generateOpaqueToken()
            let hash = random.hashOpaqueToken(token: code)

            try await store.exchangeTokens.createExchangeToken(
                for: user,
                tokenHash: hash,
                expiresAt: Date().addingTimeInterval(60)
            )

            // First exchange - should succeed
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Second exchange with same code - should fail
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - User Data Consistency Tests

    @Test
    func `Exchange returns correct user data`() async throws {
        try await withApp(configure: configure) { app in
            let user = try await createTestUser(
                app: app,
                email: "specific@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let store = app.passage.storage.services.store
            let random = app.passage.storage.services.random
            let code = random.generateOpaqueToken()
            let hash = random.hashOpaqueToken(token: code)

            try await store.exchangeTokens.createExchangeToken(
                for: user,
                tokenHash: hash,
                expiresAt: Date().addingTimeInterval(60)
            )

            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(authUser.user.email == "specific@example.com")
                #expect(authUser.user.id == user.id?.description)
            })
        }
    }

    // MARK: - Custom Route Path Tests

    @Test
    func `Exchange works with custom route path`() async throws {
        @Sendable func customConfigure(_ app: Application) async throws {
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
                routes: .init(
                    group: "api", "v1",
                    exchangeCode: .init(path: "oauth", "exchange")
                ),
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
        }

        try await withApp(configure: customConfigure) { app in
            let user = try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let store = app.passage.storage.services.store
            let random = app.passage.storage.services.random
            let code = random.generateOpaqueToken()
            let hash = random.hashOpaqueToken(token: code)

            try await store.exchangeTokens.createExchangeToken(
                for: user,
                tokenHash: hash,
                expiresAt: Date().addingTimeInterval(60)
            )

            // Exchange at custom path
            try await app.testing().test(.POST, "api/v1/oauth/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })
        }
    }

    // MARK: - Refresh Token Usability Tests

    @Test
    func `Refresh token from exchange is usable`() async throws {
        try await withApp(configure: configure) { app in
            let user = try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let store = app.passage.storage.services.store
            let random = app.passage.storage.services.random
            let code = random.generateOpaqueToken()
            let hash = random.hashOpaqueToken(token: code)

            try await store.exchangeTokens.createExchangeToken(
                for: user,
                tokenHash: hash,
                expiresAt: Date().addingTimeInterval(60)
            )

            var refreshToken = ""

            // Exchange the code
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode([
                    "code": code
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                refreshToken = authUser.refreshToken
            })

            // Use the refresh token
            try await app.testing().test(.POST, "auth/refresh-token", beforeRequest: { req in
                try req.content.encode([
                    "refreshToken": refreshToken
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(!authUser.accessToken.isEmpty)
                #expect(!authUser.refreshToken.isEmpty)
                #expect(authUser.refreshToken != refreshToken) // Should be rotated
            })
        }
    }
}
