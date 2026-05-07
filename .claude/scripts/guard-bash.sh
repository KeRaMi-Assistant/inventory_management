#!/bin/bash
# PreToolUse Hook für Bash. Blockiert destruktive / sensitive Aktionen.
# Exit 2 = blockt mit Fehler-Message an Claude. Exit 0 = OK.

set -u

input=$(cat)
cmd=$(printf '%s' "$input" | /usr/bin/python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

if [ -z "$cmd" ]; then
  exit 0
fi

block() {
  echo "BLOCKED by guard-bash: $1" >&2
  echo "Command: $cmd" >&2
  exit 2
}

# Force-push auf main
if echo "$cmd" | grep -qE 'git push.*-f.*\b(origin\s+)?main\b'; then
  block "force-push auf main ist verboten"
fi
if echo "$cmd" | grep -qE 'git push.*--force.*\b(origin\s+)?main\b'; then
  block "force-push auf main ist verboten"
fi

# git reset --hard auf remote
if echo "$cmd" | grep -qE 'git reset --hard origin/'; then
  block "git reset --hard auf origin/* ist verboten"
fi

# rm -rf außerhalb sicherer Pfade
if echo "$cmd" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-rf|-fr)'; then
  if ! echo "$cmd" | grep -qE 'rm\s+-[rf]+\s+(\./)?(build|\.dart_tool|coverage|node_modules|\.next)/'; then
    block "rm -rf nur in build/, .dart_tool/, coverage/, node_modules/, .next/ erlaubt"
  fi
fi

# Supabase Prod-Aktionen
if echo "$cmd" | grep -qE '\bsupabase\s+db\s+push\b'; then
  block "supabase db push ist verboten — manuell vom User ausführen"
fi
if echo "$cmd" | grep -qE '\bsupabase\s+link\b'; then
  block "supabase link ist verboten — manuell vom User ausführen"
fi
if echo "$cmd" | grep -qE '\bsupabase\s+secrets\s+set\b'; then
  block "supabase secrets set ist verboten — manuell vom User ausführen"
fi

# Flutter publish
if echo "$cmd" | grep -qE 'flutter\s+pub\s+publish'; then
  block "flutter pub publish ist verboten"
fi

# Schreiben in geschützte Files
if echo "$cmd" | grep -qE '>\s*lib/config/supabase_config\.dart'; then
  block "Schreiben in lib/config/supabase_config.dart ist verboten"
fi
if echo "$cmd" | grep -qE 'google-services\.json|GoogleService-Info\.plist'; then
  block "Schreiben in Firebase-Config-Files ist verboten"
fi

# git add . (Whitelist erzwingen)
if echo "$cmd" | grep -qE 'git\s+add\s+(\.|--all|-A)\s*$'; then
  block "git add . / --all / -A verboten — nutze Whitelist (lib/, supabase/, test/, etc.)"
fi

exit 0
