#!/usr/bin/env bash
# verify/panic-mode.sh — Sandbox tests for P3-7 Panic-Mode + Stakeholder-Notification.
#
# Tests:
#   1. 3 consecutive failures → PANIC marker, counter=3, critical notify sent.
#   2. 2 failures + 1 success → counter=0 (no PANIC).
#   3. success-reset: counter=2 → success → counter=0.
#   4. resume.sh without user-session-active → exit 1.
#   5. resume.sh with valid user-session-active → PANIC gone, counter=0, audit.
#   6. is_in_panic: marker present → 0; absent → 1.
#   7. Quiet-Hours bypass: mock-Hour=23, critical → sent (not queued).
#
# Exit 0 if all tests pass; non-zero on first failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_REAL="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
_ok()   { printf '[PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() { printf '[FAIL] %s\n' "$1"; FAIL=$(( FAIL + 1 )); }
_assert() {
  local label="$1" cond="$2"
  if eval "$cond" 2>/dev/null; then _ok "$label"; else _fail "$label"; fi
}

# ---------------------------------------------------------------------------
# Sandbox: isolated REPO_ROOT so tests don't touch real state
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Mirror required dirs into sandbox
mkdir -p \
  "$SANDBOX/.claude/overseer/state" \
  "$SANDBOX/.claude/overseer/notifications" \
  "$SANDBOX/.claude/audit"

# Point REPO_ROOT at sandbox for all library calls
export REPO_ROOT="$SANDBOX"

# Copy libs into sandbox (panic.sh needs notify.sh + audit.sh to be accessible)
mkdir -p "$SANDBOX/.claude/scripts/lib"
cp "$REPO_ROOT_REAL/.claude/scripts/lib/panic.sh"         "$SANDBOX/.claude/scripts/lib/"
cp "$REPO_ROOT_REAL/.claude/scripts/lib/audit.sh"         "$SANDBOX/.claude/scripts/lib/"
cp "$REPO_ROOT_REAL/.claude/scripts/lib/self-mod-blocklist.sh" "$SANDBOX/.claude/scripts/lib/"
mkdir -p "$SANDBOX/.claude/scripts"
cp "$REPO_ROOT_REAL/.claude/scripts/notify.sh"            "$SANDBOX/.claude/scripts/"
cp "$REPO_ROOT_REAL/.claude/scripts/lib/notify-impl.sh"   "$SANDBOX/.claude/scripts/lib/"
cp "$REPO_ROOT_REAL/.claude/scripts/resume.sh"            "$SANDBOX/.claude/scripts/"

# Make scripts executable
chmod +x "$SANDBOX/.claude/scripts/notify.sh"
chmod +x "$SANDBOX/.claude/scripts/resume.sh"

# Patch the notify.sh shim to point at sandbox copy of notify-impl.sh
cat > "$SANDBOX/.claude/scripts/notify.sh" <<'EOF'
#!/usr/bin/env bash
exec /bin/bash "$(dirname "${BASH_SOURCE[0]}")/lib/notify-impl.sh" "$@"
EOF
chmod +x "$SANDBOX/.claude/scripts/notify.sh"

# Patch notify-impl.sh REPO_ROOT resolution so it uses our sandbox
# We use NOTIFY_DRY_RUN=1 to avoid real pushes + record to sent.jsonl.
export NOTIFY_DRY_RUN=1
export NTFY_TOPIC="test-topic"

# sent.jsonl lives at $SANDBOX/.claude/overseer/notifications/sent.jsonl
SENT_JSONL="$SANDBOX/.claude/overseer/notifications/sent.jsonl"
QUEUED_JSONL="$SANDBOX/.claude/overseer/notifications/queued.jsonl"

# Source panic.sh with sandbox REPO_ROOT
_panic_reset_counter() {
  rm -f "$SANDBOX/.claude/overseer/state/failure-counter.json"
  rm -f "$SANDBOX/.claude/overseer/PANIC"
}

_source_panic() {
  # Re-source so _PANIC_* vars are refreshed from REPO_ROOT
  unset -f record_worker_failure record_worker_success enter_panic is_in_panic \
           _panic_now_iso _panic_read_json _panic_write_json _panic_notify_critical _panic_audit \
           2>/dev/null || true
  # shellcheck disable=SC1090
  source "$SANDBOX/.claude/scripts/lib/panic.sh"
}

_read_counter() {
  python3 -c "
import json, sys
try:
    d = json.load(open('$SANDBOX/.claude/overseer/state/failure-counter.json'))
    print(d.get('consecutive_failures', 0))
except Exception:
    print(0)
"
}

_sent_count_critical() {
  if [ ! -f "$SENT_JSONL" ]; then echo 0; return; fi
  python3 -c "
import json
count=0
with open('$SENT_JSONL') as f:
    for line in f:
        try:
            d=json.loads(line)
            if d.get('severity')=='critical': count+=1
        except: pass
print(count)
"
}

# ============================================================================
# Test 1: 3 consecutive failures → PANIC marker, counter=3, critical notify
# ============================================================================
printf '\n=== Test 1: 3 consecutive failures ===\n'
_panic_reset_counter
> "$SENT_JSONL" 2>/dev/null || true
_source_panic

record_worker_failure "slug-a" 1
record_worker_failure "slug-b" 1
record_worker_failure "slug-c" 1

_assert "T1: PANIC marker exists" "[ -f '$SANDBOX/.claude/overseer/PANIC' ]"
_assert "T1: counter=3" "[ \$(_read_counter) -eq 3 ]"
_assert "T1: critical notify sent" "[ \$(_sent_count_critical) -ge 1 ]"
_assert "T1: PANIC file contains reason" "grep -q 'consecutive_failures' '$SANDBOX/.claude/overseer/PANIC'"

# ============================================================================
# Test 2: 2 failures + 1 success → counter=0, no PANIC
# ============================================================================
printf '\n=== Test 2: 2 failures + 1 success → counter=0 ===\n'
_panic_reset_counter
_source_panic

record_worker_failure "slug-x" 1
record_worker_failure "slug-y" 1
record_worker_success "slug-z"

_assert "T2: no PANIC marker" "[ ! -f '$SANDBOX/.claude/overseer/PANIC' ]"
_assert "T2: counter=0" "[ \$(_read_counter) -eq 0 ]"

# ============================================================================
# Test 3: success-reset: counter=2 → success → 0
# ============================================================================
printf '\n=== Test 3: success resets counter from 2 ===\n'
_panic_reset_counter
_source_panic

record_worker_failure "slug-1" 1
record_worker_failure "slug-2" 1
_assert "T3: counter=2 before success" "[ \$(_read_counter) -eq 2 ]"

record_worker_success "slug-3"
_assert "T3: counter=0 after success" "[ \$(_read_counter) -eq 0 ]"

# ============================================================================
# Test 4: resume.sh without user-session-active → exit 1
# ============================================================================
printf '\n=== Test 4: resume.sh without user-session-active ===\n'
rm -f "$SANDBOX/.claude/.user-session-active"

# resume.sh needs self-mod-blocklist to validate the session marker;
# without the secret file it will also fail. Either way, exit 1 expected.
resume_rc=0
REPO_ROOT="$SANDBOX" bash "$SANDBOX/.claude/scripts/resume.sh" >/dev/null 2>&1 || resume_rc=$?
_assert "T4: exit 1 without session marker" "[ $resume_rc -eq 1 ]"

# ============================================================================
# Test 5: resume.sh with valid user-session-active → PANIC gone, counter=0
# ============================================================================
printf '\n=== Test 5: resume.sh with valid user-session-active ===\n'
_panic_reset_counter
_source_panic
# Create PANIC marker
enter_panic "test-panic-for-resume"
_assert "T5: PANIC marker present before resume" "[ -f '$SANDBOX/.claude/overseer/PANIC' ]"

# Inject a valid-looking session marker.
# resume.sh calls _is_session_marker_valid which requires the secret file;
# in sandbox mode the secret file won't exist → validation falls through to
# the degraded-mode check (file non-empty).  We write a non-empty value.
mkdir -p "$SANDBOX/.claude"
printf 'sandbox-bypass-token\n' > "$SANDBOX/.claude/.user-session-active"

# Also create a fake secret file so hash validation doesn't crash
# (it will fail hash check → falls to degraded mode if we skip the lib).
# We patch resume.sh to skip hash validation in sandbox by setting
# CLAUDE_SESSION_SECRET_FILE to /dev/null.
export CLAUDE_SESSION_SECRET_FILE="/dev/null"

# To make _is_session_marker_valid return true in sandbox without real secret,
# we directly test that resume.sh at minimum removes PANIC when called.
# We override the validation check by providing a mock session marker check:
# monkeypatch the lib source inside sandbox to always return valid.
cat > "$SANDBOX/.claude/scripts/lib/self-mod-blocklist.sh" <<'EOF'
#!/usr/bin/env bash
set -u
SELF_MOD_REPO_ROOT="${SELF_MOD_REPO_ROOT:-$(pwd)}"
SELF_MOD_BLOCKLIST=()
SELF_MOD_BLOCKLIST_GLOBS=()
_is_self_mod_blocked() { return 1; }
_is_self_mod_protection_active() { return 1; }
_is_session_marker_valid() {
  # Sandbox: always valid if file is non-empty
  local marker="${1:-}"
  [ -f "$marker" ] && [ -s "$marker" ]
}
_session_compute_hash() { echo "sandbox-bypass-token"; }
EOF

resume_rc=0
REPO_ROOT="$SANDBOX" bash "$SANDBOX/.claude/scripts/resume.sh" >/dev/null 2>&1 || resume_rc=$?
_assert "T5: resume.sh exits 0" "[ $resume_rc -eq 0 ]"
_assert "T5: PANIC marker removed" "[ ! -f '$SANDBOX/.claude/overseer/PANIC' ]"
_assert "T5: counter=0 after resume" "[ \$(_read_counter) -eq 0 ]"

# ============================================================================
# Test 6: is_in_panic
# ============================================================================
printf '\n=== Test 6: is_in_panic ===\n'
_panic_reset_counter
_source_panic

# No marker → exit 1
is_in_panic && panic_when_absent=0 || panic_when_absent=1
_assert "T6: is_in_panic=1 when no marker" "[ $panic_when_absent -eq 1 ]"

# With marker → exit 0
touch "$SANDBOX/.claude/overseer/PANIC"
is_in_panic && panic_when_present=0 || panic_when_present=1
_assert "T6: is_in_panic=0 when marker present" "[ $panic_when_present -eq 0 ]"

# ============================================================================
# Test 7: Quiet-Hours bypass — critical notify at hour=23 still goes to sent.jsonl
# ============================================================================
printf '\n=== Test 7: Quiet-Hours bypass for critical severity ===\n'
_panic_reset_counter
rm -f "$SENT_JSONL" "$QUEUED_JSONL"
> "$SENT_JSONL" 2>/dev/null || true
> "$QUEUED_JSONL" 2>/dev/null || true

export NOTIFY_MOCK_HOUR=23
export QUIET_HOURS_START=22
export QUIET_HOURS_END=8
_source_panic

# Directly call enter_panic to trigger critical notification
enter_panic "quiet-hours-bypass-test"

_assert "T7: critical sent (not queued) during quiet hours" "[ \$(_sent_count_critical) -ge 1 ]"

# Verify NOT queued (queued.jsonl should be empty or not have this entry)
queued_critical=0
if [ -f "$QUEUED_JSONL" ]; then
  queued_critical="$(python3 -c "
import json
count=0
with open('$QUEUED_JSONL') as f:
    for line in f:
        try:
            d=json.loads(line)
            if d.get('severity')=='critical': count+=1
        except: pass
print(count)
" 2>/dev/null || echo 0)"
fi
_assert "T7: critical NOT queued (quiet-hours bypass)" "[ $queued_critical -eq 0 ]"

# ============================================================================
# Summary
# ============================================================================
printf '\n=== Summary: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
