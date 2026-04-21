---
description: Decompose NIST SP 800-63B into docs/AAL1/requirements.yaml (one-shot bootstrap)
argument-hint: <path-to-pdf-or-url>
allowed-tools: Read, Write, Edit, Bash(shasum:*), Bash(sha256sum:*), Bash(date:*), Bash(curl:*), Bash(.scripts/aal1-lint.sh:*), WebFetch
---

You are populating the AAL1 requirements ledger `docs/AAL1/requirements.yaml` from the NIST SP 800-63B specification text.

**Argument.** `$ARGUMENTS` — a local file path (PDF or plain text) or a URL to the specification document. Default if empty: `https://pages.nist.gov/800-63-3/sp800-63b.html`.

**Pinned revision.** NIST SP 800-63B rev 3 (2017, updated 2020). Do not decompose any other revision under this command — there is a separate process (`docs/AAL1/revision-process.md`) for future revisions.

**Scope.** Extract only the clauses relevant to AAL1: §4.1 (AAL1 requirements), §4.4 (records retention as it applies to AAL1), §4.5 (privacy as it applies to AAL1), §5.1.1 (memorized-secret authenticators and verifiers), §5.2 (general authenticator requirements, including §5.2.2 throttling), §7 (session management). Skip AAL2 / AAL3 / §5.1.2 – §5.1.9 / §6 / §8 / §9 / §10 / §11 / Appendix A unless a clause is explicitly referenced by an in-scope section.

**Output schema (one record per clause).** See `docs/AAL1/requirements.yaml` for the schema reference block. Every record must populate: `id`, `normative`, `section`, `tags`, `testability`, `status: pending`, `tests: []`, `excluded_reason` (null unless `testability: excluded`), `requirement` (verbatim clause text).

**Clause ID format.** `<section>.<subsection>(-<letter>)?` — e.g. `5.1.1.2-a`. When the spec enumerates multiple SHALLs under a single sub-section, split them into `-a`, `-b`, `-c` in document order.

**Tag selection.** Use the tag names declared in `Tests/PassageTests/Testing+Passage.swift`: `memorizedSecret`, `authenticator`, `throttling`, `sessionManagement`, `reauthentication`, `recordsRetention`. Every record gets at least one section-level tag.

**Testability decision tree.**
- If the clause describes verifier behaviour observable via an HTTP request / stored credential / emitted token → `testable`.
- If the clause constrains what the library does *not* expose (e.g. "SHALL NOT permit hints", "SHALL NOT use KBA") but can be proved by asserting a runtime rejection OR the absence of an API surface → `testable` (these are `SHALL_NOT` clauses; real tests, not design assertions).
- If the clause is about structural properties of the library (cryptographic primitives, dependency choices) → `design-assertion`.
- If the clause applies to a layer Passage doesn't own (TLS, deployment, identity proofing) → `excluded`, with a concrete `excluded_reason`.

**Workflow.**
1. Fetch the source if `$ARGUMENTS` is a URL; otherwise read the local file. Compute SHA256 of the retrieved content.
2. Draft each record. Preserve the exact `SHALL` / `SHALL NOT` / `SHOULD` / `MAY` language in `requirement`; do not paraphrase.
3. Write the full ledger to `docs/AAL1/requirements.yaml`. Populate `meta.source_sha256` with the computed hash and `meta.retrieved` with today's ISO-8601 date.
4. Validate: run `.scripts/aal1-lint.sh`. It should pass on an empty-tests ledger (no raw-identifier prefix violations because no tests exist yet).
5. Report to the user: total record count, breakdown by `testability`, breakdown by `normative`. Do not commit — human review comes first.

**Cautions.**
- LLM-extracted specifications contain silent errors. Summarise what you did so the human can spot-check.
- Do not invent clause IDs. If the spec uses numbered enumerations, preserve them exactly; if not, use `-a`, `-b` suffixes in document order.
- If a clause contains multiple SHALLs joined by "and" / "or" where the separate propositions are independently testable, split them into separate records.
- The `requirement` field may contain colons and pipes — YAML block-literal form (`|`) is used to keep them intact. Do not fold or escape them.
