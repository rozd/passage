# Architectural Attestations

Some SP 800-63B clauses cannot be proved by a runtime test because compliance is a structural property of the library — e.g. "verifiers SHALL use approved cryptography." The library does not implement cryptographic primitives; it delegates to dependencies known to be approved.

This document enumerates every such **architectural attestation**. Each entry cites:

1. The SP 800-63B clause being attested to.
2. The structural fact that satisfies the clause.
3. The code reference (file path, dependency name) that demonstrates the fact.
4. A pointer to the corresponding test in `Tests/PassageTests/AAL1/Architectural.swift` that asserts the structural fact is still true (e.g. by inspecting `Package.swift` at test time).

Every row in [`requirements.yaml`](./requirements.yaml) with `testability: design-assertion` is represented here.

---

## Template

```
### §<clause-id>: <short name>

**Clause.** <verbatim clause text>

**Attestation.** <one-sentence structural fact>

**Evidence.**
- Source: <file path or Package.swift dependency>
- Test: `Tests/PassageTests/AAL1/Architectural.swift::<functionName>`

**Last verified.** <ISO-8601 date>
```

---

<!--
  Populated in Phase 2 as design-assertion clauses are processed. Example:

  ### §5.1.1.2-g: Approved key-derivation for memorized secrets

  **Clause.** Verifiers SHALL store memorized secrets in a form that is resistant
  to offline attacks, using an approved one-way key derivation function.

  **Attestation.** Passage hashes memorized secrets with Bcrypt via `Vapor/Bcrypt`;
  the library does not implement its own hash and has no dependency on
  unapproved cryptographic primitives.

  **Evidence.**
  - Source: `Sources/Passage/Features/Restoration/Restoration+EmailRouteCollection.swift:64`
  - Source: `Package.swift` — dependency on `vapor/vapor` (provides `Bcrypt`)
  - Test: `Tests/PassageTests/AAL1/Architectural.swift::usesApprovedKeyDerivationForMemorizedSecrets`

  **Last verified.** 2026-04-20
-->
