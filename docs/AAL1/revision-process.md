# Revision Upgrade Process

Passage's current AAL1 claim is pinned to **NIST SP 800-63B rev 3** (2017, updated 2020). When a future revision of SP 800-63B is adopted — rev 4 or later — this document describes how to migrate the conformance artifacts without invalidating the existing claim or losing tests.

## Principle

A revision bump is a **new claim, not a mutation of the existing one**. The rev 3 artifacts remain intact and archived; rev 4 artifacts are built alongside. Both claims coexist until the library drops support for integrators still audited against rev 3.

## Process

1. **Archive the current artifacts.**
   - Rename `requirements.yaml` → `requirements.rev3.yaml`.
   - Rename `conformance.md` → `conformance.rev3.md`.
   - Rename `CLAIM.md` → `CLAIM.rev3.md`.
   - Commit: `docs(aal1): archive rev 3 artifacts ahead of rev 4 migration`.

2. **Decompose the new revision.**
   - Run `/aal1-decompose <rev4-source>` to produce `requirements.rev4.yaml`.
   - Human review; populate provenance frontmatter (source SHA256, retrieval date).

3. **Diff and triage.**
   - `diff requirements.rev3.yaml requirements.rev4.yaml` surfaces added / removed / modified clauses.
   - For each change:
     - **Added clause** → `status: pending` in rev4 ledger; picked up by `/aal1-add`.
     - **Removed clause** → no action; rev3 artifact archived, not deleted.
     - **Modified clause** → rev4 record starts as `status: pending` even if its rev3 counterpart was `has_test`; the existing test is re-evaluated for whether it still satisfies the modified wording. If yes, the test is re-pointed to the rev4 ID via `/aal1-add`'s ledger-update path. If no, the test is rewritten.

4. **Iterate.** Phases 2 – 5 of the plan apply identically to the rev4 artifacts.

5. **Dual-publish** until the project decides to retire rev 3. Root `README.md` links both claims; `CLAIM.rev3.md` gains a banner noting that a newer claim exists.

## When to start

- Within **3 months** of NIST publishing a final revision (not a draft).
- Earlier if a downstream integrator requires the new revision for their own audit.
- Never based on a draft — drafts change materially before finalisation and the decomposition work would be wasted.

## Archival policy

- Rev N artifacts remain in `docs/AAL1/` for at least one year after rev N+1 is published, and longer if any public integrator still cites them.
- Tag the repo at the point of archival: `aal1-rev3-final`.
- Add an entry to `CHANGELOG.md` citing the migration PR and the archival tag.
