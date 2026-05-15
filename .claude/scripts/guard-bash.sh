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

# git commit auf main blockieren (Bug-Fix D+F 2026-05-15):
# CLAUDE.md §Branching: NIE direkt auf main committen. Hook fängt das jetzt.
# Auto-Commit-Hook hat `auto:`-Commits auf main durchgehen lassen.
if echo "$cmd" | grep -qE 'git[[:space:]]+commit\b'; then
  # Aktuellen Branch ermitteln (best-effort, fail-silent wenn nicht in Git-Repo)
  cur_branch=$(cd "${CLAUDE_PROJECT_DIR:-.}" && git branch --show-current 2>/dev/null || echo "")
  if [ "$cur_branch" = "main" ] || [ "$cur_branch" = "master" ]; then
    override_ok=0
    if [ "${MAIN_COMMIT_OVERRIDE:-0}" = "1" ]; then
      override_ok=1
    fi
    if echo "$cmd" | grep -qE '(^|[[:space:]])MAIN_COMMIT_OVERRIDE=1([[:space:]]|$)'; then
      override_ok=1
    fi
    if [ "$override_ok" != "1" ]; then
      block "git commit auf '$cur_branch' verboten — feature/<slug>- oder fix/<slug>-Branch erst. CLAUDE.md §Branching. Override: MAIN_COMMIT_OVERRIDE=1."
    fi
  fi
fi

# gh pr merge --admin nur mit MERGE_ADMIN_OVERRIDE=1 (CLAUDE.md §Verbotene Aktionen)
# Bug 2026-05-15: 6× --admin-Merges ohne Override durchgewunken, Hook hat nicht gefangen.
# Root-Cause: BSD grep -E kennt kein `\s` — nur POSIX-`[[:space:]]`.
# Hook-Bug-Fix: env-var im Command-Prefix (MERGE_ADMIN_OVERRIDE=1 gh pr merge ...)
# wird auch erkannt — bash inherited env wird vom Hook NICHT gesehen, nur
# der raw command-string. Audit-Log-Eintrag bei legitimer Override-Verwendung.
if echo "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+merge[[:space:]].*--admin([[:space:]]|$)'; then
  # Check both: (a) Hook-process env (für direct test calls) und
  # (b) Command-Prefix MERGE_ADMIN_OVERRIDE=1 (für inline-Aufrufe).
  override_ok=0
  if [ "${MERGE_ADMIN_OVERRIDE:-0}" = "1" ]; then
    override_ok=1
  fi
  if echo "$cmd" | grep -qE '(^|[[:space:]])MERGE_ADMIN_OVERRIDE=1([[:space:]]|$)'; then
    override_ok=1
  fi
  if [ "$override_ok" != "1" ]; then
    block "gh pr merge --admin verboten — setze MERGE_ADMIN_OVERRIDE=1 explizit (CLAUDE.md §565). Default: --auto + warte auf CI."
  fi
  # Override-Use auditieren (Best-effort, fail-silent)
  audit_file="$CLAUDE_PROJECT_DIR/.claude/audit/$(date -u +%Y-%m-%d).md"
  if [ -d "$(dirname "$audit_file")" ]; then
    {
      printf '\n---\naction: merge_admin_override\nts: %s\nsubject: %s\nreason: MERGE_ADMIN_OVERRIDE=1 explizit gesetzt\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$(echo "$cmd" | grep -oE 'gh pr merge [0-9]+' | head -1)"
    } >> "$audit_file" 2>/dev/null || true
  fi
fi

exit 0
