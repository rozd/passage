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

// MARK: - AAL1 Unicode code-point counting
//
// SP 800-63B §5.1.1.2-f: For purposes of the length requirements, each
// Unicode code point SHALL be counted as a single character.
//
// Swift's `String.count` counts extended grapheme clusters, not code points.
// `"e\u{0301}"` (NFD: 'e' + combining acute) is 1 grapheme cluster but 2 code
// points. A verifier that uses `String.count` to enforce the 8-character
// floor would reject a perfectly valid 8-code-point password whose clusters
// happen to combine — contrary to §5.1.1.2-f.

@Suite("AAL1 Unicode code-point counting", .tags(.aal1, .memorizedSecret))
struct UnicodeLengthTests {

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
        "§5.1.1.2-f: Length is measured in Unicode code points — combining sequences with 8 code points are accepted",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func lengthIsMeasuredInCodePoints() async throws {
        // Build "e\u{0301}" four times: 4 grapheme clusters, 8 Unicode
        // scalars. NIST counts this as 8 characters; Swift's
        // String.count reports 4. A compliant verifier MUST accept this as
        // meeting the 8-char minimum.
        let combining = "e\u{0301}"
        let password = String(repeating: combining, count: 4)
        #expect(password.unicodeScalars.count == 8,
                "precondition: 8 Unicode scalars (NIST code-point count)")
        #expect(password.count == 4,
                "precondition: 4 grapheme clusters (Swift String.count)")

        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "codepoint-length",
                    "password": password,
                    "confirmPassword": password
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "8-code-point password must be accepted per §5.1.1.2-f")
            })
        }
    }
}
