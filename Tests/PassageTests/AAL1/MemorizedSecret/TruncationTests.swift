import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import JWT
import Queues
import XCTQueues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 no-truncation of memorized secret
//
// SP 800-63B §5.1.1.2-e: Truncation of the secret SHALL NOT be performed.
//
// The canonical regression is Bcrypt's silent 72-byte cap — if a verifier
// passes a >72-byte password directly to Bcrypt, every byte past position 72
// is ignored and authentication succeeds against any prefix that matches the
// first 72 bytes. The test registers with a 73-byte password and tries to log
// in with the 72-byte prefix: if login succeeds, the verifier is truncating.

@Suite(.tags(.aal1, .memorizedSecret))
struct `AAL1 memorized secret truncation` {

    @Sendable private func configure(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )
        app.queues.use(.asyncTest)

        app.passwords.use(.bcrypt(
            pepper: SymmetricKey(data: Data("aal1-test-pepper-do-not-use-in-prod".utf8))
        ))

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
    func `§5.1.1.2-e: Verifier SHALL NOT accept a truncated prefix of a registered memorized secret`() async throws {
        // 73 ASCII characters — one byte past Bcrypt's silent-truncation
        // boundary. The 72-char prefix differs from the full string only by
        // the trailing "Z", so if the verifier honours the full string the
        // prefix MUST be rejected.
        let full = String(repeating: "a", count: 72) + "Z"
        let prefix = String(full.prefix(72))
        #expect(full.count == 73)
        #expect(prefix.count == 72)
        #expect(full != prefix)

        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "no-truncation",
                    "password": full,
                    "confirmPassword": full
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "registration with a 73-byte password must succeed (§5.1.1.2-b already permits ≥64)")
            })

            // Attempt login with the 72-byte prefix — if the verifier is
            // truncating at 72 bytes, this will succeed; §5.1.1.2-e says
            // it MUST NOT.
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "no-truncation",
                    "password": prefix
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized,
                        "login with a 72-byte prefix must fail — truncation violates §5.1.1.2-e")
            })
        }
    }
}
