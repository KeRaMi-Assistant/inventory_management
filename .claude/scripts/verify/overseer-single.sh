#!/usr/bin/env bash
# overseer-single.sh — Verify suite for .claude/scripts/overseer.sh (P1-1).
#
# Strategy: build an isolated sandbox repo with mock libs/scripts beside a
# real copy of overseer.sh. Overseer's path resolution finds the mocks
# (because SCRIPT_DIR is the sandbox), so we never run a real worker /
# real worktree against the parent repo.
#
# Exit 0 = all tests pass, Exit 1 = at least one failure.

set -euo pipefail

REAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$REAL_SCRIPT_DIR/../../.." && pwd)"
REAL_OVERSEER_SH="$REAL_REPO_ROOT/.claude/scripts/overseer.sh"

if [ ! -f "$REAL_OVERSEER_SH" ]; then
  printf 'ERROR: overseer.sh not found at %s\n' "$REAL_OVERSEER_SH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox setup
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap '_cleanup' EXIT
_cleanup() {
  if command -v chflags >/dev/null 2>&1; then
    find "$SANDBOX" -type f -exec chflags nouchg {} \; 2>/dev/null || true
  fi
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
  rm -rf "$SANDBOX"
}

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
_assert_file_exists() {
  local desc="$1" path="$2"
  if [ -e "$path" ]; then _pass "$desc"; else _fail "$desc (missing: $path)"; fi
}
_assert_file_not_exists() {
  local desc="$1" path="$2"
  if [ ! -e "$path" ]; then _pass "$desc"; else _fail "$desc (should not exist: $path)"; fi
}
_assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then _pass "$desc"
  else _fail "$desc (expected='$expected' actual='$actual')"; fi
}

# ---------------------------------------------------------------------------
# Build sandbox repo: a tiny git repo with .claude/scripts/ holding overseer
# plus mock siblings.
# ---------------------------------------------------------------------------
SBX_REPO="$SANDBOX/repo"
SBX_SCRIPTS="$SBX_REPO/.claude/scripts"
SBX_LIB="$SBX_SCRIPTS/lib"
SBX_OVERSEER="$SBX_REPO/.claude/overseer"

mkdir -p "$SBX_SCRIPTS" "$SBX_LIB" "$SBX_OVERSEER/inbox" \
         "$SBX_OVERSEER/in_progress" "$SBX_OVERSEER/done" \
         "$SBX_OVERSEER/failed" "$SBX_OVERSEER/state" \
         "$SBX_OVERSEER/notifications"

# Initialize git repo (overseer / picker need git rev-parse)
(cd "$SBX_REPO" && git init -q && git config user.email t@t && git config user.name t \
   && git commit --allow-empty -q -m init)

# Real overseer.sh
cp "$REAL_OVERSEER_SH" "$SBX_SCRIPTS/overseer.sh"
chmod +x "$SBX_SCRIPTS/overseer.sh"

# Real picker.sh — we want its real atomic-move semantics in tests.
cp "$REAL_REPO_ROOT/.claude/scripts/lib/picker.sh" "$SBX_LIB/picker.sh"

# Real audit.sh — but a sandboxed AUDIT_DIR via CLAUDE_PROJECT_DIR.
cp "$REAL_REPO_ROOT/.claude/scripts/lib/audit.sh" "$SBX_LIB/audit.sh"

# Mock cost-cap.sh: parameterized cost_check_or_die
cat > "$SBX_LIB/cost-cap.sh" <<'EOF'
#!/usr/bin/env bash
# Mock cost-cap.sh for overseer verify
cost_record() { return 0; }
cost_today_usd() { printf '%s\n' "${MOCK_COST_TODAY:-0.00}"; }
cost_week_usd()  { printf '%s\n' "${MOCK_COST_WEEK:-0.00}"; }
cost_check_or_die() {
  if [ "${MOCK_COST_EXCEEDED:-0}" = "1" ]; then
    local marker="${COST_CAP_LEDGER_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/overseer}/COST_CAP_REACHED"
    mkdir -p "$(dirname "$marker")"
    printf 'mock cost-cap exceeded\n' > "$marker"
    return 2
  fi
  return 0
}
EOF

# Mock worktree.sh: just makedirs
cat > "$SBX_LIB/worktree.sh" <<'EOF'
#!/usr/bin/env bash
# Mock worktree.sh for overseer verify
worktree_create() {
  local slug="$1"
  local p="${SANDBOX_WORKTREES:-/tmp}/wt_${slug}"
  mkdir -p "$p"
  printf '%s\n' "$p"
  return 0
}
worktree_remove() {
  local slug="$1"
  rm -rf "${SANDBOX_WORKTREES:-/tmp}/wt_${slug}" 2>/dev/null || true
  return 0
}
worktree_list() { :; }
EOF

# Mock oauth-check.sh: oauth_check_all returns rc from MOCK_OAUTH_RC
cat > "$SBX_LIB/oauth-check.sh" <<'EOF'
#!/usr/bin/env bash
oauth_check_all() {
  local rc="${MOCK_OAUTH_RC:-0}"
  if [ "$rc" = "2" ]; then
    local marker="${CLAUDE_PROJECT_DIR:-.}/.claude/overseer/AUTH_EXPIRED"
    mkdir -p "$(dirname "$marker")"
    printf 'mock auth expired\n' > "$marker"
  fi
  return "$rc"
}
EOF

# Mock notify.sh: append a line per call
cat > "$SBX_SCRIPTS/notify.sh" <<'EOF'
#!/usr/bin/env bash
log="${REPO_ROOT:-.}/.claude/overseer/notifications/sent.log"
mkdir -p "$(dirname "$log")"
printf '%s|%s|%s|%s\n' "${1:-}" "${2:-}" "${3:-}" "${4:-}" >> "$log"
exit 0
EOF
chmod +x "$SBX_SCRIPTS/notify.sh"

# Mock watchdog.sh: noop
cat > "$SBX_SCRIPTS/watchdog.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$SBX_SCRIPTS/watchdog.sh"

# Default mock worker (exit 0)
WORKER_SH="$SBX_SCRIPTS/worker.sh"
_set_worker() {
  local exit_code="$1"
  cat > "$WORKER_SH" <<EOF
#!/usr/bin/env bash
printf 'mock-worker exit=$exit_code item=%s wt=%s\n' "\$1" "\$2"
exit $exit_code
EOF
  chmod +x "$WORKER_SH"
}
_set_worker 0

# Sandboxed worktrees dir
export SANDBOX_WORKTREES="$SANDBOX/worktrees"
mkdir -p "$SANDBOX_WORKTREES"

# Run overseer in the sandbox: REPO_ROOT, CLAUDE_PROJECT_DIR override the path
# resolution; NOTIFY_DRY_RUN keeps notify silent (we use mock notify anyway).
# OVERSEER_MAX_WORKERS=1 forces single-worker mode so tests are deterministic:
# each --once spawns exactly 1 worker; the next --once reaps it.
_overseer() {
  REPO_ROOT="$SBX_REPO" \
  CLAUDE_PROJECT_DIR="$SBX_REPO" \
  COST_CAP_LEDGER_DIR="$SBX_OVERSEER" \
  OVERSEER_SLEEP_IDLE=0 OVERSEER_SLEEP_BETWEEN=0 \
  OVERSEER_OAUTH_TTL=999999 \
  OVERSEER_MAX_WORKERS=1 \
  bash "$SBX_SCRIPTS/overseer.sh" "$@"
}

_write_item() {
  local name="$1"
  local body="${2:-test item}"
  cat > "$SBX_OVERSEER/inbox/${name}.md" <<EOF
---
title: $name
source: tier-1
budget_usd: 1
---

$body
EOF
}

_reset() {
  # Wait for any in-flight exit-file renames to complete before wiping the
  # state/workers/ dir. A stale renamer writing AFTER _reset would corrupt
  # the freshly-recreated dir for the next test. We poll until no _tmp_*
  # temp files remain (rename done) or up to 6s timeout.
  local settle_deadline=$(( $(date +%s) + 6 ))
  while [ "$(date +%s)" -lt "$settle_deadline" ]; do
    local active_tmp
    # pipefail-safe: wrap in subshell with pipefail disabled so that a missing
    # state/workers/ dir (first _reset call or after rm -rf) doesn't abort.
    active_tmp=$(set +o pipefail; find "$SBX_OVERSEER/state/workers" -name '_tmp_*.exit.tmp' 2>/dev/null | wc -l | tr -d ' '; exit 0)
    if [ "${active_tmp:-0}" -eq 0 ]; then break; fi
    sleep 0.2
  done
  rm -rf "$SBX_OVERSEER"
  mkdir -p "$SBX_OVERSEER/inbox" "$SBX_OVERSEER/in_progress" \
           "$SBX_OVERSEER/done" "$SBX_OVERSEER/failed" \
           "$SBX_OVERSEER/state" "$SBX_OVERSEER/state/workers" \
           "$SBX_OVERSEER/notifications"
  rm -rf "$SANDBOX_WORKTREES"
  mkdir -p "$SANDBOX_WORKTREES"
  _set_worker 0
  unset MOCK_COST_EXCEEDED MOCK_OAUTH_RC
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Test 1: --once with 3 items → pool processes all 3 items into done/.
# With OVERSEER_MAX_WORKERS=1, each --once spawns at most 1 worker.
# The pipeline is: --once → spawn worker-N → --once → reap-N + spawn worker-N+1 → …
# We need enough --once ticks to both pick all items AND reap all workers.
printf '\nTest 1: 3 items, sequential --once\n'
_reset
_write_item item-001
_write_item item-002
_write_item item-003

# Initial ticks: pick all 3 items (each tick: reap previous + pick next)
_overseer --once >/dev/null 2>&1
_overseer --once >/dev/null 2>&1
_overseer --once >/dev/null 2>&1

# Wait loop: keep ticking until all 3 items land in done/ (30s timeout)
deadline1=$(( $(date +%s) + 30 ))
while [ "$(date +%s)" -lt "$deadline1" ]; do
  count_done=$(find "$SBX_OVERSEER/done" -name '*.md' | wc -l | tr -d ' ')
  if [ "$count_done" -ge 3 ]; then break; fi
  _overseer --once >/dev/null 2>&1 || true
  sleep 0.5
done

count_done=$(find "$SBX_OVERSEER/done" -name '*.md' | wc -l | tr -d ' ')
count_inbox=$(find "$SBX_OVERSEER/inbox" -name '*.md' | wc -l | tr -d ' ')
_assert_eq "3 items moved to done/" "3" "$count_done"
_assert_eq "inbox empty after 3 runs" "0" "$count_inbox"

# Test 2: STOP marker → no pickup, no error.
printf '\nTest 2: STOP marker\n'
_reset
_write_item item-stop-1
touch "$SBX_OVERSEER/STOP"

_overseer --once >/dev/null 2>&1
rc=$?
_assert_eq "exit 0 with STOP" "0" "$rc"
_assert_file_not_exists "item NOT picked (still in inbox)" \
  "$SBX_OVERSEER/done/item-stop-1.md"
_assert_file_exists "item still in inbox" \
  "$SBX_OVERSEER/inbox/item-stop-1.md"
rm -f "$SBX_OVERSEER/STOP"

# Test 3: PANIC marker → idle, critical notify.
printf '\nTest 3: PANIC marker idles\n'
_reset
_write_item item-panic-1
printf 'pre-existing panic\n' > "$SBX_OVERSEER/PANIC"

_overseer --once >/dev/null 2>&1
_assert_file_exists "item still in inbox under PANIC" \
  "$SBX_OVERSEER/inbox/item-panic-1.md"
if grep -q 'critical' "$SBX_OVERSEER/notifications/sent.log" 2>/dev/null; then
  _pass "critical notification sent for PANIC"
else
  _fail "no critical notification logged for PANIC"
fi
rm -f "$SBX_OVERSEER/PANIC"

# Test 4: Cost-cap exceeded → COST_CAP_REACHED marker + notify.
printf '\nTest 4: cost-cap exceeded\n'
_reset
_write_item item-cost-1
MOCK_COST_EXCEEDED=1 _overseer --once >/dev/null 2>&1
_assert_file_exists "COST_CAP_REACHED marker created" \
  "$SBX_OVERSEER/COST_CAP_REACHED"
_assert_file_exists "item NOT picked (still in inbox)" \
  "$SBX_OVERSEER/inbox/item-cost-1.md"
rm -f "$SBX_OVERSEER/COST_CAP_REACHED"

# _wait_for_reap: poll overseer --once until <file> exists or timeout.
# Usage: _wait_for_reap <expected_file> [timeout_seconds]
_wait_for_reap() {
  local expected="$1"
  local timeout_sec="${2:-30}"
  local deadline=$(( $(date +%s) + timeout_sec ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ -e "$expected" ]; then
      return 0
    fi
    # Re-tick overseer to trigger reap of finished workers
    _overseer --once >/dev/null 2>&1 || true
    sleep 0.5
  done
  # Final check after timeout
  [ -e "$expected" ]
}

# Test 5: Worker stub exit 0 → done/, worktree gone.
printf '\nTest 5: worker exit 0 → done/\n'
_reset
_write_item item-ok-1
_set_worker 0
_overseer --once >/dev/null 2>&1
# Workers are async — wait for reap to move item to done/
done_sentinel="$SBX_OVERSEER/done/.test5_sentinel"
deadline5=$(( $(date +%s) + 30 ))
while [ "$(date +%s)" -lt "$deadline5" ]; do
  done_match=$(find "$SBX_OVERSEER/done" -name 'item-ok-1*.md' | wc -l | tr -d ' ')
  if [ "$done_match" -ge 1 ]; then break; fi
  _overseer --once >/dev/null 2>&1 || true
  sleep 0.5
done
done_match=$(find "$SBX_OVERSEER/done" -name 'item-ok-1*.md' | wc -l | tr -d ' ')
_assert_eq "item in done/ (any pid suffix)" "1" "$done_match"
_assert_file_not_exists "worktree removed" "$SANDBOX_WORKTREES/wt_item-ok-1"

# Test 6: Worker stub exit 1 → failed/, audit.
printf '\nTest 6: worker exit 1 → failed/\n'
_reset
_write_item item-fail-1
_set_worker 1
_overseer --once >/dev/null 2>&1
# Workers are async — wait for reap to move item to failed/
deadline6=$(( $(date +%s) + 30 ))
while [ "$(date +%s)" -lt "$deadline6" ]; do
  fail_match=$(find "$SBX_OVERSEER/failed" -name 'item-fail-1*.md' | wc -l | tr -d ' ')
  if [ "$fail_match" -ge 1 ]; then break; fi
  _overseer --once >/dev/null 2>&1 || true
  sleep 0.5
done
fail_match=$(find "$SBX_OVERSEER/failed" -name 'item-fail-1*.md' | wc -l | tr -d ' ')
_assert_eq "item in failed/ (any pid suffix)" "1" "$fail_match"
today="$(date -u +%Y-%m-%d)"
if grep -q 'item-fail-1' "$SBX_REPO/.claude/audit/${today}.md" 2>/dev/null; then
  _pass "audit recorded the failure"
else
  _fail "audit did not record failure for item-fail-1"
fi

# Test 7: Worker stub exit 2 → PANIC, item back to inbox.
printf '\nTest 7: worker exit 2 → PANIC, item back to inbox\n'
_reset
_write_item item-panic-w-1
_set_worker 2
_overseer --once 2>&1 | grep -E 'spawned|reap' >&2 || true
# Workers are async — wait for reap to write PANIC marker
deadline7=$(( $(date +%s) + 30 ))
while [ "$(date +%s)" -lt "$deadline7" ]; do
  if [ -f "$SBX_OVERSEER/PANIC" ]; then break; fi
  _overseer --once 2>&1 | grep -E 'spawned|reap' >&2 || true
  sleep 0.5
done
# Wait briefly for any lingering background renames to finish before _reset
sleep 0.5
_assert_file_exists "PANIC marker written by worker exit 2" \
  "$SBX_OVERSEER/PANIC"
_assert_file_exists "item returned to inbox" \
  "$SBX_OVERSEER/inbox/item-panic-w-1.md"
_assert_file_not_exists "item NOT in failed/" \
  "$SBX_OVERSEER/failed/item-panic-w-1.md"
rm -f "$SBX_OVERSEER/PANIC"

# Test 8: Lock conflict — second --once exits silent while first holds lock.
printf '\nTest 8: lock conflict\n'
_reset
_write_item item-lock-1
# Run first overseer in the background with a short-sleep mock worker
# (enough to hold the lock, but not so long it slows the suite)
cat > "$WORKER_SH" <<'EOF'
#!/usr/bin/env bash
sleep 2
exit 0
EOF
chmod +x "$WORKER_SH"

_overseer --once >/dev/null 2>&1 &
first_pid=$!
# Wait until lock is held (or first completes).
sleep 0.5
# Second invocation should exit 0 silently (no item picked).
_overseer --once >/dev/null 2>&1
rc=$?
_assert_eq "second --once exits 0 silently" "0" "$rc"
# Wait for first overseer to finish, then reap the background worker.
wait "$first_pid" || true
# IMPORTANT: do NOT call _set_worker here — the inner worker (bash worker.sh,
# spawned async by _pool_spawn) is still running "sleep 2". On bash 3.2 macOS,
# overwriting the script file while bash reads it incrementally causes a syntax
# error (rc=2), which the reaper interprets as a worker PANIC. Wait for the reap
# to complete first; _set_worker 0 is called at the end of the test.
# Reap: keep ticking until item lands in done/ (or timeout).
deadline8=$(( $(date +%s) + 30 ))
while [ "$(date +%s)" -lt "$deadline8" ]; do
  total_processed=$(( $(find "$SBX_OVERSEER/done" -name '*.md' | wc -l) + \
                      $(find "$SBX_OVERSEER/failed" -name '*.md' | wc -l) ))
  if [ "$total_processed" -ge 1 ]; then break; fi
  _overseer --once >/dev/null 2>&1 || true
  sleep 0.5
done
total_processed=$(( $(find "$SBX_OVERSEER/done" -name '*.md' | wc -l) + \
                    $(find "$SBX_OVERSEER/failed" -name '*.md' | wc -l) ))
_assert_eq "exactly 1 item processed under lock contention" "1" "$total_processed"
_set_worker 0

# Test 9: Bestehender Headless-Runner unangetastet (separate inbox path).
printf '\nTest 9: legacy backlog inbox untouched\n'
_reset
mkdir -p "$SBX_REPO/.claude/backlog/inbox"
echo "legacy item" > "$SBX_REPO/.claude/backlog/inbox/legacy.md"
_write_item item-isolated
_overseer --once >/dev/null 2>&1
_assert_file_exists "legacy backlog inbox item still untouched" \
  "$SBX_REPO/.claude/backlog/inbox/legacy.md"
_assert_file_not_exists "no legacy lock file created" \
  "$SBX_REPO/.claude/backlog/.lock"

# Test 10: Recover orphans — item with dead PID returns to inbox.
printf '\nTest 10: orphan recovery\n'
_reset
_write_item item-fresh
# Inject orphan: make a fake in_progress file with a definitely-dead PID.
echo "orphan body" > "$SBX_OVERSEER/in_progress/orphan-slug.999999.md"
_overseer --once >/dev/null 2>&1
# orphan should now be back in inbox under [recovered]-* name
recovered=$(find "$SBX_OVERSEER/inbox" -name '*recovered*orphan*' | wc -l | tr -d ' ')
_assert_eq "orphan recovered to inbox" "1" "$recovered"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Summary: PASS=%d FAIL=%d ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
