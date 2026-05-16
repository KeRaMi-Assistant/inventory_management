---
slug: ruflow-t-d7-analyzer-spam-fix
priority: 4
agent: flutter-coder
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
depends: ruflow-t-d1-analyzer-bottleneck-analysis
council_approved: 2026-05-16
---

# T-D7 — Analyzer-Spam reduzieren

Council-getriggert (Variante D). Schreib-Task, depends auf T-D1.

## Vorbedingung
T-D1 abgeschlossen — Top-3-Spam-Analyzer aus `docs/audits/2026-05-16_analyzer-bottleneck.md` bekannt.

## Output
- 1 PR mit Analyzer-Config-Changes oder Dedup-Hash-Verschärfung
- Geänderte Files: `.claude/analyzer/configs/*.yaml` und/oder `.claude/scripts/scan-*.sh`
- Pro betroffener Analyzer: Begründung im Commit-Body

## Erfolgsfaktor
Nach Merge: Analyzer-Output letzte 7 Tage zeigt ≥ 40% weniger Items im
betroffenen Modul-Cluster (vorher/nachher-Vergleich im PR).
