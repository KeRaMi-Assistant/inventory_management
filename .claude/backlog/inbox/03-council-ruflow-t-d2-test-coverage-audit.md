---
slug: ruflow-t-d2-test-coverage-audit
priority: 3
agent: tester
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-D2 — Test-Coverage-Audit

Council-getriggert (Variante D, RuFlow-Council 2026-05-16). Read-only.

## Vorgehen
1. `flutter test --coverage` lokal
2. Coverage-Report (`coverage/lcov.info`) parsen
3. Service-Layer-Coverage messen (Dateien in `lib/services/`)
4. Top-5 ungetestete Services identifizieren

## Output
- Markdown-Report unter `docs/audits/2026-05-16_test-coverage.md`
- Pro Service: aktuelle Coverage %, LOC, Public-API-Count
- CLAUDE.md Auto-Merge-Gate fordert >60% Service-Layer-Coverage — heute schon erreicht?

## Erfolgsfaktor
Konkrete Top-5-Liste mit Service-Name + Coverage % + Begründung warum
priorisiert.
