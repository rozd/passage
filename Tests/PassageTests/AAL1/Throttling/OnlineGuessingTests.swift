import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import XCTQueues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 online guessing protection
//
// SP 800-63B §5.2.2-a: The verifier SHALL implement controls to protect
// against online guessing attacks. §5.1.1.2-q covers per-account rate
// limiting; §5.2.2-a is the broader counterpart — guessing a *list* of
// usernames from the same source must also be throttled, otherwise an
// attacker bypasses per-account caps by spreading requests across many
// accounts.

@Suite("AAL1 online guessing protection", .tags(.aal1, .throttling))
struct OnlineGuessingTests {

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

    @Test(
        "§5.2.2-a: Login endpoint throttles online-guessing spray attacks across many accounts",
        .tags(.aal1, .throttling, .authenticator, .integration, .shall)
    )
    func loginThrottlesSprayAttacks() async throws {
        try await withApp(configure: configure) { app in
            // Fire 100 failed login attempts against different usernames —
            // a credential-stuffing / username-spray pattern. §5.2.2-a
            // requires the verifier to implement *some* control against
            // online guessing; an effective control returns a
            // throttling status (429 Too Many Requests or 403 Forbidden
            // with a lockout reason) before the run completes.
            var throttled = false
            for i in 0..<100 {
                try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                    try req.content.encode([
                        "username": "spray-target-\(i)",
                        "password": "guess"
                    ])
                }, afterResponse: { res async in
                    if res.status == .tooManyRequests || res.status == .locked || res.status == .forbidden {
                        throttled = true
                    }
                })
                if throttled { break }
            }

            #expect(throttled,
                    "spray attack must be throttled by at least one guessing-protection control per §5.2.2-a")
        }
    }
}
