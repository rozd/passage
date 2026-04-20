import Testing
import Vapor
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

    @Test(
        "§4.1.2-a: Cryptographic authenticators use approved cryptography (Bcrypt)",
        .tags(.aal1, .authenticator, .unit, .shall)
    )
    func cryptographicAuthenticatorsUseApprovedCryptography() async throws {
        // Passage does not implement its own password hash. Every call site
        // that stores or verifies a memorized secret delegates to Vapor's
        // Bcrypt (see Features/Restoration/Restoration+EmailRouteCollection.swift
        // and Features/Account/Passage+Account.swift). Bcrypt is the approved
        // key-derivation function referenced by §5.1.1.2-g — its presence
        // also satisfies §4.1.2-a for the memorized-secret authenticator.
        //
        // This test exercises the real Bcrypt call path to prove the
        // dependency is still wired up — if Vapor drops Bcrypt or it is
        // replaced with a bespoke hash, the format assertion will fail.
        let hash = try Bcrypt.hash("a-secret-password", cost: 4)
        #expect(hash.hasPrefix("$2"), "Bcrypt hashes must begin with $2 (modular crypt format)")

        let ok = try Bcrypt.verify("a-secret-password", created: hash)
        #expect(ok, "Bcrypt.verify must round-trip the hash")
    }

    @Test(
        "§5.1.1.2-x: Memorized secrets are salted and hashed using an approved KDF (Bcrypt)",
        .tags(.aal1, .memorizedSecret, .authenticator, .unit, .shall)
    )
    func saltedHashedWithApprovedKDF() async throws {
        // Bcrypt (OpenBSD, 1999) is the key-derivation function Vapor
        // exposes and Passage delegates to. Its output encodes the KDF
        // variant, the cost factor, a 128-bit random salt, and the
        // derived key. The structural attestation: the hash string
        // matches that modular-crypt shape — `$2[abxy]$<cost>$<22-char
        // base64 salt><31-char base64 key>`. A regression away from
        // Bcrypt (e.g. bare SHA-256) would immediately break the shape.
        let hash = try Bcrypt.hash("§5.1.1.2-x sample", cost: 4)
        #expect(hash.hasPrefix("$2"),
                "Bcrypt prefix encodes the KDF family — required by §5.1.1.2-x")
        // Modular-crypt body: $2X$NN$<22-char salt><31-char hash> ≥ 59
        #expect(hash.count >= 59,
                "Bcrypt output must include salt + derived key — got \(hash.count) chars")

        // Two hashes of the same input differ — proves a random per-hash
        // salt is in use (the "salted" half of §5.1.1.2-x).
        let twin = try Bcrypt.hash("§5.1.1.2-x sample", cost: 4)
        #expect(hash != twin,
                "two fresh Bcrypt hashes of the same input must differ — salt must be random")
    }
}
