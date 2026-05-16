---
slug: ruflow-t-d4-prompt-cache-verification
priority: 3
agent: yota
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-D4 — Prompt-Cache-Hit-Rate-Verifikation

Council-getriggert (Variante D). Read-only Status-Snapshot.

## Vorgehen
1. `bash .claude/scripts/verify/prompt-cache-friendly.sh` — Exit 0 = alle cache-friendly?
2. Letzte 10 Worker-Runs aus `.claude/overseer/runs/` lesen
3. `cached_input_tokens` vs. `input_tokens` Ratio berechnen

## Output
- Read-only Snapshot-Report unter `docs/audits/2026-05-16_prompt-cache.md`
- Pro Agent: durchschnittlicher Cache-Hit-Ratio
- Bottleneck-Agents (Cache-Hit < 50%) auflisten + warum

## Erfolgsfaktor
Klare Aussage: läuft Prompt-Caching wie erwartet (CLAUDE.md verspricht ~90%
Cost-Reduktion bei cache-friendly Invocation)?
