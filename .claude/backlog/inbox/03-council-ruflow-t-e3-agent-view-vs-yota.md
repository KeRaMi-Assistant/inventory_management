---
slug: ruflow-t-e3-agent-view-vs-yota
priority: 4
agent: planner
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-E3 — Agent-View-Dashboard vs. yota-snapshot.sh (0.5 PT)

Council-getriggert (Variante E, Native Anthropic Adoption).

## Vorgehen
1. Anthropic Agent-View-Dashboard aktivieren + ausprobieren
2. Featureset vs. `bash .claude/scripts/yota-snapshot.sh --human` vergleichen:
   - Status-Aggregation (Workers, Cost-Ledger, PANIC-Marker)
   - Sprachen-Support (de-DE bei Yota Pflicht)
   - LLM-Cost (Yota ~$0.05/Call, Agent-View vermutlich gratis)
3. Read-only-Charakter: bleibt Yota nötig für Phone-/Telegram-Snapshots?

## Output
- ADR-Snippet `plans/2026-05-XX_adr-agent-view.md` (in T-E4 konsolidierbar)
- Konkrete Empfehlung: Yota-Migration sinnvoll? Pro/Contra mit Belegen

## Erfolgsfaktor
Klare Aussage zu Token-Ersparnis + DX-Trade-off. Liefert Input für T-E4.
