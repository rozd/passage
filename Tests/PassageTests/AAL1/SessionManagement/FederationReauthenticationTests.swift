import Foundation
import Testing
@testable import Passage

// MARK: - AAL1 federation reauthentication
//
// SP 800-63B §7.2.1 governs reauthentication when a federation protocol
// (OIDC, SAML) brokers the auth event. Passage currently acts as an RP
// against IdPs (Google, GitHub, custom) via Imperial. For AAL1 compliance
// the RP SHALL tell the IdP the maximum acceptable authentication age
// (§7.2.1-b) and the CSP SHALL communicate the auth-event time back to
// the RP (§7.2.1-c). These tests pin the API surface these clauses demand
// — they will fail to compile until the corresponding configuration and
// claim fields ship. Compilation failure here IS the signal for Phase 3.

@Suite("AAL1 federation reauthentication", .tags(.aal1, .sessionManagement, .reauthentication))
struct FederationReauthenticationTests {

    @Test(
        "§7.2.1-b: RP specifies a maximum authentication age so the CSP can enforce reauthentication",
        .tags(.aal1, .sessionManagement, .reauthentication, .authenticator, .unit, .shall)
    )
    func rpSpecifiesMaxAuthenticationAge() async throws {
        // §7.2.1-b SHALL: when the protocol supports it, the RP must
        // specify the max acceptable authentication age so the CSP can
        // reauthenticate the subscriber if the last event is older than
        // that window. In OIDC this is the `max_age` parameter.
        //
        // The expected Passage surface: a configurable `maxAuthAge` on
        // each federated provider entry, defaulting to `nil` (use
        // provider's default) and — for AAL1 — capped at the same 30-day
        // ceiling §4.1.3-b places on local sessions. Construction of a
        // provider with `maxAuthAge` drives the wiring that will have
        // Passage emit `max_age=<seconds>` on the authorize request.
        let provider = Passage.Configuration.FederatedLogin.Provider(
            provider: .github(),
            maxAuthAge: 30 * 24 * 3600 // 30 days — AAL1 ceiling
        )
        let age = try #require(provider.maxAuthAge,
                               "§7.2.1-b: provider config must carry a `maxAuthAge` field for the RP to specify")
        #expect(age > 0,
                "§7.2.1-b: a specified max-auth-age must be a positive duration")
        #expect(age <= 30 * 24 * 3600,
                "§7.2.1-b: AAL1 RPs must not specify a reauth window exceeding §4.1.3-b's 30-day ceiling")
    }
}
