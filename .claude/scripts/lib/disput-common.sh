#!/usr/bin/env bash
# lib/disput-common.sh — Sourceable Disput-Helper-Library
#
# Wird von disput.sh und intake-council.sh verwendet.
# Stellt bereit:
#   extract_vote <file>
#   call_agent <agent-name> <output-file> <context-files...>
#   compute_consensus <vote1> [vote2 ...]
#   write_round_file <disput-id> <round-num> <agent-name> <content>
#   disput_cost_record <role> <usd>
#
# Voraussetzungen (müssen vor dem Source gesetzt sein):
#   SCRIPT_DIR         — Verzeichnis des aufrufenden Skripts
#   DISPUTES_DIR       — Basisverzeichnis für Dispute (oder INTAKE_COUNCIL_DIR)
#   COST_PER_AGENT_CALL
#   DISPUT_CAP_PER_DISPUTE
#   DISPUT_CAP_PER_DAY
#   CLAUDE_CMD         — Pfad zu claude (default: claude)
#   DISPUT_MOCK        — 0/1 (default: 0)
#   DISPUT_ID          — aktuell laufende Disput-ID (optional, für cost.log)

# Testability: erlaubt PATH-Prepend für Mock-claude in Tests
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
DISPUT_MOCK="${DISPUT_MOCK:-0}"

# ---------------------------------------------------------------------------
# extract_vote <file>
# ---------------------------------------------------------------------------
# Parsed letzte "### Vote: <decision>" oder "### Verdict: <decision>" Zeile
# aus einem Agent-Markdown-Output. Gibt decision (lowercased, getrimmed) auf
# stdout aus. Gibt "abstain" zurück wenn keine Vote/Verdict-Zeile gefunden.
# Exit 1 wenn file nicht existiert.
extract_vote() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf 'abstain'
    return 1
  fi
  local vote
  vote="$(grep -i '^### Vote:' "$file" | tail -n1 | sed 's/^### Vote:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [ -z "$vote" ]; then
    # Fallback: check "### Verdict:"
    vote="$(grep -i '^### Verdict:' "$file" | tail -n1 | sed 's/^### Verdict:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  fi
  if [ -z "$vote" ]; then
    printf 'abstain'
  else
    printf '%s' "$vote"
  fi
}

# ---------------------------------------------------------------------------
# check_consensus <vote1> <vote2>
# ---------------------------------------------------------------------------
# Prüft ob zwei Votes Konsens ergeben.
# Gibt "consensus <verdict>" oder "no-consensus" aus.
check_consensus() {
  local pv="$1"
  local sv="$2"

  if [ "$pv" = "accept" ] && [ "$sv" = "accept" ]; then
    printf 'consensus accept'; return
  fi
  if [ "$pv" = "reject" ] && [ "$sv" = "reject" ]; then
    printf 'consensus reject'; return
  fi
  if [ "$pv" = "accept" ] && [ "$sv" = "accept-with-changes" ]; then
    printf 'consensus accept-with-changes'; return
  fi
  if [ "$pv" = "accept-with-changes" ] && [ "$sv" = "accept" ]; then
    printf 'consensus accept-with-changes'; return
  fi
  if [ "$pv" = "accept-with-changes" ] && [ "$sv" = "accept-with-changes" ]; then
    printf 'consensus accept-with-changes'; return
  fi
  printf 'no-consensus'
}

# ---------------------------------------------------------------------------
# compute_consensus <vote1> [vote2 ...]
# ---------------------------------------------------------------------------
# Variadic Version: gegeben N votes, gibt:
#   "consensus_accept"          — alle accept (oder accept-with-changes)
#   "consensus_reject"          — alle reject
#   "needs_tiebreak"            — gemischt
#
# Für Rückwärtskompatibilität zu disput.sh bleibt check_consensus (2-arg) erhalten.
compute_consensus() {
  local votes=("$@")
  local has_accept=0
  local has_reject=0
  local has_other=0

  for v in "${votes[@]}"; do
    case "$v" in
      accept|accept-with-changes) has_accept=1 ;;
      reject)                     has_reject=1 ;;
      *)                          has_other=1  ;;
    esac
  done

  if [ "$has_reject" = "0" ] && [ "$has_other" = "0" ] && [ "$has_accept" = "1" ]; then
    printf 'consensus_accept'
  elif [ "$has_accept" = "0" ] && [ "$has_other" = "0" ] && [ "$has_reject" = "1" ]; then
    printf 'consensus_reject'
  else
    printf 'needs_tiebreak'
  fi
}

# ---------------------------------------------------------------------------
# is_final_verdict <verdict>
# ---------------------------------------------------------------------------
is_final_verdict() {
  case "$1" in
    accept|reject|accept-with-changes) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# call_agent <agent-name> <output-file> <context-files...>
# ---------------------------------------------------------------------------
# Wrapper um claude --print --agent. Liest context-files und übergibt sie
# als stdin-Block. Schreibt Output in output-file.
# Respektiert Mock-Stub-Pattern via PATH-Prepend / CLAUDE_CMD.
# Gibt exit-code von claude zurück.
call_agent() {
  local agent_name="$1"
  local output_file="$2"
  shift 2
  local context_files=("${@:-}")

  # Cost-Cap prüfen (cost_check_or_die muss durch aufrufendes Skript bereitgestellt werden)
  if command -v cost_check_or_die &>/dev/null; then
    if ! cost_check_or_die "${DISPUT_CAP_PER_DISPUTE:-10}" "${DISPUT_CAP_PER_DAY:-20}"; then
      printf '[disput-common] Cost-Cap erreicht vor Aufruf von %s\n' "$agent_name" >&2
      return 2
    fi
  fi

  # Prompt zusammenbauen: alle context_files lesen und als Nachricht übergeben
  local prompt_file
  prompt_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$prompt_file'" RETURN

  {
    for ctx in "${context_files[@]+"${context_files[@]}"}"; do
      if [ -f "$ctx" ]; then
        printf '<<<FILE: %s>>>\n' "$(basename "$ctx")"
        cat "$ctx"
        printf '\n<<<END_FILE>>>\n\n'
      fi
    done
  } > "$prompt_file"

  printf '[disput-common] Rufe Agent '\''%s'\'' auf → %s\n' "$agent_name" "$output_file" >&2

  local exit_code=0
  "$CLAUDE_CMD" --print --agent "$agent_name" < "$prompt_file" > "$output_file" 2>/dev/null || exit_code=$?

  # Kosten schreiben
  if command -v cost_record &>/dev/null; then
    cost_record "disput-${agent_name}" "${COST_PER_AGENT_CALL:-1.50}" || true
  fi

  # Disput-internen Cost-Log schreiben
  if [ -n "${DISPUT_ID:-}" ] && [ -n "${DISPUTES_DIR:-}" ]; then
    local cost_log="${DISPUTES_DIR}/${DISPUT_ID}/cost.log"
    printf '%s  agent=%-25s  usd=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_name" "${COST_PER_AGENT_CALL:-1.50}" \
      >> "$cost_log" 2>/dev/null || true
  fi

  # Audit-Record (optional)
  if command -v audit_record &>/dev/null; then
    audit_record "disput-orchestrator" "agent-call" "$agent_name" \
      "output=$output_file exit=$exit_code" || true
  fi

  return "$exit_code"
}

# ---------------------------------------------------------------------------
# write_round_file <disput-id> <round-num> <agent-name> <content>
# ---------------------------------------------------------------------------
# Schreibt .claude/disputes/<id>/round-<n>-<agent>.md
# Wenn INTAKE_COUNCIL_DIR gesetzt ist, schreibt nach
# .claude/intake-council/<id>/round-<n>-<agent>.md stattdessen.
write_round_file() {
  local disput_id="$1"
  local round_num="$2"
  local agent_name="$3"
  local content="$4"

  local base_dir
  if [ -n "${INTAKE_COUNCIL_DIR:-}" ]; then
    base_dir="${INTAKE_COUNCIL_DIR}/${disput_id}"
  else
    base_dir="${DISPUTES_DIR:-${REPO_ROOT:-.}/.claude/disputes}/${disput_id}"
  fi

  mkdir -p "$base_dir"
  local outfile="${base_dir}/round-${round_num}-${agent_name}.md"
  printf '%s' "$content" > "$outfile"
  printf '[disput-common] write_round_file → %s\n' "$outfile" >&2
}

# ---------------------------------------------------------------------------
# disput_cost_record <role> <usd>
# ---------------------------------------------------------------------------
# Wrapper um cost_record mit semantischem Prefix "disput-<role>".
disput_cost_record() {
  local role="$1"
  local usd="$2"
  if command -v cost_record &>/dev/null; then
    cost_record "disput-${role}" "$usd" || true
  fi
}
