import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import JWT
import Queues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 no unauthenticated password hint
//
// SP 800-63B §5.1.1.2-j: Memorized secret verifiers SHALL NOT permit the
// subscriber to store a "hint" that is accessible to an unauthenticated
// claimant. The simplest structural enforcement is for Passage to expose
// *no* password-hint surface at all — no storage, no route, no field on
// the user protocol. The test probes the public route table for any
// hint-adjacent endpoint reachable without authentication.

@Suite(.tags(.aal1, .memorizedSecret))
struct `AAL1 no password hint surface` {

    @Sendable private func configure(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

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

    @Test(.tags(.aal1, .memorizedSecret, .authenticator, .integration, .shallNot))
    func `§5.1.1.2-j: No unauthenticated password-hint endpoint exists`() async throws {
        try await withApp(configure: configure) { app in
            // Two common hint URL shapes. Neither must be registered —
            // the lookup must 404, not 200/401/403 (200 would return a
            // hint, 401/403 would imply the route exists but is gated).
            for path in ["auth/password/hint", "auth/hint"] {
                try await app.testing().test(
                    .GET,
                    "\(path)?username=anybody",
                    afterResponse: { res async in
                        #expect(res.status == .notFound,
                                "\(path) must not be a known route — §5.1.1.2-j forbids an unauthenticated hint surface")
                    }
                )
            }

            // And a POST — a well-meaning developer might ship the hint
            // setter even if the reader is missing. Neither endpoint may
            // exist.
            try await app.testing().test(
                .POST,
                "auth/password/hint",
                beforeRequest: { req in
                    try req.content.encode(["hint": "my dog's name"])
                },
                afterResponse: { res async in
                    #expect(res.status == .notFound,
                            "setting a password hint must not be a registered route")
                }
            )
        }
    }
}
