import Foundation
import Testing
@testable import Passage

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
}
