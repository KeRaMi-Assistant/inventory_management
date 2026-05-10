#!/usr/bin/env bash
# verify/analyzer-daemon.sh — Tests für analyzer.sh (P2-8)
#
# Alle Tests laufen in isolierten mktemp-Sandboxes.
# Mock-Module + Mock-cost-cap werden via PATH-Prepend injiziert.
# Exit 0 = alle Tests grün.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZER_SH="${SCRIPT_DIR}/../analyzer.sh"
INSTALL_SH="${SCRIPT_DIR}/../install-analyzer.sh"
ROOT_REAL="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ ! -f "$ANALYZER_SH" ]; then
  printf 'ERROR: analyzer.sh nicht gefunden: %s\n' "$ANALYZER_SH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '\033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; FAILURES=$(( FAILURES + 1 )); }

FAILURES=0
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# ---------------------------------------------------------------------------
# Sandbox factory
# ---------------------------------------------------------------------------
_new_sandbox() {
  local name="$1"
  local sb="${TMPDIR_BASE}/sandbox_${name}"

  # Minimal repo structure
  mkdir -p "$sb/.claude/overseer"
  mkdir -p "$sb/.claude/analyzer/state"
  mkdir -p "$sb/.claude/analyzer/modules"
  mkdir -p "$sb/.claude/audit"
  mkdir -p "$sb/.claude/scripts/lib"
  mkdir -p "$sb/.git"
  printf 'ref: refs/heads/main\n' > "$sb/.git/HEAD"

  # Stub audit.sh — no-op, avoids writing real audit files
  cat > "$sb/.claude/scripts/lib/audit.sh" <<'STUBEOF'
audit_record() { return 0; }
STUBEOF

  # Stub notify.sh — no-op
  cat > "$sb/.claude/scripts/notify.sh" <<'STUBEOF'
#!/usr/bin/env bash
exit 0
STUBEOF
  chmod +x "$sb/.claude/scripts/notify.sh"

  printf '%s' "$sb"
}

# Write a successful mock module (exit 0, prints items count)
_write_mock_module_ok() {
  local sb="$1" name="$2"
  cat > "$sb/.claude/analyzer/modules/${name}" <<STUBEOF
#!/usr/bin/env bash
printf '[%s] Items generated: 1\n' "${name%.*}"
exit 0
STUBEOF
  chmod +x "$sb/.claude/analyzer/modules/${name}"
}

# Write a failing mock module (exit 1)
_write_mock_module_fail() {
  local sb="$1" name="$2"
  cat > "$sb/.claude/analyzer/modules/${name}" <<STUBEOF
#!/usr/bin/env bash
printf '[%s] ERROR: mock failure\n' "${name%.*}" >&2
exit 1
STUBEOF
  chmod +x "$sb/.claude/analyzer/modules/${name}"
}

# Write a mock cost-cap.sh that always passes
_write_mock_cost_cap_ok() {
  local sb="$1"
  cat > "$sb/.claude/scripts/lib/cost-cap.sh" <<'STUBEOF'
cost_record() { return 0; }
cost_check_or_die() { return 0; }
cost_today_usd() { printf '0.00\n'; }
cost_week_usd() { printf '0.00\n'; }
STUBEOF
}

# Write a mock cost-cap.sh that trips the cap (exit 2)
_write_mock_cost_cap_hit() {
  local sb="$1"
  cat > "$sb/.claude/scripts/lib/cost-cap.sh" <<'STUBEOF'
cost_record() { return 0; }
cost_check_or_die() {
  printf '[cost-cap] HARD-STOP: mock cap hit\n' >&2
  return 2
}
cost_today_usd() { printf '99.00\n'; }
cost_week_usd() { printf '999.00\n'; }
STUBEOF
}

# Run analyzer.sh in sandbox, pointing at the real script but overriding ROOT via symlink trick
_run_analyzer() {
  local sb="$1"
  shift
  # We override the script's ROOT by setting CLAUDE_PROJECT_DIR and creating
  # a symlink so the script resolves to our sandbox.
  # The script uses: ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  # We can't easily override ROOT directly, but we can create a wrapper.
  local wrapper="${TMPDIR_BASE}/wrapper_$(basename "$sb").sh"
  cat > "$wrapper" <<WRAPEOF
#!/usr/bin/env bash
# Patch ROOT resolution: inject sandbox paths into the real analyzer.sh
# by setting the environment and sourcing it with overrides.
set -uo pipefail

# Override lib paths that analyzer.sh uses
export CLAUDE_PROJECT_DIR="$sb"

# We need to override the ROOT var in analyzer.sh — do this by sourcing
# after patching. Simplest approach: run the real script with env overrides.
ROOT_ORIG="$ROOT_REAL"
SB="$sb"

# Rewrite ROOT inside analyzer.sh by running through sed and executing.
TMP_SCRIPT="\$(mktemp)"
sed \\
  -e 's|ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"|ROOT="'"$sb"'"|g' \\
  "$ANALYZER_SH" > "\$TMP_SCRIPT"
chmod +x "\$TMP_SCRIPT"
bash "\$TMP_SCRIPT" "$@"
RC=\$?
rm -f "\$TMP_SCRIPT"
exit \$RC
WRAPEOF
  chmod +x "$wrapper"
  bash "$wrapper" "$@"
}

# ---------------------------------------------------------------------------
# T1 — --once happy path: all 3 modules called, audit trail
# ---------------------------------------------------------------------------
sb1="$(_new_sandbox T1)"
_write_mock_module_ok "$sb1" "scan-tech-debt.sh"
_write_mock_module_ok "$sb1" "scan-l10n-drift.sh"
_write_mock_module_ok "$sb1" "scan-failure-lessons-expiry.sh"
_write_mock_cost_cap_ok "$sb1"

# Track which modules were called via sentinel files
for m in scan-tech-debt scan-l10n-drift scan-failure-lessons-expiry; do
  cat > "$sb1/.claude/analyzer/modules/${m}.sh" <<STUBEOF
#!/usr/bin/env bash
touch "${sb1}/.claude/analyzer/state/called_${m}"
printf '[${m}] Items generated: 1\n'
exit 0
STUBEOF
  chmod +x "$sb1/.claude/analyzer/modules/${m}.sh"
done

rc=0
_run_analyzer "$sb1" --once >/dev/null 2>&1 || rc=$?

all_called=1
for m in scan-tech-debt scan-l10n-drift scan-failure-lessons-expiry; do
  [ -f "$sb1/.claude/analyzer/state/called_${m}" ] || all_called=0
done

if [ "$rc" -eq 0 ] && [ "$all_called" -eq 1 ]; then
  _pass "T1: --once happy — all 3 modules called, exit 0"
else
  _fail "T1: --once happy — all 3 modules called, exit 0" \
    "rc=$rc all_called=$all_called"
fi

# Check state file was written
if [ -f "$sb1/.claude/analyzer/state/analyzer-daemon.json" ]; then
  _pass "T1: state file written"
else
  _fail "T1: state file written" "missing $sb1/.claude/analyzer/state/analyzer-daemon.json"
fi

# ---------------------------------------------------------------------------
# T2 — PANIC marker: idle, no modules called
# ---------------------------------------------------------------------------
sb2="$(_new_sandbox T2)"
_write_mock_cost_cap_ok "$sb2"
touch "$sb2/.claude/overseer/PANIC"

called_flag="$sb2/.claude/analyzer/state/any_module_called"
for m in scan-tech-debt.sh scan-l10n-drift.sh scan-failure-lessons-expiry.sh; do
  cat > "$sb2/.claude/analyzer/modules/${m}" <<STUBEOF
#!/usr/bin/env bash
touch "$called_flag"
exit 0
STUBEOF
  chmod +x "$sb2/.claude/analyzer/modules/${m}"
done

rc=0
_run_analyzer "$sb2" --once >/dev/null 2>&1 || rc=$?

if [ "$rc" -eq 0 ] && [ ! -f "$called_flag" ]; then
  _pass "T2: PANIC marker → idle, no modules called"
else
  _fail "T2: PANIC marker → idle, no modules called" \
    "rc=$rc called=$([ -f "$called_flag" ] && echo yes || echo no)"
fi

# ---------------------------------------------------------------------------
# T3 — ANALYZER_PAUSE marker: idle
# ---------------------------------------------------------------------------
sb3="$(_new_sandbox T3)"
_write_mock_cost_cap_ok "$sb3"
touch "$sb3/.claude/overseer/ANALYZER_PAUSE"

called_flag3="$sb3/.claude/analyzer/state/any_module_called"
for m in scan-tech-debt.sh scan-l10n-drift.sh scan-failure-lessons-expiry.sh; do
  cat > "$sb3/.claude/analyzer/modules/${m}" <<STUBEOF
#!/usr/bin/env bash
touch "$called_flag3"
exit 0
STUBEOF
  chmod +x "$sb3/.claude/analyzer/modules/${m}"
done

rc=0
_run_analyzer "$sb3" --once >/dev/null 2>&1 || rc=$?

if [ "$rc" -eq 0 ] && [ ! -f "$called_flag3" ]; then
  _pass "T3: ANALYZER_PAUSE → idle, no modules called"
else
  _fail "T3: ANALYZER_PAUSE → idle, no modules called" \
    "rc=$rc called=$([ -f "$called_flag3" ] && echo yes || echo no)"
fi

# ---------------------------------------------------------------------------
# T4 — Module-Fail: continue to next module, not blocked
# ---------------------------------------------------------------------------
sb4="$(_new_sandbox T4)"
_write_mock_cost_cap_ok "$sb4"

# Module 1 fails, modules 2+3 succeed
cat > "$sb4/.claude/analyzer/modules/scan-tech-debt.sh" <<STUBEOF
#!/usr/bin/env bash
exit 1
STUBEOF
chmod +x "$sb4/.claude/analyzer/modules/scan-tech-debt.sh"

for m in scan-l10n-drift scan-failure-lessons-expiry; do
  cat > "$sb4/.claude/analyzer/modules/${m}.sh" <<STUBEOF
#!/usr/bin/env bash
touch "${sb4}/.claude/analyzer/state/called_${m}"
exit 0
STUBEOF
  chmod +x "$sb4/.claude/analyzer/modules/${m}.sh"
done

rc=0
_run_analyzer "$sb4" --once >/dev/null 2>&1 || rc=$?

l10n_called=0
lessons_called=0
[ -f "$sb4/.claude/analyzer/state/called_scan-l10n-drift" ] && l10n_called=1
[ -f "$sb4/.claude/analyzer/state/called_scan-failure-lessons-expiry" ] && lessons_called=1

if [ "$rc" -eq 0 ] && [ "$l10n_called" -eq 1 ] && [ "$lessons_called" -eq 1 ]; then
  _pass "T4: module-fail → continues to next modules"
else
  _fail "T4: module-fail → continues to next modules" \
    "rc=$rc l10n=$l10n_called lessons=$lessons_called"
fi

# ---------------------------------------------------------------------------
# T5 — Cost-Cap hit: idle (cost_check_or_die exits 2)
# ---------------------------------------------------------------------------
sb5="$(_new_sandbox T5)"
_write_mock_cost_cap_hit "$sb5"

called_flag5="$sb5/.claude/analyzer/state/any_module_called"
for m in scan-tech-debt.sh scan-l10n-drift.sh scan-failure-lessons-expiry.sh; do
  cat > "$sb5/.claude/analyzer/modules/${m}" <<STUBEOF
#!/usr/bin/env bash
touch "$called_flag5"
exit 0
STUBEOF
  chmod +x "$sb5/.claude/analyzer/modules/${m}"
done

rc=0
_run_analyzer "$sb5" --once >/dev/null 2>&1 || rc=$?

if [ "$rc" -eq 0 ] && [ ! -f "$called_flag5" ]; then
  _pass "T5: cost-cap hit → idle, no modules called"
else
  _fail "T5: cost-cap hit → idle, no modules called" \
    "rc=$rc called=$([ -f "$called_flag5" ] && echo yes || echo no)"
fi

# ---------------------------------------------------------------------------
# T6 — --status: prints state
# ---------------------------------------------------------------------------
sb6="$(_new_sandbox T6)"
_write_mock_cost_cap_ok "$sb6"
mkdir -p "$sb6/.claude/analyzer/state"
printf '{"last_run":"2026-05-10T10:00:00Z","last_run_status":"ok","runs_total":3}\n' \
  > "$sb6/.claude/analyzer/state/analyzer-daemon.json"

output=""
rc=0
output="$(_run_analyzer "$sb6" --status 2>&1)" || rc=$?

if printf '%s' "$output" | grep -q "last_run" && \
   printf '%s' "$output" | grep -q "2026-05-10"; then
  _pass "T6: --status prints state with last_run"
else
  _fail "T6: --status prints state with last_run" \
    "rc=$rc output=$(printf '%s' "$output" | head -3)"
fi

# ---------------------------------------------------------------------------
# T7 — LaunchAgent plist: valid XML (plutil -lint)
# ---------------------------------------------------------------------------
PLIST_TEMPLATE="${ROOT_REAL}/.claude/analyzer-launchagent.plist.template"
if [ ! -f "$PLIST_TEMPLATE" ]; then
  _fail "T7: plist template exists" "not found: $PLIST_TEMPLATE"
else
  # Materialize template for validation
  tmp_plist="$(mktemp).plist"
  sed \
    -e "s|__REPO_ROOT__|/tmp/test-repo|g" \
    -e "s|__HOME__|/tmp/testhome|g" \
    "$PLIST_TEMPLATE" > "$tmp_plist"

  if plutil -lint "$tmp_plist" >/dev/null 2>&1; then
    _pass "T7: plist template → valid XML (plutil -lint)"
  else
    _fail "T7: plist template → valid XML (plutil -lint)" \
      "$(plutil -lint "$tmp_plist" 2>&1 | head -3)"
  fi
  rm -f "$tmp_plist"

  # Check required keys
  if grep -q "com.inventory.analyzer" "$PLIST_TEMPLATE" && \
     grep -q "StartInterval" "$PLIST_TEMPLATE" && \
     grep -q "RunAtLoad" "$PLIST_TEMPLATE" && \
     grep -q "ThrottleInterval" "$PLIST_TEMPLATE" && \
     grep -q "analyzer.sh" "$PLIST_TEMPLATE" && \
     grep -q "\-\-once" "$PLIST_TEMPLATE"; then
    _pass "T7: plist contains required keys (Label, StartInterval, RunAtLoad, ThrottleInterval, --once)"
  else
    _fail "T7: plist contains required keys" \
      "Missing one of: Label, StartInterval, RunAtLoad, ThrottleInterval, --once arg"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '\033[32mAll tests passed.\033[0m\n'
  exit 0
else
  printf '\033[31m%d test(s) FAILED.\033[0m\n' "$FAILURES"
  exit 1
fi
