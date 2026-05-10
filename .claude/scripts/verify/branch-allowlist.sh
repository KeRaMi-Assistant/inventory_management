#!/usr/bin/env bash
# verify/branch-allowlist.sh — Tests für den Branch-Allowlist-Check in guard-bash.sh (P3-8)
# Aufruf: bash .claude/scripts/verify/branch-allowlist.sh
# Exit 0 = alle Tests bestanden, 1 = mindestens ein Test fehlgeschlagen.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/../guard-bash.sh"

pass=0
fail=0

# Helper: ruft guard-bash.sh mit einem simulierten Bash-Befehl auf.
# Gibt exit-code des Guards zurück.
_run_guard() {
  local cmd="$1"
  local json
  json="$(printf '{"tool_input":{"command":"%s"}}' "$cmd")"
  echo "$json" | bash "$GUARD" >/dev/null 2>&1
  echo $?
}

_assert_allowed() {
  local label="$1"
  local cmd="$2"
  local rc
  rc="$(_run_guard "$cmd")"
  if [ "$rc" -eq 0 ]; then
    echo "  PASS (allowed): $label"
    pass=$((pass + 1))
  else
    echo "  FAIL (should be allowed but was blocked): $label  [rc=$rc]"
    fail=$((fail + 1))
  fi
}

_assert_blocked() {
  local label="$1"
  local cmd="$2"
  local rc
  rc="$(_run_guard "$cmd")"
  if [ "$rc" -ne 0 ]; then
    echo "  PASS (blocked): $label"
    pass=$((pass + 1))
  else
    echo "  FAIL (should be blocked but was allowed): $label"
    fail=$((fail + 1))
  fi
}

echo "=== Branch-Allowlist Tests ==="
echo

echo "--- Erlaubte Patterns ---"
_assert_allowed "feature/abc"                             "git checkout -b feature/abc"
_assert_allowed "fix/issue-123"                           "git checkout -b fix/issue-123"
_assert_allowed "chore/cleanup"                           "git checkout -b chore/cleanup"
_assert_allowed "feature/a-very-long-40-char-name (genau 40)" "git checkout -b feature/a-very-long-name-exactly-forty-xx"
_assert_allowed "git checkout main (kein -b)"             "git checkout main"
_assert_allowed "git switch -c feature/my-feature"        "git switch -c feature/my-feature"
_assert_allowed "git push -u origin feature/my-branch"    "git push -u origin feature/my-branch"

echo
echo "--- Verbotene Patterns ---"
_assert_blocked "weird_branch (kein prefix)"              "git checkout -b weird_branch"
_assert_blocked "BadCase (Großbuchstaben)"                "git checkout -b BadCase"
_assert_blocked "feature/path/nested (Slashes nach prefix)" "git checkout -b feature/path/nested"
_assert_blocked "feature/x-too-long (über 40 chars)"     "git checkout -b feature/x-y-z-this-is-over-forty-characters-toolong"
_assert_blocked "git push -u origin random-branch"        "git push -u origin random-branch"
_assert_blocked "git switch -c bug/old-style (bug/ nicht in Allowlist)" "git switch -c bug/old-style"

echo
echo "--- main/master/HEAD ausgenommen ---"
_assert_allowed "git push -u origin main"                 "git push -u origin main"
_assert_allowed "git push -u origin master"               "git push -u origin master"

echo
echo "=== Ergebnis: $pass bestanden, $fail fehlgeschlagen ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
