#!/usr/bin/env bash
# verify/cloud-heartbeat.sh — Sandbox tests for Cloud-Heartbeat (P3-12).
#
# Tests:
#   1. Normal-Ping: token set, mock-curl exit 0 → exit 0, last-heartbeat.json written
#   2. Token absent: no env + no token file → exit 0 (graceful skip)
#   3. curl-Fail: mock-curl exits 1 → ping script exits 0 (network failures non-fatal)
#   4. YAML syntax: cloud-heartbeat-watch.yml is valid YAML
#   5. setup-cloud-heartbeat.sh: generates valid token file with mode 0400
#
# Exit 0 if all tests pass.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PING_SH="${SCRIPTS_DIR}/cloud-heartbeat-ping.sh"
SETUP_SH="${SCRIPTS_DIR}/setup-cloud-heartbeat.sh"
WORKFLOW_YML="$(cd "${SCRIPTS_DIR}/../../.github/workflows" && pwd)/cloud-heartbeat-watch.yml"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
ERRORS=()

_pass() { printf '  [PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() {
  printf '  [FAIL] %s\n' "$1"
  ERRORS+=("$1")
  FAIL=$(( FAIL + 1 ))
}
_section() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------------------
# Sandbox
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
_cleanup() {
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
  rm -rf "$SANDBOX"
}
trap '_cleanup' EXIT

MOCK_BIN="${SANDBOX}/mock-bin"
mkdir -p "$MOCK_BIN"

# Fake REPO_ROOT so the script writes last-heartbeat.json into sandbox
FAKE_REPO="${SANDBOX}/repo"
mkdir -p "${FAKE_REPO}/.claude/overseer"

# Fake HOME so setup script doesn't touch real ~/.claude
FAKE_HOME="${SANDBOX}/home"
mkdir -p "${FAKE_HOME}/.claude"

# ---------------------------------------------------------------------------
# Helper: write a mock curl that exits with a given code
# ---------------------------------------------------------------------------
_mock_curl() {
  local exit_code="${1:-0}"
  cat > "${MOCK_BIN}/curl" <<STUB
#!/usr/bin/env bash
exit ${exit_code}
STUB
  chmod +x "${MOCK_BIN}/curl"
}

# ---------------------------------------------------------------------------
# Test 1: Normal-Ping — token in env, curl exits 0, json written
# ---------------------------------------------------------------------------
_section "Test 1: Normal-Ping (token set, curl ok)"

_mock_curl 0

HEARTBEAT_JSON="${FAKE_REPO}/.claude/overseer/last-heartbeat.json"
rm -f "$HEARTBEAT_JSON"

EXIT1=0
set +e
PATH="${MOCK_BIN}:${PATH}" \
  REPO_ROOT="$FAKE_REPO" \
  OVERSEER_HEARTBEAT_TOKEN="$(printf '%.0sa' {1..40})" \
  NTFY_TOPIC="claude-code-test" \
  bash "$PING_SH" 2>/dev/null
EXIT1=$?
set -e

if [ "$EXIT1" -eq 0 ]; then
  _pass "Normal-Ping: exit 0"
else
  _fail "Normal-Ping: expected exit 0, got ${EXIT1}"
fi

if [ -f "$HEARTBEAT_JSON" ]; then
  _pass "Normal-Ping: last-heartbeat.json written"
else
  _fail "Normal-Ping: last-heartbeat.json not found at ${HEARTBEAT_JSON}"
fi

# Validate JSON structure
if python3 -c "
import json, sys
d = json.load(open('${HEARTBEAT_JSON}'))
assert 'ts' in d
assert 'host' in d
assert 'token' in d
" 2>/dev/null; then
  _pass "Normal-Ping: last-heartbeat.json has ts+host+token fields"
else
  _fail "Normal-Ping: last-heartbeat.json invalid JSON or missing fields"
fi

# ---------------------------------------------------------------------------
# Test 2: Token absent — no env, no token file → graceful skip, exit 0
# ---------------------------------------------------------------------------
_section "Test 2: Token absent — graceful skip"

_mock_curl 0

EXIT2=0
set +e
PATH="${MOCK_BIN}:${PATH}" \
  REPO_ROOT="$FAKE_REPO" \
  HOME="$FAKE_HOME" \
  bash "$PING_SH" 2>/dev/null
EXIT2=$?
set -e

if [ "$EXIT2" -eq 0 ]; then
  _pass "Token absent: exit 0 (graceful skip)"
else
  _fail "Token absent: expected exit 0, got ${EXIT2}"
fi

# ---------------------------------------------------------------------------
# Test 3: curl-Fail — mock curl exits 1, ping should still exit 0
# ---------------------------------------------------------------------------
_section "Test 3: curl-Fail — network error is non-fatal"

_mock_curl 1

# Ensure heartbeat.json exists so we can test it's still updated
rm -f "$HEARTBEAT_JSON"

EXIT3=0
set +e
PATH="${MOCK_BIN}:${PATH}" \
  REPO_ROOT="$FAKE_REPO" \
  OVERSEER_HEARTBEAT_TOKEN="$(printf '%.0sa' {1..40})" \
  NTFY_TOPIC="claude-code-test" \
  bash "$PING_SH" 2>/dev/null
EXIT3=$?
set -e

if [ "$EXIT3" -eq 0 ]; then
  _pass "curl-Fail: exit 0 (non-fatal)"
else
  _fail "curl-Fail: expected exit 0 even on curl failure, got ${EXIT3}"
fi

# Local state should still be written even when ntfy push fails
if [ -f "$HEARTBEAT_JSON" ]; then
  _pass "curl-Fail: last-heartbeat.json still written despite curl failure"
else
  _fail "curl-Fail: last-heartbeat.json not written"
fi

# ---------------------------------------------------------------------------
# Test 4: YAML content checks — cloud-heartbeat-watch.yml exists and has
# the required structure (grep-based; avoids pyyaml dependency).
# ---------------------------------------------------------------------------
_section "Test 4: GitHub Actions YAML structure"

if [ -f "$WORKFLOW_YML" ]; then
  _pass "YAML file: cloud-heartbeat-watch.yml exists"
else
  _fail "YAML file: cloud-heartbeat-watch.yml not found at ${WORKFLOW_YML}"
fi

# schedule trigger (cron line)
if grep -q 'cron:' "$WORKFLOW_YML" 2>/dev/null; then
  _pass "YAML structure: schedule cron trigger present"
else
  _fail "YAML structure: no cron line found"
fi

# workflow_dispatch
if grep -q 'workflow_dispatch' "$WORKFLOW_YML" 2>/dev/null; then
  _pass "YAML structure: workflow_dispatch trigger present"
else
  _fail "YAML structure: workflow_dispatch missing"
fi

# NTFY_TOPIC secret reference
if grep -q 'NTFY_TOPIC' "$WORKFLOW_YML" 2>/dev/null; then
  _pass "YAML structure: NTFY_TOPIC secret reference present"
else
  _fail "YAML structure: NTFY_TOPIC not referenced"
fi

# OVERSEER_HEARTBEAT_TOKEN secret reference
if grep -q 'OVERSEER_HEARTBEAT_TOKEN' "$WORKFLOW_YML" 2>/dev/null; then
  _pass "YAML structure: OVERSEER_HEARTBEAT_TOKEN secret reference present"
else
  _fail "YAML structure: OVERSEER_HEARTBEAT_TOKEN not referenced"
fi

# ---------------------------------------------------------------------------
# Test 5: setup-cloud-heartbeat.sh — generates token file with mode 0400
# ---------------------------------------------------------------------------
_section "Test 5: setup-cloud-heartbeat.sh token generation"

FAKE_TOKEN_FILE="${FAKE_HOME}/.claude/inventory-overseer-heartbeat-token"
rm -f "$FAKE_TOKEN_FILE"

# Run setup script non-interactively (pipe 'y' for any overwrite prompts,
# but no existing file so it should not prompt)
EXIT5=0
set +e
HOME="$FAKE_HOME" \
  REPO_ROOT="$FAKE_REPO" \
  bash "$SETUP_SH" </dev/null >/dev/null 2>&1
EXIT5=$?
set -e

if [ "$EXIT5" -eq 0 ]; then
  _pass "setup-cloud-heartbeat: exits 0"
else
  _fail "setup-cloud-heartbeat: expected exit 0, got ${EXIT5}"
fi

if [ -f "$FAKE_TOKEN_FILE" ]; then
  _pass "setup-cloud-heartbeat: token file created"
else
  _fail "setup-cloud-heartbeat: token file not created at ${FAKE_TOKEN_FILE}"
fi

# Check mode 0400
if [ -f "$FAKE_TOKEN_FILE" ]; then
  PERMS="$(stat -c '%a' "$FAKE_TOKEN_FILE" 2>/dev/null || stat -f '%A' "$FAKE_TOKEN_FILE" 2>/dev/null || echo '???')"
  # Normalize: stat -f on macOS gives "400", stat -c on Linux gives "400"
  if [ "$PERMS" = "400" ]; then
    _pass "setup-cloud-heartbeat: token file mode is 0400"
  else
    _fail "setup-cloud-heartbeat: expected mode 0400, got ${PERMS}"
  fi

  # Check token length >= 32 chars
  TOKEN_LEN="$(wc -c < "$FAKE_TOKEN_FILE" | tr -d ' ')"
  if [ "$TOKEN_LEN" -ge 32 ]; then
    _pass "setup-cloud-heartbeat: token length >= 32 chars (got ${TOKEN_LEN})"
  else
    _fail "setup-cloud-heartbeat: token too short (${TOKEN_LEN} chars < 32)"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=============================\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed tests:\n'
  for e in "${ERRORS[@]}"; do
    printf '  - %s\n' "$e"
  done
  exit 1
fi

printf 'All tests passed.\n'
exit 0
