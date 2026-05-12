# Telegram-Yota Setup

Bidirektionaler Chat vom Phone: `/yota`, `/yota <frage>`, `/btw <text>`.

## Schritt 1: Bot via BotFather erstellen (1 Min)

1. Telegram öffnen → suche `@BotFather` → start.
2. `/newbot` → folge Anweisungen. Vergebe Namen (z. B. "Yota Inventory Bot")
   und User-Name (z. B. "yota_inventory_bot").
3. BotFather gibt dir einen Token wie `123456789:ABCdef...` — kopiere ihn.

## Schritt 2: Deine User-ID rausfinden

1. Telegram öffnen → suche `@userinfobot` → start. (Alternativ
   `@username_to_id_bot`.)
2. Bot schickt dir deine numerische User-ID (z. B. `987654321`).

## Schritt 3: `.env.headless` ergänzen

Im Repo-Root:

```bash
cat >> .env.headless <<EOF
TELEGRAM_BOT_TOKEN=123456789:ABCdef...
TELEGRAM_ALLOWED_USER_IDS=987654321
NTFY_TOPIC=<dein-ntfy-topic-falls-noch-nicht-gesetzt>
EOF
```

Mehrere User-IDs: komma-separiert (`987654321,123456789`).

## Schritt 4: LaunchAgent installieren

```bash
bash .claude/scripts/session-start.sh          # signed-marker für Edits (5min TTL)
bash .claude/scripts/install-telegram-bot.sh --load-now
```

## Schritt 5: Testen

1. In Telegram zu deinem Bot wechseln → `/start`.
2. `/yota` → sollte Status-Snapshot zurückgeben.
3. `/yota was läuft gerade?` → Yota-LLM-Antwort (kostet ~$0.05).
4. `/btw "Test-Feature: dunkler Footer auf Inventory"` → triagiert sich
   autonom in Backlog.

## Commands im Bot

- `/yota` — Snapshot in 5 Zeilen (free, sofort).
- `/yota <frage>` — Yota-LLM-Antwort (~$0.05, dauert 5–30 s).
- `/status` — Alias zu `/yota`.
- `/btw <text>` — Stakeholder-Item → Triage → Backlog.
- `/help` — diese Liste.

## Rate-Limits

- `/btw`: max 5 Items pro Stunde (separater Counter).
- `/yota <frage>`: max 10 LLM-Calls pro Stunde (Cost-Cap).
- `/yota` ohne Frage (Snapshot): unbegrenzt.

## Sicherheit

- Nur User-IDs in `TELEGRAM_ALLOWED_USER_IDS` werden angenommen — Fremde
  werden geloggt + ignoriert.
- HMAC-Token-Rotation aktivierbar via Briefing (P3-9).
- Alle Empfangs-Events landen im Audit-Trail (`.claude/audit/<date>.md`).

## Troubleshooting

- Logs: `tail -f .claude/overseer/telegram-bot.err.log`
- Status: `launchctl list | grep com.inventory.telegram-bot`
- Stop/Remove: `bash .claude/scripts/uninstall-telegram-bot.sh`
