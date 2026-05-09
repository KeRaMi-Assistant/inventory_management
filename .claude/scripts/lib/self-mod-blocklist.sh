#!/usr/bin/env bash
# self-mod-blocklist.sh — Single-Source-of-Truth für die Self-Mod-Blocklist.
#
# Sourced by guard-bash.sh, pre-push hook, integrity-check.sh, etc.
# Definiert SELF_MOD_BLOCKLIST (Repo-relative Pfade) und Helper-Funktionen.
#
# Pfad-Vergleiche IMMER absolut (via realpath), niemals reine Substring-Matches —
# sonst Bypass via `./xxx/../guard-bash.sh` möglich.

# Hinweis: KEIN `set -e` hier — wird von Hosts gesourced, die ihre eigenen
# Fehler-Modi haben. Wir setzen lediglich -u für Variable-Hygiene.
set -u

# Repo-Root (Caller darf SELF_MOD_REPO_ROOT überschreiben für Tests).
if [ -z "${SELF_MOD_REPO_ROOT:-}" ]; then
  SELF_MOD_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

# --- Blocklist (Repo-relative Pfade) ----------------------------------------
# WICHTIG: integrity-check.sh ist BEWUSST nicht in der Liste — sonst nicht
# updatebar. Manifest-Builder/Helper ebenfalls nicht (legitime Updates).
SELF_MOD_BLOCKLIST=(
  ".claude/scripts/guard-bash.sh"
  ".claude/scripts/lib/self-mod-blocklist.sh"
  ".claude/scripts/lib/cost-cap.sh"
  ".claude/scripts/lib/audit.sh"
  ".claude/scripts/auto-merge-pr.sh"
  ".claude/scripts/auto-commit.sh"
  ".claude/scripts/install-headless.sh"
  ".claude/scripts/install-overseer.sh"
  ".claude/scripts/install-self-mod-guard.sh"
  ".claude/scripts/install-integrity-check.sh"
  ".claude/scripts/uninstall-headless.sh"
  ".claude/scripts/uninstall-overseer.sh"
  ".claude/scripts/uninstall-integrity-check.sh"
  ".claude/scripts/overseer.sh"
  ".claude/scripts/worker.sh"
  ".claude/scripts/watchdog.sh"
  ".claude/scripts/recover.sh"
  ".claude/scripts/audit-record.sh"
  ".claude/scripts/notify.sh"
  ".claude/scripts/integrity-manifest-build.sh"
  ".claude/scripts/integrity-check.sh"
  ".claude/scripts/session-start.sh"
  ".claude/scripts/session-end.sh"
  ".claude/.user-session-active"
  ".claude/agents/disput-proponent.md"
  ".claude/agents/disput-skeptic.md"
  ".claude/agents/disput-pragmatist.md"
  ".claude/agents/stakeholder-triage.md"
  ".claude/agents/stakeholder-validator.md"
  ".claude/settings.json"
  ".claude/settings.local.json"
  ".claude/git-hooks/pre-push"
  "CLAUDE.md"
)

# Templates for plist installer scripts (proactive coverage for #11)
SELF_MOD_BLOCKLIST_OPTIONAL=(
  ".claude/scripts/integrity-launchagent.plist.template"
  ".claude/scripts/overseer-launchagent.plist.template"
)
for _opt in "${SELF_MOD_BLOCKLIST_OPTIONAL[@]}"; do
  SELF_MOD_BLOCKLIST+=("$_opt")
done
unset _opt

# Glob-Muster (absolut). Werden separat geprüft.
SELF_MOD_BLOCKLIST_GLOBS=(
  "$HOME/Library/LaunchAgents/com.inventory.*.plist"
  "$HOME/Library/LaunchAgents/com.kerami.inventory.*.plist"
)

# --- Helper: ist Pfad geschützt? --------------------------------------------
# Usage: _is_self_mod_blocked <path>
# Exit 0 = blocked, 1 = nicht blocked
_is_self_mod_blocked() {
  local raw="${1:-}"
  [ -z "$raw" ] && return 1

  # Absoluten Pfad bestimmen — auch wenn die Datei (noch) nicht existiert
  # (für `>` redirects auf neue Files). Wir nutzen Python für portable
  # realpath, weil macOS' coreutils kein -m hat.
  local abs
  abs="$(/usr/bin/python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$raw" 2>/dev/null || printf '%s' "$raw")"

  local entry full
  for entry in "${SELF_MOD_BLOCKLIST[@]}"; do
    full="$SELF_MOD_REPO_ROOT/$entry"
    full="$(/usr/bin/python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$full" 2>/dev/null || printf '%s' "$full")"
    if [ "$abs" = "$full" ]; then
      return 0
    fi
  done

  # Glob-Patterns
  local pat
  for pat in "${SELF_MOD_BLOCKLIST_GLOBS[@]}"; do
    # shellcheck disable=SC2053
    case "$abs" in
      $pat) return 0 ;;
    esac
  done

  return 1
}

# --- Helper: ist Self-Mod-Schutz aktiv? -------------------------------------
# Schutz ist aktiv wenn:
#   - HEADLESS_MODE=1 oder OVERSEER_WORKER_PID gesetzt
#   - UND .claude/.user-session-active fehlt (sonst Bypass)
_is_self_mod_protection_active() {
  if [ "${HEADLESS_MODE:-0}" = "1" ] || [ -n "${OVERSEER_WORKER_PID:-}" ]; then
    local marker="$SELF_MOD_REPO_ROOT/.claude/.user-session-active"
    if _is_session_marker_valid "$marker"; then
      return 1
    fi
    return 0
  fi
  return 1
}

# --- Session-Marker-Validierung ---------------------------------------------
# Marker ist gültig, wenn:
#   - Datei existiert + nicht leer.
#   - Inhalt (erste Zeile, getrimmt) == sha256(secret + iso_minute) für eines
#     der letzten 5 Minuten-Slots.
#   - Secret-File ~/.claude/inventory-session-secret existiert + lesbar.
# Ohne Secret-File oder bei leerem Marker: ungültig → Schutz aktiv.
# Ein Worker, der `touch .claude/.user-session-active` ausführt, schreibt eine
# leere Datei → invalid → kann Schutz nicht bypassen.
_is_session_marker_valid() {
  local marker="${1:-}"
  [ -n "$marker" ] || return 1
  [ -f "$marker" ] || return 1
  [ -s "$marker" ] || return 1

  local secret_file="${CLAUDE_SESSION_SECRET_FILE:-$HOME/.claude/inventory-session-secret}"
  [ -r "$secret_file" ] || return 1

  /usr/bin/python3 - "$marker" "$secret_file" <<'PYEOF' 2>/dev/null
import sys, hashlib, time
marker, secret_file = sys.argv[1], sys.argv[2]
try:
    with open(marker, 'r', encoding='utf-8') as f:
        provided = f.readline().strip()
    if not provided:
        sys.exit(1)
    with open(secret_file, 'r', encoding='utf-8') as f:
        secret = f.read().strip()
    if not secret:
        sys.exit(1)
    now = int(time.time() // 60)
    for delta in range(0, 6):  # 0..5 minute slots back
        minute = now - delta
        h = hashlib.sha256(f"{secret}|{minute}".encode('utf-8')).hexdigest()
        if h == provided:
            sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PYEOF
}

# --- Helper: aktuellen Session-Hash erzeugen --------------------------------
# Wird von session-start.sh genutzt. Schreibt Hash nach stdout.
# Erstellt Secret-File falls nicht vorhanden (mode 0400).
_session_compute_hash() {
  local secret_file="${CLAUDE_SESSION_SECRET_FILE:-$HOME/.claude/inventory-session-secret}"
  /usr/bin/python3 - "$secret_file" <<'PYEOF'
import sys, os, hashlib, time, secrets
secret_file = sys.argv[1]
os.makedirs(os.path.dirname(secret_file), exist_ok=True)
if not os.path.exists(secret_file) or os.path.getsize(secret_file) == 0:
    with open(secret_file, 'w', encoding='utf-8') as f:
        f.write(secrets.token_hex(32))
    os.chmod(secret_file, 0o400)
try:
    os.chmod(secret_file, 0o400)
except Exception:
    pass
with open(secret_file, 'r', encoding='utf-8') as f:
    secret = f.read().strip()
minute = int(time.time() // 60)
print(hashlib.sha256(f"{secret}|{minute}".encode('utf-8')).hexdigest())
PYEOF
}

# --- Helper: Audit + Notify bei Block ---------------------------------------
_self_mod_audit_and_notify() {
  local action="${1:-block}"
  local target="${2:-?}"
  local actor="${OVERSEER_AGENT:-${USER:-unknown}}"

  # Audit (best-effort — audit-record.sh existiert evtl. noch nicht)
  if [ -x "$SELF_MOD_REPO_ROOT/.claude/scripts/audit-record.sh" ]; then
    "$SELF_MOD_REPO_ROOT/.claude/scripts/audit-record.sh" \
      "$actor" "self-mod-$action" "$target" \
      "blocked by self-mod guard (HEADLESS_MODE=${HEADLESS_MODE:-0})" \
      >/dev/null 2>&1 || true
  else
    # Fallback: minimal flat-file log
    mkdir -p "$SELF_MOD_REPO_ROOT/.claude/audit" 2>/dev/null || true
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\t%s\tself-mod-%s\t%s\n' \
      "$ts" "$actor" "$action" "$target" \
      >> "$SELF_MOD_REPO_ROOT/.claude/audit/self-mod.log" 2>/dev/null || true
  fi

  # Notify (best-effort)
  if [ -x "$SELF_MOD_REPO_ROOT/.claude/scripts/notify.sh" ]; then
    "$SELF_MOD_REPO_ROOT/.claude/scripts/notify.sh" \
      "Self-Mod blocked" \
      "Actor=$actor target=$target" \
      "failure" >/dev/null 2>&1 || true
  fi
}

# --- Bash-Command-Inspektor -------------------------------------------------
# Konservativ: jeder Bash-Befehl, der einen Blocklist-Pfad als Argument hat
# (außer reine Read-Operations wie cat/head/grep/less/wc/diff/tail/file/stat),
# wird als Self-Mod-Versuch klassifiziert.
#
# Usage: _guard_bash_self_mod "<command>"
# Exit 0 = OK, 2 = blocked
_guard_bash_self_mod() {
  local cmd="${1:-}"
  [ -z "$cmd" ] && return 0

  if ! _is_self_mod_protection_active; then
    return 0
  fi

  # 1) Direkte Pfad-Tokens prüfen
  local entry hit=""
  for entry in "${SELF_MOD_BLOCKLIST[@]}"; do
    # Wir matchen sowohl repo-relativ als auch /absolut.
    local pat_rel="$entry"
    local pat_abs="$SELF_MOD_REPO_ROOT/$entry"

    # Word-boundary-Match (sehr konservativ — false positives akzeptiert)
    if printf '%s' "$cmd" | grep -qF -- "$pat_rel" \
       || printf '%s' "$cmd" | grep -qF -- "$pat_abs"; then
      hit="$entry"
      break
    fi
  done

  [ -z "$hit" ] && return 0

  # 2) Read-only-Whitelist: cat/head/tail/grep/less/wc/diff/file/stat/sha256sum
  #    Wir prüfen das ERSTE Token — bei pipes greifen wir trotzdem (sed -i
  #    in einer pipe ist trotzdem ein Write).
  local first
  first="$(printf '%s' "$cmd" | awk '{print $1}')"
  case "$first" in
    cat|head|tail|grep|egrep|fgrep|less|more|wc|diff|file|stat|shasum|sha256sum|md5|md5sum|ls|find|awk|cut|sort|uniq|tee)
      # `tee` schreibt — nicht whitelisten
      if [ "$first" = "tee" ]; then
        :
      else
        # Prüfe explizit auf write-Patterns weiter unten
        :
      fi
      ;;
  esac

  # 3) Write-Patterns suchen — diese qualifizieren als Self-Mod
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]|;&])sed[[:space:]]+-i'; then
    _self_mod_audit_and_notify "bash-sed" "$hit"
    return 2
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]|;&])(rm|mv|cp|tee|truncate|install|chmod|chown|chflags|ln)([[:space:]]|$)'; then
    _self_mod_audit_and_notify "bash-write" "$hit"
    return 2
  fi
  if printf '%s' "$cmd" | grep -qE '>>?[[:space:]]*'; then
    _self_mod_audit_and_notify "bash-redirect" "$hit"
    return 2
  fi
  if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+(rm|checkout|restore|reset|apply)'; then
    _self_mod_audit_and_notify "bash-git-mod" "$hit"
    return 2
  fi
  if printf '%s' "$cmd" | grep -qE 'cat[[:space:]]+<<'; then
    _self_mod_audit_and_notify "bash-heredoc" "$hit"
    return 2
  fi

  return 0
}

# --- Helper für Edit/Write-Hooks --------------------------------------------
# Usage: _guard_path_self_mod <path>
# Exit 0 = OK, 2 = blocked
_guard_path_self_mod() {
  local path="${1:-}"
  [ -z "$path" ] && return 0
  if ! _is_self_mod_protection_active; then
    return 0
  fi
  if _is_self_mod_blocked "$path"; then
    _self_mod_audit_and_notify "edit" "$path"
    return 2
  fi
  return 0
}
