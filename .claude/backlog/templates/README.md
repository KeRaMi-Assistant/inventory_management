# Backlog-Templates (Roadmap-Mapping)

Vorgefertigte Backlog-Items für autonome Headless-Runs, abgeleitet aus
[`docs/STRATEGY.md`](../../../docs/STRATEGY.md).

## Wie aktivieren?

```bash
# Eines aktivieren (kopieren nach inbox/):
bash .claude/scripts/queue-template.sh 03-tickets-table-migration

# Alles aus einem Sprint aktivieren:
bash .claude/scripts/queue-template.sh sprint-7

# Alle aktivieren (große Gefahr — viele Tokens):
bash .claude/scripts/queue-template.sh all
```

Der LaunchAgent verarbeitet die Items dann sequenziell (FIFO nach
Filename), 1 Item pro 30-Min-Tick. 12 Items = ~6 h Headless-Run.

## Was Claude autonom kann (✅) vs. extern (❌)

| Sprint / Feature | Autonom | Extern (du musst) |
|---|---|---|
| **Sprint 5 — Discord-Bot** | App-Seite (Migrations, Edge Function `discord-dispatcher`, Settings-Tab UI) | Discord-Developer-Account, Bot-Token, Fly.io-Deployment des Bot-Service |
| **Sprint 6 — Postfach** | ✅ Fertig (laut STRATEGY) | — |
| **Sprint 7 — Archiv** | Komplett (Migrations, Triggers, UI-Tabs) | — |
| **Sprint 8 — eBay-Sync** | Edge Function, Migration, UI | eBay-Developer-Account, OAuth-Setup |
| **Sprint 9 — DATEV + i18n EN** | Komplett | — |
| **Querschnitt 7.1 — Cmd+K** | Action-Provider + Hotkey | — |
| **Querschnitt 7.5 — Verkaufsseite** | Public-Profile-Page (`/u/<handle>`) komplett | — |
| **Querschnitt 7.9 — Dark-Mode** | Komplett | — |
| **Querschnitt 7.10 — Onboarding** | Komplett | — |
| **Tech-Debt: Tests** | Komplett | — |

## Templates

### Sprint 7 — Archiv-Refactor (5 Items, ~1 Woche autonom)

- `s7-01-tickets-table-migration.md` — Migration: echte `tickets`-Tabelle + Backfill aus existierenden `deals.ticket_number`
- `s7-02-deals-shipped-at-migration.md` — Spalte `deals.shipped_at` (timestamptz)
- `s7-03-archive-triggers-migration.md` — Postgres-Trigger für Auto-Archive
- `s7-04-tickets-screen-archive-tab.md` — UI: Tab Aktiv/Archiv mit Monatsgruppierung
- `s7-05-inventory-verkauft-tab.md` — UI: "Verkauft"-Tab als eigenständige Ansicht

### Sprint 9 — DATEV + i18n EN (3 Items)

- `s9-01-datev-csv-export.md` — CSV-Service + Settings-UI für Quartal-/Jahres-Export
- `s9-02-i18n-en-tickets-screen.md` — Alle hardcoded Strings → ARB
- `s9-03-i18n-en-inventory-screen.md` — Alle hardcoded Strings → ARB

### Querschnitts-Features (4 Items)

- `q-01-public-profile-page.md` — Verkaufsseite `/u/<workspace-handle>` mit Bestand
- `q-02-dark-mode-toggle.md` — Settings-Toggle, persistiert in SharedPreferences
- `q-03-cmd-k-actions.md` — Action-Provider für globale Suche
- `q-04-onboarding-demo-data.md` — First-Time-User-Flow + "Demo-Daten laden"

### Tech-Debt (1 Item)

- `td-01-tests-services-coverage.md` — Unit-Tests für Service-Layer (Ziel: 30%)

## Dann?

Sobald ein Item gequeue't ist:
- **Sofortiger Trigger:** `bash .claude/scripts/headless-runner.sh` (manueller Run)
- **Alle 30 Min** läuft der LaunchAgent automatisch (wenn installiert)
- **Status:** `ls .claude/backlog/{inbox,done,failed}/`
- **Logs:** `.claude/backlog/runs/<timestamp>-<slug>.log`
- **Notifications:** macOS + Phone-Push (ntfy) bei Erfolg/Fehler
