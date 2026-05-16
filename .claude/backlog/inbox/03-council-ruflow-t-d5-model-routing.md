---
slug: ruflow-t-d5-agent-model-routing-review
priority: 3
agent: planner
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-D5 — Agent-Modell-Routing-Review

Council-getriggert (Variante D). Read-only Review.

## Vorgehen
1. Alle `.claude/agents/*.md` lesen — pro Agent: aktuelles Modell aus Frontmatter
2. CLAUDE.md §Subagent-Modell-Routing als Referenz: welche Tasks rechtfertigen Opus?
3. Real-Runs aus `.claude/overseer/runs/` (letzte 20) auswerten — Token-Usage + Modell

## Output
- Markdown-Report unter `docs/audits/2026-05-16_model-routing.md`
- Pro Agent: aktuelles Modell, Routing-Konformität (ja/nein), Cost-Estimate Sonnet-Migration
- Liste der Migration-Kandidaten (Opus → Sonnet ohne Qualitätsverlust)

## Erfolgsfaktor
Konkrete Liste mit Begründung pro Agent. Liefert Input für T-D8 (Schreib-Task).
