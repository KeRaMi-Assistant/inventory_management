#!/usr/bin/env bash
# verify/intake-queue-layout.sh — Prüft T01: Pending-Queue-Verzeichnis-Layout + Gitignore-Whitelist
# Aufruf: bash .claude/scripts/verify/intake-queue-layout.sh
# Exit 0 = alle Checks bestanden, 1 = mindestens ein Check fehlgeschlagen.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

pass=0
fail=0

_pass() { echo "  PASS: $1"; pass=$((pass + 1)); }
_fail() { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "=== T01 — Intake-Queue-Layout-Verify ==="
echo

# 1. Alle 6 Dirs existieren + .gitkeep vorhanden
echo "--- 1) Verzeichnisse + .gitkeep ---"
DIRS=(
  ".claude/stakeholder/pending-proposal"
  ".claude/stakeholder/pending-approval"
  ".claude/stakeholder/pending-approval/stale"
  ".claude/stakeholder/rejected"
  ".claude/intake-council"
  ".claude/intake-council/state"
)
for d in "${DIRS[@]}"; do
  full="$REPO_ROOT/$d"
  if [ -d "$full" ]; then
    _pass "dir exists: $d"
  else
    _fail "dir missing: $d"
  fi
  if [ -f "$full/.gitkeep" ]; then
    _pass ".gitkeep exists: $d/.gitkeep"
  else
    _fail ".gitkeep missing: $d/.gitkeep"
  fi
done

echo
echo "--- 2) .gitkeep-Files sind stageable (nicht gitignored) ---"
for d in "${DIRS[@]}"; do
  gk="$d/.gitkeep"
  if git -C "$REPO_ROOT" check-ignore -q "$gk" 2>/dev/null; then
    _fail ".gitkeep is gitignored (should NOT be): $gk"
  else
    _pass ".gitkeep not gitignored: $gk"
  fi
done

echo
echo "--- 3) *.md-Files in pending-proposal sind gitignored ---"
DUMMY="$REPO_ROOT/.claude/stakeholder/pending-proposal/dummy.md"
touch "$DUMMY"
if git -C "$REPO_ROOT" check-ignore -q "$DUMMY" 2>/dev/null; then
  _pass "pending-proposal/dummy.md is gitignored"
else
  _fail "pending-proposal/dummy.md is NOT gitignored (expected ignored)"
fi
rm -f "$DUMMY"

echo
echo "--- 4) *.md-Files in pending-approval + stale + rejected sind gitignored ---"
MD_PATHS=(
  ".claude/stakeholder/pending-approval/test.md"
  ".claude/stakeholder/pending-approval/stale/test.md"
  ".claude/stakeholder/rejected/test.md"
)
for f in "${MD_PATHS[@]}"; do
  abs="$REPO_ROOT/$f"
  touch "$abs"
  if git -C "$REPO_ROOT" check-ignore -q "$abs" 2>/dev/null; then
    _pass "gitignored: $f"
  else
    _fail "NOT gitignored: $f"
  fi
  rm -f "$abs"
done

echo
echo "--- 5) intake-council/state/*.json ist gitignored ---"
STATE_JSON="$REPO_ROOT/.claude/intake-council/state/reject-streak.json"
touch "$STATE_JSON"
if git -C "$REPO_ROOT" check-ignore -q "$STATE_JSON" 2>/dev/null; then
  _pass "intake-council/state/reject-streak.json is gitignored"
else
  _fail "intake-council/state/reject-streak.json is NOT gitignored"
fi
rm -f "$STATE_JSON"

echo
echo "--- 6) Whitelist enthält neue Pfade ---"
WHITELIST="$REPO_ROOT/.claude/whitelist.txt"
REQUIRED_PATHS=(
  ".claude/stakeholder/pending-proposal"
  ".claude/stakeholder/pending-approval"
  ".claude/stakeholder/rejected"
  ".claude/intake-council"
)
for p in "${REQUIRED_PATHS[@]}"; do
  if grep -qF "$p" "$WHITELIST"; then
    _pass "whitelist contains: $p"
  else
    _fail "whitelist MISSING: $p"
  fi
done

echo
echo "=== Ergebnis: $pass bestanden, $fail fehlgeschlagen ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
