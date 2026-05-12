#!/usr/bin/env bash
# verify/intake-slug-lib.sh — Unit tests for .claude/scripts/lib/slug.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/slug.sh
source "${SCRIPT_DIR}/../lib/slug.sh"

PASS=0
FAIL=0

_assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
    (( PASS++ )) || true
  else
    echo "  FAIL: $desc"
    echo "        expected: '$expected'"
    echo "        actual:   '$actual'"
    (( FAIL++ )) || true
  fi
}

_assert_exit() {
  local desc="$1" expected_exit="$2"
  shift 2
  local actual_exit=0
  "$@" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" == "$expected_exit" ]]; then
    echo "  PASS: $desc (exit $actual_exit)"
    (( PASS++ )) || true
  else
    echo "  FAIL: $desc"
    echo "        expected exit: $expected_exit"
    echo "        actual exit:   $actual_exit"
    (( FAIL++ )) || true
  fi
}

echo "=== make_slug tests ==="

_assert_eq 'normal text with punctuation' \
  'add-csv-export' \
  "$(make_slug 'Add CSV Export!')"

_assert_eq 'path traversal defense' \
  'etc-passwd' \
  "$(make_slug '../../../etc/passwd')"

_assert_eq 'empty input → manual-input' \
  'manual-input' \
  "$(make_slug '')"

LONG_INPUT="$(python3 -c "print('a' * 50)")"
EXPECTED_40="$(python3 -c "print('a' * 40)")"
_assert_eq 'max-length: 50 chars truncated to 40' \
  "$EXPECTED_40" \
  "$(make_slug "$LONG_INPUT")"

echo ""
echo "=== make_intake_id tests ==="

ID="$(make_intake_id 'test')"
echo "  Generated ID: $ID"
if [[ "$ID" =~ ^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$ ]]; then
  echo "  PASS: make_intake_id 'test' matches ID regex"
  (( PASS++ )) || true
else
  echo "  FAIL: make_intake_id 'test' → '$ID' does not match ID regex"
  (( FAIL++ )) || true
fi

echo ""
echo "=== Collision test ==="
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Pre-create the first slot to simulate a collision in the same second
FAKE_TS="$(date -u +%Y%m%d-%H%M%S)"
SLUG="collision-test"
FIRST_ID="${FAKE_TS}-${SLUG}"
touch "${TMP_DIR}/${FIRST_ID}.md"

# make_intake_id must now return a different ID since FIRST_ID file exists
ID2="$(make_intake_id "$SLUG" "$TMP_DIR")"

if [[ "$FIRST_ID" != "$ID2" ]]; then
  echo "  PASS: collision → two distinct IDs ('$FIRST_ID' vs '$ID2')"
  (( PASS++ )) || true
else
  echo "  FAIL: collision not resolved ('$FIRST_ID' == '$ID2')"
  (( FAIL++ )) || true
fi

echo ""
echo "=== validate_intake_id tests ==="

_assert_eq 'valid ID echoed back' \
  '20260512-143000-foo' \
  "$(validate_intake_id '20260512-143000-foo')"

_assert_exit 'valid ID → exit 0' 0 validate_intake_id '20260512-143000-foo'
_assert_exit 'path traversal → exit 1' 1 validate_intake_id '../../etc/passwd'
_assert_exit 'uppercase → exit 1' 1 validate_intake_id '20260512-143000-FooBar'

echo ""
echo "=== validate_slug tests ==="

_assert_exit 'valid slug → exit 0' 0 validate_slug 'add-csv-export'
_assert_exit 'uppercase slug → exit 1' 1 validate_slug 'BadCase'
_assert_exit 'leading hyphen → exit 1' 1 validate_slug '-bad-slug'

echo ""
echo "================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
