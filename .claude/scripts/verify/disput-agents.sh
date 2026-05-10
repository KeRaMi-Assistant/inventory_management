#!/usr/bin/env bash
# verify/disput-agents.sh — Prüft Format-Korrektheit der 3 Disput-Agent-Files
# Exit 0 = alle Tests bestanden. Exit 1 = mindestens ein Fehler.

set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")/../../agents" && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

check_file() {
  local file="$1"
  local label="$2"
  if [[ -f "$file" ]]; then
    pass "$label existiert: $file"
  else
    fail "$label fehlt: $file"
  fi
}

check_frontmatter_field() {
  local file="$1"
  local field="$2"
  local expected="$3"
  local label="$4"
  if grep -q "^${field}: ${expected}" "$file" 2>/dev/null; then
    pass "$label — Frontmatter '${field}: ${expected}'"
  else
    fail "$label — Frontmatter '${field}: ${expected}' fehlt in $file"
  fi
}

check_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -qF "$pattern" "$file" 2>/dev/null; then
    pass "$label — enthält: '$pattern'"
  else
    fail "$label — fehlt: '$pattern'"
  fi
}

check_line_count() {
  local file="$1"
  local max="$2"
  local label="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label — Datei nicht gefunden, Zeilenanzahl nicht prüfbar"
    return
  fi
  local lines
  lines=$(wc -l < "$file")
  if [[ "$lines" -le "$max" ]]; then
    pass "$label — $lines Zeilen (≤ $max)"
  else
    fail "$label — $lines Zeilen (> $max / 500 Zeilen Limit)"
  fi
}

PROPONENT="$AGENTS_DIR/disput-proponent.md"
SKEPTIC="$AGENTS_DIR/disput-skeptic.md"
PRAGMATIST="$AGENTS_DIR/disput-pragmatist.md"

echo ""
echo "=== Test 1: Alle 3 Agent-Files existieren ==="
check_file "$PROPONENT"    "disput-proponent.md"
check_file "$SKEPTIC"      "disput-skeptic.md"
check_file "$PRAGMATIST"   "disput-pragmatist.md"

echo ""
echo "=== Test 2: Frontmatter — name, model: opus, tools-Whitelist ==="
for file in "$PROPONENT" "$SKEPTIC" "$PRAGMATIST"; do
  label="$(basename "$file")"
  if [[ ! -f "$file" ]]; then
    fail "$label — nicht gefunden, Frontmatter-Check übersprungen"
    continue
  fi

  # name muss gesetzt sein
  if grep -q "^name: disput-" "$file"; then
    pass "$label — name: disput-* vorhanden"
  else
    fail "$label — name: disput-* fehlt"
  fi

  # model: opus
  check_frontmatter_field "$file" "model" "opus" "$label"

  # tools: Whitelist (Read, Grep, Glob, WebSearch)
  if grep -q "^tools:" "$file"; then
    tools_line=$(grep "^tools:" "$file")
    # Erlaubt: Read, Grep, Glob, WebSearch
    # Verboten: Bash, Edit, Write
    for forbidden in "Bash" "Edit" "Write"; do
      if echo "$tools_line" | grep -q "$forbidden"; then
        fail "$label — tools-Whitelist verletzt: '$forbidden' ist nicht erlaubt"
      else
        pass "$label — tools-Whitelist OK: '$forbidden' nicht enthalten"
      fi
    done
    for required in "Read" "Grep" "Glob" "WebSearch"; do
      if echo "$tools_line" | grep -q "$required"; then
        pass "$label — tools enthält: '$required'"
      else
        fail "$label — tools fehlt: '$required'"
      fi
    done
  else
    fail "$label — 'tools:' Frontmatter-Zeile fehlt"
  fi
done

echo ""
echo "=== Test 3: Proponent — Output-Format dokumentiert ==="
if [[ -f "$PROPONENT" ]]; then
  check_contains "$PROPONENT" "## Proponent (Round N)"      "Proponent-Format: Round-Header"
  check_contains "$PROPONENT" "### Vorteile"                "Proponent-Format: Vorteile-Sektion"
  check_contains "$PROPONENT" "### Empfohlene Implementation" "Proponent-Format: Implementation-Sektion"
  check_contains "$PROPONENT" "### Vote: accept"            "Proponent-Format: Vote-Zeile"
fi

echo ""
echo "=== Test 4: Skeptic — Output-Format dokumentiert ==="
if [[ -f "$SKEPTIC" ]]; then
  check_contains "$SKEPTIC" "## Skeptic (Round N)"          "Skeptic-Format: Round-Header"
  check_contains "$SKEPTIC" "### Risiken"                   "Skeptic-Format: Risiken-Sektion"
  check_contains "$SKEPTIC" "### Falsche Annahmen"          "Skeptic-Format: Falsche-Annahmen-Sektion"
  check_contains "$SKEPTIC" "### Maintenance-Lasten"        "Skeptic-Format: Maintenance-Lasten-Sektion"
  check_contains "$SKEPTIC" "### Vote: reject"              "Skeptic-Format: Vote-Zeile"
fi

echo ""
echo "=== Test 5: Pragmatist — 'nur bei Patt' / 'nur als Tie-Break' ==="
if [[ -f "$PRAGMATIST" ]]; then
  if grep -qiE "nur bei Patt|nur als Tie-Break|NUR als Tie-Break|NUR bei Patt" "$PRAGMATIST"; then
    pass "Pragmatist — enthält explizite Nur-Tie-Break-Einschränkung"
  else
    fail "Pragmatist — fehlt explizite 'nur bei Patt' oder 'nur als Tie-Break' Regel"
  fi
fi

echo ""
echo "=== Test 6: Sandwich-Markers in allen 3 Prompts ==="
for file in "$PROPONENT" "$SKEPTIC" "$PRAGMATIST"; do
  label="$(basename "$file")"
  [[ -f "$file" ]] || continue
  check_contains "$file" "<<<UNTRUSTED_PROPOSAL>>>"  "$label — Sandwich-Marker öffnen"
  check_contains "$file" "<<<END_UNTRUSTED>>>"       "$label — Sandwich-Marker schließen"
done

echo ""
echo "=== Test 7: Few-Shot-Examples in allen 3 ==="
for file in "$PROPONENT" "$SKEPTIC" "$PRAGMATIST"; do
  label="$(basename "$file")"
  [[ -f "$file" ]] || continue
  if grep -qiE "Few-Shot|Beispiel-Proposal|Beispiel-Output" "$file"; then
    pass "$label — Few-Shot-Example-Block gefunden"
  else
    fail "$label — Few-Shot-Example-Block fehlt"
  fi
done

echo ""
echo "=== Test 8: Zeilenlänge < 500 Zeilen pro Agent ==="
check_line_count "$PROPONENT"  500 "disput-proponent.md"
check_line_count "$SKEPTIC"    500 "disput-skeptic.md"
check_line_count "$PRAGMATIST" 500 "disput-pragmatist.md"

echo ""
echo "========================================"
echo "Ergebnis: ${PASS} PASS / ${FAIL} FAIL"
echo "========================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
