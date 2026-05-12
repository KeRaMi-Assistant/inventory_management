#!/usr/bin/env bash
# verify/plan-critic.sh — Format-Verify für .claude/agents/plan-critic.md
# Exit 0: alle Checks pass. Exit 1: mindestens ein Check fehlgeschlagen.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT_FILE="$PROJECT_ROOT/.claude/agents/plan-critic.md"
COMMAND_FILE="$PROJECT_ROOT/.claude/commands/plan-critic.md"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo "  [PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== plan-critic verify ==="
echo ""

# 1. Agent-File existiert
if [ -f "$AGENT_FILE" ]; then
  check "Agent-File existiert ($AGENT_FILE)" "ok"
else
  check "Agent-File existiert ($AGENT_FILE)" "fail"
  echo "ABORT: Agent-File fehlt, weitere Checks übersprungen."
  exit 1
fi

# 2. Frontmatter vollständig: name, description, model=opus, tools
grep -q "^name: plan-critic" "$AGENT_FILE" \
  && check "Frontmatter: name=plan-critic" "ok" \
  || check "Frontmatter: name=plan-critic" "fail"

grep -q "^description:" "$AGENT_FILE" \
  && check "Frontmatter: description vorhanden" "ok" \
  || check "Frontmatter: description vorhanden" "fail"

grep -q "^model: opus" "$AGENT_FILE" \
  && check "Frontmatter: model=opus" "ok" \
  || check "Frontmatter: model=opus" "fail"

grep -q "^tools:" "$AGENT_FILE" \
  && check "Frontmatter: tools-Zeile vorhanden" "ok" \
  || check "Frontmatter: tools-Zeile vorhanden" "fail"

# 3. Tools whitelist: nur Read, Grep, Glob, WebSearch — KEIN Bash, Edit, Write
TOOLS_LINE="$(grep "^tools:" "$AGENT_FILE" || true)"
if echo "$TOOLS_LINE" | grep -qE "Bash|Edit|Write"; then
  check "Tools: kein Bash/Edit/Write in Whitelist" "fail"
else
  check "Tools: kein Bash/Edit/Write in Whitelist" "ok"
fi
for required_tool in "Read" "Grep" "Glob" "WebSearch"; do
  if echo "$TOOLS_LINE" | grep -q "$required_tool"; then
    check "Tools: $required_tool vorhanden" "ok"
  else
    check "Tools: $required_tool vorhanden" "fail"
  fi
done

# 4. Output-Format-Section mit Verdict-Optionen + Findings
grep -q "FREIGEGEBEN" "$AGENT_FILE" \
  && check "Output-Format: FREIGEGEBEN-Verdict vorhanden" "ok" \
  || check "Output-Format: FREIGEGEBEN-Verdict vorhanden" "fail"

grep -q "ÜBERARBEITUNG" "$AGENT_FILE" \
  && check "Output-Format: ÜBERARBEITUNG-Verdict vorhanden" "ok" \
  || check "Output-Format: ÜBERARBEITUNG-Verdict vorhanden" "fail"

grep -q "ABLEHNUNG" "$AGENT_FILE" \
  && check "Output-Format: ABLEHNUNG-Verdict vorhanden" "ok" \
  || check "Output-Format: ABLEHNUNG-Verdict vorhanden" "fail"

grep -q "### Findings" "$AGENT_FILE" \
  && check "Output-Format: Findings-Sektion vorhanden" "ok" \
  || check "Output-Format: Findings-Sektion vorhanden" "fail"

# 5. "NICHT-pflicht" / kein Findings-Mindestanzahl-Zwang
grep -q "NICHT-pflicht" "$AGENT_FILE" \
  && check "Regelwerk: NICHT-pflicht ≥3 Findings erwähnt" "ok" \
  || check "Regelwerk: NICHT-pflicht ≥3 Findings erwähnt" "fail"

# 6. Sandwich-Markers erwähnt
grep -q "UNTRUSTED_PLAN_DRAFT" "$AGENT_FILE" \
  && check "Sandwich-Markers: UNTRUSTED_PLAN_DRAFT vorhanden" "ok" \
  || check "Sandwich-Markers: UNTRUSTED_PLAN_DRAFT vorhanden" "fail"

grep -q "END_UNTRUSTED" "$AGENT_FILE" \
  && check "Sandwich-Markers: END_UNTRUSTED vorhanden" "ok" \
  || check "Sandwich-Markers: END_UNTRUSTED vorhanden" "fail"

# 7. Mind. 1 Few-Shot-Example
grep -q "Few-Shot" "$AGENT_FILE" \
  && check "Few-Shot-Example: Section vorhanden" "ok" \
  || check "Few-Shot-Example: Section vorhanden" "fail"

grep -q "<<<UNTRUSTED_PLAN_DRAFT>>>" "$AGENT_FILE" \
  && check "Few-Shot-Example: Beispiel-Input mit Marker vorhanden" "ok" \
  || check "Few-Shot-Example: Beispiel-Input mit Marker vorhanden" "fail"

# 8. Slash-Command-File existiert
if [ -f "$COMMAND_FILE" ]; then
  check "Slash-Command-File existiert ($COMMAND_FILE)" "ok"
else
  check "Slash-Command-File existiert ($COMMAND_FILE)" "fail"
fi

# 9. Output-Cap 600 Tokens erwähnt
grep -q "600" "$AGENT_FILE" \
  && check "Output-Cap: 600 Tokens erwähnt" "ok" \
  || check "Output-Cap: 600 Tokens erwähnt" "fail"

echo ""
echo "=== Ergebnis: $PASS pass, $FAIL fail ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
