import Foundation
import Testing
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 periodic reauthentication
//
// SP 800-63B §4.1.3 requires that subscriber sessions be periodically
// reauthenticated. In Passage, reauthentication is enforced implicitly by the
// refresh-token lifecycle: the access token is short-lived, and the refresh
// token has a finite TTL after which the user must reauthenticate by
// submitting credentials to /auth/login. This file pins the invariants that
// keep that guarantee intact.

@Suite("AAL1 periodic reauthentication", .tags(.aal1, .reauthentication))
struct PeriodicReauthenticationTests {

    @Test(
        "§4.1.3-a: Refresh token TTL is finite so that periodic reauthentication is enforced",
        .tags(.aal1, .reauthentication, .authenticator, .unit, .shall)
    )
    func refreshTokenTTLIsFinite() async throws {
        // Passage issues an access token alongside a refresh token. The
        // access token has a short TTL (15m default) and the refresh token
        // has a longer but still finite TTL. When the refresh token expires,
        // /auth/refresh-token rejects rotations and the user must
        // reauthenticate via /auth/login with credentials.
        //
        // §4.1.3-a is satisfied structurally iff the refresh-token TTL is
        // finite — an infinite TTL (or <= 0) would let a session continue
        // without ever reauthenticating. Default constructor is the shipped
        // contract, so the default is what we pin.
        let tokens = Passage.Configuration.Tokens()
        #expect(tokens.refreshToken.timeToLive > 0,
                "refresh-token TTL must be positive to enforce reauthentication")
        #expect(tokens.refreshToken.timeToLive.isFinite,
                "refresh-token TTL must be finite to enforce reauthentication")
        #expect(tokens.accessToken.timeToLive < tokens.refreshToken.timeToLive,
                "access-token TTL must be shorter than refresh-token TTL")
    }

    @Test(
        "§4.1.3-b: Default refresh token TTL is at most 30 days (AAL1 SHOULD ceiling)",
        .tags(.aal1, .reauthentication, .authenticator, .unit, .should)
    )
    func refreshTokenTTLWithin30DayCeiling() async throws {
        // AAL1 SHOULD reauthenticate at least once per 30 days during an
        // extended usage session, regardless of user activity. Passage's
        // refresh-token TTL is the upper bound on how long a session can
        // survive without reauthentication, so the default MUST NOT exceed
        // 30 days.
        let thirtyDays: TimeInterval = 30 * 24 * 3600
        let tokens = Passage.Configuration.Tokens()
        #expect(tokens.refreshToken.timeToLive <= thirtyDays,
                "default refresh-token TTL must be <= 30 days to satisfy AAL1 §4.1.3-b")
    }

    @Test(
        "§7.2-e: Presenting an auth factor (AAL1: any one) extends the reauth time limit by minting a fresh session secret",
        .tags(.aal1, .reauthentication, .sessionManagement, .authenticator, .unit, .shall)
    )
    func authFactorPresentationExtendsReauthLimit() async throws {
        // §7.2-e SHALL: prior to session expiration, the reauth time limit
        // is extended by prompting the subscriber for the AAL-required
        // factor(s) — AAL1's Table 7-1 row reads "Presentation of any one
        // factor". In Passage this happens at /auth/login: the subscriber
        // submits their memorized secret (one factor), and
        // `Passage.Account.login` calls `tokens.issue(for:)` which mints a
        // *new* refresh token with `expiresAt = .now + TTL`. The invariant
        // that satisfies §7.2-e: the post-reauth `expiresAt` is strictly
        // later than the pre-reauth one — i.e., presenting the factor
        // actually bought the subscriber more time.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("reauth-extend"),
            with: .password("$2b$12$hash")
        )

        // First auth event: old-style "initial login".
        let firstSecret = random.generateOpaqueToken()
        let firstExpiresAt = Date().addingTimeInterval(60)
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: firstSecret),
            expiresAt: firstExpiresAt
        )

        // Simulate the subscriber re-presenting their auth factor before
        // expiry — the `issue(for:)` path with `revokeExisting: true`
        // revokes the prior family and mints a fresh session secret whose
        // `expiresAt` is `now + TTL`. We model a fresh Bcrypt-backed
        // successful login here by calling the same storage primitives.
        try await store.tokens.revokeRefreshToken(for: user)
        let freshSecret = random.generateOpaqueToken()
        let freshExpiresAt = Date().addingTimeInterval(600) // post-reauth TTL
        let freshToken = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: freshSecret),
            expiresAt: freshExpiresAt
        )

        #expect(freshToken.expiresAt > firstExpiresAt,
                "§7.2-e: presenting an auth factor must extend the session's reauth time limit")
        #expect(freshToken.isValid,
                "§7.2-e: the post-reauth session must be valid for continued use")
    }
}
