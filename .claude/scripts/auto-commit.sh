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

# Nur committen wenn überhaupt Änderungen in Whitelist-Pfaden
WHITELIST=(lib supabase/migrations supabase/functions test pubspec.yaml pubspec.lock plans .github CLAUDE.md .claude/agents .claude/commands .claude/scripts .claude/settings.json)

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
