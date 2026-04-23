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

// MARK: - AAL1 Unicode normalization
//
// SP 800-63B §5.1.1.2-g: If Unicode characters are accepted in memorized
// secrets, the verifier SHOULD apply the Normalization Process for Stabilized
// Strings using either NFKC or NFKD (UAX 15) before hashing. Without
// normalization a user who types the same password on two different keyboards
// — one producing NFC, the other NFD — cannot log in interchangeably.

@Suite(.tags(.aal1, .memorizedSecret))
struct `AAL1 Unicode normalization` {

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
    func `§5.1.1.2-g: Password registered in NFD form authenticates when submitted in NFC form`() async throws {
        // "café1234" in NFD (8 graphemes, 9 scalars — 'cafe' + combining
        // acute + "1234") vs NFC (8 scalars where 'é' is a single scalar).
        let nfd = "cafe\u{0301}1234"
        let nfc = "caf\u{00E9}1234"
        #expect(nfd.precomposedStringWithCanonicalMapping == nfc,
                "precondition: the two strings are canonical equivalents")
        // Swift's `String ==` compares under Unicode canonical equivalence, so
        // the NFD and NFC forms compare equal. Drop to UTF-8 bytes to assert
        // the encodings actually differ — that is what the verifier would see
        // if it hashed the raw input without normalizing first.
        #expect(Array(nfd.utf8) != Array(nfc.utf8),
                "precondition: byte encodings differ prior to normalization")

        try await withApp(configure: configure) { app in
            // Register with the NFD form.
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "normalize-user",
                    "password": nfd,
                    "confirmPassword": nfd
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Log in with the canonically-equivalent NFC form. Without
            // NFKC/NFKD normalization before hashing, Bcrypt treats the two
            // byte sequences as different passwords and login fails.
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "normalize-user",
                    "password": nfc
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "NFC/NFD equivalence must be preserved through the verifier per §5.1.1.2-g")
            })
        }
    }
}
