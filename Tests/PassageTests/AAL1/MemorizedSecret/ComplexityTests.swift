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

// MARK: - AAL1 no extra complexity requirements
//
// SP 800-63B §5.1.1.1-d: No other complexity requirements for memorized
// secrets SHOULD be imposed beyond the 8-character minimum — SP 800-63B
// Appendix A explicitly argues that mandatory mixed-case/digit/special-char
// rules harm usability without improving strength.

@Suite(.tags(.aal1, .memorizedSecret), .primeNIOSingletons)
struct `AAL1 no extra complexity requirements` {

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
    func `§5.1.1.1-d: Passwords meeting the length floor are accepted without extra complexity constraints`() async throws {
        try await withApp(configure: configure) { app in
            // 10 characters, all lowercase, no digits, no special chars. Per
            // §5.1.1.1-d this is the smallest counterexample that would be
            // rejected if the verifier imposed a mixed-case/digit/special
            // rule — so if this registration succeeds, no extra complexity
            // rule is in force.
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "plainlowercase",
                    "password": "abcdefghij",
                    "confirmPassword": "abcdefghij"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok,
                        "length-compliant lowercase-only password must not be rejected on complexity grounds")

                let store = app.passage.storage.services.store
                let user = try await store.users.find(byIdentifier: .username("plainlowercase"))
                #expect(user != nil, "user must be persisted when password meets AAL1 §5.1.1.1-d")
            })
        }
    }

    @Test(.tags(.aal1, .memorizedSecret, .authenticator, .integration, .should))
    func `§5.1.1.2-r: Verifier accepts a repeated-character password without prohibiting consecutive duplicates`() async throws {
        try await withApp(configure: configure) { app in
            // §5.1.1.2-r specifically calls out "prohibiting consecutively
            // repeated characters" as an anti-pattern. This 8-char
            // all-"a" password would be rejected by any composition rule
            // that tried to ban runs; it MUST be accepted on length alone.
            let password = "aaaaaaaa"
            #expect(password.count == 8)

            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "repeat-chars",
                    "password": password,
                    "confirmPassword": password
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "repeated-character password must be accepted per §5.1.1.2-r — no composition rule may ban runs")
            })
        }
    }
}
