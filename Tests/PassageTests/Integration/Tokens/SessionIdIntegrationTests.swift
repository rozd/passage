import Foundation
import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration))
struct `Session ID Integration Tests` {

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
            sessions: .init(enabled: false),
            jwt: .init(jwks: .init(json: emptyJwks)),
            passwordless: .init(
                emailMagicLink: .email(
                    useQueues: false,
                    linkExpiration: 3600,
                    maxAttempts: 3,
                    autoCreateUser: false,
                    requireSameBrowser: true
                )
            ),
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

        let protected = app.grouped(PassageBearerAuthenticator())
        protected.get("get-session-id") { req -> String in
            if let sessionId = req.passage.sessionId {
                return sessionId.uuidString
            }
            return "no-session-id"
        }

        app.post("revoke-session", ":sid") { req async throws -> String in
            guard let sidParam = req.parameters.get("sid"),
                  let sessionId = UUID(uuidString: sidParam) else {
                throw Abort(.badRequest, reason: "Invalid session ID")
            }
            try await req.passage.revoke(sessionId: sessionId)
            return "revoked"
        }
    }

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

    @Test
    func `refresh preserves the sessionId from login`() async throws {
        try await withApp(configure: configure) { app in
            try await createTestUser(app: app, email: "sid1@test.com")

            var firstSessionId: UUID?
            var refreshToken: String = ""

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "sid1@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                refreshToken = authUser.refreshToken
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                firstSessionId = decodedToken.sessionId
            })

            var refreshedSessionId: UUID?
            try await app.testing().test(.POST, "auth/refresh-token", beforeRequest: { req in
                try req.content.encode(["refreshToken": refreshToken])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                refreshedSessionId = decodedToken.sessionId
            })

            #expect(refreshedSessionId == firstSessionId)
        }
    }

    @Test
    func `refresh token fails after session revocation`() async throws {
        try await withApp(configure: configure) { app in
            try await createTestUser(app: app, email: "sid2@test.com")

            var sessionId: UUID?
            var refreshToken: String = ""

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "sid2@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                refreshToken = authUser.refreshToken
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                sessionId = decodedToken.sessionId
            })

            try await app.testing().test(.POST, "revoke-session/\(sessionId!.uuidString)", beforeRequest: { req in
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            try await app.testing().test(.POST, "auth/refresh-token", beforeRequest: { req in
                try req.content.encode(["refreshToken": refreshToken])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `authenticated bearer request can access sessionId`() async throws {
        try await withApp(configure: configure) { app in
            let userId = try await createTestUser(app: app, email: "sid3@test.com")

            var accessToken: String = ""
            var loginSessionId: UUID?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "sid3@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                loginSessionId = decodedToken.sessionId
            })

            try await app.testing().test(.GET, "get-session-id", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body == loginSessionId!.uuidString)
            })
        }
    }

    @Test
    func `browser session stores and retrieves sessionId`() async throws {
        var configureWithSessions: (@Sendable (Application) async throws -> Void)?
        configureWithSessions = { app in
            await app.jwt.keys.add(
                hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
                digestAlgorithm: .sha256,
                kid: JWKIdentifier(string: "test-key")
            )

            app.middleware.use(app.sessions.middleware)

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
                )
            )

            try await app.passage.configure(services: services, configuration: configuration)

            app.get("get-session-id") { req -> String in
                if let sessionId = req.passage.sessionId {
                    return sessionId.uuidString
                }
                return "no-session-id"
            }
        }

        try await withApp(configure: configureWithSessions!) { app in
            try await createTestUser(app: app, email: "sid4@test.com")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "sid4@test.com", "password": "password123"])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }
}
