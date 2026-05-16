---
slug: ruflow-t-d1-analyzer-bottleneck-analysis
priority: 3
agent: planner
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-D1 — Bottleneck-Analyse Analyzer-Output

Council-getriggert (Variante D, RuFlow-Council 2026-05-16). Read-only Discovery.

## Input
- `.claude/analyzer/` — letzte 30 Tage Items
- Häufigkeit pro Modul, "pre-existing"-Dedupe-Rate

## Output
- Markdown-Report mit den Top-3-Spam-Analyzern
- Empfehlung pro Spam-Analyzer: pausieren, Dedup-Hash verschärfen, oder Config anpassen
- Speichern unter `docs/audits/2026-05-16_analyzer-bottleneck.md`

## Erfolgsfaktor
Report zeigt konkrete Item-Counts pro Analyzer + nennt Top-3 mit Begründung.
Liefert Input für T-D7 (Schreib-Task).
