#!/usr/bin/env bash
# verify/inbox-migration.sh — Verification suite for P4-0 migrate-inbox.sh
#
# Tests:
#   1. Pre-flight: Inboxen voll → exit 1
#   2. Pre-flight: beide LaunchAgents aktiv → exit 1 (via mock launchctl)
#   3. Happy migration: beide leer, kein LaunchAgent → success, marker written
#   4. --dry-run: kein Edit, stdout zeigt Plan
#   5. Backup-Erstellung: .pre-migration.bak dir entsteht
#   6. Idempotency: zweiter Run → no-op (already migrated)
#
# Exit 0 = all pass, Exit 1 = at least one failure.
#
# REPO_ROOT can be overridden for sandbox tests.

set -euo pipefail

REAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="${REPO_ROOT:-$(cd "$REAL_SCRIPT_DIR/../../.." && pwd)}"
MIGRATE_SH="${REAL_REPO_ROOT}/.claude/scripts/migrate-inbox.sh"

if [ ! -f "$MIGRATE_SH" ]; then
  printf 'ERROR: migrate-inbox.sh not found at %s\n' "$MIGRATE_SH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox infrastructure
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap '_cleanup' EXIT
_cleanup() {
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
  rm -rf "$SANDBOX"
}

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
_assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then _pass "$desc"
  else _fail "$desc (expected='$expected' actual='$actual')"; fi
}
_assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then _pass "$desc"
  else _fail "$desc (needle='$needle' not in output)"; fi
}
_assert_file_exists() {
  local desc="$1" path="$2"
  if [ -e "$path" ]; then _pass "$desc"
  else _fail "$desc (missing: $path)"; fi
}
_assert_file_missing() {
  local desc="$1" path="$2"
  if [ ! -e "$path" ]; then _pass "$desc"
  else _fail "$desc (unexpected: $path)"; fi
}

# ---------------------------------------------------------------------------
# _make_sandbox — creates and echoes a unique sandbox directory path
# Does NOT use command substitution to avoid subshell side effects.
# Call: SBX="$SANDBOX/sbxN"; _make_sandbox "$SBX"
# ---------------------------------------------------------------------------
_SBX_COUNTER=0
_make_sandbox() {
  local sbx="$1"
  mkdir -p "$sbx"

  # Git stub (scripts may call git rev-parse)
  git init -q "$sbx"
  git -C "$sbx" config user.email "test@test.com"
  git -C "$sbx" config user.name "Test"

  # Directory structure
  mkdir -p "${sbx}/.claude/overseer/inbox"
  mkdir -p "${sbx}/.claude/overseer/done"
  mkdir -p "${sbx}/.claude/overseer/failed"
  mkdir -p "${sbx}/.claude/overseer/in_progress"
  mkdir -p "${sbx}/.claude/backlog/inbox"
  mkdir -p "${sbx}/.claude/backlog/done"
  mkdir -p "${sbx}/.claude/backlog/failed"
  mkdir -p "${sbx}/.claude/audit"

  # Create user-session-active file by default (user-gated)
  touch "${sbx}/.claude/.user-session-active"

  # Stub launchctl that returns no agents by default
  mkdir -p "${sbx}/bin"
  printf '#!/usr/bin/env bash\necho ""\n' > "${sbx}/bin/launchctl"
  chmod +x "${sbx}/bin/launchctl"
}

_new_sbx() {
  _SBX_COUNTER=$(( _SBX_COUNTER + 1 ))
  local sbx="${SANDBOX}/sbx${_SBX_COUNTER}"
  _make_sandbox "$sbx"
  echo "$sbx"
}

# _run_migrate <sbx> [args...] — runs migrate-inbox.sh with sandbox REPO_ROOT, returns combined output
_run_migrate() {
  local sbx="$1"; shift
  if [ $# -gt 0 ]; then
    PATH="${sbx}/bin:$PATH" REPO_ROOT="$sbx" bash "$MIGRATE_SH" "$@" 2>&1 || true
  else
    PATH="${sbx}/bin:$PATH" REPO_ROOT="$sbx" bash "$MIGRATE_SH" 2>&1 || true
  fi
}

# _run_migrate_rc <sbx> [args...] — echoes exit code
_run_migrate_rc() {
  local sbx="$1"; shift
  local rc=0
  if [ $# -gt 0 ]; then
    PATH="${sbx}/bin:$PATH" REPO_ROOT="$sbx" bash "$MIGRATE_SH" "$@" >/dev/null 2>&1 || rc=$?
  else
    PATH="${sbx}/bin:$PATH" REPO_ROOT="$sbx" bash "$MIGRATE_SH" >/dev/null 2>&1 || rc=$?
  fi
  echo "$rc"
}

# ---------------------------------------------------------------------------
# Test 1: Pre-flight — Inboxen voll → exit 1
# ---------------------------------------------------------------------------
printf '\nTest 1: Pre-flight — Inboxen nicht leer → exit 1\n'
SBX1a="$SANDBOX/sbx1a"
_make_sandbox "$SBX1a"
touch "${SBX1a}/.claude/overseer/inbox/99-test-item.md"
rc1a="$(_run_migrate_rc "$SBX1a")"
_assert_eq "exit code is 1 when overseer inbox has items" "1" "$rc1a"

SBX1b="$SANDBOX/sbx1b"
_make_sandbox "$SBX1b"
touch "${SBX1b}/.claude/backlog/inbox/99-test-item.md"
rc1b="$(_run_migrate_rc "$SBX1b")"
_assert_eq "exit code is 1 when backlog inbox has items" "1" "$rc1b"

# ---------------------------------------------------------------------------
# Test 2: Pre-flight — beide LaunchAgents aktiv → exit 1
# ---------------------------------------------------------------------------
printf '\nTest 2: Pre-flight — beide LaunchAgents aktiv → exit 1\n'
SBX2="$SANDBOX/sbx2"
_make_sandbox "$SBX2"
# Override stub launchctl to report both agents active
printf '#!/usr/bin/env bash\necho "com.example.headless"\necho "com.example.overseer"\n' \
  > "${SBX2}/bin/launchctl"
chmod +x "${SBX2}/bin/launchctl"

rc2="$(_run_migrate_rc "$SBX2")"
_assert_eq "exit code is 1 when both LaunchAgents active" "1" "$rc2"

out2="$(_run_migrate "$SBX2")"
_assert_contains "stderr output mentions LaunchAgent" "LaunchAgent" "$out2"

# ---------------------------------------------------------------------------
# Test 3: Happy migration — beide leer, kein LaunchAgent → success
# ---------------------------------------------------------------------------
printf '\nTest 3: Happy migration — beide leer, kein LaunchAgent\n'
SBX3="$SANDBOX/sbx3"
_make_sandbox "$SBX3"

rc3="$(_run_migrate_rc "$SBX3")"
_assert_eq "exit code is 0 for happy migration" "0" "$rc3"

_assert_file_exists "migration marker created" \
  "${SBX3}/.claude/overseer/.inbox-migration-done"
_assert_file_exists "audit log written" \
  "${SBX3}/.claude/audit/migrate-inbox.log"

audit3="$(cat "${SBX3}/.claude/audit/migrate-inbox.log" 2>/dev/null || true)"
_assert_contains "audit log contains migration_complete" "migration_complete" "$audit3"

# ---------------------------------------------------------------------------
# Test 4: --dry-run — kein Edit, stdout zeigt Plan
# ---------------------------------------------------------------------------
printf '\nTest 4: --dry-run — kein Edit, stdout zeigt Plan\n'
SBX4="$SANDBOX/sbx4"
_make_sandbox "$SBX4"

out4="$(_run_migrate "$SBX4" --dry-run)"
_assert_contains "dry-run output contains DRY-RUN" "DRY-RUN" "$out4"
_assert_contains "dry-run shows backlog/inbox path" "backlog/inbox" "$out4"

_assert_file_missing "no migration marker in dry-run" \
  "${SBX4}/.claude/overseer/.inbox-migration-done"

# No migration_complete in audit during dry-run
if [ -f "${SBX4}/.claude/audit/migrate-inbox.log" ]; then
  audit4="$(cat "${SBX4}/.claude/audit/migrate-inbox.log" 2>/dev/null || true)"
  if printf '%s' "$audit4" | grep -qF "migration_complete"; then
    _fail "dry-run must not write migration_complete to audit"
  else
    _pass "dry-run did not write migration_complete to audit"
  fi
else
  _pass "dry-run did not create audit log"
fi

# ---------------------------------------------------------------------------
# Test 5: Backup-Erstellung — .pre-migration.bak dir entsteht
# ---------------------------------------------------------------------------
printf '\nTest 5: Backup-Erstellung — .pre-migration.bak dir entsteht\n'
SBX5="$SANDBOX/sbx5"
_make_sandbox "$SBX5"

_run_migrate_rc "$SBX5" >/dev/null

_assert_file_exists "backup dir created" \
  "${SBX5}/.claude/overseer/inbox.pre-migration.bak"

if [ -d "${SBX5}/.claude/overseer/inbox.pre-migration.bak" ]; then
  _pass "backup is a directory"
else
  _fail "backup is not a directory"
fi

# ---------------------------------------------------------------------------
# Test 6: Idempotency — zweiter Run → no-op (already migrated)
# ---------------------------------------------------------------------------
printf '\nTest 6: Idempotency — zweiter Run → no-op (already migrated)\n'
SBX6="$SANDBOX/sbx6"
_make_sandbox "$SBX6"

# First run
_run_migrate_rc "$SBX6" >/dev/null
marker6="${SBX6}/.claude/overseer/.inbox-migration-done"
first_mtime="$(stat -f %m "$marker6" 2>/dev/null || stat -c %Y "$marker6" 2>/dev/null || echo 0)"

# Small delay so mtime would differ if marker is rewritten
sleep 1

# Second run
rc6="$(_run_migrate_rc "$SBX6")"
_assert_eq "second run exits 0 (no-op)" "0" "$rc6"

second_mtime="$(stat -f %m "$marker6" 2>/dev/null || stat -c %Y "$marker6" 2>/dev/null || echo 0)"
_assert_eq "migration marker not re-written (same mtime)" "$first_mtime" "$second_mtime"

out6="$(_run_migrate "$SBX6")"
_assert_contains "second run says already migrated" "Already migrated" "$out6"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== inbox-migration verify: %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
