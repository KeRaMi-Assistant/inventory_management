#!/usr/bin/env bash
# verify/worktree.sh — Sandbox tests for .claude/scripts/lib/worktree.sh
# Exits 0 if all tests pass, 1 if any fail.
#
# Limitations documented:
#   - Disk-Cap real test: uses MOCK_DISK_FREE_GB env override
#   - flutter analyze + smoke-login: deferred to Phase-1-Integration
#     (requires .env.test with real credentials + running web app)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"

# ---------------------------------------------------------------------------
# Test framework
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

_pass() { echo "  PASS: $1"; (( PASS++ )) || true; }
_fail() { echo "  FAIL: $1"; (( FAIL++ )) || true; }
_section() { echo; echo "=== $1 ==="; }

# ---------------------------------------------------------------------------
# Setup: mktemp sandbox git repo
# ---------------------------------------------------------------------------
_section "Setup: sandbox git repo"

SANDBOX_DIR=$(mktemp -d)
trap 'rm -rf "$SANDBOX_DIR"' EXIT

# Init a minimal git repo
git -C "$SANDBOX_DIR" init -q
git -C "$SANDBOX_DIR" config user.email "test@test.local"
git -C "$SANDBOX_DIR" config user.name "Test"
echo "initial" > "$SANDBOX_DIR/README.md"
git -C "$SANDBOX_DIR" add README.md
git -C "$SANDBOX_DIR" commit -q -m "init"

echo "Sandbox: $SANDBOX_DIR"

# ---------------------------------------------------------------------------
# Source the library (with REPO_ROOT override for sandbox)
# ---------------------------------------------------------------------------

# We cd into the sandbox so _worktree_repo_root() returns SANDBOX_DIR
pushd "$SANDBOX_DIR" > /dev/null

# Patch: override the internal function to return our sandbox root
# by running tests from within the sandbox dir
source "${LIB_DIR}/worktree.sh"

# ---------------------------------------------------------------------------
# Test 1: worktree_create test-a → exit 0, worktree exists
# ---------------------------------------------------------------------------
_section "Test 1: worktree_create test-a"
result=$(worktree_create "test-a" 2>&1)
exit_code=$?
wt_a="${SANDBOX_DIR}_worker_test-a"
if [[ $exit_code -eq 0 ]] && [[ -d "$wt_a" ]]; then
  _pass "test-a created at $wt_a"
else
  _fail "test-a failed (exit $exit_code, result: $result)"
fi

# ---------------------------------------------------------------------------
# Test 2: worktree_create test-b → exit 0
# ---------------------------------------------------------------------------
_section "Test 2: worktree_create test-b"
result=$(worktree_create "test-b" 2>&1)
exit_code=$?
wt_b="${SANDBOX_DIR}_worker_test-b"
if [[ $exit_code -eq 0 ]] && [[ -d "$wt_b" ]]; then
  _pass "test-b created at $wt_b"
else
  _fail "test-b failed (exit $exit_code, result: $result)"
fi

# ---------------------------------------------------------------------------
# Test 3: worktree_create test-c → exit 0 (3rd worktree, at hard-cap)
# ---------------------------------------------------------------------------
_section "Test 3: worktree_create test-c (3rd, at cap)"
result=$(worktree_create "test-c" 2>&1)
exit_code=$?
wt_c="${SANDBOX_DIR}_worker_test-c"
if [[ $exit_code -eq 0 ]] && [[ -d "$wt_c" ]]; then
  _pass "test-c created at $wt_c (count now at cap=3)"
else
  _fail "test-c failed (exit $exit_code, result: $result)"
fi

# ---------------------------------------------------------------------------
# Test 4: worktree_create test-d → exit 3 (hard-cap exceeded)
# ---------------------------------------------------------------------------
_section "Test 4: worktree_create test-d → exit 3 (hard-cap)"
result=$(worktree_create "test-d" 2>&1) || exit_code=$?
if [[ ${exit_code:-0} -eq 3 ]]; then
  _pass "test-d correctly rejected with exit 3"
else
  _fail "test-d should have exited 3, got exit ${exit_code:-0} (result: $result)"
fi

# ---------------------------------------------------------------------------
# Test 5: Symlink-Check
# ---------------------------------------------------------------------------
_section "Test 5: Symlink strategy for .env.test"

# Remove test-a, test-b, test-c to free up slots
worktree_remove "test-a" 2>/dev/null || true
worktree_remove "test-b" 2>/dev/null || true
worktree_remove "test-c" 2>/dev/null || true

# Create a .env.test in the sandbox repo
echo "SUPABASE_URL=mock" > "${SANDBOX_DIR}/.env.test"

# Create worktree test-e
result=$(worktree_create "test-e" 2>&1)
exit_code=$?
wt_e="${SANDBOX_DIR}_worker_test-e"

if [[ $exit_code -ne 0 ]]; then
  _fail "test-e creation failed (exit $exit_code, result: $result)"
else
  # Check no real .env* files (only symlinks)
  real_files=$(find "$wt_e" -maxdepth 1 -name '.env*' -type f 2>/dev/null || true)
  if [[ -z "$real_files" ]]; then
    _pass "no real .env* files in worktree (only symlinks)"
  else
    _fail "found real .env* files: $real_files"
  fi

  # Check symlink points to sandbox's .env.test
  # Use readlink -f to resolve macOS /var → /private/var symlinks
  symlink_target=$(readlink "${wt_e}/.env.test" 2>/dev/null || echo "")
  symlink_resolved=$(readlink -f "${wt_e}/.env.test" 2>/dev/null || echo "")
  sandbox_real=$(cd "$SANDBOX_DIR" && pwd -P)  # resolve /var → /private/var on macOS
  if [[ -n "$symlink_target" ]] && [[ "$symlink_resolved" == "${sandbox_real}/.env.test" ]]; then
    _pass "symlink .env.test → $symlink_target (resolves to $symlink_resolved)"
  else
    _fail "symlink target wrong: expected '${sandbox_real}/.env.test', got '${symlink_resolved}' (raw: '${symlink_target}')"
  fi
fi

# ---------------------------------------------------------------------------
# Test 6: worktree_remove test-e → exit 0, worktree gone, no .dart_tool/ rückstand
# ---------------------------------------------------------------------------
_section "Test 6: worktree_remove test-e"

# Create some fake artifacts first
if [[ -d "$wt_e" ]]; then
  mkdir -p "${wt_e}/.dart_tool"
  mkdir -p "${wt_e}/build"
  touch "${wt_e}/.flutter-plugins-dependencies"
fi

worktree_remove "test-e"
exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ ! -d "$wt_e" ]]; then
  _pass "test-e removed, worktree dir gone"
else
  _fail "test-e removal failed (exit $exit_code, dir exists: $(test -d "$wt_e" && echo yes || echo no))"
fi

# Check no .dart_tool rückstand in parent dir
if [[ ! -d "${wt_e}/.dart_tool" ]]; then
  _pass "no .dart_tool rückstand"
else
  _fail ".dart_tool still exists"
fi

# ---------------------------------------------------------------------------
# Test 7: Disk-Cap via MOCK_DISK_FREE_GB=10 → exit 4
# ---------------------------------------------------------------------------
_section "Test 7: Disk-Cap mock (MOCK_DISK_FREE_GB=10)"

exit_code=0
result=$(MOCK_DISK_FREE_GB=10 worktree_create "test-disk" 2>&1) || exit_code=$?
if [[ $exit_code -eq 4 ]]; then
  _pass "disk-cap correctly rejected with exit 4 (MOCK_DISK_FREE_GB=10)"
else
  _fail "disk-cap test failed (exit $exit_code, result: $result)"
fi

# Also test percent mock
exit_code=0
result=$(MOCK_DISK_FREE_PCT=20 worktree_create "test-disk2" 2>&1) || exit_code=$?
if [[ $exit_code -eq 4 ]]; then
  _pass "disk-cap percent correctly rejected with exit 4 (MOCK_DISK_FREE_PCT=20)"
else
  _fail "disk-cap percent test failed (exit $exit_code, result: $result)"
fi

# ---------------------------------------------------------------------------
# Test 8: Slug validation → exit 1
# ---------------------------------------------------------------------------
_section "Test 8: Slug validation"

exit_code=0
result=$(worktree_create "BAD SLUG!" 2>&1) || exit_code=$?
if [[ $exit_code -eq 1 ]]; then
  _pass "invalid slug rejected with exit 1"
else
  _fail "invalid slug test failed (exit $exit_code, result: $result)"
fi

# Also test uppercase
exit_code=0
result=$(worktree_create "BadSlug" 2>&1) || exit_code=$?
if [[ $exit_code -eq 1 ]]; then
  _pass "uppercase slug rejected with exit 1"
else
  _fail "uppercase slug test failed (exit $exit_code, result: $result)"
fi

# Also test valid edge case (single char)
exit_code=0
# First remove any existing to free up slots
worktree_remove "a" 2>/dev/null || true
result=$(worktree_create "a" 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  _pass "single-char slug 'a' accepted"
  worktree_remove "a" 2>/dev/null || true
else
  _fail "single-char slug 'a' rejected (exit $exit_code)"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
popd > /dev/null

echo
echo "=============================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  echo "KNOWN LIMITATIONS:"
  echo "  - flutter analyze + smoke-login: deferred to Phase-1-Integration"
  echo "    (requires .env.test with real credentials + running web app)"
  echo "  - gwq-specific code paths not tested (gwq not installed)"
  exit 1
fi

echo
echo "KNOWN LIMITATIONS (non-blocking):"
echo "  - flutter analyze + smoke-login: deferred to Phase-1-Integration"
echo "    (requires .env.test with real credentials + running web app)"
echo "  - gwq-specific code paths not tested (gwq not installed; git worktree fallback used)"
echo "  - flutter pre-warm path not tested (would need flutter in PATH + pub cache)"
exit 0
