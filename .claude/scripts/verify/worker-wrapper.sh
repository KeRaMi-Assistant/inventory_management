#!/usr/bin/env bash
# verify/worker-wrapper.sh — Sandbox tests for .claude/scripts/worker.sh (P1-2).
#
# Strategy: mktemp sandbox repo + mock `claude` on PATH that records its argv
# and env into log files we can inspect. Run worker.sh against the sandbox
# and assert exit code, env scrubbing, sentinel handling, pre-ship gates,
# cost-event recording, PANIC handling.
#
# Exit 0 = all tests pass, 1 = at least one failure.

set -uo pipefail

REAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$REAL_SCRIPT_DIR/../../.." && pwd)"
REAL_WORKER_SH="$REAL_REPO_ROOT/.claude/scripts/worker.sh"

if [ ! -f "$REAL_WORKER_SH" ]; then
  printf 'ERROR: worker.sh not found at %s\n' "$REAL_WORKER_SH" >&2
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
_section() { printf '\n=== %s ===\n' "$1"; }

SBX_REPO="$SANDBOX/repo"
SBX_SCRIPTS="$SBX_REPO/.claude/scripts"
SBX_LIB="$SBX_SCRIPTS/lib"
SBX_OVERSEER="$SBX_REPO/.claude/overseer"
SBX_RUNS="$SBX_REPO/.claude/backlog/runs"
SBX_INBOX="$SBX_OVERSEER/inbox"
SBX_TESTRUNS="$SBX_REPO/.claude/test-runs"

mkdir -p "$SBX_SCRIPTS" "$SBX_LIB" "$SBX_OVERSEER" "$SBX_RUNS" "$SBX_INBOX" \
         "$SBX_TESTRUNS" "$SBX_REPO/lib/screens" "$SBX_REPO/lib/services"

# Init git
(cd "$SBX_REPO" && git init -q -b main \
   && git config user.email t@t && git config user.name t \
   && echo "init" > README.md \
   && git add README.md \
   && git commit -q -m init) >/dev/null 2>&1

# Copy real worker.sh into sandbox so SCRIPT_DIR resolution finds sandbox libs.
cp "$REAL_WORKER_SH" "$SBX_SCRIPTS/worker.sh"
chmod +x "$SBX_SCRIPTS/worker.sh"

# Real cost-cap.sh + audit.sh.
cp "$REAL_REPO_ROOT/.claude/scripts/lib/cost-cap.sh" "$SBX_LIB/cost-cap.sh"
cp "$REAL_REPO_ROOT/.claude/scripts/lib/audit.sh"    "$SBX_LIB/audit.sh"

# Mock notify.sh — no-op.
cat > "$SBX_SCRIPTS/notify.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$SBX_SCRIPTS/notify.sh"

# Mock check-l10n.py — controlled by env L10N_FAIL.
cat > "$SBX_SCRIPTS/check-l10n.py" <<'EOF'
#!/usr/bin/env python3
import os, sys
sys.exit(1 if os.environ.get("L10N_FAIL") == "1" else 0)
EOF
chmod +x "$SBX_SCRIPTS/check-l10n.py"

# ---------------------------------------------------------------------------
# Mock claude — records argv + selected env vars into a per-call file.
# Behavior controlled by env vars set per test:
#   MOCK_CLAUDE_OUTPUT  — extra text to write to its stdout (gets captured into RUN_LOG)
#   MOCK_CLAUDE_EXIT    — exit code to return (default 0)
#   MOCK_CLAUDE_TOUCH   — file (relative to CLAUDE_PROJECT_DIR) to create + commit
#   MOCK_CLAUDE_PANIC   — if "1": touch the PANIC marker mid-run, then sleep
# ---------------------------------------------------------------------------
MOCK_BIN="$SANDBOX/mockbin"
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
LOG_FILE="${MOCK_CLAUDE_LOG:-/tmp/mock-claude.log}"
{
  echo "=== mock claude invocation ==="
  echo "argv: $*"
  echo "env GH_TOKEN=${GH_TOKEN-<unset>}"
  echo "env SUPABASE_ACCESS_TOKEN=${SUPABASE_ACCESS_TOKEN-<unset>}"
  echo "env SUPABASE_DB_PASSWORD=${SUPABASE_DB_PASSWORD-<unset>}"
  echo "env HEADLESS_MODE=${HEADLESS_MODE-<unset>}"
  echo "env OVERSEER_WORKER_PID=${OVERSEER_WORKER_PID-<unset>}"
  echo "env CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR-<unset>}"
  echo "cwd: $(pwd)"
} >> "$LOG_FILE"

# Stdout is captured into the worker's RUN_LOG.
echo "mock-claude: starting"
if [ -n "${MOCK_CLAUDE_OUTPUT:-}" ]; then
  printf '%s\n' "$MOCK_CLAUDE_OUTPUT"
fi
echo "Total cost: \$0.42"

# Optionally touch + commit a file in the worktree.
if [ -n "${MOCK_CLAUDE_TOUCH:-}" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  target="$CLAUDE_PROJECT_DIR/$MOCK_CLAUDE_TOUCH"
  mkdir -p "$(dirname "$target")"
  echo "// mock content" > "$target"
  git -C "$CLAUDE_PROJECT_DIR" add "$MOCK_CLAUDE_TOUCH" >/dev/null 2>&1 || true
  git -C "$CLAUDE_PROJECT_DIR" -c user.email=m@m -c user.name=m \
    commit -q -m "mock: touch $MOCK_CLAUDE_TOUCH" >/dev/null 2>&1 || true
fi

# Optional PANIC injection.
if [ "${MOCK_CLAUDE_PANIC:-0}" = "1" ]; then
  touch "$PANIC_MARKER_PATH"
  # Sleep so the watcher (30s tick) catches it. Use a small marker-ack file
  # so the test can shorten this for CI: poll a kill instead.
  for _ in $(seq 1 60); do
    sleep 1
  done
fi

exit "${MOCK_CLAUDE_EXIT:-0}"
EOF
chmod +x "$MOCK_BIN/claude"

# Make the mock claude visible BEFORE any real one.
export PATH="$MOCK_BIN:$PATH"

# Common env for worker calls
export REPO_ROOT="$SBX_REPO"
export CLAUDE_PROJECT_DIR="$SBX_REPO"
export OVERSEER_WORKER_PID="$$"
export HEADLESS_MODE=1
export COST_CAP_LEDGER_DIR="$SBX_OVERSEER"

# Helper to write an item file
write_item() {
  local name="$1"
  local fm_block="$2"
  local body="$3"
  cat > "$SBX_INBOX/$name" <<ITEM
---
$fm_block
---

$body
ITEM
  printf '%s' "$SBX_INBOX/$name"
}

# Run worker.sh in a clean child env to avoid set -e contamination.
run_worker() {
  local item="$1"
  shift
  set +e
  ( bash "$SBX_SCRIPTS/worker.sh" "$item" "$SBX_REPO" "$@" ) >>"$WORKER_OUT" 2>&1
  echo $?
  set -e
}

WORKER_OUT="$SANDBOX/worker.out"
: > "$WORKER_OUT"

export PANIC_MARKER_PATH="$SBX_OVERSEER/PANIC"

# ---------------------------------------------------------------------------
# Test 1: missing budget_usd → exit 1
# ---------------------------------------------------------------------------
_section "Test 1: missing budget_usd → exit 1"

ITEM1="$(write_item "no-budget.md" "slug: no-budget
source: tier-1" "body without budget")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-1.log"
export MOCK_CLAUDE_OUTPUT=""
export MOCK_CLAUDE_EXIT=0
export MOCK_CLAUDE_TOUCH=""
export MOCK_CLAUDE_PANIC=0

ec="$(run_worker "$ITEM1")"
[ "$ec" = "1" ] && _pass "exit 1 on missing budget_usd" \
  || _fail "expected exit 1, got $ec on missing budget_usd"

# ---------------------------------------------------------------------------
# Test 2: default model = sonnet
# ---------------------------------------------------------------------------
_section "Test 2: default model sonnet"

ITEM2="$(write_item "default-model.md" "slug: default-model
budget_usd: 0.50
source: tier-1
touches: [lib/services/foo.dart]" "default model body")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-2.log"
ec="$(run_worker "$ITEM2")"
if grep -q -- "--model sonnet" "$MOCK_CLAUDE_LOG" 2>/dev/null; then
  _pass "claude invoked with --model sonnet (default)"
else
  _fail "expected --model sonnet in mock log"
fi

# ---------------------------------------------------------------------------
# Test 3: model override → opus
# ---------------------------------------------------------------------------
_section "Test 3: model override opus"

ITEM3="$(write_item "opus-model.md" "slug: opus-model
budget_usd: 1.00
model: opus
source: analyzer
touches: [lib/services/bar.dart]" "body")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-3.log"
ec="$(run_worker "$ITEM3")"
if grep -q -- "--model opus" "$MOCK_CLAUDE_LOG"; then
  _pass "claude invoked with --model opus on override"
else
  _fail "expected --model opus on override"
fi

# ---------------------------------------------------------------------------
# Test 4: needs_gh: false → GH_TOKEN empty in worker subshell
# ---------------------------------------------------------------------------
_section "Test 4: needs_gh false scrubs GH_TOKEN"

ITEM4="$(write_item "no-gh.md" "slug: no-gh
budget_usd: 0.10
source: tier-1
touches: [lib/services/baz.dart]" "body")"

export GH_TOKEN="ghs_parent_secret"
export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-4.log"
ec="$(run_worker "$ITEM4")"
# Acceptable forms: GH_TOKEN= (empty) or <unset>
if grep -q "env GH_TOKEN=$" "$MOCK_CLAUDE_LOG" \
   || grep -q "env GH_TOKEN=<unset>" "$MOCK_CLAUDE_LOG"; then
  _pass "GH_TOKEN scrubbed when needs_gh=false"
else
  _fail "GH_TOKEN leaked: $(grep 'GH_TOKEN' "$MOCK_CLAUDE_LOG" || echo 'not found')"
fi

# ---------------------------------------------------------------------------
# Test 5: needs_gh: true → GH_TOKEN passed through
# ---------------------------------------------------------------------------
_section "Test 5: needs_gh true passes GH_TOKEN"

ITEM5="$(write_item "yes-gh.md" "slug: yes-gh
budget_usd: 0.10
source: tier-1
needs_gh: true
touches: [lib/services/qux.dart]" "body")"

export GH_TOKEN="ghs_parent_secret_AAA"
export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-5.log"
ec="$(run_worker "$ITEM5")"
if grep -q "env GH_TOKEN=ghs_parent_secret_AAA" "$MOCK_CLAUDE_LOG"; then
  _pass "GH_TOKEN passed through when needs_gh=true"
else
  _fail "GH_TOKEN not passed: $(grep 'GH_TOKEN' "$MOCK_CLAUDE_LOG" || echo 'not found')"
fi

# ---------------------------------------------------------------------------
# Test 6: SUPABASE_ACCESS_TOKEN always scrubbed
# ---------------------------------------------------------------------------
_section "Test 6: SUPABASE_* always empty"

ITEM6="$(write_item "supa.md" "slug: supa
budget_usd: 0.10
source: tier-1
needs_gh: true
touches: [lib/services/zz.dart]" "body")"

export SUPABASE_ACCESS_TOKEN="sbp_parent_should_not_leak"
export SUPABASE_DB_PASSWORD="db_parent_should_not_leak"
export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-6.log"
ec="$(run_worker "$ITEM6")"
if grep -qE "env SUPABASE_ACCESS_TOKEN=(\$|<unset>)" "$MOCK_CLAUDE_LOG" \
   && grep -qE "env SUPABASE_DB_PASSWORD=(\$|<unset>)" "$MOCK_CLAUDE_LOG"; then
  _pass "SUPABASE_* tokens scrubbed in worker env"
else
  _fail "SUPABASE_* tokens leaked: $(grep SUPABASE "$MOCK_CLAUDE_LOG" || true)"
fi
unset SUPABASE_ACCESS_TOKEN SUPABASE_DB_PASSWORD
unset GH_TOKEN

# ---------------------------------------------------------------------------
# Test 7: pre-ship audit violation (UI touched, no green report) → exit 3
# ---------------------------------------------------------------------------
_section "Test 7: UI touched + no audit report → exit 3 + sentinel"

# Reset working tree (commits from previous tests don't matter; we use
# uncommitted changes via MOCK_CLAUDE_TOUCH — which goes through commit).
ITEM7="$(write_item "ui-no-audit.md" "slug: ui-no-audit
budget_usd: 0.20
source: tier-1
touches: [lib/screens/foo_screen.dart]" "modify a screen")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-7.log"
export MOCK_CLAUDE_TOUCH="lib/screens/foo_screen.dart"
# No test-runs report present → blocked.
rm -rf "$SBX_TESTRUNS"
mkdir -p "$SBX_TESTRUNS"

ec="$(run_worker "$ITEM7")"
[ "$ec" = "3" ] && _pass "exit 3 (blocked-pre-ship) when UI touched + no audit" \
  || _fail "expected exit 3, got $ec"

# Verify sentinel in latest run-log
LATEST_LOG="$(ls -t "$SBX_RUNS"/*.log 2>/dev/null | head -n 1)"
if grep -q "## Result: blocked-pre-ship" "$LATEST_LOG" 2>/dev/null; then
  _pass "run-log contains blocked-pre-ship sentinel"
else
  _fail "run-log missing blocked-pre-ship sentinel ($LATEST_LOG)"
fi
export MOCK_CLAUDE_TOUCH=""

# ---------------------------------------------------------------------------
# Test 8: non-UI path touched → no pre-ship gate, exit 0
# ---------------------------------------------------------------------------
_section "Test 8: non-UI path → no pre-ship gate"

ITEM8="$(write_item "service-only.md" "slug: service-only
budget_usd: 0.15
source: tier-1
touches: [lib/services/svc.dart]" "service body")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-8.log"
export MOCK_CLAUDE_TOUCH="lib/services/svc.dart"
ec="$(run_worker "$ITEM8")"
[ "$ec" = "0" ] && _pass "exit 0 when only services/ touched (no UI gate)" \
  || _fail "expected exit 0, got $ec"
export MOCK_CLAUDE_TOUCH=""

# ---------------------------------------------------------------------------
# Test 9: cost_record was invoked (ledger has entry for slug)
# ---------------------------------------------------------------------------
_section "Test 9: cost-event recorded"

LEDGER="$SBX_OVERSEER/cost-ledger.jsonl"
if [ -f "$LEDGER" ] && grep -q '"agent":"worker-' "$LEDGER"; then
  _pass "cost-ledger has worker-* entries"
else
  _fail "cost-ledger missing or no worker entries"
fi

# ---------------------------------------------------------------------------
# Test 10: PANIC marker → worker exit 2
# ---------------------------------------------------------------------------
_section "Test 10: PANIC marker → exit 2"

ITEM10="$(write_item "panic-item.md" "slug: panic-item
budget_usd: 0.10
source: tier-1
touches: [lib/services/p.dart]" "body")"

# We don't want to wait 30s for the watcher tick. Instead, pre-create the
# PANIC marker and run claude with non-zero exit + grep tampering pattern
# to trigger the synthetic PANIC sentinel path. We use the cost-cap-tampering
# detector: it is a deterministic exit 2 path that doesn't depend on timing.
export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-10.log"
export MOCK_CLAUDE_OUTPUT="rm /tmp/cost-ledger.jsonl"
ec="$(run_worker "$ITEM10")"
[ "$ec" = "2" ] && _pass "exit 2 on cost-cap tampering (PANIC sentinel)" \
  || _fail "expected exit 2, got $ec"
export MOCK_CLAUDE_OUTPUT=""
LATEST_LOG="$(ls -t "$SBX_RUNS"/*.log 2>/dev/null | head -n 1)"
if grep -q "## Result: panic-abort" "$LATEST_LOG" 2>/dev/null; then
  _pass "panic-abort sentinel written"
else
  _fail "missing panic-abort sentinel"
fi

# ---------------------------------------------------------------------------
# Test 11: sentinel `## Result: failed` → exit 1
# ---------------------------------------------------------------------------
_section "Test 11: sentinel failed → exit 1"

ITEM11="$(write_item "fail-sentinel.md" "slug: fail-sentinel
budget_usd: 0.10
source: tier-1
touches: [lib/services/f.dart]" "body")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-11.log"
export MOCK_CLAUDE_OUTPUT="## Result: failed
giving up because reasons"
ec="$(run_worker "$ITEM11")"
[ "$ec" = "1" ] && _pass "exit 1 on '## Result: failed' sentinel" \
  || _fail "expected exit 1, got $ec"
export MOCK_CLAUDE_OUTPUT=""

# ---------------------------------------------------------------------------
# Test 12: run-log file exists in expected path
# ---------------------------------------------------------------------------
_section "Test 12: run-log path"

if compgen -G "$SBX_RUNS/*.log" >/dev/null 2>&1; then
  _pass "run-log files exist under .claude/backlog/runs/"
else
  _fail "no run-log files under $SBX_RUNS"
fi

# Also check filename pattern <ts>-<slug>.log for at least one
if ls "$SBX_RUNS" | grep -qE '^[0-9]{8}-[0-9]{6}-.+\.log$'; then
  _pass "run-log filename matches <ts>-<slug>.log pattern"
else
  _fail "run-log filename pattern incorrect"
fi

# ---------------------------------------------------------------------------
# Bonus: pre-ship gate passes when smoke-full-app-audit report is green.
# ---------------------------------------------------------------------------
_section "Test 13: pre-ship gate passes with green audit report"

mkdir -p "$SBX_TESTRUNS/20260510-000000-mock"
cat > "$SBX_TESTRUNS/20260510-000000-mock/report.md" <<'EOF'
# Mock Smoke-Full-App-Audit Report
Result: passed
EOF

ITEM13="$(write_item "ui-with-audit.md" "slug: ui-with-audit
budget_usd: 0.20
source: tier-1
touches: [lib/screens/bar_screen.dart]" "modify another screen")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-13.log"
export MOCK_CLAUDE_TOUCH="lib/screens/bar_screen.dart"
export L10N_FAIL=0
# Patch worker via PATH to make our mock check-l10n.py the one used:
# worker.sh references $REPO_ROOT/.claude/scripts/check-l10n.py → already present.
ec="$(run_worker "$ITEM13")"
[ "$ec" = "0" ] && _pass "exit 0 when UI touched + green audit + l10n clean" \
  || _fail "expected exit 0, got $ec"
export MOCK_CLAUDE_TOUCH=""

# ---------------------------------------------------------------------------
# Test 14: l10n-checker fails → blocked-pre-ship
# ---------------------------------------------------------------------------
_section "Test 14: l10n fail → exit 3"

ITEM14="$(write_item "ui-l10n-fail.md" "slug: ui-l10n-fail
budget_usd: 0.20
source: tier-1
touches: [lib/l10n/app_de.arb]" "broken arb")"

export MOCK_CLAUDE_LOG="$SANDBOX/mock-claude-14.log"
export MOCK_CLAUDE_TOUCH="lib/l10n/app_de.arb"
export L10N_FAIL=1
ec="$(run_worker "$ITEM14")"
[ "$ec" = "3" ] && _pass "exit 3 when l10n-checker fails on UI change" \
  || _fail "expected exit 3, got $ec"
export L10N_FAIL=0
export MOCK_CLAUDE_TOUCH=""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Summary ===\n'
printf '  PASS: %d\n' "$PASS"
printf '  FAIL: %d\n' "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf '\nWorker output excerpt:\n'
  tail -n 60 "$WORKER_OUT" || true
  exit 1
fi
exit 0
