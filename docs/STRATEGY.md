# Strategie & Analyse — InventoryOS

> Status: Sprint 3 abgeschlossen · letzte Aktualisierung 2026-05-03
> Kontext: Eine in Flutter geschriebene Lager- und Deal-Verwaltung mit
> Supabase-Backend, gebaut für Reseller/Flipper. Multi-Plattform
> (Web, iOS, Android, macOS, Windows), deutschsprachig, Cloud-Sync,
> Discord-Ticket-Integration.

---

## 1. Produkt & Marktwert

### 1.1 Wahrgenommener Marktwert (Status quo)

Die App hat einen geschätzten **Marktwert von 25–60 €/Monat pro Nutzer** in
ihrem aktuellen Zustand, wenn sie als SaaS angeboten würde. Das ergibt sich
aus der Summe vergleichbarer Tools:

| Funktion | Vergleichbares Tool | Preis |
|---|---|---|
| Reseller-Inventar | Sortly Pro / Flipwise | 19–39 €/Mon |
| Multi-Plattform mit Cloud-Sync | inFlow Inventory | 89 €/Mon |
| Statistik-Dashboard | Hypemaster Playbook | ~30 €/Mon |
| Discord-Ticket-Integration | — | unbepreist (USP) |

**Was den Wert real beweist:**
- Vollständige Cloud-Sync mit Supabase + Auth + RLS — produktionsreif
- 5-Tab-Statistikdashboard mit Charts, KPIs, Cashflow, Steuerreport
- Multi-Currency, Tax-aware, MHD/Chargen-Tracking
- 5 Plattformen, deutsche UI, OAuth (Google/Apple)

**Was den wahrgenommenen Wert aktuell drückt:**
- Keine Marke, keine Landing Page, keine Reviews
- Solo-Tool-Charakter — fühlt sich an wie internes Tool, nicht wie Produkt
- Keine Demo-Videos, keine Onboarding-Flows
- Nur deutschsprachig → addressabler Markt klein
- Kein offizieller App-Store-Eintrag → niemand findet es

### 1.2 Was den Wert signifikant steigern würde

Sortiert nach **Wertsteigerung pro Aufwand**:

1. **Marketplace-Integrationen** (eBay, Vinted, Mercari, Kleinanzeigen, StockX).
   Auto-Sync von Listings, Verkäufen, Versand. **Das ist der Tipping-Point**
   vom "Excel-Ersatz" zum "unverzichtbaren Hub" — alleine dadurch kann der
   Preis verdreifacht werden. Vergleichbare Tools (Vendoo, List Perfectly)
   nehmen 30–50 €/Monat NUR für Crossposting.
2. **Discord-Bot** (eigenständig). Der Bot postet Updates direkt in den Ticket-Channel,
   liest Tracking-Codes automatisch aus, erinnert an MHD/Lieferungen.
   Das ist der Discord-USP, **multipliziert** mit Automatisierung.
3. **Foto-Anhänge an Items/Deals.** Nicht-trivialer Mehrwert — niemand will
   Reseller-Software ohne Bilder. Supabase Storage macht das einfach.
4. **Mobile-first Onboarding-Flow + Barcode-Scanner.** EAN-Feld existiert
   bereits, ist aber ohne Scanner-UX wertlos. `mobile_scanner`-Package
   integrieren → Lager-Workflow drastisch beschleunigt.
5. **Public Profile / Sharing.** Reseller wollen ihren Shop teilen. Eine
   öffentliche Read-only-Seite (`/u/<username>`) mit aktuellem Bestand
   wäre Akquise-Magnet (jeder geteilte Link = Werbung).
6. **Tax-Export für deutsche Steuerberater (DATEV-Format).** Niemand sonst
   bietet das im Reseller-Bereich. Hochpreis-Argument für KMU-Reseller.

### 1.3 Differenzierung gegenüber Wettbewerbern

| Wettbewerber | Stärke dort | Lücke = unsere Chance |
|---|---|---|
| Vendoo / List Perfectly | Crossposting | Kein Profit-Tracking, kein deutsches Steuermodell |
| Sortly | UX, Mobile | Generisch, nicht reseller-spezifisch, kein Discord |
| Hypemaster Playbook | Cookgroup-Reichweite | Excel-basiert, kein Cloud-Sync, USA-Fokus |
| Lexware Warenwirtschaft | Steuer/Buchhaltung | Klassisch, B2B, nicht für Reseller-Workflow |
| Notion-Templates | Flexibilität | Kein echtes Datenmodell, manuell, fehleranfällig |

**Eigenes Differenzierungsprofil**, das es so noch nicht gibt:

> *"Reseller-Software für den deutschen Markt, mit nativer Discord-Integration,
> Multi-Marketplace-Sync und steuerkonformer Buchhaltung — gebaut von einem
> Reseller, für Reseller."*

---

## 2. Funktionale Analyse

### 2.1 Fehlende Features (User- & Business-Sicht)

**Tier S — Must-have für Produktreife** (Reseller wechseln nicht, solange das fehlt):

- [ ] **Bilder/Anhänge** für Items und Deals (Supabase Storage)
- [ ] **Barcode-Scanner** (EAN existiert als Feld, aber kein Scanner)
- [ ] **Push-Benachrichtigungen** (MHD-Warnung, Lieferung angekommen, Käufer-Zahlung)
- [ ] **Mobile-optimierte Listenansichten** (aktuell sind viele Tabellen am Handy schmerzhaft)
- [ ] **Activity-Log UI** (existiert im Backend, ist aber nirgends sichtbar)
- [ ] **Suchfunktion global** (Cmd+K-Style — über Deals, Items, Tickets, Käufer)

**Tier A — High-Impact, nächster Sprint:**

- [ ] **Discord-Bot** für: Ticket-Sync, MHD-Erinnerungen, neue Deal-Posts
- [ ] **Marketplace-Sync** (eBay API zuerst — größter Markt, beste Doku)
- [ ] **Automatisches Tracking-Update** (DHL/UPS/Hermes APIs → Status, Ankunft)
- [ ] **Bulk-Edit im Deal-Table** (mehrere markieren → Status/Käufer/Tracking ändern)
- [ ] **Versand-Etiketten erstellen** (Sendcloud / Shipcloud Integration)

**Tier B — Schöne Adds:**

- [ ] **Kommentar-/Notiz-Threads** auf Deals (für Team später)
- [ ] **Recurring-Items** (z.B. monatlich nachbestellen)
- [ ] **Preis-Tracker** (Vergleich VK vs. aktueller Marktpreis bei StockX/eBay)
- [ ] **Steuer-Export DATEV-konform** (CSV mit Buchungssätzen, nicht nur Liste)
- [ ] **Public Profile Page** (Read-only-Bestandsliste auf eigener URL)
- [ ] **Templates** für wiederkehrende Item-Typen
- [ ] **Multi-Sprach-Support** (EN als zweite Sprache → 10× Markt)

**Tier C — Premium/Enterprise:**

- [ ] **Team-Modus** (mehrere User pro Account, Rollen, Audit-Log)
- [ ] **API-Zugang** für eigene Scripts/Integrationen
- [ ] **Webhook-Support** (Zapier-style: "Wenn Deal Status=Done → poste in Discord")
- [ ] **White-Label** für Cookgroup-Owner

### 2.2 Überflüssig oder vereinfachbar

- **Zwei Status-Sets** (`status` für Deals, separater `status` für InventoryItems) → könnten harmonisiert werden in einer State-Machine
- **`shippingType` als String** ("Reship"/"Dropship") → reicht 1 Boolean (`isDropship`)
- **`beleg` als String "Ja"/"Nein"** → klassischer SQL-Code-Smell, sollte ein Boolean sein
- **`ticketUrl` UND `ticketNumber`** in Deals UND InventoryItems → redundant. Sollte über `ticketNumber` aufgelöst werden, URL nur einmal speichern
- **JSON-Backup-Restore** (existiert in Settings) → nutzt niemand, da Cloud-Sync läuft. Kann weg
- **Settings-Tab "Discord-Info"** → ist Hilfetext, gehört in eine richtige Hilfe-/Onboarding-Seite

### 2.3 High-Impact-Priorisierung (nächste 90 Tage)

```
Sprint 4 (2 Wochen):
  - Bilder/Foto-Upload (Items + Deals)
  - Barcode-Scanner mobile
  - Push-Notifications (FCM via Supabase)
  - Activity-Log-UI

Sprint 5 (3 Wochen):
  - Discord-Bot v1 (Ticket-Sync + MHD-Reminder)
  - Bulk-Edit in Deal-Tabelle
  - Tracking-Auto-Update (DHL API zuerst)

Sprint 6 (4 Wochen):
  - eBay-Marketplace-Integration (read-only zuerst: Verkäufe importieren)
  - DATEV-konformer Steuer-Export
  - Englische Übersetzung
```

Das wäre der Pfad von "fertiges Tool" zu "Produkt mit echtem Markt-Fit".

---

## 3. Datenmodell & Architektur

### 3.1 Zukunftssicherheit

Das aktuelle Modell (Postgres via Supabase, RLS pro User, Soft-Delete,
Audit-Spalten `updated_at`/`updated_by`/`version`) ist **solide für den
Single-User-Fall**.

**Skaliert nicht ohne Anpassung für:**
- Team-/Workspace-Modell (kein Workspace-Owner-Konzept)
- Multi-Account pro User (z.B. privat + business)
- Real-Time-Collab (Supabase Realtime ist da, aber nicht eingebunden)
- Sehr große Datasets (>50k Deals) — viele Stats werden client-seitig berechnet

### 3.2 Fehlende Entitäten / Relationen

| Entität | Warum sie fehlt |
|---|---|
| **`workspace`** / `team` | Aktuell ist `user_id` direkt auf jeder Tabelle. Für Team-Modus brauchst du `workspace_id` + `workspace_members` mit Rollen |
| **`attachment`** | Bilder, Belege, Versandlabels — gehört eigene Tabelle mit Polymorphic-Reference auf Deal/Item/Batch |
| **`marketplace_listing`** | Verknüpfung Item ↔ Listing auf eBay/Vinted/etc. Mit Status (aktiv, verkauft, gelistet, gepausit) |
| **`payment`** | Aktuell ist Zahlung implizit über `status='Done'` — eine `payment`-Tabelle mit Datum, Betrag, Methode wäre sauber für Cashflow |
| **`shipment`** | Tracking, Versand-Etikett, Carrier, Versandkosten — gehören aus `Deal` raus |
| **`tag` / `category`** | Items haben aktuell keine Kategorisierung (Sneaker, Kleidung, Elektronik…). Tags wären die einfachste Lösung |
| **`price_history`** | Wenn man Marktpreis-Tracking will, braucht man eine Zeitreihe pro Item/EAN |
| **`event`** | Generischer Event-Stream für Analytics, AI, Integrations (siehe 3.4) |
| **`buyer_address`** | Käufer haben aktuell keine Lieferadressen — braucht es spätestens für Versand-Etiketten |

### 3.3 Wo entstehen Probleme später?

**Performance:**
- `StatisticsService` rechnet alle Stats jedes Mal client-seitig auf der ganzen Liste. Bei 10k+ Deals merkt man das. → **Lösung**: Postgres-Materialized-Views oder serverseitige RPC-Funktionen mit Caching
- `loadAll()` lädt alle Tabellen komplett auf jeder Anmeldung → **Lösung**: Inkrementelles Sync via `updated_at > last_sync`
- `inventoryItemIds`-Array auf Deal (nicht in DB-Schema sichtbar) — wenn das ein PG-Array ist, schlecht für Joins → **Lösung**: Normale Many-to-Many-Tabelle `deal_items`

**Wartbarkeit:**
- Drei Datenrepräsentationen pro Entität (`toJson` für Backups, `toSupabaseInsert` snake_case, `fromSupabase`) — DRY-Verletzung. Bei jeder neuen Spalte musst du sie an 4 Stellen pflegen → **Lösung**: Code-Gen mit `freezed` + `json_serializable` ODER eine zentrale Mapping-Schicht
- `_sentinel`-Object-Trick im `copyWith` von Hand pro Klasse → **Lösung**: `freezed` macht das automatisch
- 700+ Zeilen `inventory_provider.dart` ist zu viel → split nach Domain (Deals/Items/Suppliers/Batches als separate Provider/Repositories)

**Konsistenz:**
- Kein Foreign-Key-Constraint zwischen Deal und InventoryItem (Item-IDs werden nur lokal in `inventoryItemIds` gehalten) → **Bug-Risiko**: gelöschte Items hinterlassen Dangling-References
- `arrivalDate` auf Deal vs. `arrival_date` auf Item — können auseinanderdriften, kein Sync

### 3.4 Erweiterungs-Vorschläge

**Event-Sourcing-Light für Analytics + AI-Readiness:**

Statt nur den aktuellen Zustand zu speichern, eine `event`-Tabelle ergänzen:
```
events:
  id, user_id, workspace_id,
  type (deal.created, deal.status_changed, item.scanned, ...),
  entity_type, entity_id,
  payload jsonb,
  created_at
```

Vorteile:
- AI/ML-Modelle können auf strukturierten Events trainiert werden ("welcher Käufer kauft wann was zu welchem Preis")
- Zeitreihen-Analysen ohne Spaltenexplosion
- Externe Webhook-Integration trivial (Event → fan-out)
- DSGVO-Audit-Trail kostenlos dazu

**Vector-Search für Produkte:**
Mit `pgvector` (Supabase unterstützt es nativ) eine Embedding-Spalte auf
Items/Deals → semantische Suche und "ähnliche Produkte" mit minimalem Aufwand.

**Telemetry-Schicht:**
Aktuell loggt die App nur intern via `_log` in eine `activity_log`-Tabelle.
Für echte Produkttelemetrie (Onboarding-Funnel, Feature-Nutzung) ein
schlankes Tool wie **PostHog** oder **Plausible** ergänzen — frei,
self-hostbar, sehr DSGVO-freundlich.

---

## 4. Skalierbarkeit & Technik

### 4.1 Wachstumsfähigkeit

| Achse | Aktuell tragfähig bis | Bottleneck |
|---|---|---|
| **User pro Account** | 1 | Kein Team-Modell |
| **Deals pro User** | ~5.000 | Client-seitige Stats-Berechnung |
| **Konkurrente User** | 100–500 | Supabase-Free-Tier-Limits |
| **Plattformen** | 5 | Aktuell nur deutsche UI, kein i18n |

### 4.2 Sinnvolle Patterns/Tech-Ergänzungen

**Code-Layer:**
- `freezed` + `json_serializable` → Datenklassen + JSON automatisch generiert
- `riverpod` (oder zumindest `provider` strenger nutzen) → besseres Dependency-Tracking als die aktuellen ChangeNotifier-Mischungen
- `go_router` → typsichere Deep-Links + bessere Navigation als der aktuelle Index-State im `MainScreen`
- `dart_mappable` als modernere Alternative zu `freezed` für Mapping
- Separate `DealRepository` / `InventoryRepository` / `SupplierRepository`, statt einem Mega-Provider

**Server-Layer:**
- **Supabase Edge Functions** für: Webhooks empfangen (eBay, DHL), Discord-Bot-Endpoints, schwere Aggregationen, Tax-Export
- **PostgreSQL RPC-Funktionen** für die Statistik-Aggregationen — verschiebt Last vom Client zum DB-Server
- **Supabase Realtime** für Live-Updates (Deal-Status ändert sich → andere Geräte aktualisieren ohne Reload)
- **Supabase Storage** für Bilder
- **pgvector** + Embeddings für Produkt-Suche
- **CRON-Jobs in Supabase** (`pg_cron`) für: tägliche MHD-Checks, Tracking-API-Polls, automatische Zahlungs-Reminder

**Infrastructure:**
- **Sentry / GlitchTip** für Error-Tracking (frei, self-hostbar)
- **GitHub Actions** für CI/CD: Test-Run, `flutter analyze`, Build pro Plattform, Release-Channel
- **Coverage-Reports** + Integration-Tests (aktuell gibt's keinen `test/`-Folder mit Tests)

### 4.3 Risiken / Tech Debt

**Hoch:**
- **Keine Tests.** Keine einzige Unit- oder Integration-Test-Datei → jede Änderung kann
  unbemerkt regressieren. Bei 8.000+ LOC ist das ein wachsendes Risiko.
- **Drei Mapper pro Modell** (toJson, toSupabaseInsert, fromSupabase) → Drift-Risiko zwischen Backup-Format und DB-Format
- **Stats werden bei jedem Tab-Wechsel neu gemountet** — die Tab-Implementierung
  in `statistics_screen.dart` zerstört State, wenn man tabbt. Performance-Bug bei großen Datasets.

**Mittel:**
- **CSV-Service mit `dart:io`** funktioniert auf Web nur wegen Tree-Shaking. Sauber wäre Conditional Imports (`stub_io.dart` / `web_io.dart`)
- **Hardcoded Farben** überall (`Color(0xFF…)`) → kein Theming, keine Dark-Mode-Vorbereitung
- **Keine Rate-Limits** auf Auth-Endpoints sichtbar — Brute-Force theoretisch möglich (Supabase macht zwar etwas, aber nicht App-spezifisch)
- **DSGVO-Compliance** fehlt: keine Datenschutz-Erklärung, kein Consent-Banner, keine Data-Export-Funktion (außer JSON-Backup)

**Niedrig (aber nervig):**
- Inkonsistente Naming-Conventions (`zuBekommen` vs. `vk` vs. `revenue`)
- `_sentinel`-Trick in jedem Model → mit Code-Gen eliminierbar
- Mehrere identische `_dateFmt`-Definitionen über die Codebase verstreut

---

## 5. Monetarisierung & Business-Modell

### 5.1 Passende Strategien

**Empfehlung in absteigender Priorität:**

#### A) Freemium-SaaS (Standard, sicher, niedriges Risiko)

| Tier | Preis | Limits / Features |
|---|---|---|
| **Free** | 0 € | 50 Deals/Monat, 1 Plattform, keine Charts, keine Exports |
| **Reseller** | 14,99 €/Mon | Unlimited Deals, alle Plattformen, alle Charts, CSV/PDF/Excel-Export, eine Marketplace-Integration |
| **Pro** | 39,99 €/Mon | + Discord-Bot, + alle Marketplace-Integrationen, + Tracking-Auto-Update, + DATEV-Export, + 10GB Bilder |
| **Team** | 99 €/Mon (3 Seats) | + Workspace, + Rollen, + Audit-Log, + API, + White-Label optional |

Erwartete Conversion bei 1000 Free-Usern: ~3–5% → 30–50 zahlend → **~600–2000 €/Monat MRR pro 1000 User**.

#### B) Lifetime-Deal + Add-on-Käufe (für initialen Traction-Boost)

- **Lifetime Pro-Lizenz** auf AppSumo / eigener Seite: einmalig **149 €**
  → typischer AppSumo-Run bringt 500–2000 Käufer = 75–300k € einmalig
- **Add-Ons** danach kostenpflichtig: Marketplace-Connector je 5 €/Monat, KI-Insights 9 €/Monat

Das funktioniert besonders, wenn man Anfang des Wachstums ist (Reichweite > MRR).

#### C) Pay-per-Marketplace (volumenbasiert, B2B-tauglich)

- App selbst ist kostenlos
- Pro synchronisiertes Listing/Verkauf: **0,10 € Transaktionsgebühr**
- Spart sich die Free-vs-Paid-Schwelle, monetarisiert direkt mit Mehrwert

Nachteil: Tracking-Aufwand, Erwartungshaltung "App kostet nichts".

#### D) Reseller-Cookgroup-White-Label (Nische, Premium)

Cookgroup-Owner nehmen monatlich 30–50 €/Monat von ihren Mitgliedern.
Du bietest:
- Eigene Domain (cookgroup.com/inventory)
- Custom-Branding
- Eingebauter Discord-Bot in IHREN Server
- **Du nimmst 5 €/Member/Monat oder eine Flat von 199–499 €/Monat pro Cookgroup**

Das ist Hochmargen-Nische — wenn du 20 Cookgroups gewinnst, bist du bei 4–10k €/Monat MRR mit minimalem Marketing.

### 5.2 Features, die Zahlungsbereitschaft erhöhen

Sortiert nach Conversion-Power:

1. **Marketplace-Sync** — der zahlt sich SOFORT durch Zeitersparnis aus
2. **Discord-Bot mit Auto-Posting** — Reseller leben in Discord, Automatisierung ist Gold
3. **Tracking-Auto-Update** — niemand will manuell DHL-Codes eingeben
4. **DATEV/Steuer-Export** — verkauft sich an alle, die einen Steuerberater haben
5. **Bilder + öffentliches Profil** — Reseller wollen "ihren Shop" zeigen
6. **Mobile Barcode-Scanner** — schneller Workflow am Wareneingang
7. **Bulk-Edit + Templates** — Power-User-Feature für Vielnutzer
8. **API-Zugang** — entwicklerische Reseller zahlen extra dafür

### 5.3 Upsell-/Abo-Möglichkeiten

**Innerhalb der App (Just-in-Time-Upsells):**
- Free-User exportiert PDF → "Brauchst du mehr als 1 Export pro Monat? Upgrade auf Reseller"
- Free-User klickt auf "Bilder hinzufügen" → "Bilder sind Pro-Feature"
- Free-User erreicht 50 Deals → "Unlimited mit Reseller-Tier"

**Plattform-Modell-Optionen:**
- **App-Store für Integrationen**: Drittanbieter bauen Connectoren (z.B. Vinted, Etsy) → 30% Revenue-Share
- **Marketplace für Templates**: User verkaufen ihre Item-Templates / Workflow-Setups → 20% Cut
- **Daten-Insights** anonymisiert verkaufen: "Welche Sneaker-Modelle gehen 2026 am besten?" — Aggregat-Reports an Hersteller/Händler ab 199 €/Monat (DSGVO-Vorsicht!)

**Add-On-Strategie:**
- **AI-Pricing-Assistant** (zusätzlich 9 €/Monat): "Dieses Produkt verkauft sich aktuell für 84 € auf StockX, du hast 79 € als VK gesetzt. Anpassen?"
- **Backup-as-a-Service**: tägliche Off-Site-Backups, eigene S3-URL, ab 4,99 €/Monat
- **Custom-Reports**: Berater-Style PDF-Reports einmalig oder monatlich

### 5.4 Empfohlene 12-Monats-Monetarisierungs-Roadmap

```
Monat 0–2:  Sprint 4–5 abschließen (Bilder, Scanner, Bot, Notifications)
            Keine Monetarisierung, Fokus auf Polish + erste 100 Beta-User

Monat 3–4:  Free-Tier mit Limits live + Reseller-Tier 14,99 €/Mon
            Erste Marketplace-Integration (eBay)
            Ziel: 30 zahlende User (~450 €/Monat MRR)

Monat 5–6:  Pro-Tier launch + Discord-Bot + DATEV-Export
            Lifetime-Deal-Push auf einer Reseller-Plattform/Cookgroup
            Ziel: 80 zahlende User (~2.000 €/Monat MRR)

Monat 7–9:  Cookgroup-White-Label-Pilot mit 2 Partnern
            Mehr Marketplace-Connectoren
            Ziel: 200 zahlende User + 2 Cookgroups (~5.000 €/Monat MRR)

Monat 10–12: API + Team-Tier launch
             AI-Pricing als Add-on
             Ziel: 400 zahlende + 5 Cookgroups (~10.000 €/Monat MRR)
```

---

## TL;DR

**Was die App heute hat**: ein technisch solides, feature-reiches Reseller-Inventory mit
seltener Discord-Integration und gutem Statistik-Dashboard.

**Was sie bräuchte um Marktwert zu vervielfachen**: Bilder + Marketplace-Sync + Discord-Bot
+ Mobile-Polish + ein klarer Free/Paid-Schnitt.

**Wo das größte Geld liegt**: Cookgroup-White-Label (B2B-Nische, hohe Margen) und
DACH-spezifischer Steuer-Export (kein Wettbewerber in dem Feld). Beides skaliert mit
relativ wenig zusätzlicher Engineering-Arbeit, weil das Datenmodell schon stimmt.

**Was du in den nächsten 4 Wochen tun solltest**: Sprint 4 fokussieren auf Bilder +
Scanner + Notifications, parallel die Free/Paid-Trennung im Code vorbereiten
(Feature-Flags!), und einen ersten Cookgroup-Owner zum White-Label-Gespräch einladen.
