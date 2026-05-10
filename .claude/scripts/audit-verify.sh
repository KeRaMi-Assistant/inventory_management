#!/usr/bin/env bash
# audit-verify.sh — Out-of-process verifier for the audit trail hash-chain.
#
# Usage:
#   audit-verify.sh [<audit-file> ...]
#   audit-verify.sh          # verifies all .claude/audit/*.md files
#
# Exit codes:
#   0 = chain valid
#   1 = chain broken (tampered entry)
#   2 = parse error

set -euo pipefail

# ---------------------------------------------------------------------------
# SHA256 helper
# ---------------------------------------------------------------------------
_verify_sha256() {
  local input="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$input" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$input" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$input" | python3 -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())"
  fi
}

# ---------------------------------------------------------------------------
# Parse audit file into entries
# Returns blocks separated by record separator \x1e
# ---------------------------------------------------------------------------
_parse_entries() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Split on --- boundaries; entries are between --- delimiters
# Pattern: starts with --- line, ends with --- line
pattern = re.compile(r'---\n(.*?)---\n', re.DOTALL)
entries = pattern.findall(content)

for entry in entries:
    # Print each entry body separated by record separator \x1e
    sys.stdout.write('\x1e' + entry)
PYEOF
}

# ---------------------------------------------------------------------------
# Verify a single audit file
# ---------------------------------------------------------------------------
verify_file() {
  local file="$1"
  local ok=0

  if [ ! -f "$file" ]; then
    printf 'SKIP (not found): %s\n' "$file"
    return 0
  fi

  if [ ! -s "$file" ]; then
    printf 'OK (empty): %s\n' "$file"
    return 0
  fi

  # Parse entries via python3
  local raw_entries
  raw_entries="$(_parse_entries "$file")"

  if [ -z "$raw_entries" ]; then
    printf 'OK (no entries): %s\n' "$file"
    return 0
  fi

  # Process entries: split on \x1e
  local entry_num=0
  local accumulated_content=""
  local prev_computed_hash="0000000000000000000000000000000000000000000000000000000000000000"

  # We'll use python3 to do the verification loop for reliable parsing
  python3 - "$file" <<PYEOF
import sys, re, hashlib

def sha256(s):
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r'---\n(.*?)---\n', re.DOTALL)
raw_blocks = []
for m in pattern.finditer(content):
    raw_blocks.append(m.group(0))  # full block including --- delimiters

entry_bodies = [m.group(1) for m in pattern.finditer(content)]

if not entry_bodies:
    print("OK (no entries)")
    sys.exit(0)

errors = []
prev_hash = "0" * 64
accumulated = ""

for i, (body, full_block) in enumerate(zip(entry_bodies, raw_blocks)):
    fields = {}
    for line in body.split('\n'):
        line = line.rstrip()
        if ':' in line:
            k, _, v = line.partition(': ')
            fields[k.strip()] = v.strip()

    required = ['ts', 'sha', 'actor', 'action', 'subject', 'prev_hash', 'entry_hash', 'reason']
    missing = [r for r in required if r not in fields]
    if missing:
        errors.append(f"Entry {i+1}: missing fields: {missing}")
        continue

    stored_prev_hash = fields['prev_hash']
    stored_entry_hash = fields['entry_hash']
    reason_val = fields['reason']

    # Verify prev_hash
    if i == 0:
        expected_prev = "0" * 64
        if stored_prev_hash != expected_prev:
            errors.append(f"Entry {i+1}: prev_hash mismatch. Expected all-zeros, got {stored_prev_hash}")
    else:
        # prev_hash should be SHA256 of the previous full block + newline (as appended)
        # The accumulated content is everything up to (but not including) this entry
        expected_prev = sha256(accumulated)
        if stored_prev_hash != expected_prev:
            errors.append(
                f"Entry {i+1}: prev_hash mismatch.\n"
                f"  stored:   {stored_prev_hash}\n"
                f"  expected: {expected_prev}"
            )

    # Verify entry_hash
    entry_data = f"{fields['ts']}|{fields['sha']}|{fields['actor']}|{fields['action']}|{fields['subject']}|{stored_prev_hash}|{reason_val}"
    expected_entry_hash = sha256(entry_data)
    if stored_entry_hash != expected_entry_hash:
        errors.append(
            f"Entry {i+1}: entry_hash mismatch.\n"
            f"  stored:   {stored_entry_hash}\n"
            f"  expected: {expected_entry_hash}"
        )

    # Accumulate: the block as written to file (full_block + '\n' from printf)
    accumulated += full_block + '\n'

if errors:
    print(f"FAIL: {path}")
    for e in errors:
        print(f"  {e}")
    sys.exit(1)
else:
    print(f"OK: {path} ({len(entry_bodies)} entries, chain valid)")
    sys.exit(0)
PYEOF
  return $?
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
_syslog_crosscheck() {
  local file="$1"
  # Cross-check is OPT-IN: enabled when CLAUDE_AUDIT_VERIFY_SYSLOG=1 (or
  # when CLAUDE_AUDIT_SYSLOG_FILE points to a stub-file used by tests).
  # Default-OFF because `log show` on macOS lags by seconds and is not
  # always reliable in sandboxed test contexts. Production callers
  # (overseer / nightly verifier) explicitly set the env var.
  if [ "${CLAUDE_AUDIT_VERIFY_SYSLOG:-0}" != "1" ] \
     && [ -z "${CLAUDE_AUDIT_SYSLOG_FILE:-}" ]; then
    return 0
  fi

  local syslog_dump=""
  local using_stub=0
  if [ -n "${CLAUDE_AUDIT_SYSLOG_FILE:-}" ] && [ -f "${CLAUDE_AUDIT_SYSLOG_FILE}" ]; then
    syslog_dump="$(cat "$CLAUDE_AUDIT_SYSLOG_FILE")"
    using_stub=1
  elif command -v log >/dev/null 2>&1; then
    syslog_dump="$(log show --last 24h --predicate 'eventMessage CONTAINS "claude-audit"' --style compact 2>/dev/null || true)"
  fi

  # In stub mode (test path), an empty syslog dump means "tampering";
  # in real mode (macOS log show), an empty result may just be lag → soft skip.
  if [ -z "$syslog_dump" ]; then
    if [ "$using_stub" -eq 1 ]; then
      printf 'FAIL: syslog mirror is empty — entries missing\n' >&2
      return 1
    fi
    return 0
  fi

  # Extract entry_hashes from local file
  local local_hashes
  local_hashes="$(python3 -c "
import re, sys
with open('$file') as f:
    content = f.read()
for m in re.finditer(r'entry_hash:\s*([0-9a-f]{64})', content):
    print(m.group(1))
" 2>/dev/null)"

  local missing=0
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    if ! printf '%s' "$syslog_dump" | grep -qF "entry_hash=$h"; then
      missing=$((missing + 1))
      printf '  syslog mismatch: entry_hash=%s missing in syslog\n' "$h" >&2
    fi
  done <<< "$local_hashes"

  if [ "$missing" -gt 0 ]; then
    printf 'FAIL: %d entries missing in syslog mirror — possible tampering\n' "$missing" >&2
    return 1
  fi
  return 0
}

main() {
  local files=("$@")

  if [ ${#files[@]} -eq 0 ]; then
    # Default: all audit files
    local audit_dir
    if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
      audit_dir="${CLAUDE_PROJECT_DIR}/.claude/audit"
    else
      local repo_root
      repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      audit_dir="${repo_root}/.claude/audit"
    fi

    if [ ! -d "$audit_dir" ]; then
      printf 'No audit directory found at %s\n' "$audit_dir"
      exit 0
    fi

    # Collect all .md files
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$audit_dir" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)

    if [ ${#files[@]} -eq 0 ]; then
      printf 'No audit files found in %s\n' "$audit_dir"
      exit 0
    fi
  fi

  local exit_code=0
  for f in "${files[@]}"; do
    verify_file "$f" || exit_code=1
    _syslog_crosscheck "$f" || exit_code=1
  done

  exit $exit_code
}

main "$@"
