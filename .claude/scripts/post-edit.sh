#!/bin/bash
# PostToolUse Hook für Edit/Write. Führt fokussierte Lint-Checks aus.
# Exit 0 immer (non-blocking). Output landet im Tool-Result-Stream zu Claude.

set -u

input=$(cat)
file_path=$(printf '%s' "$input" | /usr/bin/python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

case "$file_path" in
  *.dart)
    if command -v dart >/dev/null 2>&1; then
      out=$(dart analyze "$file_path" 2>&1)
      ec=$?
      if [ $ec -ne 0 ]; then
        echo "─── dart analyze ($file_path) ───" >&2
        echo "$out" | head -30 >&2
      fi
    fi
    ;;
  */supabase/functions/*.ts)
    if command -v deno >/dev/null 2>&1; then
      out=$(deno check "$file_path" 2>&1)
      ec=$?
      if [ $ec -ne 0 ]; then
        echo "─── deno check ($file_path) ───" >&2
        echo "$out" | head -30 >&2
      fi
    fi
    ;;
  *l10n/app_*.arb)
    de_keys=$(/usr/bin/python3 -c "import json,sys; print('\n'.join(sorted(k for k in json.load(open('lib/l10n/app_de.arb')).keys() if not k.startswith('@'))))" 2>/dev/null)
    en_keys=$(/usr/bin/python3 -c "import json,sys; print('\n'.join(sorted(k for k in json.load(open('lib/l10n/app_en.arb')).keys() if not k.startswith('@'))))" 2>/dev/null)
    if [ -n "$de_keys" ] && [ -n "$en_keys" ] && [ "$de_keys" != "$en_keys" ]; then
      echo "─── ARB-Drift: app_de.arb und app_en.arb haben unterschiedliche Keys ───" >&2
      diff <(echo "$de_keys") <(echo "$en_keys") | head -20 >&2
    fi
    ;;
esac

exit 0
