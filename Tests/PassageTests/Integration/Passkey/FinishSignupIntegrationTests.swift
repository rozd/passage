import JWT
import NIOFoundationCompat
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

/// End-to-end coverage of `POST /auth/passkey/signup/finish` — the second
/// leg of the registration ceremony. Pairs with `BeginSignupIntegrationTests`.
///
/// The tests seed a challenge via the store (mimicking what `POST begin`
/// would persist), then POST a finish body and assert the expected orchestration:
/// service is called with the raw body, the `lookupChallenge` closure finds
/// the seeded challenge, the verified credential is persisted, and the
/// challenge is consumed (one-shot).
///
/// The mock `PasskeyService` bypasses cryptographic verification — real
/// swift-webauthn verification is covered by `passage-webauthn`'s own tests
/// and by end-to-end browser flows, not here.
@Suite(.tags(.integration, .passkey))
struct `Passkey Finish Signup Integration Tests` {

    // MARK: - Fixtures

    /// The challenge bytes the mock service "extracts" from the posted body
    /// and the mock store is seeded with under the matching hash.
    private static let sharedChallengeBytes = Data([0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8])

    /// Minimal finish body — real WebAuthn posts have much more, but the
    /// mock doesn't parse the content, it just receives Data.
    private static let minimalFinishBody = #"{"id":"any","type":"public-key","rawId":"any","response":{"clientDataJSON":"","attestationObject":"","transports":["internal"]}}"#

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
        seedValidChallenge: Bool = true,
        seedConsumedChallenge: Bool = false,
        seedExistingCredential: Bool = false
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

        // Seed a user + challenge so the finish handler has something to
        // resolve. The mock `lookupChallenge` closure will match on the raw
        // bytes the mock "extracts" from the body.
        if seedValidChallenge || seedConsumedChallenge {
            let user = try await store.users.create(
                identifier: .email("alice@example.com"),
                with: nil
            )
            holder.seededUser = user

            guard let challenges = store.passkeyChallenges else {
                Issue.record("InMemoryStore.passkeyChallenges was nil")
                return
            }

            let expiresAt = seedConsumedChallenge
                ? Date().addingTimeInterval(-1)  // short-circuit validity
                : Date().addingTimeInterval(300)

            let stored = try await challenges.createPasskeyChallenge(
                for: user,
                from: PasskeyChallenge(
                    bytes: Self.sharedChallengeBytes,
                    kind: .registration,
                    expiresAt: expiresAt
                )
            )
            if seedConsumedChallenge {
                try await challenges.consume(passkeyChallenge: stored)
            }
        }

        if seedExistingCredential {
            guard
                let user = holder.seededUser,
                let credentials = store.passkeyCredentials
            else {
                Issue.record("missing prerequisites for existing credential seed")
                return
            }
            _ = try await credentials.createPasskeyCredential(
                for: user,
                from: PasskeyCredential(
                    credentialID: "credential-id-mock",
                    publicKey: Data(),
                    signCount: 0,
                    uvInitialized: false,
                    transports: [],
                    backupEligible: false,
                    isBackedUp: false,
                    aaguid: nil,
                    attestationFormat: nil
                )
            )
        }
    }

    // MARK: - Happy path

    @Test
    func `POST finish returns 201 with credentialID JSON`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .created)
                let json = try #require(
                    try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
                )
                #expect(json["credentialID"] as? String == "credential-id-mock")
            }
        }
    }

    @Test
    func `POST finish persists the credential for the matched user`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .created)
            }

            let credentials = try #require(holder.store?.passkeyCredentials)
            let stored = try await credentials.find(byCredentialID: "credential-id-mock")
            let credential = try #require(stored)
            #expect(credential.credentialID == "credential-id-mock")
            #expect(credential.publicKey == Data([0x30, 0x59, 0x30, 0x13]))
        }
    }

    @Test
    func `POST finish consumes the matched challenge (one-shot)`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .created)
            }

            let challenges = try #require(holder.store?.passkeyChallenges)
            let stored = try await challenges.find(
                passkeyChallengeMatching: Self.sharedChallengeBytes
            )
            let after = try #require(stored)
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
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .created)
            }

            let finishCalls = try #require(holder.service?.finishCalls)
            #expect(finishCalls.count == 1)
            let received = String(data: finishCalls[0].rawBody, encoding: .utf8)
            #expect(received == Self.minimalFinishBody)
        }
    }

    // MARK: - Challenge resolution failures (HTTP 401)

    @Test
    func `POST finish returns 401 when no challenge is stored for the bytes`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, seedValidChallenge: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/finish",
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
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test
    func `POST finish returns 401 when the credential ID is already registered`() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, seedExistingCredential: true)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                // Mock throws invalidPasskeyChallenge when confirmUnused returns
                // false. Real swift-webauthn raises a different error; the HTTP
                // code is the one documented on AuthenticationError.
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
                .POST, "/auth/passkey/signup/finish",
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
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                // Without passkey config, routes aren't registered.
                #expect(res.status == .notFound)
            }
        }
    }

    @Test
    func `POST finish propagates service-level errors`() async throws {
        struct BoomError: AbortError {
            var status: HTTPResponseStatus { .internalServerError }
            var reason: String { "boom" }
        }

        let holder = Holder()
        try await withApp(configure: { app in
            let service = MockPasskeyService(finishError: BoomError())
            try await self.configure(app, holder: holder, passkeyService: service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .internalServerError)
            }
        }
    }

    // MARK: - Route registration gating

    @Test
    func `Finish route honors custom signupFinish path override`() async throws {
        // Using the default configure method but with a slightly different
        // route path. We inline the whole config here to isolate the
        // customization.
        let holder = Holder()
        let customRoutes = Passage.Configuration.Passkey.Routes(
            signupFinish: .init(path: "done")
        )
        try await withApp(configure: { app in
            await app.jwt.keys.add(
                hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
                digestAlgorithm: .sha256,
                kid: JWKIdentifier(string: "test-key")
            )
            let store = Passage.OnlyForTest.InMemoryStore()
            holder.store = store
            let service = MockPasskeyService()
            holder.service = service

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
                passkey: .init(
                    routes: customRoutes
                )
            )
            try await app.passage.configure(services: services, configuration: configuration)

            // Seed a valid challenge under the custom configuration.
            let user = try await store.users.create(
                identifier: .email("alice@example.com"), with: nil
            )
            let challenges = try #require(store.passkeyChallenges)
            _ = try await challenges.createPasskeyChallenge(
                for: user,
                from: PasskeyChallenge(
                    bytes: Self.sharedChallengeBytes,
                    kind: .registration,
                    expiresAt: Date().addingTimeInterval(300)
                )
            )
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .notFound)
            }
            try await app.testing().test(
                .POST, "/auth/passkey/done",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalFinishBody)
            ) { res in
                #expect(res.status == .created)
            }
        }
    }
}
