import Foundation
import Testing
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 session invalidation on logout
//
// SP 800-63B §7.1-h: Session-binding secrets SHALL be erased or invalidated
// by the session subject when the subscriber logs out. Passage's
// `Passage.Account.logout()` implements this by calling
// `Passage.Tokens.revoke(for:)`, which in turn calls
// `store.tokens.revokeRefreshTokens(for: user)`. After revocation, the
// refresh-token record is either gone or no longer valid — a subsequent
// rotation attempt with the now-stale secret is rejected.

@Suite(.tags(.aal1, .sessionManagement))
struct `AAL1 session invalidation` {

    @Test(.tags(.aal1, .sessionManagement, .authenticator, .unit, .shall))
    func `§7.1-h: Refresh-token session secret is invalidated on logout`() async throws {
        // Drive the real logout-side storage path: mint a secret, then call
        // `revokeRefreshTokens(for: user)` — the exact call `Passage.Tokens
        // .revoke` makes. The invariant: after logout, the formerly-valid
        // secret can no longer be used to resolve a live session.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("logout-victim"),
            with: .password("$2b$12$hash")
        )

        let subscriberSecret = random.generateOpaqueToken()
        let hash = random.hashOpaqueToken(token: subscriberSecret)
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: hash,
            expiresAt: Date().addingTimeInterval(3600),
            sessionId: UUID()
        )

        // Sanity: before logout the session is alive.
        let alive = try await store.tokens.find(refreshTokenHash: hash)
        try #require(alive?.isValid == true,
                     "precondition: session secret must be valid before logout")

        // Logout — the same storage call `Passage.Tokens.revoke` issues.
        try await store.tokens.revokeRefreshTokens(for: user)

        // §7.1-h: the secret must no longer open a valid session. Either
        // the record is removed outright, or it remains but is no longer
        // `isValid`. Both satisfy "erased or invalidated".
        let after = try await store.tokens.find(refreshTokenHash: hash)
        #expect(after == nil || after?.isValid == false,
                "§7.1-h: refresh-token secret must be erased or invalidated on logout")
    }
}
