#!/usr/bin/env bash
#
# .scripts/generate-aal1-matrix.sh — emit docs/AAL1/conformance.md from the ledger.
#
# Phase 1 stub: emits a skeleton document with a header and an empty table when
# the ledger is empty. Phase 4 will flesh out clause lookup, test-result joining,
# and enforcement-source extraction.
#
# Usage:
#   .scripts/generate-aal1-matrix.sh            # writes docs/AAL1/conformance.md
#   .scripts/generate-aal1-matrix.sh --check    # exits non-zero if committed copy
#                                                 differs from a fresh regeneration
#
# CI uses --check on every PR to prevent matrix drift.

set -euo pipefail
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEDGER="$ROOT/docs/AAL1/requirements.yaml"
OUT="$ROOT/docs/AAL1/conformance.md"

fail() { echo "generate-aal1-matrix FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "yq not found (install via 'brew install yq')"
[ -f "$LEDGER" ] || fail "ledger not found at $LEDGER"

MODE="write"
if [ "${1:-}" = "--check" ]; then
    MODE="check"
fi

META_SOURCE="$(yq eval '.meta.source' "$LEDGER")"
META_VERSION="$(yq eval '.meta.passage_version_claimed' "$LEDGER")"
META_RETRIEVED="$(yq eval '.meta.retrieved' "$LEDGER")"
REQ_COUNT="$(yq eval '.requirements | length' "$LEDGER")"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

{
    echo "# AAL1 Conformance Matrix"
    echo
    echo "> **Generated artifact.** Do not hand-edit. Regenerate via \`.scripts/generate-aal1-matrix.sh\`."
    echo
    echo "- **Source spec:** $META_SOURCE"
    echo "- **Passage version claimed:** ${META_VERSION}"
    echo "- **Spec retrieved:** ${META_RETRIEVED}"
    echo "- **Clauses in ledger:** $REQ_COUNT"
    echo
    echo "## Clause-by-clause"
    echo
    echo "| Clause | Normative | Testability | Status | Tests | Requirement |"
    echo "|---|---|---|---|---|---|"

    if [ "$REQ_COUNT" -eq 0 ]; then
        echo "| *(empty — run /aal1-decompose to populate)* | | | | | |"
    else
        # Phase 4 will expand this to include real columns joined with test-run results.
        yq eval -r '.requirements[] | [.id, .normative, .testability, .status, (.tests | join(", ")), (.requirement | sub("\n"; " ") | sub("\\|"; "\\|"))] | "| §" + .[0] + " | " + .[1] + " | " + .[2] + " | " + .[3] + " | " + .[4] + " | " + .[5] + " |"' "$LEDGER"
    fi

    echo
    echo "## Legend"
    echo
    echo "- **Testability.** \`testable\` = runtime test proves enforcement; \`design-assertion\` = architectural attestation (see [attestations.md](./attestations.md)); \`excluded\` = out of scope for Passage (integrator responsibility or layered elsewhere)."
    echo "- **Status.** \`pending\` = no test yet; \`has_test\` = test landed (pass/fail determined at test run, not from this file); \`excluded\` = no test by design."
    echo
    echo "See [CLAIM.md](./CLAIM.md) for the self-assertion narrative; see [requirements.yaml](./requirements.yaml) for the ledger this matrix is derived from."
} > "$TMP"

case "$MODE" in
    write)
        mv "$TMP" "$OUT"
        echo "generate-aal1-matrix: wrote $OUT"
        ;;
    check)
        if ! diff -q "$OUT" "$TMP" >/dev/null 2>&1; then
            echo "generate-aal1-matrix FAIL: committed $OUT is stale relative to the ledger." >&2
            echo "Run .scripts/generate-aal1-matrix.sh to regenerate." >&2
            diff "$OUT" "$TMP" >&2 || true
            exit 1
        fi
        echo "generate-aal1-matrix: $OUT is up to date"
        ;;
esac
