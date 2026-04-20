---
description: Run /aal1-add in an autonomous Ralph loop until the AAL1 ledger is exhausted
argument-hint: (none)
allowed-tools: Read, Bash(yq:*), Bash(ls:*), Bash(cat:*), Bash(.claude/commands/aal1-add.md:*)
---

You are starting a Ralph loop that autonomously iterates `/aal1-add 1` until every testable clause in `docs/AAL1/requirements.yaml` has a corresponding test.

**Pre-flight checks (abort on any failure).**

1. **No competing Ralph loop.** Check for an existing state file at `.claude/ralph-loop.local.md`. If it exists AND its frontmatter `completion_promise` is not `AAL1_TESTS_COMPLETE`, abort with a message telling the user to run `/cancel-ralph` first. A second Ralph loop on a different task would overwrite this one's state.

2. **Ledger is populated.** Run:
   ```bash
   yq eval '.requirements | length' docs/AAL1/requirements.yaml
   ```
   If the result is `0`, abort with a message directing the user to run `/aal1-decompose` first.

3. **Clean working tree.** Run `git status --porcelain`; abort if non-empty. The loop relies on each iteration starting from a clean state so commit-per-test atomicity is meaningful.

**Compute iteration budget.**

```bash
PENDING=$(yq eval '[.requirements[] | select(.status == "pending" and .testability != "excluded")] | length' docs/AAL1/requirements.yaml)
BUDGET=$((PENDING + 20))
```

The +20 is a safety buffer for retries if a Ralph iteration fails to commit.

**Start the loop.**

Invoke the global `/ralph-loop` command with:
- Task prompt: `/aal1-add 1`
- Completion promise: `AAL1_TESTS_COMPLETE`
- Max iterations: `$BUDGET`

Pass these via the standard `/ralph-loop` invocation. The ralph-loop plugin's Stop hook will re-feed `/aal1-add 1` until `/aal1-add` itself emits `<promise>AAL1_TESTS_COMPLETE</promise>` after verifying the ledger is exhausted.

**What the user sees.**

Between iterations the ralph-loop plugin resumes the session automatically; each iteration's log is the output of one `/aal1-add 1` run (a per-clause status line plus a `git commit` summary). When the loop completes, the state file is archived and a final message confirms completion.

**Stopping early.**

The user can interrupt at any time by running `/cancel-ralph`. In-progress iteration is preserved — every completed test is already committed.
