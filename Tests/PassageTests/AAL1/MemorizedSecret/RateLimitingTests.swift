import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import XCTQueues
import JWT
import Queues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 rate-limiting of failed authentication attempts
//
// SP 800-63B §5.1.1.2-q: Verifiers SHALL implement a rate-limiting mechanism
// that effectively limits the number of failed authentication attempts that
// can be made on the subscriber's account as described in §5.2.2.
//
// Passage does not throttle login today. This test asserts the behavioural
// invariant: a run of wrong-password submissions against the same identifier
// eventually starts being rejected without being passed to the verifier —
// either with HTTP 429 (Too Many Requests) or HTTP 423 (Locked). Until
// throttling ships, the test will fail with every attempt returning 401
// instead.

@Suite(.tags(.aal1, .memorizedSecret, .throttling))
struct `AAL1 memorized secret rate limiting` {

    @Sendable private func configure(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )
        app.queues.use(.asyncTest)

        let services = Passage.Services(
            store: Passage.OnlyForTest.InMemoryStore(),
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
            federatedLogin: nil
        )

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            jwt: .init(jwks: .init(json: "{\"keys\":[]}"))
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    @Test(.tags(.aal1, .memorizedSecret, .throttling, .authenticator, .integration, .shall))
    func `§5.1.1.2-q: Sustained failed login attempts against one account are rate-limited`() async throws {
        try await withApp(configure: configure) { app in
            // Register the victim account with a real password.
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "throttle-target",
                    "password": "the-real-password",
                    "confirmPassword": "the-real-password"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Guess loop — §5.2.2 caps attempts at 100, but an effective
            // rate-limiter will engage much sooner. Pump 50 attempts; the
            // tail of the sequence MUST include at least one non-401
            // throttle signal (429 Too Many Requests or 423 Locked).
            var throttled = false
            for i in 0..<50 {
                try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                    try req.content.encode([
                        "username": "throttle-target",
                        "password": "guess-\(i)"
                    ])
                }, afterResponse: { res async in
                    if res.status == .tooManyRequests || res.status == .locked {
                        throttled = true
                    }
                })
                if throttled { break }
            }

            #expect(throttled,
                    "sustained wrong-password attempts must eventually be throttled per §5.1.1.2-q")
        }
    }
}
