#!/usr/bin/env bash
# audit-grep.sh — Search audit trail files for a keyword.
#
# Usage: audit-grep.sh <keyword>
#
# Prints complete entry blocks (from --- to ---) that contain the keyword.
# Works even on 0444-mode files (read-only access is fine).

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]; then
  printf 'Usage: audit-grep.sh <keyword>\n' >&2
  exit 1
fi

KEYWORD="$1"

# Resolve audit dir
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  AUDIT_DIR="${CLAUDE_PROJECT_DIR}/.claude/audit"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  AUDIT_DIR="${REPO_ROOT}/.claude/audit"
fi

if [ ! -d "$AUDIT_DIR" ]; then
  printf 'No audit directory found at %s\n' "$AUDIT_DIR" >&2
  exit 0
fi

# Use python3 to parse and grep entries reliably
python3 - "$AUDIT_DIR" "$KEYWORD" <<'PYEOF'
import sys, re, os

audit_dir = sys.argv[1]
keyword = sys.argv[2]

pattern = re.compile(r'(---\n.*?---\n)', re.DOTALL)

found = False
for fname in sorted(os.listdir(audit_dir)):
    if not fname.endswith('.md'):
        continue
    fpath = os.path.join(audit_dir, fname)
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
    except OSError as e:
        print(f"# could not read {fpath}: {e}", file=sys.stderr)
        continue

    for m in pattern.finditer(content):
        block = m.group(1)
        if keyword.lower() in block.lower():
            print(block, end='')
            found = True

if not found:
    print(f"# No entries matching '{keyword}' found.", file=sys.stderr)
PYEOF
