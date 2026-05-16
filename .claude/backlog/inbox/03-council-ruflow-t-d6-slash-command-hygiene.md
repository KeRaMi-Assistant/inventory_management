---
slug: ruflow-t-d6-slash-command-hygiene
priority: 3
agent: doc-updater
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-D6 — Slash-Command-Hygiene-Audit

Council-getriggert (Variante D). Read-only.

## Vorgehen
1. `.claude/commands/*.md` — alle 13 Slash-Commands listen
2. `.claude/audit/` letzte 30 Tage — Nutzungs-Counts pro Command
3. Cross-Check: welche Commands sind in `lib/screens/help_screen.dart` referenziert? In `CLAUDE.md`?

## Output
- Markdown-Report unter `docs/audits/2026-05-16_slash-commands.md`
- Pro Command: Last-Used-Datum, Use-Count letzte 30d, Doku-Status
- Deprecation-Kandidaten benennen (0 Uses + nicht in Help/CLAUDE.md = Kandidat)

## Erfolgsfaktor
Konkrete Deprecation-Vorschläge mit Belegen.
