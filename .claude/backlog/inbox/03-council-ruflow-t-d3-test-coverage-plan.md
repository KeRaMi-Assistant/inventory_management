---
slug: ruflow-t-d3-test-coverage-increment-plan
priority: 4
agent: planner
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
depends: ruflow-t-d2-test-coverage-audit
council_approved: 2026-05-16
---

# T-D3 — Test-Coverage-Increment-Plan

Council-getriggert (Variante D). Plan-Erstellung basierend auf T-D2 Output.

## Vorbedingung
T-D2 muss abgeschlossen sein (`docs/audits/2026-05-16_test-coverage.md` existiert).

## Output
- Plan-File in `plans/2026-05-17_test-coverage-increment.md`
- Priorisierung der Top-5 Services aus T-D2
- Pro Service: Test-Strategie (Unit/Integration), erwarteter Coverage-Gain, PT-Schätzung

## Erfolgsfaktor
Plan ist atomar (1 Task pro Service, einzeln PR-fähig).
