import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

/// End-to-end coverage of `POST /auth/passkey/register/finish` — the
/// authenticated leg that persists a passkey credential for an already
/// signed-in user. Pairs with `BeginRegistrationIntegrationTests`.
///
/// The defense-in-depth check verifies that the session user at `finish` time
/// matches the user the challenge was issued to at `begin` time; a mismatch
/// is surfaced as `invalidPasskeyChallenge` (401) rather than being silently
/// attributed to the wrong account.
@Suite("Passkey Finish Registration (authenticated) Integration Tests", .tags(.integration, .passkey))
struct FinishRegistrationIntegrationTests {

    private static let minimalFinishBody = #"{"id":"any","type":"public-key","rawId":"any","response":{"clientDataJSON":"","attestationObject":"","transports":["internal"]}}"#

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

    @Sendable private func createUserAndLogin(
        app: Application,
        email: String,
        password: String = "password123"
    ) async throws -> (user: any User, token: String) {
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
        return (user, accessToken)
    }

    // MARK: - Authentication gating

    @Test("POST finish returns 401 when the request carries no auth")
    func unauthenticatedReturns401() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/register/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    // MARK: - Happy path

    @Test("POST finish with matching session persists a credential bound to the session user")
    func finishPersistsCredentialForSessionUser() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            let (user, token) = try await self.createUserAndLogin(app: app, email: "alice@example.com")

            try await app.testing().test(
                .POST, "/auth/passkey/register/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
            }

            try await app.testing().test(
                .POST, "/auth/passkey/register/finish",
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .created)
            }

            let credentials = try #require(holder.store?.passkeyCredentials)
            let stored = try await credentials.find(byCredentialID: "credential-id-mock")
            let credential = try #require(stored)
            let credentialUserId = try credential.user.requiredIdAsString
            let sessionUserId = try user.requiredIdAsString
            #expect(credentialUserId == sessionUserId)
        }
    }

    // MARK: - User-mismatch rejection

    @Test("POST finish returns 401 when a different authenticated user completes the ceremony")
    func crossUserFinishIsRejected() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            let (_, aliceToken) = try await self.createUserAndLogin(app: app, email: "alice@example.com")
            let (_, bobToken) = try await self.createUserAndLogin(app: app, email: "bob@example.com")

            try await app.testing().test(
                .POST, "/auth/passkey/register/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(aliceToken)"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
            }

            // Bob tries to complete the ceremony Alice started.
            try await app.testing().test(
                .POST, "/auth/passkey/register/finish",
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(bobToken)"
                ],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .unauthorized)
            }

            // And no credential should be persisted — the challenge is still
            // pending until the legitimate user finishes it.
            let credentials = try #require(holder.store?.passkeyCredentials)
            let after = try await credentials.find(byCredentialID: "credential-id-mock")
            #expect(after == nil)
        }
    }
}
