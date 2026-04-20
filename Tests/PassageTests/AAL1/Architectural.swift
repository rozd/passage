import Testing

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
//
// Populated by /aal1-add as design-assertion rows from requirements.yaml are
// processed. See docs/AAL1/README.md for the workflow.

@Suite("AAL1 architectural attestations", .tags(.aal1))
struct AAL1ArchitecturalTests {
    // Tests will be added by /aal1-add. Example shape (do not uncomment
    // without a corresponding entry in docs/AAL1/attestations.md and a row in
    // docs/AAL1/requirements.yaml):
    //
    // @Test(
    //     "§5.1.1.2-g: Verifiers SHALL store memorized secrets using an approved key-derivation function",
    //     .tags(.aal1, .memorizedSecret, .unit, .shall)
    // )
    // func usesApprovedKeyDerivationForMemorizedSecrets() async throws {
    //     // Structural attestation: Passage does not implement its own hash;
    //     // it delegates to Vapor's Bcrypt. See Package.swift dependency on
    //     // vapor/vapor and Restoration+EmailRouteCollection.swift:64.
    // }
}
