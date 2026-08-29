import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

extension Tag {
    @Tag static var session: Self
}

@Suite(.tags(.integration, .session))
struct `Sessions Authentication Integration Tests` {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage and session support enabled
    @Sendable private func configureWithSession(_ app: Application) async throws {
        app.middleware.use(app.sessions.middleware)

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

        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            sessions: .init(enabled: true),
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
            ),
            views: viewsConfig
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )

        let authenticated = app
            .grouped(PassageSessionAuthenticator())
            .grouped(PassageBearerAuthenticator())

        authenticated.get("test-session-auth") { req -> String in
            if let user = req.auth.get(Passage.OnlyForTest.InMemoryUser.self) {
                return "authenticated:\(user.id ?? "no-id")"
            }
            return "not-authenticated"
        }

        let guarded = authenticated.grouped(PassageGuard())
        guarded.get("test-protected") { req -> String in
            let user = try req.passage.user
            return "protected:\(try user.requiredIdAsString)"
        }
    }

    @Sendable private func configureWithSessionAndRevokedHook(_ app: Application) async throws {
        app.middleware.use(app.sessions.middleware)

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

        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            sessions: .init(enabled: true),
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
            ),
            views: viewsConfig
        )

        let hooks = Passage.Hooks(
            account: .hook(isSessionRevoked: { _, _ in true })
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration,
            hooks: hooks
        )

        let authenticated = app
            .grouped(PassageSessionAuthenticator())
            .grouped(PassageBearerAuthenticator())

        authenticated.get("test-session-auth") { req -> String in
            if let user = req.auth.get(Passage.OnlyForTest.InMemoryUser.self) {
                return "authenticated:\(user.id ?? "no-id")"
            }
            return "not-authenticated"
        }

        let guarded = authenticated.grouped(PassageGuard())
        guarded.get("test-protected") { req -> String in
            let user = try req.passage.user
            return "protected:\(try user.requiredIdAsString)"
        }
    }

    /// Configures a test Vapor application with Passage and session support disabled
    @Sendable private func configureWithoutSession(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        // Configure Passage with test services and session disabled (default)
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
            sessions: .init(enabled: false),
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

    /// Creates a test user with verified email
    @Sendable private func createTestUser(
        app: Application,
        email: String = "user@example.com",
        password: String = "password123"
    ) async throws {
        let store = app.passage.storage.services.store

        let passwordHash = try await app.password.async.hash(password)
        let identifier = Identifier.email(email)
        let credential = Credential.password(passwordHash)

        let user = try await store.users.create(identifier: identifier, with: credential)
        try await store.users.markEmailVerified(for: user)
    }

    // MARK: - Login with Sessions Tests

    @Test
    func `Form login with session enabled sets session cookie`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "user@example.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)

                // Check that a session cookie was set
                let setCookieHeader = res.headers[.setCookie]
                #expect(setCookieHeader.contains { $0.contains("vapor-session") })
            })
        }
    }

    @Test
    func `Login with session disabled does not set session cookie`() async throws {
        try await withApp(configure: configureWithoutSession) { app in
            try await createTestUser(app: app)

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let hasSessionCookie = res.headers[.setCookie].contains { $0.contains("vapor-session") }
                // When sessions are disabled, there should be no session cookie
                #expect(!hasSessionCookie)
            })
        }
    }

    @Test
    func `JSON login with sessions enabled returns tokens and no session cookie`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(authUser.accessToken.isEmpty == false)

                let hasSessionCookie = res.headers[.setCookie].contains { $0.contains("vapor-session") }
                #expect(!hasSessionCookie)
            })
        }
    }

    // MARK: - Sessions Authentication Tests

    @Test
    func `Sessions authenticator authenticates user from session cookie`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            var sessionCookie: String?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "user@example.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)

                if let cookieHeader = res.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
                    // Parse the cookie value
                    let parts = cookieHeader.split(separator: ";")
                    if let cookiePart = parts.first {
                        sessionCookie = String(cookiePart)
                    }
                }
            })

            #expect(sessionCookie != nil)

            // Now access a protected route with just the session cookie (no Bearer token)
            try await app.testing().test(.GET, "test-session-auth", beforeRequest: { req in
                if let cookie = sessionCookie {
                    req.headers.add(name: .cookie, value: cookie)
                }
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body.contains("authenticated:"))
            })
        }
    }

    @Test
    func `Sessions authenticator with no session returns not authenticated`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            // Access route without any authentication
            try await app.testing().test(.GET, "test-session-auth", afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "not-authenticated")

                let hasSessionCookie = res.headers[.setCookie].contains { $0.contains("vapor-session") }
                #expect(!hasSessionCookie)
            })
        }
    }

    @Test
    func `Revoked cookie session is not authenticated`() async throws {
        try await withApp(configure: configureWithSessionAndRevokedHook) { app in
            try await createTestUser(app: app)

            var sessionCookie: String?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "user@example.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)

                if let cookieHeader = res.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
                    let parts = cookieHeader.split(separator: ";")
                    if let cookiePart = parts.first {
                        sessionCookie = String(cookiePart)
                    }
                }
            })

            #expect(sessionCookie != nil)

            try await app.testing().test(.GET, "test-protected", beforeRequest: { req in
                if let cookie = sessionCookie {
                    req.headers.add(name: .cookie, value: cookie)
                }
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Logout with Sessions Tests

    @Test
    func `Logout clears session when session is enabled`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            var sessionCookie: String?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "user@example.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)

                if let cookieHeader = res.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
                    let parts = cookieHeader.split(separator: ";")
                    if let cookiePart = parts.first {
                        sessionCookie = String(cookiePart)
                    }
                }
            })

            #expect(sessionCookie != nil)

            try await app.testing().test(.POST, "auth/logout", beforeRequest: { req in
                if let cookie = sessionCookie {
                    req.headers.add(name: .cookie, value: cookie)
                }
                try req.content.encode([String: String]())
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Try to access protected route with same session cookie - should fail
            try await app.testing().test(.GET, "test-session-auth", beforeRequest: { req in
                if let cookie = sessionCookie {
                    req.headers.add(name: .cookie, value: cookie)
                }
            }, afterResponse: { res async in
                let body = String(buffer: res.body)
                // After logout, session should be cleared
                #expect(body == "not-authenticated")
            })
        }
    }

    // MARK: - Current User with Sessions Tests

    @Test
    func `Current user endpoint works with session authentication`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            var sessionCookie: String?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "user@example.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)

                if let cookieHeader = res.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
                    let parts = cookieHeader.split(separator: ";")
                    if let cookiePart = parts.first {
                        sessionCookie = String(cookiePart)
                    }
                }
            })

            #expect(sessionCookie != nil)

            // Access /me with session cookie only
            try await app.testing().test(.GET, "me", beforeRequest: { req in
                if let cookie = sessionCookie {
                    req.headers.add(name: .cookie, value: cookie)
                }
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let userInfo = try res.content.decode(AuthUser.User.self)
                #expect(userInfo.email == "user@example.com")
            })
        }
    }

    // MARK: - Combined Auth Tests

    @Test
    func `Bearer token takes precedence when both session and bearer are provided`() async throws {
        try await withApp(configure: configureWithSession) { app in
            // Create two users
            try await createTestUser(app: app, email: "user1@example.com")
            try await createTestUser(app: app, email: "user2@example.com")

            var sessionCookie: String?
            var user2AccessToken: String?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "user1@example.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)

                if let cookieHeader = res.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
                    let parts = cookieHeader.split(separator: ";")
                    if let cookiePart = parts.first {
                        sessionCookie = String(cookiePart)
                    }
                }
            })

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "user2@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                user2AccessToken = authUser.accessToken
            })

            #expect(sessionCookie != nil)
            #expect(user2AccessToken != nil)

            // Access with user1's session cookie but user2's bearer token
            // Session authenticator runs first and finds user1, so session wins
            try await app.testing().test(.GET, "test-session-auth", beforeRequest: { req in
                if let cookie = sessionCookie {
                    req.headers.add(name: .cookie, value: cookie)
                }
                if let token = user2AccessToken {
                    req.headers.bearerAuthorization = BearerAuthorization(token: token)
                }
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                // Session runs first, so user1 from session is authenticated
                #expect(body.contains("authenticated:"))
            })
        }
    }

    // MARK: - PassageGuard with Session Tests

    @Test
    func `PassageGuard works with session authenticated user`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            var sessionCookie: String?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "user@example.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)

                if let cookieHeader = res.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
                    let parts = cookieHeader.split(separator: ";")
                    if let cookiePart = parts.first {
                        sessionCookie = String(cookiePart)
                    }
                }
            })

            #expect(sessionCookie != nil)

            // Access protected route with session cookie
            try await app.testing().test(.GET, "test-protected", beforeRequest: { req in
                if let cookie = sessionCookie {
                    req.headers.add(name: .cookie, value: cookie)
                }
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body.contains("protected:"))
            })
        }
    }

    @Test
    func `PassageGuard rejects unauthenticated request`() async throws {
        try await withApp(configure: configureWithSession) { app in
            try await createTestUser(app: app)

            // Access protected route without any authentication
            try await app.testing().test(.GET, "test-protected", afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }
}
