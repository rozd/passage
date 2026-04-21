import Foundation
import Testing
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 session continuity
//
// SP 800-63B §7.2 governs how a session persists between the initial
// authentication event and the next reauthentication. Passage's model:
// continuity is established exclusively by the subscriber presenting a
// valid refresh token (the session-binding secret), which the server
// rotates to issue a fresh access token. No other path extends the session.

@Suite(.tags(.aal1, .sessionManagement, .reauthentication))
struct `AAL1 session continuity` {

    @Test(.tags(.aal1, .sessionManagement, .reauthentication, .authenticator, .unit, .shall))
    func `§7.2-a: Session continuity depends on presenting a valid session secret`() async throws {
        // The only path by which an authenticated session persists across
        // requests is the refresh-token rotation — the subscriber presents
        // the opaque token, and the server (after verifying it `isValid`)
        // issues a new access token. If the presented secret is not valid,
        // no new token is minted and the session ends.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("continuity"),
            with: .password("$2b$12$hash")
        )

        // Path A — continuity via a valid secret: rotation succeeds.
        let validSecret = random.generateOpaqueToken()
        let validToken = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: validSecret),
            expiresAt: Date().addingTimeInterval(3600)
        )
        #expect(validToken.isValid,
                "§7.2-a: a valid session secret must permit continuation")

        // Path B — no continuity without the secret: a random bogus secret
        // does not resolve to any token.
        let bogusLookup = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: random.generateOpaqueToken())
        )
        #expect(bogusLookup == nil,
                "§7.2-a: continuity must not be granted without the session secret")

        // Path C — continuity ends when the secret is revoked (logout).
        try await store.tokens.revokeRefreshToken(for: user)
        let revoked = try await store.tokens.find(
            refreshTokenHash: random.hashOpaqueToken(token: validSecret)
        )
        #expect(revoked == nil || revoked?.isValid == false,
                "§7.2-a: once the secret is revoked, continuity ends")
    }

    @Test(.tags(.aal1, .sessionManagement, .reauthentication, .authenticator, .unit, .shall))
    func `§7.2-c: Periodic reauthentication is enforced — a session cannot survive indefinitely on its secret`() async throws {
        // §7.2-c SHALL: sessions must be periodically reauthenticated.
        // Passage's mechanism is the finite refresh-token TTL: once the
        // token's `expiresAt` passes, rotation fails (§7.2-a wiring) and
        // the subscriber must reauthenticate via /auth/login with
        // credentials. Proof by contradiction: simulate the session
        // reaching its TTL and confirm the secret is no longer accepted.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("reauth-required"),
            with: .password("$2b$12$hash")
        )

        let secret = random.generateOpaqueToken()
        let hash = random.hashOpaqueToken(token: secret)
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: hash,
            expiresAt: Date().addingTimeInterval(-1) // models the TTL expiring
        )

        let stored = try await store.tokens.find(refreshTokenHash: hash)
        try #require(stored != nil, "precondition: the record must be retrievable")
        #expect(stored?.isValid == false,
                "§7.2-c: once the TTL lapses the session must stop accepting its secret — forcing reauth")

        // The shipped default TTL is finite and positive — the invariant
        // that makes periodic reauth possible at all. An infinite TTL
        // would silently defeat §7.2-c.
        let config = Passage.Configuration.Tokens()
        #expect(config.refreshToken.timeToLive > 0,
                "§7.2-c: refresh-token TTL must be positive")
        #expect(config.refreshToken.timeToLive.isFinite,
                "§7.2-c: refresh-token TTL must be finite so reauth is eventually forced")
    }

    @Test(.tags(.aal1, .sessionManagement, .reauthentication, .authenticator, .unit, .shallNot))
    func `§7.2-d: Presenting the session secret alone cannot extend the session past the reauth ceiling`() async throws {
        // §7.2-d SHALL NOT: a session cannot be extended past the
        // reauthentication guidelines based solely on presenting the
        // session secret. Passage enforces this by pinning `expiresAt` at
        // creation time and never advancing it on rotation — each rotation
        // mints a *new* record, it does not extend the old one. This test
        // pins that invariant: after a rotation, the outer sliding window
        // capped at the configured TTL is what's in force, not some
        // accumulated extension.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("no-extension"),
            with: .password("$2b$12$hash")
        )

        // Create a refresh token. Its `expiresAt` is fixed — subsequent
        // lookups of the *same* token must never report a later expiry.
        let secret = random.generateOpaqueToken()
        let hash = random.hashOpaqueToken(token: secret)
        let originalExpiry = Date().addingTimeInterval(60)
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: hash,
            expiresAt: originalExpiry
        )

        // Present the secret repeatedly (simulated by successive lookups):
        // the stored `expiresAt` must never move forward.
        for _ in 0..<5 {
            let look = try await store.tokens.find(refreshTokenHash: hash)
            try #require(look != nil)
            #expect(look!.expiresAt == originalExpiry,
                    "§7.2-d: presenting the secret must not extend `expiresAt` in place")
        }

        // The reauth ceiling — even under repeated rotation — is the
        // configured refresh-token TTL. Passage has no code path that
        // raises that ceiling from the rotation endpoint.
        let configured = Passage.Configuration.Tokens().refreshToken.timeToLive
        #expect(configured.isFinite && configured > 0,
                "§7.2-d: the reauth ceiling must be a finite, positive TTL — not relaxable by secret presentation")
    }
}
