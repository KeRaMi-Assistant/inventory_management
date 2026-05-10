#!/usr/bin/env bash
# verify/needs-dispute.sh — Tests für needs-dispute.sh (P3-3)
#
# Tests:
#   1. Item mit needs_dispute: true   → exit 0, reason "explicit override"
#   2. Item mit needs_dispute: false  → exit 1, selbst bei Migration in touches (override gewinnt)
#   3. tier-3 + Migration             → exit 0
#   4. tier-1 + Tippfehler            → exit 1
#   5. touches: > 5 Files             → exit 0
#   6. touches: pubspec.yaml          → exit 0
#   7. Body "refactor architektur"    → exit 0
#   8. Body "update help text"        → exit 1
#   9. touches: lib/app_theme.dart    → exit 0
#  10. touches: supabase/functions/…  → exit 0
#
# Exit 0 = alle Tests bestanden. Exit 1 = mindestens ein Fehler.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
NEEDS_DISPUTE_LIB="$LIB_DIR/needs-dispute.sh"

PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox setup
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$SANDBOX'" EXIT

# Override CLAUDE_PROJECT_DIR so audit_record writes into sandbox
export CLAUDE_PROJECT_DIR="$SANDBOX"
# Override git in subshell via git stub that returns sandbox dir
mkdir -p "$SANDBOX/mock-bin"
cat > "$SANDBOX/mock-bin/git" <<'SH'
#!/usr/bin/env bash
# Stub: rev-parse --show-toplevel → SANDBOX; --short HEAD → 0000000
if [[ "$*" == *"rev-parse --show-toplevel"* ]]; then
  echo "${CLAUDE_PROJECT_DIR:-/tmp}"
elif [[ "$*" == *"rev-parse --short HEAD"* ]]; then
  echo "0000000"
fi
SH
chmod +x "$SANDBOX/mock-bin/git"
export PATH="$SANDBOX/mock-bin:$PATH"

# Helper: write a temp item md file
make_item() {
  local name="$1"
  local content="$2"
  local file="$SANDBOX/${name}.md"
  printf '%s\n' "$content" > "$file"
  echo "$file"
}

# Helper: run needs_dispute in a subshell (fresh source each call to avoid state leakage)
run_nd() {
  local item_path="$1"
  bash -c "
    export CLAUDE_PROJECT_DIR='$CLAUDE_PROJECT_DIR'
    export PATH='$SANDBOX/mock-bin:$PATH'
    source '$NEEDS_DISPUTE_LIB'
    needs_dispute '$item_path'
  "
  return $?
}

get_reason() {
  local item_path="$1"
  bash -c "
    export CLAUDE_PROJECT_DIR='$CLAUDE_PROJECT_DIR'
    export PATH='$SANDBOX/mock-bin:$PATH'
    source '$NEEDS_DISPUTE_LIB'
    needs_dispute '$item_path'
  " 2>/dev/null
}

printf '\n=== needs-dispute.sh verify ===\n\n'

# ---------------------------------------------------------------------------
# Test 1: needs_dispute: true → exit 0, reason contains "explicit override"
# ---------------------------------------------------------------------------
ITEM1="$(make_item "t1-explicit-true" "---
title: Some big task
needs_dispute: true
touches:
  - lib/screens/foo.dart
---
Regular body text.")"

reason="$(get_reason "$ITEM1")"
if run_nd "$ITEM1" >/dev/null 2>&1; then
  if echo "$reason" | grep -qi 'explicit'; then
    pass "Test 1: needs_dispute: true → exit 0 + reason contains 'explicit'"
  else
    fail "Test 1: needs_dispute: true → exit 0 but reason='$reason' (expected 'explicit')"
  fi
else
  fail "Test 1: needs_dispute: true → expected exit 0 but got exit 1"
fi

# ---------------------------------------------------------------------------
# Test 2: needs_dispute: false → exit 1, even with migration in touches
# ---------------------------------------------------------------------------
ITEM2="$(make_item "t2-explicit-false" "---
title: Fix typo with migration
needs_dispute: false
source: tier-3
touches:
  - supabase/migrations/20260101_fix.sql
---
Fix a typo and add RLS policy.")"

if ! run_nd "$ITEM2" >/dev/null 2>&1; then
  reason2="$(get_reason "$ITEM2")"
  if echo "$reason2" | grep -qi 'explicit'; then
    pass "Test 2: needs_dispute: false → exit 1 (override wins over migration)"
  else
    fail "Test 2: needs_dispute: false → exit 1 but reason='$reason2' (expected 'explicit')"
  fi
else
  fail "Test 2: needs_dispute: false → expected exit 1 but got exit 0"
fi

# ---------------------------------------------------------------------------
# Test 3: source: tier-3 + supabase/migrations/ in touches → exit 0
# ---------------------------------------------------------------------------
ITEM3="$(make_item "t3-tier3-migration" "---
title: Add workspace table
source: tier-3
touches:
  - supabase/migrations/20260101_workspace.sql
---
Add a new workspace table.")"

if run_nd "$ITEM3" >/dev/null 2>&1; then
  reason3="$(get_reason "$ITEM3")"
  if echo "$reason3" | grep -qi 'tier-3'; then
    pass "Test 3: tier-3 + migration → exit 0 + reason contains 'tier-3'"
  else
    fail "Test 3: tier-3 + migration → exit 0 but reason='$reason3' (expected 'tier-3')"
  fi
else
  fail "Test 3: tier-3 + migration → expected exit 0 but got exit 1"
fi

# ---------------------------------------------------------------------------
# Test 4: source: tier-1 + body "fix typo" → exit 1
# ---------------------------------------------------------------------------
ITEM4="$(make_item "t4-tier1-typo" "---
title: Fix typo in label
source: tier-1
touches:
  - lib/screens/home_screen.dart
---
Fix typo in the button label text.")"

if ! run_nd "$ITEM4" >/dev/null 2>&1; then
  pass "Test 4: tier-1 + typo body → exit 1 (no dispute needed)"
else
  fail "Test 4: tier-1 + typo body → expected exit 1 but got exit 0"
fi

# ---------------------------------------------------------------------------
# Test 5: touches: > 5 files → exit 0
# ---------------------------------------------------------------------------
ITEM5="$(make_item "t5-six-files" "---
title: Multi-file change
touches:
  - lib/screens/a.dart
  - lib/screens/b.dart
  - lib/screens/c.dart
  - lib/screens/d.dart
  - lib/screens/e.dart
  - lib/screens/f.dart
---
Touch six files.")"

if run_nd "$ITEM5" >/dev/null 2>&1; then
  reason5="$(get_reason "$ITEM5")"
  if echo "$reason5" | grep -qi '> 5\|touches'; then
    pass "Test 5: 6 touches → exit 0"
  else
    fail "Test 5: 6 touches → exit 0 but reason='$reason5'"
  fi
else
  fail "Test 5: 6 touches → expected exit 0 but got exit 1"
fi

# ---------------------------------------------------------------------------
# Test 6: touches: pubspec.yaml → exit 0
# ---------------------------------------------------------------------------
ITEM6="$(make_item "t6-pubspec" "---
title: Add new package
touches:
  - pubspec.yaml
  - lib/services/new_service.dart
---
Add new dependency.")"

if run_nd "$ITEM6" >/dev/null 2>&1; then
  pass "Test 6: touches pubspec.yaml → exit 0"
else
  fail "Test 6: touches pubspec.yaml → expected exit 0 but got exit 1"
fi

# ---------------------------------------------------------------------------
# Test 7: body contains "refactor architektur" → exit 0
# ---------------------------------------------------------------------------
ITEM7="$(make_item "t7-arch-keyword" "---
title: Update providers
touches:
  - lib/providers/main_provider.dart
---
This task is a refactor architektur of the provider layer.")"

if run_nd "$ITEM7" >/dev/null 2>&1; then
  pass "Test 7: body 'refactor architektur' → exit 0"
else
  fail "Test 7: body 'refactor architektur' → expected exit 0 but got exit 1"
fi

# ---------------------------------------------------------------------------
# Test 8: body "update help text" → exit 1
# ---------------------------------------------------------------------------
ITEM8="$(make_item "t8-help-text" "---
title: Update help text
touches:
  - lib/screens/help_screen.dart
---
Update help text wording for clarity.")"

if ! run_nd "$ITEM8" >/dev/null 2>&1; then
  pass "Test 8: body 'update help text' → exit 1 (no dispute needed)"
else
  fail "Test 8: body 'update help text' → expected exit 1 but got exit 0"
fi

# ---------------------------------------------------------------------------
# Test 9: touches: lib/app_theme.dart → exit 0
# ---------------------------------------------------------------------------
ITEM9="$(make_item "t9-theme" "---
title: Adjust theme colors
touches:
  - lib/app_theme.dart
---
Tweak accent color.")"

if run_nd "$ITEM9" >/dev/null 2>&1; then
  pass "Test 9: touches lib/app_theme.dart → exit 0"
else
  fail "Test 9: touches lib/app_theme.dart → expected exit 0 but got exit 1"
fi

# ---------------------------------------------------------------------------
# Test 10: touches: supabase/functions/foo/index.ts → exit 0
# ---------------------------------------------------------------------------
ITEM10="$(make_item "t10-edge-fn" "---
title: New edge function
touches:
  - supabase/functions/notify/index.ts
---
Add a notification edge function.")"

if run_nd "$ITEM10" >/dev/null 2>&1; then
  pass "Test 10: touches supabase/functions/ → exit 0"
else
  fail "Test 10: touches supabase/functions/ → expected exit 0 but got exit 1"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
