#!/usr/bin/env bash
# disput.sh — Disput-Orchestrator (P3-2)
#
# Usage:
#   disput.sh <proposal-md-path>           — Startet neuen Disput
#   disput.sh --resume <id>                — Resumed gecrashen Disput
#   disput.sh --status <id>                — Zeigt Verdict
#
# Spawnt Disput-Council mit 3-Runden-Cap.
# Pragmatist NUR als Tie-Break (Round 2+).
#
# Cost-Caps: $10/Disput (Hard), $20/Tag (Hard).
# Agent-Kostenpessimist: $1.50 pro Opus-Agent-Call.

set -euo pipefail

# ---------------------------------------------------------------------------
# Pfad-Resolution
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Bibliotheken laden
# shellcheck source=lib/cost-cap.sh
source "$SCRIPT_DIR/lib/cost-cap.sh"
# shellcheck source=lib/audit.sh
source "$SCRIPT_DIR/lib/audit.sh"

NOTIFY_SH="$SCRIPT_DIR/notify.sh"
# DISPUTES_DIR kann via Env überschrieben werden (für Tests in mktemp-Sandbox)
DISPUTES_DIR="${DISPUTES_DIR:-$REPO_ROOT/.claude/disputes}"
COST_PER_AGENT_CALL="${DISPUT_COST_PER_CALL:-1.50}"    # Pessimist-Fallback
DISPUT_CAP_PER_DISPUTE="${DISPUT_CAP:-10}"
DISPUT_CAP_PER_DAY="${DISPUT_CAP_DAY:-20}"

# Testability: claude-Stub via PATH-Prepend in Tests
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
log()   { printf '[disput] %s\n' "$*" >&2; }
die()   { printf '[disput] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
Usage:
  disput.sh <proposal-md-path>    — Startet neuen Disput
  disput.sh --resume <id>         — Resumed gecrashen Disput
  disput.sh --status <id>         — Zeigt Verdict-File
EOF
  exit 1
}

# Extrahiert letzten "### Vote: <value>" aus Markdown-File.
# Gibt Wert in Kleinbuchstaben aus. Gibt "abstain" zurück wenn nicht gefunden.
extract_vote() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf 'abstain'
    return
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

# Prüft ob zwei Votes Konsens ergeben.
# Gibt "consensus <verdict>" oder "no-consensus" aus.
check_consensus() {
  local pv="$1"
  local sv="$2"

  # Beide accept
  if [ "$pv" = "accept" ] && [ "$sv" = "accept" ]; then
    printf 'consensus accept'
    return
  fi
  # Beide reject
  if [ "$pv" = "reject" ] && [ "$sv" = "reject" ]; then
    printf 'consensus reject'
    return
  fi
  # proponent=accept + skeptic=accept-with-changes
  if [ "$pv" = "accept" ] && [ "$sv" = "accept-with-changes" ]; then
    printf 'consensus accept-with-changes'
    return
  fi
  # proponent=accept-with-changes + skeptic=accept
  if [ "$pv" = "accept-with-changes" ] && [ "$sv" = "accept" ]; then
    printf 'consensus accept-with-changes'
    return
  fi
  # Beide accept-with-changes
  if [ "$pv" = "accept-with-changes" ] && [ "$sv" = "accept-with-changes" ]; then
    printf 'consensus accept-with-changes'
    return
  fi

  printf 'no-consensus'
}

# Prüft ob ein Verdict-Wert ein endgültiges Ergebnis ist (kein abstain/unresolved).
is_final_verdict() {
  case "$1" in
    accept|reject|accept-with-changes) return 0 ;;
    *) return 1 ;;
  esac
}

# Ruft einen Agent via claude auf und schreibt Output in die angegebene Datei.
# Fügt Sandwich-Markers um das Proposal ein.
# Argumente: <agent-name> <output-file> <context-files...>
call_agent() {
  local agent_name="$1"
  local output_file="$2"
  shift 2
  local context_files=("$@")

  # Cost-Cap prüfen
  if ! cost_check_or_die "$DISPUT_CAP_PER_DISPUTE" "$DISPUT_CAP_PER_DAY"; then
    log "Cost-Cap erreicht vor Aufruf von $agent_name"
    return 2
  fi

  # Prompt zusammenbauen: alle context_files lesen und als Nachricht übergeben
  local prompt_file
  prompt_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$prompt_file'" RETURN

  {
    for ctx in "${context_files[@]}"; do
      if [ -f "$ctx" ]; then
        printf '<<<FILE: %s>>>\n' "$(basename "$ctx")"
        cat "$ctx"
        printf '\n<<<END_FILE>>>\n\n'
      fi
    done
  } > "$prompt_file"

  log "Rufe Agent '$agent_name' auf → $output_file"

  local exit_code=0
  if [ "${DISPUT_MOCK:-0}" = "1" ]; then
    # Im Test-Modus: CLAUDE_CMD ist ein Mock-Stub
    "$CLAUDE_CMD" --print --agent "$agent_name" < "$prompt_file" > "$output_file" 2>/dev/null || exit_code=$?
  else
    "$CLAUDE_CMD" --print --agent "$agent_name" < "$prompt_file" > "$output_file" 2>/dev/null || exit_code=$?
  fi

  # Kosten schreiben (Pessimist-Fallback)
  cost_record "disput-${agent_name}" "$COST_PER_AGENT_CALL" || true

  # Disput-internen Cost-Log schreiben
  if [ -n "${DISPUT_ID:-}" ]; then
    local cost_log="$DISPUTES_DIR/${DISPUT_ID}/cost.log"
    printf '%s  agent=%-25s  usd=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_name" "$COST_PER_AGENT_CALL" >> "$cost_log"
  fi

  audit_record "disput-orchestrator" "agent-call" "$agent_name" "output=$output_file exit=$exit_code" || true

  return "$exit_code"
}

# Schreibt das finale Verdict-File.
write_verdict() {
  local disput_dir="$1"
  local disput_id="$2"
  local proposal_path="$3"
  local status="$4"
  local decided_by="$5"
  local rounds="$6"
  local created_at="$7"
  local summary="$8"

  local decided_at
  decided_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Gesamtkosten aus cost.log summieren
  local total_cost="0.00"
  local cost_log="$disput_dir/cost.log"
  if [ -f "$cost_log" ]; then
    total_cost="$(awk '{sum += $NF} END {printf "%.2f", sum}' "$cost_log" 2>/dev/null || printf '0.00')"
  fi

  # Round-Summary generieren
  local round_summary=""
  for r in 1 2 3; do
    local pfile="$disput_dir/round-${r}-proponent.md"
    local sfile="$disput_dir/round-${r}-skeptic.md"
    local pragfile="$disput_dir/round-${r}-pragmatist.md"
    if [ -f "$pfile" ] || [ -f "$sfile" ] || [ -f "$pragfile" ]; then
      local pv sv pragv
      pv="$(extract_vote "$pfile" 2>/dev/null || printf 'n/a')"
      sv="$(extract_vote "$sfile" 2>/dev/null || printf 'n/a')"
      [ -f "$pfile" ] || pv="n/a"
      [ -f "$sfile" ] || sv="n/a"
      if [ -f "$pragfile" ]; then
        pragv="$(extract_vote "$pragfile" 2>/dev/null || printf 'n/a')"
        round_summary="${round_summary}- Round ${r}: proponent=${pv}, skeptic=${sv}, pragmatist=${pragv}\n"
      else
        round_summary="${round_summary}- Round ${r}: proponent=${pv}, skeptic=${sv}\n"
      fi
    fi
  done

  cat > "$disput_dir/verdict.md" <<VERDICT_EOF
---
id: ${disput_id}
proposal: ${proposal_path}
status: ${status}
decided_by: ${decided_by}
rounds: ${rounds}
total_cost_usd: ${total_cost}
created_at: ${created_at}
decided_at: ${decided_at}
---

## Verdict

${summary}

## Round-Summary

$(printf '%b' "$round_summary")
VERDICT_EOF

  log "Verdict geschrieben: $disput_dir/verdict.md (status=$status)"
}

# ---------------------------------------------------------------------------
# Haupt-Disput-Logik
# ---------------------------------------------------------------------------
# run_dispute <proposal_path> [resume_round] [existing_disput_id] [created_at]
#   resume_round: 0 = neu, 2 = starte bei Round 2, 3 = starte bei Round 3
#   existing_disput_id: wenn gesetzt, wird dieser ID verwendet (Resume-Modus)
#   created_at: ISO-Timestamp wenn aus altem Verdict übernommen
run_dispute() {
  local proposal_path="$1"
  local resume_round="${2:-0}"   # 0 = kein Resume, N = starte bei Round N
  local existing_disput_id="${3:-}"
  local existing_created_at="${4:-}"

  [ -f "$proposal_path" ] || die "Proposal-File nicht gefunden: $proposal_path"

  # Disput-ID generieren oder vorhandene nutzen
  local disput_id
  if [ -n "$existing_disput_id" ]; then
    disput_id="$existing_disput_id"
  else
    local proposal_basename
    proposal_basename="$(basename "$proposal_path" .md | head -c 30)"
    disput_id="$(date -u +%Y%m%dT%H%M%S)-${proposal_basename}"
  fi
  export DISPUT_ID="$disput_id"

  local disput_dir="$DISPUTES_DIR/$disput_id"
  mkdir -p "$disput_dir"

  local created_at
  if [ -n "$existing_created_at" ]; then
    created_at="$existing_created_at"
  else
    created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  log "Disput gestartet: $disput_id"
  log "Proposal: $proposal_path"
  audit_record "disput-orchestrator" "dispute-start" "$disput_id" "proposal=$proposal_path" || true

  # Proposal-Inhalt mit Sandwich-Markers für Agents vorbereiten
  local sandwiched_proposal="$disput_dir/proposal-sandwiched.md"
  # Nur erstellen wenn noch nicht vorhanden (Resume-Schutz)
  if [ ! -f "$sandwiched_proposal" ]; then
    {
      printf '<<<UNTRUSTED_PROPOSAL>>>\n'
      cat "$proposal_path"
      printf '\n<<<END_UNTRUSTED>>>\n'
    } > "$sandwiched_proposal"
  fi

  local final_status=""
  local decided_by=""
  local rounds_done=0
  local verdict_summary=""

  # ---------------------------------------------------------------------------
  # Round 1: proponent + skeptic parallel (sequentiell in Bash)
  # ---------------------------------------------------------------------------
  local skip_round1=0
  [ "$resume_round" -gt 1 ] && skip_round1=1

  if [ "$skip_round1" = "0" ]; then
    log "=== Round 1: Proponent + Skeptic ==="

    local r1_pro="$disput_dir/round-1-proponent.md"
    local r1_skp="$disput_dir/round-1-skeptic.md"

    if ! call_agent "disput-proponent" "$r1_pro" "$sandwiched_proposal"; then
      log "Proponent Round 1 fehlgeschlagen oder Cost-Cap"
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "cost-cap-aborted" "orchestrator" "1" "$created_at" \
        "Disput abgebrochen: Cost-Cap vor Round-1-Proponent erreicht."
      printf 'Disput %s: cost-cap-aborted\n' "$disput_id"
      return 1
    fi

    if ! call_agent "disput-skeptic" "$r1_skp" "$sandwiched_proposal"; then
      log "Skeptic Round 1 fehlgeschlagen oder Cost-Cap"
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "cost-cap-aborted" "orchestrator" "1" "$created_at" \
        "Disput abgebrochen: Cost-Cap vor Round-1-Skeptic erreicht."
      printf 'Disput %s: cost-cap-aborted\n' "$disput_id"
      return 1
    fi

    rounds_done=1

    local pv1 sv1
    pv1="$(extract_vote "$r1_pro")"
    sv1="$(extract_vote "$r1_skp")"
    log "Round 1 Votes: proponent=$pv1, skeptic=$sv1"

    local consensus1
    consensus1="$(check_consensus "$pv1" "$sv1")"

    if [[ "$consensus1" == consensus* ]]; then
      final_status="${consensus1#consensus }"
      decided_by="consensus"
      verdict_summary="Konsens nach Round 1 erreicht: proponent=${pv1}, skeptic=${sv1}."
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "$final_status" "$decided_by" "$rounds_done" "$created_at" "$verdict_summary"
      log "Konsens nach Round 1: $final_status"
      printf 'Disput %s: %s (by %s, %d round(s))\n' "$disput_id" "$final_status" "$decided_by" "$rounds_done"
      log "Gesamtkosten: $(awk '{sum += $NF} END {printf "%.2f", sum}' "$disput_dir/cost.log" 2>/dev/null || printf '0.00') USD"
      return 0
    fi

    log "Kein Konsens nach Round 1 — Round 2 wird gestartet"
  fi

  # ---------------------------------------------------------------------------
  # Round 2: proponent + skeptic mit Round-1-Kontext, dann ggf. pragmatist
  # ---------------------------------------------------------------------------
  local skip_round2=0
  [ "$resume_round" -gt 2 ] && skip_round2=1

  if [ "$skip_round2" = "0" ]; then
    log "=== Round 2: Proponent + Skeptic (mit Kontext aus Round 1) ==="

    local r2_pro="$disput_dir/round-2-proponent.md"
    local r2_skp="$disput_dir/round-2-skeptic.md"
    local r2_prag="$disput_dir/round-2-pragmatist.md"

    local r1_pro="$disput_dir/round-1-proponent.md"
    local r1_skp="$disput_dir/round-1-skeptic.md"

    if ! call_agent "disput-proponent" "$r2_pro" "$sandwiched_proposal" "$r1_pro" "$r1_skp"; then
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "cost-cap-aborted" "orchestrator" "2" "$created_at" \
        "Disput abgebrochen: Cost-Cap vor Round-2-Proponent erreicht."
      printf 'Disput %s: cost-cap-aborted\n' "$disput_id"
      return 1
    fi

    if ! call_agent "disput-skeptic" "$r2_skp" "$sandwiched_proposal" "$r1_pro" "$r1_skp"; then
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "cost-cap-aborted" "orchestrator" "2" "$created_at" \
        "Disput abgebrochen: Cost-Cap vor Round-2-Skeptic erreicht."
      printf 'Disput %s: cost-cap-aborted\n' "$disput_id"
      return 1
    fi

    rounds_done=2

    local pv2 sv2
    pv2="$(extract_vote "$r2_pro")"
    sv2="$(extract_vote "$r2_skp")"
    log "Round 2 Votes: proponent=$pv2, skeptic=$sv2"

    local consensus2
    consensus2="$(check_consensus "$pv2" "$sv2")"

    if [[ "$consensus2" == consensus* ]]; then
      final_status="${consensus2#consensus }"
      decided_by="consensus"
      verdict_summary="Konsens nach Round 2 erreicht: proponent=${pv2}, skeptic=${sv2}."
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "$final_status" "$decided_by" "$rounds_done" "$created_at" "$verdict_summary"
      log "Konsens nach Round 2: $final_status"
      printf 'Disput %s: %s (by %s, %d round(s))\n' "$disput_id" "$final_status" "$decided_by" "$rounds_done"
      return 0
    fi

    log "Weiterhin Patt nach Round 2 — Pragmatist Tie-Break"

    if ! call_agent "disput-pragmatist" "$r2_prag" \
        "$sandwiched_proposal" "$r1_pro" "$r1_skp" "$r2_pro" "$r2_skp"; then
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "cost-cap-aborted" "orchestrator" "2" "$created_at" \
        "Disput abgebrochen: Cost-Cap vor Round-2-Pragmatist erreicht."
      printf 'Disput %s: cost-cap-aborted\n' "$disput_id"
      return 1
    fi

    local pragv2
    pragv2="$(extract_vote "$r2_prag")"
    log "Pragmatist Round 2 Verdict: $pragv2"

    if is_final_verdict "$pragv2"; then
      final_status="$pragv2"
      decided_by="pragmatist"
      verdict_summary="Pragmatist Tie-Break nach Round 2: $pragv2."
      write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
        "$final_status" "$decided_by" "$rounds_done" "$created_at" "$verdict_summary"
      log "Pragmatist entschieden nach Round 2: $final_status"
      printf 'Disput %s: %s (by %s, %d round(s))\n' "$disput_id" "$final_status" "$decided_by" "$rounds_done"
      return 0
    fi

    log "Pragmatist sagt 'unresolved' nach Round 2 — Round 3 wird gestartet"
  fi

  # ---------------------------------------------------------------------------
  # Round 3: Pragmatist erneut (mit vollständigem Kontext)
  # ---------------------------------------------------------------------------
  log "=== Round 3: Pragmatist Tie-Break (final) ==="

  local r3_prag="$disput_dir/round-3-pragmatist.md"

  local r1_pro="$disput_dir/round-1-proponent.md"
  local r1_skp="$disput_dir/round-1-skeptic.md"
  local r2_pro="$disput_dir/round-2-proponent.md"
  local r2_skp="$disput_dir/round-2-skeptic.md"
  local r2_prag="$disput_dir/round-2-pragmatist.md"

  local context_r3=()
  for f in "$sandwiched_proposal" "$r1_pro" "$r1_skp" "$r2_pro" "$r2_skp" "$r2_prag"; do
    [ -f "$f" ] && context_r3+=("$f")
  done

  if ! call_agent "disput-pragmatist" "$r3_prag" "${context_r3[@]}"; then
    write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
      "cost-cap-aborted" "orchestrator" "3" "$created_at" \
      "Disput abgebrochen: Cost-Cap vor Round-3-Pragmatist erreicht."
    printf 'Disput %s: cost-cap-aborted\n' "$disput_id"
    return 1
  fi

  rounds_done=3

  local pragv3
  pragv3="$(extract_vote "$r3_prag")"
  log "Pragmatist Round 3 Verdict: $pragv3"

  if is_final_verdict "$pragv3"; then
    final_status="$pragv3"
    decided_by="pragmatist"
    verdict_summary="Pragmatist Tie-Break nach Round 3: $pragv3."
    write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
      "$final_status" "$decided_by" "$rounds_done" "$created_at" "$verdict_summary"
    log "Pragmatist entschieden nach Round 3: $final_status"
    printf 'Disput %s: %s (by %s, %d round(s))\n' "$disput_id" "$final_status" "$decided_by" "$rounds_done"
    return 0
  fi

  # ---------------------------------------------------------------------------
  # Round 3 Patt: unresolved → disputes/unresolved/<id>/ + Stakeholder-Notify
  # ---------------------------------------------------------------------------
  log "Patt nach Round 3 — Disput unresolved → Eskalation"

  verdict_summary="Disput nach 3 Runden und Pragmatist-Tie-Break ungelöst. Stakeholder-Eskalation erforderlich."
  write_verdict "$disput_dir" "$disput_id" "$proposal_path" \
    "unresolved" "stakeholder-escalation" "$rounds_done" "$created_at" "$verdict_summary"

  # unresolved-Ordner anlegen + Symlink/Move
  local unresolved_dir="$DISPUTES_DIR/unresolved"
  mkdir -p "$unresolved_dir"
  ln -sfn "$disput_dir" "$unresolved_dir/$disput_id" 2>/dev/null || \
    cp -r "$disput_dir" "$unresolved_dir/$disput_id" 2>/dev/null || true

  # Stakeholder-Notify (info, NICHT critical — Patt ist normal)
  local notify_body="Disput '$disput_id' ungelöst nach 3 Runden. Proposal: $(basename "$proposal_path"). Manuelle Entscheidung benötigt."
  if [ -x "$NOTIFY_SH" ]; then
    "$NOTIFY_SH" "info" "${NTFY_TOPIC:-claude-code}" \
      "Disput unresolved: $disput_id" \
      "$notify_body" 2>/dev/null || true
  fi

  audit_record "disput-orchestrator" "dispute-unresolved" "$disput_id" \
    "proposal=$proposal_path rounds=3 notify=sent" || true

  printf 'Disput %s: unresolved (stakeholder-escalation, 3 rounds)\n' "$disput_id"
  log "Disput-Folder: $disput_dir"
  log "Unresolved-Link: $unresolved_dir/$disput_id"
  log "Gesamtkosten: $(awk '{sum += $NF} END {printf "%.2f", sum}' "$disput_dir/cost.log" 2>/dev/null || printf '0.00') USD"
  return 0
}

# ---------------------------------------------------------------------------
# Resume-Logik
# ---------------------------------------------------------------------------
resume_dispute() {
  local disput_id="$1"
  local disput_dir="$DISPUTES_DIR/$disput_id"

  [ -d "$disput_dir" ] || die "Disput-Folder nicht gefunden: $disput_dir"

  # Verdict schon vorhanden?
  if [ -f "$disput_dir/verdict.md" ]; then
    local existing_status
    existing_status="$(grep '^status:' "$disput_dir/verdict.md" | head -n1 | sed 's/^status:[[:space:]]*//')"
    if [ "$existing_status" != "cost-cap-aborted" ]; then
      log "Disput $disput_id hat bereits Verdict: $existing_status"
      cat "$disput_dir/verdict.md"
      return 0
    fi
    log "Vorheriger Status: cost-cap-aborted — Resume-Versuch"
  fi

  # Proposal-Pfad aus Verdict oder Disput-Folder ermitteln
  local proposal_path=""
  if [ -f "$disput_dir/verdict.md" ]; then
    proposal_path="$(grep '^proposal:' "$disput_dir/verdict.md" | head -n1 | sed 's/^proposal:[[:space:]]*//')"
  fi
  if [ -z "$proposal_path" ] || [ ! -f "$proposal_path" ]; then
    # Fallback: proposal-sandwiched.md vorhanden?
    if [ -f "$disput_dir/proposal-sandwiched.md" ]; then
      proposal_path="$disput_dir/proposal-sandwiched.md"
    else
      die "Proposal-Pfad nicht rekonstruierbar für Disput $disput_id"
    fi
  fi

  # Ermittle letzten abgeschlossenen Round
  local resume_from=1
  if [ -f "$disput_dir/round-2-skeptic.md" ]; then
    resume_from=3
  elif [ -f "$disput_dir/round-1-skeptic.md" ]; then
    resume_from=2
  fi

  log "Resume Disput $disput_id ab Round $resume_from"

  # Extrahiere created_at aus altem Verdict oder setze jetzt
  local created_at=""
  if [ -f "$disput_dir/verdict.md" ]; then
    created_at="$(grep '^created_at:' "$disput_dir/verdict.md" | head -n1 | sed 's/^created_at:[[:space:]]*//')"
  fi
  created_at="${created_at:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

  run_dispute "$proposal_path" "$resume_from" "$disput_id" "$created_at"
}

# ---------------------------------------------------------------------------
# Status anzeigen
# ---------------------------------------------------------------------------
show_status() {
  local disput_id="$1"
  local verdict_file="$DISPUTES_DIR/$disput_id/verdict.md"

  if [ ! -f "$verdict_file" ]; then
    die "Kein Verdict-File für Disput $disput_id (Pfad: $verdict_file)"
  fi

  cat "$verdict_file"
}

# ---------------------------------------------------------------------------
# CLI-Dispatch
# ---------------------------------------------------------------------------
case "${1:-}" in
  --help|-h)
    usage
    ;;
  --status)
    [ -n "${2:-}" ] || die "--status erwartet <id>"
    show_status "$2"
    ;;
  --resume)
    [ -n "${2:-}" ] || die "--resume erwartet <id>"
    resume_dispute "$2"
    ;;
  "")
    usage
    ;;
  --*)
    die "Unbekanntes Flag: $1"
    ;;
  *)
    # Normaler Modus: <proposal-md-path>
    run_dispute "$1" 0
    ;;
esac
