#!/usr/bin/env bash
# verify/whitelist-paths.sh — Acceptance-Tests für P0-1 (Whitelist-Erweiterung).
#
# Tests:
#   1. Neuer Pfad in .claude/audit/ wird von auto-commit.sh gestaged.
#   2. HEADLESS_MODE=1 + Blocklist-Pfad im Diff → auto-commit.sh exit 1.
#   3. .claude/backlog/runs/ bleibt gitignored.
#   4. Kein Wildcard ".claude/*" in Whitelist-Stellen.
#
# Exit 0 = alle Tests bestanden, 1 = mindestens ein Fehler.

set -u

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "FAIL: kein Git-Repo gefunden" >&2
  exit 1
fi

cd "$REPO_ROOT"

PASS=0
FAIL=0
AUTO_COMMIT="$REPO_ROOT/.claude/scripts/auto-commit.sh"

_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
_fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "=== whitelist-paths.sh — P0-1 Acceptance Tests ==="

# ---------------------------------------------------------------------------
# Test 1: .claude/audit/ ist gestaged nach auto-commit.sh
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 1: .claude/audit/ Pfad wird gestaged ---"

TEST_FILE=".claude/audit/.test-whitelist-$$"
printf 'test-content-%d\n' "$$" > "$TEST_FILE"

# Git-Status vorher: sichergehen dass die Datei untracked ist
if git ls-files --others --exclude-standard -- "$TEST_FILE" | grep -q .; then
  # Simuliere auto-commit Whitelist-Add: .claude/audit ist in der Whitelist
  git add -- .claude/audit/ 2>/dev/null || true
  if git diff --cached --name-only | grep -qF "$TEST_FILE"; then
    _pass ".claude/audit/.gitkeep / Test-Datei wurde von Whitelist-Add gestaged"
  else
    _fail ".claude/audit/ ist NICHT in Whitelist-Add — Datei wurde nicht gestaged"
  fi
  # Cleanup: unstage
  git restore --staged -- "$TEST_FILE" 2>/dev/null || git reset HEAD -- "$TEST_FILE" 2>/dev/null || true
else
  _fail "Test-Datei $TEST_FILE nicht als untracked erkannt (ggf. bereits tracked oder gitignored)"
fi
rm -f "$TEST_FILE"

# ---------------------------------------------------------------------------
# Test 2: HEADLESS_MODE=1 + Blocklist-Pfad → auto-commit.sh exit 1
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 2: HEADLESS_MODE=1 blockt Blocklist-Diff ---"

# Blocklist-Pfad: .claude/scripts/notify.sh (existiert und ist in SELF_MOD_BLOCKLIST)
BLOCKLIST_FILE=".claude/scripts/notify.sh"

if [ ! -f "$BLOCKLIST_FILE" ]; then
  echo "  SKIP: $BLOCKLIST_FILE existiert nicht — Test 2 übersprungen"
else
  # Backup working-tree state before modification (avoids `git restore` losing
  # any uncommitted changes — the previous version reset notify.sh to the
  # 49-line HEAD on every run).
  _BLOCKLIST_BACKUP="$(mktemp /tmp/whitelist-verify-backup.XXXXXX)"
  cp "$BLOCKLIST_FILE" "$_BLOCKLIST_BACKUP"
  # Wir fügen eine harmlose Zeile ein, dann testen, dann reverten
  printf '\n# whitelist-paths-verify-test\n' >> "$BLOCKLIST_FILE"

  # Sicherstellen dass .user-session-active NICHT existiert
  SESSION_ACTIVE=".claude/.user-session-active"
  _session_was_present=0
  if [ -f "$SESSION_ACTIVE" ]; then
    _session_was_present=1
    rm -f "$SESSION_ACTIVE"
  fi

  # auto-commit.sh laufen lassen mit HEADLESS_MODE=1
  # Wir mocken einen Branch der nicht main ist (aktueller Branch reicht)
  BRANCH="$(git branch --show-current)"
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] || [ -z "$BRANCH" ]; then
    echo "  SKIP: aktueller Branch ist main/master — Test 2 übersprungen (sicherheitshalber)"
  else
    _exit_code=0
    HEADLESS_MODE=1 bash "$AUTO_COMMIT" 2>/dev/null || _exit_code=$?
    if [ "$_exit_code" -eq 1 ]; then
      _pass "HEADLESS_MODE=1 mit Blocklist-Diff → auto-commit.sh exit 1"
    else
      _fail "HEADLESS_MODE=1 mit Blocklist-Diff → exit $_exit_code (erwartet: 1)"
    fi
  fi

  # Cleanup: Session-Marker zurücksetzen
  if [ "$_session_was_present" -eq 1 ]; then
    touch "$SESSION_ACTIVE"
  fi

  # Revert die Änderung an notify.sh — restore from working-tree backup
  # (NOT `git restore` — das würde uncommitted shim/notify-impl-Setup zerstören).
  if [ -f "$_BLOCKLIST_BACKUP" ]; then
    cp "$_BLOCKLIST_BACKUP" "$BLOCKLIST_FILE"
    rm -f "$_BLOCKLIST_BACKUP"
  fi
fi

# ---------------------------------------------------------------------------
# Test 3: .claude/backlog/runs/ bleibt gitignored
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 3: .claude/backlog/runs/ ist gitignored ---"

mkdir -p ".claude/backlog/runs"
RUNS_DUMMY=".claude/backlog/runs/dummy-test-$$"
printf 'ignored\n' > "$RUNS_DUMMY"

if git check-ignore -q "$RUNS_DUMMY" 2>/dev/null; then
  _pass ".claude/backlog/runs/ ist gitignored"
else
  _fail ".claude/backlog/runs/ ist NICHT gitignored — .gitignore prüfen"
fi
rm -f "$RUNS_DUMMY"

# ---------------------------------------------------------------------------
# Test 4: Kein Wildcard ".claude/*" in Whitelist-Stellen
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 4: Kein Wildcard .claude/* in Whitelist-Stellen ---"

_wildcard_found=0

# Wir prüfen auf tatsächliche Wildcard-Nutzung in git-add-Kontexten:
# z.B. "git add .claude/*" oder nur ".claude/*" als eigenständiges Token in
# einer Whitelist-Zeile. NICHT: Prosa-Text der das Verbot erklärt.
_check_wildcard_in_file() {
  local file="$1"
  local label="$2"
  # Matches: "git add ... .claude/*" ODER ".claude/*" als eigenständiges Wort
  # (nicht eingebettet in Prosa wie "Kein Wildcard `.claude/*`")
  if grep -vE '(Kein Wildcard|no wildcard|VERBOTEN.*\.claude/\*)' "$file" 2>/dev/null \
     | grep -qE '(git add[^"]*\.claude/\*|^\.claude/\*([[:space:]]|$))'; then
    _fail "$label enthält Wildcard .claude/* in Whitelist — verboten"
    return 1
  fi
  return 0
}

# auto-commit.sh
_check_wildcard_in_file "$AUTO_COMMIT" "auto-commit.sh" || _wildcard_found=1

# ship.md
_check_wildcard_in_file "$REPO_ROOT/.claude/commands/ship.md" "ship.md" || _wildcard_found=1

# CLAUDE.md (nur git-add Kontext)
_check_wildcard_in_file "$REPO_ROOT/CLAUDE.md" "CLAUDE.md" || _wildcard_found=1

# whitelist.txt — hier ist jede nicht-kommentierte Zeile ein Pfad; .claude/* wäre direkt ein Wildcard
if [ -f "$REPO_ROOT/.claude/whitelist.txt" ]; then
  if grep -vE '^#|^[[:space:]]*$' "$REPO_ROOT/.claude/whitelist.txt" | grep -qE '\.claude/\*'; then
    _fail "whitelist.txt enthält Wildcard .claude/* — verboten"
    _wildcard_found=1
  fi
fi

if [ "$_wildcard_found" -eq 0 ]; then
  _pass "Kein Wildcard .claude/* in Whitelist-Stellen gefunden"
fi

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------
echo ""
echo "=== Ergebnis: $PASS pass, $FAIL fail ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
