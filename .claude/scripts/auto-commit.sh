#!/bin/bash
# Stop Hook: Auto-Commit + Auto-Push auf Feature-Branch.
# Skip wenn: auf main, keine Änderungen, oder analyze rot.

set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

branch=$(git branch --show-current 2>/dev/null)

# Nie auf main / master automatisch committen
if [ "$branch" = "main" ] || [ "$branch" = "master" ] || [ -z "$branch" ]; then
  exit 0
fi

# --- Self-Mod-Reject (Mitigation 2) -----------------------------------------
# Unter HEADLESS_MODE=1: Prüfe ob staged/unstaged Diffs Blocklist-Pfade berühren.
# Pfade in .claude/whitelist.txt sind die EINZIGEN erlaubten autonomy-Pfade —
# alles andere in der Blocklist wird geblockt wenn keine User-Session aktiv ist.
if [ "${HEADLESS_MODE:-0}" = "1" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  SELF_MOD_BLOCKLIST_LIB="$REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
  if [ -f "$SELF_MOD_BLOCKLIST_LIB" ]; then
    # shellcheck source=.claude/scripts/lib/self-mod-blocklist.sh
    . "$SELF_MOD_BLOCKLIST_LIB"
    # Hole alle geänderten Dateien (staged + unstaged gegenüber HEAD)
    _changed_files="$(git diff --name-only HEAD 2>/dev/null)"
    _blocked_file=""
    while IFS= read -r _file; do
      [ -z "$_file" ] && continue
      if _is_self_mod_blocked "$REPO_ROOT/$_file"; then
        _blocked_file="$_file"
        break
      fi
    done <<< "$_changed_files"

    if [ -n "$_blocked_file" ]; then
      if [ ! -f "$REPO_ROOT/.claude/.user-session-active" ]; then
        echo "auto-commit ABORTED: Headless-Mode versuchte Blocklist-Pfad zu committen: $_blocked_file" >&2
        _self_mod_audit_and_notify "commit-block" "$_blocked_file"
        exit 1
      else
        echo "auto-commit WARN: Blocklist-Pfad in Diff ($_ blocked_file), aber User-Session aktiv — erlaubt." >&2
      fi
    fi
  fi
elif git diff --name-only HEAD 2>/dev/null | grep -q .; then
  # Außerhalb HEADLESS_MODE: nur warnen wenn Blocklist-Pfad im Diff
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  SELF_MOD_BLOCKLIST_LIB="$REPO_ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
  if [ -f "$SELF_MOD_BLOCKLIST_LIB" ]; then
    . "$SELF_MOD_BLOCKLIST_LIB"
    while IFS= read -r _file; do
      [ -z "$_file" ] && continue
      if _is_self_mod_blocked "$REPO_ROOT/$_file"; then
        echo "auto-commit WARN (non-headless): Blocklist-Pfad im Diff: $_file — manuelle Session, kein Block." >&2
        break
      fi
    done <<< "$(git diff --name-only HEAD 2>/dev/null)"
  fi
fi
# ---------------------------------------------------------------------------

# Nur committen wenn überhaupt Änderungen in Whitelist-Pfaden
# Pfade werden auch aus .claude/whitelist.txt gelesen (Single-Source-of-Truth).
# Hardcoded Basis-Whitelist als Fallback falls whitelist.txt fehlt.
WHITELIST=(
  lib supabase/migrations supabase/functions test
  pubspec.yaml pubspec.lock plans .github CLAUDE.md
  .claude/agents .claude/commands .claude/scripts .claude/settings.json
  .claude/stakeholder .claude/stakeholder/digest
  .claude/disputes .claude/audit .claude/overseer
  .claude/analyzer .claude/integrity .claude/git-hooks
  .claude/memory .claude/schemas .claude/metrics
)

# Ergänze Pfade aus whitelist.txt (dedupliziert, leer-Zeilen und #-Kommentare ignoriert)
if [ -f ".claude/whitelist.txt" ]; then
  while IFS= read -r _wl_path; do
    _wl_path="${_wl_path%%#*}"   # Kommentar abschneiden
    _wl_path="${_wl_path// /}"   # Leerzeichen trimmen (simpel)
    [ -z "$_wl_path" ] && continue
    # Nur hinzufügen wenn noch nicht drin (einfache Duplikat-Prüfung)
    _already=0
    for _existing in "${WHITELIST[@]}"; do
      [ "$_existing" = "$_wl_path" ] && _already=1 && break
    done
    [ "$_already" -eq 0 ] && WHITELIST+=("$_wl_path")
  done < ".claude/whitelist.txt"
fi

has_changes=0
for path in "${WHITELIST[@]}"; do
  if [ -e "$path" ] && ! git diff --quiet HEAD -- "$path" 2>/dev/null; then
    has_changes=1
    break
  fi
  if [ -e "$path" ] && git ls-files --others --exclude-standard -- "$path" 2>/dev/null | grep -q .; then
    has_changes=1
    break
  fi
done

if [ $has_changes -eq 0 ]; then
  exit 0
fi

# Quality-Gate: dart analyze auf lib/ muss grün sein
if command -v dart >/dev/null 2>&1; then
  if ! dart analyze lib/ >/dev/null 2>&1; then
    echo "auto-commit skipped: dart analyze hat Fehler — fix first" >&2
    exit 0
  fi
fi

# Whitelist-Add
for path in "${WHITELIST[@]}"; do
  if [ -e "$path" ]; then
    git add -- "$path" 2>/dev/null || true
  fi
done

# Wenn nach add nichts staged ist, raus
if git diff --cached --quiet; then
  exit 0
fi

last_task=""
if [ -f .claude/last-task.txt ]; then
  last_task=$(head -1 .claude/last-task.txt | tr -d '\n' | cut -c1-72)
fi
[ -z "$last_task" ] && last_task="autonome iteration"

git commit -m "auto: $last_task

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" >/dev/null 2>&1 || exit 0

# Push (best-effort — Network-Errors sind nicht fatal)
git push origin "$branch" >/dev/null 2>&1 || echo "auto-commit: push fehlgeschlagen (Branch lokal committed)" >&2

exit 0
