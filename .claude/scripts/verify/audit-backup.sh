#!/usr/bin/env bash
# verify/audit-backup.sh — Sandbox-Tests für audit-backup.sh (P3-13)
#
# Setzt ein lokales bare-Git-Repo als Mock-Remote und läuft alle
# Acceptance-Szenarien durch. Exit 0 = alle Tests grüßen.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TARGET="${REPO_ROOT}/.claude/scripts/audit-backup.sh"

PASS=0
FAIL=0
_result() {
  local status="$1" name="$2" detail="${3:-}"
  if [ "$status" = "pass" ]; then
    printf '  [PASS] %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s%s\n' "$name" "${detail:+ — $detail}"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Setup: tmp dirs
# ---------------------------------------------------------------------------
TMPBASE="$(mktemp -d)"
trap 'chmod -R u+w "$TMPBASE" 2>/dev/null; chflags -R nouchg "$TMPBASE" 2>/dev/null; rm -rf "$TMPBASE" 2>/dev/null; true' EXIT

BARE_REMOTE="${TMPBASE}/backup.git"
CLONE_TARGET="${TMPBASE}/backup-clone"
MOCK_REPO="${TMPBASE}/mock-main-repo"
MOCK_AUDIT_DIR="${MOCK_REPO}/.claude/audit"

# Create fake project repo (so audit_record's git rev-parse works)
git init -q "$MOCK_REPO"
git -C "$MOCK_REPO" -c user.email="t@t.com" -c user.name="T" \
  commit -q --allow-empty -m "init"

mkdir -p "$MOCK_AUDIT_DIR"
printf '# Audit Test File\nentry: foo\n' > "${MOCK_AUDIT_DIR}/2026-05-10.md"

# Create a valid bare remote — seed with an initial commit so clones work.
git init -q --bare "$BARE_REMOTE"
INIT_CLONE="${TMPBASE}/init-clone"
git clone -q "$BARE_REMOTE" "$INIT_CLONE" 2>/dev/null || true
git -C "$INIT_CLONE" -c user.email="t@t.com" -c user.name="T" \
  commit -q --allow-empty -m "init"
git -C "$INIT_CLONE" push -q origin HEAD:refs/heads/main
git -C "$BARE_REMOTE" symbolic-ref HEAD refs/heads/main 2>/dev/null || true

printf '\n=== audit-backup verify suite ===\n\n'

# Helper: run target in mock environment
_run() {
  local extra_env="$1"; shift
  env \
    REPO_ROOT="$MOCK_REPO" \
    AUDIT_BACKUP_REMOTE="$BARE_REMOTE" \
    AUDIT_BACKUP_LOCAL="$CLONE_TARGET" \
    AUDIT_BACKUP_BRANCH="main" \
    CLAUDE_PROJECT_DIR="$MOCK_REPO" \
    GIT_AUTHOR_NAME="test" \
    GIT_AUTHOR_EMAIL="test@test.com" \
    $extra_env \
    bash "$TARGET" "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Test 1: AUDIT_BACKUP_REMOTE not set → exit 0 with warning
# ---------------------------------------------------------------------------
output=$(env AUDIT_BACKUP_REMOTE="" REPO_ROOT="$MOCK_REPO" \
  bash "$TARGET" 2>&1)
rc=$?
if [ $rc -eq 0 ] && echo "$output" | grep -qi "no backup target"; then
  _result pass "T1: AUDIT_BACKUP_REMOTE unset → exit 0 + warning"
else
  _result fail "T1: AUDIT_BACKUP_REMOTE unset → exit 0 + warning" \
    "rc=$rc output=$(echo "$output" | head -2)"
fi

# ---------------------------------------------------------------------------
# Test 2: Mock-Backup-Ziel offline → exit 1 + critical notify
# ---------------------------------------------------------------------------
rm -rf "$CLONE_TARGET"
output=$(env \
  REPO_ROOT="$MOCK_REPO" \
  AUDIT_BACKUP_REMOTE="/nonexistent/no-such-remote.git" \
  AUDIT_BACKUP_LOCAL="${TMPBASE}/clone-offline" \
  CLAUDE_PROJECT_DIR="$MOCK_REPO" \
  bash "$TARGET" 2>&1)
rc=$?
if [ $rc -eq 1 ]; then
  _result pass "T2: Offline remote → exit 1"
else
  _result fail "T2: Offline remote → exit 1" "rc=$rc"
fi
# Data-loss guard: main audit must still exist
if [ -f "${MOCK_AUDIT_DIR}/2026-05-10.md" ]; then
  _result pass "T2b: No data loss (audit file intact)"
else
  _result fail "T2b: No data loss (audit file intact)"
fi

# ---------------------------------------------------------------------------
# Test 3: Erfolgreicher Push — files landen im Mock-Remote
# ---------------------------------------------------------------------------
rm -rf "$CLONE_TARGET"
output=$(_run "" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
  _result pass "T3: Successful push → exit 0"
else
  _result fail "T3: Successful push → exit 0" "rc=$rc out=$(echo "$output" | tail -3)"
fi

# Verify files are in the remote
VERIFY_CLONE="${TMPBASE}/verify-clone"
git clone -q "$BARE_REMOTE" "$VERIFY_CLONE"
REPO_NAME="$(basename "$MOCK_REPO")"
if [ -f "${VERIFY_CLONE}/audit/${REPO_NAME}/2026-05-10.md" ]; then
  _result pass "T3b: Files present in remote after push"
else
  _result fail "T3b: Files present in remote after push"
fi
rm -rf "$VERIFY_CLONE"

# ---------------------------------------------------------------------------
# Test 4: Re-Run mit nichts Neuem → kein commit, exit 0
# Run once more so the previous audit_record side-effect is synced, then
# a third run with no new source changes should skip commit.
# ---------------------------------------------------------------------------
# Helper: run with rate-limit=0 (no audit_record side-effects in source)
_run_frozen() {
  env \
    REPO_ROOT="$MOCK_REPO" \
    AUDIT_BACKUP_REMOTE="$BARE_REMOTE" \
    AUDIT_BACKUP_LOCAL="$CLONE_TARGET" \
    AUDIT_BACKUP_BRANCH="main" \
    CLAUDE_PROJECT_DIR="$MOCK_REPO" \
    CLAUDE_AUDIT_MAX_PER_MINUTE=0 \
    GIT_AUTHOR_NAME="test" \
    GIT_AUTHOR_EMAIL="test@test.com" \
    bash "$TARGET" "$@" 2>&1
}

# Sync pass (frozen): backs up current source state without appending to it
_run_frozen >/dev/null 2>&1 || true

# Second sync pass to ensure absolutely in sync
_run_frozen >/dev/null 2>&1 || true

# Now source and backup are identical. Another frozen run must produce no new commit.
COMMITS_T4_BEFORE=$(git -C "$BARE_REMOTE" rev-list --count HEAD 2>/dev/null || echo 0)
output=$(_run_frozen 2>&1)
rc=$?
COMMITS_T4_AFTER=$(git -C "$BARE_REMOTE" rev-list --count HEAD 2>/dev/null || echo 0)
if [ $rc -eq 0 ] && [ "$COMMITS_T4_BEFORE" = "$COMMITS_T4_AFTER" ]; then
  _result pass "T4: Re-run unchanged → no commit, exit 0"
else
  _result fail "T4: Re-run unchanged → no commit, exit 0" \
    "rc=$rc commits_before=$COMMITS_T4_BEFORE after=$COMMITS_T4_AFTER"
fi

# ---------------------------------------------------------------------------
# Test 5: Re-Run mit neuem Audit-File → commit + push
# ---------------------------------------------------------------------------
printf '# Second audit file\n' > "${MOCK_AUDIT_DIR}/2026-05-11.md"
output=$(_run "" 2>&1)
rc=$?
VERIFY_CLONE2="${TMPBASE}/verify-clone2"
git clone -q "$BARE_REMOTE" "$VERIFY_CLONE2"
if [ $rc -eq 0 ] && [ -f "${VERIFY_CLONE2}/audit/${REPO_NAME}/2026-05-11.md" ]; then
  _result pass "T5: New audit file → commit + push"
else
  _result fail "T5: New audit file → commit + push" "rc=$rc"
fi
rm -rf "$VERIFY_CLONE2"

# ---------------------------------------------------------------------------
# Test 6: --dry-run → no push
# ---------------------------------------------------------------------------
BARE_REMOTE2="${TMPBASE}/backup2.git"
git init -q --bare "$BARE_REMOTE2"
INIT_CLONE2="${TMPBASE}/init-clone2"
git clone -q "$BARE_REMOTE2" "$INIT_CLONE2" 2>/dev/null || true
git -C "$INIT_CLONE2" -c user.email="t@t.com" -c user.name="T" \
  commit -q --allow-empty -m "init"
git -C "$INIT_CLONE2" push -q origin HEAD:refs/heads/main
git -C "$BARE_REMOTE2" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
CLONE_TARGET2="${TMPBASE}/backup-clone2"

# First do a real push so clone exists
env \
  REPO_ROOT="$MOCK_REPO" \
  AUDIT_BACKUP_REMOTE="$BARE_REMOTE2" \
  AUDIT_BACKUP_LOCAL="$CLONE_TARGET2" \
  AUDIT_BACKUP_BRANCH="main" \
  CLAUDE_PROJECT_DIR="$MOCK_REPO" \
  bash "$TARGET" >/dev/null 2>&1 || true

# Now add new file and do --dry-run
printf '# dry-run file\n' > "${MOCK_AUDIT_DIR}/2026-05-12.md"
COMMITS_BEFORE=$(git -C "$BARE_REMOTE2" rev-list --count HEAD 2>/dev/null || echo 0)

env \
  REPO_ROOT="$MOCK_REPO" \
  AUDIT_BACKUP_REMOTE="$BARE_REMOTE2" \
  AUDIT_BACKUP_LOCAL="$CLONE_TARGET2" \
  AUDIT_BACKUP_BRANCH="main" \
  CLAUDE_PROJECT_DIR="$MOCK_REPO" \
  bash "$TARGET" --dry-run >/dev/null 2>&1

COMMITS_AFTER=$(git -C "$BARE_REMOTE2" rev-list --count HEAD 2>/dev/null || echo 0)
if [ "$COMMITS_BEFORE" = "$COMMITS_AFTER" ]; then
  _result pass "T6: --dry-run → no push"
else
  _result fail "T6: --dry-run → no push" \
    "commits before=$COMMITS_BEFORE after=$COMMITS_AFTER"
fi
# Cleanup dry-run extra file
rm -f "${MOCK_AUDIT_DIR}/2026-05-12.md"

# ---------------------------------------------------------------------------
# Test 7: Plist template valid (xmllint)
# ---------------------------------------------------------------------------
PLIST="${REPO_ROOT}/.claude/audit-backup-launchagent.plist.template"
if command -v xmllint >/dev/null 2>&1; then
  if xmllint --noout "$PLIST" 2>/dev/null; then
    _result pass "T7: Plist XML valid"
  else
    _result fail "T7: Plist XML valid"
  fi
else
  # fallback: check it contains required keys
  if grep -q "com.inventory.audit-backup" "$PLIST" && \
     grep -q "StartCalendarInterval" "$PLIST" && \
     grep -q "Weekday" "$PLIST"; then
    _result pass "T7: Plist contains required keys (xmllint not available)"
  else
    _result fail "T7: Plist missing required keys"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n--- Results: %d passed, %d failed ---\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
