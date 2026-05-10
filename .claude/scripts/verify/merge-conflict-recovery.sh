#!/usr/bin/env bash
# verify/merge-conflict-recovery.sh — Sandbox verification for merge-retry.sh (P3-11).
#
# All tests run against an isolated sandbox with mock gh + git stubs.
# Tests:
#   1. Happy merge: mock-gh exit 0 → function returns 0
#   2. Conflict + Rebase-success: mock-gh fails first, rebase succeeds → returns 0
#   3. Conflict + Rebase-fail: mock rebase fails with conflict → returns 2 + stderr
#   4. [merge-conflict] marker: on exit 2, release_item puts item back in inbox with marker
#   5. --admin absent from default path: no MERGE_ADMIN_OVERRIDE → gh called without --admin
#   6. MERGE_ADMIN_OVERRIDE=1: --admin appears in gh args
#   7. Stakeholder-Override audit: MERGE_ADMIN_OVERRIDE=1 + audit_record call logged
#
# Exit 0 if all tests pass.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${SCRIPTS_DIR}/lib"

MERGE_RETRY_LIB="${LIB_DIR}/merge-retry.sh"
PICKER_LIB="${LIB_DIR}/picker.sh"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
ERRORS=()

_pass() { printf '  [PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() {
  printf '  [FAIL] %s\n' "$1"
  ERRORS+=("$1")
  FAIL=$(( FAIL + 1 ))
}
_section() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------------------
# Sandbox setup
# ---------------------------------------------------------------------------
SANDBOX_ROOT="$(mktemp -d)"
_cleanup_sandbox() {
  # Remove immutable flags (audit.sh sets chflags uchg on macOS)
  chflags -R nouchg "$SANDBOX_ROOT" 2>/dev/null || true
  chmod -R u+w "$SANDBOX_ROOT" 2>/dev/null || true
  rm -rf "$SANDBOX_ROOT" 2>/dev/null || true
}
trap '_cleanup_sandbox' EXIT

# Minimal git repo for audit.sh and picker.sh
git -C "$SANDBOX_ROOT" init -q
git -C "$SANDBOX_ROOT" config user.email "test@test.com"
git -C "$SANDBOX_ROOT" config user.name "Test"
echo "init" > "${SANDBOX_ROOT}/README.md"
git -C "$SANDBOX_ROOT" add README.md
git -C "$SANDBOX_ROOT" commit -q -m "init"

export CLAUDE_PROJECT_DIR="$SANDBOX_ROOT"

# Overseer dirs
OVERSEER_DIR="${SANDBOX_ROOT}/.claude/overseer"
INBOX_DIR="${OVERSEER_DIR}/inbox"
INPROGRESS_DIR="${OVERSEER_DIR}/in_progress"
mkdir -p "$INBOX_DIR" "$INPROGRESS_DIR" "${OVERSEER_DIR}/done" "${OVERSEER_DIR}/failed"

# Mock bin dir (prepended to PATH so our stubs shadow real gh/git)
MOCK_BIN="${SANDBOX_ROOT}/mock-bin"
mkdir -p "$MOCK_BIN"

# Resolve real git before prepending mock-bin to PATH (avoids stub self-loop)
REAL_GIT="$(command -v git)"

# Worktree dir (must be a real dir with a .git for git -C to work on)
FAKE_WORKTREE="${SANDBOX_ROOT}/worktree"
mkdir -p "$FAKE_WORKTREE"
git -C "$FAKE_WORKTREE" init -q
git -C "$FAKE_WORKTREE" config user.email "test@test.com"
git -C "$FAKE_WORKTREE" config user.name "Test"
echo "x" > "${FAKE_WORKTREE}/x.txt"
git -C "$FAKE_WORKTREE" add x.txt
git -C "$FAKE_WORKTREE" commit -q -m "init"

# Create a fake origin/main ref for the worktree
git -C "$FAKE_WORKTREE" remote add origin "${SANDBOX_ROOT}" 2>/dev/null || true

# GH call-log
GH_LOG="${SANDBOX_ROOT}/gh-calls.log"

# Helper: create mock gh with configurable behavior
_setup_mock_gh() {
  local behavior="$1"   # success | conflict_then_success | conflict_fail
  cat > "${MOCK_BIN}/gh" <<STUB
#!/usr/bin/env bash
# Log all args
echo "gh \$@" >> "${GH_LOG}"
case "${behavior}" in
  success)
    exit 0
    ;;
  conflict_then_success)
    # First call exits with conflict error, subsequent calls succeed
    CALL_COUNT_FILE="${SANDBOX_ROOT}/gh-call-count"
    count=0
    [ -f "\$CALL_COUNT_FILE" ] && count=\$(cat "\$CALL_COUNT_FILE")
    count=\$(( count + 1 ))
    echo "\$count" > "\$CALL_COUNT_FILE"
    if [ "\$count" -eq 1 ]; then
      echo "GraphQL: Merge conflict detected — branches have diverged" >&2
      exit 1
    fi
    exit 0
    ;;
  conflict_fail)
    echo "GraphQL: Merge conflict detected — branches have diverged" >&2
    exit 1
    ;;
esac
STUB
  chmod +x "${MOCK_BIN}/gh"
  rm -f "${SANDBOX_ROOT}/gh-call-count"
  > "$GH_LOG"
}

# Helper: mock git for rebase behavior
_setup_mock_git() {
  local rebase_behavior="$1"  # success | conflict
  cat > "${MOCK_BIN}/git" <<STUB
#!/usr/bin/env bash
# Intercept rebase calls; pass everything else to real git
if [[ "\$*" == *"rebase"* ]] && [[ "\$*" != *"--abort"* ]]; then
  echo "git \$@" >> "${GH_LOG}"
  case "${rebase_behavior}" in
    success)
      exit 0
      ;;
    conflict)
      echo "CONFLICT (content): Merge conflict in x.txt" >&2
      exit 1
      ;;
  esac
fi
# For fetch — succeed silently (we don't actually need real fetch in tests)
if [[ "\$*" == *"fetch"* ]]; then
  echo "git \$@" >> "${GH_LOG}"
  exit 0
fi
# For push --force-with-lease — succeed
if [[ "\$*" == *"push"* ]]; then
  echo "git \$@" >> "${GH_LOG}"
  exit 0
fi
# For rebase --abort
if [[ "\$*" == *"rebase --abort"* ]]; then
  echo "git \$@" >> "${GH_LOG}"
  exit 0
fi
# All other git commands: delegate to real git
exec "${REAL_GIT}" "\$@"
STUB
  chmod +x "${MOCK_BIN}/git"
}

# Helper: create a fake in_progress item
_create_fake_item() {
  local name="$1"
  local path="${INPROGRESS_DIR}/${name}.12345.md"
  cat > "$path" <<'YAML'
---
title: Test item
touches:
  - lib/test/
---
Test item body.
YAML
  echo "$path"
}

# ---------------------------------------------------------------------------
# Test 1: Happy merge (mock-gh exit 0 → function exit 0)
# ---------------------------------------------------------------------------
_section "Test 1: Happy merge"

_setup_mock_gh "success"
unset GIT  # ensure we use real git path
export PATH="${MOCK_BIN}:${PATH}"

(
  source "$MERGE_RETRY_LIB"
  unset MERGE_ADMIN_OVERRIDE
  auto_merge_with_retry "42" "/fake/item.md" "$FAKE_WORKTREE"
) 2>/dev/null
EXIT1=$?

if [ "$EXIT1" -eq 0 ]; then
  _pass "Happy merge: exit 0"
else
  _fail "Happy merge: expected exit 0, got ${EXIT1}"
fi

# Verify no rebase was attempted
if grep -q "rebase" "$GH_LOG" 2>/dev/null; then
  _fail "Happy merge: rebase should NOT be attempted on success"
else
  _pass "Happy merge: no rebase on success"
fi

# ---------------------------------------------------------------------------
# Test 2: Conflict + Rebase-success → exit 0
# ---------------------------------------------------------------------------
_section "Test 2: Conflict + Rebase-success"

_setup_mock_gh "conflict_then_success"
_setup_mock_git "success"

(
  source "$MERGE_RETRY_LIB"
  unset MERGE_ADMIN_OVERRIDE
  auto_merge_with_retry "43" "/fake/item.md" "$FAKE_WORKTREE"
) 2>/dev/null
EXIT2=$?

if [ "$EXIT2" -eq 0 ]; then
  _pass "Conflict+Rebase-success: exit 0"
else
  _fail "Conflict+Rebase-success: expected exit 0, got ${EXIT2}"
fi

# Verify fetch + rebase + push were attempted
if grep -q "fetch" "$GH_LOG" 2>/dev/null; then
  _pass "Conflict+Rebase-success: git fetch called"
else
  _fail "Conflict+Rebase-success: git fetch not found in log"
fi

if grep -q "rebase" "$GH_LOG" 2>/dev/null; then
  _pass "Conflict+Rebase-success: git rebase called"
else
  _fail "Conflict+Rebase-success: git rebase not found in log"
fi

if grep -q "push" "$GH_LOG" 2>/dev/null; then
  _pass "Conflict+Rebase-success: git push called"
else
  _fail "Conflict+Rebase-success: git push not found in log"
fi

# ---------------------------------------------------------------------------
# Test 3: Conflict + Rebase-fail → exit 2 + stderr message
# ---------------------------------------------------------------------------
_section "Test 3: Conflict + Rebase-fail"

_setup_mock_gh "conflict_fail"
_setup_mock_git "conflict"

EXIT3_FILE="${SANDBOX_ROOT}/exit3"
STDERR3="$(
  (
    source "$MERGE_RETRY_LIB"
    unset MERGE_ADMIN_OVERRIDE
    set +e
    auto_merge_with_retry "44" "/fake/item.md" "$FAKE_WORKTREE"
    printf '%s' "$?" > "$EXIT3_FILE"
  ) 2>&1
)"
EXIT3="$(cat "$EXIT3_FILE" 2>/dev/null || printf '99')"

if [ "$EXIT3" -eq 2 ]; then
  _pass "Conflict+Rebase-fail: exit 2"
else
  _fail "Conflict+Rebase-fail: expected exit 2, got ${EXIT3}"
fi

if printf '%s' "$STDERR3" | grep -qi "conflict\|merge-conflict\|not auto-resolvable"; then
  _pass "Conflict+Rebase-fail: stderr contains conflict message"
else
  _fail "Conflict+Rebase-fail: stderr missing conflict message. Got: ${STDERR3}"
fi

# ---------------------------------------------------------------------------
# Test 4: [merge-conflict] marker — release_item on exit 2 → item in inbox
# ---------------------------------------------------------------------------
_section "Test 4: [merge-conflict] marker in inbox after exit 2"

_setup_mock_gh "conflict_fail"
_setup_mock_git "conflict"

ITEM4="$(_create_fake_item "00-test-task")"

(
  source "$MERGE_RETRY_LIB"
  source "$PICKER_LIB"
  unset MERGE_ADMIN_OVERRIDE

  set +e
  auto_merge_with_retry "45" "$ITEM4" "$FAKE_WORKTREE"
  MEXIT=$?
  set -e

  if [ "$MEXIT" -eq 2 ]; then
    release_item "$ITEM4" "merge-conflict"
  fi
) 2>/dev/null

# Check that inbox has a [merge-conflict]-prefixed file
# Use ls + grep instead of find glob to avoid shell bracket-expansion issues
MARKER_FILE="$(ls "$INBOX_DIR"/ 2>/dev/null | grep -F '[merge-conflict]-' | head -1 || true)"
if [ -n "$MARKER_FILE" ]; then
  _pass "[merge-conflict] marker: item found in inbox: ${MARKER_FILE}"
else
  _fail "[merge-conflict] marker: no [merge-conflict]-prefixed file in inbox"
fi

# Original item no longer in in_progress
if [ ! -f "$ITEM4" ]; then
  _pass "[merge-conflict] marker: original item removed from in_progress"
else
  _fail "[merge-conflict] marker: original item still in in_progress"
fi

# Clean up for subsequent tests
rm -f "$MARKER_FILE" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Test 5: --admin absent from default gh call
# ---------------------------------------------------------------------------
_section "Test 5: --admin absent from default (no MERGE_ADMIN_OVERRIDE)"

_setup_mock_gh "success"

(
  source "$MERGE_RETRY_LIB"
  unset MERGE_ADMIN_OVERRIDE
  auto_merge_with_retry "46" "/fake/item.md" "$FAKE_WORKTREE"
) 2>/dev/null

if grep -q "\-\-admin" "$GH_LOG" 2>/dev/null; then
  _fail "Default path: --admin found in gh call (should NOT be present)"
else
  _pass "Default path: --admin absent from gh call"
fi

# Verify --squash and --delete-branch ARE present
if grep -q "\-\-squash" "$GH_LOG" 2>/dev/null && grep -q "\-\-delete-branch" "$GH_LOG" 2>/dev/null; then
  _pass "Default path: --squash and --delete-branch present"
else
  _fail "Default path: --squash or --delete-branch missing from gh call"
fi

# ---------------------------------------------------------------------------
# Test 6: MERGE_ADMIN_OVERRIDE=1 → --admin in gh call
# ---------------------------------------------------------------------------
_section "Test 6: MERGE_ADMIN_OVERRIDE=1 → --admin in gh call"

_setup_mock_gh "success"

(
  source "$MERGE_RETRY_LIB"
  export MERGE_ADMIN_OVERRIDE=1
  auto_merge_with_retry "47" "/fake/item.md" "$FAKE_WORKTREE"
) 2>/dev/null

if grep -q "\-\-admin" "$GH_LOG" 2>/dev/null; then
  _pass "MERGE_ADMIN_OVERRIDE=1: --admin present in gh call"
else
  _fail "MERGE_ADMIN_OVERRIDE=1: --admin missing from gh call"
fi

# ---------------------------------------------------------------------------
# Test 7: Stakeholder-Override path — MERGE_ADMIN_OVERRIDE=1 + audit log
# ---------------------------------------------------------------------------
_section "Test 7: Stakeholder-Override: MERGE_ADMIN_OVERRIDE=1 audit notification"

_setup_mock_gh "success"

STDERR7="$(
  (
    source "$MERGE_RETRY_LIB"
    export MERGE_ADMIN_OVERRIDE=1
    auto_merge_with_retry "48" "/fake/item.md" "$FAKE_WORKTREE"
  ) 2>&1 || true
)"

# merge-retry.sh logs a warning to stderr when --admin is active
if printf '%s' "$STDERR7" | grep -qi "MERGE_ADMIN_OVERRIDE\|--admin"; then
  _pass "Stakeholder-Override: --admin activation logged to stderr"
else
  _fail "Stakeholder-Override: no --admin mention in stderr. Got: ${STDERR7}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=============================\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed tests:\n'
  for e in "${ERRORS[@]}"; do
    printf '  - %s\n' "$e"
  done
  exit 1
fi

printf 'All tests passed.\n'
exit 0
