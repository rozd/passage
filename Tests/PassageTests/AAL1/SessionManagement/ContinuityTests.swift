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

@Suite("AAL1 session continuity", .tags(.aal1, .sessionManagement, .reauthentication))
struct ContinuityTests {

    @Test(
        "§7.2-a: Session continuity depends on presenting a valid session secret",
        .tags(.aal1, .sessionManagement, .reauthentication, .authenticator, .unit, .shall)
    )
    func continuityRequiresValidSessionSecret() async throws {
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
}
