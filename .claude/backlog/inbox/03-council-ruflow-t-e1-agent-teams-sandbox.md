---
slug: ruflow-t-e1-agent-teams-sandbox
priority: 4
agent: planner
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-E1 — Agent-Teams-Sandbox-Test (1 PT)

Council-getriggert (Variante E, Native Anthropic Adoption).

## Vorgehen
1. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in einem Sandbox-Setup aktivieren (NICHT im Production-Repo)
2. Sandbox-Test mit 2-3 unserer Multi-Agent-Workflows:
   - Council (5 parallele Reviewer)
   - Disput (3 Agents, Pragmatist Tie-Break)
3. Vergleich vs. unser Worker-Pool-Eigenbau:
   - Parallelism-Verhalten
   - Token-Cost
   - Audit-Trail-Sichtbarkeit
   - Approval-Gate-Möglichkeiten

## Output
- ADR (Architecture-Decision-Record) unter `plans/2026-05-XX_adr-agent-teams.md`
- Konkrete Aussage: Eignet sich Agent Teams als Worker-Pool-Ersatz für unseren Stack?
- Mit Sec-Gate (Audit-Hash-Chain, HMAC, Self-Mod-Guard erhaltbar?) und DX-Gate
  (Telegram-Bridge, Yota-Surface erhaltbar?)

## Erfolgsfaktor
ADR liefert klare Empfehlung mit Belegen. Liefert Input für T-E4.
