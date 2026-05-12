#!/usr/bin/env bash
# verify/intake-docs.sh — prüft T21/T22/T24 Doku-Änderungen
# Exit 0 = alle 5 Checks pass. Exit 1 = mind. ein Check failed.

set -euo pipefail

REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "true" ]; then
    echo "  PASS: $desc"
    ((PASS++)) || true
  else
    echo "  FAIL: $desc"
    ((FAIL++)) || true
  fi
}

echo "=== verify/intake-docs.sh ==="

# 1. CLAUDE.md enthält "Intake-Council (User-Gated"
check "CLAUDE.md enthält 'Intake-Council (User-Gated'" \
  "$(grep -q 'Intake-Council (User-Gated' "$REPO/CLAUDE.md" && echo true || echo false)"

# 2. CLAUDE.md erwähnt Creator-Binding + HMAC-Token
check "CLAUDE.md enthält 'Creator-Binding'" \
  "$(grep -q 'Creator-Binding' "$REPO/CLAUDE.md" && echo true || echo false)"
check "CLAUDE.md enthält 'HMAC-Token'" \
  "$(grep -q 'HMAC-Token' "$REPO/CLAUDE.md" && echo true || echo false)"

# 3. yota.md listet /yota propose-Command
check ".claude/agents/yota.md listet '/yota propose'" \
  "$(grep -q '/yota propose' "$REPO/.claude/agents/yota.md" && echo true || echo false)"

# 4. docs/handbook/05-architecture.md enthält "Intake-Council (Post-Phase-4"
check "docs/handbook/05-architecture.md enthält 'Intake-Council (Post-Phase-4'" \
  "$(grep -q 'Intake-Council (Post-Phase-4' "$REPO/docs/handbook/05-architecture.md" && echo true || echo false)"

# 5. CLAUDE.md erwähnt "intake-council" >= 2 mal
COUNT=$(grep -c 'intake-council' "$REPO/CLAUDE.md" || true)
check "CLAUDE.md erwähnt 'intake-council' >= 2 mal (found: $COUNT)" \
  "$([ "$COUNT" -ge 2 ] && echo true || echo false)"

echo ""
echo "Result: $PASS pass, $FAIL fail"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
