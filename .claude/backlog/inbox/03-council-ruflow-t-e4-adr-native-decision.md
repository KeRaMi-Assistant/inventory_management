---
slug: ruflow-t-e4-adr-native-adoption-decision
priority: 5
agent: planner
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
depends: ruflow-t-e1-agent-teams-sandbox, ruflow-t-e2-goal-command-test, ruflow-t-e3-agent-view-vs-yota
council_approved: 2026-05-16
---

# T-E4 — ADR Native-Adoption-Decision

Council-getriggert (Variante E, Final-Synthese).

## Vorbedingung
T-E1, T-E2, T-E3 müssen abgeschlossen sein.

## Output
- ADR unter `plans/2026-05-XX_adr-native-anthropic-adoption.md`
- Synthese aus T-E1, T-E2, T-E3
- Entscheidung: Behalten wir Eigenbau komplett, oder migrieren wir 1-2 Schichten auf Anthropic-Native?
- Sec-Gate-Check (CLAUDE.md §Sicherheit) + DX-Gate-Check (Telegram-Bridge, Yota)

## Erfolgsfaktor
ADR ist konkret genug, dass Stakeholder per `/yota propose <migration-task>` ein
Backlog-Item erzeugen kann. Kein vager "wäre nice".
6-Monats-Trigger: T-E4 wird periodisch wiederholt (Mitigation R13 Native-Catch-Up).
