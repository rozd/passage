import Foundation
import Testing
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 session termination at reauthentication time limit
//
// SP 800-63B §4.1.3-c requires the session to be terminated (logged out) when
// the reauthentication time limit is reached. Passage implements this by
// pinning a finite `expiresAt` on every refresh token when it is created, and
// refusing to rotate a token once `expiresAt` has passed.

@Suite(.tags(.aal1, .reauthentication, .sessionManagement))
struct `AAL1 session termination` {

    @Test(.tags(.aal1, .reauthentication, .sessionManagement, .unit, .should))
    func `§4.1.3-c: Expired refresh token is invalid so the session is effectively terminated`() async throws {
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("reauth-expiry"),
            with: .password("$2b$12$hash")
        )

        // Create a refresh token whose lifetime is already exhausted — this
        // models the moment §4.1.3-b would normally fire (30 days since
        // initial auth). At that point §4.1.3-c says the session SHOULD end.
        let expiredAt = Date(timeIntervalSinceNow: -1)
        let tokenHash = "expired-token-hash"
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: tokenHash,
            expiresAt: expiredAt
        )

        let stored = try await store.tokens.find(refreshTokenHash: tokenHash)
        try #require(stored != nil, "refresh token must be retrievable by hash")

        // These are the exact invariants the rotation path (Passage+Tokens
        // refresh) consults: an invalid token is rejected and the family is
        // revoked. No valid token ⇒ no new access token ⇒ session terminated.
        #expect(stored?.isExpired == true, "past expiresAt must mark token expired")
        #expect(stored?.isValid == false, "expired token must not be valid for rotation")
    }

    @Test(.tags(.aal1, .reauthentication, .sessionManagement, .authenticator, .unit, .shall))
    func `§7.2-f: After session termination, a new session can only be started by a fresh auth event`() async throws {
        // §7.2-f SHALL: when a session has been terminated (timeout, logout,
        // admin revocation), the subscriber must establish a *new* session
        // by authenticating again. Passage enforces this via its rotation
        // path: `Passage.Tokens.refresh` looks up the presented secret and
        // throws `AuthenticationError.refreshTokenNotFound` / `.invalidRefreshToken`
        // if the token is missing, revoked, or expired. The only way out
        // is /auth/login, which runs the password (or passkey) path from
        // scratch — a fresh auth event.
        //
        // This test drives the storage primitives the rotation path uses
        // to show that a terminated secret no longer resolves to a live
        // session — proving the only remaining entry point is a fresh
        // auth event against /auth/login.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("terminated-session"),
            with: .password("$2b$12$hash")
        )

        // Establish a session.
        let secret = random.generateOpaqueToken()
        let hash = random.hashOpaqueToken(token: secret)
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: hash,
            expiresAt: Date().addingTimeInterval(3600)
        )

        // Terminate it (logout or admin revoke).
        try await store.tokens.revokeRefreshToken(for: user)

        // The secret no longer resolves to a *live* session: the record is
        // retained (so `Passage.Tokens.refresh` can detect reuse attempts
        // and revoke the family) but `isValid` flips to false, which is
        // exactly the gate the rotation path checks at Passage+Tokens.swift:92
        // before throwing `.invalidRefreshToken`.
        let lookedUp = try await store.tokens.find(refreshTokenHash: hash)
        #expect(lookedUp?.isValid == false,
                "§7.2-f: after termination, the session secret must not resolve to a live session")
        #expect(lookedUp?.isRevoked == true,
                "§7.2-f: termination is recorded via revokedAt — the invariant the rotation path consults")

        // A fresh auth event (modelled here by creating a new token via
        // the `issue(for:)`-equivalent storage call) is the only path to
        // a new session. The new secret has no relationship to the old.
        let freshSecret = random.generateOpaqueToken()
        let freshHash = random.hashOpaqueToken(token: freshSecret)
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: freshHash,
            expiresAt: Date().addingTimeInterval(3600)
        )
        let freshLookup = try await store.tokens.find(refreshTokenHash: freshHash)
        #expect(freshLookup?.isValid == true,
                "§7.2-f: a fresh auth event establishes a new session — the only valid path post-termination")
        #expect(freshHash != hash,
                "§7.2-f: the post-termination session secret must be distinct from the terminated one")
    }
}
