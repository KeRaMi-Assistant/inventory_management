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

# --- Self-Mod-Blocklist (P0-0) ---------------------------------------------
# Source library, prüfe Bash-Command gegen Blocklist BEVOR existing Guards.
GUARD_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/self-mod-blocklist.sh"
if [ -r "$GUARD_LIB" ]; then
  # shellcheck disable=SC1090
  . "$GUARD_LIB"
  _guard_bash_self_mod "$cmd"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    block "self-mod-blocklist: Bash-Befehl würde geschützten Pfad ändern (HEADLESS_MODE/Overseer aktiv)"
  fi
fi

# --- Branch-Allowlist-Check (P3-8) -----------------------------------------
_branch_allowlist_check() {
  local cmd="$*"
  local branch=""

  if [[ "$cmd" =~ git[[:space:]]+checkout[[:space:]]+-b[[:space:]]+([^[:space:]]+) ]]; then
    branch="${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ git[[:space:]]+switch[[:space:]]+-c[[:space:]]+([^[:space:]]+) ]]; then
    branch="${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ git[[:space:]]+push[[:space:]]+-u[[:space:]]+origin[[:space:]]+([^[:space:]]+) ]]; then
    branch="${BASH_REMATCH[1]}"
  fi

  if [ -n "$branch" ]; then
    # Allow main, master, HEAD — no prefix check needed
    case "$branch" in main|master|HEAD) return 0 ;; esac
    # Check allowlist
    if [[ ! "$branch" =~ ^(feature|fix|chore)/[a-z0-9][a-z0-9-]{0,39}$ ]]; then
      echo "[guard-bash] Branch-Name verstößt gegen Allowlist:" >&2
      echo "  Erwartet: ^(feature|fix|chore)/[a-z0-9][a-z0-9-]{0,39}$  (max 40 Zeichen nach Prefix-Slash)" >&2
      echo "  Bekommen: $branch" >&2
      return 2
    fi
  fi
  return 0
}

_branch_allowlist_check "$cmd"
if [ $? -eq 2 ]; then
  exit 2
fi

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
