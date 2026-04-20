# Passage — Self-Asserted AAL1 Conformance Claim

> **Status: DRAFT.** This document is a scaffold; it will not be dated, versioned, or linked from the root README until Phase 5 of the AAL1 plan. Content below is illustrative of the target shape. Do not cite this document externally until the `Status` line reads "Published".

## Declaration

Passage publishes this document as a **self-asserted conformance claim** under NIST SP 800-63B rev 3 (2017, updated 2020), §4.1 (Authenticator Assurance Level 1).

**This is not a certification.** This claim has not been validated by NVLAP, FedRAMP, Kantara Initiative, FICAM, or any accredited body. It is a public engineering attestation by the Passage maintainers, intended to let integrators verify Passage's handling of authentication requirements against the specification without repeating the analysis themselves.

## Scope

### In scope

- Memorized-secret authenticator flows (register / login / password reset) provided by Passage's core route collections.
- Session management (issuance, lifetime, reauthentication) via Passage's JWT access token + opaque refresh token pair.
- Throttling of failed authentication attempts.
- Verifier storage of credentials (password hashing, refresh token hashing).
- Assertion cryptography (JWT signing via JWKS).

### Out of scope

- AAL2 and AAL3 controls. Passkey / WebAuthn flows (which have stronger phishing-resistance properties) are covered by a separate document; they are not part of this AAL1 claim.
- IAL (identity proofing) — governed by SP 800-63A, not covered here.
- FAL (federation assurance level) — governed by SP 800-63C, not covered here.
- Transport security (TLS / HSTS / secure-cookie deployment) — delegated to the integrator's Vapor deployment.
- Multi-instance throttling state — requires the `passage-fluent` storage-backed implementation, covered separately.

## Passage version covered

*To be pinned at publication.*

## Matrix

The clause-by-clause traceability matrix is appended as [`conformance.md`](./conformance.md). It is machine-generated from [`requirements.yaml`](./requirements.yaml) and the AAL1 test suite under `Tests/PassageTests/AAL1/`. CI fails if the committed matrix is stale relative to the ledger or the tests.

## Threat model

See [`threat-model.md`](./threat-model.md). Summary:

- **Attacker capabilities assumed.** Online guessing against the verifier endpoint; replay of captured bearer/session tokens within validity windows; session hijack via stolen refresh token.
- **Not assumed (out of scope at AAL1).** Verifier impersonation, phishing of the authenticator, endpoint compromise.

## Cryptographic dependencies

Passage does not implement its own cryptographic primitives. Compliance with §5.1.1.2-g ("approved one-way key derivation") and §4.1.5 ("approved cryptography for assertions") is inherited from upstream dependencies:

- **`apple/swift-crypto`** — hashing, HMAC, symmetric primitives.
- **`vapor/vapor`** (provides `Bcrypt`) — memorized-secret key derivation.
- **`vapor/jwt-kit`** — JWT signing and verification.

Architectural attestations for each delegation appear in [`attestations.md`](./attestations.md).

## Residual risks

*To be expanded in Phase 5 based on what the test suite surfaces.* Known items up front:

- **Default `BreachedPasswordService` behaviour** — configured in Phase 3. The claim for §5.1.1.2-d depends on which default ships.
- **In-memory throttling default** — per-instance only; multi-instance deployments need `passage-fluent` for the claim to hold globally.
- **Password length upper bound** — §5.1.1.2 requires ≥ 64 characters; Passage's enforced upper bound is the final value set by `Passage.Configuration.PasswordPolicy` after Phase 3.

## Integrator responsibilities

Integrators adopting Passage for an AAL1-relevant deployment must:

1. Terminate TLS at the edge; serve all Passage routes over HTTPS.
2. Provide a `BreachedPasswordService` implementation that actually consults a current breach list (unless the bundled default already does so — Phase 3 decision).
3. Configure `Passage.Configuration.Sessions.maxSessionAge` consistent with their assurance-level requirements (30 days is the AAL1 ceiling).
4. Use the storage-backed throttle implementation from `passage-fluent` for multi-instance deployments.
5. Deploy the JWKS signing keys with appropriate operational controls (HSM or equivalent, rotation, access auditing).

## Changelog

See [`CHANGELOG.md`](./CHANGELOG.md) for the AAL1-specific audit trail.

## Contact

Issues or disputes about this claim should be filed against the Passage repository on GitHub.
