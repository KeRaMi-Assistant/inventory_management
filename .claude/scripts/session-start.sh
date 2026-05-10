#!/usr/bin/env bash
# Markiert eine manuelle User-Session — bypasst Self-Mod-Blocklist und
# Integrity-Check-PANIC. NICHT in Worker/Headless-Kontexten setzen.
#
# Schreibt einen signierten Hash in .claude/.user-session-active, der mit
# einem repo-externen Secret in ~/.claude/inventory-session-secret korreliert
# und pro Minute rotiert. Marker ist 5 Minuten lang gültig — danach erneut
# `bash .claude/scripts/session-start.sh` ausführen, um zu refreshen.
#
# Ein Worker mit HEADLESS_MODE=1 hat keinen Lese-Zugriff auf das Secret
# (mode 0400), kann also keinen gültigen Hash forgen — der Bypass ist
# kryptographisch geschützt.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/.claude/scripts/lib/self-mod-blocklist.sh"

if [ ! -r "$LIB" ]; then
  echo "missing lib: $LIB" >&2
  exit 1
fi
# shellcheck disable=SC1090
SELF_MOD_REPO_ROOT="$ROOT" . "$LIB"

mkdir -p "$ROOT/.claude"
hash_value="$(_session_compute_hash)"
if [ -z "$hash_value" ]; then
  echo "session-start: failed to compute hash (secret-file unreadable?)" >&2
  exit 2
fi

# Ensure target file is writable (it's in the blocklist, but session-start
# itself MUST be runnable by the user — guards only fire under HEADLESS_MODE).
marker="$ROOT/.claude/.user-session-active"
if [ -f "$marker" ]; then
  chmod 0644 "$marker" 2>/dev/null || true
fi
printf '%s\n' "$hash_value" > "$marker"
chmod 0644 "$marker"
echo "user-session marker set (5min TTL): $marker"
