import Foundation
import Testing
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 session-secret timeout
//
// SP 800-63B §7.1-l: Session-binding secrets SHALL time out and not be
// accepted after the times specified in Sections 4.1.4 / 4.2.4 / 4.3.4 for
// the applicable AAL. Passage's session secret is the refresh token; its
// lifetime is governed by `Passage.Configuration.Tokens.RefreshToken
// .timeToLive` (default 7 days, §4.1.3-b ceiling 30 days). Beyond the TTL
// the stored record is `isExpired`, and the rotation path rejects it.

@Suite(.tags(.aal1, .sessionManagement, .reauthentication))
struct `AAL1 session-secret timeout` {

    @Test(.tags(.aal1, .sessionManagement, .reauthentication, .authenticator, .unit, .shall))
    func `§7.1-l: Session-binding secret times out and is rejected after its TTL`() async throws {
        // Drive the concrete path: mint a token whose `expiresAt` is in the
        // past (models "now" > TTL lapse), then consult the exact
        // `isExpired` / `isValid` predicates Passage.Tokens.refresh uses.
        // If §7.1-l is violated — i.e. expired records are still accepted —
        // this test fails.
        let random = DefaultRandomGenerator()
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = try await store.users.create(
            identifier: .username("ttl-lapse"),
            with: .password("$2b$12$hash")
        )

        let hash = random.hashOpaqueToken(token: random.generateOpaqueToken())
        _ = try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: hash,
            expiresAt: Date().addingTimeInterval(-1) // already expired
        )

        let stored = try await store.tokens.find(refreshTokenHash: hash)
        try #require(stored != nil, "precondition: expired record must still be retrievable")
        #expect(stored?.isExpired == true,
                "§7.1-l: past-TTL secret must be considered expired")
        #expect(stored?.isValid == false,
                "§7.1-l: expired secret must not be accepted (`isValid` false)")
    }
}
