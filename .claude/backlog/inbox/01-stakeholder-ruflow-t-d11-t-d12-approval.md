---
slug: ruflow-t-d11-t-d12-sec-haertung-approval
priority: 1
agent: stakeholder-triage
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
requires_human_dispute: true
council_approved: 2026-05-16
---

# T-D11 + T-D12 — Sec-Härtung (Self-Mod-Pfade) — HUMAN APPROVAL REQUIRED

**STOP — diese Tasks brauchen Stakeholder-Aufmerksamkeit pro Datei-Änderung.**

Council-Verdict (2026-05-16) hat T-D11/T-D12 als Stop-Kriterium-Pflicht markiert,
ABER beide Tasks berühren Self-Mod-Blocklist-Pfade. Automatische Implementation
durch `flutter-coder` wird vom `guard-edit.sh`-Hook geblockt.

CLAUDE.md §Mensch-im-Loop-Stops Punkt 7: **"Self-Mod-Hit (Worker hat Blocklist-Pfad
gewollt)"** → System pausiert UNBEDINGT.

## Betroffene Self-Mod-Pfade

**T-D11:**
- `.claude/settings.json` — Hook-Matcher erweitern: `Bash|Edit|Write|MultiEdit|NotebookEdit|mcp__.*`
- `.claude/scripts/guard-mcp.sh` (NEU) — prüft MCP-Tool `tool_input.file_path` gegen `SELF_MOD_BLOCKLIST`
- Smoke-Test: `mcp__supabase__execute_sql` mit Path-Verstoß MUSS blockieren

**T-D12:**
- `.claude/scripts/lib/self-mod-blocklist.sh` — `integrity-check.sh` + `integrity-manifest-build.sh` aufnehmen
- `.claude/scripts/audit-backup.sh` — Off-Site-Manifest-Backup aktivieren
- Migration-Pfad dokumentieren (z.B. Session-Marker-Schutz für legitime Updates)

## Stakeholder-Decision benötigt

1. **Approval pro Datei-Touch** (CLAUDE.md §Verbotene Aktionen impliziert manuelle Bestätigung)
2. **Mit Override:** `bash .claude/scripts/session-start.sh` + Begründung in Audit-Log, dann manuelle Edit-Sessions

## Vorgeschlagener Pfad

- Branch `fix/sec-haertung-mcp-hook-matcher` erstellen
- T-D11 in einer Sitzung mit Stakeholder zusammen
- T-D12 in einer zweiten Sitzung (depends auf T-D11)
- Pro Sitzung: security-reviewer-Pass vor Commit

## Risiko bei NICHT-Implementation

Aus Council-Security-Review:
- KRITISCH: `mcp__*`-Tools umgehen Self-Mod-Guard komplett → ein bösartiges MCP-Tool kann
  in `guard-bash.sh`, `CLAUDE.md`, LaunchAgent-Plists schreiben ohne Block
- KRITISCH: `integrity-check.sh` selbst nicht in Blocklist → ein Hook-Update könnte
  die Hash-Chain still aushebeln
- Aktuell nicht akut, da kein Drittanbieter-MCP-Tool mit Write-Access installiert ist.
  Aber: Supabase-MCP-Tools existieren bereits, Threat-Surface ist real.

## Erfolgsfaktor
Stakeholder bestätigt aktiv oder verschiebt mit Begründung. Item wird NICHT
automatisch vom Worker gepickt (`requires_human_dispute: true`).
