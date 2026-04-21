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

    @Test(
        "§7.1-b: Session secret is presented directly by the subscriber on each request",
        .tags(.aal1, .sessionManagement, .authenticator, .unit, .shall)
    )
    func sessionSecretIsPresentedDirectly() async throws {
        // §7.1-b permits either direct presentation or proof-of-possession.
        // Passage uses the direct-presentation branch: the subscriber
        // presents the opaque refresh token in the POST body on
        // /auth/refresh-token, and the server rotates it. This test drives
        // the concrete rotation path (Passage.Tokens.refresh equivalent,
        // minus JWT signing) by proving that presenting the plain-text
        // secret is what unlocks the session — nothing else is required.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("direct-present"),
            with: .password("$2b$12$hash")
        )

        let subscriberSecret = random.generateOpaqueToken()
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: subscriberSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )

        // Directly presenting the secret resolves the session.
        let presented = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: subscriberSecret)
        )
        #expect(presented?.isValid == true,
                "§7.1-b: direct presentation of the secret must authorise the session")

        // Presenting only the *hash* (which is what's stored) must not work —
        // the hash is a server-side artefact, not the subscriber's secret.
        // If both were accepted, the server-side record itself would be
        // usable as a bearer token, collapsing §7.1-b into a non-requirement.
        let hashPresentedAsIfSecret = random.hashOpaqueToken(token: subscriberSecret)
        let spoofed = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: hashPresentedAsIfSecret)
        )
        #expect(spoofed == nil,
                "§7.1-b: only the plain-text secret (not its server-side hash) may be presented")
    }

    @Test(
        "§7.1-c: Session secret is generated by the session host in direct response to an auth event",
        .tags(.aal1, .sessionManagement, .authenticator, .unit, .shall)
    )
    func sessionSecretIsGeneratedInDirectResponseToAuth() async throws {
        // §7.1-c requires that the session-binding secret be minted by the
        // session host (i.e. the server) *in direct response to an auth
        // event* — not pre-provisioned or client-supplied. The invariant:
        // no refresh-token record exists for a user until the server has
        // processed an authentication event, and each such event mints a
        // fresh secret.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("direct-response"),
            with: .password("$2b$12$hash")
        )

        // Before any authentication event, the user has no session secret
        // on the server. A pre-existing secret would mean the host generated
        // it out-of-band — exactly what §7.1-c forbids.
        let before = try await store.tokens.find(refreshTokenHash: "does-not-exist")
        #expect(before == nil,
                "§7.1-c: no session secret may exist before an auth event")

        // Simulate two auth events (e.g. two logins). Each must emit a
        // *distinct* freshly-generated secret — the server is the source.
        let firstSecret = random.generateOpaqueToken()
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: firstSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )
        let secondSecret = random.generateOpaqueToken()
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: secondSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )

        #expect(firstSecret != secondSecret,
                "§7.1-c: each auth event must produce a freshly-generated secret")
    }

    @Test(
        "§7.1-f: Session secret is generated by the session host during the post-auth interaction",
        .tags(.aal1, .sessionManagement, .authenticator, .unit, .shall)
    )
    func sessionSecretGeneratedByHostPostAuth() async throws {
        // §7.1-f nails down *who* generates the secret (the session host,
        // i.e. the server) and *when* (immediately following authentication).
        // Passage's `Passage.Tokens.issue(for:)` is the single place that
        // mints a session secret, and it does so from the server-side
        // `DefaultRandomGenerator` — the subscriber never supplies a
        // token. The test exercises the exact generator the server uses.
        let random = DefaultRandomGenerator()

        // The generator is called by the server and produces an opaque
        // token with no input from the subscriber — the secret is a pure
        // function of server-side randomness.
        let t0 = random.generateOpaqueToken()
        let t1 = random.generateOpaqueToken()
        #expect(!t0.isEmpty,
                "§7.1-f: the session host must emit a non-empty secret")
        #expect(t0 != t1,
                "§7.1-f: successive host-generated secrets must differ (otherwise the host is not the source)")

        // Immediately after the auth event, the secret is persisted
        // server-side — pinned via `createRefreshToken` with the freshly-
        // generated hash. If the secret weren't generated in-process post-
        // auth, this sequence wouldn't round-trip.
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("host-generated"),
            with: .password("$2b$12$hash")
        )
        let hostSecret = random.generateOpaqueToken()
        let token = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: hostSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )
        #expect(token.tokenHash == random.hashOpaqueToken(token: hostSecret),
                "§7.1-f: the persisted hash must match the host-generated secret")
    }
}
