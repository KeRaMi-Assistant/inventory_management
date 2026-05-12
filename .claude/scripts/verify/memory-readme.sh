#!/usr/bin/env bash
# memory-readme.sh — Verify-Skript: prüft .claude/memory/README.md + failure-lessons.md
#
# Exit 0 wenn alle Tests bestanden, Exit 1 bei Fehler.

set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
README="${REPO_ROOT}/.claude/memory/README.md"
LESSONS="${REPO_ROOT}/.claude/memory/failure-lessons.md"

PASS=0
FAIL=0

_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS+1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "=== memory-readme verify ==="

# 1. README existiert + enthält "3-Kriterien"
if [ -f "$README" ] && grep -q "3-Kriterien" "$README"; then
  _pass "README.md existiert und enthält '3-Kriterien'"
else
  _fail "README.md fehlt oder enthält nicht '3-Kriterien'"
fi

# 2. Drei Schlüsselwörter wörtlich vorhanden
for word in "surprising" "non-obvious" "future-relevant"; do
  if grep -qi "$word" "$README" 2>/dev/null; then
    _pass "Keyword '$word' vorhanden"
  else
    _fail "Keyword '$word' fehlt in README.md"
  fi
done

# 3. "3×"-Konsolidierungs-Sektion vorhanden
if grep -q "3×" "$README" 2>/dev/null && grep -q "Rule" "$README" 2>/dev/null; then
  _pass "'3× → Rule'-Sektion vorhanden"
else
  _fail "'3× → Rule'-Sektion fehlt in README.md"
fi

# 4. Beispiel-Eintrag mit allen 4 Pflicht-Feldern
for field in "cause:" "pattern:" "mitigation:" "expires_at:"; do
  if grep -q "$field" "$README" 2>/dev/null; then
    _pass "Pflicht-Feld '$field' im Beispiel vorhanden"
  else
    _fail "Pflicht-Feld '$field' fehlt im Beispiel"
  fi
done

# 5. "Anti-Patterns"-Sektion vorhanden
if grep -q "Anti-Pattern" "$README" 2>/dev/null; then
  _pass "'Anti-Patterns'-Sektion vorhanden"
else
  _fail "'Anti-Patterns'-Sektion fehlt in README.md"
fi

# 6. failure-lessons.md existiert mit Header
if [ -f "$LESSONS" ] && grep -q "Failure-Memory" "$LESSONS"; then
  _pass "failure-lessons.md existiert mit Header"
else
  _fail "failure-lessons.md fehlt oder hat keinen Header"
fi

# 7. Sources verweisen auf claude-memory-compiler
if grep -q "claude-memory-compiler" "$README" 2>/dev/null; then
  _pass "Sources verweisen auf claude-memory-compiler"
else
  _fail "Sources-Verweis auf claude-memory-compiler fehlt"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Ergebnis: ${PASS} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
