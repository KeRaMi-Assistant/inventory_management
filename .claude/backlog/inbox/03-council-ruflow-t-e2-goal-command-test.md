---
slug: ruflow-t-e2-goal-command-test
priority: 4
agent: planner
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-E2 — /goal-Command-Test (1 PT)

Council-getriggert (Variante E, Native Anthropic Adoption).

## Vorgehen
1. `/goal`-Command an einem konkretem Backlog-Item testen (z.B. ein kleines T-D6 / T-D4)
2. Supervisor-Validation-Pattern beobachten (zweite Claude-Session prüft Goal-State)
3. Vergleich vs. unser Disput-Loop (3 Runden, Pragmatist Tie-Break)

## Output
- ADR-Snippet unter `plans/2026-05-XX_adr-goal-command.md` (kann in T-E4 konsolidiert werden)
- Konkrete Aussage: Eignet sich `/goal` als Disput-Tie-Break-Ersatz?
- Token-Cost-Vergleich vs. unser 3-Runden-Council

## Erfolgsfaktor
Klare Empfehlung mit Belegen. Liefert Input für T-E4.
