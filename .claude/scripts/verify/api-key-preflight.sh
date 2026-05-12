#!/usr/bin/env bash
# verify/api-key-preflight.sh — Tests for api-key-preflight.sh + yota-propose integration
#
# Tests:
#   T1: check_no_api_key — no env-var → exit 0, no output
#   T2: check_no_api_key — ANTHROPIC_API_KEY=fake → exit 1, stderr contains FATAL
#   T3: audit entry written when blocked (mock audit lib)
#   T4: yota-propose.sh "test" with ANTHROPIC_API_KEY=fake → exit 1
#   T5: yota-propose.sh without env-var runs to completion (writes proposal file)
#
# Exit 0 = all pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../lib/api-key-preflight.sh"
PROPOSE_SH="$SCRIPT_DIR/../yota-propose.sh"

if [ ! -f "$LIB" ]; then
  printf 'ERROR: api-key-preflight.sh not found: %s\n' "$LIB" >&2
  exit 1
fi

# ---- Helpers ----------------------------------------------------------------
_pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '\033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; FAILURES=$((FAILURES+1)); }

FAILURES=0

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# ---- T1: no env-var → exit 0, no stderr output ------------------------------
T1_OUT="$TMPDIR_BASE/t1_stderr"
(
  unset ANTHROPIC_API_KEY 2>/dev/null || true
  # Prevent any side-effects from repo root resolution
  CLAUDE_PROJECT_DIR="$TMPDIR_BASE"
  # shellcheck source=../lib/api-key-preflight.sh
  source "$LIB"
  check_no_api_key
) 2>"$T1_OUT"
T1_EXIT=$?

# Soft warning about missing auth.json is acceptable — only a FATAL line is a failure
T1_STDERR="$(cat "$T1_OUT")"
if [ "$T1_EXIT" -eq 0 ] && ! printf '%s' "$T1_STDERR" | grep -q "FATAL"; then
  _pass "T1: no env-var → exit 0, no FATAL in stderr"
else
  _fail "T1: no env-var" "exit=$T1_EXIT stderr=$T1_STDERR"
fi

# ---- T2: ANTHROPIC_API_KEY set → exit 1, stderr contains FATAL --------------
T2_OUT="$TMPDIR_BASE/t2_stderr"
(
  ANTHROPIC_API_KEY="fake-key-for-test"
  CLAUDE_PROJECT_DIR="$TMPDIR_BASE"
  # shellcheck source=../lib/api-key-preflight.sh
  source "$LIB"
  check_no_api_key
) 2>"$T2_OUT" ; T2_EXIT=$?

# check_no_api_key calls `exit 1` in the subshell
if [ "$T2_EXIT" -eq 1 ] && grep -q "FATAL" "$T2_OUT"; then
  _pass "T2: ANTHROPIC_API_KEY set → exit 1, FATAL in stderr"
else
  _fail "T2: ANTHROPIC_API_KEY set" "exit=$T2_EXIT stderr=$(cat "$T2_OUT")"
fi

# ---- T3: audit entry written when blocked (mock audit lib) ------------------
MOCK_AUDIT_DIR="$TMPDIR_BASE/mock-audit"
mkdir -p "$MOCK_AUDIT_DIR"
MOCK_AUDIT_CALLS="$MOCK_AUDIT_DIR/calls.txt"

# Create a fake project dir with a mock audit lib
MOCK_PROJECT="$TMPDIR_BASE/mock-project"
mkdir -p "$MOCK_PROJECT/.claude/scripts/lib"

cat > "$MOCK_PROJECT/.claude/scripts/lib/audit.sh" <<'MOCK'
#!/usr/bin/env bash
audit_record() {
  printf 'AUDIT_CALLED actor=%s action=%s subject=%s reason=%s\n' "$1" "$2" "$3" "${4:-}" \
    >> "${MOCK_AUDIT_CALLS:-/dev/null}"
}
MOCK

T3_OUT="$TMPDIR_BASE/t3_stderr"
(
  ANTHROPIC_API_KEY="fake-key-for-test"
  CLAUDE_PROJECT_DIR="$MOCK_PROJECT"
  MOCK_AUDIT_CALLS="$MOCK_AUDIT_CALLS"
  export MOCK_AUDIT_CALLS
  # Source the real lib (it will pick up mock audit from CLAUDE_PROJECT_DIR)
  source "$LIB"
  check_no_api_key
) 2>"$T3_OUT" ; T3_EXIT=$?

if [ "$T3_EXIT" -eq 1 ] && grep -q "intake_api_key_blocked" "$MOCK_AUDIT_CALLS" 2>/dev/null; then
  _pass "T3: audit_record called with intake_api_key_blocked"
else
  _fail "T3: audit entry" "exit=$T3_EXIT audit_file=$(cat "$MOCK_AUDIT_CALLS" 2>/dev/null || echo '<absent>')"
fi

# ---- T4: yota-propose.sh with ANTHROPIC_API_KEY=fake → exit 1 ---------------
if [ ! -f "$PROPOSE_SH" ]; then
  _fail "T4: yota-propose.sh not found" "path=$PROPOSE_SH"
  _fail "T5: yota-propose.sh not found" "path=$PROPOSE_SH"
else
  T4_ERR="$TMPDIR_BASE/t4_stderr"
  ANTHROPIC_API_KEY="fake-key-for-test" \
    CLAUDE_PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)" \
    bash "$PROPOSE_SH" "test proposal" 2>"$T4_ERR" >/dev/null ; T4_EXIT=$?

  if [ "$T4_EXIT" -eq 1 ] && grep -q "FATAL" "$T4_ERR"; then
    _pass "T4: yota-propose with ANTHROPIC_API_KEY=fake → exit 1"
  else
    _fail "T4: yota-propose integration" "exit=$T4_EXIT stderr=$(cat "$T4_ERR")"
  fi

  # ---- T5: yota-propose.sh without env-var → writes proposal file ------------
  T5_PROPOSAL_DIR="$TMPDIR_BASE/t5-proposals"
  T5_OUT="$TMPDIR_BASE/t5_stdout"
  T5_ERR="$TMPDIR_BASE/t5_stderr"

  # We need a minimal repo layout so slug/audit libs resolve
  REPO_ROOT_REAL="$(cd "$SCRIPT_DIR/../../.." && pwd)"

  unset ANTHROPIC_API_KEY 2>/dev/null || true
  # Use unique text (timestamp + random) to avoid content-dedup rejection across runs
  T5_UNIQUE_TEXT="t5 integration test $(date -u +%s%N 2>/dev/null || date -u +%s)-$$-$RANDOM"
  PROPOSAL_DIR="$T5_PROPOSAL_DIR" \
    CLAUDE_PROJECT_DIR="$REPO_ROOT_REAL" \
    bash "$PROPOSE_SH" "$T5_UNIQUE_TEXT" >"$T5_OUT" 2>"$T5_ERR" ; T5_EXIT=$?

  # Exit 0 and outfile exists
  T5_OUTFILE="$(cat "$T5_OUT" 2>/dev/null || true)"
  if [ "$T5_EXIT" -eq 0 ] && [ -n "$T5_OUTFILE" ] && [ -f "$T5_OUTFILE" ]; then
    _pass "T5: yota-propose without env-var → exit 0, proposal file written"
  else
    _fail "T5: yota-propose no env-var" "exit=$T5_EXIT outfile='$T5_OUTFILE' stderr=$(cat "$T5_ERR")"
  fi
fi

# ---- Summary ----------------------------------------------------------------
if [ "$FAILURES" -eq 0 ]; then
  printf '\n\033[32mAll tests passed.\033[0m\n'
  exit 0
else
  printf '\n\033[31m%d test(s) FAILED.\033[0m\n' "$FAILURES"
  exit 1
fi
