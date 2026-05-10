#!/usr/bin/env bash
# cost-verify.sh — Out-of-Process Hash-Chain-Verifier for the cost ledger.
#
# Usage:
#   cost-verify.sh [<ledger-path>]
#
# If <ledger-path> is omitted, the default ledger is used:
#   ${COST_CAP_LEDGER_DIR:-<repo-root>/.claude/overseer}/cost-ledger.jsonl
#
# Exit codes:
#   0 — Hash-Chain valid (or ledger does not exist / is empty).
#   1 — Tampering detected (removed line, modified usd, wrong entry_hash, …).
#   2 — I/O or parse error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Resolve ledger path
if [ -n "${1:-}" ]; then
  LEDGER_FILE="$1"
else
  if [ -n "${COST_CAP_LEDGER_DIR:-}" ]; then
    LEDGER_FILE="${COST_CAP_LEDGER_DIR}/cost-ledger.jsonl"
  else
    LEDGER_FILE="${REPO_ROOT}/.claude/overseer/cost-ledger.jsonl"
  fi
fi

if [ ! -f "$LEDGER_FILE" ]; then
  printf '[cost-verify] Ledger not found — nothing to verify: %s\n' "$LEDGER_FILE" >&2
  exit 0
fi

python3 - "$LEDGER_FILE" <<'PYEOF'
import sys, json, hashlib, re

ledger_path = sys.argv[1]

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

zero_hash = '0' * 64

# Regex to extract raw numeric tokens from JSON (preserves trailing zeros like 0.10)
_usd_re  = re.compile(r'"usd"\s*:\s*([0-9]+(?:\.[0-9]+)?)')
_pid_re  = re.compile(r'"pid"\s*:\s*([0-9]+)')

def _raw_field(line: str, pattern: re.Pattern) -> str:
    m = pattern.search(line)
    return m.group(1) if m else ''

try:
    with open(ledger_path, 'r') as f:
        raw_lines = f.readlines()
except OSError as e:
    print(f'[cost-verify] I/O error reading ledger: {e}', file=sys.stderr)
    sys.exit(2)

# Filter non-empty lines
lines = [l for l in raw_lines if l.strip()]

if not lines:
    # Empty ledger is valid
    sys.exit(0)

errors = []

for idx, raw_line in enumerate(lines):
    line_no = idx + 1  # 1-based for human output

    try:
        entry = json.loads(raw_line)
    except json.JSONDecodeError as e:
        errors.append(f'Line {line_no}: JSON parse error: {e}')
        continue

    # --- Reconstruct prev_hash ---
    expected_prev = zero_hash if idx == 0 else sha256(lines[idx - 1])

    stored_prev = entry.get('prev_hash', '')
    if stored_prev != expected_prev:
        errors.append(
            f'Line {line_no}: prev_hash mismatch\n'
            f'  expected: {expected_prev}\n'
            f'  stored:   {stored_prev}'
        )

    # --- Reconstruct entry_hash ---
    # Use raw string tokens to match what cost_record wrote (avoids float rounding)
    ts    = entry.get('ts', '')
    agent = entry.get('agent', '')
    usd   = _raw_field(raw_line, _usd_re)   # raw text, e.g. "0.10" not "0.1"
    pid   = _raw_field(raw_line, _pid_re)   # raw text integer

    entry_data = f"{ts}|{agent}|{usd}|{pid}|{expected_prev}"
    expected_entry_hash = sha256(entry_data)

    stored_entry_hash = entry.get('entry_hash', '')
    if stored_entry_hash != expected_entry_hash:
        errors.append(
            f'Line {line_no}: entry_hash mismatch\n'
            f'  expected: {expected_entry_hash}\n'
            f'  stored:   {stored_entry_hash}\n'
            f'  (ts={ts} agent={agent} usd={usd} pid={pid})'
        )

if errors:
    print('[cost-verify] TAMPERING DETECTED in cost ledger:', file=sys.stderr)
    for e in errors:
        print(f'  {e}', file=sys.stderr)
    sys.exit(1)

print(f'[cost-verify] OK — {len(lines)} entries, hash-chain valid.')
sys.exit(0)
PYEOF
