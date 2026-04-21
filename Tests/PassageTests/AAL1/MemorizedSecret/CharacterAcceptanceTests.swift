import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import XCTQueues
@testable import Passage
@testable import PassageOnlyForTest
import JWT
import Queues

// MARK: - AAL1 character-set acceptance
//
// SP 800-63B §5.1.1.2-c/-d require verifiers to accept the full printable
// ASCII range (with space), and Unicode code points. Passage's policy MUST
// NOT filter by character class — only length and blocklist membership are
// grounds for rejection.

@Suite(.tags(.aal1, .memorizedSecret))
struct `AAL1 memorized secret character acceptance` {

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

    @Test(.tags(.aal1, .memorizedSecret, .authenticator, .integration, .should))
    func `§5.1.1.2-c: Verifier accepts a password containing printable ASCII characters and a space`() async throws {
        // A 16-character password drawn from punctuation, digits, letters,
        // and a space — one sample per "printable ASCII class". If any class
        // were rejected, registration would return 400.
        let password = "Ab1 !@#$%^&*()_+"
        #expect(password.count == 16)

        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "ascii-and-space",
                    "password": password,
                    "confirmPassword": password
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok,
                        "printable ASCII + space must be accepted per §5.1.1.2-c")
            })

            // And it must still authenticate — if any character were silently
            // stripped or re-encoded, a full-string login would fail.
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "ascii-and-space",
                    "password": password
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "login with the same ASCII+space secret must round-trip")
            })
        }
    }

    @Test(.tags(.aal1, .memorizedSecret, .authenticator, .integration, .should))
    func `§5.1.1.2-d: Verifier accepts a password containing Unicode characters`() async throws {
        // Mix Latin, Cyrillic, CJK, and a supplementary-plane emoji to
        // cover BMP + non-BMP. Any verifier that rejected non-ASCII would
        // fail on at least one of these.
        let password = "Pässwörd-пароль-密码-🔐"

        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "unicode-user",
                    "password": password,
                    "confirmPassword": password
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "Unicode memorized secrets must be accepted per §5.1.1.2-d")
            })

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "unicode-user",
                    "password": password
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "Unicode login must round-trip the full byte sequence")
            })
        }
    }
}
