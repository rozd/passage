# AAL1 Threat Model

Scope of this document: the threats in scope for Passage's AAL1 conformance claim, the threats deliberately out of scope, and the attacker capabilities assumed by the specification. Companion to [`CLAIM.md`](./CLAIM.md).

## Trust boundary

Passage is an authentication and session-management library embedded in a Vapor application. For the purpose of this claim:

- **Inside the boundary.** Credential verification, authenticator storage, session establishment and lifetime enforcement, JWT / JWKS signing, token rotation and revocation, password policy enforcement, rate limiting. These are the behaviours Passage owns and that its conformance claim covers.
- **At the boundary, delegated to the deployment.** TLS termination, HSTS, secure-cookie flags, HTTP/2 or HTTP/3 transport, the relying-party application that consumes Passage, the database engine that implements the storage protocols. The integrator is responsible for provisioning these correctly; Passage provides safe defaults (e.g. secure-cookie flags in production) and fails closed where it can.
- **Outside the boundary.** Subscriber endpoint security, subscriber password hygiene beyond what §5.1.1.2 asks the verifier to enforce, phishing of bearer tokens at the relying party, malware on the subscriber device, compromise of the underlying OS or hardware.

## Attacker capabilities (AAL1-relevant)

Per SP 800-63B §4.1 and §5.2, the AAL1 verifier is expected to resist:

- **Online guessing** — attacker tries credentials against the verifier's endpoint. Mitigated by throttling (§5.2.2) and breached-password rejection (§5.1.1.2-d).
- **Replay of captured secrets** — attacker re-sends a captured bearer/session token within its validity window. Mitigated by session TTL and refresh-token rotation with family revocation on reuse detection.
- **Session hijack via stolen refresh token** — attacker obtains a refresh token and attempts to use it. Mitigated by refresh-token hashing at rest, rotation, and reuse-detection that revokes the entire family.

AAL1 explicitly **does not** require resistance to:

- Verifier impersonation (that's AAL2+).
- Phishing of the authenticator (that's AAL3 with phishing-resistant authenticators).
- Endpoint compromise.

## Out-of-scope threats

- **Physical security** of the infrastructure hosting the integrator's deployment.
- **Insider threat** within the integrator's operations team.
- **Cryptographic primitives themselves** — Passage delegates to Vapor's JWT implementation, `swift-crypto`, and Bcrypt. Their correctness is an assumption, not a claim made here. See [`attestations.md`](./attestations.md).
- **Identity proofing** (IAL, covered by SP 800-63A) — Passage is a credential-management service, not an identity-proofing service.

## Residual risks

- Passage does not implement AAL2 or AAL3 controls (multi-factor, phishing-resistant, hardware-bound authenticators) for memorized-secret flows. Passkey/WebAuthn flows have stronger properties and are tracked separately.
- The breached-password check depends on an integrator-supplied service; the default implementation (Phase 3 decision) governs what is claimed out of the box.
- Throttling is in-memory by default and per-instance; multi-instance deployments need the storage-backed implementation from `passage-fluent` for §5.2.2 to hold globally.
