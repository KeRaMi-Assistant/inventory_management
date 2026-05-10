#!/usr/bin/env bash
# verify/scan-dependency-rot.sh — Sandbox tests for scan-dependency-rot analyzer module.
#
# Usage: bash .claude/scripts/verify/scan-dependency-rot.sh
# Exit 0 = all pass, exit 1 = one or more failures.
#
# Isolation: uses mktemp sandbox + PATH-mock for flutter/gh stubs.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODULE="$REPO_ROOT/.claude/analyzer/modules/scan-dependency-rot.sh"

if [ ! -f "$MODULE" ]; then
  printf 'ERROR: Module not found: %s\n' "$MODULE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Test framework
# ---------------------------------------------------------------------------
_pass=0
_fail=0

ok() {
  printf '  \033[32m[PASS]\033[0m %s\n' "$1"
  _pass=$(( _pass + 1 ))
}

fail() {
  printf '  \033[31m[FAIL]\033[0m %s\n' "$1" >&2
  _fail=$(( _fail + 1 ))
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ok "$label (expected=$expected)"
  else
    fail "$label (expected='$expected', actual='$actual')"
  fi
}

# ---------------------------------------------------------------------------
# Sandbox helpers
# ---------------------------------------------------------------------------
TMPBASE="$(mktemp -d /tmp/verify-scan-dep-rot.XXXXXX)"
_cleanup() {
  rm -rf "$TMPBASE" 2>/dev/null || true
}
trap '_cleanup' EXIT INT TERM

_new_sandbox() {
  local name="$1"
  local sandbox="$TMPBASE/$name"
  mkdir -p "$sandbox"

  # Minimal directory structure
  mkdir -p "$sandbox/.claude/overseer/inbox"
  mkdir -p "$sandbox/.claude/overseer/notifications"
  mkdir -p "$sandbox/.claude/analyzer/state"
  mkdir -p "$sandbox/.claude/scripts/lib"
  mkdir -p "$sandbox/.claude/scripts"
  mkdir -p "$sandbox/bin"  # for stub binaries

  # Copy audit.sh if present
  [ -f "$REPO_ROOT/.claude/scripts/lib/audit.sh" ] && \
    cp "$REPO_ROOT/.claude/scripts/lib/audit.sh" \
       "$sandbox/.claude/scripts/lib/audit.sh"

  # Stub notify.sh
  cat > "$sandbox/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
_STUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_STUB_REPO_ROOT="$(cd "$_STUB_SCRIPT_DIR/../.." && pwd)"
SENT_DIR="$_STUB_REPO_ROOT/.claude/overseer/notifications"
mkdir -p "$SENT_DIR"
printf '{"severity":"%s","topic":"%s","title":"%s","body":"%s"}\n' \
  "${1:-}" "${2:-}" "${3:-}" "${4:-}" >> "$SENT_DIR/sent.jsonl"
STUB
  chmod +x "$sandbox/.claude/scripts/notify.sh"

  printf '%s' "$sandbox"
}

# Create a flutter stub that returns mock pub outdated JSON
_make_flutter_stub() {
  local sandbox="$1"
  local json_payload="$2"

  cat > "$sandbox/bin/flutter" <<STUB
#!/usr/bin/env bash
# Stub flutter — returns mock pub outdated JSON
if [[ "\$*" == *"pub outdated"* ]]; then
  printf '%s\n' '$json_payload'
  exit 0
fi
exit 0
STUB
  chmod +x "$sandbox/bin/flutter"
}

# Create a gh stub that returns a hardcoded mock issue body with 2 major bumps
_make_gh_stub() {
  local sandbox="$1"
  # Write body to a file so the stub can cat it (avoids quoting/backtick issues)
  local body_file="$sandbox/.renovate-body.txt"
  cat > "$body_file" <<'BODYEOF'
## Dependency Dashboard

- [ ] **supabase_flutter** (2.8.0 -> 3.0.0)
- [ ] **google_fonts** (6.2.1 -> 7.0.0)
- [x] **provider** (6.1.2 -> 6.2.0) (already merged)
BODYEOF

  cat > "$sandbox/bin/gh" <<STUB
#!/usr/bin/env bash
# Stub gh — returns mock Renovate dashboard body
cat '${body_file}'
exit 0
STUB
  chmod +x "$sandbox/bin/gh"
}

# Run module with PATH pointing to sandbox/bin first
_run_module() {
  local sandbox="$1"
  shift
  ANALYZER_STATE_FILE="$sandbox/.claude/analyzer/state/scan-dependency-rot.json" \
  OVERSEER_INBOX_DIR="$sandbox/.claude/overseer/inbox" \
  CLAUDE_PROJECT_DIR="$sandbox" \
  FLUTTER_BIN="$sandbox/bin/flutter" \
  GH_BIN="$sandbox/bin/gh" \
  bash "$MODULE" "$@"
}

# JSON with no major bumps (all same major)
NO_MAJOR_BUMP_JSON='{"packages":[{"package":"provider","current":{"version":"6.1.2"},"latest":{"version":"6.2.0"}},{"package":"intl","current":{"version":"0.20.2"},"latest":{"version":"0.20.3"}}]}'

# JSON with 1 major bump
ONE_MAJOR_BUMP_JSON='{"packages":[{"package":"fl_chart","current":{"version":"0.69.0"},"latest":{"version":"1.0.0"}},{"package":"intl","current":{"version":"0.20.2"},"latest":{"version":"0.20.3"}}]}'

# JSON with 5 major bumps
FIVE_MAJOR_BUMPS_JSON='{"packages":[{"package":"pkg_a","current":{"version":"1.0.0"},"latest":{"version":"2.0.0"}},{"package":"pkg_b","current":{"version":"2.0.0"},"latest":{"version":"3.0.0"}},{"package":"pkg_c","current":{"version":"3.0.0"},"latest":{"version":"4.0.0"}},{"package":"pkg_d","current":{"version":"4.0.0"},"latest":{"version":"5.0.0"}},{"package":"pkg_e","current":{"version":"5.0.0"},"latest":{"version":"6.0.0"}}]}'

# ---------------------------------------------------------------------------
# Test 1: flutter missing → exit 0, no item
# ---------------------------------------------------------------------------
printf '\nTest 1: flutter not found → exit 0, no item\n'
SB="$(_new_sandbox t1)"
# No flutter stub in PATH → use a bin dir with no flutter
output="$(FLUTTER_BIN="/nonexistent/flutter" _run_module "$SB" 2>&1 || true)"
rc=$?
assert_eq "exit 0 when flutter missing" "0" "$rc"
item_count="$(find "$SB/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "no item when flutter missing" "0" "$item_count"

# ---------------------------------------------------------------------------
# Test 2: no major bumps → no item
# ---------------------------------------------------------------------------
printf '\nTest 2: No major bumps → no item\n'
SB2="$(_new_sandbox t2)"
_make_flutter_stub "$SB2" "$NO_MAJOR_BUMP_JSON"
_run_module "$SB2" 2>/dev/null
item_count2="$(find "$SB2/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "no item when no major bumps" "0" "$item_count2"

# ---------------------------------------------------------------------------
# Test 3: 1 major bump → 1 item with needs_dispute: true
# ---------------------------------------------------------------------------
printf '\nTest 3: 1 major bump → 1 item with needs_dispute:true\n'
SB3="$(_new_sandbox t3)"
_make_flutter_stub "$SB3" "$ONE_MAJOR_BUMP_JSON"
_run_module "$SB3" 2>/dev/null
item_count3="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "1 item for 1 major bump" "1" "$item_count3"

item_file3="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | head -1)"
if [ -n "$item_file3" ]; then
  content3="$(cat "$item_file3")"
  if printf '%s' "$content3" | grep -q "needs_dispute: true"; then
    ok "needs_dispute: true present"
  else
    fail "needs_dispute: true missing"
  fi
  if printf '%s' "$content3" | grep -q "source: tier-3"; then
    ok "source: tier-3 present"
  else
    fail "source: tier-3 missing"
  fi
  if printf '%s' "$content3" | grep -q "pub.dev/packages"; then
    ok "changelog link present"
  else
    fail "changelog link missing"
  fi
  if printf '%s' "$content3" | grep -q "fl_chart"; then
    ok "package name (fl_chart) in body"
  else
    fail "package name missing from body"
  fi
fi

# ---------------------------------------------------------------------------
# Test 4: 5 major bumps → max 3 items (cap)
# ---------------------------------------------------------------------------
printf '\nTest 4: 5 major bumps → max 3 items (cap)\n'
SB4="$(_new_sandbox t4)"
_make_flutter_stub "$SB4" "$FIVE_MAJOR_BUMPS_JSON"
_run_module "$SB4" 2>/dev/null
item_count4="$(find "$SB4/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "max 3 items (cap)" "3" "$item_count4"

# ---------------------------------------------------------------------------
# Test 5: re-run → dedup (no new items)
# ---------------------------------------------------------------------------
printf '\nTest 5: re-run → dedup\n'
# Reuse SB3 (1 item already there)
_run_module "$SB3" 2>/dev/null
item_count5="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "still 1 item after re-run (dedup)" "1" "$item_count5"

# ---------------------------------------------------------------------------
# Test 6: RENOVATE_DASHBOARD_ISSUE_NUM set + mock gh → Path B items
# ---------------------------------------------------------------------------
printf '\nTest 6: RENOVATE_DASHBOARD_ISSUE_NUM set + mock gh → Path B\n'
SB6="$(_new_sandbox t6)"

RENOVATE_ISSUE_BODY='## Dependency Dashboard

- [ ] **supabase_flutter** (`2.8.0` -> `3.0.0`)
- [ ] **google_fonts** (`6.2.1` -> `7.0.0`)
- [x] **provider** (`6.1.2` -> `6.2.0`) (already merged)
'
_make_gh_stub "$SB6" "$RENOVATE_ISSUE_BODY"

RENOVATE_DASHBOARD_ISSUE_NUM=42 _run_module "$SB6" 2>/dev/null

item_count6="$(find "$SB6/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$item_count6" -ge 1 ]; then
  ok "Path B: at least 1 item from Renovate dashboard (got $item_count6)"
else
  fail "Path B: no item generated from Renovate dashboard"
fi

# Checked item (provider 6.x→6.x, not a major bump) must NOT appear
checked_in_item="$(grep -rl "provider" "$SB6/.claude/overseer/inbox/" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Path B: checked/minor item not generated" "0" "$checked_in_item"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n--- scan-dependency-rot verify summary ---\n'
printf 'PASS: %d  FAIL: %d\n' "$_pass" "$_fail"

[ "$_fail" -gt 0 ] && exit 1
exit 0
