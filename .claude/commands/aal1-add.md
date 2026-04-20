---
description: Write N AAL1 tests from the next pending clauses in the ledger
argument-hint: <N>
allowed-tools: Read, Write, Edit, Bash(swift:*), Bash(yq:*), Bash(git:*), Bash(.scripts/aal1-lint.sh:*), Bash(grep:*), Bash(awk:*)
---

You are writing AAL1 compliance tests under `Tests/PassageTests/AAL1/` against clauses from `docs/AAL1/requirements.yaml`. Each iteration is atomic: one test, one ledger update, one commit.

**Argument.** `$ARGUMENTS` is the count `N` — default `1` if empty. You will perform `N` independent iterations of the workflow below. After each iteration, continue only if the previous one committed successfully and there are still pending records.

**Pre-flight (run once before the first iteration).**
1. Ensure working tree is clean. Run `git status --porcelain`; if output is non-empty, abort with a message. The plan's commit-per-test atomicity assumes iterations start clean.
2. Ensure `docs/AAL1/requirements.yaml` exists and is populated. If `yq eval '.requirements | length' docs/AAL1/requirements.yaml` is `0`, abort with a message directing the user to run `/aal1-decompose` first.

**Per-iteration workflow.**

1. **Select next clause.** From `docs/AAL1/requirements.yaml`, find the first record (in document order) where `status == pending` and `testability != excluded`. If none, emit the completion promise (see bottom) and stop. Use:
   ```bash
   yq eval '[.requirements[] | select(.status == "pending" and .testability != "excluded")] | .[0]' docs/AAL1/requirements.yaml
   ```

2. **Decide target file.** Map the record's first tag to a sub-directory:
   - `memorizedSecret` → `Tests/PassageTests/AAL1/MemorizedSecret/`
   - `throttling` → `Tests/PassageTests/AAL1/Throttling/`
   - `sessionManagement` → `Tests/PassageTests/AAL1/SessionManagement/`
   - `reauthentication` → `Tests/PassageTests/AAL1/Reauthentication/`
   - `authenticator` (JWT / JWKS) → `Tests/PassageTests/AAL1/Assertion/`
   - `recordsRetention` → `Tests/PassageTests/AAL1/SessionManagement/` (records are retained via session/token store)
   - `testability == design-assertion` → `Tests/PassageTests/AAL1/Architectural.swift`
   Filename pattern: `<BehaviourNoun>Tests.swift` (e.g. `MinimumLengthTests.swift`, `BreachedPasswordTests.swift`). Group tests that exercise the same behaviour cluster in the same file; create a new file if none fits.

3. **Write the test.** Swift Testing syntax; `@Test` display string MUST begin with `§<clause-id>: ` (or comma-separated `§<id>,§<id>: ` if covering multiple clauses). Tags: `.aal1`, at least one module tag (matching the record's tags), one of `.unit` / `.integration`, one of `.shall` / `.shallNot` / `.should` (matching the record's normative level — `SHALL_NOT` maps to `.shallNot`). Function name: clean camelCase verb phrase; no clause ID in the function name.

   The test MUST exercise a concrete code path — no `#expect(true)` stubs. If the behaviour is not yet implemented, write the test against the API you expect (`Passage.Configuration.PasswordPolicy.minLength`, etc.); the test will fail to compile if the API is missing, which IS the signal to add the feature in Phase 3. Prefer compilation failure over a green placeholder.

   Reuse existing patterns: `Passage.OnlyForTest.InMemoryStore` for storage, `Application.testing().test(...)` for integration suites, mocks from `Passage+Mocks.swift`.

4. **Verify compilation.** Run `swift build --build-tests`. If it fails because the test references an unimplemented API, that is acceptable — record the failure in the commit message but do NOT add a stub implementation to make it build. If it fails for a different reason (syntax error in the test itself), fix the test before continuing.

5. **Verify the test is discoverable.** If compilation succeeded, run:
   ```bash
   swift test list 2>/dev/null | grep -F "§<clause-id>:"
   ```
   The test should appear. If it does not, the test is written in a way Swift Testing doesn't recognise — fix before continuing.

   If compilation failed in step 4 due to missing API, skip this check (the test cannot be listed until it compiles). Proceed — Phase 3 will resolve.

6. **Update the ledger.** Use `yq eval -i` to atomically flip the record's `status` to `has_test` and append the test reference to `tests`:
   ```bash
   yq eval -i '(.requirements[] | select(.id == "<id>")).status = "has_test" | (.requirements[] | select(.id == "<id>")).tests += ["AAL1/<Module>/<File>.swift::<functionName>"]' docs/AAL1/requirements.yaml
   ```

7. **Lint.** Run `.scripts/aal1-lint.sh`. Must exit clean. If it fails, fix the cause (usually a malformed `@Test` prefix or a ledger typo) and re-lint.

8. **Commit.** Use the Bash tool to commit exactly the two files touched:
   ```bash
   git add Tests/PassageTests/AAL1/<Module>/<File>.swift docs/AAL1/requirements.yaml
   git commit -m "test(aal1): §<clause-id> <short verb phrase>"
   ```

**Completion promise.**

When step 1 finds no remaining pending records, emit exactly the following on its own line and stop:

    <promise>AAL1_TESTS_COMPLETE</promise>

Before emitting, verify by running:
```bash
yq eval '[.requirements[] | select(.status == "pending" and .testability != "excluded")] | length' docs/AAL1/requirements.yaml
```
Result must be `0`. If not, do not emit the promise; iterate further.

**Reporting.**

Between iterations, give the user a one-line update: `iteration M/N: §<clause-id> → <test file>::<function> [compiled | failed-to-compile-expected]`.

At the end of the batch (N iterations complete or ledger exhausted), report the total number of tests added, the count remaining pending, and the git log since the batch started.
