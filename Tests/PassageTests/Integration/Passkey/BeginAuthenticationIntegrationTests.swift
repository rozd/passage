import Testing
import Foundation
import Vapor
import VaporTesting
import JWTKit
@testable import Passage
@testable import PassageOnlyForTest

/// End-to-end coverage of `POST /auth/passkey/authenticate/begin` —
/// the first leg of the authentication ceremony. Discoverable-only flow:
/// the endpoint accepts no body (empty `{}` from the browser is fine),
/// always forwards `allowCredentials: nil` to the service, and persists
/// a kind=.authentication challenge with `user == nil`.
@Suite("Passkey Begin Authentication Integration Tests", .tags(.integration, .passkey))
struct BeginAuthenticationIntegrationTests {

    // MARK: - Fixtures

    final class Holder: @unchecked Sendable {
        var service: MockPasskeyService?
        var store: Passage.OnlyForTest.InMemoryStore?
    }

    @Sendable private func configure(
        _ app: Application,
        holder: Holder,
        passkeyService: (any Passage.PasskeyService)? = nil,
        includePasskeyConfig: Bool = true,
        allowDiscoverableLogin: Bool = true
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
            passkey: .init(
                policy: .init(allowDiscoverableLogin: allowDiscoverableLogin)
            )
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    // MARK: - Happy path

    @Test("POST begin returns 200 JSON with a base64url challenge")
    func beginReturns200JSON() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authenticate/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
                let json = try #require(
                    try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
                )
                let challenge = try #require(json["challenge"] as? String)
                #expect(!challenge.isEmpty)
                #expect(!challenge.contains("="))
                #expect(json["rpId"] as? String == "example.com")
            }
        }
    }

    @Test("Service receives allowCredentials=nil (discoverable flow)")
    func serviceReceivesNilAllowCredentials() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authenticate/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
                let calls = try #require(holder.service?.beginAuthenticationCalls)
                #expect(calls.count == 1)
                #expect(calls.first?.allowCredentials == nil)
            }
        }
    }

    @Test("Challenge is persisted with kind=.authentication and user=nil")
    func challengeIsPersistedAsAuthentication() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authenticate/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
                let challenges = try #require(holder.store?.passkeyChallenges)
                let stored = try #require(
                    try await challenges.find(passkeyChallengeMatching: MockPasskeyService.sharedChallengeBytes)
                )
                #expect(stored.kind == .authentication)
                #expect(stored.user == nil)
                #expect(stored.isValid == true)
            }
        }
    }

    @Test("POST begin accepts an empty body (no content-type)")
    func beginAcceptsEmptyBody() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authenticate/begin"
            ) { res in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - Policy gating

    @Test("POST begin returns 400 when allowDiscoverableLogin is false")
    func discoverableDisabledReturns400() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, allowDiscoverableLogin: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authenticate/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .badRequest)
            }
        }
    }

    // MARK: - Configuration / service gating

    @Test("POST begin returns 404 when passkey config is absent")
    func passkeyConfigAbsentReturns404() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, includePasskeyConfig: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authenticate/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("POST begin returns 404 when passkey service is nil (routes not registered)")
    func serviceNilReturns404() async throws {
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
                .POST, "/auth/passkey/authenticate/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("POST begin propagates service-level errors verbatim")
    func beginPropagatesServiceError() async throws {
        struct BoomError: AbortError {
            var status: HTTPResponseStatus { .internalServerError }
            var reason: String { "boom" }
        }

        let holder = Holder()
        try await withApp(configure: { app in
            let service = MockPasskeyService(beginAuthenticationError: BoomError())
            try await self.configure(app, holder: holder, passkeyService: service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authenticate/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .internalServerError)
            }
        }
    }
}
