import JWT
import NIOFoundationCompat
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

/// End-to-end coverage of `POST /auth/passkey/registration/begin` — the
/// authenticated "add a passkey to my existing account" flow. This is the
/// WebAuthn-spec-default way to onboard passkeys per FIDO/Apple/Google
/// guidance, and the trust model differs from signup: identity comes from
/// the bearer/session, not the request body.
///
/// The parallel public signup flow lives at `BeginSignupIntegrationTests`.
@Suite(.tags(.integration, .passkey))
struct `Passkey Begin Registration (authenticated) Integration Tests` {

    final class Holder: @unchecked Sendable {
        var service: MockPasskeyService?
        var store: Passage.OnlyForTest.InMemoryStore?
    }

    @Sendable private func configure(
        _ app: Application,
        holder: Holder,
        passkeyService: (any Passage.PasskeyService)? = nil
    ) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        holder.store = store

        let service = passkeyService ?? MockPasskeyService()
        holder.service = service as? MockPasskeyService

        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
            federatedLogin: nil,
            passkey: service
        )

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: #"{"keys":[]}"#)),
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
            passkey: .init()
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    /// Creates a user and returns a bearer JWT for them. Uses the live login
    /// endpoint so the token is issued by the same code path an app would
    /// trigger in production.
    @Sendable private func createUserAndLogin(
        app: Application,
        email: String = "alice@example.com",
        password: String = "password123"
    ) async throws -> String {
        let store = app.passage.storage.services.store
        let passwordHash = try await app.password.async.hash(password)
        let user = try await store.users.create(
            identifier: .email(email),
            with: .password(passwordHash)
        )
        try await store.users.markEmailVerified(for: user)

        var accessToken = ""
        try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
            try req.content.encode(["email": email, "password": password])
        }, afterResponse: { res async throws in
            #expect(res.status == .ok)
            let authUser = try res.content.decode(AuthUser.self)
            accessToken = authUser.accessToken
        })
        return accessToken
    }

    // MARK: - Authentication gating

    @Test
    func `POST begin returns 401 when the request carries no auth`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test
    func `POST begin returns 401 when the bearer token is invalid`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer not-a-real-jwt"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    // MARK: - Happy path

    @Test
    func `POST begin with valid bearer returns ceremony options`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            let token = try await self.createUserAndLogin(app: app)

            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: #"{"displayName":"Alice"}"#)
            ) { res in
                #expect(res.status == .ok)
                let json = try #require(
                    try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
                )
                let user = try #require(json["user"] as? [String: Any])
                #expect(user["displayName"] as? String == "Alice")
                #expect(user["name"] as? String == "alice@example.com")
            }
        }
    }

    @Test
    func `POST begin binds the stored challenge to the authenticated user`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            let token = try await self.createUserAndLogin(app: app)

            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
            }

            let challenges = try #require(holder.store?.passkeyChallenges)
            let stored = try await challenges.find(
                passkeyChallengeMatching: MockPasskeyService.sharedChallengeBytes
            )
            let challenge = try #require(stored)
            #expect(challenge.user != nil)
            #expect(challenge.kind == .registration)
        }
    }

    @Test
    func `POST begin falls back to user identifier when displayName is omitted`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            let token = try await self.createUserAndLogin(app: app, email: "bob@example.com")

            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
                let json = try #require(
                    try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
                )
                let user = try #require(json["user"] as? [String: Any])
                #expect(user["displayName"] as? String == "bob@example.com")
            }
        }
    }
}
