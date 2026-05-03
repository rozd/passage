import JWT
import NIOFoundationCompat
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

/// End-to-end coverage of `POST /auth/passkey/authentication/finish`.
///
/// The tests seed a user + credential + authentication challenge directly in
/// the in-memory store (mimicking what `POST begin` + a prior
/// `POST register/finish` would persist), then POST a finish body and assert:
/// the service is called with the raw body, the `lookupChallenge` closure
/// finds the seeded challenge, the stored credential's sign-count is updated,
/// the challenge is consumed (one-shot), and the response carries an exchange
/// code.
@Suite(.tags(.integration, .passkey))
struct `Passkey Finish Authentication Integration Tests` {

    // MARK: - Fixtures

    /// Matches `MockPasskeyService` defaults so begin+finish wire up cleanly.
    private static let sharedChallengeBytes = MockPasskeyService.sharedChallengeBytes
    private static let sharedCredentialID = "credential-id-mock"

    /// Any JSON — the mock doesn't inspect it, only the integration boundary
    /// with WebAuthn cares about the shape.
    private static let minimalFinishBody = #"{"id":"credential-id-mock","rawId":"credential-id-mock","type":"public-key","response":{"clientDataJSON":"","authenticatorData":"","signature":""}}"#

    final class Holder: @unchecked Sendable {
        var service: MockPasskeyService?
        var store: Passage.OnlyForTest.InMemoryStore?
        var seededUser: (any User)?
    }

    @Sendable private func configure(
        _ app: Application,
        holder: Holder,
        passkeyService: (any Passage.PasskeyService)? = nil,
        includePasskeyConfig: Bool = true,
        seedChallenge: Bool = true,
        seedConsumedChallenge: Bool = false,
        seedChallengeKind: PasskeyChallengeKind = .authentication,
        seedCredential: Bool = true
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
            passkey: includePasskeyConfig ? service : nil
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

        // Seed the user + credential + challenge that the orchestration will
        // look up. Mirrors what the registration + begin-auth ceremonies
        // would have already persisted.
        let user = try await store.users.create(
            identifier: .email("alice@example.com"),
            with: nil
        )
        holder.seededUser = user

        if seedCredential, let credentials = store.passkeyCredentials {
            _ = try await credentials.createPasskeyCredential(
                for: user,
                from: PasskeyCredential(
                    credentialID: Self.sharedCredentialID,
                    publicKey: Data([0x04, 0xDE, 0xAD]),
                    signCount: 0,
                    uvInitialized: false,
                    transports: [.internal],
                    backupEligible: false,
                    isBackedUp: false,
                    aaguid: nil,
                    attestationFormat: nil
                )
            )
        }

        if seedChallenge || seedConsumedChallenge, let challenges = store.passkeyChallenges {
            let expiresAt = seedConsumedChallenge
                ? Date().addingTimeInterval(-1)
                : Date().addingTimeInterval(300)
            let stored = try await challenges.createPasskeyChallenge(
                from: PasskeyChallenge(
                    bytes: Self.sharedChallengeBytes,
                    kind: seedChallengeKind,
                    expiresAt: expiresAt
                )
            )
            if seedConsumedChallenge {
                try await challenges.consume(passkeyChallenge: stored)
            }
        }
    }

    // MARK: - Happy path

    @Test
    func `POST finish returns 200 with exchange 'code' JSON`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .ok)
                let json = try #require(
                    try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
                )
                let code = try #require(json["code"] as? String)
                #expect(!code.isEmpty)
            }
        }
    }

    @Test
    func `POST finish updates the credential's signCount and backup flag`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            let service = MockPasskeyService(newSignCount: 7, credentialBackedUp: true)
            try await self.configure(app, holder: holder, passkeyService: service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .ok)
            }

            let credentials = try #require(holder.store?.passkeyCredentials)
            let updated = try #require(
                try await credentials.find(byCredentialID: Self.sharedCredentialID)
            )
            #expect(updated.signCount == 7)
            #expect(updated.isBackedUp == true)
        }
    }

    @Test
    func `POST finish consumes the matched challenge (one-shot)`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .ok)
            }

            let challenges = try #require(holder.store?.passkeyChallenges)
            let after = try #require(
                try await challenges.find(passkeyChallengeMatching: Self.sharedChallengeBytes)
            )
            #expect(after.isConsumed == true)
            #expect(after.isValid == false)
        }
    }

    @Test
    func `POST finish forwards the raw body to the service verbatim`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .ok)
            }

            let calls = try #require(holder.service?.finishAuthenticationCalls)
            #expect(calls.count == 1)
            let received = String(data: calls[0].rawBody, encoding: .utf8)
            #expect(received == Self.minimalFinishBody)
        }
    }

    // MARK: - Challenge resolution failures (HTTP 401)

    @Test
    func `POST finish returns 401 when no challenge is stored for the bytes`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, seedChallenge: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test
    func `POST finish returns 401 when the stored challenge is already consumed`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, seedConsumedChallenge: true)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test
    func `POST finish returns 401 when a registration challenge is replayed for authentication`() async throws {
        // Core's lookupChallenge closure requires kind == .authentication; a
        // registration-kind challenge with the same bytes must not unlock auth.
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, seedChallengeKind: .registration)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test
    func `POST finish returns 401 when the credential ID is not in the store`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, seedCredential: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    // MARK: - Service / configuration errors

    @Test
    func `POST finish returns 404 when passkey service is nil (routes not registered)`() async throws {
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
                emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
                phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
                federatedLogin: nil,
                passkey: nil
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
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test
    func `POST finish returns 404 when passkey config is absent`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, includePasskeyConfig: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test
    func `POST finish propagates service-level errors verbatim`() async throws {
        struct BoomError: AbortError {
            var status: HTTPResponseStatus { .internalServerError }
            var reason: String { "boom" }
        }
        let holder = Holder()
        try await withApp(configure: { app in
            let service = MockPasskeyService(finishAuthenticationError: BoomError())
            try await self.configure(app, holder: holder, passkeyService: service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .internalServerError)
            }
        }
    }
}
