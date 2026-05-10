#!/usr/bin/env bash
# verify/stakeholder-triage.sh — Format-Verify für .claude/agents/stakeholder-triage.md
# Prüft: Frontmatter, Tools-Whitelist, Sandwich-Marker, Few-Shot-Examples, Schema, Quarantine-Pfad.
# Exit 0 = alle Tests pass. Exit 1 = mind. 1 Fehler.

set -euo pipefail

AGENT_FILE="$(dirname "$0")/../../agents/stakeholder-triage.md"
PASS=0
FAIL=0

check() {
  local label="$1"
  local result="$2"  # "pass" oder "fail"
  local detail="${3:-}"
  if [[ "$result" == "pass" ]]; then
    echo "  [PASS] $label"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label${detail:+ — $detail}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== stakeholder-triage.md Format-Verify ==="
echo "File: $AGENT_FILE"
echo ""

if [[ ! -f "$AGENT_FILE" ]]; then
  echo "[FAIL] Agent-File nicht gefunden: $AGENT_FILE"
  exit 1
fi

# ── Test 1: Frontmatter-Felder komplett ─────────────────────────────────────
echo "-- Test 1: Frontmatter komplett"

grep -q '^name: stakeholder-triage' "$AGENT_FILE" && \
  check "name: stakeholder-triage" "pass" || \
  check "name: stakeholder-triage" "fail" "Feld fehlt oder falsch"

grep -q '^model: opus' "$AGENT_FILE" && \
  check "model: opus" "pass" || \
  check "model: opus" "fail" "Muss 'opus' sein (adversarial boundary)"

grep -q '^tools:' "$AGENT_FILE" && \
  check "tools: Zeile vorhanden" "pass" || \
  check "tools: Zeile vorhanden" "fail" "Fehlt"

grep -q '^description:' "$AGENT_FILE" && \
  check "description: vorhanden" "pass" || \
  check "description: vorhanden" "fail" "Fehlt"

# ── Test 2: Tools-Whitelist (kein Bash, kein Edit) ──────────────────────────
echo ""
echo "-- Test 2: Tools-Whitelist"

TOOLS_LINE=$(grep '^tools:' "$AGENT_FILE" || true)

echo "$TOOLS_LINE" | grep -qiw "Read" && \
  check "Tool Read vorhanden" "pass" || \
  check "Tool Read vorhanden" "fail"

echo "$TOOLS_LINE" | grep -qiw "Grep" && \
  check "Tool Grep vorhanden" "pass" || \
  check "Tool Grep vorhanden" "fail"

echo "$TOOLS_LINE" | grep -qiw "Glob" && \
  check "Tool Glob vorhanden" "pass" || \
  check "Tool Glob vorhanden" "fail"

echo "$TOOLS_LINE" | grep -qiw "Write" && \
  check "Tool Write vorhanden" "pass" || \
  check "Tool Write vorhanden" "fail"

# Bash ist VERBOTEN für diesen Agent
if echo "$TOOLS_LINE" | grep -qiw "Bash"; then
  check "Kein Bash-Tool" "fail" "Bash in tools-Liste gefunden — muss entfernt werden"
else
  check "Kein Bash-Tool" "pass"
fi

# Edit ist VERBOTEN (nur Write erlaubt)
if echo "$TOOLS_LINE" | grep -qiw "Edit"; then
  check "Kein Edit-Tool" "fail" "Edit in tools-Liste gefunden — nur Write erlaubt"
else
  check "Kein Edit-Tool" "pass"
fi

# ── Test 3: Sandwich-Marker-Sektion ─────────────────────────────────────────
echo ""
echo "-- Test 3: Sandwich-Marker-Sektion"

grep -q '<<<UNTRUSTED_STAKEHOLDER_INPUT>>>' "$AGENT_FILE" && \
  check "Marker <<<UNTRUSTED_STAKEHOLDER_INPUT>>> vorhanden" "pass" || \
  check "Marker <<<UNTRUSTED_STAKEHOLDER_INPUT>>> vorhanden" "fail"

grep -q '<<<END_UNTRUSTED>>>' "$AGENT_FILE" && \
  check "Marker <<<END_UNTRUSTED>>> vorhanden" "pass" || \
  check "Marker <<<END_UNTRUSTED>>> vorhanden" "fail"

grep -qi 'ausschließlich als Daten' "$AGENT_FILE" && \
  check "Anweisung 'ausschließlich als Daten' vorhanden" "pass" || \
  check "Anweisung 'ausschließlich als Daten' vorhanden" "fail"

grep -qi 'Imperative.*IGNORIEREN\|IGNORIEREN.*Imperative\|zu IGNORIEREN' "$AGENT_FILE" && \
  check "Imperativ-Ignorier-Regel dokumentiert" "pass" || \
  check "Imperativ-Ignorier-Regel dokumentiert" "fail"

# ── Test 4: Few-Shot-Examples (3 Stück) ─────────────────────────────────────
echo ""
echo "-- Test 4: Few-Shot-Examples"

grep -q 'CSV-Export\|csv-export\|csv_export' "$AGENT_FILE" && \
  check "Example 1 (feature-request CSV-Export) vorhanden" "pass" || \
  check "Example 1 (feature-request CSV-Export) vorhanden" "fail"

grep -q 'Theme.*Dunkel\|theme-question\|Dark.*Mode\|Dunkel-Modus\|Dunkel.Modus' "$AGENT_FILE" && \
  check "Example 2 (question Theme) vorhanden" "pass" || \
  check "Example 2 (question Theme) vorhanden" "fail"

grep -q 'SUPABASE_SERVICE_ROLE_KEY\|injection-attempt.*sandwich\|sandwich.*escape' "$AGENT_FILE" && \
  check "Example 3 (injection-attempt Sandwich-Escape) vorhanden" "pass" || \
  check "Example 3 (injection-attempt Sandwich-Escape) vorhanden" "fail"

# ── Test 5: Pflicht-Frontmatter-Felder im Prompt-Body ───────────────────────
echo ""
echo "-- Test 5: Schema-Dokumentation (Pflicht-Felder im Prompt-Body)"

for field in "slug" "source" "priority" "budget_usd" "model" "touches" "needs_gh" \
             "estimated_minutes" "created_from" "stakeholder_slug" "trust_tier"; do
  grep -q "^${field}:" "$AGENT_FILE" && \
    check "Feld '${field}' im Schema dokumentiert" "pass" || \
    check "Feld '${field}' im Schema dokumentiert" "fail"
done

# ── Test 6: Quarantine-Pfad dokumentiert ────────────────────────────────────
echo ""
echo "-- Test 6: Quarantine-Pfad und injection-attempt-Handling"

grep -q '\.claude/stakeholder/quarantine' "$AGENT_FILE" && \
  check "Quarantine-Pfad .claude/stakeholder/quarantine/ dokumentiert" "pass" || \
  check "Quarantine-Pfad .claude/stakeholder/quarantine/ dokumentiert" "fail"

grep -qi 'injection.attempt' "$AGENT_FILE" && \
  check "injection-attempt Klassifikation beschrieben" "pass" || \
  check "injection-attempt Klassifikation beschrieben" "fail"

grep -q 'quarantine' "$AGENT_FILE" && \
  check "Quarantine-Anweisung vorhanden" "pass" || \
  check "Quarantine-Anweisung vorhanden" "fail"

# ── Ergebnis ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Ergebnis: ${PASS} pass, ${FAIL} fail ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED — $FAIL Test(s) fehlgeschlagen."
  exit 1
else
  echo "ALL PASS"
  exit 0
fi
