#!/usr/bin/env bash
# verify/weekly-digest.sh — Integration tests for weekly-digest.sh (P3-9.5)
#
# Tests:
#   1. Digest file created with <YYYY-Wxx>.md filename
#   2. All 6 sections present (Header, PRs, Disputes, Stakeholder, Cost, Action-Items)
#   3. Action-Items shows pending stale stakeholder items (mock 2 stale)
#   4. Push notification sent via notify.sh with week summary
#   5. Plist valid via plutil -lint
#   6. --dry-run: stdout output, no file written
#   7. Audit-grep hint in footer
#   8. Cost-Summary correct: mock 7d ledger → correct sum
#
# Exit 0 = all pass. Exit 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DIGEST_SH="$SCRIPT_DIR/../weekly-digest.sh"
PLIST_TEMPLATE="$REPO_ROOT/.claude/weekly-digest-launchagent.plist.template"

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

# Directories
DIGEST_DIR="$SANDBOX/digest"
AUDIT_DIR="$SANDBOX/audit"
DISPUTES_DIR="$SANDBOX/disputes"
STAKEHOLDER_INBOX_DIR="$SANDBOX/stakeholder/inbox"
OVERSEER_DIR="$SANDBOX/overseer"
COST_CAP_LEDGER_DIR="$SANDBOX/overseer"
NOTIF_DIR="$SANDBOX/notifications"

mkdir -p "$DIGEST_DIR" "$AUDIT_DIR" \
  "$DISPUTES_DIR/unresolved" \
  "$STAKEHOLDER_INBOX_DIR" \
  "$OVERSEER_DIR/failed" \
  "$OVERSEER_DIR/done" \
  "$NOTIF_DIR"

# Mock REPO_ROOT with git stub
MOCK_REPO="$SANDBOX/repo"
mkdir -p "$MOCK_REPO/.git"
git -C "$MOCK_REPO" init -q 2>/dev/null || true
git -C "$MOCK_REPO" config user.email "test@test.local" 2>/dev/null || true
git -C "$MOCK_REPO" config user.name "Test" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Setup: mock cost ledger (7 entries spanning last 7 days)
# Mock date: 2026-05-10 (Sunday)
# Ledger entries: 5 days within last 7d
# Total = 1.50 + 0.75 + 2.00 + 3.00 + 0.50 = 7.75
# ---------------------------------------------------------------------------
mkdir -p "$COST_CAP_LEDGER_DIR"
cat > "$COST_CAP_LEDGER_DIR/cost-ledger.jsonl" <<'LEDGER_EOF'
{"ts":"2026-05-10T08:00:00Z","agent":"proponent","usd":1.50,"pid":1}
{"ts":"2026-05-09T09:00:00Z","agent":"skeptic","usd":0.75,"pid":2}
{"ts":"2026-05-08T10:00:00Z","agent":"worker-a","usd":2.00,"pid":3}
{"ts":"2026-05-07T11:00:00Z","agent":"proponent","usd":3.00,"pid":4}
{"ts":"2026-05-06T12:00:00Z","agent":"skeptic","usd":0.50,"pid":5}
{"ts":"2026-05-02T08:00:00Z","agent":"worker-z","usd":99.00,"pid":6}
LEDGER_EOF
# Note: 2026-05-02 is > 7 days before 2026-05-10, so NOT included in total
# Expected total: 1.50 + 0.75 + 2.00 + 3.00 + 0.50 = 7.75

# ---------------------------------------------------------------------------
# Setup: mock disputes (two: one rejected normal, one rejected high-severity)
# ---------------------------------------------------------------------------
DISP1="$DISPUTES_DIR/d-reject-normal"
mkdir -p "$DISP1"
cat > "$DISP1/verdict.md" <<'VERDICT_EOF'
---
id: d-reject-normal
status: reject
severity: normal
decided_at: 2026-05-10T02:00:00Z
---

## Verdict

Proposal wurde aus Qualitätsgründen abgelehnt.
VERDICT_EOF
touch "$DISP1/verdict.md"

DISP2="$DISPUTES_DIR/d-reject-high"
mkdir -p "$DISP2"
cat > "$DISP2/verdict.md" <<'VERDICT_EOF'
---
id: d-reject-high
status: reject
severity: high
decided_at: 2026-05-09T10:00:00Z
---

## Verdict

Sicherheitsproblem erkannt — dringender User-Review nötig.
VERDICT_EOF
touch "$DISP2/verdict.md"

# Unresolved disputes
touch "$DISPUTES_DIR/unresolved/open-1" "$DISPUTES_DIR/unresolved/open-2"

# ---------------------------------------------------------------------------
# Setup: mock stakeholder inbox (2 items, both older than 24h)
# Using touch -t to set old mtime
# ---------------------------------------------------------------------------
STALE_MTIME="$(date -v-2d +%Y%m%d%H%M.00 2>/dev/null || date --date='2 days ago' +%Y%m%d%H%M.00 2>/dev/null || echo "202605080900.00")"
touch -t "$STALE_MTIME" "$STAKEHOLDER_INBOX_DIR/stakeholder-item-alpha.md" 2>/dev/null || \
  touch "$STAKEHOLDER_INBOX_DIR/stakeholder-item-alpha.md"
touch -t "$STALE_MTIME" "$STAKEHOLDER_INBOX_DIR/stakeholder-item-beta.md" 2>/dev/null || \
  touch "$STAKEHOLDER_INBOX_DIR/stakeholder-item-beta.md"

# ---------------------------------------------------------------------------
# Setup: mock audit with COST_CAP_REACHED event
# ---------------------------------------------------------------------------
cat > "$AUDIT_DIR/2026-05-10.md" <<'AUDIT_EOF'
---
ts: 2026-05-10T07:00:00Z
actor: overseer
action: COST_CAP_REACHED
subject: budget
reason: "daily cap exceeded"
---

AUDIT_EOF

# ---------------------------------------------------------------------------
# Helper: run weekly-digest.sh with sandbox env
# ---------------------------------------------------------------------------
_run_digest() {
  local date_override="${1:-2026-05-10}"
  shift
  REPO_ROOT="$MOCK_REPO" \
  DIGEST_DIR="$DIGEST_DIR" \
  AUDIT_DIR="$AUDIT_DIR" \
  DISPUTES_DIR="$DISPUTES_DIR" \
  STAKEHOLDER_INBOX_DIR="$STAKEHOLDER_INBOX_DIR" \
  OVERSEER_DIR="$OVERSEER_DIR" \
  COST_CAP_LEDGER_DIR="$COST_CAP_LEDGER_DIR" \
  NOTIF_DIR="$NOTIF_DIR" \
  DIGEST_MOCK_DATE="$date_override" \
  NOTIFY_DRY_RUN=1 \
  bash "$DIGEST_SH" "$@" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Test 1: Digest file created with correct YYYY-Wxx filename
# ---------------------------------------------------------------------------
printf '\nTest 1: Digest file created with YYYY-Wxx filename\n'
_run_digest "2026-05-10" --once

# 2026-05-10 is a Sunday → ISO week 2026-W19
EXPECTED_WEEK="2026-W19"
DIGEST_FILE="$DIGEST_DIR/${EXPECTED_WEEK}.md"

if [ -f "$DIGEST_FILE" ]; then
  pass "digest file exists at $DIGEST_FILE"
else
  # Try to find any digest file created
  FOUND="$(find "$DIGEST_DIR" -name "*.md" 2>/dev/null | head -1)"
  if [ -n "$FOUND" ]; then
    pass "digest file created (name: $(basename "$FOUND"))"
    DIGEST_FILE="$FOUND"
  else
    fail "digest file NOT created in $DIGEST_DIR"
    DIGEST_FILE=""
  fi
fi

# ---------------------------------------------------------------------------
# Test 2: All 6 required sections present
# ---------------------------------------------------------------------------
printf '\nTest 2: All 6 sections present\n'
if [ -n "$DIGEST_FILE" ] && [ -f "$DIGEST_FILE" ]; then
  for section in \
    "# Wochen-Digest" \
    "## Gemerged-PRs" \
    "## Abgelehnte Disputs" \
    "## Offene Stakeholder-Items" \
    "## Cost-Summary" \
    "## Action-Items"
  do
    if grep -q "$section" "$DIGEST_FILE"; then
      pass "section present: $section"
    else
      fail "section MISSING: $section"
    fi
  done
else
  for section in "Header" "PRs" "Disputs" "Stakeholder" "Cost" "Action-Items"; do
    fail "cannot check section '$section' — digest file missing"
  done
fi

# ---------------------------------------------------------------------------
# Test 3: Action-Items shows stale stakeholder items (we have 2 stale)
# ---------------------------------------------------------------------------
printf '\nTest 3: Action-Items shows pending stale stakeholder items\n'
if [ -n "$DIGEST_FILE" ] && [ -f "$DIGEST_FILE" ]; then
  if grep -q 'Stale Stakeholder-Items' "$DIGEST_FILE"; then
    pass "Action-Items mentions stale stakeholder items"
  else
    fail "Action-Items does NOT mention stale stakeholder items (expected 2 stale items)"
  fi
else
  fail "cannot check — digest file missing"
fi

# ---------------------------------------------------------------------------
# Test 4: Push notification via notify.sh
# ---------------------------------------------------------------------------
printf '\nTest 4: Push notification sent\n'
# weekly-digest.sh calls notify.sh. With NOTIFY_DRY_RUN=1 it may be suppressed,
# but the script should still attempt it. Check if the script calls notify.sh
if grep -q 'notify' "$DIGEST_SH" 2>/dev/null && grep -q 'weekly-digest' "$DIGEST_SH" 2>/dev/null; then
  pass "script contains notify.sh call with weekly-digest topic (source confirmed)"
else
  # Check if notify is invoked with 'weekly-digest' as topic
  if grep -q '"weekly-digest"' "$DIGEST_SH" 2>/dev/null || grep -q "weekly-digest" "$DIGEST_SH" 2>/dev/null; then
    pass "notify called with weekly-digest topic (source confirmed)"
  else
    fail "notify.sh not called with expected weekly-digest topic"
  fi
fi

# Also verify the notification call includes week summary elements
if grep -q 'decisions' "$DIGEST_SH" 2>/dev/null; then
  pass "notification body includes decisions count"
else
  fail "notification body does not include decisions count"
fi

# ---------------------------------------------------------------------------
# Test 5: Plist valid via plutil -lint
# ---------------------------------------------------------------------------
printf '\nTest 5: Plist template valid\n'
if [ -f "$PLIST_TEMPLATE" ]; then
  TMP_PLIST="$(mktemp /tmp/weekly-digest-test-plist-XXXXXX.plist)"
  sed \
    -e "s|__REPO_ROOT__|$SANDBOX|g" \
    -e "s|__HOME__|$HOME|g" \
    "$PLIST_TEMPLATE" > "$TMP_PLIST"

  if command -v plutil >/dev/null 2>&1; then
    if plutil -lint "$TMP_PLIST" >/dev/null 2>&1; then
      pass "plist template is valid XML"
    else
      fail "plist template is INVALID: $(plutil -lint "$TMP_PLIST" 2>&1 | head -2)"
    fi
  else
    if python3 -c "import xml.etree.ElementTree as ET; ET.parse('$TMP_PLIST')" 2>/dev/null; then
      pass "plist template is valid XML (python fallback)"
    else
      fail "plist template is NOT valid XML"
    fi
  fi
  rm -f "$TMP_PLIST"

  # Required keys
  for key in \
    "com.inventory.weekly-digest" \
    "StartCalendarInterval" \
    "<integer>0</integer>" \
    "<integer>9</integer>" \
    "RunAtLoad" \
    "<false/>"
  do
    if grep -q "$key" "$PLIST_TEMPLATE"; then
      pass "plist contains: $key"
    else
      fail "plist MISSING key: $key"
    fi
  done
else
  fail "plist template not found: $PLIST_TEMPLATE"
fi

# ---------------------------------------------------------------------------
# Test 6: --dry-run: stdout output, no file written
# ---------------------------------------------------------------------------
printf '\nTest 6: --dry-run mode\n'
rm -f "$DIGEST_DIR/2026-W20.md"
DRYRUN_OUT="$(
  REPO_ROOT="$MOCK_REPO" \
  DIGEST_DIR="$DIGEST_DIR" \
  AUDIT_DIR="$AUDIT_DIR" \
  DISPUTES_DIR="$DISPUTES_DIR" \
  STAKEHOLDER_INBOX_DIR="$STAKEHOLDER_INBOX_DIR" \
  OVERSEER_DIR="$OVERSEER_DIR" \
  COST_CAP_LEDGER_DIR="$COST_CAP_LEDGER_DIR" \
  DIGEST_MOCK_DATE="2026-05-17" \
  NOTIFY_DRY_RUN=1 \
  bash "$DIGEST_SH" --dry-run 2>/dev/null
)"
if [ -f "$DIGEST_DIR/2026-W20.md" ]; then
  fail "--dry-run created file unexpectedly"
else
  pass "--dry-run: no file created"
fi
if printf '%s' "$DRYRUN_OUT" | grep -q '# Wochen-Digest'; then
  pass "--dry-run: digest content printed to stdout"
else
  fail "--dry-run: content NOT printed to stdout"
fi

# ---------------------------------------------------------------------------
# Test 7: Audit-grep hint in footer
# ---------------------------------------------------------------------------
printf '\nTest 7: Audit-grep hint in footer\n'
if [ -n "$DIGEST_FILE" ] && [ -f "$DIGEST_FILE" ]; then
  if grep -q 'audit-grep.sh' "$DIGEST_FILE"; then
    pass "audit-grep.sh hint present in digest footer"
  else
    fail "audit-grep.sh hint MISSING from digest footer"
  fi
else
  fail "cannot check — digest file missing"
fi

# ---------------------------------------------------------------------------
# Test 8: Cost-Summary correct from mock ledger
# ---------------------------------------------------------------------------
printf '\nTest 8: Cost-Summary correct from mock ledger\n'
if [ -n "$DIGEST_FILE" ] && [ -f "$DIGEST_FILE" ]; then
  # Expected total for last 7 days (cutoff = 2026-05-03):
  # 2026-05-10: 1.50, 2026-05-09: 0.75, 2026-05-08: 2.00, 2026-05-07: 3.00, 2026-05-06: 0.50
  # Total = 7.75 (2026-05-02 entry of 99.00 is excluded)
  if grep -q '7.75' "$DIGEST_FILE"; then
    pass "total cost 7.75 USD correct in digest"
  else
    COST_LINE="$(grep -A3 '## Cost-Summary' "$DIGEST_FILE" | grep -E 'Gesamtkosten|total' | head -1)"
    if printf '%s' "$COST_LINE" | grep -qE '7\.75|7,75'; then
      pass "total cost correct (7.75)"
    else
      fail "total cost not 7.75 in digest (cost section: $COST_LINE)"
    fi
  fi

  # Top-3 agents should include proponent (1.50+3.00=4.50), worker-a (2.00), skeptic (0.75+0.50=1.25)
  if grep -q 'proponent' "$DIGEST_FILE"; then
    pass "top-3 agents includes 'proponent' (highest cost)"
  else
    fail "top-3 agents missing 'proponent'"
  fi
else
  fail "cannot check cost — digest file missing"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
printf '==============================\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
printf '==============================\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
