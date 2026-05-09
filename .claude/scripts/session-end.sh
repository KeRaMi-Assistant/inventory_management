#!/usr/bin/env bash
# Beendet die manuelle User-Session (löscht den signierten Marker).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
rm -f "$ROOT/.claude/.user-session-active"
echo "user-session marker cleared"
