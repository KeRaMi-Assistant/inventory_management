#!/usr/bin/env bash
# scan-security-drift.sh — Analyzer-Modul: detect security drift.
#
# Check 1: New/changed migrations with CREATE TABLE but no RLS policy.
# Check 2: New/changed Edge Functions without Auth-header check.
#
# Usage:
#   scan-security-drift.sh           — full run, writes items to overseer/inbox/
#   scan-security-drift.sh --dry-run — plan to stdout, no files written
#   scan-security-drift.sh --status  — print state JSON to stdout
#
# Read-Only: never modifies source code.
# Dedup key: sha256(subject_key + "scan-security-drift") — stable across re-runs.
# Cap: 3 items/run (security per-item, no aggregation).
# Inbox-Cap: skip if .claude/overseer/inbox/ has > 50 files.
# needs_dispute: true always (Mitigation 14).

set -uo pipefail

# ---------------------------------------------------------------------------
# Paths & config
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# CLAUDE_PROJECT_DIR allows sandbox/test overrides of the repo root.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  REPO_ROOT="$(cd "$CLAUDE_PROJECT_DIR" && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

MODULE_NAME="scan-security-drift"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-security-drift.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"

MAX_ITEMS=3
INBOX_CAP=50

DRY_RUN=0
STATUS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --status)  STATUS_ONLY=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_sha256() {
  printf '%s' "$1" | shasum -a 256 2>/dev/null | awk '{print $1}' \
    || printf '%s' "$1" | sha256sum | awk '{print $1}'
}

_sha8() { printf '%s' "$(_sha256 "$1")" | cut -c1-8; }

_audit() {
  if [ -f "$AUDIT_SH" ]; then
    # shellcheck source=/dev/null
    source "$AUDIT_SH"
    audit_record "$MODULE_NAME" "${1:-info}" "${2:-}" "${3:-}" 2>/dev/null || true
  fi
}

_notify_info() {
  local msg="$1"
  if [ -f "$NOTIFY_SH" ]; then
    NOTIFY_DRY_RUN="${NOTIFY_DRY_RUN:-0}" bash "$NOTIFY_SH" info "claude-swarm" \
      "scan-security-drift" "$msg" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Status-only mode
# ---------------------------------------------------------------------------
if [ "$STATUS_ONLY" -eq 1 ]; then
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    printf '{"last_run":null,"subjects":{}}\n'
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Load / initialise state
# ---------------------------------------------------------------------------
_load_state() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    printf '{"last_run":null,"subjects":{}}\n'
  fi
}

_save_state() {
  local json="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$json" > "$STATE_FILE"
}

STATE_JSON="$(_load_state)"

# ---------------------------------------------------------------------------
# Inbox-Cap check
# ---------------------------------------------------------------------------
_inbox_count() {
  find "$INBOX_DIR" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' '
}

if [ -d "$INBOX_DIR" ]; then
  INBOX_CNT="$(_inbox_count)"
  if [ "$INBOX_CNT" -gt "$INBOX_CAP" ]; then
    printf '[scan-security-drift] SKIP: inbox has %d items (cap=%d)\n' "$INBOX_CNT" "$INBOX_CAP"
    _audit "skip" "inbox-cap" "inbox=$INBOX_CNT > cap=$INBOX_CAP — no items generated"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# State helpers (python3, avoids jq dependency)
# ---------------------------------------------------------------------------
_state_has_subject() {
  local hash="$1"
  python3 - "$STATE_FILE" "$hash" <<'PYEOF'
import sys, json, os
sf, h = sys.argv[1], sys.argv[2]
if not os.path.exists(sf):
    print('0'); sys.exit(0)
with open(sf) as f:
    d = json.load(f)
print('1' if h in d.get('subjects', {}) else '0')
PYEOF
}

_state_add_subject() {
  local hash="$1" subject_key="$2" drift_type="$3" file="$4"
  STATE_JSON="$(python3 - "$STATE_JSON" "$hash" "$subject_key" "$drift_type" "$file" <<'PYEOF'
import sys, json, datetime
state_json, h, key, dtype, fpath = sys.argv[1:]
d = json.loads(state_json)
d.setdefault('subjects', {})[h] = {
    'key': key,
    'drift_type': dtype,
    'file': fpath,
    'first_seen': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
}
print(json.dumps(d, indent=2))
PYEOF
)"
}

# ---------------------------------------------------------------------------
# Collect drift signals
# ---------------------------------------------------------------------------
# Each entry format: "<drift_type>\t<subject_key>\t<file>\t<description>"
declare -a SIGNALS=()

# ---- Check 1: Migrations without RLS -----------------------------------------
# Get new/changed migration files vs origin/main
MIGRATION_FILES=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  MIGRATION_FILES+=("$f")
done < <(git -C "$REPO_ROOT" diff origin/main...HEAD --name-only \
  -- 'supabase/migrations/*.sql' 2>/dev/null || true)

for mig_rel in "${MIGRATION_FILES[@]+"${MIGRATION_FILES[@]}"}"; do
  mig_abs="$REPO_ROOT/$mig_rel"
  [ -f "$mig_abs" ] || continue

  # Extract CREATE TABLE names (case-insensitive)
  while IFS= read -r table_name; do
    [ -n "$table_name" ] || continue
    table_name="${table_name// /}"

    # Check for RLS enablement or policy in the same file
    # Also scan all migration files (later migrations may enable RLS)
    rls_found=0

    # Search all migrations (not just current) for this table's RLS
    if grep -ril "ENABLE ROW LEVEL SECURITY" "$REPO_ROOT/supabase/migrations/" 2>/dev/null \
        | xargs grep -l "$table_name" 2>/dev/null | grep -q .; then
      rls_found=1
    fi

    if [ "$rls_found" -eq 0 ]; then
      # Also check for CREATE POLICY ... ON <table>
      if grep -ril "CREATE POLICY" "$REPO_ROOT/supabase/migrations/" 2>/dev/null \
          | xargs grep -li "ON.*${table_name}\b\|ON ${table_name}" 2>/dev/null | grep -q .; then
        rls_found=1
      fi
    fi

    if [ "$rls_found" -eq 0 ]; then
      subject_key="rls-missing:${table_name}:${mig_rel}"
      desc="Table \`${table_name}\` created in \`${mig_rel}\` without RLS policy."
      SIGNALS+=("rls-missing"$'\t'"$subject_key"$'\t'"$mig_rel"$'\t'"$desc")
    fi
  done < <(grep -ioE 'CREATE TABLE[[:space:]]+(IF NOT EXISTS[[:space:]]+)?([a-z_]+)' \
    "$mig_abs" 2>/dev/null \
    | grep -ioE '[a-z_]+$' || true)
done

# ---- Check 2: Edge Functions without Auth ------------------------------------
FUNCTION_FILES=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  FUNCTION_FILES+=("$f")
done < <(git -C "$REPO_ROOT" diff origin/main...HEAD --name-only \
  -- 'supabase/functions/*/index.ts' 2>/dev/null || true)

for fn_rel in "${FUNCTION_FILES[@]+"${FUNCTION_FILES[@]}"}"; do
  fn_abs="$REPO_ROOT/$fn_rel"
  [ -f "$fn_abs" ] || continue

  uses_service_role=0
  has_serve=0
  has_auth_check=0

  # Check for service_role key usage
  grep -q "SUPABASE_SERVICE_ROLE_KEY" "$fn_abs" 2>/dev/null && uses_service_role=1

  # Check for Deno.serve pattern
  grep -q "Deno\.serve\|serve(" "$fn_abs" 2>/dev/null && has_serve=1

  # Check for auth header verification
  grep -qE "req\.headers\.get\(['\"]Authorization|authHeader|auth_header|Authorization" \
    "$fn_abs" 2>/dev/null && has_auth_check=1

  # Signal if: uses service_role without auth-check OR has serve without auth-check
  if [ "$has_auth_check" -eq 0 ] && { [ "$uses_service_role" -eq 1 ] || [ "$has_serve" -eq 1 ]; }; then
    subject_key="fn-no-auth:${fn_rel}"
    desc="Edge Function \`${fn_rel}\` has no Authorization-header check (service_role=${uses_service_role}, serve=${has_serve})."
    SIGNALS+=("fn-no-auth"$'\t'"$subject_key"$'\t'"$fn_rel"$'\t'"$desc")
  fi
done

# ---------------------------------------------------------------------------
# No signals → done
# ---------------------------------------------------------------------------
if [ "${#SIGNALS[@]}" -eq 0 ]; then
  printf '[scan-security-drift] No security drift found. Done.\n'
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(
      _iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Process signals — dedup, cap, write items
# ---------------------------------------------------------------------------
NOW_ISO="$(_iso_now)"
ITEMS_WRITTEN=0

for signal in "${SIGNALS[@]+"${SIGNALS[@]}"}"; do
  [ "$ITEMS_WRITTEN" -ge "$MAX_ITEMS" ] && break

  IFS=$'\t' read -r drift_type subject_key sig_file description <<< "$signal"

  # Dedup: skip if already seen
  hash_input="${subject_key}${MODULE_NAME}"
  full_hash="$(_sha256 "$hash_input")"
  sha8="$(_sha8 "$hash_input")"

  already_seen="$(_state_has_subject "$full_hash")"
  if [ "$already_seen" = "1" ]; then
    printf '[scan-security-drift] SKIP (dedup): %s\n' "$subject_key"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] Would generate item for %s (type=%s, hash=%s)\n' \
      "$sig_file" "$drift_type" "$sha8"
    ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
    _state_add_subject "$full_hash" "$subject_key" "$drift_type" "$sig_file"
    continue
  fi

  # Determine required action based on drift type
  if [ "$drift_type" = "rls-missing" ]; then
    required_action="Required: RLS-Policy hinzufügen — \`ALTER TABLE <name> ENABLE ROW LEVEL SECURITY\` + \`CREATE POLICY\`."
    title="Security: Tabelle ohne RLS-Policy"
  else
    required_action="Required: Auth-Check ergänzen — \`req.headers.get('Authorization')\` prüfen und bei fehlendem/ungültigem Token mit HTTP 401 ablehnen."
    title="Security: Edge Function ohne Auth-Check"
  fi

  # Write item
  mkdir -p "$INBOX_DIR"
  item_file="$INBOX_DIR/00-security-drift-${sha8}.md"

  cat > "$item_file" <<EOF
---
slug: security-drift-${sha8}
source: tier-3
priority: 0
budget_usd: 4.0
model: opus
touches: [${sig_file}]
needs_gh: false
needs_dispute: true
estimated_minutes: 60
created_from: ${MODULE_NAME}
trust_tier: 3
---

## ${title}

${description}

${required_action}

## Acceptance

- Drift behoben: RLS aktiv oder Auth-Check vorhanden.
- \`supabase db reset\` läuft erfolgreich (bei RLS-Änderung).
- \`dart analyze\` / Linter clean.
- Kein Regression in bestehenden Tests.
EOF

  printf '[scan-security-drift] Item written: %s\n' "$item_file"
  _audit "item-created" "$sig_file" "drift_type=$drift_type hash=$full_hash item=$item_file"
  _notify_info "Security drift detected ($drift_type): $sig_file"
  _state_add_subject "$full_hash" "$subject_key" "$drift_type" "$sig_file"
  ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
done

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"

[ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"

printf '[scan-security-drift] Done. Items generated: %d\n' "$ITEMS_WRITTEN"
