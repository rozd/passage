import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite
struct `PassageContext Tests` {

    // MARK: - Structure Tests

    @Test
    func `PassageContext type name is correct`() {
        let typeName = String(describing: PassageContext.self)
        #expect(typeName == "PassageContext")
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `PassageContext conforms to Sendable`() {
        // This test verifies at compile time that PassageContext is Sendable
        // If PassageContext didn't conform to Sendable, this would fail to compile
        func acceptsSendable<T: Sendable>(_ type: T.Type) {}
        acceptsSendable(PassageContext.self)
    }

    // MARK: - Public Interface Tests

    @Test
    func `PassageContext has user property`() {
        // Verify PassageContext has a user property that throws
        // This is a compile-time check - if the property doesn't exist, this won't compile
        func checkUserProperty(_ context: PassageContext) throws -> any User {
            try context.user
        }
        // Test passes if it compiles
    }

    @Test
    func `PassageContext has hasUser property`() {
        // Verify PassageContext has a hasUser bool property
        func checkHasUserProperty(_ context: PassageContext) -> Bool {
            context.hasUser
        }
        // Test passes if it compiles
    }

    @Test
    func `PassageContext has login method`() {
        // Verify PassageContext has a login method that accepts a User
        func checkLoginMethod(_ context: PassageContext, _ user: any User) async throws {
            _ = try await context.login(user, origin: .login, via: .bearer)
        }
        // Test passes if it compiles
    }

    @Test
    func `PassageContext has logout method`() {
        // Verify PassageContext has a logout method
        func checkLogoutMethod(_ context: PassageContext) {
            context.logout()
        }
        // Test passes if it compiles
    }

    // MARK: - Browser Login Tests

    @Test
    func `login via browser with sessions enabled returns nil and authenticates user with session`() async throws {
        try await withApp(configure: { app in
            app.middleware.use(app.sessions.middleware)

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

            let configuration = try Passage.Configuration(
                origin: URL(string: "http://localhost:8080")!,
                routes: .init(),
                tokens: .init(
                    issuer: "test-issuer",
                    accessToken: .init(timeToLive: 3600),
                    refreshToken: .init(timeToLive: 86400)
                ),
                sessions: .init(enabled: true),
                jwt: .init(jwks: .init(json: "{\"keys\":[]}")),
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

            try await app.passage.configure(services: services, configuration: configuration)

            app.post("test-browser-login") { req async throws -> String in
                let app = req.application
                let store = app.passage.storage.services.store
                let passwordHash = try await req.password.async.hash("password123")
                let identifier = Identifier.email("browser@example.com")
                let credential = Credential.password(passwordHash)
                let user = try await store.users.create(identifier: identifier, with: credential)

                let context = PassageContext(request: req)
                let sessionId = UUID()
                let result = try await context.login(user, origin: .login, via: .browser, sessionId: sessionId)

                #expect(result == nil)
                #expect(req.auth.has(Passage.OnlyForTest.InMemoryUser.self))
                #expect(req.session.sessionId == sessionId)
                return "ok"
            }
        }) { app in
            try await app.testing().test(.POST, "test-browser-login", afterResponse: { res async throws in
                #expect(res.status == .ok)
            })
        }
    }

    @Test
    func `login via browser with sessions disabled throws PassageError sessionsDisabled`() async throws {
        try await withApp(configure: { app in
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

            let configuration = try Passage.Configuration(
                origin: URL(string: "http://localhost:8080")!,
                routes: .init(),
                tokens: .init(
                    issuer: "test-issuer",
                    accessToken: .init(timeToLive: 3600),
                    refreshToken: .init(timeToLive: 86400)
                ),
                sessions: .init(enabled: false),
                jwt: .init(jwks: .init(json: "{\"keys\":[]}")),
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

            try await app.passage.configure(services: services, configuration: configuration)

            app.post("test-sessions-disabled") { req async throws -> String in
                let app = req.application
                let store = app.passage.storage.services.store
                let passwordHash = try await req.password.async.hash("password123")
                let identifier = Identifier.email("nobrowser@example.com")
                let credential = Credential.password(passwordHash)
                let user = try await store.users.create(identifier: identifier, with: credential)

                let context = PassageContext(request: req)

                do {
                    _ = try await context.login(user, origin: .login, via: .browser)
                    throw Abort(.internalServerError, reason: "Expected PassageError.sessionsDisabled to be thrown")
                } catch PassageError.sessionsDisabled {
                    return "sessions-disabled-error"
                } catch {
                    throw error
                }
            }
        }) { app in
            try await app.testing().test(.POST, "test-sessions-disabled", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == "sessions-disabled-error")
            })
        }
    }
}
