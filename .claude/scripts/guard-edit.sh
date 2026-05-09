#!/usr/bin/env bash
# PreToolUse Hook für Edit/Write/MultiEdit/NotebookEdit.
# Blockiert Edits an Self-Mod-Blocklist-Pfaden, sobald HEADLESS_MODE=1
# oder OVERSEER_WORKER_PID gesetzt ist.
#
# Exit 2 = blocked, 0 = OK.

set -u

# Read input JSON from stdin and extract file_path
input="$(cat)"
file_path="$(printf '%s' "$input" | /usr/bin/python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {}) or {}
    p = ti.get('file_path') or ti.get('path') or ti.get('notebook_path') or ''
    print(p)
except Exception:
    print('')
" 2>/dev/null)"

if [ -z "$file_path" ]; then
  exit 0
fi

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/self-mod-blocklist.sh"
if [ ! -r "$LIB" ]; then
  exit 0
fi

# shellcheck disable=SC1090
. "$LIB"

_guard_path_self_mod "$file_path"
rc=$?
if [ "$rc" -eq 2 ]; then
  echo "BLOCKED by guard-edit: $file_path liegt in Self-Mod-Blocklist (HEADLESS_MODE/Overseer aktiv)" >&2
  exit 2
fi
exit 0
