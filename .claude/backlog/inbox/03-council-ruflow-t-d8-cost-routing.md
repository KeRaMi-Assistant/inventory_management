---
slug: ruflow-t-d8-cost-routing-opus-to-sonnet
priority: 4
agent: flutter-coder
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
depends: ruflow-t-d5-agent-model-routing-review
council_approved: 2026-05-16
---

# T-D8 — Cost-Routing Opus→Sonnet (vorsichtig, pro Agent ein PR)

Council-getriggert (Variante D). Schreib-Task, depends auf T-D5.

## Vorbedingung
T-D5 abgeschlossen — Migration-Kandidaten-Liste aus `docs/audits/2026-05-16_model-routing.md` bekannt.

## Vorgehen
**PRO AGENT EIN SEPARATER PR.** Nicht alle auf einmal — sonst ist Rollback bei Qualitätsverlust schwierig.

Pro Migration-Kandidat:
1. Branch `fix/agent-<name>-opus-to-sonnet`
2. `.claude/agents/<name>.md` Frontmatter `model: opus` → `model: sonnet`
3. 5 Real-Runs gegen ein konkretes Backlog-Item (synthetisch wenn nötig)
4. Output-Quality-Vergleich vs. Opus-Baseline (Spot-Check)
5. PR mit Cost-Diff + Quality-Annotations

## Erfolgsfaktor
Pro Agent: nach 5 Sonnet-Runs ist Output ≥ 90% äquivalent zum Opus-Run.
Sonst: revert + Begründung in PR-Comment.
