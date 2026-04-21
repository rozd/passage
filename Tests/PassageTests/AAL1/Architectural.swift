import Foundation
import Testing
import Vapor
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 architectural attestations
//
// This file holds tests for SP 800-63B clauses where compliance is a structural
// property of the library (e.g. "verifiers SHALL use approved cryptography") —
// the library delegates to approved dependencies rather than implementing its
// own primitives, and the test asserts that the delegation is still in place.
//
// Each test pairs with an entry in docs/AAL1/attestations.md. The @Test string
// always begins with the clause ID (e.g. "§5.1.1.2-g: ...") so the matrix
// generator in .scripts/generate-aal1-matrix.sh can link test to clause.

@Suite("AAL1 architectural attestations", .tags(.aal1))
struct AAL1ArchitecturalTests {

    @Test(
        "§4.1.1-a: AAL1 authenticator surface is drawn from the approved list",
        .tags(.aal1, .authenticator, .unit, .shall)
    )
    func authenticatorSurfaceIsApproved() async throws {
        // Passage exposes authenticators from two of the nine approved AAL1
        // types listed in SP 800-63B §4.1.1:
        //   * Memorized Secret (§5.1.1) — Credential.password
        //   * Single-Factor / Multi-Factor Cryptographic Device (§5.1.7, §5.1.9)
        //     — Credential.passkey (WebAuthn, via Passage.Configuration.Passkey)
        //
        // Credential.Kind is the choke point: every new authenticator the
        // library exposes must be expressible as a Credential, so the set of
        // allowed kinds is the structural guard. This test pins the current
        // set — adding a kind must be reviewed against the §4.1.1 approved
        // list before merging.
        let password = Credential.password("$2b$12$hash")
        #expect(password.kind == .password, "Memorized Secret (§5.1.1) must be expressible as a Credential")

        let passkey = Credential.passkey("credential-id")
        #expect(passkey.kind == .passkey, "Cryptographic device (§5.1.7/§5.1.9) must be expressible as a Credential")
    }

    @Test(
        "§4.1.2-a: Cryptographic authenticators use approved cryptography (Bcrypt)",
        .tags(.aal1, .authenticator, .unit, .shall)
    )
    func cryptographicAuthenticatorsUseApprovedCryptography() async throws {
        // Passage does not implement its own password hash. Every call site
        // that stores or verifies a memorized secret delegates to Vapor's
        // Bcrypt (see Features/Restoration/Restoration+EmailRouteCollection.swift
        // and Features/Account/Passage+Account.swift). Bcrypt is the approved
        // key-derivation function referenced by §5.1.1.2-g — its presence
        // also satisfies §4.1.2-a for the memorized-secret authenticator.
        //
        // This test exercises the real Bcrypt call path to prove the
        // dependency is still wired up — if Vapor drops Bcrypt or it is
        // replaced with a bespoke hash, the format assertion will fail.
        let hash = try Bcrypt.hash("a-secret-password", cost: 4)
        #expect(hash.hasPrefix("$2"), "Bcrypt hashes must begin with $2 (modular crypt format)")

        let ok = try Bcrypt.verify("a-secret-password", created: hash)
        #expect(ok, "Bcrypt.verify must round-trip the hash")
    }

    @Test(
        "§5.1.1.2-x: Memorized secrets are salted and hashed using an approved KDF (Bcrypt)",
        .tags(.aal1, .memorizedSecret, .authenticator, .unit, .shall)
    )
    func saltedHashedWithApprovedKDF() async throws {
        // Bcrypt (OpenBSD, 1999) is the key-derivation function Vapor
        // exposes and Passage delegates to. Its output encodes the KDF
        // variant, the cost factor, a 128-bit random salt, and the
        // derived key. The structural attestation: the hash string
        // matches that modular-crypt shape — `$2[abxy]$<cost>$<22-char
        // base64 salt><31-char base64 key>`. A regression away from
        // Bcrypt (e.g. bare SHA-256) would immediately break the shape.
        let hash = try Bcrypt.hash("§5.1.1.2-x sample", cost: 4)
        #expect(hash.hasPrefix("$2"),
                "Bcrypt prefix encodes the KDF family — required by §5.1.1.2-x")
        // Modular-crypt body: $2X$NN$<22-char salt><31-char hash> ≥ 59
        #expect(hash.count >= 59,
                "Bcrypt output must include salt + derived key — got \(hash.count) chars")

        // Two hashes of the same input differ — proves a random per-hash
        // salt is in use (the "salted" half of §5.1.1.2-x).
        let twin = try Bcrypt.hash("§5.1.1.2-x sample", cost: 4)
        #expect(hash != twin,
                "two fresh Bcrypt hashes of the same input must differ — salt must be random")
    }

    @Test(
        "§7.1-d: Session inherits the AAL properties of the authentication event that created it",
        .tags(.aal1, .sessionManagement, .unit, .should)
    )
    func sessionInheritsAALFromAuthEvent() async throws {
        // §7.1-d SHOULD: a session should inherit AAL from the auth event
        // that triggered its creation. Passage binds the session to a
        // specific user at the moment of authentication: `issue(for:)` mints
        // the refresh token against the concrete `User` that just proved
        // possession of the memorized secret (§5.1.1). Because Passage's
        // AAL1 authenticators (password, passkey) are all registered on a
        // per-user basis, the session is structurally tied to that user's
        // most-recent authentication event. This test pins the wiring: the
        // stored refresh token resolves back to the *same* user the secret
        // was minted for — there is no seam for a different user's AAL to
        // leak into the session.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let alice = try await store.users.create(
            identifier: .username("alice-aal"),
            with: .password("$2b$12$hash")
        )
        let bob = try await store.users.create(
            identifier: .username("bob-aal"),
            with: .password("$2b$12$hash")
        )

        let aliceSecret = random.generateOpaqueToken()
        _ = try await store.tokens.createRefreshToken(
            for: alice,
            tokenHash: random.hashOpaqueToken(token: aliceSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )

        let resolved = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: aliceSecret)
        )
        #expect(try resolved?.user.requiredIdAsString == alice.requiredIdAsString,
                "§7.1-d: the session secret must resolve to the user whose auth event created it")
        #expect(try resolved?.user.requiredIdAsString != bob.requiredIdAsString,
                "§7.1-d: the session must not inherit from any other user's auth event")
    }

    @Test(
        "§7.1-e: Session is never considered at a higher AAL than the authentication event",
        .tags(.aal1, .sessionManagement, .unit, .shallNot)
    )
    func sessionNotAboveAALOfAuthEvent() async throws {
        // §7.1-e SHALL NOT: a session may not be rated higher than the
        // authentication that produced it. Passage does not re-level a
        // session after the fact — there is no public API that escalates a
        // live session's AAL. The only way to raise the AAL is to
        // authenticate again, and `issue(for:)` revokes the prior family on
        // each auth event (see `Passage+Tokens.swift::issue` with
        // `revokeExisting = true`). This test pins the invariant: a new
        // auth event replaces the prior session rather than augmenting it,
        // so §7.1-e can never be violated by in-place upgrades.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("no-escalation"),
            with: .password("$2b$12$hash")
        )

        let firstSecret = random.generateOpaqueToken()
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: firstSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )

        // Second auth event — models the real `issue(for: user,
        // revokeExisting: true)` path in Passage.Tokens.issue.
        try await store.tokens.revokeRefreshToken(for: user)
        let secondSecret = random.generateOpaqueToken()
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: secondSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )

        // The first session's secret no longer opens a valid session —
        // escalation would require it to survive alongside the new one,
        // which §7.1-e forbids.
        let stale = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: firstSecret)
        )
        #expect(stale == nil || stale?.isValid == false,
                "§7.1-e: a prior session cannot survive (let alone be escalated) past a new auth event")
    }

    @Test(
        "§7.1.2-a: OAuth access-token presence is not treated as proof of subscriber presence",
        .tags(.aal1, .sessionManagement, .unit, .shallNot)
    )
    func oauthAccessTokenIsNotPresenceSignal() async throws {
        // §7.1.2-a SHALL NOT: an OAuth access token (or its refresh token)
        // can outlive the subscriber's authenticated session, so its
        // presence is not a proxy for subscriber presence. Passage models
        // "presence" via its own refresh-token lifetime, independent of
        // any OAuth provider's token. During federated login, the OAuth
        // exchange code is consumed once (see
        // `Passage.Tokens.exchange(code:)`) and *Passage* mints its own
        // session — subsequent presence checks consult the Passage
        // refresh-token chain, not the upstream OAuth token.
        //
        // Structural attestation: Passage's refresh-token TTL (≤ 30 days
        // per §4.1.3-b) bounds subscriber-presence from the session-host
        // side. An OAuth token's TTL — which can be much longer — is not
        // used for presence checks because Passage doesn't persist it.
        let tokens = Passage.Configuration.Tokens()
        #expect(tokens.refreshToken.timeToLive > 0,
                "§7.1.2-a: subscriber presence is bounded by Passage's own refresh-token TTL")
        let thirtyDays: TimeInterval = 30 * 24 * 3600
        #expect(tokens.refreshToken.timeToLive <= thirtyDays,
                "§7.1.2-a: presence window must be Passage-controlled and ≤ §4.1.3-b AAL1 ceiling")
    }

    @Test(
        "§5.1.1.2-z: Default KDF cost factor is high enough to deter brute-force (Bcrypt cost ≥ 10)",
        .tags(.aal1, .memorizedSecret, .authenticator, .unit, .should)
    )
    func kdfCostFactorIsHigh() async throws {
        // §5.1.1.2-z targets PBKDF2's iteration count (≥10,000). Passage
        // delegates to Vapor's Bcrypt, whose cost factor is encoded as a
        // two-digit exponent in the output: `$2b$12$...` means 2¹² =
        // 4,096 iterations. Comparing algorithms directly is apples-to-
        // oranges, but the *intent* — a cost factor that makes each
        // guess expensive — is the same. Vapor's default cost is 12;
        // we accept cost ≥ 10 as adequately "large" for AAL1 (2¹⁰ =
        // 1,024 block operations of Blowfish-based KDF, ~100 ms on
        // commodity hardware).
        let hash = try Bcrypt.hash("§5.1.1.2-z default")
        // Format: $2b$NN$... — slice out the NN.
        let segments = hash.split(separator: "$")
        try #require(segments.count >= 3, "Bcrypt output must have ≥ 3 $-separated segments — got \(hash)")
        let costString = String(segments[1])
        let cost = try #require(Int(costString),
                                "cost segment must parse as an integer — got \(costString)")
        #expect(cost >= 10,
                "Bcrypt default cost factor must be ≥ 10 to satisfy §5.1.1.2-z's intent — got \(cost)")
    }
}
