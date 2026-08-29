import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .login))
struct `Login Integration Tests` {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage
    @Sendable private func configure(_ app: Application) async throws {
        try await configureWithConcurrency(app, concurrency: .unlimited)
    }

    @Sendable private func configureWithConcurrency(
        _ app: Application,
        concurrency: Passage.Configuration.Tokens.RefreshToken.Concurrency
    ) async throws {
        // Add HMAC key directly for testing (simpler than RSA)
        // Using JWTKit's direct API instead of JWKS
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        // Configure Passage with test services
        // Note: We pass an empty JWKS since we added the key directly above
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
                refreshToken: .init(timeToLive: 86400, concurrency: concurrency)
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

    // MARK: - Successful Login Tests

    @Test
    func `Login succeeds with verified email`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with verified email
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            // Attempt login via HTTP
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(authUser.user.email == "user@example.com")
                #expect(!authUser.accessToken.isEmpty)
                #expect(!authUser.refreshToken.isEmpty)
                #expect(authUser.tokenType == "Bearer")
                #expect(authUser.expiresIn == 3600)
            })
        }
    }

    @Test
    func `Login succeeds with verified phone`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with verified phone
            try await createTestUser(
                app: app,
                phone: "+1234567890",
                password: "password123",
                isPhoneVerified: true
            )

            // Attempt login via HTTP
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(authUser.user.phone == "+1234567890")
                #expect(!authUser.accessToken.isEmpty)
                #expect(!authUser.refreshToken.isEmpty)
                #expect(authUser.tokenType == "Bearer")
            })
        }
    }

    @Test
    func `Login succeeds with username (no verification required)`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with username
            try await createTestUser(
                app: app,
                username: "testuser",
                password: "password123"
            )

            // Attempt login via HTTP
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(!authUser.accessToken.isEmpty)
                #expect(!authUser.refreshToken.isEmpty)
                #expect(authUser.tokenType == "Bearer")
            })
        }
    }

    // MARK: - Validation Failure Tests

    @Test
    func `Login fails when no identifier is provided`() async throws {
        try await withApp(configure: configure) { app in
            // Attempt login with no identifier
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    // MARK: - User Not Found Tests

    @Test
    func `Login fails when email does not exist`() async throws {
        try await withApp(configure: configure) { app in
            // No user created, attempt login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "nonexistent@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Login fails when phone does not exist`() async throws {
        try await withApp(configure: configure) { app in
            // No user created, attempt login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+9999999999",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Login fails when username does not exist`() async throws {
        try await withApp(configure: configure) { app in
            // No user created, attempt login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "nonexistent",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Password Mismatch Tests

    @Test
    func `Login fails with incorrect password for email`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with verified email
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "correctpassword",
                isEmailVerified: true
            )

            // Attempt login with wrong password
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "wrongpassword"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Login fails with incorrect password for phone`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with verified phone
            try await createTestUser(
                app: app,
                phone: "+1234567890",
                password: "correctpassword",
                isPhoneVerified: true
            )

            // Attempt login with wrong password
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "wrongpassword"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Login fails with incorrect password for username`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with username
            try await createTestUser(
                app: app,
                username: "testuser",
                password: "correctpassword"
            )

            // Attempt login with wrong password
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "wrongpassword"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Unverified Identifier Tests

    @Test
    func `Login fails with unverified email`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with unverified email
            try await createTestUser(
                app: app,
                email: "unverified@example.com",
                password: "password123",
                isEmailVerified: false
            )

            // Attempt login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "unverified@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
        }
    }

    @Test
    func `Login fails with unverified phone`() async throws {
        try await withApp(configure: configure) { app in
            // Create user with unverified phone
            try await createTestUser(
                app: app,
                phone: "+1234567890",
                password: "password123",
                isPhoneVerified: false
            )

            // Attempt login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
        }
    }

    // MARK: - Token Generation Tests

    @Test
    func `Login generates valid access token with correct claims`() async throws {
        try await withApp(configure: configure) { app in
            // Create verified user
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            // Login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)

                // Verify access token by decoding it
                let req = Request(application: app, on: app.eventLoopGroup.any())
                let payload = try await req.jwt.verify(authUser.accessToken, as: AccessToken.self)

                #expect(payload.issuer?.value == "test-issuer")
                #expect(!payload.subject.value.isEmpty)
                #expect(payload.expiration.value > Date())
            })
        }
    }

    @Test
    func `Login generates refresh token stored in database`() async throws {
        try await withApp(configure: configure) { app in
            // Create verified user
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            // Login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)

                // Verify refresh token is in store
                let store = app.passage.storage.services.store
                let random = app.passage.storage.services.random
                let hash = random.hashOpaqueToken(token: authUser.refreshToken)
                let refreshToken = try await store.tokens.find(refreshTokenHash: hash)

                #expect(refreshToken != nil)
                #expect(refreshToken?.isValid == true)
            })
        }
    }

    @Test
    func `Login revokes previous refresh tokens`() async throws {
        try await withApp(configure: { app in
            try await self.configureWithConcurrency(app, concurrency: .single)
        }) { app in
            // Create verified user
            try await createTestUser(
                app: app,
                email: "user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            var firstRefreshToken = ""

            // First login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                firstRefreshToken = authUser.refreshToken
            })

            // Second login
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let secondAuth = try res.content.decode(AuthUser.self)

                // First token should be revoked
                let store = app.passage.storage.services.store
                let random = app.passage.storage.services.random
                let firstHash = random.hashOpaqueToken(token: firstRefreshToken)
                let firstToken = try await store.tokens.find(refreshTokenHash: firstHash)

                #expect(firstToken?.revokedAt != nil)

                // Second token should be valid
                let secondHash = random.hashOpaqueToken(token: secondAuth.refreshToken)
                let secondToken = try await store.tokens.find(refreshTokenHash: secondHash)

                #expect(secondToken?.isValid == true)
            })
        }
    }

    // MARK: - Additional Edge Cases

    @Test
    func `Multiple users can exist with different identifier types`() async throws {
        try await withApp(configure: configure) { app in
            // Create users with different identifier types
            try await createTestUser(
                app: app,
                email: "email@example.com",
                password: "password1",
                isEmailVerified: true
            )

            try await createTestUser(
                app: app,
                phone: "+1234567890",
                password: "password2",
                isPhoneVerified: true
            )

            try await createTestUser(
                app: app,
                username: "testuser",
                password: "password3"
            )

            var emailUserId = ""
            var phoneUserId = ""
            var usernameUserId = ""

            // Login with each
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "email@example.com",
                    "password": "password1"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                emailUserId = authUser.user.id
            })

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password2"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                phoneUserId = authUser.user.id
            })

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "password3"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                usernameUserId = authUser.user.id
            })

            // All should have different user IDs
            #expect(emailUserId != phoneUserId)
            #expect(emailUserId != usernameUserId)
            #expect(phoneUserId != usernameUserId)
        }
    }
}
