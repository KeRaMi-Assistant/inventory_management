#!/usr/bin/env bash
# verify/scan-failure-lessons.sh — Tests für scan-failure-lessons-expiry.sh
#
# Alle Tests laufen in isolierten mktemp-Sandboxes via CLAUDE_PROJECT_DIR.
# Exit 0 = alle Tests grün.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="${SCRIPT_DIR}/../../analyzer/modules/scan-failure-lessons-expiry.sh"

if [ ! -f "$MODULE" ]; then
  printf 'ERROR: Modul nicht gefunden: %s\n' "$MODULE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '\033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; FAILURES=$((FAILURES + 1)); }

FAILURES=0
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

_new_sandbox() {
  local name="$1"
  local d="${TMPDIR_BASE}/sandbox_${name}"
  mkdir -p "$d/.claude/memory"
  mkdir -p "$d/.claude/overseer/inbox"
  mkdir -p "$d/.claude/analyzer/state"
  mkdir -p "$d/.claude/audit"
  # Provide a minimal git-stub so git rev-parse doesn't fail
  mkdir -p "$d/.git"
  printf 'ref: refs/heads/main\n' > "$d/.git/HEAD"
  printf '%s' "$d"
}

_run_module() {
  local sandbox="$1"
  shift
  CLAUDE_PROJECT_DIR="$sandbox" bash "$MODULE" "$@"
}

_item_count() {
  local sandbox="$1"
  find "$sandbox/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-failure-lessons-expiry-*.md" 2>/dev/null | wc -l | tr -d ' '
}

# Datumshelper
_date_past() {
  # Gibt ein Datum 30 Tage in der Vergangenheit zurück
  if date -v -30d +%Y-%m-%d >/dev/null 2>&1; then
    date -u -v -30d +%Y-%m-%d
  else
    date -u -d "-30 days" +%Y-%m-%d
  fi
}

_date_future() {
  # Gibt ein Datum 30 Tage in der Zukunft zurück
  if date -v +30d +%Y-%m-%d >/dev/null 2>&1; then
    date -u -v +30d +%Y-%m-%d
  else
    date -u -d "+30 days" +%Y-%m-%d
  fi
}

PAST="$(_date_past)"
FUTURE="$(_date_future)"

# ---------------------------------------------------------------------------
# T1 — File fehlt: exit 0, kein Item
# ---------------------------------------------------------------------------
sb1="$(_new_sandbox T1)"
rc=0
_run_module "$sb1" >/dev/null 2>&1 || rc=$?
count1="$(_item_count "$sb1")"

if [ "$rc" -eq 0 ] && [ "$count1" -eq 0 ]; then
  _pass "T1: File fehlt → exit 0, 0 Items"
else
  _fail "T1: File fehlt → exit 0, 0 Items" "rc=$rc count=$count1"
fi

# ---------------------------------------------------------------------------
# T2 — File leer: exit 0, kein Item
# ---------------------------------------------------------------------------
sb2="$(_new_sandbox T2)"
touch "$sb2/.claude/memory/failure-lessons.md"
rc=0
_run_module "$sb2" >/dev/null 2>&1 || rc=$?
count2="$(_item_count "$sb2")"

if [ "$rc" -eq 0 ] && [ "$count2" -eq 0 ]; then
  _pass "T2: File leer → exit 0, 0 Items"
else
  _fail "T2: File leer → exit 0, 0 Items" "rc=$rc count=$count2"
fi

# ---------------------------------------------------------------------------
# T3 — 1 Lesson, expired: 1 Item, Frontmatter korrekt
# ---------------------------------------------------------------------------
sb3="$(_new_sandbox T3)"
cat > "$sb3/.claude/memory/failure-lessons.md" <<EOF
## amazon-parse-bug
- cause: Regex zu breit
- pattern: Amazon-Mails werden falsch geparst
- mitigation: Engere Regex
- expires_at: ${PAST}
EOF

rc=0
_run_module "$sb3" >/dev/null 2>&1 || rc=$?
count3="$(_item_count "$sb3")"

if [ "$rc" -eq 0 ] && [ "$count3" -eq 1 ]; then
  _pass "T3: 1 expired Lesson → exit 0, 1 Item erzeugt"
else
  _fail "T3: 1 expired Lesson → exit 0, 1 Item erzeugt" "rc=$rc count=$count3"
fi

# Frontmatter prüfen
item3="$(find "$sb3/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-failure-lessons-expiry-amazon-parse-bug.md" 2>/dev/null | head -1)"
if [ -n "$item3" ]; then
  if grep -q "source: tier-3" "$item3" && \
     grep -q "priority: 2" "$item3" && \
     grep -q "budget_usd: 1.0" "$item3" && \
     grep -q "model: haiku" "$item3" && \
     grep -q "needs_gh: false" "$item3" && \
     grep -q "trust_tier: 3" "$item3" && \
     grep -q "created_from: scan-failure-lessons-expiry" "$item3"; then
    _pass "T3: Frontmatter vollständig korrekt"
  else
    _fail "T3: Frontmatter vollständig korrekt" "Fehlende Felder in $item3"
  fi

  if grep -q "amazon-parse-bug" "$item3" && grep -q "$PAST" "$item3"; then
    _pass "T3: Body enthält Slug + Datum"
  else
    _fail "T3: Body enthält Slug + Datum" "Content: $(cat "$item3")"
  fi
else
  _fail "T3: Item-File vorhanden" "Kein passender Filename in inbox"
fi

# ---------------------------------------------------------------------------
# T4 — 1 Lesson, nicht expired (future): 0 Items
# ---------------------------------------------------------------------------
sb4="$(_new_sandbox T4)"
cat > "$sb4/.claude/memory/failure-lessons.md" <<EOF
## future-lesson
- cause: Zukünftiger Fehler
- pattern: Kommt noch
- mitigation: Abwarten
- expires_at: ${FUTURE}
EOF

rc=0
_run_module "$sb4" >/dev/null 2>&1 || rc=$?
count4="$(_item_count "$sb4")"

if [ "$rc" -eq 0 ] && [ "$count4" -eq 0 ]; then
  _pass "T4: 1 future Lesson → exit 0, 0 Items"
else
  _fail "T4: 1 future Lesson → exit 0, 0 Items" "rc=$rc count=$count4"
fi

# ---------------------------------------------------------------------------
# T5 — Re-Run mit gleichem expired Slug: kein Duplikat
# ---------------------------------------------------------------------------
sb5="$(_new_sandbox T5)"
cat > "$sb5/.claude/memory/failure-lessons.md" <<EOF
## dedup-test
- cause: X
- pattern: Y
- mitigation: Z
- expires_at: ${PAST}
EOF

# Erster Run
_run_module "$sb5" >/dev/null 2>&1
count5a="$(_item_count "$sb5")"

# Zweiter Run
_run_module "$sb5" >/dev/null 2>&1
count5b="$(_item_count "$sb5")"

if [ "$count5a" -eq 1 ] && [ "$count5b" -eq 1 ]; then
  _pass "T5: Re-Run → kein Duplikat (1 Item nach beiden Runs)"
else
  _fail "T5: Re-Run → kein Duplikat" "count nach Run1=$count5a count nach Run2=$count5b"
fi

# ---------------------------------------------------------------------------
# T6 — Mehrere Lessons gemischt: 2 expired + 1 future → 2 Items
# ---------------------------------------------------------------------------
sb6="$(_new_sandbox T6)"
cat > "$sb6/.claude/memory/failure-lessons.md" <<EOF
## expired-one
- cause: A
- pattern: B
- mitigation: C
- expires_at: ${PAST}

## future-one
- cause: D
- pattern: E
- mitigation: F
- expires_at: ${FUTURE}

## expired-two
- cause: G
- pattern: H
- mitigation: I
- expires_at: ${PAST}
EOF

rc=0
_run_module "$sb6" >/dev/null 2>&1 || rc=$?
count6="$(_item_count "$sb6")"

if [ "$rc" -eq 0 ] && [ "$count6" -eq 2 ]; then
  _pass "T6: 2 expired + 1 future → exit 0, 2 Items"
else
  _fail "T6: 2 expired + 1 future → exit 0, 2 Items" "rc=$rc count=$count6"
fi

# ---------------------------------------------------------------------------
# T7 — --dry-run: stdout zeigt geplante Items, kein File geschrieben
# ---------------------------------------------------------------------------
sb7="$(_new_sandbox T7)"
cat > "$sb7/.claude/memory/failure-lessons.md" <<EOF
## dry-run-lesson
- cause: X
- pattern: Y
- mitigation: Z
- expires_at: ${PAST}
EOF

output7="$(CLAUDE_PROJECT_DIR="$sb7" bash "$MODULE" --dry-run 2>&1)"
count7="$(_item_count "$sb7")"

if echo "$output7" | grep -q "DRY-RUN" && [ "$count7" -eq 0 ]; then
  _pass "T7: --dry-run → stdout zeigt DRY-RUN, 0 Files geschrieben"
else
  _fail "T7: --dry-run → stdout zeigt DRY-RUN, 0 Files geschrieben" \
    "output contains DRY-RUN=$(echo "$output7" | grep -c "DRY-RUN") count=$count7"
fi

# ---------------------------------------------------------------------------
# T8 — Lesson ohne expires_at: skip mit Warning (kein Item)
# ---------------------------------------------------------------------------
sb8="$(_new_sandbox T8)"
cat > "$sb8/.claude/memory/failure-lessons.md" <<EOF
## no-expiry-lesson
- cause: X
- pattern: Y
- mitigation: Z
EOF

rc=0
stderr8="$(CLAUDE_PROJECT_DIR="$sb8" bash "$MODULE" 2>&1 >/dev/null)" || rc=$?
count8="$(_item_count "$sb8")"

if [ "$rc" -eq 0 ] && [ "$count8" -eq 0 ] && echo "$stderr8" | grep -qi "warn\|kein\|skip\|no.*expires"; then
  _pass "T8: Lesson ohne expires_at → skip mit Warning, 0 Items"
else
  _fail "T8: Lesson ohne expires_at → skip mit Warning, 0 Items" \
    "rc=$rc count=$count8 stderr='$stderr8'"
fi

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '\033[32mAlle Tests grün.\033[0m\n'
  exit 0
else
  printf '\033[31m%d Test(s) fehlgeschlagen.\033[0m\n' "$FAILURES"
  exit 1
fi
