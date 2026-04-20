#!/usr/bin/env bash
#
# .scripts/aal1-lint.sh — validator for the AAL1 test ledger.
#
# Checks performed:
#   1. docs/AAL1/requirements.yaml exists and has the expected top-level shape.
#   2. Every @Test string in Tests/PassageTests/AAL1/*.swift begins with a
#      §<clause-id>(,§<clause-id>)*: prefix (clause ID format matches the ledger).
#   3. Every clause ID referenced in a test exists in requirements.yaml (no orphans).
#   4. Every ledger record with status == has_test lists at least one test reference.
#   5. Every test reference in a ledger record points to a file that exists on disk.
#
# Exit code: 0 on success, non-zero with a human-readable reason on any violation.
#
# Invoked by /aal1-add as part of its iteration success check, and by CI on
# every PR. Requires: bash 4+, yq, python3 (available on macOS by default),
# UTF-8 locale (for the § literal).

set -euo pipefail
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEDGER="$ROOT/docs/AAL1/requirements.yaml"
TESTS_DIR="$ROOT/Tests/PassageTests/AAL1"

fail() { echo "aal1-lint FAIL: $*" >&2; exit 1; }
info() { echo "aal1-lint: $*"; }

command -v yq >/dev/null 2>&1 || fail "yq not found (install via 'brew install yq')"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

# ---------------------------------------------------------------------------
# Check 1 — ledger exists and has the expected top-level shape
# ---------------------------------------------------------------------------
[ -f "$LEDGER" ] || fail "ledger not found at $LEDGER"
yq eval '.' "$LEDGER" >/dev/null 2>&1 || fail "ledger at $LEDGER is not valid YAML"

META_SOURCE="$(yq eval '.meta.source' "$LEDGER")"
[ "$META_SOURCE" != "null" ] && [ -n "$META_SOURCE" ] || fail "ledger missing meta.source"

REQ_TYPE="$(yq eval '.requirements | type' "$LEDGER")"
[ "$REQ_TYPE" = "!!seq" ] || fail "ledger requirements is not a sequence (got: $REQ_TYPE)"

# ---------------------------------------------------------------------------
# Check 2 & 3 — @Test prefix format and cross-reference to ledger
# ---------------------------------------------------------------------------
# Gather the set of IDs declared in the ledger (for the orphan check)
LEDGER_IDS_FILE="$(mktemp)"
trap 'rm -f "$LEDGER_IDS_FILE"' EXIT
yq eval '.requirements[].id' "$LEDGER" | grep -v '^null$' | sort -u > "$LEDGER_IDS_FILE" || true

# Delegate Swift-file scanning to python3 for robust multi-line @Test parsing
SCAN_OUTPUT="$(
  python3 - "$TESTS_DIR" "$LEDGER_IDS_FILE" <<'PY'
import pathlib, re, sys

tests_dir, ledger_ids_file = sys.argv[1], sys.argv[2]
ledger_ids = set(pathlib.Path(ledger_ids_file).read_text().split())

# Match the first string literal argument to @Test(...).
# The @Test macro accepts the display-name string as its first positional arg.
# We match "@Test(" followed by optional whitespace/newlines, then a quoted string.
test_re = re.compile(r'@Test\s*\(\s*"((?:[^"\\]|\\.)*)"', re.MULTILINE)
# Clause prefix: §N(.N)*(-a)?(,§N(.N)*(-a)?)*: (trailing space)
prefix_re = re.compile(r'^(§\d+(?:\.\d+)*(?:-[a-z])?)(,§\d+(?:\.\d+)*(?:-[a-z])?)*:\s')
id_re = re.compile(r'§(\d+(?:\.\d+)*(?:-[a-z])?)')

violations = []
referenced_ids = set()

for swift in sorted(pathlib.Path(tests_dir).rglob("*.swift")):
    text = swift.read_text(encoding="utf-8")
    # Strip // line comments and /* block comments to avoid matching example
    # @Test strings that live in commented-out scaffolding.
    text_nocmt = re.sub(r'//[^\n]*', '', text)
    text_nocmt = re.sub(r'/\*.*?\*/', '', text_nocmt, flags=re.DOTALL)
    for m in test_re.finditer(text_nocmt):
        display = m.group(1)
        if not prefix_re.match(display):
            violations.append(f"{swift}: @Test string missing §<id>: prefix: {display!r}")
            continue
        for cid in id_re.findall(display):
            referenced_ids.add(cid)

orphans = sorted(referenced_ids - ledger_ids)
for cid in orphans:
    violations.append(f"orphan test reference: §{cid} not found in ledger")

if violations:
    for v in violations:
        print(v)
    sys.exit(1)

# Emit referenced IDs so the parent shell can report on coverage
for cid in sorted(referenced_ids):
    print(f"REF §{cid}")
PY
)" || fail "test-prefix validation failed:\n$SCAN_OUTPUT"

# ---------------------------------------------------------------------------
# Check 4 — has_test clauses must have at least one tests[] entry
# ---------------------------------------------------------------------------
HAS_TEST_EMPTY="$(yq eval '.requirements[] | select(.status == "has_test" and (.tests | length == 0)) | .id' "$LEDGER" | grep -v '^null$' || true)"
if [ -n "$HAS_TEST_EMPTY" ]; then
    fail "clauses marked has_test with empty tests[]:\n$HAS_TEST_EMPTY"
fi

# ---------------------------------------------------------------------------
# Check 5 — tests[] references point to real files
# ---------------------------------------------------------------------------
TEST_REFS="$(yq eval '.requirements[].tests[]' "$LEDGER" 2>/dev/null | grep -v '^null$' || true)"
if [ -n "$TEST_REFS" ]; then
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        file_part="${ref%%::*}"
        full_path="$ROOT/Tests/PassageTests/$file_part"
        [ -f "$full_path" ] || fail "ledger references missing file: $file_part (from ref: $ref)"
    done <<< "$TEST_REFS"
fi

info "ledger at docs/AAL1/requirements.yaml: OK"
info "all AAL1 @Test strings have valid §<id>: prefixes"
exit 0
