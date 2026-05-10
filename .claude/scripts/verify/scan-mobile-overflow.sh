#!/usr/bin/env bash
# verify/scan-mobile-overflow.sh — Sandbox-Tests für scan-mobile-overflow.sh (P3-4a)
#
# Alle Tests laufen in isolierten mktemp-Sandboxes.
# Exit 0 = alle Tests grün.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_SH="$(cd "$SCRIPT_DIR/../../analyzer/modules" && pwd)/scan-mobile-overflow.sh"

if [ ! -f "$MODULE_SH" ]; then
  printf 'ERROR: scan-mobile-overflow.sh nicht gefunden: %s\n' "$MODULE_SH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '\033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; FAILURES=$(( FAILURES + 1 )); }

FAILURES=0
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# ---------------------------------------------------------------------------
# Sandbox factory
# ---------------------------------------------------------------------------
_new_sandbox() {
  local name="$1"
  local sb="${TMPDIR_BASE}/sandbox_${name}"

  mkdir -p "$sb/.claude/overseer/inbox"
  mkdir -p "$sb/.claude/analyzer/state"
  mkdir -p "$sb/.claude/test-runs"
  mkdir -p "$sb/.claude/scripts/lib"
  mkdir -p "$sb/.git"
  printf 'ref: refs/heads/main\n' > "$sb/.git/HEAD"

  # Stub audit.sh — no-op
  cat > "$sb/.claude/scripts/lib/audit.sh" <<'STUBEOF'
audit_record() { return 0; }
STUBEOF

  # No notify.sh stub needed — module handles missing file gracefully

  printf '%s\n' "$sb"
}

# Create a mock findings.json in a test-run directory
_make_findings() {
  local run_dir="$1"    # full path to test-run dir
  local started_at="$2" # ISO timestamp
  shift 2
  local findings_json="$1"  # raw JSON array for "findings" key
  shift

  mkdir -p "$run_dir"
  cat > "$run_dir/findings.json" <<EOF
{
  "run_id": "mock-run",
  "scenario": "smoke-full-app-audit",
  "started_at": "${started_at}",
  "finished_at": "${started_at}",
  "result": "failed",
  "findings": ${findings_json},
  "top_level_routes": [],
  "routes": []
}
EOF
}

_run_module() {
  local sb="$1"; shift
  CLAUDE_PROJECT_DIR="$sb" \
  ANALYZER_STATE_FILE="$sb/.claude/analyzer/state/scan-mobile-overflow.json" \
  OVERSEER_INBOX_DIR="$sb/.claude/overseer/inbox" \
  TEST_RUNS_DIR_OVERRIDE="$sb/.claude/test-runs" \
    bash "$MODULE_SH" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: No test-run → exit 0, no item
# ---------------------------------------------------------------------------
T="T1-no-testrun"
sb="$(_new_sandbox "$T")"
# test-runs dir exists but is empty
output="$(_run_module "$sb" 2>&1)"
exit_code=$?
item_count="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$exit_code" -eq 0 ] && [ "$item_count" -eq 0 ]; then
  _pass "$T: exit 0, no item generated"
else
  _fail "$T" "exit=$exit_code items=$item_count (expected exit=0, items=0)"
fi

# ---------------------------------------------------------------------------
# Test 2: Mock findings.json with 2 mobile findings → 2 items (≤ cap=3)
# ---------------------------------------------------------------------------
T="T2-two-mobile-findings"
sb="$(_new_sandbox "$T")"
RUN_DIR="$sb/.claude/test-runs/20260510T120000Z"
NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
_make_findings "$RUN_DIR" "$NOW_TS" '[
  {
    "id": "F001",
    "category": "pixel-overflow",
    "route": "/deals",
    "viewport": "phone",
    "screenshot": "light-phone-deals.png"
  },
  {
    "id": "F002",
    "category": "mobile-no-bottom-nav",
    "route": "/inventory",
    "viewport": "tablet",
    "screenshot": ""
  }
]'

output="$(_run_module "$sb" 2>&1)"
exit_code=$?
item_count="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$exit_code" -eq 0 ] && [ "$item_count" -eq 2 ]; then
  _pass "$T: 2 items generated for 2 mobile findings"
else
  _fail "$T" "exit=$exit_code items=$item_count (expected exit=0, items=2)\noutput: $output"
fi

# Check frontmatter of first item
first_item="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | head -1)"
if [ -n "$first_item" ]; then
  if grep -q 'source: tier-3' "$first_item" && \
     grep -q 'priority: 1' "$first_item" && \
     grep -q 'touches:' "$first_item"; then
    _pass "$T-frontmatter: source=tier-3, priority=1, touches present"
  else
    _fail "$T-frontmatter" "frontmatter missing required fields in $first_item"
  fi
fi

# ---------------------------------------------------------------------------
# Test 3: Re-run → no duplicate items (dedup)
# ---------------------------------------------------------------------------
T="T3-dedup"
# Reuse same sandbox (items already in inbox from T2 — but different sandbox)
sb="$(_new_sandbox "$T")"
RUN_DIR="$sb/.claude/test-runs/20260510T120000Z"
NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
_make_findings "$RUN_DIR" "$NOW_TS" '[
  {
    "id": "F001",
    "category": "pixel-overflow",
    "route": "/deals",
    "viewport": "phone",
    "screenshot": ""
  }
]'

# First run
_run_module "$sb" > /dev/null 2>&1
count_after_first="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

# Second run (same finding)
_run_module "$sb" > /dev/null 2>&1
count_after_second="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$count_after_first" -eq "$count_after_second" ]; then
  _pass "$T: Re-run produced no duplicate (items stayed at $count_after_first)"
else
  _fail "$T" "items after first=$count_after_first, after second=$count_after_second — duplicate written"
fi

# ---------------------------------------------------------------------------
# Test 4: Mix phone + desktop findings → desktop ignored
# ---------------------------------------------------------------------------
T="T4-desktop-ignored"
sb="$(_new_sandbox "$T")"
RUN_DIR="$sb/.claude/test-runs/20260510T130000Z"
NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
_make_findings "$RUN_DIR" "$NOW_TS" '[
  {
    "id": "F001",
    "category": "pixel-overflow",
    "route": "/dashboard",
    "viewport": "desktop",
    "screenshot": ""
  },
  {
    "id": "F002",
    "category": "pixel-overflow",
    "route": "/deals",
    "viewport": "phone",
    "screenshot": ""
  }
]'

output="$(_run_module "$sb" 2>&1)"
item_count="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

# Should generate 1 item (phone) but NOT the desktop one
if [ "$item_count" -eq 1 ]; then
  _pass "$T: desktop finding ignored, 1 phone item generated"
else
  _fail "$T" "items=$item_count (expected 1 — desktop finding must be ignored)\noutput: $output"
fi

# ---------------------------------------------------------------------------
# Test 5: 4th attempt → 7d-pause + notify (no item written on 4th attempt)
# ---------------------------------------------------------------------------
T="T5-fourth-attempt-pause"
sb="$(_new_sandbox "$T")"
RUN_DIR="$sb/.claude/test-runs/20260510T140000Z"

# Pre-seed state with 3 recent attempts for the subject
ROUTE="/inbox"
CAT="touch-target-too-small"
hash_input="scan-mobile-overflow${ROUTE}${CAT}"
FULL_HASH="$(printf '%s' "$hash_input" | shasum -a 256 | awk '{print $1}')"
NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$sb/.claude/analyzer/state"
cat > "$sb/.claude/analyzer/state/scan-mobile-overflow.json" <<EOF
{
  "last_run": null,
  "subjects": {
    "${FULL_HASH}": {
      "route": "${ROUTE}",
      "category": "${CAT}",
      "first_seen": "${NOW_TS}",
      "last_attempts": ["${NOW_TS}", "${NOW_TS}", "${NOW_TS}"],
      "paused_until": null
    }
  }
}
EOF

_make_findings "$RUN_DIR" "$NOW_TS" "[
  {
    \"id\": \"F001\",
    \"category\": \"${CAT}\",
    \"route\": \"${ROUTE}\",
    \"viewport\": \"phone\",
    \"screenshot\": \"\"
  }
]"

output="$(_run_module "$sb" 2>&1)"
item_count="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

# Should NOT write an item — should trigger pause
paused_until="$(python3 -c "
import json, sys
with open('$sb/.claude/analyzer/state/scan-mobile-overflow.json') as f:
    d = json.load(f)
subj = d.get('subjects', {}).get('$FULL_HASH', {})
print(subj.get('paused_until') or 'null')
" 2>/dev/null || echo null)"

if [ "$item_count" -eq 0 ] && [ "$paused_until" != "null" ]; then
  _pass "$T: 4th attempt → no item, pause set to $paused_until"
else
  _fail "$T" "items=$item_count paused_until=${paused_until} (expected 0 items + pause set)\noutput: $output"
fi

# ---------------------------------------------------------------------------
# Test 6: Stale run (> 7 days) → warning, no item
# ---------------------------------------------------------------------------
T="T6-stale-run"
sb="$(_new_sandbox "$T")"

# Create a run from 8 days ago
EIGHT_DAYS_AGO="$(python3 -c "
import datetime
dt = datetime.datetime.utcnow() - datetime.timedelta(days=8)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
")"
RUN_LABEL="$(python3 -c "
import datetime
dt = datetime.datetime.utcnow() - datetime.timedelta(days=8)
print(dt.strftime('%Y%m%dT%H%M%SZ'))
")"
RUN_DIR="$sb/.claude/test-runs/${RUN_LABEL}"

_make_findings "$RUN_DIR" "$EIGHT_DAYS_AGO" '[
  {
    "id": "F001",
    "category": "pixel-overflow",
    "route": "/dashboard",
    "viewport": "phone",
    "screenshot": ""
  }
]'

output="$(_run_module "$sb" 2>&1)"
exit_code=$?
item_count="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$exit_code" -eq 0 ] && [ "$item_count" -eq 0 ] && \
   printf '%s' "$output" | grep -qi "stale\|WARNING"; then
  _pass "$T: stale run → exit 0, no item, warning logged"
else
  _fail "$T" "exit=$exit_code items=$item_count warning=$(echo "$output" | grep -i 'stale\|warning' | head -1)"
fi

# ---------------------------------------------------------------------------
# Test 7: Item frontmatter — source:tier-3, priority:1, touches from route
# ---------------------------------------------------------------------------
T="T7-frontmatter-touches"
sb="$(_new_sandbox "$T")"
RUN_DIR="$sb/.claude/test-runs/20260510T150000Z"
NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
_make_findings "$RUN_DIR" "$NOW_TS" '[
  {
    "id": "F001",
    "category": "pixel-overflow",
    "route": "/tickets",
    "viewport": "phone",
    "screenshot": "light-phone-tickets.png"
  }
]'

_run_module "$sb" > /dev/null 2>&1
item_file="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | head -1)"

if [ -z "$item_file" ]; then
  _fail "$T" "no item file created"
else
  source_ok=0; priority_ok=0; touches_ok=0
  grep -q 'source: tier-3' "$item_file"   && source_ok=1
  grep -q 'priority: 1'    "$item_file"   && priority_ok=1
  # touches should contain lib/screens/ reference
  grep -q 'touches:' "$item_file" && grep -q 'lib/screens/' "$item_file" && touches_ok=1

  if [ "$source_ok" -eq 1 ] && [ "$priority_ok" -eq 1 ] && [ "$touches_ok" -eq 1 ]; then
    _pass "$T: source=tier-3, priority=1, touches=lib/screens/tickets_screen.dart"
  else
    _fail "$T" "source_ok=$source_ok priority_ok=$priority_ok touches_ok=$touches_ok"
    cat "$item_file" >&2
  fi
fi

# ---------------------------------------------------------------------------
# Test 8: findings.json missing → exit 0, no item
# ---------------------------------------------------------------------------
T="T8-missing-findings-json"
sb="$(_new_sandbox "$T")"
RUN_DIR="$sb/.claude/test-runs/20260510T160000Z"
mkdir -p "$RUN_DIR"
# No findings.json written

output="$(_run_module "$sb" 2>&1)"
exit_code=$?
item_count="$(find "$sb/.claude/overseer/inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$exit_code" -eq 0 ] && [ "$item_count" -eq 0 ]; then
  _pass "$T: missing findings.json → exit 0, no item"
else
  _fail "$T" "exit=$exit_code items=$item_count"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '\033[32mAll tests passed.\033[0m\n'
  exit 0
else
  printf '\033[31m%d test(s) FAILED.\033[0m\n' "$FAILURES"
  exit 1
fi
