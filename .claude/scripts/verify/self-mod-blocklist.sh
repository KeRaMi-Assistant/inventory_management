#!/usr/bin/env bash
# Verify-Skript für P0-0 Self-Mod-Blocklist.
# Testet:
#   1. _is_self_mod_blocked auf Beispiel-Pfaden.
#   2. Bash-Guard (HEADLESS_MODE=1) blockt rm/sed -i/heredoc auf Blocklist.
#   3. Bash-Guard ohne HEADLESS_MODE lässt durch.
#   4. User-Session-Marker bypasst.
#   5. Edit-Hook (guard-edit.sh) blockt Edit auf Blocklist-Pfad.
#   6. Pre-push Hook abort bei HEADLESS_MODE + Blocklist-Diff (Mock).
#   7. Integrity-Check: PANIC bei Drift ohne Marker; Akzeptanz mit Marker.
#
# Exit 0 = alle Tests grün.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LIB="$ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
PASS=0
FAIL=0

ok()   { echo "  PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL+1)); }

# Sandbox: arbeite mit Mock-Repo, NICHT auf echtem Repo
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Mini-Repo aufbauen, das Lib + Scripts spiegelt
mkdir -p "$SANDBOX/.claude/scripts/lib"
mkdir -p "$SANDBOX/.claude/scripts/verify"
mkdir -p "$SANDBOX/.claude/agents"
mkdir -p "$SANDBOX/.claude/git-hooks"
mkdir -p "$SANDBOX/.claude/integrity"
mkdir -p "$SANDBOX/.claude/audit"
cp "$LIB" "$SANDBOX/.claude/scripts/lib/self-mod-blocklist.sh"
cp "$ROOT/.claude/scripts/guard-bash.sh" "$SANDBOX/.claude/scripts/guard-bash.sh"
cp "$ROOT/.claude/scripts/guard-edit.sh" "$SANDBOX/.claude/scripts/guard-edit.sh"
cp "$ROOT/.claude/scripts/integrity-check.sh" "$SANDBOX/.claude/scripts/integrity-check.sh"
cp "$ROOT/.claude/scripts/integrity-manifest-build.sh" "$SANDBOX/.claude/scripts/integrity-manifest-build.sh"
cp "$ROOT/.claude/git-hooks/pre-push" "$SANDBOX/.claude/git-hooks/pre-push"
# Stub-Files, die in Blocklist sind
echo "stub" > "$SANDBOX/.claude/scripts/auto-commit.sh"
echo "stub" > "$SANDBOX/.claude/scripts/notify.sh"
echo "stub" > "$SANDBOX/.claude/agents/disput-proponent.md"
echo "stub" > "$SANDBOX/CLAUDE.md"
mkdir -p "$SANDBOX/.claude/scripts/lib"
echo "stub" > "$SANDBOX/.claude/scripts/lib/cost-cap.sh"
chmod +x "$SANDBOX/.claude/scripts/"*.sh
chmod +x "$SANDBOX/.claude/git-hooks/pre-push"

# Init git in sandbox
git -C "$SANDBOX" init -q
git -C "$SANDBOX" config user.email t@t
git -C "$SANDBOX" config user.name t
git -C "$SANDBOX" add -A
git -C "$SANDBOX" commit -q -m init >/dev/null 2>&1 || true

cd "$SANDBOX"
export SELF_MOD_REPO_ROOT="$SANDBOX"
# shellcheck disable=SC1090
. "$SANDBOX/.claude/scripts/lib/self-mod-blocklist.sh"

echo "[1] _is_self_mod_blocked path matching"
if _is_self_mod_blocked "$SANDBOX/.claude/scripts/auto-commit.sh"; then
  ok "auto-commit.sh detected"
else
  fail "auto-commit.sh NOT detected"
fi
if _is_self_mod_blocked "$SANDBOX/.claude/scripts/lib/cost-cap.sh"; then
  ok "lib/cost-cap.sh detected"
else
  fail "lib/cost-cap.sh NOT detected"
fi
if _is_self_mod_blocked "$SANDBOX/lib/screens/foo.dart"; then
  fail "false-positive on lib/screens/foo.dart"
else
  ok "lib/screens/foo.dart correctly NOT blocked"
fi
# Path traversal guard
if _is_self_mod_blocked "$SANDBOX/.claude/scripts/foo/../auto-commit.sh"; then
  ok "path-traversal canonicalized"
else
  fail "path-traversal NOT canonicalized"
fi

echo "[2] Bash-Guard with HEADLESS_MODE=1 blocks self-mods"
HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" \
  bash -c '
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "echo x >> .claude/scripts/auto-commit.sh"
  '
rc=$?
if [ "$rc" -eq 2 ]; then ok "redirect blocked"; else fail "redirect NOT blocked (rc=$rc)"; fi

HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" \
  bash -c '
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "sed -i.bak s/foo/bar/ .claude/scripts/lib/cost-cap.sh"
  '
rc=$?
if [ "$rc" -eq 2 ]; then ok "sed -i blocked"; else fail "sed -i NOT blocked (rc=$rc)"; fi

HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" \
  bash -c '
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "rm .claude/agents/disput-proponent.md"
  '
rc=$?
if [ "$rc" -eq 2 ]; then ok "rm blocked"; else fail "rm NOT blocked (rc=$rc)"; fi

HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" \
  bash -c '
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "cat .claude/scripts/auto-commit.sh"
  '
rc=$?
if [ "$rc" -eq 0 ]; then ok "cat (read-only) NOT blocked"; else fail "cat falsely blocked (rc=$rc)"; fi

echo "[3] Bash-Guard without HEADLESS_MODE allows self-mods"
SELF_MOD_REPO_ROOT="$SANDBOX" \
  bash -c '
    unset HEADLESS_MODE OVERSEER_WORKER_PID
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "echo x >> .claude/scripts/auto-commit.sh"
  '
rc=$?
if [ "$rc" -eq 0 ]; then ok "no HEADLESS_MODE allows mod"; else fail "blocked despite no HEADLESS_MODE (rc=$rc)"; fi

echo "[4] User-session marker — signed only"

# Use isolated secret-file in sandbox (don't touch $HOME)
export CLAUDE_SESSION_SECRET_FILE="$SANDBOX/.session-secret"

# 4a) Empty file (worker `touch`) → guards STAY active
touch "$SANDBOX/.claude/.user-session-active"
HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash -c '
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "echo x >> .claude/scripts/auto-commit.sh"
  '
rc=$?
if [ "$rc" -eq 2 ]; then ok "empty marker does NOT bypass (worker-touch attack)"; else fail "empty marker incorrectly bypassed guard (rc=$rc)"; fi
rm -f "$SANDBOX/.claude/.user-session-active"

# 4b) Bogus hash content → guards STAY active
printf 'deadbeef\n' > "$SANDBOX/.claude/.user-session-active"
HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash -c '
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "echo x >> .claude/scripts/auto-commit.sh"
  '
rc=$?
if [ "$rc" -eq 2 ]; then ok "bogus hash does NOT bypass"; else fail "bogus hash bypassed guard (rc=$rc)"; fi
rm -f "$SANDBOX/.claude/.user-session-active"

# 4c) Run session-start.sh (with secret access) → guards inactive
cp "$ROOT/.claude/scripts/session-start.sh" "$SANDBOX/.claude/scripts/session-start.sh"
chmod +x "$SANDBOX/.claude/scripts/session-start.sh"
CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash "$SANDBOX/.claude/scripts/session-start.sh" >/dev/null 2>&1 || true
HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash -c '
    . "$SELF_MOD_REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
    _guard_bash_self_mod "echo x >> .claude/scripts/auto-commit.sh"
  '
rc=$?
if [ "$rc" -eq 0 ]; then ok "valid signed marker DOES bypass"; else fail "valid signed marker did not bypass (rc=$rc)"; fi
rm -f "$SANDBOX/.claude/.user-session-active"

echo "[5] guard-edit.sh blocks Edit on blocklist path"
input='{"tool_input":{"file_path":"'"$SANDBOX"'/.claude/scripts/auto-commit.sh"}}'
out=$(echo "$input" | HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" \
  bash "$SANDBOX/.claude/scripts/guard-edit.sh" 2>&1)
rc=$?
if [ "$rc" -eq 2 ]; then ok "guard-edit blocked: $out"; else fail "guard-edit did not block (rc=$rc)"; fi

echo "[6] Pre-push hook (mock-range simulation)"
# Create a commit that touches a blocklist file
cd "$SANDBOX"
echo "# tampered" >> .claude/scripts/auto-commit.sh
git add .claude/scripts/auto-commit.sh
git commit -q -m "tamper" >/dev/null
local_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse HEAD~1)"
input="refs/heads/main $local_sha refs/heads/main $remote_sha"
out=$(printf '%s\n' "$input" | HEADLESS_MODE=1 bash "$SANDBOX/.claude/git-hooks/pre-push" 2>&1)
rc=$?
if [ "$rc" -eq 1 ]; then ok "pre-push aborts under HEADLESS_MODE"; else fail "pre-push did not abort (rc=$rc, out=$out)"; fi

# Without HEADLESS_MODE: warns but exits 0
out=$(printf '%s\n' "$input" | bash "$SANDBOX/.claude/git-hooks/pre-push" 2>&1 || true)
rc=$?
if [ "$rc" -eq 0 ]; then ok "pre-push warns-only without HEADLESS_MODE"; else fail "pre-push aborted unexpectedly (rc=$rc)"; fi

echo "[7] Integrity-check (signed manifest + marker)"
# Ensure secret-file exists (manifest-build needs it for signing)
CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash "$SANDBOX/.claude/scripts/session-start.sh" >/dev/null 2>&1 || true
# Build initial manifest (run as USER, no HEADLESS → auth-gate not triggered)
CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash "$SANDBOX/.claude/scripts/integrity-manifest-build.sh" >/dev/null
rm -f "$SANDBOX/.claude/.user-session-active"
# Drift: tamper file, no marker → expect PANIC (exit 3)
echo "drift" >> "$SANDBOX/.claude/scripts/auto-commit.sh"
out=$(CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" bash "$SANDBOX/.claude/scripts/integrity-check.sh" 2>&1); rc=$?
if [ "$rc" -eq 3 ] && [ -f "$SANDBOX/.claude/overseer/PANIC" ]; then
  ok "integrity-check PANIC on drift"
else
  fail "integrity-check did NOT PANIC (rc=$rc, out=$out)"
fi

# With valid signed marker: should accept and rebuild manifest
rm -f "$SANDBOX/.claude/overseer/PANIC"
CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash "$SANDBOX/.claude/scripts/session-start.sh" >/dev/null 2>&1 || true
out=$(CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" bash "$SANDBOX/.claude/scripts/integrity-check.sh" 2>&1 || true)
rc=$?
out2=$(CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" bash "$SANDBOX/.claude/scripts/integrity-check.sh" 2>&1 || true)
rc2=$?
if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ]; then
  ok "integrity-check accepts under valid signed session"
else
  fail "signed session bypass failed (rc=$rc rc2=$rc2 out=$out)"
fi

echo "[8] integrity-manifest-build refuses worker rebuild"
rm -f "$SANDBOX/.claude/.user-session-active"
out=$(HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash "$SANDBOX/.claude/scripts/integrity-manifest-build.sh" 2>&1)
rc=$?
if [ "$rc" -eq 3 ]; then
  ok "manifest-build refused under HEADLESS_MODE without marker"
else
  fail "manifest-build NOT refused (rc=$rc, out=$out)"
fi

# With valid signed marker, even under HEADLESS_MODE, build should succeed
CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash "$SANDBOX/.claude/scripts/session-start.sh" >/dev/null 2>&1 || true
out=$(HEADLESS_MODE=1 SELF_MOD_REPO_ROOT="$SANDBOX" CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" \
  bash "$SANDBOX/.claude/scripts/integrity-manifest-build.sh" 2>&1)
rc=$?
if [ "$rc" -eq 0 ]; then
  ok "manifest-build allowed under HEADLESS_MODE with valid marker"
else
  fail "manifest-build incorrectly blocked with valid marker (rc=$rc, out=$out)"
fi

echo "[9] Manifest signature check"
# Tamper the signature line, run integrity-check → PANIC even if hashes match
rm -f "$SANDBOX/.claude/.user-session-active" "$SANDBOX/.claude/overseer/PANIC"
manifest="$SANDBOX/.claude/integrity/manifest.sha256"
# Replace signature with a bogus value
python3 -c "
import re
with open('$manifest','r') as f: c=f.read()
c2 = re.sub(r'# signature:.*', '# signature: 0000000000000000000000000000000000000000000000000000000000000000', c)
with open('$manifest','w') as f: f.write(c2)
"
out=$(CLAUDE_SESSION_SECRET_FILE="$CLAUDE_SESSION_SECRET_FILE" bash "$SANDBOX/.claude/scripts/integrity-check.sh" 2>&1)
rc=$?
if [ "$rc" -eq 3 ]; then
  ok "integrity-check PANIC on signature mismatch"
else
  fail "integrity-check accepted bogus signature (rc=$rc, out=$out)"
fi

echo
echo "Summary: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
