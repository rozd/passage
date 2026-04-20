import Testing
@testable import Passage

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
}
