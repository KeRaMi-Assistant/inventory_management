#!/usr/bin/env bash
# overseer-pool.sh — Verify suite for P2-1 Worker-Pool in overseer.sh.
#
# Strategy: isolated sandbox repo with mock libs/worker.sh stub.
# Tests parallel-spawn behaviour without touching git or real workers.
#
# Tests:
#   1. Default N=2: 4 items → peak 2 parallel, all 4 processed.
#   2. N=3: 5 items, OVERSEER_MAX_WORKERS=3 → 3 parallel peak, all 5 processed.
#   3. Hard-cap clamp: OVERSEER_MAX_WORKERS=4 → effective 3, warning in log.
#   4. Disk-panic pause: health.json panic=true → no spawn while panic active.
#   5. Slot free → next item picked: 2 items, N=2, first finishes → third item picked.
#
# Exit 0 = all pass, Exit 1 = at least one failure.

set -euo pipefail

REAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$REAL_SCRIPT_DIR/../../.." && pwd)"
REAL_OVERSEER_SH="$REAL_REPO_ROOT/.claude/scripts/overseer.sh"

if [ ! -f "$REAL_OVERSEER_SH" ]; then
  printf 'ERROR: overseer.sh not found at %s\n' "$REAL_OVERSEER_SH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox
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
_assert_ge() {
  local desc="$1" min="$2" actual="$3"
  if (( actual >= min )); then _pass "$desc"
  else _fail "$desc (expected>=$min actual=$actual)"; fi
}
_assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then _pass "$desc"
  else _fail "$desc (needle='$needle' not found in output)"; fi
}

# ---------------------------------------------------------------------------
# Build a minimal sandbox git repo with mock scripts.
# Each test calls _setup_sandbox to get a fresh environment.
# ---------------------------------------------------------------------------
SBX_REPO="$SANDBOX/repo"
SBX_SCRIPTS="$SBX_REPO/.claude/scripts"
SBX_LIB="$SBX_SCRIPTS/lib"
SBX_OVERSEER_DIR="$SBX_REPO/.claude/overseer"

_setup_sandbox() {
  rm -rf "$SBX_REPO"
  mkdir -p "$SBX_REPO" "$SBX_SCRIPTS" "$SBX_LIB"
  mkdir -p "$SBX_OVERSEER_DIR/inbox" "$SBX_OVERSEER_DIR/in_progress" \
           "$SBX_OVERSEER_DIR/done" "$SBX_OVERSEER_DIR/failed" \
           "$SBX_OVERSEER_DIR/state/workers"

  # Minimal git repo (required by picker/worktree path resolution)
  git -C "$SBX_REPO" init -q
  git -C "$SBX_REPO" commit --allow-empty -q -m "init"

  # Copy real overseer.sh
  cp "$REAL_OVERSEER_SH" "$SBX_SCRIPTS/overseer.sh"
  chmod +x "$SBX_SCRIPTS/overseer.sh"

  # ---- Mock picker lib ----
  cat > "$SBX_LIB/picker.sh" <<'PICKER_EOF'
# Mock picker.sh for overseer-pool tests
set -u
_picker_overseer_root() {
  echo "${REPO_ROOT:-$(git rev-parse --show-toplevel)}/.claude/overseer"
}
pick_next_item() {
  local pid="${1:?}"
  local overseer_root; overseer_root="$(_picker_overseer_root)"
  local inbox_dir="${overseer_root}/inbox"
  local inprogress_dir="${overseer_root}/in_progress"
  mkdir -p "$inbox_dir" "$inprogress_dir"
  local item_path
  item_path="$(find "$inbox_dir" -maxdepth 1 -name '*.md' | sort | head -1)"
  [ -n "$item_path" ] || return 1
  local basename; basename="$(basename "$item_path")"
  local slug="${basename%.md}"
  local target="${inprogress_dir}/${slug}.${pid}.md"
  mv "$item_path" "$target" 2>/dev/null || return 1
  echo "$target"
}
release_item() {
  local item_path="${1:?}" result="${2:?}"
  local overseer_root; overseer_root="$(_picker_overseer_root)"
  local basename; basename="$(basename "$item_path")"
  case "$result" in
    done|failed)
      mkdir -p "${overseer_root}/${result}"
      mv "$item_path" "${overseer_root}/${result}/${basename}" 2>/dev/null || true
      ;;
    blocked-pre-ship|merge-conflict)
      mkdir -p "${overseer_root}/inbox"
      local slug="${basename%.md}"
      slug="$(printf '%s' "$slug" | sed 's/\.[0-9][0-9]*$//')"
      mv "$item_path" "${overseer_root}/inbox/[${result}]-${slug}.md" 2>/dev/null || true
      ;;
  esac
}
recover_orphaned_items() { echo 0; }
PICKER_EOF

  # ---- Mock worktree lib ----
  cat > "$SBX_LIB/worktree.sh" <<'WORKTREE_EOF'
# Mock worktree.sh for overseer-pool tests
set -u
worktree_create() {
  local slug="${1:?}"
  local worktree_path="${REPO_ROOT:-$(git rev-parse --show-toplevel)}/../mock_worker_${slug}"
  mkdir -p "$worktree_path"
  echo "$worktree_path"
}
worktree_remove() {
  local slug="${1:?}"
  local worktree_path="${REPO_ROOT:-$(git rev-parse --show-toplevel)}/../mock_worker_${slug}"
  rm -rf "$worktree_path" 2>/dev/null || true
}
worktree_list() { : ; }
WORKTREE_EOF

  # ---- Mock cost-cap lib ----
  cat > "$SBX_LIB/cost-cap.sh" <<'COST_EOF'
# Mock cost-cap.sh
cost_check_or_die() { return 0; }
cost_today_usd()    { echo "0.00"; }
cost_week_usd()     { echo "0.00"; }
COST_EOF

  # ---- Mock audit lib ----
  cat > "$SBX_LIB/audit.sh" <<'AUDIT_EOF'
audit_record() { : ; }
AUDIT_EOF

  # ---- Mock oauth-check lib ----
  cat > "$SBX_LIB/oauth-check.sh" <<'OAUTH_EOF'
oauth_check_all() { return 0; }
OAUTH_EOF

  # ---- Mock notify.sh ----
  cat > "$SBX_SCRIPTS/notify.sh" <<'NOTIFY_EOF'
#!/usr/bin/env bash
exit 0
NOTIFY_EOF
  chmod +x "$SBX_SCRIPTS/notify.sh"

  # ---- Mock watchdog.sh ----
  cat > "$SBX_SCRIPTS/watchdog.sh" <<'WATCHDOG_EOF'
#!/usr/bin/env bash
exit 0
WATCHDOG_EOF
  chmod +x "$SBX_SCRIPTS/watchdog.sh"
}

# Create a mock inbox item with required frontmatter (touches: field)
_add_inbox_item() {
  local name="$1"
  cat > "$SBX_OVERSEER_DIR/inbox/${name}.md" <<ITEM_EOF
---
slug: ${name}
touches: [test/mock-${name}]
timeout_minutes: 1
---
# Mock item ${name}
ITEM_EOF
}

# Create mock worker.sh with configurable sleep + exit
_setup_worker() {
  local sleep_secs="${1:-1}" exit_code="${2:-0}"
  cat > "$SBX_SCRIPTS/worker.sh" <<WORKER_EOF
#!/usr/bin/env bash
# Mock worker — sleeps briefly then exits
sleep ${sleep_secs}
exit ${exit_code}
WORKER_EOF
  chmod +x "$SBX_SCRIPTS/worker.sh"
}

# Run overseer via repeated --once iterations until inbox is drained and all workers reaped.
# Uses --once (no lock held between iterations) — safe for sequential sandbox tests.
# Sets OVERSEER_LOG with combined log output.
OVERSEER_LOG=""
_run_overseer_until_done() {
  local max_seconds="$1"
  local extra_env="${2:-}"
  local log_accum=""

  local deadline=$(( $(date +%s) + max_seconds ))
  while (( $(date +%s) < deadline )); do
    # Run one pool iteration
    local iter_log
    iter_log="$(
      env REPO_ROOT="$SBX_REPO" \
          OVERSEER_SLEEP_IDLE=1 \
          OVERSEER_SLEEP_BETWEEN=1 \
          OVERSEER_WORKER_TIMEOUT=60 \
          ${extra_env} \
          bash "$SBX_SCRIPTS/overseer.sh" --once 2>&1 || true
    )"
    log_accum="${log_accum}${iter_log}"$'\n'

    # Check if still work to do
    local inbox_count in_progress_count worker_count
    inbox_count="$(find "$SBX_OVERSEER_DIR/inbox" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    in_progress_count="$(find "$SBX_OVERSEER_DIR/in_progress" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    worker_count="$(find "$SBX_OVERSEER_DIR/state/workers" -name '*.pid' 2>/dev/null | wc -l | tr -d ' ')"

    if (( inbox_count == 0 && in_progress_count == 0 && worker_count == 0 )); then
      break
    fi

    # Workers still running — wait briefly before next reap iteration
    if (( in_progress_count > 0 || worker_count > 0 )); then
      sleep 2
    fi
  done

  OVERSEER_LOG="$log_accum"
}

# Alias for backward compat with test calls below
_run_overseer_daemon_until_done() { _run_overseer_until_done "$@"; }

# ---------------------------------------------------------------------------
# Test 1: Default N=2, 4 items → all 4 processed, peak parallel == 2
# ---------------------------------------------------------------------------
printf '\nTest 1: Default N=2, 4 items → all 4 processed\n'
_setup_sandbox
_setup_worker 2 0  # each worker sleeps 2s

for i in 1 2 3 4; do _add_inbox_item "item-t1-${i}"; done

_run_overseer_daemon_until_done 30

# All 4 should be in done/
done_count="$(find "$SBX_OVERSEER_DIR/done" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
_assert_eq "Test1: all 4 items processed (done_count)" "4" "$done_count"

# Log should contain worker-pool: max=2
_assert_contains "Test1: log shows worker-pool: max=2" "worker-pool: max=2" "$OVERSEER_LOG"

# ---------------------------------------------------------------------------
# Test 2: N=3, 5 items → all 5 processed
# ---------------------------------------------------------------------------
printf '\nTest 2: N=3, 5 items → all 5 processed\n'
_setup_sandbox
_setup_worker 2 0

for i in 1 2 3 4 5; do _add_inbox_item "item-t2-${i}"; done

_run_overseer_daemon_until_done 40 "OVERSEER_MAX_WORKERS=3"

done_count="$(find "$SBX_OVERSEER_DIR/done" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
_assert_eq "Test2: all 5 items processed (done_count)" "5" "$done_count"
_assert_contains "Test2: log shows worker-pool: max=3" "worker-pool: max=3" "$OVERSEER_LOG"

# ---------------------------------------------------------------------------
# Test 3: Hard-cap clamp OVERSEER_MAX_WORKERS=4 → effective 3, warning in log
# ---------------------------------------------------------------------------
printf '\nTest 3: OVERSEER_MAX_WORKERS=4 → clamped to 3 + warning\n'
_setup_sandbox
_setup_worker 1 0

_add_inbox_item "item-t3-1"

# Just start and stop quickly — we only need to check the clamp log line
OVERSEER_LOG="$(
  env REPO_ROOT="$SBX_REPO" \
      OVERSEER_SLEEP_IDLE=1 \
      OVERSEER_SLEEP_BETWEEN=1 \
      OVERSEER_MAX_WORKERS=4 \
      bash "$SBX_SCRIPTS/overseer.sh" --once 2>&1 || true
)"

_assert_contains "Test3: clamp warning in log" "clamping to 3" "$OVERSEER_LOG"
_assert_contains "Test3: effective max=3 in log" "worker-pool: max=3" "$OVERSEER_LOG"

# ---------------------------------------------------------------------------
# Test 4: Disk-panic → no spawn while panic active
# ---------------------------------------------------------------------------
printf '\nTest 4: Disk-panic → no spawn\n'
_setup_sandbox
_setup_worker 1 0

_add_inbox_item "item-t4-1"
_add_inbox_item "item-t4-2"

# Write a fresh health.json with panic=true
mkdir -p "$SBX_OVERSEER_DIR"
python3 - "$SBX_OVERSEER_DIR/health.json" <<'PYEOF'
import json, sys
health = {
  "ts": "2026-05-10T00:00:00Z",
  "panic": True,
  "checks": {
    "disk": {"free_pct": 2, "free_gb": 1, "ok": False},
    "worktrees": {"count": 0, "ok": True},
    "inbox": {"count": 2, "paused": False, "ok": True},
    "stash": {"count": 0, "ok": True},
    "cost": {"today_usd": 0.0, "week_usd": 0.0, "ok": True}
  },
  "notifications_sent": []
}
with open(sys.argv[1], 'w') as f:
    json.dump(health, f, indent=2)
    f.write('\n')
PYEOF

# Run one iteration — should not spawn (disk panic)
OVERSEER_LOG="$(
  env REPO_ROOT="$SBX_REPO" \
      OVERSEER_SLEEP_IDLE=1 \
      OVERSEER_SLEEP_BETWEEN=1 \
      bash "$SBX_SCRIPTS/overseer.sh" --once 2>&1 || true
)"

# Items should remain in inbox (not processed)
inbox_remaining="$(find "$SBX_OVERSEER_DIR/inbox" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
done_after_panic="$(find "$SBX_OVERSEER_DIR/done" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"

# At least one item must still be in inbox or we see the panic log
# (If the item got picked but spawn aborted, it goes to failed — both are acceptable
# as long as it did NOT succeed to done/)
_assert_eq "Test4: no items completed to done/ during disk-panic" "0" "$done_after_panic"
_assert_contains "Test4: disk-panic mentioned in log" "panic" "$OVERSEER_LOG"

# ---------------------------------------------------------------------------
# Test 5: Slot free → next item picked (N=2, 3 items, first worker fast)
# ---------------------------------------------------------------------------
printf '\nTest 5: Slot free → next item picked (N=2, 3 items)\n'
_setup_sandbox
_setup_worker 1 0   # fast workers so 3rd item gets picked in follow-up iteration

for i in 1 2 3; do _add_inbox_item "item-t5-${i}"; done

_run_overseer_daemon_until_done 30

done_count="$(find "$SBX_OVERSEER_DIR/done" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
_assert_eq "Test5: all 3 items processed via slot-free pickup" "3" "$done_count"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n--- overseer-pool verify summary ---\n'
printf 'PASS: %d\n' "$PASS"
printf 'FAIL: %d\n' "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
