import Foundation
import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration))
struct `Session Revocation Integration Tests` {

    final class SessionRevocationSpy: @unchecked Sendable {
        var sessionRevokedCalls: [(UUID, Int)] = []

        func makeAccountHook() -> any Passage.Hooks.Account {
            _AccountHooksClosures.hook(
                isSessionRevoked: { [self] sessionId, _ in
                    self.sessionRevokedCalls.append((sessionId, self.sessionRevokedCalls.count))
                    return self.shouldRevoke(sessionId)
                }
            )
        }

        private var revokedSessions: Set<UUID> = []

        func revoke(_ sessionId: UUID) {
            revokedSessions.insert(sessionId)
        }

        func shouldRevoke(_ sessionId: UUID) -> Bool {
            revokedSessions.contains(sessionId)
        }
    }

    @Sendable private func configure(
        _ app: Application,
        hooks: Passage.Hooks = .init()
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
            configuration: configuration,
            hooks: hooks
        )

        let protected = app.grouped(PassageBearerAuthenticator())
        protected.get("protected-route") { req -> String in
            if let user = req.auth.get(Passage.OnlyForTest.InMemoryUser.self) {
                return "authorized:\(user.id ?? "no-id")"
            }
            return "not-authorized"
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
    func `bearer token with revoked sessionId returns 401`() async throws {
        let spy = SessionRevocationSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            _ = try await createTestUser(app: app, email: "revoked1@test.com")

            var accessToken: String = ""
            var sessionId: UUID?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "revoked1@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                sessionId = decodedToken.sessionId
            })

            spy.revoke(sessionId!)

            try await app.testing().test(.GET, "protected-route", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })

            #expect(spy.sessionRevokedCalls.count >= 1)
            #expect(spy.sessionRevokedCalls[0].0 == sessionId!)
        }
    }

    @Test
    func `bearer token with active sessionId returns 200`() async throws {
        let spy = SessionRevocationSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            _ = try await createTestUser(app: app, email: "revoked2@test.com")

            var accessToken: String = ""
            var sessionId: UUID?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "revoked2@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                sessionId = decodedToken.sessionId
            })

            try await app.testing().test(.GET, "protected-route", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let body = String(buffer: res.body)
                #expect(body.contains("authorized:"))
            })

            #expect(spy.sessionRevokedCalls.count >= 1)
            #expect(spy.sessionRevokedCalls[0].0 == sessionId!)
        }
    }

}
