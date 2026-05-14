#!/usr/bin/env bash
# validate-plan-test.sh — Smoke-Tests für .claude/scripts/validate-plan.sh
# Usage: bash validate-plan-test.sh
# Exit: 0 = alle Tests grün, 1 = mindestens einer rot.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/.claude/scripts/validate-plan.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
FAILED_TESTS=()

run() {
  local name="$1" expected_exit="$2" expected_grep="$3" plan="$4"
  local out err actual
  out=$(mktemp); err=$(mktemp)
  bash "$VALIDATOR" "$plan" >"$out" 2>"$err"
  actual=$?
  local ok=1
  if [ "$actual" != "$expected_exit" ]; then
    ok=0
  fi
  if [ -n "$expected_grep" ]; then
    if ! grep -qE "$expected_grep" "$err" "$out"; then
      ok=0
    fi
  fi
  if [ "$ok" = "1" ]; then
    PASS=$((PASS+1))
    echo "  PASS  $name (exit=$actual)"
  else
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name")
    echo "  FAIL  $name (exit=$actual, expected=$expected_exit)"
    echo "    --- stderr ---"
    sed 's/^/    /' "$err"
    echo "    --- stdout ---"
    sed 's/^/    /' "$out"
  fi
  rm -f "$out" "$err"
}

echo "[validate-plan-test] Running fixtures from $FIXTURES"

# T1: valid table -> exit 0
run "T1 valid table (deals)" 0 "" "$FIXTURES/plan-valid-table.md"

# T2: bad table -> exit 1, message names the table
run "T2 unknown table (tracking_unicorn)" 1 "tracking_unicorn" "$FIXTURES/plan-bad-table.md"

# T3: [NEW]-marker -> exit 0
run "T3 [NEW]-marker on new table" 0 "" "$FIXTURES/plan-new-marker-table.md"

# T4: valid provider method
run "T4 valid provider method (InventoryProvider.loadData)" 0 "" "$FIXTURES/plan-valid-provider.md"

# T5: unknown provider method
run "T5 unknown provider method (unicornMethod)" 1 "unicornMethod" "$FIXTURES/plan-bad-provider.md"

# T6: empty plan
run "T6 empty plan file" 0 "" "$FIXTURES/plan-empty.md"

# T7: missing plan file
out=$(mktemp); err=$(mktemp)
bash "$VALIDATOR" "$FIXTURES/this-file-does-not-exist.md" >"$out" 2>"$err"
actual=$?
if [ "$actual" = "2" ] && grep -q "Usage:" "$err"; then
  PASS=$((PASS+1)); echo "  PASS  T7 missing plan file (exit=2 + Usage:)"
else
  FAIL=$((FAIL+1)); FAILED_TESTS+=("T7 missing plan file")
  echo "  FAIL  T7 missing plan file (exit=$actual)"
  sed 's/^/    /' "$err"
fi
rm -f "$out" "$err"

echo ""
echo "[validate-plan-test] $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  - %s\n' "${FAILED_TESTS[@]}"
  exit 1
fi
exit 0
