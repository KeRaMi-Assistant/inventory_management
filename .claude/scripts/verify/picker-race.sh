#!/usr/bin/env bash
# picker-race.sh — Verify suite for .claude/scripts/lib/picker.sh
# Tests: atomic race, per-file soft lock, tier-1 bypass, no-touches skip,
#        blocked-pre-ship release, orphan recovery, PID in filename.
# Exit 0 = all pass, Exit 1 = at least one failure.

set -euo pipefail

# ---------------------------------------------------------------------------
# Setup: sandbox in a temp dir
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap '_picker_sandbox_cleanup "$SANDBOX"' EXIT
_picker_sandbox_cleanup() {
  local dir="$1"
  # Unlock immutable files set by audit.sh (chflags uchg) before removing
  if command -v chflags >/dev/null 2>&1; then
    find "$dir" -type f -exec chflags nouchg {} \; 2>/dev/null || true
  fi
  # Make all files writable before rm
  chmod -R u+w "$dir" 2>/dev/null || true
  rm -rf "$dir"
}

export CLAUDE_PROJECT_DIR="$SANDBOX"

# Create overseer directory structure
mkdir -p "$SANDBOX/.claude/overseer/inbox"
mkdir -p "$SANDBOX/.claude/overseer/in_progress"

# Resolve lib dir relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
PICKER_LIB="${LIB_DIR}/picker.sh"

if [ ! -f "$PICKER_LIB" ]; then
  printf 'ERROR: picker.sh not found at %s\n' "$PICKER_LIB" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

_pass() {
  printf '  [PASS] %s\n' "$1"
  PASS=$((PASS + 1))
}

_fail() {
  printf '  [FAIL] %s\n' "$1"
  FAIL=$((FAIL + 1))
}

_assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    _pass "$desc"
  else
    _fail "$desc (expected='$expected' actual='$actual')"
  fi
}

_assert_file_exists() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    _pass "$desc"
  else
    _fail "$desc (file not found: $path)"
  fi
}

_assert_file_not_exists() {
  local desc="$1" path="$2"
  if [ ! -f "$path" ]; then
    _pass "$desc"
  else
    _fail "$desc (file should not exist: $path)"
  fi
}

_reset_sandbox() {
  rm -rf "$SANDBOX/.claude/overseer"
  mkdir -p "$SANDBOX/.claude/overseer/inbox"
  mkdir -p "$SANDBOX/.claude/overseer/in_progress"
}

# ---------------------------------------------------------------------------
# Helper: write a minimal frontmatter item
# ---------------------------------------------------------------------------
_write_item() {
  local path="$1"
  local source="${2:-}"
  local touches="${3:-}"  # comma-separated or empty
  local bypass="${4:-}"

  {
    printf '%s\n' "---"
    printf '%s\n' "title: Test Item"
    [ -n "$source" ] && printf 'source: %s\n' "$source"
    [ -n "$bypass" ] && printf 'bypass_touches: %s\n' "$bypass"
    if [ -n "$touches" ]; then
      printf '%s\n' "touches:"
      IFS=',' read -ra touch_paths <<< "$touches"
      for p in "${touch_paths[@]}"; do
        printf '  - %s\n' "$p"
      done
    fi
    printf '%s\n' "---"
    printf '%s\n' ""
    printf '%s\n' "Item content here."
  } > "$path"
}

# ---------------------------------------------------------------------------
# Test 1: Atomic Race — 2 parallel pickers, exactly 1 picks the item
# ---------------------------------------------------------------------------
printf '\nTest 1: Atomic Race\n'
_reset_sandbox

_write_item "$SANDBOX/.claude/overseer/inbox/item-001.md" "tier-1" "" ""

# Source picker and run two parallel subshells
(
  source "$PICKER_LIB"
  pick_next_item "$$" > "$SANDBOX/t1_result_a.txt" 2>/dev/null
  echo $? > "$SANDBOX/t1_exit_a.txt"
) &
PID_A=$!
(
  source "$PICKER_LIB"
  pick_next_item "$$" > "$SANDBOX/t1_result_b.txt" 2>/dev/null
  echo $? > "$SANDBOX/t1_exit_b.txt"
) &
PID_B=$!
wait "$PID_A" "$PID_B" 2>/dev/null || true

EXIT_A="$(cat "$SANDBOX/t1_exit_a.txt" 2>/dev/null || echo 1)"
EXIT_B="$(cat "$SANDBOX/t1_exit_b.txt" 2>/dev/null || echo 1)"
RESULT_A="$(cat "$SANDBOX/t1_result_a.txt" 2>/dev/null || true)"
RESULT_B="$(cat "$SANDBOX/t1_result_b.txt" 2>/dev/null || true)"

# Exactly one must succeed (exit 0) and one must fail (exit 1)
SUCCESS_COUNT=0
[ "$EXIT_A" = "0" ] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
[ "$EXIT_B" = "0" ] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

_assert_eq "Exactly 1 of 2 parallel pickers succeeds" "1" "$SUCCESS_COUNT"

# The winner must have echoed a path
if [ "$EXIT_A" = "0" ]; then
  WINNER_PATH="$RESULT_A"
else
  WINNER_PATH="$RESULT_B"
fi
[[ "$WINNER_PATH" == *"in_progress"* ]] && _pass "Winner path is in in_progress" || _fail "Winner path not in in_progress: $WINNER_PATH"

# Test 7 (PID in filename) — check here since it shares Test 1's setup
printf '\nTest 7: PID in Filename\n'
BASENAME="$(basename "$WINNER_PATH")"
# Should match pattern *.PID.md where PID is digits
if echo "$BASENAME" | grep -qE '\.[0-9]+\.md$'; then
  _pass "Picked filename contains numeric PID suffix"
else
  _fail "Picked filename does not contain PID suffix: $BASENAME"
fi

# ---------------------------------------------------------------------------
# Test 2: Per-File Soft Lock
# ---------------------------------------------------------------------------
printf '\nTest 2: Per-File Soft Lock\n'
_reset_sandbox

_write_item "$SANDBOX/.claude/overseer/inbox/item-a.md" "" "lib/app_theme.dart"
_write_item "$SANDBOX/.claude/overseer/inbox/item-b.md" "" "lib/app_theme.dart"

# Source in this shell
source "$PICKER_LIB"

# Pick item-a
PICKED_A="$(pick_next_item "11111")"
_assert_file_exists "item-a picked → in in_progress" "$PICKED_A"
_assert_file_not_exists "item-a no longer in inbox" "$SANDBOX/.claude/overseer/inbox/item-a.md"

# Now try to pick item-b — should be blocked (same touches)
PICK_B_EXIT=0
PICKED_B="$(pick_next_item "22222" 2>/dev/null)" || PICK_B_EXIT=$?

_assert_eq "item-b pick returns exit 1 (soft lock)" "1" "$PICK_B_EXIT"
_assert_file_exists "item-b remains in inbox" "$SANDBOX/.claude/overseer/inbox/item-b.md"

# ---------------------------------------------------------------------------
# Test 3: Tier-1 Bypass (no touches field, has source: tier-1)
# ---------------------------------------------------------------------------
printf '\nTest 3: Tier-1 Bypass\n'
_reset_sandbox

_write_item "$SANDBOX/.claude/overseer/inbox/tier1-item.md" "tier-1" "" ""

source "$PICKER_LIB"
TIER1_EXIT=0
TIER1_PICKED="$(pick_next_item "33333" 2>/dev/null)" || TIER1_EXIT=$?

_assert_eq "tier-1 item picked without touches" "0" "$TIER1_EXIT"
_assert_file_not_exists "tier-1 item removed from inbox" "$SANDBOX/.claude/overseer/inbox/tier1-item.md"
_assert_file_exists "tier-1 item in in_progress" "$TIER1_PICKED"

# Also test bypass_touches: true
_reset_sandbox
_write_item "$SANDBOX/.claude/overseer/inbox/bypass-item.md" "" "" "true"

source "$PICKER_LIB"
BYPASS_EXIT=0
BYPASS_PICKED="$(pick_next_item "33334" 2>/dev/null)" || BYPASS_EXIT=$?
_assert_eq "bypass_touches:true item picked without touches" "0" "$BYPASS_EXIT"

# ---------------------------------------------------------------------------
# Test 4: Items without touches and not tier-1 are skipped
# ---------------------------------------------------------------------------
printf '\nTest 4: No-Touches Non-Tier-1 Item Skip\n'
_reset_sandbox

# Write item with no touches and no tier-1 source
_write_item "$SANDBOX/.claude/overseer/inbox/no-touches.md" "" "" ""

source "$PICKER_LIB"
NO_TOUCHES_EXIT=0
NO_TOUCHES_STDERR="$(pick_next_item "44444" 2>&1 >/dev/null)" || NO_TOUCHES_EXIT=$?

_assert_eq "no-touches non-tier-1 pick returns exit 1" "1" "$NO_TOUCHES_EXIT"
_assert_file_exists "no-touches item stays in inbox" "$SANDBOX/.claude/overseer/inbox/no-touches.md"
# Warning should appear on stderr
if echo "$NO_TOUCHES_STDERR" | grep -qi "WARNING"; then
  _pass "WARNING message emitted on stderr"
else
  _fail "No WARNING on stderr for no-touches non-tier-1 item (got: $NO_TOUCHES_STDERR)"
fi

# ---------------------------------------------------------------------------
# Test 5: release_item to blocked-pre-ship returns to inbox with marker
# ---------------------------------------------------------------------------
printf '\nTest 5: release_item blocked-pre-ship\n'
_reset_sandbox

# Simulate an in-progress item
_write_item "$SANDBOX/.claude/overseer/in_progress/my-item.55555.md" "tier-1" "" ""

source "$PICKER_LIB"
RELEASE_EXIT=0
release_item "$SANDBOX/.claude/overseer/in_progress/my-item.55555.md" "blocked-pre-ship" || RELEASE_EXIT=$?

_assert_eq "release_item blocked-pre-ship exits 0" "0" "$RELEASE_EXIT"
_assert_file_not_exists "item removed from in_progress" "$SANDBOX/.claude/overseer/in_progress/my-item.55555.md"

# Check inbox has a file with [blocked-pre-ship] marker
BLOCKED_FILE="$(find "$SANDBOX/.claude/overseer/inbox" -name "*blocked-pre-ship*" | head -1 || true)"
if [ -n "$BLOCKED_FILE" ]; then
  _pass "blocked-pre-ship item returned to inbox with marker"
else
  _fail "blocked-pre-ship item not found in inbox"
fi

# Also test merge-conflict returns to inbox
_write_item "$SANDBOX/.claude/overseer/in_progress/mc-item.55556.md" "tier-1" "" ""
source "$PICKER_LIB"
release_item "$SANDBOX/.claude/overseer/in_progress/mc-item.55556.md" "merge-conflict" 2>/dev/null || true
MC_FILE="$(find "$SANDBOX/.claude/overseer/inbox" -name "*merge-conflict*" | head -1 || true)"
if [ -n "$MC_FILE" ]; then
  _pass "merge-conflict item returned to inbox with marker"
else
  _fail "merge-conflict item not found in inbox"
fi

# ---------------------------------------------------------------------------
# Test 6: recover_orphaned_items with dead PID
# ---------------------------------------------------------------------------
printf '\nTest 6: recover_orphaned_items (dead PID)\n'
_reset_sandbox

DEAD_PID="99999999"
_write_item "$SANDBOX/.claude/overseer/in_progress/orphan.${DEAD_PID}.md" "tier-1" "" ""

source "$PICKER_LIB"
RECOVERY_COUNT="$(recover_orphaned_items 2>/dev/null)"

_assert_eq "recover_orphaned_items returns count 1" "1" "$RECOVERY_COUNT"
_assert_file_not_exists "orphan removed from in_progress" "$SANDBOX/.claude/overseer/in_progress/orphan.${DEAD_PID}.md"

RECOVERED_FILE="$(find "$SANDBOX/.claude/overseer/inbox" -name "*recovered*" | head -1 || true)"
if [ -n "$RECOVERED_FILE" ]; then
  _pass "orphaned item recovered to inbox with [recovered] marker"
else
  _fail "orphaned item not found in inbox after recovery"
fi

# Verify live PID is NOT recovered
_reset_sandbox
LIVE_PID="$$"
_write_item "$SANDBOX/.claude/overseer/in_progress/live-item.${LIVE_PID}.md" "tier-1" "" ""

source "$PICKER_LIB"
LIVE_RECOVERY_COUNT="$(recover_orphaned_items 2>/dev/null)"
_assert_eq "live PID item not recovered" "0" "$LIVE_RECOVERY_COUNT"
_assert_file_exists "live-item remains in in_progress" "$SANDBOX/.claude/overseer/in_progress/live-item.${LIVE_PID}.md"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n========================================\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
printf '========================================\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
