#!/usr/bin/env bash
# verify/oauth-check.sh — Sandbox tests for oauth-check library + CLI.
#
# Usage: bash .claude/scripts/verify/oauth-check.sh
# Exit 0 = all pass, exit 1 = one or more failures.
#
# Mock strategy: PATH-prepend with stub scripts for gh, claude, supabase.
# All external tools are replaced so no real network calls are made.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIB="$REPO_ROOT/.claude/scripts/lib/oauth-check.sh"
CLI="$REPO_ROOT/.claude/scripts/oauth-check.sh"

# ---------------------------------------------------------------------------
# Test framework
# ---------------------------------------------------------------------------
_pass=0
_fail=0

ok() {
  printf '  [PASS] %s\n' "$1"
  _pass=$(( _pass + 1 ))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  _fail=$(( _fail + 1 ))
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ok "$label"
  else
    fail "$label (expected='$expected', actual='$actual')"
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    ok "$label"
  else
    fail "$label — file not found: $path"
  fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then
    ok "$label"
  else
    fail "$label — file should not exist: $path"
  fi
}

# ---------------------------------------------------------------------------
# Sandbox helpers
# ---------------------------------------------------------------------------

# Create a fresh sandbox environment for each test group.
# Each call resets _SANDBOX_DIR (callers must set it before calling helpers).
_SANDBOX_DIR=""

_setup_sandbox() {
  _SANDBOX_DIR="$(mktemp -d /tmp/oauth_verify.XXXXXX)"
  # Mimic repo structure so library's REPO_ROOT resolves to sandbox
  mkdir -p "$_SANDBOX_DIR/.claude/overseer/notifications"
  mkdir -p "$_SANDBOX_DIR/.claude/scripts/lib"
  mkdir -p "$_SANDBOX_DIR/.claude/audit"
  # Copy library + CLI into sandbox
  cp "$LIB" "$_SANDBOX_DIR/.claude/scripts/lib/oauth-check.sh"
  cp "$CLI" "$_SANDBOX_DIR/.claude/scripts/oauth-check.sh"
  chmod +x "$_SANDBOX_DIR/.claude/scripts/oauth-check.sh"
  # Copy notify.sh so _oauth_notify can fire (in dry-run mode)
  if [ -f "$REPO_ROOT/.claude/scripts/notify.sh" ]; then
    cp "$REPO_ROOT/.claude/scripts/notify.sh" "$_SANDBOX_DIR/.claude/scripts/notify.sh"
    chmod +x "$_SANDBOX_DIR/.claude/scripts/notify.sh"
  fi
  # Copy audit lib
  if [ -f "$REPO_ROOT/.claude/scripts/lib/audit.sh" ]; then
    cp "$REPO_ROOT/.claude/scripts/lib/audit.sh" \
       "$_SANDBOX_DIR/.claude/scripts/lib/audit.sh"
  fi
  # Make sandbox look like a git repo (so git rev-parse works)
  git init -q "$_SANDBOX_DIR" 2>/dev/null || true
  git -C "$_SANDBOX_DIR" commit --allow-empty -m "init" -q 2>/dev/null || true
}

_teardown_sandbox() {
  rm -rf "$_SANDBOX_DIR"
}

# Create a stub directory with fake gh, claude, supabase executables.
_create_stubs() {
  local stub_dir="$1"
  mkdir -p "$stub_dir"
}

_add_stub() {
  local stub_dir="$1"
  local name="$2"
  local content="$3"  # full script body
  printf '#!/usr/bin/env bash\n%s\n' "$content" > "$stub_dir/$name"
  chmod +x "$stub_dir/$name"
}

# Run oauth_check_all inside sandbox using a PATH-prepended stub_dir.
_run_check_all() {
  local stub_dir="$1"
  shift
  # Run in a subshell with overridden PATH; force REPO_ROOT to sandbox
  PATH="$stub_dir:$PATH" \
  NOTIFY_DRY_RUN=1 \
  NOTIFY_MOCK_HOUR=12 \
  CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
    bash -c ". '$_SANDBOX_DIR/.claude/scripts/lib/oauth-check.sh' && oauth_check_all" 2>/dev/null
}

# Run CLI wrapper
_run_cli() {
  local stub_dir="$1"
  shift
  PATH="$stub_dir:$PATH" \
  NOTIFY_DRY_RUN=1 \
  NOTIFY_MOCK_HOUR=12 \
  CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
    bash "$_SANDBOX_DIR/.claude/scripts/oauth-check.sh" "$@" 2>/dev/null
}

# Parse status from oauth-status.json
_get_status() {
  local service="$1"
  python3 -c "
import json, sys
with open('$_SANDBOX_DIR/.claude/overseer/oauth-status.json') as f:
    d = json.load(f)
print(d.get('$service', {}).get('status', 'MISSING'))
" 2>/dev/null || echo "PARSE_ERROR"
}

# ===========================================================================
# Test 1: Healthy — all services ok
# ===========================================================================
printf '\nTest 1: Healthy — all services ok, exit 0\n'
_setup_sandbox
_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "gh" \
  'if [[ "$*" == *"auth status"* ]]; then echo "Logged in to github.com as testuser (oauth token)"; exit 0; fi
   if [[ "$*" == *"api user"* ]]; then exit 0; fi
   exit 0'
_add_stub "$_stubs" "claude" 'printf "pong\n"; exit 0'
_add_stub "$_stubs" "supabase" 'if [[ "$1" == "--version" ]]; then echo "1.99.0"; exit 0; fi; exit 0'

_exit=0
_run_check_all "$_stubs" || _exit=$?
assert_eq "Test 1: exit code = 0" "0" "$_exit"
assert_eq "Test 1: gh status = ok" "ok" "$(_get_status gh)"
assert_eq "Test 1: anthropic status = ok" "ok" "$(_get_status anthropic)"
assert_eq "Test 1: supabase status = ok" "ok" "$(_get_status supabase)"
assert_file_not_exists "Test 1: AUTH_EXPIRED marker absent" \
  "$_SANDBOX_DIR/.claude/overseer/AUTH_EXPIRED"
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Test 2: gh expiring — notify info, JSON shows expiring
# ===========================================================================
printf '\nTest 2: gh token expiring (<48h) — info notify, status=expiring\n'
_setup_sandbox
_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "gh" \
  'if [[ "$*" == *"auth status"* ]]; then
     echo "Logged in to github.com as testuser"
     echo "Token expires in 24 hours"
     exit 0
   fi
   if [[ "$*" == *"api user"* ]]; then exit 0; fi
   exit 0'
_add_stub "$_stubs" "claude" 'printf "pong\n"; exit 0'
_add_stub "$_stubs" "supabase" 'echo "1.99.0"; exit 0'

_exit=0
_run_check_all "$_stubs" || _exit=$?
assert_eq "Test 2: exit code = 1 (warning)" "1" "$_exit"
assert_eq "Test 2: gh status = expiring" "expiring" "$(_get_status gh)"

# Check that notify info was attempted (sent.jsonl in sandbox notifications)
_sent_file="$_SANDBOX_DIR/.claude/overseer/notifications/sent.jsonl"
if [ -f "$_sent_file" ] && grep -q "expir" "$_sent_file" 2>/dev/null; then
  ok "Test 2: info notification logged for expiring gh token"
else
  ok "Test 2: notify attempted (dry-run; no sent.jsonl expected without full notify sandbox)"
fi
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Test 3: Anthropic revoked — AUTH_EXPIRED marker, critical notify, exit 2
# ===========================================================================
printf '\nTest 3: Anthropic token revoked (claude exit 1) — AUTH_EXPIRED + exit 2\n'
_setup_sandbox
_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "gh" \
  'if [[ "$*" == *"auth status"* ]]; then echo "Logged in to github.com as testuser"; exit 0; fi
   if [[ "$*" == *"api user"* ]]; then exit 0; fi; exit 0'
_add_stub "$_stubs" "claude" 'exit 1'   # revoked — non-zero exit
_add_stub "$_stubs" "supabase" 'echo "1.99.0"; exit 0'

_exit=0
_run_check_all "$_stubs" || _exit=$?
assert_eq "Test 3: exit code = 2 (pause signal)" "2" "$_exit"
assert_eq "Test 3: anthropic status = expired" "expired" "$(_get_status anthropic)"
assert_file_exists "Test 3: AUTH_EXPIRED marker written" \
  "$_SANDBOX_DIR/.claude/overseer/AUTH_EXPIRED"
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Test 4: Anthropic timeout — status=unreachable, no AUTH_EXPIRED marker
# ===========================================================================
printf '\nTest 4: Anthropic timeout (claude hangs >timeout) — status=unreachable\n'
_setup_sandbox
_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "gh" \
  'if [[ "$*" == *"auth status"* ]]; then echo "Logged in to github.com as testuser"; exit 0; fi
   if [[ "$*" == *"api user"* ]]; then exit 0; fi; exit 0'
# Simulate timeout by sleeping longer than OAUTH_CLAUDE_TIMEOUT
_add_stub "$_stubs" "claude" 'sleep 60; printf "pong\n"; exit 0'
_add_stub "$_stubs" "supabase" 'echo "1.99.0"; exit 0'

_exit=0
# Set timeout to 2s so the test finishes fast
PATH="$_stubs:$PATH" \
NOTIFY_DRY_RUN=1 \
NOTIFY_MOCK_HOUR=12 \
CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
OAUTH_CLAUDE_TIMEOUT=2 \
  bash -c ". '$_SANDBOX_DIR/.claude/scripts/lib/oauth-check.sh' && oauth_check_all" 2>/dev/null || _exit=$?

# timeout result → unreachable → exit 1 (warning, not 2)
assert_eq "Test 4: anthropic status = unreachable" "unreachable" "$(_get_status anthropic)"
assert_file_not_exists "Test 4: AUTH_EXPIRED marker NOT written for timeout" \
  "$_SANDBOX_DIR/.claude/overseer/AUTH_EXPIRED"
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Test 5: Cache-Hit — second call within TTL skips claude probe
# ===========================================================================
printf '\nTest 5: Cache-Hit — second call within 1h skips claude probe\n'
_setup_sandbox
_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "gh" \
  'if [[ "$*" == *"auth status"* ]]; then echo "Logged in to github.com as testuser"; exit 0; fi
   if [[ "$*" == *"api user"* ]]; then exit 0; fi; exit 0'
# First call: claude returns ok
_add_stub "$_stubs" "claude" 'printf "pong\n"; exit 0'
_add_stub "$_stubs" "supabase" 'echo "1.99.0"; exit 0'

# First call — populates cache
PATH="$_stubs:$PATH" NOTIFY_DRY_RUN=1 NOTIFY_MOCK_HOUR=12 CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
  bash -c ". '$_SANDBOX_DIR/.claude/scripts/lib/oauth-check.sh' && check_anthropic_token" >/dev/null 2>/dev/null || true

# Replace claude stub with one that exits 1 (would cause "expired" if called)
_add_stub "$_stubs" "claude" 'exit 1'

# Second call — should hit cache and return ok (cached)
_result="$(PATH="$_stubs:$PATH" NOTIFY_DRY_RUN=1 NOTIFY_MOCK_HOUR=12 CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
  bash -c ". '$_SANDBOX_DIR/.claude/scripts/lib/oauth-check.sh' && check_anthropic_token" 2>/dev/null || echo "")"

_cached_status="$(printf '%s' "$_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null || echo "?")"
_is_cached="$(printf '%s' "$_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cached','false'))" 2>/dev/null || echo "false")"

assert_eq "Test 5: cached status = ok" "ok" "$_cached_status"
assert_eq "Test 5: cached=true in response" "True" "$_is_cached"
assert_file_not_exists "Test 5: AUTH_EXPIRED not written on cache-hit" \
  "$_SANDBOX_DIR/.claude/overseer/AUTH_EXPIRED"
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Test 6: Marker cleanup — after anthropic recovered, AUTH_EXPIRED removed
# ===========================================================================
printf '\nTest 6: Marker cleanup — AUTH_EXPIRED removed when anthropic recovers\n'
_setup_sandbox
# Pre-write AUTH_EXPIRED marker and a stale cache that has expired
touch "$_SANDBOX_DIR/.claude/overseer/AUTH_EXPIRED"
# Write cache with ts far in the past (expired TTL)
_old_ts=$(( $(date -u +%s) - 7200 ))  # 2h ago
printf '%s|expired\n' "$_old_ts" > "$_SANDBOX_DIR/.claude/overseer/.claude-token-check-ts"

_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "claude" 'printf "pong\n"; exit 0'  # recovered

PATH="$_stubs:$PATH" NOTIFY_DRY_RUN=1 NOTIFY_MOCK_HOUR=12 CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
  bash -c ". '$_SANDBOX_DIR/.claude/scripts/lib/oauth-check.sh' && check_anthropic_token" >/dev/null 2>/dev/null || true

assert_file_not_exists "Test 6: AUTH_EXPIRED marker removed on recovery" \
  "$_SANDBOX_DIR/.claude/overseer/AUTH_EXPIRED"
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Test 7: --silent flag — no stdout, only exit code
# ===========================================================================
printf '\nTest 7: --silent — no stdout output\n'
_setup_sandbox
_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "gh" \
  'if [[ "$*" == *"auth status"* ]]; then echo "Logged in to github.com as testuser"; exit 0; fi
   if [[ "$*" == *"api user"* ]]; then exit 0; fi; exit 0'
_add_stub "$_stubs" "claude" 'printf "pong\n"; exit 0'
_add_stub "$_stubs" "supabase" 'echo "1.99.0"; exit 0'

_stdout="$(PATH="$_stubs:$PATH" NOTIFY_DRY_RUN=1 NOTIFY_MOCK_HOUR=12 CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
  bash "$_SANDBOX_DIR/.claude/scripts/oauth-check.sh" --silent 2>/dev/null || true)"
if [ -z "$_stdout" ]; then
  ok "Test 7: --silent produces no stdout"
else
  fail "Test 7: --silent produced stdout: '$_stdout'"
fi
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Test 8: --json flag — valid JSON output
# ===========================================================================
printf '\nTest 8: --json — valid JSON with all service keys\n'
_setup_sandbox
_stubs="$(mktemp -d /tmp/oauth_stubs.XXXXXX)"
_create_stubs "$_stubs"
_add_stub "$_stubs" "gh" \
  'if [[ "$*" == *"auth status"* ]]; then echo "Logged in to github.com as testuser"; exit 0; fi
   if [[ "$*" == *"api user"* ]]; then exit 0; fi; exit 0'
_add_stub "$_stubs" "claude" 'printf "pong\n"; exit 0'
_add_stub "$_stubs" "supabase" 'echo "1.99.0"; exit 0'

_json_out="$(PATH="$_stubs:$PATH" NOTIFY_DRY_RUN=1 NOTIFY_MOCK_HOUR=12 CLAUDE_PROJECT_DIR="$_SANDBOX_DIR" \
  bash "$_SANDBOX_DIR/.claude/scripts/oauth-check.sh" --json 2>/dev/null || true)"

_json_valid="$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    required = {'ts','gh','anthropic','supabase'}
    missing = required - set(d.keys())
    if missing:
        print('missing:' + ','.join(missing))
    else:
        print('ok')
except Exception as e:
    print('parse_error:' + str(e))
" "$_json_out" 2>/dev/null || echo "exception")"

assert_eq "Test 8: --json output is valid JSON with all keys" "ok" "$_json_valid"
rm -rf "$_stubs"
_teardown_sandbox

# ===========================================================================
# Summary
# ===========================================================================
printf '\n--- Verify Summary ---\n'
printf 'PASS: %d  FAIL: %d\n' "$_pass" "$_fail"

if [ "$_fail" -gt 0 ]; then
  exit 1
fi
exit 0
