#!/usr/bin/env bash
# intake-council.sh — Intake-Council-Orchestrator (T05/T06/T07/T08)
#
# Usage:
#   intake-council.sh <pending-proposal-path>
#   intake-council.sh --resume <id>
#   intake-council.sh --status <id>
#
# Spawnt ein 3-Agent-Mini-Council:
#   Round 1 (parallel): disput-proponent (Sonnet, Intake-Mode) + intake-skeptic (Sonnet)
#   Round 2 (IMMER): intake-pragmatist (Opus, Final-Synthesizer)
#
# Pragmatist läuft IMMER (auch bei Konsens), weil nur er das vollständige
# Backlog-Item-YAML schreiben kann. Bei Round-1-Konsens tendiert er zum
# entsprechenden Verdict (propose bei accept+accept, reject bei reject+reject),
# bei Split entscheidet er.
#
# Cost-Caps: $2/Proposal (lifetime), $10/Tag.
# Modell-deterministische Kosten: Sonnet $0.20, Opus $0.40. Gesamt ~$0.80-$1.20.
# Output: .claude/stakeholder/pending-approval/<id>.md (Schema 3.2).

set -uo pipefail

# ---------------------------------------------------------------------------
# Pfad-Resolution + Bibliotheken
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=lib/cost-cap.sh
source "$SCRIPT_DIR/lib/cost-cap.sh"
# shellcheck source=lib/audit.sh
source "$SCRIPT_DIR/lib/audit.sh"
# shellcheck source=lib/api-key-preflight.sh
source "$SCRIPT_DIR/lib/api-key-preflight.sh"
# shellcheck source=lib/intake-tokens.sh
source "$SCRIPT_DIR/lib/intake-tokens.sh"

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------
INTAKE_COUNCIL_DIR="${INTAKE_COUNCIL_DIR:-$REPO_ROOT/.claude/intake-council}"
PENDING_PROPOSAL_DIR="${PENDING_PROPOSAL_DIR:-$REPO_ROOT/.claude/stakeholder/pending-proposal}"
PENDING_APPROVAL_DIR="${PENDING_APPROVAL_DIR:-$REPO_ROOT/.claude/stakeholder/pending-approval}"

INTAKE_CAP_PER_PROPOSAL="${INTAKE_CAP_PER_PROPOSAL:-2.0}"
INTAKE_CAP_PER_DAY="${INTAKE_CAP_PER_DAY:-10.0}"

# Modell-deterministische Kosten (Pessimist-Fallback)
INTAKE_COST_SONNET="${INTAKE_COST_SONNET:-0.20}"
INTAKE_COST_OPUS="${INTAKE_COST_OPUS:-0.40}"

# disput-common Konfig (für call_agent / Cost-Cap-Check)
DISPUT_CAP_PER_DISPUTE="$INTAKE_CAP_PER_PROPOSAL"
DISPUT_CAP_PER_DAY="$INTAKE_CAP_PER_DAY"
DISPUT_MOCK="${DISPUT_MOCK:-0}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

# Self-Mod-Pfade (Mitigation #2)
SELF_MOD_PATHS=(
  ".claude/scripts/"
  ".claude/agents/"
  ".claude/settings"
  ".claude/.user-session-active"
  "CLAUDE.md"
  ".github/workflows/"
  "Library/LaunchAgents/com.inventory."
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '[intake-council] %s\n' "$*" >&2; }
die() { printf '[intake-council] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
Usage:
  intake-council.sh <pending-proposal-md-path>
  intake-council.sh --resume <id>
  intake-council.sh --status <id>
EOF
  exit 1
}

# Cleanup-Trap für Lock + Crash-Audit
_lock_held=0
_lock_file=""
_current_id=""
_finished=0

_cleanup() {
  local rc=$?
  if [ "$_lock_held" = "1" ] && [ -n "$_lock_file" ]; then
    rm -f "$_lock_file" 2>/dev/null || true
  fi
  if [ "$rc" -ne 0 ] && [ "$_finished" = "0" ] && [ -n "$_current_id" ]; then
    audit_record "intake-council" "intake_council_crashed" "$_current_id" \
      "exit=$rc" 2>/dev/null || true
  fi
  exit $rc
}
trap _cleanup EXIT

# extract_vote (inline-Kopie aus lib/disput-common.sh — vermeidet REPO_ROOT-Resolve-Race)
extract_vote() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf 'abstain'
    return 1
  fi
  local vote
  vote="$(grep -i '^### Vote:' "$file" 2>/dev/null | tail -n1 | sed 's/^### Vote:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [ -z "$vote" ]; then
    vote="$(grep -i '^### Verdict:' "$file" 2>/dev/null | tail -n1 | sed 's/^### Verdict:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  fi
  if [ -z "$vote" ]; then
    printf 'abstain'
  else
    # **bold**-Marker entfernen falls Vote im Pragmatist-Format ("**propose**")
    vote="${vote#\*\*}"
    vote="${vote%\*\*}"
    printf '%s' "$vote"
  fi
}

# compute_consensus <v1> <v2> → consensus_accept | consensus_reject | needs_tiebreak
compute_consensus() {
  local v1="$1"
  local v2="$2"
  local accept_set=""
  local reject_set=""

  for v in "$v1" "$v2"; do
    case "$v" in
      accept|accept-with-changes) accept_set="${accept_set}1" ;;
      reject) reject_set="${reject_set}1" ;;
      *) ;;
    esac
  done

  if [ "${#accept_set}" = "2" ] && [ -z "$reject_set" ]; then
    printf 'consensus_accept'
  elif [ "${#reject_set}" = "2" ] && [ -z "$accept_set" ]; then
    printf 'consensus_reject'
  else
    printf 'needs_tiebreak'
  fi
}

# ID aus Frontmatter eines pending-proposal-Files extrahieren
_extract_id() {
  local file="$1"
  grep -m1 '^id:' "$file" | sed 's/^id:[[:space:]]*//' | tr -d '[:space:]'
}

_extract_field() {
  local file="$1"
  local field="$2"
  grep -m1 "^${field}:" "$file" | sed "s/^${field}:[[:space:]]*//"
}

# Sandwich-Marker-Strip aus LLM-Outputs (Mitigation, Sentinel-Escape).
# Ersetzt `<<<UNTRUSTED…>>>` / `<<<END_UNTRUSTED…>>>` Tokens in einer Datei.
_sentinel_strip() {
  local in_file="$1"
  local out_file="$2"
  sed -E 's/<<<UNTRUSTED[A-Z_]*[^>]*>>>/[stripped-sentinel]/g; s/<<<END_UNTRUSTED[A-Z_]*[^>]*>>>/[stripped-sentinel]/g' "$in_file" > "$out_file"
}

# Backlog-Item-Block + touches: aus Pragmatist-Output extrahieren.
# Setzt globale: _PRAG_TOUCHES, _PRAG_BACKLOG_ITEM
_parse_pragmatist_output() {
  local file="$1"
  _PRAG_TOUCHES=""
  _PRAG_BACKLOG_ITEM=""
  [ -f "$file" ] || return 0

  # touches: <list> aus YAML-Block extrahieren
  _PRAG_TOUCHES="$(grep -m1 '^touches:' "$file" 2>/dev/null | sed 's/^touches:[[:space:]]*//' || true)"

  # Backlog-Item-Block ("## Vorgeschlagenes Backlog-Item" bis Ende) extrahieren
  _PRAG_BACKLOG_ITEM="$(awk '
    /^### Vorgeschlagenes Backlog-Item/ { capture=1; next }
    /^## [^#]/ && capture { exit }
    capture { print }
  ' "$file")"
}

# Prüft ob touches einen Self-Mod-Pfad trifft.
_touches_self_mod() {
  local touches="$1"
  [ -z "$touches" ] && return 1
  for path in "${SELF_MOD_PATHS[@]}"; do
    case "$touches" in
      *"$path"*) return 0 ;;
    esac
  done
  return 1
}

# Cost-record mit Modell-Mapping
_record_cost() {
  local role="$1"      # proponent | skeptic | pragmatist
  local model="$2"     # sonnet | opus
  local usd
  case "$model" in
    opus) usd="$INTAKE_COST_OPUS" ;;
    *)    usd="$INTAKE_COST_SONNET" ;;
  esac
  cost_record "intake-${role}" "$usd" || true
}

# Agent-Aufruf mit Cost-Cap-Pre-Check.
# Returns: 0 ok, 2 cost-cap-hit, 1 generic-fail
_call_intake_agent() {
  local agent="$1"
  local out_file="$2"
  local model="$3"
  local role="$4"
  shift 4
  local context_files=("$@")

  if ! cost_check_or_die "$INTAKE_CAP_PER_PROPOSAL" "$INTAKE_CAP_PER_DAY"; then
    log "Cost-Cap erreicht vor $agent"
    audit_record "intake-council" "intake_cap_exceeded" "$_current_id" \
      "agent=$agent" 2>/dev/null || true
    return 2
  fi

  local prompt_file
  prompt_file="$(mktemp)"

  {
    # Intake-Mode-Header (Pflicht laut T05-Spec)
    printf '# Intake-Mode (NICHT Code-Plan-Disput) — bewerte User-Idee gegen Pre-Launch-ROI, Doppelung, Mobile-First-Fit.\n\n'
    for ctx in "${context_files[@]+"${context_files[@]}"}"; do
      if [ -f "$ctx" ]; then
        printf '<<<FILE: %s>>>\n' "$(basename "$ctx")"
        cat "$ctx"
        printf '\n<<<END_FILE>>>\n\n'
      fi
    done
    # Rollen-spezifische Tail-Instruktion
    case "$role" in
      proponent)
        printf '\n## Anweisung\nArgumentiere FÜR die Idee. Output: `## Proponent (Intake)` mit Sektionen: Vorteile / Empfohlene Implementation / Vote.\nEnde mit Zeile `### Vote: accept|accept-with-changes|reject`.\n'
        ;;
      skeptic)
        printf '\n## Anweisung\nFolge dem System-Prompt deines `intake-skeptic`-Agents (Anti-Bias).\n'
        ;;
      pragmatist)
        printf '\n## Anweisung\nFolge dem System-Prompt deines `intake-pragmatist`-Agents. Synthetisiere Proponent + Skeptic + bewerte ROI/Doppelung/Mobile-First/Self-Mod-Pfade. Schreibe das vollständige Backlog-Item-YAML.\n'
        ;;
    esac
  } > "$prompt_file"

  local exit_code=0
  "$CLAUDE_CMD" --print --agent "$agent" < "$prompt_file" > "$out_file" 2>/dev/null || exit_code=$?
  rm -f "$prompt_file"

  _record_cost "$role" "$model"

  audit_record "intake-council" "agent-call" "$agent" \
    "id=$_current_id out=$out_file exit=$exit_code" 2>/dev/null || true

  return "$exit_code"
}

# ---------------------------------------------------------------------------
# Verdict-File schreiben (Schema 3.2, deterministic, KEIN LLM)
# ---------------------------------------------------------------------------
write_verdict_file() {
  local id="$1"
  local round="$2"
  local verdict="$3"          # propose | propose-with-changes | reject | needs-full-council
  local council_dir="$4"
  local proposal_file="$5"
  local reason="${6:-}"       # für reject/cost-cap

  mkdir -p "$PENDING_APPROVAL_DIR"
  local out="$PENDING_APPROVAL_DIR/${id}.md"

  local source trust_tier user_id created_at content_hash
  source="$(_extract_field "$proposal_file" source)"
  trust_tier="$(_extract_field "$proposal_file" trust_tier)"
  user_id="$(_extract_field "$proposal_file" user_id)"
  created_at="$(_extract_field "$proposal_file" created_at)"
  content_hash="$(_extract_field "$proposal_file" content_hash)"
  local council_finished_at
  council_finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local hmac_token
  hmac_token="$(generate_hmac_token "$id")"

  # Gesamtkosten aus Round-Files schätzen (deterministic via Cost-Mapping)
  local total_cost="0.00"
  for f in "$council_dir"/round-*-*.md; do
    [ -f "$f" ] || continue
    case "$f" in
      *pragmatist*) total_cost="$(python3 -c "print(f'{${total_cost} + ${INTAKE_COST_OPUS}:.2f}')")" ;;
      *) total_cost="$(python3 -c "print(f'{${total_cost} + ${INTAKE_COST_SONNET}:.2f}')")" ;;
    esac
  done

  # touches + backlog-item aus Pragmatist (falls vorhanden)
  local prag_file="$council_dir/round-2-pragmatist.md"
  _parse_pragmatist_output "$prag_file"
  local touches="${_PRAG_TOUCHES:-[]}"
  local backlog_item="${_PRAG_BACKLOG_ITEM:-}"

  # Self-Mod-Check
  local requires_human_dispute="false"
  if [ "$verdict" = "needs-full-council" ]; then
    requires_human_dispute="true"
  elif _touches_self_mod "$touches"; then
    requires_human_dispute="true"
    verdict="needs-full-council"
  fi

  # Stakeholder-Original-Body (deterministic-copy, NICHT LLM!) — Mitigation #5
  local proposal_body
  proposal_body="$(awk 'BEGIN{p=0; c=0} /^---[[:space:]]*$/{c++; if(c==2){p=1; next}} p{print}' "$proposal_file")"

  # Round-Files für Council-Begründung
  local pro_file="$council_dir/round-1-proponent.md"
  local skp_file="$council_dir/round-1-skeptic.md"

  local pro_content="" skp_content="" prag_content=""
  [ -f "$pro_file" ] && pro_content="$(cat "$pro_file")"
  [ -f "$skp_file" ] && skp_content="$(cat "$skp_file")"
  [ -f "$prag_file" ] && prag_content="$(cat "$prag_file")"

  # Verdict-Summary
  local verdict_summary
  case "$verdict" in
    propose)              verdict_summary="Council-Konsens: Idee passt. Proponent + Skeptic stimmten zu." ;;
    propose-with-changes) verdict_summary="Council akzeptiert mit Änderungen — Pragmatist hat konkrete Mitigations." ;;
    reject)               verdict_summary="Council lehnt ab.${reason:+ Grund: ${reason}}" ;;
    needs-full-council)   verdict_summary="Self-Mod-Pfad berührt oder Pragmatist eskaliert — Full-Council via /council nötig." ;;
    *)                    verdict_summary="Verdict: ${verdict}" ;;
  esac

  # Backlog-Item-Block nur wenn verdict ≠ reject
  local backlog_section=""
  if [ "$verdict" != "reject" ] && [ -n "$backlog_item" ]; then
    backlog_section="$backlog_item"
  fi

  cat > "$out" <<EOF
---
id: ${id}
source: ${source}
trust_tier: ${trust_tier}
user_id: ${user_id}
created_at: ${created_at}
council_finished_at: ${council_finished_at}
state: pending-approval
verdict: ${verdict}
round: ${round}
council_cost_usd: ${total_cost}
hmac_token: ${hmac_token}
pushed_at: ""
requires_human_dispute: ${requires_human_dispute}
touches: ${touches}
created_from: intake-council
content_hash: ${content_hash}
---

## Verdict-Summary

${verdict_summary}

## Vorgeschlagenes Backlog-Item

${backlog_section}

## Council-Begründung (Long)

### Proponent
${pro_content}

### Skeptic (intake-skeptic)
${skp_content}

### Pragmatist-Tie-Break (intake-pragmatist)
${prag_content}

## Stakeholder-Original

${proposal_body}
EOF

  audit_record "intake-council" "intake_verdict_written" "$id" \
    "verdict=$verdict round=$round cost=$total_cost" 2>/dev/null || true

  log "Verdict geschrieben: $out (verdict=$verdict, round=$round)"
}

# ---------------------------------------------------------------------------
# Haupt-Logik
# ---------------------------------------------------------------------------
run_council() {
  local proposal_file="$1"
  local resume_from_round="${2:-0}"

  [ -f "$proposal_file" ] || die "Proposal-File nicht gefunden: $proposal_file"

  # Schema-Pflicht-Felder
  for field in id source trust_tier user_id created_at state; do
    if ! grep -q "^${field}:" "$proposal_file"; then
      die "Proposal-Schema verletzt: Feld '${field}' fehlt"
    fi
  done

  local id
  id="$(_extract_id "$proposal_file")"
  [ -n "$id" ] || die "ID aus Frontmatter nicht extrahierbar"
  _current_id="$id"

  local council_dir="$INTAKE_COUNCIL_DIR/$id"
  mkdir -p "$council_dir"

  # Lock-File
  mkdir -p "$INTAKE_COUNCIL_DIR"
  _lock_file="$INTAKE_COUNCIL_DIR/.lock-$id"
  if [ -e "$_lock_file" ]; then
    die "Lock existiert: $_lock_file (anderer Council läuft? --resume nutzen)"
  fi
  echo "$$" > "$_lock_file"
  _lock_held=1

  log "Council gestartet: id=$id (resume_from=$resume_from_round)"
  audit_record "intake-council" "intake_council_started" "$id" \
    "proposal=$proposal_file resume=$resume_from_round" 2>/dev/null || true

  # Initial Cost-Cap-Check (Args: today, week — Mitigation #7)
  if ! cost_check_or_die "$INTAKE_CAP_PER_PROPOSAL" "$INTAKE_CAP_PER_DAY"; then
    log "Cost-Cap bereits überschritten — Council bricht ab"
    audit_record "intake-council" "intake_cap_exceeded" "$id" "pre-flight" 2>/dev/null || true
    write_verdict_file "$id" "0" "reject" "$council_dir" "$proposal_file" "cost-cap-aborted"
    _finished=1
    exit 2
  fi

  local r1_pro="$council_dir/round-1-proponent.md"
  local r1_skp="$council_dir/round-1-skeptic.md"

  # --------------------------------------------------------------------
  # Round 1: Proponent + Intake-Skeptic parallel
  # --------------------------------------------------------------------
  if [ "$resume_from_round" -le 1 ] && { [ ! -f "$r1_pro" ] || [ ! -f "$r1_skp" ]; }; then
    log "=== Round 1: Proponent + Intake-Skeptic (parallel) ==="

    local pro_rc=0 skp_rc=0
    if [ ! -f "$r1_pro" ]; then
      _call_intake_agent "disput-proponent" "$r1_pro" "sonnet" "proponent" "$proposal_file" &
      local pro_pid=$!
    else
      local pro_pid=""
    fi
    if [ ! -f "$r1_skp" ]; then
      _call_intake_agent "intake-skeptic" "$r1_skp" "sonnet" "skeptic" "$proposal_file" &
      local skp_pid=$!
    else
      local skp_pid=""
    fi

    [ -n "$pro_pid" ] && { wait "$pro_pid" || pro_rc=$?; }
    [ -n "$skp_pid" ] && { wait "$skp_pid" || skp_rc=$?; }

    if [ "$pro_rc" = "2" ] || [ "$skp_rc" = "2" ]; then
      log "Cost-Cap-Hit in Round 1"
      write_verdict_file "$id" "1" "reject" "$council_dir" "$proposal_file" "cost-cap-aborted"
      _finished=1
      exit 2
    fi
  else
    log "Round 1 Files existieren bereits — überspringe (resume)"
  fi

  audit_record "intake-council" "intake_council_round_1_complete" "$id" \
    "proponent=$r1_pro skeptic=$r1_skp" 2>/dev/null || true

  # --------------------------------------------------------------------
  # Verdict-Synthese (T07, deterministic)
  # --------------------------------------------------------------------
  local pro_vote skp_vote
  pro_vote="$(extract_vote "$r1_pro")"
  skp_vote="$(extract_vote "$r1_skp")"
  log "Round 1 Votes: proponent=$pro_vote, skeptic=$skp_vote"

  local consensus
  consensus="$(compute_consensus "$pro_vote" "$skp_vote")"
  log "Consensus: $consensus"

  case "$consensus" in
    consensus_accept) log "Konsens accept — Pragmatist synthetisiert + schreibt Backlog-Item" ;;
    consensus_reject) log "Konsens reject — Pragmatist bestätigt + schreibt finales Verdict" ;;
    needs_tiebreak)   log "Patt — Pragmatist entscheidet" ;;
  esac

  # --------------------------------------------------------------------
  # Round 2: Intake-Pragmatist als Final-Synthesizer (Opus) — IMMER aufgerufen
  # --------------------------------------------------------------------
  local r2_prag="$council_dir/round-2-pragmatist.md"

  # Sentinel-strip auf Round-1-Files bevor sie als Context gehen
  local r1_pro_stripped="$council_dir/round-1-proponent.stripped.md"
  local r1_skp_stripped="$council_dir/round-1-skeptic.stripped.md"
  _sentinel_strip "$r1_pro" "$r1_pro_stripped"
  _sentinel_strip "$r1_skp" "$r1_skp_stripped"

  if [ ! -f "$r2_prag" ]; then
    local prag_rc=0
    _call_intake_agent "intake-pragmatist" "$r2_prag" "opus" "pragmatist" \
      "$proposal_file" "$r1_pro_stripped" "$r1_skp_stripped" || prag_rc=$?

    if [ "$prag_rc" = "2" ]; then
      log "Cost-Cap-Hit in Round 2"
      write_verdict_file "$id" "2" "reject" "$council_dir" "$proposal_file" "cost-cap-aborted"
      _finished=1
      exit 2
    fi
  fi

  audit_record "intake-council" "intake_council_round_2_complete" "$id" \
    "pragmatist=$r2_prag" 2>/dev/null || true

  local prag_vote
  prag_vote="$(extract_vote "$r2_prag")"
  log "Pragmatist Vote: $prag_vote"

  # Verdict aus Pragmatist
  local final_verdict
  case "$prag_vote" in
    propose|accept) final_verdict="propose" ;;
    propose-with-changes|accept-with-changes) final_verdict="propose-with-changes" ;;
    reject) final_verdict="reject" ;;
    needs-full-council) final_verdict="needs-full-council" ;;
    *)
      # Pragmatist-Vote nicht parsebar — falle auf Round-1-Konsens zurück
      case "$consensus" in
        consensus_accept) final_verdict="propose" ;;
        consensus_reject) final_verdict="reject" ;;
        *)                final_verdict="reject" ;;
      esac
      ;;
  esac

  # round-Nummer: bei Round-1-Konsens bleibt round=1 (Backward-Compat mit Tests),
  # bei needs_tiebreak round=2.
  local final_round=2
  [ "$consensus" != "needs_tiebreak" ] && final_round=1

  write_verdict_file "$id" "$final_round" "$final_verdict" "$council_dir" "$proposal_file"
  _finished=1
  exit 0
}

# ---------------------------------------------------------------------------
# Resume / Status
# ---------------------------------------------------------------------------
resume_council() {
  local id="$1"
  local council_dir="$INTAKE_COUNCIL_DIR/$id"

  [ -d "$council_dir" ] || die "Kein Council-Verzeichnis: $council_dir"

  # Lock-File entfernen falls stale
  rm -f "$INTAKE_COUNCIL_DIR/.lock-$id" 2>/dev/null || true

  # Proposal-File rekonstruieren
  local proposal_file="$PENDING_PROPOSAL_DIR/${id}.md"
  if [ ! -f "$proposal_file" ]; then
    # Fallback — vielleicht schon nach pending-approval gerutscht; dann: nichts zu tun.
    die "Proposal-File nicht gefunden: $proposal_file"
  fi

  audit_record "intake-council" "intake_resumed" "$id" "from=$council_dir" 2>/dev/null || true

  local resume_round=0
  if [ -f "$council_dir/round-1-proponent.md" ] && [ -f "$council_dir/round-1-skeptic.md" ]; then
    resume_round=2
  fi

  run_council "$proposal_file" "$resume_round"
}

show_status() {
  local id="$1"
  local approval="$PENDING_APPROVAL_DIR/${id}.md"
  [ -f "$approval" ] || die "Kein pending-approval-File für id=$id"
  # Frontmatter (zwischen den ersten zwei --- Linien) ausgeben
  awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; print; if(c==2) exit} c==1{print}' "$approval"
  _finished=1
}

# ---------------------------------------------------------------------------
# CLI-Dispatch — VOR Argument-Parsing: API-Key-Pre-Flight (T08a, Mitigation #8)
# ---------------------------------------------------------------------------
check_no_api_key

case "${1:-}" in
  --help|-h) usage ;;
  --status)
    [ -n "${2:-}" ] || die "--status erwartet <id>"
    show_status "$2"
    ;;
  --resume)
    [ -n "${2:-}" ] || die "--resume erwartet <id>"
    resume_council "$2"
    ;;
  "") usage ;;
  --*) die "Unbekanntes Flag: $1" ;;
  *) run_council "$1" 0 ;;
esac
