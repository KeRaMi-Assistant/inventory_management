---
slug: ruflow-t-d10-help-doku-audit
priority: 4
agent: doc-updater
plan_ref: plans/2026-05-16_ruflow_integration_evaluation.md
council_approved: 2026-05-16
---

# T-D10 — Help/Doku-Audit

Council-getriggert (Variante D). Doku-Sync.

## Vorgehen
1. Liste alle 13 Slash-Commands aus `.claude/commands/*.md`
2. Liste alle Telegram-Commands aus `.claude/scripts/telegram-bot.py` (`/yota`, `/btw`, `/status`, `/help`, `/yota propose`, …)
3. Cross-Check `lib/screens/help_screen.dart`: welche Commands erwähnt?
4. Cross-Check `docs/handbook/05-architecture.md`: Subagenten-Tabelle aktuell?
5. Cross-Check `CLAUDE.md`: Verweise auf Commands aktuell?

## Output
- 1 PR mit Korrekturen
- Pro fehlender Command: Doku-Eintrag (kurz, 2-3 Zeilen) DE+EN für help-screen
- Tote Verweise entfernt

## Erfolgsfaktor
Alle 13 Slash-Commands + Telegram-Commands sind in `help_screen.dart` UND
`docs/handbook/` UND `CLAUDE.md` referenziert.
