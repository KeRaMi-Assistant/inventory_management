# STRATEGY — InventoryOS

> Stand: 2026-05-05 · Roadmap & To-Do-Liste für die nächsten 6 Monate.
> Diese Datei ist umsetzungsorientiert: jede Sektion beschreibt **was** gebaut
> wird, **warum** es zählt und **wie** es technisch aufgesetzt wird. Die
> bisherige analytische Bestandsaufnahme ist abgeschlossen — jetzt geht's an
> Auslieferung.

---

## 0. Aktueller Zustand (Kurzform)

Die App ist heute ein technisch sauberes, deutschsprachiges Reseller-Inventar
mit Supabase-Cloud-Sync, Workspaces, Push-Notifications, Bilder/Anhängen,
Barcode-Scanner, Tickets, Billing-Profilen und einer Carrier-Detection mit 8
Versanddienstleistern. Was fehlt zur echten Produkt-Reife:

1. **Discord-Bot als eigenständiger Service** (aktuell nur Hilfetext + Buyer-Links).
2. **Postfach-/E-Mail-Anbindung** zum automatischen Updaten von Bestellungen.
3. **Echte Archiv-/Verkaufs-Übersicht**, die abgeschlossene Tickets aus dem aktiven Workflow herausnimmt.
4. **Marktplatz-Sync** (eBay zuerst).
5. **DATEV-Steuerexport**.
6. **Marke + Onboarding + Landing-Page**.

Alle anderen Themen aus früheren Sprints (Workspaces, i18n-Foundation, Bilder,
Bulk-Edit, Activity-Log) sind im Schema vorhanden und werden hier nur dort
erwähnt, wo sie ein neues Feature blockieren.

---

## 1. Sprint 5 — Discord-Bot (eigenständiger Service)

**Ziel:** Reseller leben in Discord. Wenn der Bot ihre Tickets, MHDs und
Lieferungen automatisch in den Server postet, wird die App vom passiven
Inventar zum aktiven Hub. Das ist unser USP gegenüber Vendoo, Sortly und
Hypemaster Playbook — keiner davon hat eine native Discord-Integration.

### 1.1 Architektur

```
Supabase (events + workspaces)
        │
        ▼ Edge Function "discord-dispatcher" (cron alle 60s)
        │
        ▼ Discord Bot (separater Deno/Node-Service auf Fly.io)
        │
        ▼ Discord-Channel (per Workspace konfiguriert)
```

- **Bot-Service**: schlanker Deno-Prozess auf `fly.io` (kostenlos im Free-Tier
  bis ~3 Apps), nutzt `discord.js` oder `harmony` (Deno).
- **Bot-Token + App-Settings** liegen in Supabase Secrets.
- **Workspace-Konfiguration**: neue Tabelle `workspace_discord_settings`
  (`workspace_id`, `guild_id`, `channel_ticket_updates`, `channel_mhd_warnings`,
  `channel_new_deals`, `notify_role_id`, `enabled`).
- **Event-Bus**: neue Tabelle `outbound_events` (`id`, `workspace_id`, `kind`,
  `payload jsonb`, `dispatched_at`). Triggers auf `deals`, `inventory_items`,
  `deal_comments` schreiben Events rein. Edge Function pollt alle 60s,
  sendet an den Bot, markiert dispatched.

### 1.2 Bot-Commands (Slash-Commands)

| Command | Wirkung |
|---|---|
| `/ticket <nr>` | Postet Ticket-Summary (Status, Items, Tracking, Käufer) |
| `/lager <ean\|name>` | Sucht im Lager des Workspaces |
| `/mhd` | Listet alle Items mit MHD < 14 Tage |
| `/verkauft today\|week\|month` | Verkaufs-Report mit Profit |
| `/track <nr>` | Carrier-Detection + Live-Tracking-URL |
| `/note <ticket> <text>` | Hängt Kommentar an Deal (taucht in App auf) |

### 1.3 Auto-Posts (Bot postet von selbst)

- **Neuer Deal** → Channel `new_deals`: Produkt, Menge, Shop, EK, VK.
- **Status-Änderung** → Channel `ticket_updates`: "Ticket #1234 → Angekommen".
- **MHD-Warnung** (täglich 09:00) → Channel `mhd_warnings`: Items <14 Tage.
- **Tracking-Update** (siehe Sprint 6) → Channel `ticket_updates`.
- **Käufer-Match**: wenn ein Discord-Buyer per `discord_server_id` zugeordnet
  ist und ein Deal "Done" wird → DM an den Buyer mit Tracking-Link.

### 1.4 Was zu tun ist

- [ ] Migration `20260506000000_outbound_events.sql`: Tabellen + Trigger
- [ ] Migration `20260506000100_workspace_discord_settings.sql`
- [ ] Edge Function `discord-dispatcher` (Polling + Dispatch)
- [ ] Bot-Service `bot/` als separates Repo oder Subfolder mit eigenem `fly.toml`
- [ ] Settings-Screen: neuer Tab "Discord" (Guild-ID, Channel-Picker, Enable-Toggle, Test-Button)
- [ ] Onboarding: "Bot zum Server hinzufügen"-Button (OAuth2-Invite-Link)
- [ ] Hilfe-Screen: Discord-Sektion erweitern um Bot-Setup-Anleitung

---

## 2. Sprint 6 — Postfach-Integration (Order-Inbox)

**Ziel:** Reseller bekommen täglich 50+ Bestätigungs-Mails von Shops (Amazon,
eBay, Zalando, Nike, …). Diese manuell in Deals zu übertragen ist die
zeitaufwändigste Tätigkeit überhaupt. Wenn die App das Postfach lesen kann,
neue Bestellungen erkennt, Tracking-Updates parst und automatisch dem
richtigen Deal zuordnet, **ersetzt das ~30 min/Tag manueller Arbeit pro
Power-User**.

### 2.1 Anbindungs-Optionen (gestaffelt nach Aufwand)

**Stufe 1 — IMAP (universell, datenschutzfreundlich, MVP)**
- User trägt IMAP-Server, Login, App-Passwort ein.
- Edge Function `inbox-poll` läuft alle 5 min via `pg_cron`.
- Server-seitig via `Deno + ImapFlow` (npm via esm.sh) → keine Credentials im Client.
- **Vorteil**: funktioniert mit jedem Provider (Gmail, GMX, web.de, iCloud).
- **Nachteil**: User muss App-Passwort generieren.

**Stufe 2 — OAuth (Google + Microsoft, später)**
- Gmail API + Microsoft Graph für Outlook.
- Bequemer, aber jeder Provider braucht eigene App-Verifikation (bei Google: Security-Review nötig, ~3 Wochen).

**Stufe 3 — Webhook-Forwarding (für Self-Hoster + Pro-Tier)**
- User richtet Mailgun/Postmark-Inbound-Forward ein.
- Wir empfangen Mails per Webhook → trivial, keine Polls.

**Empfehlung**: Stufe 1 als MVP, Stufe 2 nach 2 Monaten, Stufe 3 als Pro-Add-on.

### 2.2 Parser-Pipeline

```
Mail → "shop_parser" identifiziert Shop (From-Header + Domain-Map)
     → schopfspezifischer Adapter extrahiert:
         · order_id, tracking, items[], total, currency, eta
     → Matching: existierender Deal mit gleicher order_id?
         ja  → Update (Status, Tracking, Arrival)
         nein → neuer "Vorschlag"-Deal in Inbox-Tab
     → Activity-Log-Eintrag + optional Discord-Post
```

**Adapter pro Shop** (Start mit den 8 wichtigsten):
- Amazon (DE/COM/FR/IT/ES/UK) — Bestellbestätigung + Versand-Mail
- eBay
- Zalando
- Nike / SNKRS
- Adidas / Confirmed
- StockX
- Otto
- About You

Jeder Adapter ist eine ~50-Zeilen-TypeScript-Funktion, die HTML/Plaintext der
Mail in ein normalisiertes `ParsedOrder`-Objekt überführt. Unbekannte Shops
landen in einem "Unklassifiziert"-Stack mit Roh-Anzeige.

### 2.3 UI

Neuer Tab "Inbox" (zwischen Tickets und Lager):
- **Vorgeschlagene Deals** (vom Parser erkannt, noch nicht bestätigt) → Swipe-to-accept
- **Aktualisierte Deals** (Status/Tracking automatisch übernommen) → Toast-Recap
- **Unklassifizierte Mails** (Parser-Miss) → manueller "Deal anlegen aus Mail"-Button

### 2.4 Was zu tun ist

- [x] Migration `20260507000000_inbox.sql`: `mailbox_accounts`, `mailbox_credentials`, `parsed_messages`, `pending_deal_suggestions` + 30-Tage-Cleanup-Cron
- [x] Edge Function `inbox-poll` (Deno + ImapFlow)
- [x] Edge Function `inbox-parse` (Adapter-Registry + Matching, 8 Shops)
- [x] Settings-Screen: neuer Tab "Postfach" — IMAP-Konfiguration
- [x] Inbox-Screen (Vorschläge / Aktualisiert / Unklassifiziert, Swipe-to-accept)
- [x] Verschlüsselung der IMAP-Credentials at-rest (`pgp_sym_encrypt` mit Supabase-Vault-Master-Key, get/set per SECURITY-DEFINER-RPC)

### 2.5 Datenschutz & Compliance

Mail-Inhalte sind sensibel. Regeln:
- Nur Header + extrahiertes JSON wird gespeichert, **nicht** der volle Mail-Body.
- Aufbewahrung 30 Tage, danach Auto-Delete des Parses.
- Klare Datenschutzerklärung + Opt-In im Onboarding.
- Auf Wunsch lokaler Modus: Polling läuft im Flutter-Client (nur Desktop), nicht in der Edge Function.

---

## 3. Sprint 7 — Archiv "Verkauft" + Lifecycle-Refactor

**Ziel:** Aktive Tickets dürfen den Workflow nicht zumüllen, wenn sie
abgeschlossen sind. Ein Ticket gehört ins Archiv, sobald

1. **alle zugehörigen Deals** verschickt (Tracking gesetzt **und**
   Versanddatum gesetzt) **oder** auf "Done" sind, **oder**
2. der zugehörige Inventory-Eintrag den Status **"Verkauft"** oder **"Versandt"**
   hat (je nach Workflow: Lager-Verkauf vs. Dropship-Verkauf).

### 3.1 Modell-Änderungen

Neue Spalten:
- `tickets.archived_at` (timestamptz, NULL = aktiv)
- `tickets.archived_reason` (`'all_shipped'`, `'all_done'`, `'inventory_sold'`, `'manual'`)
- `deals.shipped_at` (timestamptz) — wir haben aktuell `arrival_date` für Eingang, aber kein dediziertes "verlässt-Lager"-Datum

> Aktuell ist "Ticket" eine virtuelle Aggregation aus `deals.ticket_number`
> ohne eigene Tabelle. Für Archivierung brauchen wir eine echte
> `tickets`-Tabelle:
>
> ```sql
> create table tickets (
>   id bigint generated always as identity primary key,
>   workspace_id uuid not null references workspaces(id),
>   ticket_number text not null,
>   archived_at timestamptz,
>   archived_reason text,
>   archived_by uuid references auth.users(id),
>   unique (workspace_id, ticket_number)
> );
> ```
>
> Migration füllt sie aus existierenden `deals.ticket_number`-Werten.
> Deals bekommen `ticket_id` als FK; `ticket_number` bleibt als
> generated-Spalte für Backward-Compat.

### 3.2 Auto-Archive-Trigger

Postgres-Trigger nach jedem `UPDATE` auf `deals`:
```
IF jeder Deal des Tickets shipped_at IS NOT NULL OR status = 'Done'
THEN archive ticket with reason 'all_shipped' / 'all_done'
```

Trigger nach `UPDATE` auf `inventory_items`:
```
IF item.status IN ('Verkauft', 'Versandt')
   AND alle Items des Tickets in diesen Status
THEN archive ticket
```

### 3.3 UI

- **Tickets-Screen**: bekommt einen Sub-Tab `Aktiv | Archiv`
- **Archiv** zeigt die Tickets nach Verkaufsmonat gruppiert, mit Profit-Summary
  pro Gruppe — das ist gleichzeitig ein leichtgewichtiger Verkaufs-Recap
- **Re-Open**: Long-Press auf archiviertes Ticket → "Wieder öffnen" (setzt
  `archived_at = NULL`, schreibt ins Activity-Log).
- **Inventory-Screen**: "Verkauft"-Filter wird zum primären Tab statt zur
  Filter-Option, mit eigenem Header (Anzahl, Profit, Top-Käufer).

### 3.4 Performance-Effekt

Aktive Listen werden ~70% kleiner für Power-User mit >500 historischen Deals.
Die Statistik-Aggregation kann optional weiter über alle Tickets laufen — die
UI-Listen aber nur über die aktiven, was Initial-Render-Zeit auf großen
Datasets spürbar drückt.

### 3.5 Was zu tun ist

- [ ] Migration `20260508000000_tickets_table.sql` + Backfill
- [ ] Migration `20260508000100_deals_shipped_at.sql`
- [ ] Migration `20260508000200_archive_triggers.sql`
- [ ] `Deal`-Modell + `inventory_provider`: `shippedAt`, `ticketId`
- [ ] `tickets_screen`: Tab-Switcher Aktiv/Archiv, Monatsgruppierung im Archiv
- [ ] `inventory_screen`: "Verkauft"-Tab als eigenständige Ansicht
- [ ] Neue Statistik-Card "Archiv-Quote" (% archiviert vs. aktiv) im Dashboard

---

## 4. Sprint 8 — Marktplatz-Sync (eBay zuerst)

**Ziel:** Der größte einzelne Werttreiber. Vendoo nimmt 30 €/Monat allein
fürs Crossposting — wir machen das Gegenteil und ziehen Verkäufe aus den
Marktplätzen **rein**, statt zu pushen. Damit decken wir den realen Reseller-
Workflow (verkaufen über mehrere Plattformen, zentral tracken).

### 4.1 Phase 1 (read-only, MVP)

- eBay Trading API: alle abgeschlossenen Verkäufe der letzten 30 Tage importieren.
- Mapping: eBay-`ItemID` ↔ unser `inventory_item.id` (per EAN oder manuelles Linking).
- Auto-Match: wenn EAN identisch → automatisch verknüpfen.
- Bei Verkauf: Inventory-Status auf "Verkauft", Deal mit `shop = "eBay"` anlegen.

### 4.2 Phase 2 (write, später)

- Listing-Push aus dem Inventory in eBay (Bilder + Beschreibung + Preis).
- Status-Sync (Listing pausieren/aktivieren).

### 4.3 Was zu tun ist (Phase 1)

- [ ] eBay-Developer-Account + OAuth-Flow
- [ ] Edge Function `marketplace-ebay-sync` (cron 4x täglich)
- [ ] Migration `20260509000000_marketplace_listings.sql`
- [ ] Settings-Tab "Marktplätze" mit eBay-Connect-Button
- [ ] Inbox-ähnliche UI für vorgeschlagene Auto-Matches

---

## 5. Sprint 9 — DATEV-Export + i18n EN

### 5.1 DATEV-konformer Steuer-Export

Niemand im Reseller-Bereich bietet das. Direkt monetarisierbar.

- Buchungssätze nach DATEV-CSV-Format mit Pflichtspalten:
  `Umsatz, Soll/Haben, Gegenkonto, Belegdatum, Belegfeld, Buchungstext, USt`
- Konten-Mapping pro Workspace (`billing_profile.tax_account_map`):
  - Standard: 8400 Erlöse 19% / 8300 Erlöse 7% / 3300 Wareneinkauf
- Export-Range: Quartal/Jahr.
- PDF-Begleitschreiben für den Steuerberater (auto-generated).

### 5.2 Englische Übersetzung

Foundation steht (ARB-Dateien für DE/EN). Sukzessive alle hardcoded Strings
auf `AppLocalizations.of(context)` umstellen. Sprint-9-Ziel: Tickets-,
Inventory-, Deals-Screen + alle Dialoge zu 100% lokalisiert.

---

## 6. Wettbewerbsvergleich (Stand 2026-05)

| Feature | InventoryOS heute | Vendoo | List Perfectly | Sortly Pro | Flipwise | Hypemaster | Lexware |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Multi-Plattform Apps | ✅ 5 | ⚠ Web | ⚠ Web | ✅ | ⚠ Web | ❌ Excel | ✅ |
| Cloud-Sync | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Profit-Tracking | ✅ | ⚠ basic | ⚠ basic | ❌ | ✅ | ✅ | ⚠ |
| MHD/Chargen | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Discord-Bot nativ | 🔜 (Sprint 5) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Postfach-Reader | 🔜 (Sprint 6) | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠ |
| Marktplatz-Sync | 🔜 (Sprint 8) | ✅ | ✅ | ❌ | ⚠ | ❌ | ⚠ |
| Crossposting | ❌ (Phase 2) | ✅ | ✅ | ❌ | ⚠ | ❌ | ❌ |
| DATEV-Export | 🔜 (Sprint 9) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Barcode-Scan | ✅ | ❌ | ❌ | ✅ | ⚠ | ❌ | ⚠ |
| Deutsche UI | ✅ | ❌ | ❌ | ⚠ | ❌ | ❌ | ✅ |
| Push-Notifications | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Workspaces / Team | ✅ Schema | ⚠ | ⚠ | ✅ | ❌ | ❌ | ✅ |
| Preis (€/Mon) | tba | 30 | 35 | 39 | 25 | 30 | 89 |

**Drei Felder**, in denen wir alleine spielen, sobald Sprint 5–9 läuft:

1. **Discord-nativ** — keiner.
2. **Postfach-Reader** — keiner für Reseller (nur ERPs in Enterprise).
3. **DATEV + DACH-Steuerlogik im Reseller-Tooling** — keiner.

---

## 7. Querschnitts-Features, die jeden Wert spürbar erhöhen

Diese sind klein bis mittel, aber treffen direkt die User-Erfahrung. Reihenfolge ist Priorität.

### 7.1 Globale Kommando-Palette (Cmd+K)
Eine Suchleiste, die über Deals, Items, Tickets, Käufer, Lieferanten findet
**und** Aktionen erlaubt ("Neuer Deal", "Export Quartal Q2 2026"). Foundation
existiert in [global_search_dialog.dart](lib/widgets/global_search_dialog.dart) — fehlt: Action-Provider und Hotkey-
Bindung im Web/Desktop.

### 7.2 Bulk-Edit in Deal-Tabelle
Mehrere Deals markieren → Status, Käufer, Tracking, Tags gemeinsam ändern.
Power-User-Feature, sehr hoher Wert pro Codezeile.

### 7.3 Versand-Etiketten via Sendcloud
Ein Klick auf einem Deal → Versandlabel als PDF + Tracking-Nummer wird
automatisch gesetzt + Carrier erkannt. Sendcloud hat eine ordentliche REST-API
und deckt alle deutschen Carrier ab.

### 7.4 Tracking-Auto-Update
Carrier-Detection ist da. Was fehlt: Polling der Carrier-APIs (DHL, UPS, DPD)
für `arrival_date`-Auto-Update + Discord/Push-Benachrichtigung "Paket
zugestellt". Carrier-API-Keys in Workspace-Settings, Edge Function `tracking-poll`
alle 4h.

### 7.5 Public Profile Page
Eine öffentliche Read-only-Seite (`/u/<workspace-handle>`) mit aktuellem
Bestand, Bildern, Preisen, "Anfrage senden"-Button. Akquise-Magnet — jeder
geteilte Link wird Werbung.

### 7.6 AI-Pricing-Assistant (Add-on, 9 €/Mon)
Vergleicht VK gegen aktuelle StockX/eBay/Vinted-Preise und schlägt Anpassung
vor. Datenquelle: Marktplatz-Sync (Sprint 8) liefert Verkaufspreise mit;
Embeddings via `pgvector` machen Item-Matching robust gegen Tippfehler.

### 7.7 Käufer-CRM-Light
Pro Käufer: gesamter Ticket-Verlauf, Lifetime-Profit, durchschnittliche
Zahlungsdauer, Zuverlässigkeits-Score. Tabelle `buyers` existiert; UI muss um
Detail-View erweitert werden.

### 7.8 Templates / Quick-Add
"Letzte 5 EAN" + "Häufigste Produkte" als One-Tap-Buttons im Deal-Dialog.
Foundation ist da (Produkt-Vorschläge übernehmen letzte Konfiguration), fehlt:
expliziter Template-Manager.

### 7.9 Dark-Mode
Hardcoded `Color(0xFF…)` raus, alles über `Theme.of(context).colorScheme`.
Aufwand: 1 Sprint, Wirkung: jeder erwartet das in 2026.

### 7.10 Onboarding-Flow + Demo-Daten
First-Time-User-Flow mit 6 Steps (Workspace, Shops, Lieferanten, erster Deal,
Discord, Postfach). "Demo-Daten laden"-Button im Empty-State zeigt die App
sofort mit realistischen Beispiel-Tickets.

---

## 8. Tech-Debt, der sonst Sprint 5–9 blockiert

Diese Punkte sind keine Features, müssen aber **vor oder parallel** zu den
neuen Features adressiert werden.

- **Tests**: kein einziger Unit-Test in `test/` außer `carrier_service_test.dart`. Vor jedem neuen Service mindestens Happy-Path + 2 Edge-Cases. Ziel: 30% Coverage in Sprint 5, 60% in Sprint 9.
- **`inventory_provider.dart` (~1000 LOC)**: aufsplitten in `DealRepository` / `InventoryRepository` / `SupplierRepository`. Sprint 7 ist der natürliche Punkt — der Tickets-Refactor sowieso fasst Provider an.
- **`freezed` + `json_serializable`**: drei Mapper pro Modell (`toJson`, `toSupabaseInsert`, `fromSupabase`) sind ein Drift-Risiko. Migration zu Code-Gen vor dem Postfach-Sprint, weil Adapter-Output sonst chaotisch wird.
- **CI/CD**: GitHub Actions mit `flutter analyze` + Tests + Build pro Plattform. Aktuell rein lokal — bei jedem PR ein Risiko.
- **Sentry / GlitchTip**: Crash-Reporting fehlt komplett. Wird mit dem Bot-Service essentiell, weil Bugs dort silent fehlschlagen.
- **DSGVO**: Datenschutzerklärung, Consent-Banner, Data-Export (`/account/export`), Account-Löschung (existiert in Edge Function `delete-account`, aber kein UI).

---

## 9. Roadmap-Zusammenfassung

```
Sprint 5  (3 Wochen)  Discord-Bot v1                   USP, Differenzierung
Sprint 6  (4 Wochen)  Postfach-Inbox (IMAP-MVP)        Killer-Feature, 30 min/Tag Ersparnis
Sprint 7  (2 Wochen)  Archiv-Refactor + tickets-Tabelle Datenmodell-Reife
Sprint 8  (4 Wochen)  eBay-Sync (read-only)            Marktanschluss
Sprint 9  (3 Wochen)  DATEV-Export + i18n EN           Monetarisierung + 10× Markt
Sprint 10 (3 Wochen)  Public Profile + Bulk-Edit       Akquise + Power-User
Sprint 11 (4 Wochen)  Tracking-Auto-Update + Sendcloud Workflow-Automation
Sprint 12 (4 Wochen)  AI-Pricing + Crossposting eBay   Premium-Tier-Anker
```

Insgesamt **~7 Monate** bis Vollausbau. Nach Sprint 7 ist die App
**verkaufsbereit als Solo-SaaS**; nach Sprint 9 **DACH-Markt-tauglich für
Steuerberater-Workflows**; nach Sprint 12 **direkter Vendoo-Konkurrent mit
einzigartiger Discord/Postfach-Differenzierung**.

---

## 10. Was diese Datei NICHT mehr sein soll

Frühere Versionen der STRATEGY enthielten ausführliche Marktanalyse,
Preismodell-Tabellen und 12-Monats-MRR-Projektionen. Das war wichtig fürs
Alignment — gehört aber jetzt in eine separate Datei `docs/BUSINESS.md`,
falls überhaupt. Dieses Dokument ist der **Engineering-Plan**: was wird
gebaut, in welcher Reihenfolge, gegen welchen Konkurrenzlücke, mit welchen
Migrationen und welchen Edge Functions. Alles andere lenkt ab.
