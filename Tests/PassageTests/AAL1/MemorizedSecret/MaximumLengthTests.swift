import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import XCTQueues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 maximum-length permissiveness
//
// SP 800-63B §5.1.1.2-b: Verifiers SHOULD permit subscriber-chosen memorized
// secrets at least 64 characters in length. Passphrase-style secrets and
// password-manager output routinely exceed short upper bounds, so this
// clause blocks the common anti-pattern of a 20-character cap.

@Suite("AAL1 memorized secret maximum length", .tags(.aal1, .memorizedSecret))
struct MaximumLengthTests {

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
        "§5.1.1.2-b: Verifier permits subscriber-chosen memorized secret of at least 64 characters",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .should)
    )
    func verifierPermits64CharPassword() async throws {
        // Exactly 64 characters, ASCII — satisfies the §5.1.1.2-b floor and
        // fits inside Bcrypt's 72-byte input window so the verifier can hash
        // it without silent truncation (the separate §5.1.1.2-e concern).
        let sixtyFourCharPassword = String(repeating: "a", count: 64)
        #expect(sixtyFourCharPassword.count == 64)

        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "longpassphrase",
                    "password": sixtyFourCharPassword,
                    "confirmPassword": sixtyFourCharPassword
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok,
                        "verifier must accept a 64-char memorized secret to satisfy §5.1.1.2-b")

                let store = app.passage.storage.services.store
                let user = try await store.users.find(byIdentifier: .username("longpassphrase"))
                #expect(user != nil, "user must be persisted when password meets AAL1 §5.1.1.2-b")
            })

            // And it must still authenticate — an upper-length cap would
            // typically manifest as a silent truncation that lets login
            // succeed with a shorter prefix. Full-string login proves the
            // verifier is treating all 64 characters as significant.
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "longpassphrase",
                    "password": sixtyFourCharPassword
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "login with the full 64-char secret must succeed")
            })
        }
    }
}
