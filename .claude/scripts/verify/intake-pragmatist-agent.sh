#!/usr/bin/env bash
# verify/intake-pragmatist-agent.sh
# Format-Verification für .claude/agents/intake-pragmatist.md
# Exit 0 = OK, Exit 1 = Fehler

set -euo pipefail

AGENT=".claude/agents/intake-pragmatist.md"
ERRORS=0

fail() { echo "FAIL: $1"; ERRORS=$((ERRORS + 1)); }
ok()   { echo "OK:   $1"; }

if [[ ! -f "$AGENT" ]]; then
  echo "FAIL: $AGENT nicht gefunden"
  exit 1
fi

CONTENT=$(cat "$AGENT")

# ── Frontmatter-Checks ─────────────────────────────────────────────────────

grep -q '^name: intake-pragmatist$' "$AGENT" \
  && ok "frontmatter: name" || fail "frontmatter: name fehlt oder falsch"

grep -q '^description:' "$AGENT" \
  && ok "frontmatter: description" || fail "frontmatter: description fehlt"

grep -q '^model: opus$' "$AGENT" \
  && ok "frontmatter: model=opus" || fail "frontmatter: model muss opus sein"

# Tools: Read, Grep, Glob, WebSearch — alle vier müssen vorhanden sein
grep -q '^tools:' "$AGENT" || fail "frontmatter: tools-Zeile fehlt"
TOOLS_LINE=$(grep '^tools:' "$AGENT")
for TOOL in Read Grep Glob WebSearch; do
  echo "$TOOLS_LINE" | grep -q "$TOOL" \
    && ok "frontmatter: tool $TOOL" || fail "frontmatter: tool $TOOL fehlt"
done

# Verbotene Tools: kein Bash, Edit, Write
for BANNED in Bash Edit Write; do
  echo "$TOOLS_LINE" | grep -qv "$BANNED" \
    && ok "frontmatter: kein $BANNED" || fail "frontmatter: $BANNED ist verboten"
done

# ── Pflicht-Sektionen ──────────────────────────────────────────────────────

grep -q '## Aufgabe' "$AGENT" \
  && ok "sektion: Aufgabe" || fail "sektion: Aufgabe fehlt"

grep -q '## Sicherheits-Vertrag' "$AGENT" \
  && ok "sektion: Sicherheits-Vertrag" || fail "sektion: Sicherheits-Vertrag fehlt"

grep -q '<<<UNTRUSTED_PROPOSAL>>>' "$AGENT" \
  && ok "sandwich-marker: UNTRUSTED_PROPOSAL" || fail "sandwich-marker: UNTRUSTED_PROPOSAL fehlt"

grep -q '<<<END_UNTRUSTED>>>' "$AGENT" \
  && ok "sandwich-marker: END_UNTRUSTED" || fail "sandwich-marker: END_UNTRUSTED fehlt"

grep -q '## Bewertungs-Kriterien' "$AGENT" \
  && ok "sektion: Bewertungs-Kriterien" || fail "sektion: Bewertungs-Kriterien fehlt"

grep -q '## Output-Format' "$AGENT" \
  && ok "sektion: Output-Format" || fail "sektion: Output-Format fehlt"

grep -q '## Verarbeitungs-Reihenfolge' "$AGENT" \
  && ok "sektion: Verarbeitungs-Reihenfolge" || fail "sektion: Verarbeitungs-Reihenfolge fehlt"

grep -q '## Few-Shot-Examples' "$AGENT" \
  && ok "sektion: Few-Shot-Examples" || fail "sektion: Few-Shot-Examples fehlt"

# ── 4 Bewertungs-Kriterien ────────────────────────────────────────────────

grep -q 'Pre-Launch-ROI' "$AGENT" \
  && ok "kriterium: Pre-Launch-ROI" || fail "kriterium: Pre-Launch-ROI fehlt"

grep -q 'Doppelung' "$AGENT" \
  && ok "kriterium: Doppelung-Check" || fail "kriterium: Doppelung-Check fehlt"

grep -q 'Mobile-First' "$AGENT" \
  && ok "kriterium: Mobile-First-Fit" || fail "kriterium: Mobile-First-Fit fehlt"

grep -q 'Maintenance-Last' "$AGENT" \
  && ok "kriterium: Maintenance-Last" || fail "kriterium: Maintenance-Last fehlt"

# ── needs-full-council-Logik ──────────────────────────────────────────────

grep -q 'needs-full-council' "$AGENT" \
  && ok "logik: needs-full-council dokumentiert" || fail "logik: needs-full-council fehlt"

grep -q '\.claude/scripts/' "$AGENT" \
  && ok "logik: Self-Mod-Pfad .claude/scripts/ erwähnt" || fail "logik: Self-Mod-Pfad .claude/scripts/ fehlt"

grep -q '\.claude/agents/' "$AGENT" \
  && ok "logik: Self-Mod-Pfad .claude/agents/ erwähnt" || fail "logik: Self-Mod-Pfad .claude/agents/ fehlt"

grep -q 'CLAUDE\.md' "$AGENT" \
  && ok "logik: Self-Mod-Pfad CLAUDE.md erwähnt" || fail "logik: Self-Mod-Pfad CLAUDE.md fehlt"

# ── 2 Few-Shot-Examples ───────────────────────────────────────────────────

EXAMPLE_COUNT=$(grep -c '### Beispiel' "$AGENT" || true)
[[ "$EXAMPLE_COUNT" -ge 2 ]] \
  && ok "few-shot: $EXAMPLE_COUNT Beispiele (min. 2)" || fail "few-shot: weniger als 2 Beispiele ($EXAMPLE_COUNT)"

# Beispiel 1 muss harmlose Idee + propose enthalten
grep -q 'dark footer\|dark-footer\|harmlose' "$AGENT" \
  && ok "few-shot: Beispiel 1 harmlose Idee vorhanden" || fail "few-shot: Beispiel 1 harmlose Idee nicht erkennbar"

# Beispiel 2 muss needs-full-council-Case enthalten
EXAMPLE2_BLOCK=$(awk '/Beispiel 2/,0' "$AGENT")
echo "$EXAMPLE2_BLOCK" | grep -q 'needs-full-council' \
  && ok "few-shot: Beispiel 2 needs-full-council-Verdict vorhanden" || fail "few-shot: Beispiel 2 needs-full-council fehlt"

# ── Anti-Pattern: KEIN Round-1-Hard-Block ────────────────────────────────

# disput-pragmatist hat explizit "KEIN unabhängiger Reviewer in Runde 1" + Fehler-Output.
# intake-pragmatist darf das NICHT enthalten.
if grep -q 'Aufruf in Round 1 ist ein Orchestrator-Fehler' "$AGENT"; then
  fail "anti-pattern: Round-1-Hard-Block aus disput-pragmatist kopiert — NICHT erlaubt"
else
  ok "anti-pattern: kein Round-1-Hard-Block (korrekt)"
fi

# ── Zusammenfassung ───────────────────────────────────────────────────────

echo ""
if [[ "$ERRORS" -eq 0 ]]; then
  echo "RESULT: OK — alle Checks bestanden."
  exit 0
else
  echo "RESULT: FAILED — $ERRORS Fehler gefunden."
  exit 1
fi
