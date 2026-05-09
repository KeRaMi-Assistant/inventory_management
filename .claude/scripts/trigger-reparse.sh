#!/usr/bin/env bash
# Triggert die `inbox-parse` Edge Function mit `force_overwrite=true`,
# damit existierende parsed_messages mit FALSCH extrahierten Tracking-
# Werten erneut durch die aktuelle Adapter-Registry laufen. Nutzung
# nach Adapter-Bug-Fixes wie z.B. dem CONTEXT_TRACKING_RE-Fix
# (DE5455279839 kam fälschlich als orderingShipmentId rein).
#
# Usage:
#   SUPABASE_SERVICE_ROLE_KEY=<key> bash .claude/scripts/trigger-reparse.sh [shop_key] [workspace_id]
#
# Den Service-Role-Key bekommst du im Supabase-Dashboard:
#   Project (uzpkrdymlrrydtuxnvhy) → Settings → API → service_role (secret)
#
# Argumente (beide optional):
#   $1 shop_key     z.B. "amazon" (Default: alle Shops)
#   $2 workspace_id UUID (Default: alle Workspaces)

set -euo pipefail

PROJECT_REF="uzpkrdymlrrydtuxnvhy"
URL="https://${PROJECT_REF}.supabase.co/functions/v1/inbox-parse"

SHOP_KEY="${1:-}"
WORKSPACE_ID="${2:-}"

KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
if [ -z "$KEY" ]; then
  echo "❌ SUPABASE_SERVICE_ROLE_KEY nicht gesetzt." >&2
  echo "   Hole den Key aus dem Dashboard und exportiere ihn:" >&2
  echo "     export SUPABASE_SERVICE_ROLE_KEY='<your_key>'" >&2
  echo "     bash $0 ${SHOP_KEY:-} ${WORKSPACE_ID:-}" >&2
  exit 1
fi

# Build JSON body
BODY='{"reparse_no_tracking": true, "force_overwrite": true'
[ -n "$SHOP_KEY" ]     && BODY="${BODY}, \"shop_key\": \"${SHOP_KEY}\""
[ -n "$WORKSPACE_ID" ] && BODY="${BODY}, \"workspace_id\": \"${WORKSPACE_ID}\""
BODY="${BODY}}"

echo "→ POST $URL"
echo "→ body: $BODY"
echo ""

curl -fsSL -X POST "$URL" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY"

echo ""
echo "✓ Re-Parse getriggert. Refresh die App-Inbox um die korrigierten"
echo "  Tracking-Werte zu sehen."
