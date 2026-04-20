# AAL1 Conformance Changelog

AAL1-specific audit trail. Separate from the repository's general CHANGELOG because its readers (security reviewers, auditors, integrators verifying a specific claim) are different from consumers of the general library changelog.

Entries are appended at the top (newest first). Each entry cites the PR or commit that caused the change.

Format:

```
## <ISO-8601 date> — <short title>

**Change.** <one-sentence summary>

**Details.** <what specifically changed in which file>

**Source.** PR #<n> / commit <sha>
```

---

## 2026-04-20 — Initial scaffolding

**Change.** AAL1 conformance directory scaffolded.

**Details.** `docs/AAL1/` created with README, requirements ledger, threat model, architectural-attestations template, revision-process document, scaffolded CLAIM. No tests yet; no claim cut.

**Source.** branch `feat/AAL1` bootstrap commit.
