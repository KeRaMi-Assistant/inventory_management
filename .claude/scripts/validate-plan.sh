#!/usr/bin/env bash
# validate-plan.sh — Statisch prüft Plan-Annahmen gegen Codebase.
# Usage: validate-plan.sh <plan.md>
# Exit: 0 = clean, 1 = mismatches found (Liste auf stderr), 2 = usage/IO-Fehler
#
# Pflicht-Checks:
#   A) Tabellennamen aus Plan vs. supabase/migrations/*.sql
#   B) Provider/Service-Methoden vs. lib/providers/ + lib/services/
#   C) ARB-Keys vs. lib/l10n/app_de.arb + app_en.arb
#   D) Edge-Functions vs. supabase/functions/<name>/index.ts
#
# Items mit `[NEW]`, `(NEU)`, `(NEW)` oder `neu` im 80-char-Fenster nach
# dem Symbol-Match werden ignoriert (Plan deklariert sie explizit als neu).
#
# Code-Fences ```diff / ```bash / ```sql etc. werden NICHT herausgefiltert,
# aber Symbole innerhalb von ihnen sind reguläre Treffer — Plan-Autoren
# müssen `[NEW]`-Marker setzen, wenn ein Beispiel ein neues Symbol nennt.
# Ausnahme: Fenced Blocks die mit ```diff oder ```example beginnen werden
# komplett übersprungen (Heuristik für Pseudo-Code).
#
# Future: bind into .claude/hooks/pre-council.sh

set -uo pipefail
# Note: deliberately NOT using `set -e` — the script orchestrates many
# pipelines whose individual non-matches (e.g. grep finds nothing on a
# given line) are normal and must not abort the whole validator.

PLAN_FILE="${1:-}"
if [ -z "$PLAN_FILE" ]; then
  echo "Usage: $0 <plan.md>" >&2
  exit 2
fi
if [ ! -f "$PLAN_FILE" ]; then
  echo "Usage: $0 <plan.md>" >&2
  echo "Error: file not found: $PLAN_FILE" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MIGRATIONS_DIR="$REPO_ROOT/supabase/migrations"
PROVIDERS_DIR="$REPO_ROOT/lib/providers"
SERVICES_DIR="$REPO_ROOT/lib/services"
FUNCTIONS_DIR="$REPO_ROOT/supabase/functions"
ARB_DE="$REPO_ROOT/lib/l10n/app_de.arb"
ARB_EN="$REPO_ROOT/lib/l10n/app_en.arb"

# Strip fenced blocks marked as diff/example/pseudo (but keep their line numbers
# as blank lines so reported L<n> stays accurate). Output: stripped plan text.
strip_pseudo_fences() {
  awk '
    BEGIN { in_skip = 0 }
    {
      if (in_skip) {
        if ($0 ~ /^[[:space:]]*```[[:space:]]*$/) { in_skip = 0; print ""; next }
        print ""
        next
      }
      if ($0 ~ /^[[:space:]]*```(diff|example|pseudo|pseudocode)([[:space:]]|$)/) {
        in_skip = 1
        print ""
        next
      }
      print
    }
  ' "$1"
}

# Returns 0 if line text (arg1) has a [NEW]-style marker in 80 chars after
# offset (arg2 is the matched symbol used to locate the offset).
has_new_marker() {
  local line="$1" symbol="$2"
  # Find position of symbol; if not found check whole line.
  local idx
  idx=$(awk -v line="$line" -v sym="$symbol" 'BEGIN { p = index(line, sym); print p }')
  local window
  if [ "$idx" -gt 0 ]; then
    window="${line:$((idx-1)):$((${#symbol}+80))}"
  else
    window="$line"
  fi
  # Lowercase for `neu`-check
  local lower
  lower=$(printf '%s' "$window" | tr '[:upper:]' '[:lower:]')
  if printf '%s' "$window" | grep -qE '\[NEW\]|\(NEU\)|\(NEW\)'; then
    return 0
  fi
  if printf '%s' "$lower" | grep -qE '\bneu\b'; then
    return 0
  fi
  return 1
}

# Levenshtein close-match via python3 (best-effort suggestion).
close_match() {
  local needle="$1"; shift
  local candidates="$*"
  python3 - "$needle" "$candidates" <<'PY' 2>/dev/null || true
import sys, difflib
needle = sys.argv[1]
pool = sys.argv[2].split()
matches = difflib.get_close_matches(needle, pool, n=1, cutoff=0.6)
if matches:
    print(matches[0])
PY
}

# Collect known symbols ---------------------------------------------------

# Known tables: parse CREATE TABLE / ALTER TABLE statements from migrations
KNOWN_TABLES=""
if [ -d "$MIGRATIONS_DIR" ]; then
  KNOWN_TABLES=$(
    grep -hEoi 'CREATE TABLE (IF NOT EXISTS )?(public\.)?[a-z_][a-z0-9_]*|ALTER TABLE (ONLY )?(public\.)?[a-z_][a-z0-9_]*' \
      "$MIGRATIONS_DIR"/*.sql 2>/dev/null \
    | sed -E 's/^(CREATE TABLE|ALTER TABLE)( IF NOT EXISTS| ONLY)?[[:space:]]+//I' \
    | sed -E 's/^public\.//' \
    | tr '[:upper:]' '[:lower:]' \
    | sort -u
  )
fi

# Known providers/services: file-base + method names (Dart top-level/class methods).
collect_dart_methods() {
  local dir="$1"
  if [ ! -d "$dir" ]; then return; fi
  # Match patterns like `  Future<...> methodName(` or `  void methodName(` or `  Type methodName(`.
  grep -hE '^\s*(static\s+)?(Future<[^>]*>|Stream<[^>]*>|void|bool|int|double|String|List<[^>]*>|Map<[^>]*>|[A-Z][A-Za-z0-9_]*)\??\s+[a-z_][A-Za-z0-9_]*\s*\(' \
    "$dir"/*.dart 2>/dev/null \
  | sed -E 's/.*[[:space:]]([a-z_][A-Za-z0-9_]*)\s*\(.*/\1/' \
  | sort -u
}

KNOWN_PROVIDER_METHODS=$(collect_dart_methods "$PROVIDERS_DIR")
KNOWN_SERVICE_METHODS=$(collect_dart_methods "$SERVICES_DIR")

# Known ARB keys (both files must contain key).
known_arb_keys() {
  local file="$1"
  [ -f "$file" ] || return
  grep -oE '^\s*"[a-zA-Z_][a-zA-Z0-9_]*"\s*:' "$file" \
    | grep -v '^\s*"@' \
    | sed -E 's/^\s*"([a-zA-Z_][a-zA-Z0-9_]*)".*/\1/'
}
ARB_KEYS_DE=$(known_arb_keys "$ARB_DE" | sort -u)
ARB_KEYS_EN=$(known_arb_keys "$ARB_EN" | sort -u)
# Intersection: keys present in BOTH
ARB_KEYS_BOTH=$(comm -12 <(printf '%s\n' "$ARB_KEYS_DE") <(printf '%s\n' "$ARB_KEYS_EN"))

# Known edge functions: subdirs of supabase/functions with index.ts
KNOWN_FUNCTIONS=""
if [ -d "$FUNCTIONS_DIR" ]; then
  KNOWN_FUNCTIONS=$(
    for d in "$FUNCTIONS_DIR"/*/; do
      [ -f "$d/index.ts" ] || continue
      basename "$d"
    done | sort -u
  )
fi

# Build stripped plan text into temp file with original line numbers preserved.
STRIPPED=$(mktemp)
trap 'rm -f "$STRIPPED"' EXIT
strip_pseudo_fences "$PLAN_FILE" > "$STRIPPED"

# Output buffers ----------------------------------------------------------
FINDINGS_A=""
FINDINGS_B=""
FINDINGS_C=""
FINDINGS_D=""
MISMATCH_COUNT=0

add_finding() {
  local cat="$1" msg="$2"
  case "$cat" in
    A) FINDINGS_A+="$msg"$'\n' ;;
    B) FINDINGS_B+="$msg"$'\n' ;;
    C) FINDINGS_C+="$msg"$'\n' ;;
    D) FINDINGS_D+="$msg"$'\n' ;;
  esac
  MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
}

# Check A: Tabellennamen --------------------------------------------------
# Patterns: public.<t>, FROM <t>, INSERT INTO <t>, JOIN <t>, UPDATE <t>
while IFS= read -r match; do
  [ -z "$match" ] && continue
  ln="${match%%:*}"
  rest="${match#*:}"
  # Extract all candidate tablenames from this line.
  candidates=$(printf '%s' "$rest" | grep -oE '(public\.[a-z_][a-z0-9_]*|(FROM|INSERT INTO|UPDATE|JOIN)[[:space:]]+[a-z_][a-z0-9_]*)' \
    | sed -E 's/^public\.//; s/^(FROM|INSERT INTO|UPDATE|JOIN)[[:space:]]+//I' \
    | sort -u)
  for tbl in $candidates; do
    # skip generic SQL keywords / too-short
    case "$tbl" in
      where|select|values|set|on|using|as|true|false|null|exists) continue ;;
    esac
    [ ${#tbl} -lt 3 ] && continue
    if printf '%s\n' "$KNOWN_TABLES" | grep -qx "$tbl"; then
      continue
    fi
    if has_new_marker "$rest" "$tbl"; then
      continue
    fi
    suggestion=$(close_match "$tbl" "$KNOWN_TABLES")
    msg="  L $ln: '$tbl' — KEINE Migration enthält 'CREATE TABLE.*$tbl'."
    if [ -n "$suggestion" ]; then
      msg+=" Meintest du '$suggestion'?"
    else
      msg+=" Wenn neu: '[NEW]'-Marker hinzufügen."
    fi
    add_finding A "$msg"
  done
done < <(grep -nEi '(public\.[a-z_][a-z0-9_]*|\b(FROM|INSERT INTO|UPDATE|JOIN)[[:space:]]+[a-z_][a-z0-9_]*)' "$STRIPPED" || true)

# Check B: Provider/Service-Methoden --------------------------------------
# Pattern: <Name>Provider.method() or <Name>Service.method()
while IFS= read -r match; do
  [ -z "$match" ] && continue
  ln="${match%%:*}"
  rest="${match#*:}"
  hits=$(printf '%s' "$rest" | grep -oE '[A-Z][A-Za-z0-9_]*(Provider|Service)\.[a-z_][A-Za-z0-9_]*' || true)
  for hit in $hits; do
    class="${hit%%.*}"
    method="${hit##*.}"
    kind="${class##*[a-z0-9_]}"  # may be empty; we use suffix below
    if printf '%s' "$class" | grep -q 'Provider$'; then
      pool="$KNOWN_PROVIDER_METHODS"
      dir_label="lib/providers/"
    else
      pool="$KNOWN_SERVICE_METHODS"
      dir_label="lib/services/"
    fi
    if printf '%s\n' "$pool" | grep -qx "$method"; then
      continue
    fi
    if has_new_marker "$rest" "$hit"; then
      continue
    fi
    suggestion=$(close_match "$method" "$pool")
    msg="  L $ln: '$hit' — Methode '$method' nicht in $dir_label gefunden."
    if [ -n "$suggestion" ]; then
      msg+=" Meintest du '$suggestion'?"
    else
      msg+=" Wenn neu: '[NEW]'-Marker hinzufügen."
    fi
    add_finding B "$msg"
  done
done < <(grep -nE '[A-Z][A-Za-z0-9_]*(Provider|Service)\.[a-z_]' "$STRIPPED" || true)

# Check C: ARB-Keys -------------------------------------------------------
# Pattern: l10n.<key> or AppLocalizations.of(context).<key> or .l10n.<key>
while IFS= read -r match; do
  [ -z "$match" ] && continue
  ln="${match%%:*}"
  rest="${match#*:}"
  hits=$(printf '%s' "$rest" | grep -oE '(l10n|AppLocalizations\.of\([^)]*\))\.[a-zA-Z_][a-zA-Z0-9_]*' \
    | sed -E 's/.*\.([a-zA-Z_][a-zA-Z0-9_]*)$/\1/' \
    | sort -u || true)
  for key in $hits; do
    if printf '%s\n' "$ARB_KEYS_BOTH" | grep -qx "$key"; then
      continue
    fi
    if has_new_marker "$rest" "$key"; then
      continue
    fi
    # Differentiate: missing in DE, EN, or both?
    in_de=$(printf '%s\n' "$ARB_KEYS_DE" | grep -cx "$key" || true)
    in_en=$(printf '%s\n' "$ARB_KEYS_EN" | grep -cx "$key" || true)
    if [ "$in_de" -eq 0 ] && [ "$in_en" -eq 0 ]; then
      where="DE+EN"
    elif [ "$in_de" -eq 0 ]; then
      where="DE"
    else
      where="EN"
    fi
    msg="  L $ln: '$key' — fehlt in $where (lib/l10n/app_*.arb). Wenn neu: '[NEW]'-Marker hinzufügen."
    add_finding C "$msg"
  done
done < <(grep -nE '(l10n|AppLocalizations\.of\([^)]*\))\.[a-zA-Z_]' "$STRIPPED" || true)

# Check D: Edge-Functions -------------------------------------------------
# Patterns: supabase/functions/<name>/, functions.invoke('<name>')
while IFS= read -r match; do
  [ -z "$match" ] && continue
  ln="${match%%:*}"
  rest="${match#*:}"
  hits=$(printf '%s' "$rest" | grep -oE "(supabase/functions/[a-z0-9_-]+/|functions\.invoke\([\"'][a-z0-9_-]+[\"']\))" || true)
  for hit in $hits; do
    name=$(printf '%s' "$hit" | sed -E "s|supabase/functions/([a-z0-9_-]+)/|\1|; s|functions\.invoke\([\"']([a-z0-9_-]+)[\"']\)|\1|")
    # Skip the literal "_shared" helper dir
    [ "$name" = "_shared" ] && continue
    if printf '%s\n' "$KNOWN_FUNCTIONS" | grep -qx "$name"; then
      continue
    fi
    if has_new_marker "$rest" "$name"; then
      continue
    fi
    suggestion=$(close_match "$name" "$KNOWN_FUNCTIONS")
    msg="  L $ln: '$name' — supabase/functions/$name/index.ts existiert nicht."
    if [ -n "$suggestion" ]; then
      msg+=" Meintest du '$suggestion'?"
    else
      msg+=" Wenn neu: '[NEW]'-Marker hinzufügen."
    fi
    add_finding D "$msg"
  done
done < <(grep -nE "(supabase/functions/[a-z0-9_-]+/|functions\.invoke\([\"'][a-z0-9_-]+[\"'])" "$STRIPPED" || true)

# Report ------------------------------------------------------------------
{
  echo "[validate-plan] Plan: $PLAN_FILE"
  echo "[validate-plan] Mismatches found: $MISMATCH_COUNT"
  echo ""
  echo "== Tabellennamen =="
  if [ -n "$FINDINGS_A" ]; then printf '%s' "$FINDINGS_A"; else echo "  (alle ok)"; fi
  echo ""
  echo "== Provider/Service-Methoden =="
  if [ -n "$FINDINGS_B" ]; then printf '%s' "$FINDINGS_B"; else echo "  (alle ok)"; fi
  echo ""
  echo "== ARB-Keys =="
  if [ -n "$FINDINGS_C" ]; then printf '%s' "$FINDINGS_C"; else echo "  (alle ok)"; fi
  echo ""
  echo "== Edge-Functions =="
  if [ -n "$FINDINGS_D" ]; then printf '%s' "$FINDINGS_D"; else echo "  (alle ok)"; fi
} >&2

if [ "$MISMATCH_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
