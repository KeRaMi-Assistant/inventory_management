#!/usr/bin/env bash
# notify.sh — Shim. Delegiert an lib/notify-impl.sh (P0-7).
exec /bin/bash "$(dirname "${BASH_SOURCE[0]}")/lib/notify-impl.sh" "$@"
