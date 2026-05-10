#!/usr/bin/env bash
# verify/stakeholder-validator.sh — Format-Verify für .claude/agents/stakeholder-validator.md
# Prüft: Frontmatter, Tools-Whitelist, Schema-Regex-Kategorien, Few-Shot-Examples,
#        Quarantine-Pfad, Frontmatter-Constraints, destruktive Commands (≥7), Pfad-Patterns (≥5).
# Exit 0 = alle Tests pass. Exit 1 = mind. 1 Fehler.

set -euo pipefail

AGENT_FILE="$(dirname "$0")/../../agents/stakeholder-validator.md"
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

echo "=== stakeholder-validator.md Format-Verify ==="
echo "File: $AGENT_FILE"
echo ""

if [[ ! -f "$AGENT_FILE" ]]; then
  echo "[FAIL] Agent-File nicht gefunden: $AGENT_FILE"
  exit 1
fi

# ── Test 1: Frontmatter komplett ─────────────────────────────────────────────
echo "-- Test 1: Frontmatter komplett"

grep -q '^name: stakeholder-validator' "$AGENT_FILE" && \
  check "name: stakeholder-validator" "pass" || \
  check "name: stakeholder-validator" "fail" "Feld fehlt oder falsch"

grep -q '^model: sonnet' "$AGENT_FILE" && \
  check "model: sonnet" "pass" || \
  check "model: sonnet" "fail" "Muss 'sonnet' sein (pattern matching, nicht reasoning-heavy)"

grep -q '^tools:' "$AGENT_FILE" && \
  check "tools: Zeile vorhanden" "pass" || \
  check "tools: Zeile vorhanden" "fail" "Fehlt"

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

grep -q '^description:' "$AGENT_FILE" && \
  check "description: vorhanden" "pass" || \
  check "description: vorhanden" "fail" "Fehlt"

# ── Test 2: Tools-Whitelist (kein Bash, kein Edit) ───────────────────────────
echo ""
echo "-- Test 2: Tools-Whitelist"

if echo "$TOOLS_LINE" | grep -qiw "Bash"; then
  check "Kein Bash-Tool" "fail" "Bash in tools-Liste gefunden — muss entfernt werden"
else
  check "Kein Bash-Tool" "pass"
fi

if echo "$TOOLS_LINE" | grep -qiw "Edit"; then
  check "Kein Edit-Tool" "fail" "Edit in tools-Liste gefunden — nur Write erlaubt"
else
  check "Kein Edit-Tool" "pass"
fi

# ── Test 3: Alle 4 Schema-Regex-Kategorien dokumentiert ──────────────────────
echo ""
echo "-- Test 3: Alle 4 Schema-Regex-Kategorien dokumentiert"

grep -qi 'destruktive.*befehle\|destructive.*cmd\|Kategorie 1' "$AGENT_FILE" && \
  check "Kategorie 1: Destruktive-Commands-Sektion vorhanden" "pass" || \
  check "Kategorie 1: Destruktive-Commands-Sektion vorhanden" "fail"

grep -qi 'gefährliche.*pfade\|gefährliche.*schreib\|Kategorie 2' "$AGENT_FILE" && \
  check "Kategorie 2: Gefährliche-Pfade-Sektion vorhanden" "pass" || \
  check "Kategorie 2: Gefährliche-Pfade-Sektion vorhanden" "fail"

grep -qi 'prompt.injection\|Kategorie 3' "$AGENT_FILE" && \
  check "Kategorie 3: Prompt-Injection-Sektion vorhanden" "pass" || \
  check "Kategorie 3: Prompt-Injection-Sektion vorhanden" "fail"

grep -qi 'frontmatter.valid\|Kategorie 4' "$AGENT_FILE" && \
  check "Kategorie 4: Frontmatter-Validation-Sektion vorhanden" "pass" || \
  check "Kategorie 4: Frontmatter-Validation-Sektion vorhanden" "fail"

# ── Test 4: 3 Few-Shot-Examples vorhanden ────────────────────────────────────
echo ""
echo "-- Test 4: 3 Few-Shot-Examples"

grep -qi 'beispiel 1\|example 1' "$AGENT_FILE" && \
  check "Beispiel 1 vorhanden" "pass" || \
  check "Beispiel 1 vorhanden" "fail"

grep -qi 'beispiel 2\|example 2' "$AGENT_FILE" && \
  check "Beispiel 2 vorhanden" "pass" || \
  check "Beispiel 2 vorhanden" "fail"

grep -qi 'beispiel 3\|example 3' "$AGENT_FILE" && \
  check "Beispiel 3 vorhanden" "pass" || \
  check "Beispiel 3 vorhanden" "fail"

# Pass-Beispiel muss vorhanden sein
grep -qi 'PASS\|pass.*sauber\|sauber.*pass\|clean.*pass\|→ PASS' "$AGENT_FILE" && \
  check "Sauberes Item → PASS-Beispiel vorhanden" "pass" || \
  check "Sauberes Item → PASS-Beispiel vorhanden" "fail"

# git rm -Beispiel
grep -q 'git rm' "$AGENT_FILE" && \
  check "git-rm-Beispiel (Beispiel 2) vorhanden" "pass" || \
  check "git-rm-Beispiel (Beispiel 2) vorhanden" "fail"

# .env-Beispiel
grep -q '\.env\.headless\|env\.headless' "$AGENT_FILE" && \
  check ".env.headless-Beispiel (Beispiel 3) vorhanden" "pass" || \
  check ".env.headless-Beispiel (Beispiel 3) vorhanden" "fail"

# ── Test 5: Quarantine-Pfad im Prompt erwähnt ────────────────────────────────
echo ""
echo "-- Test 5: Quarantine-Pfad dokumentiert"

grep -q '\.claude/stakeholder/quarantine' "$AGENT_FILE" && \
  check "Quarantine-Pfad .claude/stakeholder/quarantine/ dokumentiert" "pass" || \
  check "Quarantine-Pfad .claude/stakeholder/quarantine/ dokumentiert" "fail"

grep -q '\-rejected\.md' "$AGENT_FILE" && \
  check "Quarantine-Filename-Pattern (<slug>-rejected.md) dokumentiert" "pass" || \
  check "Quarantine-Filename-Pattern (<slug>-rejected.md) dokumentiert" "fail"

grep -q '\.claude/overseer/inbox' "$AGENT_FILE" && \
  check "Overseer-Inbox-Pfad .claude/overseer/inbox/ dokumentiert" "pass" || \
  check "Overseer-Inbox-Pfad .claude/overseer/inbox/ dokumentiert" "fail"

# ── Test 6: Frontmatter-Constraints dokumentiert ─────────────────────────────
echo ""
echo "-- Test 6: Frontmatter-Constraints"

grep -q 'tier-1.*tier-2.*tier-3\|tier-1|tier-2|tier-3' "$AGENT_FILE" && \
  check "source: Whitelist (tier-1|tier-2|tier-3) dokumentiert" "pass" || \
  check "source: Whitelist (tier-1|tier-2|tier-3) dokumentiert" "fail"

grep -q 'budget_usd.*20\|≤ 20\|<= 20' "$AGENT_FILE" && \
  check "budget_usd ≤ 20.0 Constraint dokumentiert" "pass" || \
  check "budget_usd ≤ 20.0 Constraint dokumentiert" "fail"

grep -q 'haiku.*sonnet.*opus\|haiku|sonnet|opus' "$AGENT_FILE" && \
  check "model: Enum (haiku|sonnet|opus) dokumentiert" "pass" || \
  check "model: Enum (haiku|sonnet|opus) dokumentiert" "fail"

grep -q 'priority.*0.*1.*2\|0|1|2' "$AGENT_FILE" && \
  check "priority: Enum (0|1|2) dokumentiert" "pass" || \
  check "priority: Enum (0|1|2) dokumentiert" "fail"

# ── Test 7: Mindestens 7 destruktive Commands in Regex-Liste ─────────────────
echo ""
echo "-- Test 7: Mindestens 7 destruktive Commands"

DESTRUCTIVE_COUNT=0

grep -q 'git.rm\|git-rm' "$AGENT_FILE"             && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'rm.*-rf\|rm-rf' "$AGENT_FILE"             && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'drop.*table\|drop-table' "$AGENT_FILE"    && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'delete.*from\|delete-without-where' "$AGENT_FILE" && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'supabase.*db.*reset\|supabase-db-reset' "$AGENT_FILE" && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'gh.*repo.*delete\|gh-repo-delete' "$AGENT_FILE" && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'gh.*pr.*merge.*--admin\|gh-pr-merge-admin' "$AGENT_FILE" && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'git.*reset.*--hard\|git-reset-hard' "$AGENT_FILE" && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'git.*push.*-f\|git.*push.*--force\|git-push-force' "$AGENT_FILE" && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))
grep -q 'git.*branch.*-[Dd]\|git-branch-delete' "$AGENT_FILE" && DESTRUCTIVE_COUNT=$((DESTRUCTIVE_COUNT + 1))

if [[ "$DESTRUCTIVE_COUNT" -ge 7 ]]; then
  check "Mindestens 7 destruktive Commands dokumentiert ($DESTRUCTIVE_COUNT gefunden)" "pass"
else
  check "Mindestens 7 destruktive Commands dokumentiert ($DESTRUCTIVE_COUNT gefunden)" "fail" "Benötigt mind. 7"
fi

# ── Test 8: Mindestens 5 Pfad-Patterns in Gefährliche-Pfade-Liste ────────────
echo ""
echo "-- Test 8: Mindestens 5 Pfad-Patterns"

PATH_COUNT=0

grep -q '~/\|home-tilde' "$AGENT_FILE"              && PATH_COUNT=$((PATH_COUNT + 1))
grep -q '/etc/\|system-etc' "$AGENT_FILE"           && PATH_COUNT=$((PATH_COUNT + 1))
grep -q '/var/\|system-var' "$AGENT_FILE"           && PATH_COUNT=$((PATH_COUNT + 1))
grep -q '/usr/\|system-usr' "$AGENT_FILE"           && PATH_COUNT=$((PATH_COUNT + 1))
grep -q '/System/\|system-root' "$AGENT_FILE"       && PATH_COUNT=$((PATH_COUNT + 1))
grep -q '\.env\b\|env-file' "$AGENT_FILE"           && PATH_COUNT=$((PATH_COUNT + 1))
grep -q 'supabase_config\|supabase-config' "$AGENT_FILE" && PATH_COUNT=$((PATH_COUNT + 1))
grep -q 'google-services' "$AGENT_FILE"             && PATH_COUNT=$((PATH_COUNT + 1))
grep -q 'GoogleService-Info\|apple-plist' "$AGENT_FILE" && PATH_COUNT=$((PATH_COUNT + 1))

if [[ "$PATH_COUNT" -ge 5 ]]; then
  check "Mindestens 5 Pfad-Patterns dokumentiert ($PATH_COUNT gefunden)" "pass"
else
  check "Mindestens 5 Pfad-Patterns dokumentiert ($PATH_COUNT gefunden)" "fail" "Benötigt mind. 5"
fi

# ── Ergebnis ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Ergebnis: ${PASS} pass, ${FAIL} fail ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED — $FAIL Test(s) fehlgeschlagen."
  exit 1
else
  echo "ALL PASS"
  exit 0
fi
