#!/usr/bin/env bash
# Installiert den pre-push Hook nach .git/hooks/pre-push.
#
# Default: Symlink (so dass Updates am tracked-File automatisch ziehen).
# Bei `--copy` stattdessen Hardcopy (für Setups, in denen Symlinks nicht
# gehen).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/.claude/git-hooks/pre-push"

# Resolve hooksPath (falls User es überschreibt)
HOOKS_DIR="$(git -C "$ROOT" config --get core.hooksPath 2>/dev/null || true)"
if [ -z "$HOOKS_DIR" ]; then
  HOOKS_DIR="$ROOT/.git/hooks"
fi
DST="$HOOKS_DIR/pre-push"

mode="symlink"
if [ "${1:-}" = "--copy" ]; then
  mode="copy"
fi

if [ ! -f "$SRC" ]; then
  echo "missing source hook: $SRC" >&2
  exit 1
fi

mkdir -p "$HOOKS_DIR"

if [ -e "$DST" ] || [ -L "$DST" ]; then
  echo "backup existing $DST → ${DST}.bak" >&2
  mv -f "$DST" "${DST}.bak"
fi

if [ "$mode" = "symlink" ]; then
  ln -s "$SRC" "$DST"
else
  cp "$SRC" "$DST"
fi
chmod +x "$SRC"
chmod +x "$DST" 2>/dev/null || true

echo "installed pre-push hook → $DST ($mode)"
echo
echo "Test:"
echo "  echo 'x' >> .claude/scripts/guard-bash.sh"
echo "  git add -- .claude/scripts/guard-bash.sh"
echo "  git commit -m test"
echo "  HEADLESS_MODE=1 git push --dry-run   # sollte abort"
