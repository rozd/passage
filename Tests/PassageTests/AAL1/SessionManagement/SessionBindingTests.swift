import Foundation
import Testing
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 session-binding secret properties
//
// SP 800-63B §7.1 defines the properties a session-binding secret must have.
// Passage issues an opaque refresh token at authentication time: the plain
// text is returned to the subscriber, the SHA-256 hash is persisted server-
// side, and subsequent rotations require the client to present the plain-text
// token (which the server hashes and compares). That mechanism is the
// shared-secret / cryptographic-proof substrate these clauses require.

@Suite("AAL1 session binding", .tags(.aal1, .sessionManagement))
struct SessionBindingTests {

    @Test(
        "§7.1-a: A session secret is shared between the subscriber and the service",
        .tags(.aal1, .sessionManagement, .authenticator, .unit, .shall)
    )
    func sessionSecretIsSharedBetweenSubscriberAndService() async throws {
        // Passage's session-binding secret is the opaque refresh token. The
        // subscriber holds the plain text; the service holds the SHA-256
        // hash. §7.1-a is satisfied structurally iff the plain-text value
        // the subscriber holds hashes to the value the service persisted —
        // i.e. both sides are tied to the same underlying bits.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("shared-secret"),
            with: .password("$2b$12$hash")
        )

        // Service-side: mint + persist the hash (exactly what tokens.issue does).
        let subscriberSecret = random.generateOpaqueToken()
        let persistedHash = random.hashOpaqueToken(token: subscriberSecret)
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: persistedHash,
            expiresAt: Date().addingTimeInterval(3600)
        )

        // Service-side: look up by the secret the subscriber would present.
        let recovered = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: subscriberSecret)
        )
        try #require(recovered != nil,
                     "§7.1-a: service must be able to recognise the subscriber's secret")

        // A different secret (not shared) must not unlock the session.
        let impostorSecret = random.generateOpaqueToken()
        let imposter = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: impostorSecret)
        )
        #expect(imposter == nil,
                "§7.1-a: only the shared secret may resolve to a session — impostor secrets must not")
    }
}
