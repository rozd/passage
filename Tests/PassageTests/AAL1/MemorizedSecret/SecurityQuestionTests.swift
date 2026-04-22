import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import JWT
import Queues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 no knowledge-based-authentication prompts
//
// SP 800-63B §5.1.1.2-k: Verifiers SHALL NOT prompt subscribers to use
// specific types of information (e.g., "What was the name of your first
// pet?") when choosing memorized secrets. Passage enforces this
// structurally by not registering any KBA route.

@Suite(.tags(.aal1, .memorizedSecret), .primeNIOSingletons)
struct `AAL1 no security-question surface` {

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
    func `§5.1.1.2-k: No security-question / KBA route is registered`() async throws {
        try await withApp(configure: configure) { app in
            // Three canonical KBA URL shapes. If any responds with a
            // non-404 status, a security-question surface has sneaked in.
            for path in [
                "auth/security-questions",
                "auth/security-question",
                "auth/kba"
            ] {
                try await app.testing().test(
                    .GET,
                    path,
                    afterResponse: { res async in
                        #expect(res.status == .notFound,
                                "\(path) must not be a registered route — §5.1.1.2-k forbids KBA prompts for memorized-secret selection")
                    }
                )
            }
        }
    }
}
