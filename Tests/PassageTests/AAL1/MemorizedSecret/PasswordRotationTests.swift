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

// MARK: - AAL1 no arbitrary password rotation
//
// SP 800-63B §5.1.1.2-s: Verifiers SHOULD NOT require memorized secrets to be
// changed arbitrarily (e.g., periodically). Passage enforces this
// structurally by not exposing a password-age / rotation-interval knob on
// the PasswordPolicy — Mirror-reflecting the policy is a compile-agnostic
// way to assert no such field has crept in.

@Suite(.tags(.aal1, .memorizedSecret))
struct `AAL1 no arbitrary password rotation` {

    @Test(.tags(.aal1, .memorizedSecret, .authenticator, .unit, .should))
    func `§5.1.1.2-s: PasswordPolicy exposes no password-age / rotation-interval field`() async throws {
        // Reflect the default policy and assert no field name hints at a
        // time-based rotation requirement. Using Mirror keeps the test
        // honest if the API shape changes — any future `expirationInterval`,
        // `maxAge`, or `rotationPeriod` addition will trip the assertion.
        let policy = Passage.Configuration.PasswordPolicy.relaxed()
        let mirror = Mirror(reflecting: policy)

        let forbiddenSubstrings = ["age", "rotation", "expir", "lifetime"]
        for child in mirror.children {
            let label = child.label?.lowercased() ?? ""
            for forbidden in forbiddenSubstrings {
                #expect(!label.contains(forbidden),
                        "PasswordPolicy.\(label) hints at arbitrary rotation — §5.1.1.2-s SHOULD NOT impose one")
            }
        }

        // Positive anchor: the fields we *do* expect exist, so the Mirror
        // walk itself is non-vacuous. If the struct is gutted and every
        // child disappears, the forbidden loop becomes a false negative —
        // this anchor catches that.
        let labels = Set(mirror.children.compactMap { $0.label })
        #expect(labels.contains("minLength"),
                "PasswordPolicy must still expose minLength (anchor for the mirror walk)")
    }

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

    @Test(.tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall))
    func `§5.1.1.2-t: Store admin-rotating the password invalidates the old secret and accepts the new one`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "compromised-user",
                    "password": "original-secret",
                    "confirmPassword": "original-secret"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Evidence of compromise arrives — the authenticator SHALL be
            // forced to change. This path is the admin/server-side: the
            // store rotates the hash out-of-band and revokes any live
            // refresh tokens (see Passage.Store.users.setPassword and
            // tokens.revokeRefreshToken — the primitives that make forced
            // rotation possible).
            let store = app.passage.storage.services.store
            let user = try #require(try await store.users.find(byIdentifier: .username("compromised-user")))
            let newHash = try Bcrypt.hash("post-compromise-secret")
            try await store.users.setPassword(for: user, passwordHash: newHash)
            try await store.tokens.revokeRefreshTokens(for: user)

            // Old password SHALL no longer authenticate.
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "compromised-user",
                    "password": "original-secret"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized,
                        "old secret must stop working after forced rotation per §5.1.1.2-t")
            })

            // New password SHALL authenticate.
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "compromised-user",
                    "password": "post-compromise-secret"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "newly-set secret must authenticate after forced rotation")
            })
        }
    }
}
