#!/usr/bin/env bash
# triage-stakeholder.sh — Standalone helper: runs Triage → Validator pipeline
# for a single stakeholder inbox file.
#
# Usage: triage-stakeholder.sh <stakeholder-inbox-file>
#
# Intended for manual re-runs and tests. Does NOT require the overseer daemon.
# Uses the same pipeline logic as overseer.sh's _run_stakeholder_triage_pipeline.
#
# Exit codes:
#   0 — pipeline completed (pass or quarantine — both are valid outcomes)
#   1 — usage error or pipeline error (e.g. triage/validator agent failed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

LIB_AUDIT="${SCRIPT_DIR}/lib/audit.sh"
LIB_COST="${SCRIPT_DIR}/lib/cost-cap.sh"
NOTIFY_SH="${SCRIPT_DIR}/notify.sh"

STAKEHOLDER_DIR="${REPO_ROOT}/.claude/stakeholder"
STAKEHOLDER_TRIAGED_DIR="${STAKEHOLDER_DIR}/triaged"
STAKEHOLDER_QUARANTINE_DIR="${STAKEHOLDER_DIR}/quarantine"
STAKEHOLDER_PROCESSED_DIR="${STAKEHOLDER_DIR}/processed"
OVERSEER_INBOX_DIR="${REPO_ROOT}/.claude/overseer/inbox"

TRIAGE_BUDGET="${TRIAGE_BUDGET:-0.50}"
VALIDATOR_BUDGET="${VALIDATOR_BUDGET:-0.20}"

# ---------------------------------------------------------------------------
# Bootstrap dirs
# ---------------------------------------------------------------------------
mkdir -p "$STAKEHOLDER_TRIAGED_DIR" "$STAKEHOLDER_QUARANTINE_DIR" \
  "$STAKEHOLDER_PROCESSED_DIR" "$OVERSEER_INBOX_DIR"

# ---------------------------------------------------------------------------
# Source libraries (optional — degrade gracefully if missing)
# ---------------------------------------------------------------------------
for lib in "$LIB_AUDIT" "$LIB_COST"; do
  # shellcheck disable=SC1090
  [ -f "$lib" ] && source "$lib" || true
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_log() { printf '[triage-stakeholder %s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }

_audit() {
  if command -v audit_record >/dev/null 2>&1; then
    audit_record "triage-stakeholder" "$1" "$2" "${3:-}" 2>/dev/null || true
  fi
}

_notify() {
  local severity="$1" title="$2" body="$3"
  local topic="${NTFY_TOPIC:-claude-code}"
  if [ -x "$NOTIFY_SH" ]; then
    REPO_ROOT="$REPO_ROOT" "$NOTIFY_SH" "$severity" "$topic" "$title" "$body" >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------
_triage_slug_from_file() {
  local base
  base="$(basename "$1" .md)"
  printf '%s' "$base"
}

run_pipeline() {
  local inbox_file="$1"
  local slug
  slug="$(_triage_slug_from_file "$inbox_file")"

  _log "pipeline start: slug=$slug file=$inbox_file"
  _audit "triage_started" "$slug" "standalone=true inbox_file=$inbox_file"

  # Cost-check (soft — only log warning on hit, do not abort standalone run)
  if command -v cost_check_or_die >/dev/null 2>&1; then
    local cc_rc=0
    cost_check_or_die 20 100 >/dev/null 2>&1 || cc_rc=$?
    if [ "$cc_rc" -eq 2 ]; then
      _log "WARN: cost-cap exceeded — continuing standalone run anyway (--force-on-cap to suppress)"
    fi
  fi

  # Record triage cost
  if command -v cost_record >/dev/null 2>&1; then
    cost_record "stakeholder-triage" "$TRIAGE_BUDGET" >/dev/null 2>&1 || true
  fi

  # Run triage agent
  _log "invoking stakeholder-triage agent for slug=$slug"
  local triage_rc=0
  set +e
  claude --print --agent stakeholder-triage \
    "Process stakeholder inbox file: ${inbox_file}" \
    >/dev/null 2>&1
  triage_rc=$?
  set -e

  if [ "$triage_rc" -ne 0 ]; then
    _log "ERROR: stakeholder-triage agent failed (rc=$triage_rc) for slug=$slug"
    _audit "triage_agent_failed" "$slug" "rc=$triage_rc"
    return 1
  fi

  # Check triage output
  local triaged_file="${STAKEHOLDER_TRIAGED_DIR}/01-stakeholder-${slug}.md"
  local quarantine_triage_file="${STAKEHOLDER_QUARANTINE_DIR}/${slug}.md"
  local response_file="${STAKEHOLDER_DIR}/responses/${slug}.md"

  if [ -f "$quarantine_triage_file" ]; then
    _log "injection-attempt quarantined by triage agent: slug=$slug"
    _audit "triage_quarantined" "$slug" "injection-attempt detected by triage agent"
    _notify info "Stakeholder-Item quarantined (triage): $slug" \
      "see ${quarantine_triage_file}"
    mv "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" 2>/dev/null || \
      { cp "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" && rm -f "$inbox_file"; } || true
    _log "DONE: injection quarantined, original moved to processed/"
    return 0
  fi

  if [ -f "$response_file" ]; then
    _log "question answered for slug=$slug, response at $response_file"
    _audit "triage_question_answered" "$slug" "response=$response_file"
    mv "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" 2>/dev/null || \
      { cp "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" && rm -f "$inbox_file"; } || true
    _log "DONE: question answered, original moved to processed/"
    return 0
  fi

  if [ ! -f "$triaged_file" ]; then
    _log "ERROR: triage produced no output file for slug=$slug (expected $triaged_file)"
    _audit "triage_no_output" "$slug" "expected $triaged_file"
    return 1
  fi

  # Run validator
  _log "invoking stakeholder-validator for slug=$slug"

  if command -v cost_record >/dev/null 2>&1; then
    cost_record "stakeholder-validator" "$VALIDATOR_BUDGET" >/dev/null 2>&1 || true
  fi

  local validator_rc=0
  set +e
  claude --print --agent stakeholder-validator \
    "Validate triage output file: ${triaged_file}" \
    >/dev/null 2>&1
  validator_rc=$?
  set -e

  if [ "$validator_rc" -ne 0 ]; then
    _log "ERROR: stakeholder-validator agent failed (rc=$validator_rc) for slug=$slug"
    _audit "triage_validator_failed" "$slug" "rc=$validator_rc"
    return 1
  fi

  # Check validator decision
  local cleared_marker="${STAKEHOLDER_TRIAGED_DIR}/${slug}.cleared"
  local rejected_file="${STAKEHOLDER_QUARANTINE_DIR}/${slug}-rejected.md"
  local validator_result="unknown-quarantine"

  if [ -f "$cleared_marker" ]; then
    validator_result="passed"
    _log "validator PASS for slug=$slug — item forwarded to overseer inbox"
    rm -f "$triaged_file" "$cleared_marker" 2>/dev/null || true
  elif [ -f "$rejected_file" ]; then
    validator_result="quarantined"
    _log "validator QUARANTINE for slug=$slug — see $rejected_file"
    _notify info "Stakeholder-Item quarantined: $slug" "see ${rejected_file}"
    rm -f "$triaged_file" 2>/dev/null || true
  else
    _log "WARN: validator produced no recognised output for slug=$slug — treating as quarantine"
    _audit "triage_validator_no_output" "$slug" "expected cleared or rejected marker"
  fi

  _audit "triage_validated" "$slug" "$validator_result"

  # Move original to processed
  mv "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" 2>/dev/null || \
    { cp "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" && rm -f "$inbox_file"; } || true

  _log "DONE: slug=$slug result=$validator_result original moved to processed/"
  return 0
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  printf 'Usage: %s <stakeholder-inbox-file>\n' "$(basename "$0")"
  printf '  Runs Triage → Validator pipeline for a single stakeholder inbox file.\n'
  printf '  REPO_ROOT, TRIAGE_BUDGET, VALIDATOR_BUDGET can be overridden via env.\n'
  exit 0
fi

if [ $# -lt 1 ]; then
  printf 'Usage: %s <stakeholder-inbox-file>\n' "$(basename "$0")" >&2
  exit 1
fi

INBOX_FILE="$1"

if [ ! -f "$INBOX_FILE" ]; then
  printf 'ERROR: File not found: %s\n' "$INBOX_FILE" >&2
  exit 1
fi

run_pipeline "$INBOX_FILE"
