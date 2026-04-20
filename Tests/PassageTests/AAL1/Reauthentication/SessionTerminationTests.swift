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

@Suite("AAL1 session termination", .tags(.aal1, .reauthentication, .sessionManagement))
struct SessionTerminationTests {

    @Test(
        "§4.1.3-c: Expired refresh token is invalid so the session is effectively terminated",
        .tags(.aal1, .reauthentication, .sessionManagement, .unit, .should)
    )
    func expiredRefreshTokenIsInvalid() async throws {
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
}
