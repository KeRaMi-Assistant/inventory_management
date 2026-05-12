#!/usr/bin/env bash
# verify/intake-skeptic-agent.sh — Format-Verifikation für .claude/agents/intake-skeptic.md
# Exit 0 = OK, Exit 1 = Fehler

set -euo pipefail

AGENT=".claude/agents/intake-skeptic.md"
ERRORS=0

fail() {
  echo "FAIL: $1" >&2
  ERRORS=$((ERRORS + 1))
}

pass() {
  echo "OK:   $1"
}

if [[ ! -f "$AGENT" ]]; then
  echo "FAIL: $AGENT nicht gefunden" >&2
  exit 1
fi

# 1. Frontmatter: model=sonnet
if grep -q "^model: sonnet$" "$AGENT"; then
  pass "Frontmatter model=sonnet"
else
  fail "Frontmatter model: sonnet fehlt"
fi

# 2. Frontmatter: name=intake-skeptic
if grep -q "^name: intake-skeptic$" "$AGENT"; then
  pass "Frontmatter name=intake-skeptic"
else
  fail "Frontmatter name: intake-skeptic fehlt"
fi

# 3. Tools-Whitelist: Read, Grep, Glob, WebSearch — KEINE Bash/Edit/Write
if grep -q "^tools:.*Read" "$AGENT" && grep -q "^tools:.*Grep" "$AGENT" && grep -q "^tools:.*Glob" "$AGENT" && grep -q "^tools:.*WebSearch" "$AGENT"; then
  pass "Tools-Whitelist enthält Read, Grep, Glob, WebSearch"
else
  fail "Tools-Whitelist unvollständig (erwartet: Read, Grep, Glob, WebSearch)"
fi

# 4. Keine verbotenen Tools (Bash, Edit, Write)
if grep -E "^tools:.*\b(Bash|Edit|Write)\b" "$AGENT"; then
  fail "Verbotene Tools (Bash/Edit/Write) in tools: Zeile gefunden"
else
  pass "Keine verbotenen Tools (Bash/Edit/Write)"
fi

# 5. Anti-Bias-Pflichtphrase
if grep -q "Evaluate, don't relentlessly reject" "$AGENT"; then
  pass "Anti-Bias-Pflichtphrase vorhanden"
else
  fail "Anti-Bias-Phrase 'Evaluate, don't relentlessly reject' fehlt"
fi

# 6. Anti-Bias-Sektion vorhanden
if grep -q "Anti-Bias" "$AGENT"; then
  pass "Anti-Bias-Sektion vorhanden"
else
  fail "Anti-Bias-Sektion fehlt"
fi

# 7. Pflicht-Sektionen im Output-Format
for section in "Bedenken" "Wenn alles in Ordnung" "Empfohlene Mitigations" "Vote:"; do
  if grep -q "$section" "$AGENT"; then
    pass "Output-Format-Sektion '$section' vorhanden"
  else
    fail "Output-Format-Sektion '$section' fehlt"
  fi
done

# 8. 3 Few-Shot-Examples vorhanden
EXAMPLE_COUNT=$(grep -c "### Beispiel" "$AGENT" || true)
if [[ "$EXAMPLE_COUNT" -ge 3 ]]; then
  pass "3 Few-Shot-Examples vorhanden ($EXAMPLE_COUNT gefunden)"
else
  fail "Weniger als 3 Few-Shot-Examples gefunden ($EXAMPLE_COUNT)"
fi

# 9. Output-Cap 1000 Tokens erwähnt
if grep -q "1000" "$AGENT"; then
  pass "Output-Cap 1000 Tokens erwähnt"
else
  fail "Output-Cap 1000 Tokens nicht erwähnt"
fi

# 10. Sandwich-Markers Sektion
if grep -q "UNTRUSTED_PROPOSAL" "$AGENT" && grep -q "END_UNTRUSTED" "$AGENT"; then
  pass "Sandwich-Markers (UNTRUSTED_PROPOSAL / END_UNTRUSTED) vorhanden"
else
  fail "Sandwich-Markers fehlen"
fi

# 11. Vote-Optionen vollständig: accept | accept-with-changes | reject | abstain
if grep -q "accept | accept-with-changes | reject | abstain" "$AGENT"; then
  pass "Vote-Optionen vollständig (accept|accept-with-changes|reject|abstain)"
else
  fail "Vote-Optionen unvollständig (erwartet: accept | accept-with-changes | reject | abstain)"
fi

echo ""
if [[ "$ERRORS" -eq 0 ]]; then
  echo "✓ intake-skeptic-agent.sh: alle Checks bestanden."
  exit 0
else
  echo "✗ intake-skeptic-agent.sh: $ERRORS Fehler." >&2
  exit 1
fi
