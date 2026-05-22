# Warenverwaltung Feature-Parity (Lexware-Stil)

> **[Committee-Approved 2026-05-20]**
> Erstellt: 2026-05-20 · Branch-Vorschlag: `feature/warenverwaltung-feature-parity`
> Status: Durch `/council` gelaufen (5 Reviewer), alle 13 Pflicht-Findings +
> 6 empfohlene Verbesserungen eingearbeitet. Siehe
> `## Committee-Review-Historie` am Plan-Ende.

---

## Ziel

Die App soll im Bereich **Warenverwaltung / Warenwirtschaft** ein vergleichbar
vollständiges, professionelles Funktions-Set wie eine etablierte Lösung (Lexware
Warenwirtschaft / Lexware Office) bekommen — ein sauberer **Artikelstamm**,
nachvollziehbare **Bestandsbuchungen**, **Lieferanten-Stammdaten mit
Bestellwesen**, **Wareneingang**, **Inventur** und **Reporting**. Da das ein
großes Bündel ist, wird es in priorisierte Epics geschnitten; Phase 1 (P0)
schließt die schmerzhaftesten Lücken, P1/P2 folgen iterativ.

---

## Gap-Analyse (Stand 2026-05-20, reale Codebase-Fakten)

### Was die App heute schon kann

Belegt durch `lib/models/inventory_item.dart`, `lib/models/supplier.dart`,
`lib/models/inventory_batch.dart`, `lib/providers/inventory_provider.dart`,
`lib/screens/inventory_screen.dart`, `lib/screens/suppliers_screen.dart`,
`lib/services/csv_service.dart` und den Migrations `20260430000000`,
`20260503000500`–`20260503000700`, `20260504000500`.

| Bereich | Heutiger Stand |
|---|---|
| Artikelstamm | `inventory_items`: `name`, `sku`, `ean`, `quantity`, `min_stock`, `location` (Freitext), `cost_price`, `arrival_date`, `status` (4 Werte), `note`, `supplier_id`, `deal_id`, `attachment_paths`, `is_public`/`public_price`/`public_description` |
| Lagerbestand | `quantity`-Feld pro Artikel; KPIs `totalStockQuantity`, `totalStockValue`, `criticalStockCount` im `InventoryProvider` |
| Bestandsbuchungen | `inventory_movements`-Tabelle existiert + `InventoryMovement`-Model; Provider erzeugt Movements bei `addInventoryItem`/`updateInventoryItem`/`adjustStock`/`checkInDeal`. **Reason ist Freitext** |
| Mindestbestand | `min_stock`-Spalte + `isCritical`-Getter + `criticalStockCount`-KPI |
| Lieferanten | `suppliers`-Tabelle + `SuppliersScreen` + `AddEditSupplierDialog`; Felder: `name`, `contact_name`, `email`, `phone`, `website`, `note`, `active` |
| Chargen / MHD | `inventory_batches` mit `batch_number`, `serial_number`, `mhd`, `quantity`; `InventoryBatchesSheet`-Widget |
| Barcode / SKU | `BarcodeScannerSheet`-Widget vorhanden; SKU + EAN als Freitext-Felder |
| Wareneingang via Deal | `checkInDeal()` bucht einen Deal als Lagerartikel ein |
| CSV Import/Export | `CsvService` mit 5-Sektionen-CSV (Deals/Shops/Käufer/Lieferanten/Lagerbestand) |
| Reporting | `StatisticsScreen` mit 5 Tabs inkl. `inventory_suppliers_tab.dart` |

### Lücken zu einer professionellen Warenwirtschaft

| # | Lücke | Heute | Lexware-Niveau | Prio |
|---|---|---|---|---|
| L1 | **Kein Produktkatalog getrennt vom Lagerbestand** — jeder `inventory_item` ist eine konkrete physische Charge, kein wiederverwendbarer Artikel-Stammsatz. Gleiches Produkt = mehrere Rows mit dupliziertem Namen/SKU | Pro Wareneingang neue Row | Stammartikel 1×, Bestand n× referenziert darauf | P1 (A-full) |
| L2 | **Keine Artikel-Kategorien / Warengruppen** | — | Hierarchische Warengruppen, Filter danach | P1 |
| L3 | **Bestandsbuchungs-`reason` ist Freitext** — keine typisierte, auswertbare Buchungsart (Wareneingang/Warenausgang/Korrektur/Inventur/Umlagerung) | Freitext `reason` | Enum-Buchungsarten, je auswertbar | P0 (A-lite) |
| L4 | **Kein Mehrlager / strukturierte Lagerorte** — `location` ist ein freier String pro Artikel | Freitext | Lager + Lagerplatz-Hierarchie, Bestand pro Lager | P1 |
| L5 | **Kein Bestellwesen** — keine Nachbestellungen / Purchase Orders an Lieferanten | — | Bestellung anlegen, Status verfolgen, an Wareneingang koppeln | P1 |
| L6 | **Kein dedizierter Wareneingang/Lieferschein** — nur `checkInDeal` (Deal-zentriert), kein PO-basierter Wareneingang mit Teil-/Mengenabgleich | Deal → Item | Wareneingangsbeleg gegen Bestellung, Soll/Ist | P1 |
| L7 | **Keine echte Inventur** — kein geführter Zähl-/Korrektur-Workflow mit Differenz-Report | manuelles `adjustStock` | Inventur-Session, Soll/Ist, Sammel-Korrekturbuchung | P2 |
| L8 | **Mindestbestand-Alerts nur passiv** — `criticalStockCount` ist ein KPI, kein Push, keine Nachbestell-Aktion | KPI | Aktiver Alert + Nachbestellvorschlag | P1 |
| L9 | **Keine Einstandspreis-Bewertung** — nur `cost_price` als Momentwert; keine gewichtete Durchschnittsbewertung über Wareneingänge | Snapshot | Gleitender Durchschnitt / FIFO-Bewertung | P2 |
| L10 | **Lieferanten-Stammdaten dünn** — keine Adresse, USt-IdNr, Zahlungsbedingungen, Lieferzeit, Mindestbestellwert, Artikel-Lieferanten-Zuordnung mit Lieferant-SKU/-Preis | 7 Felder | Vollständige Kreditoren-Stammdaten | P1 |
| L11 | **Kein Artikel-Detail-Screen** — Artikel werden nur in Listen-Cards + Edit-Dialog gezeigt; keine 360°-Sicht (Bewegungshistorie, Chargen, Lieferant, Bestellungen) | Card + Dialog | Detail mit Tabs/Historie | P0 (A-lite) |
| L12 | **Reporting flach** — keine Lagerumschlag-/Reichweiten-/Ladenhüter-/ABC-Analyse, kein dedizierter Inventurwert-Report mit Stichtag | 5 Stat-Tabs | Bestandsbewertung, Umschlag, ABC | P2 |
| L13 | **CSV-Import/Export deckt neues Schema nicht ab** — `CsvService` kennt nur die heutigen Spalten | 5 Sektionen | muss mit Katalog/Kategorien/Lager/PO mitwachsen | P1 |

---

## Scope

### In Scope (dieser Plan, alle Epics)

> **Committee-Finding 1 — Epic A entkoppelt.** Epic A wird in zwei
> Sub-Epics geschnitten:
> - **Epic A-lite (P0):** echtes P0, niedrig-riskant — getypte
>   `inventory_movements.movement_type` (Migration + Model +
>   Provider-Umstellung) und ein `ProductDetailScreen`, der auf der
>   **bestehenden `inventory_items`-Row** aufsetzt (kein neues `products`).
>   Bricht weder `checkInDeal`/`TicketSummary` noch den Archive-Trigger.
> - **Epic A-full (P1):** der teure/riskante Block — die `products`-
>   Stammkatalog-Tabelle + additive Verknüpfung. **Direkt VOR Epic C**
>   platziert, weil das Bestellwesen den Stammkatalog zwingend braucht.

- **Epic A-lite (P0):** Getypte Buchungsarten auf `inventory_movements`
  (`movement_type`-Enum) + Artikel-Detail-Screen auf der bestehenden
  `inventory_items`-Row.
- **Epic B (P1):** Kategorien/Warengruppen + erweiterte Lieferanten-Stammdaten
  + Artikel-Lieferanten-Zuordnung.
- **Epic A-full (P1):** Artikelstamm-Refactor — `products` als Stammkatalog,
  `inventory_items` bekommt eine **dauerhaft nullable** `product_id`-
  Referenz. Liegt unmittelbar vor Epic C.
- **Epic C (P1):** Bestellwesen (Purchase Orders) + Wareneingang gegen
  Bestellung. Setzt Epic A-full voraus.
- **Epic D (P1):** Mehrlager/Lagerorte (strukturiert) + aktive
  Mindestbestand-Alerts/Nachbestellvorschläge.
- **Epic E (P2):** Inventur-Workflow + erweitertes Reporting (Bestandsbewertung,
  Umschlag, ABC) + Bewertungsverfahren.
- **Epic F (P1, querschnittlich):** CSV-Import/Export an das neue Schema
  anpassen; Handbuch + Hilfeseite nachziehen.

**Epic-Reihenfolge (verbindlich):** A-lite → B → A-full → C → D → E → F.

### Out of Scope (bewusst NICHT in diesem Plan)

- **Rechnungserstellung / Buchhaltung** — die App ist Warenwirtschaft, nicht
  Faktura. Der Stakeholder-Wunsch zielt explizit auf *Warenverwaltung*. Das
  bestehende `billing_profiles` + `lexware`-Feld bleiben unangetastet.
- **DATEV-/ELSTER-Export, GoBD-Konformität** — Buchhaltungs-Compliance.
- **Externe Shop-/Marktplatz-Sync** (Amazon-Bestandssync, Otto, eBay
  Inventory-API) — eigenes Großprojekt.
- **Echtes Multi-Currency-Lager-Reporting** über Wechselkurse.
- **EDI / automatische Bestellübermittlung an Lieferanten-Systeme.**
- **Migration von Bestandsdaten echter Nutzer** — Pre-Launch, keine echten
  Nutzer; **es gibt keinen Backfill** (siehe Datenmodell, Finding 2).
- **Rückstandsverwaltung / Reservierungs-Engine** über mehrere Aufträge.
- **`data_table_2`-Package** — vom External-Scout geprüft und **verworfen**.
  Tabellen-Darstellung auf Desktop löst der bestehende `LayoutBuilder`-
  Ansatz; kein neues Tabellen-Package wird eingeplant.

---

## Datenmodell + RLS

> **Audit-Spalten-Vorspann gilt nur für ECHTE NEU-Tabellen.** Alle neuen
> Tabellen (`products`, `product_categories`, `product_suppliers`,
> `purchase_orders`, `purchase_order_items`, `warehouses`, `stocktakes`,
> `stocktake_items`, `purchase_order_counters`) bekommen das RLS-Pattern
> strikt nach `20260504000500_data_workspace_scope.sql`: `workspace_id
> NOT NULL` + FK, `user_id` als Erfasser-Spalte, Policies über
> `is_workspace_member` (read) und `has_workspace_role(...,['owner',
> 'admin','member'])` (write). Audit-Spalten `created_at`/`updated_at`/
> `deleted_at` + Touch-Trigger wie bei `suppliers`.
> **Ausnahme:** `inventory_movements` ist KEINE Neu-Tabelle und bekommt
> KEINE `updated_at`/`deleted_at`/Touch-Trigger — siehe nächster Absatz.
> Migration-Namensschema `YYYYMMDDHHMMSS_<slug>.sql`.

### Querschnitt: `inventory_movements` bleibt append-only (Committee-Finding 5)

Verifiziert in `20260504000500_data_workspace_scope.sql` (Zeilen 346–353):
`inventory_movements` trägt heute **nur** `inventory_movements_ws_read`
+ `inventory_movements_ws_insert` — kein UPDATE, kein DELETE. Das ist ein
**Audit-Journal** und bleibt es:

- Die generische 4-Policy-RLS-Skizze (read/insert/update/delete) am Ende
  dieses Kapitels gilt für `inventory_movements` **NICHT**.
- Movement-Korrekturen / Stornos laufen ausschließlich über
  **Gegenbuchungen** (neue Row mit invertierter Menge), nie über UPDATE/
  DELETE bestehender Rows.
- `inventory_movements` bekommt **keine** `updated_at`/`deleted_at`/Touch-
  Trigger — der Audit-Spalten-Vorspann oben ist nur für echte NEU-Tabellen.
- Der `movement_type`-Backfill (A-lite) läuft als **Migration mit
  Service-Role** (RLS-Bypass) — das ist zulässig und der einzige Weg,
  bestehende Rows nachträglich zu typisieren, ohne die Insert-only-Policy
  zu verletzen.

### Querschnitt: Archive-Trigger bleibt intakt (Committee-Finding 4)

Der Trigger `inventory_check_ticket_archive_trg` (definiert in
`20260509000300_archive_triggers.sql`, Zeilen 182–187) feuert
`AFTER UPDATE OF status, ticket_number, workspace_id, deleted_at` auf
`inventory_items` und resolved das Ticket über
`(workspace_id, ticket_number)`. Daraus folgt verbindlich:

- **`status` bleibt physisch auf der `inventory_items`-Bestands-Row.**
  `status` wird NICHT auf `products` verschoben. Der Trigger und seine
  Funktion `tg_check_ticket_archive_from_inventory` bleiben unverändert
  — **keine Migration am Trigger nötig**.
- `ticket_number` bleibt ebenfalls auf der Bestands-Row.
- Konsequenz für A-full: `products` ist reiner Stammkatalog (Was ist das
  Produkt?), `inventory_items` bleibt die Bestands-/Vorgangs-Row (Wie viel
  liegt wo, in welchem Vorgangs-Status, zu welchem Ticket?).

### Querschnitt: FK-Cross-Workspace-Validierung (Committee-Finding 6)

Jede neue FK-Spalte, die auf eine andere workspace-scoped Tabelle zeigt,
muss DB-seitig erzwingen, dass die referenzierte Row im **selben
Workspace** liegt — ein reiner FK reicht nicht (er erlaubt Cross-Workspace-
Referenzen). Betroffene Spalten:

`products.category_id`, `products.default_supplier_id`,
`inventory_items.product_id`, `inventory_items.warehouse_id`,
`purchase_orders.supplier_id`, `purchase_order_items.product_id`,
`purchase_order_items.purchase_order_id`, `product_suppliers.product_id`,
`product_suppliers.supplier_id`, `stocktake_items.product_id`,
`stocktakes.warehouse_id`.

**Gewählte Variante:** `BEFORE INSERT OR UPDATE`-Trigger pro Tabelle,
`SECURITY DEFINER`, `SET search_path = public, pg_temp`. Der Trigger prüft
per `EXISTS`, dass die referenzierte Row dieselbe `workspace_id` trägt wie
die einfügende Row, und wirft sonst eine Exception. Begründung gegenüber
`WITH CHECK`-Policy: Trigger sind unabhängig vom Policy-Rollen-Set und
greifen auch beim Service-Role-Pfad (Demo-Seed, Migrationen).

**Pflicht** mindestens für die Kind-/Verknüpfungstabellen
`purchase_order_items`, `stocktake_items`, `product_suppliers`. Für die
übrigen Spalten ebenfalls umgesetzt. Jeder Epic-Migrationsblock trägt
einen **eigenen Migrations-Teiltask** „FK-Cross-Workspace-Validierung".

### Epic A-lite — getypte Buchungsarten (P0)

**GEÄNDERT: `inventory_movements`** — getypte Buchungsart
- NEUE Spalte: `movement_type TEXT NOT NULL DEFAULT 'correction'
  CHECK (movement_type IN ('goods_in','goods_out','correction','stocktake','transfer','sale'))`.
- NEUE Spalte: `unit_cost NUMERIC(12,2)` — Einstandspreis der Buchung (für L9).
- `reason` (Freitext) bleibt als optionale Detail-Notiz.
- Backfill: bestehende Rows bekommen `movement_type` per Heuristik aus `reason`
  (`'Einbuchung*'`→`goods_in`, `'Ausbuchung*'`→`goods_out`, sonst `correction`).
  Backfill läuft als Migration mit Service-Role (RLS-Bypass, siehe
  Append-only-Absatz oben).
- **Kein** `product_id` auf `inventory_movements` in A-lite — diese Spalte
  kommt erst mit Epic A-full (siehe unten).
- A-lite legt **keine** neue Tabelle an; `inventory_movements` behält seine
  2-Policy-RLS.

**NEU: `ProductDetailScreen` auf bestehender `inventory_items`-Row** —
360°-Sicht ohne `products`-Tabelle: Stammdaten der Bestands-Row, aktueller
Bestand, Bewegungshistorie (jetzt getypt), Chargen, Lieferant. Wird in
Epic A-full additiv um Produkt-Aggregation erweitert.

### Epic A-full — Artikelstamm (P1)

**NEU: Tabelle `products`** (Stammkatalog — der wiederverwendbare Artikel)
```
id            UUID PK DEFAULT gen_random_uuid()
workspace_id  UUID NOT NULL  → workspaces(id) ON DELETE CASCADE
user_id       UUID NOT NULL  → auth.users(id)
name          TEXT NOT NULL CHECK (length BETWEEN 1 AND 200)
sku           TEXT            -- Artikelnummer, eindeutig pro Workspace
ean           TEXT CHECK (ean ~ '^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$')  -- aus 20260503000500
category_id   UUID            → product_categories(id) ON DELETE SET NULL  (Epic B)
default_supplier_id UUID      → suppliers(id) ON DELETE SET NULL
unit          TEXT NOT NULL DEFAULT 'Stk'   -- Mengeneinheit
default_cost_price  NUMERIC(12,2)
default_sale_price  NUMERIC(12,2)
min_stock     INTEGER NOT NULL DEFAULT 0    -- zieht vom Item auf Produkt um
tax_rate      NUMERIC(5,2)
note          TEXT
is_active     BOOLEAN NOT NULL DEFAULT TRUE
created_at / updated_at / deleted_at TIMESTAMPTZ
```
- RLS: `products_ws_read/insert/update/delete` (Standard-4-Policy-Pattern).
- Index: `(workspace_id)`, partial `UNIQUE (workspace_id, lower(sku)) WHERE sku IS NOT NULL AND deleted_at IS NULL`, `(workspace_id, category_id)`.
- FK-Cross-Workspace-Trigger für `category_id` + `default_supplier_id`.

**GEÄNDERT: `inventory_items`** wird (additiv) zur Bestands-Row

> **Committee-Finding 2 — `product_id` ist dauerhaft NULLABLE.** Es gibt
> **keinen NOT-NULL-Schritt und keinen Zwangs-Backfill.** `product_id`
> ist ein rein **additiver, dauerhaft nullable FK**. Bestehende Items
> ohne verknüpftes Produkt funktionieren unverändert weiter; nur neue
> Wareneingänge / PO-Receipts verlinken auf ein Produkt. Begründung:
> Pre-Launch = keine echten Daten — ein Backfill wäre verschwendete
> Komplexität und zusätzliches Risiko ohne Nutzen.

- NEUE Spalte: `product_id UUID → products(id) ON DELETE SET NULL`
  — **dauerhaft nullable**, kein NOT-NULL-Constraint, kein Backfill.
  (`ON DELETE SET NULL` statt `RESTRICT`, damit ein gelöschtes Produkt
  keine Bestands-Rows blockiert.)
- `inventory_items.name`/`sku`/`ean`/`min_stock` bleiben physisch erhalten
  (kein DROP) und funktional gültig für nicht-verknüpfte Bestands-Rows.
  Bei verknüpften Rows ist `products` die primäre Anzeigequelle.
- NEUE Spalte: `warehouse_id UUID → warehouses(id)` (nullable, Epic D füllt).
- **`status` bleibt auf `inventory_items`** (Archive-Trigger, Finding 4).
- FK-Cross-Workspace-Trigger für `product_id` + `warehouse_id`.

**GEÄNDERT: `inventory_movements`** — Produkt-Verknüpfung (A-full-Teil)
- NEUE Spalte: `product_id UUID → products(id) ON DELETE SET NULL` (parallel
  zum bestehenden `item_id`, für katalogweite Auswertung).
- Index `(workspace_id, product_id)` — für Produkt-Detail-Movement-History.
- Append-only-Charakter bleibt; weiterhin nur 2-Policy-RLS.

**NEU: DB-View `product_stock`** (Committee-Finding 9) — die **einzige
Bestands-Wahrheit** für Low-Stock-Alerts (D4) und Produkt-Detail-Aggregation:
```sql
CREATE VIEW public.product_stock AS
SELECT
  i.workspace_id,
  i.product_id,
  i.warehouse_id,
  SUM(i.quantity)                              AS qty_in_warehouse
FROM public.inventory_items i
WHERE i.deleted_at IS NULL
  AND i.product_id IS NOT NULL
GROUP BY i.workspace_id, i.product_id, i.warehouse_id;
```
- **Aggregations-Achse:** pro `(workspace_id, product_id, warehouse_id)` —
  liefert Bestand pro Lager. Gesamtbestand pro Produkt = Summe darüber
  (`GROUP BY workspace_id, product_id`).
- Die View erbt RLS implizit über die zugrunde liegende `inventory_items`-
  Policy (View ohne `security_invoker` läuft mit Definer-Rechten — daher
  View explizit als `security_invoker = true` anlegen, damit die
  `inventory_items_ws_read`-Policy greift).
- Konsumenten: `product_stock` ersetzt Ad-hoc-Summen in D4 (Low-Stock) und
  im Produkt-Detail. Nicht-verknüpfte Bestands-Rows (`product_id IS NULL`)
  fallen bewusst raus — sie haben kein Produkt-Mindestbestand-Ziel.

### Epic B — Kategorien + Lieferanten-Erweiterung

**NEU: Tabelle `product_categories`**
```
id            UUID PK
workspace_id  UUID NOT NULL → workspaces(id)
user_id       UUID NOT NULL
name          TEXT NOT NULL CHECK (length BETWEEN 1 AND 100)
parent_id     UUID → product_categories(id) ON DELETE SET NULL   -- Hierarchie
sort_order    INTEGER NOT NULL DEFAULT 0
created_at / updated_at / deleted_at
```
- RLS Standard-4-Policy-Pattern. Index `(workspace_id)`, `(workspace_id, parent_id)`.
- Tiefe in der App auf 2 Ebenen begrenzen (App-seitige Validierung, kein
  DB-Constraint).
- FK-Cross-Workspace-Trigger für `parent_id` (self-referenziell, derselbe
  Workspace).

**GEÄNDERT: `suppliers`** — erweiterte Kreditoren-Stammdaten
- NEUE Spalten: `address_street`, `address_zip`, `address_city`,
  `address_country TEXT DEFAULT 'DE'`, `vat_id TEXT` (USt-IdNr),
  `customer_number TEXT` (eigene Kundennummer beim Lieferanten),
  `payment_terms_days INTEGER`, `lead_time_days INTEGER` (Lieferzeit),
  `min_order_value NUMERIC(12,2)`.
- Alle nullable, kein Backfill nötig.

**NEU: Tabelle `product_suppliers`** (Artikel-Lieferanten-Zuordnung n:m)
```
id            UUID PK
workspace_id  UUID NOT NULL → workspaces(id)
user_id       UUID NOT NULL
product_id    UUID NOT NULL → products(id) ON DELETE CASCADE
supplier_id   UUID NOT NULL → suppliers(id) ON DELETE CASCADE
supplier_sku  TEXT            -- Artikelnummer beim Lieferanten
supplier_price NUMERIC(12,2)  -- Einkaufspreis bei diesem Lieferanten
is_preferred  BOOLEAN NOT NULL DEFAULT FALSE
created_at / updated_at / deleted_at
UNIQUE (workspace_id, product_id, supplier_id) WHERE deleted_at IS NULL
```
- RLS Standard-4-Policy-Pattern.
- FK-Cross-Workspace-Trigger für `product_id` + `supplier_id` (**Pflicht**).
- Partial-UNIQUE für „nur ein bevorzugter Lieferant pro Produkt":
  `UNIQUE (workspace_id, product_id) WHERE is_preferred AND deleted_at IS NULL`
  (Committee-Empfehlung 5).

> **Hinweis Epic-Abhängigkeit:** `product_suppliers` referenziert
> `products` und gehört damit logisch nach A-full. Epic B liefert in der
> hier verbindlichen Reihenfolge (A-lite → B → A-full) zunächst nur
> `product_categories` + die `suppliers`-Erweiterung; die
> `product_suppliers`-Tabelle wird im A-full-Cluster mitgezogen — siehe
> Task-Liste B1/B-Split.

### Epic A-full — Produkt-Stammkatalog (P1, Tabellen oben definiert)

Siehe Abschnitt „Epic A-full — Artikelstamm" weiter oben. Liegt in der
Reihenfolge unmittelbar vor Epic C.

### Epic C — Bestellwesen

**NEU: Tabelle `purchase_orders`**
```
id            BIGSERIAL PK
workspace_id  UUID NOT NULL → workspaces(id)
user_id       UUID NOT NULL
supplier_id   UUID NOT NULL → suppliers(id) ON DELETE RESTRICT
order_number  TEXT NOT NULL          -- generiert, z.B. "PO-2026-0001"
status        TEXT NOT NULL DEFAULT 'draft'
              CHECK (status IN ('draft','ordered','partially_received','received','cancelled'))
order_date    TIMESTAMPTZ
expected_date TIMESTAMPTZ
note          TEXT
total_net     NUMERIC(12,2)          -- denormalisierte Summe, von Trigger gepflegt
created_at / updated_at / deleted_at
UNIQUE (workspace_id, order_number) WHERE deleted_at IS NULL
```
- FK-Cross-Workspace-Trigger für `supplier_id`.

**NEU: Tabelle `purchase_order_items`**
```
id            UUID PK
workspace_id  UUID NOT NULL → workspaces(id)
purchase_order_id BIGINT NOT NULL → purchase_orders(id) ON DELETE CASCADE
product_id    UUID NOT NULL → products(id) ON DELETE RESTRICT
quantity_ordered  INTEGER NOT NULL CHECK (> 0)
quantity_received INTEGER NOT NULL DEFAULT 0 CHECK (>= 0)
unit_price    NUMERIC(12,2)
created_at / updated_at / deleted_at
```
- RLS für beide: Standard-4-Policy-Pattern. `purchase_order_items` filtert
  über eigene `workspace_id`-Spalte (nicht über Parent), konsistent mit
  `inventory_movements`.
- FK-Cross-Workspace-Trigger für `product_id` + `purchase_order_id`
  (**Pflicht** — Kind-Tabelle).
- Trigger: bei `purchase_order_items`-Update von `quantity_received` →
  `purchase_orders.status` automatisch auf `partially_received`/`received`
  setzen (analog `archive_triggers.sql`).

**NEU: Tabelle `purchase_order_counters`** (Committee-Finding 12 — nur falls
RPC-Variante gewählt; siehe API-Kapitel)
```
workspace_id  UUID PK → workspaces(id) ON DELETE CASCADE
year          INTEGER NOT NULL
last_seq      INTEGER NOT NULL DEFAULT 0
```
- RLS: nur read für Workspace-Mitglieder; geschrieben ausschließlich von
  der `SECURITY DEFINER`-RPC. Siehe API-Kapitel für die Entscheidung
  client-seitig vs. RPC.

**PO-Wareneingang — atomar (Committee-Finding 12):** Beim Buchen eines
Wareneingangs wird `purchase_order_items.quantity_received` **serverseitig
atomar inkrementiert** — `SET quantity_received = quantity_received + :x`
in einem einzigen UPDATE bzw. via RPC. **Kein Read-modify-write im Client**
— sonst verlieren parallele Buchungen Daten. Der Status-Trigger oben feuert
auf dieses UPDATE.

### Epic D — Mehrlager + Alerts

**NEU: Tabelle `warehouses`**
```
id            UUID PK
workspace_id  UUID NOT NULL → workspaces(id)
user_id       UUID NOT NULL
name          TEXT NOT NULL CHECK (length BETWEEN 1 AND 100)
address       TEXT
is_default    BOOLEAN NOT NULL DEFAULT FALSE
is_active     BOOLEAN NOT NULL DEFAULT TRUE
created_at / updated_at / deleted_at
```
- RLS Standard-4-Policy-Pattern. Beim ersten Workspace-Touch via App ein
  Default-Lager „Hauptlager" anlegen (App-seitig, nicht per DB-Trigger —
  vermeidet komplexe Migration).
- Partial-UNIQUE „nur ein Default-Lager pro Workspace":
  `UNIQUE (workspace_id) WHERE is_default AND deleted_at IS NULL`
  (Committee-Empfehlung 5).
- `inventory_items.warehouse_id` (aus Epic A-full) wird hier aktiv genutzt;
  `inventory_items.location` (Freitext) bleibt als „Lagerplatz" innerhalb des
  Lagers erhalten.
- Mindestbestand-Alerts brauchen **keine** neue Tabelle — sie nutzen den
  `product_stock`-View vs. `products.min_stock`. Push-Versand reuse der
  bestehenden `send-notifications`-Function + `notification_preferences`.

**Low-Stock-Push — nachgeschärft (Committee-Finding 7):**
- **Migration:** `notifications_sent.ref_kind`-CHECK-Constraint erweitern.
  Verifiziert in `20260503001000_push_notifications.sql` (Zeile 56): heute
  `CHECK (ref_kind IN ('mhd','delivery','payment'))`. Neuer erlaubter Wert:
  `'low_stock'`. Die Migration muss den bestehenden Constraint droppen und
  neu anlegen (`ALTER TABLE ... DROP CONSTRAINT ... ; ADD CONSTRAINT ...`).
- Optional `workspace_id`-Spalte auf `notifications_sent` ergänzen, damit
  Dedup pro Workspace sauber greift (heute PK
  `(user_id, ref_kind, ref_id)`).
- **Empfänger:** nur aktive `workspace_members` des betroffenen Workspaces,
  gefiltert über vorhandene Notification-Preference (`notification_preferences`).
- **Aggregation:** strikt `GROUP BY workspace_id, product_id`; jeder Alert
  trägt genau **eine** `workspace_id`. Ein Sammel-Push pro Workspace, nicht
  pro Produkt.
- **PII-arm:** Der FCM-Klartext-Payload enthält nur eine Zahl —
  „X Artikel unter Mindestbestand". **Keine** Produktnamen, Mengen oder
  Lieferantendaten im Push-Body. Details erst beim Tap im In-App-Screen.
- **Kein `console.log`** von Produktdaten / PII in der Edge Function.

### Epic E — Inventur

**NEU: Tabelle `stocktakes`** (Inventur-Session)
```
id            BIGSERIAL PK
workspace_id  UUID NOT NULL → workspaces(id)
user_id       UUID NOT NULL
warehouse_id  UUID → warehouses(id) ON DELETE SET NULL
status        TEXT NOT NULL DEFAULT 'open'
              CHECK (status IN ('open','counting','closed','cancelled'))
title         TEXT
started_at    TIMESTAMPTZ
closed_at     TIMESTAMPTZ
created_at / updated_at / deleted_at
```
- FK-Cross-Workspace-Trigger für `warehouse_id`.

**NEU: Tabelle `stocktake_items`**
```
id            UUID PK
workspace_id  UUID NOT NULL → workspaces(id)
stocktake_id  BIGINT NOT NULL → stocktakes(id) ON DELETE CASCADE
product_id    UUID NOT NULL → products(id) ON DELETE RESTRICT
expected_qty  INTEGER NOT NULL    -- Soll-Bestand zum Snapshot-Zeitpunkt
counted_qty   INTEGER             -- NULL = noch nicht gezählt
created_at / updated_at
```
- RLS Standard-4-Policy-Pattern. Beim Schließen einer Inventur erzeugt die
  App pro Differenz eine `inventory_movements`-Row mit
  `movement_type='stocktake'` (append-only, siehe Querschnitt).
- FK-Cross-Workspace-Trigger für `product_id` + `stocktake_id`
  (**Pflicht** — Kind-Tabelle).

### RLS-Policy-Skizze (gilt für alle echten NEU-Tabellen)

> **Gilt NICHT für `inventory_movements`** — diese Tabelle behält ihre
> bestehende 2-Policy-RLS (read + insert), siehe Querschnitt-Absatz oben.

```sql
ALTER TABLE public.<t> ENABLE ROW LEVEL SECURITY;
CREATE POLICY <t>_ws_read   ON public.<t> FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY <t>_ws_insert ON public.<t> FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY <t>_ws_update ON public.<t> FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY <t>_ws_delete ON public.<t> FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));
```

### FK-Cross-Workspace-Trigger-Skizze (Committee-Finding 6)

```sql
CREATE OR REPLACE FUNCTION public.assert_<col>_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.<fk_col> IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.<referenced_table> r
    WHERE r.id = NEW.<fk_col>
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for <fk_col>';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER <t>_<col>_ws_check
  BEFORE INSERT OR UPDATE OF <fk_col> ON public.<t>
  FOR EACH ROW EXECUTE FUNCTION public.assert_<col>_same_workspace();
```

### Down-Migrations / Reversibilität (Committee-Empfehlung 3)

Pro invasiver Migration gilt: **entweder** eine Down-Migration mitliefern
(DROP der hinzugefügten Spalten/Tabellen/Trigger), **oder** explizit als
„irreversibel ab Merge" dokumentieren. Für diesen Plan wird festgelegt:

- Reine `CREATE TABLE`-Migrationen (`products`, `product_categories`, …):
  Down = `DROP TABLE` — günstig, wird mitgeliefert.
- Spalten-Ergänzungen auf bestehenden Tabellen (`inventory_movements.movement_type`,
  `inventory_items.product_id`, `suppliers`-Erweiterung): Down = `DROP COLUMN`
  — wird mitgeliefert, **aber** der `movement_type`-Backfill ist
  datenverlust-relevant beim Down (Typ-Info weg). Das wird im Migrations-
  Kommentar als bewusster Hinweis vermerkt.
- Der `ref_kind`-CHECK-Constraint-Tausch (D-Migration) ist **bewusst als
  „irreversibel ab Merge" dokumentiert** — ein Down würde bestehende
  `low_stock`-Rows verletzen.

---

## API / Edge Functions

- **Keine zwingend neue Edge Function für Epic A-lite/A-full/B/C/E.** CRUD
  läuft über den Supabase-Client via `SupabaseRepository` (RLS schützt). Das
  ist konsistent mit dem bestehenden Inventory-/Supplier-Pfad.
- **GEÄNDERT: `seed-demo-workspace`** (Committee-Finding 3) — die Function
  `supabase/functions/seed-demo-workspace/index.ts` inserted heute
  `inventory_items` mit einem festen Spalten-Set (verifiziert: Zeilen
  836–841, `inventoryPayload`) und `inventory_movements` (Zeile 493). Sie
  muss synchron zu den Schema-Änderungen angepasst werden:
  - Nach A-lite: `movement_type` bei jedem `inventory_movements`-Insert
    setzen (sonst greift nur der DEFAULT `'correction'`).
  - Nach A-full: optional `products` mitanlegen und die Demo-`inventory_items`
    über `product_id` verlinken.
  - Die Anpassung läuft **im selben PR/Task-Cluster wie die jeweilige
    Migration** (A-lite-Migration bzw. A-full-Migration).
  - Ebenfalls betroffen und im selben Cluster mitzuziehen:
    `lib/services/demo_data_service.dart` und `lib/services/csv_service.dart`
    (Letzteres voll erst in Epic F, aber Schema-Awareness ab A-lite).
- **GEÄNDERT: `send-notifications`** (Epic D) — neuer Notification-Typ
  `low_stock` (`ref_kind`). Details siehe Datenmodell „Low-Stock-Push —
  nachgeschärft". Kein neuer Cron-Job nötig, an bestehenden
  `send-notifications`-Schedule andocken.
- **`order_number`-Vergabe (Committee-Finding 12, Offene Frage 2 — ENTSCHIEDEN):**
  Für Pre-Launch wird die **client-seitige Vergabe mit erlaubten Lücken**
  gewählt (einfachste sichere Variante, kein Race-Risiko mit Datenverlust,
  nur kosmetische Lücken). Die `UNIQUE (workspace_id, order_number)`-
  Constraint fängt Kollisionen ab; bei Kollision retryt der Client.
  - **Fallback-Variante (falls lückenlose Nummern später Pflicht werden):**
    `SECURITY DEFINER`-RPC `next_purchase_order_number(workspace_id)`. Diese
    RPC MUSS dann zwingend: (a) `is_workspace_member(workspace_id, auth.uid())`
    im Body prüfen und bei Fehlschlag `RAISE EXCEPTION`, (b)
    `SET search_path = public, pg_temp`, (c) `GRANT EXECUTE` nur an die
    Rolle `authenticated` (kein `anon`, kein `public`), (d) die
    `purchase_order_counters`-Tabelle via `SELECT ... FOR UPDATE`
    race-frei hochzählen. Diese Variante ist im Plan dokumentiert, aber
    **nicht** als Task eingeplant (P-späteres-Increment).
- Kein neues Secret, kein `supabase secrets set` nötig.
- **PDF-Belege (Epic C, External-Scout):** Bestell-PDF und Lieferschein-PDF
  werden über das **bereits gebundene `pdf`/`printing`-Package** erzeugt —
  das Pattern existiert in `lib/services/statistics_export_service.dart` und
  wird wiederverwendet. Kein neues Package.

---

## UI + l10n-Keys

> Mobile-First Pflicht (CLAUDE.md): Phone-Viewport 360/390 zuerst, Touch-Targets
> ≥ 48 dp, Bottom-Nav vs. Sidebar via `MediaQuery.sizeOf`. Alle Strings in
> `lib/l10n/app_de.arb` UND `app_en.arb`. Vor `/ship`:
> `smoke-full-app-audit` + `/check-l10n`.

### Navigation — ENTSCHIEDEN (Committee-Finding 10)

> Offene Frage 1 (Nav-Struktur) ist **entschieden**, das alte Risiko 4 war
> falsch formuliert (das Problem ist nicht die Bottom-Nav an sich, sondern
> dass das „Mehr"-Sheet überläuft, wenn jeder Bereich ein eigener Tab wird).

**Festlegung:** Es kommt **genau EIN** neuer `MainTab`-Wert hinzu:
`warehouse` („Warenwirtschaft"). Dieser zeigt einen neuen
**Hub-Screen `lib/screens/warehouse_hub_screen.dart` (NEU)**. Alle weiteren
Bereiche — **Bestellungen, Lager, Kategorien, Inventur, Reporting** — sind
**gepushte Sub-Routen INNERHALB des Hubs**, kein eigener `MainTab` pro
Bereich.

Konsequenz für `lib/screens/main_screen.dart`: `_navIcons`, `_navLabels`,
`_navVisibility` und `_bottomNavTabs` werden **genau EINMAL** erweitert
(um den `warehouse`-Hub). Tasks C5 / D3 / E3 fügen **keinen** weiteren
`MainTab` hinzu — sie liefern jeweils nur eine Sub-Route, die der Hub
anbietet.

### A-lite — getypte Buchungen + Artikel-Detail (P0)
- **NEU: `lib/screens/product_detail_screen.dart`** — 360°-Sicht auf der
  **bestehenden `inventory_items`-Row**: Stammdaten, aktueller Bestand,
  Bewegungshistorie (jetzt getypt mit Buchungsart-Badges), Chargen,
  Lieferant. In A-full additiv um Produkt-Aggregation erweitert.
- **GEÄNDERT: `inventory_screen.dart`** — Movement-Anzeige nutzt
  `movement_type` für Badge/Farbe statt Freitext-`reason`.
- **States** (Pflicht-Unterpunkt): empty (`productDetailEmpty` +
  `productDetailEmptyHint`), loading (`skeletonizer`), error mit Retry
  (`productDetailLoadError`), no-network, **no-permission** (Viewer-Rolle
  → Buchungs-Buttons via `has_workspace_role` ausgeblendet/disabled).
- **A11y-Keys:** `Key('productDetailScrollView')`,
  `Key('movementHistoryList')`, `Key('movementRow-<id>')`.
- l10n-Keys (DE / EN):
  `productDetailTitle` „Artikeldetails" / „Product details";
  `productDetailEmpty` „Keine Daten" / „No data";
  `productDetailEmptyHint` „Für diesen Artikel gibt es noch keine Bewegungen." / „No movements for this item yet.";
  `productDetailLoadError` „Artikeldetails konnten nicht geladen werden." / „Could not load product details.";
  `movementTypeGoodsIn` „Wareneingang" / „Goods in";
  `movementTypeGoodsOut` „Warenausgang" / „Goods out";
  `movementTypeCorrection` „Korrektur" / „Correction";
  `movementTypeStocktake` „Inventur" / „Stocktake";
  `movementTypeTransfer` „Umlagerung" / „Transfer";
  `movementTypeSale` „Verkauf" / „Sale";
  `movementHistoryTitle` „Bewegungshistorie" / „Movement history".

### Epic B — Kategorien + Lieferanten
- **NEU: `lib/screens/categories_screen.dart`** — Warengruppen-Baum
  verwalten, als Sub-Route des Warenwirtschaft-Hubs.
- **GEÄNDERT: `add_edit_supplier_dialog.dart`** — neue Felder Adresse, USt-IdNr,
  Zahlungsziel, Lieferzeit, Mindestbestellwert (zusammenklappbarer Abschnitt
  „Erweitert" damit der Dialog auf Phone nicht überläuft;
  `SingleChildScrollView` + `SafeArea` + `MediaQuery.viewInsetsOf`).
- **States** (`categories_screen`): empty (`categoriesEmpty` +
  `categoriesEmptyHint`), loading, error (`categoriesLoadError`),
  no-network, no-permission (Viewer → kein FAB).
- **A11y-Keys:** `Key('categoryNewFab')`, `Key('categoryRow-<id>')`,
  `Key('categoryParentDropdown')`.
- l10n-Keys:
  `categoriesTitle` „Warengruppen" / „Categories";
  `categoriesEmpty` „Keine Warengruppen" / „No categories";
  `categoriesEmptyHint` „Lege deine erste Warengruppe an." / „Create your first category.";
  `categoriesLoadError` „Warengruppen konnten nicht geladen werden." / „Could not load categories.";
  `categoryNew` „Neue Warengruppe" / „New category";
  `categoryParent` „Übergeordnet" / „Parent category";
  `supplierAddress` „Adresse" / „Address";
  `supplierVatId` „USt-IdNr" / „VAT ID";
  `supplierPaymentTerms` „Zahlungsziel (Tage)" / „Payment terms (days)";
  `supplierLeadTime` „Lieferzeit (Tage)" / „Lead time (days)";
  `supplierMinOrderValue` „Mindestbestellwert" / „Minimum order value";
  `supplierAdvancedSection` „Erweiterte Angaben" / „Advanced details".

### Epic A-full — Artikelstamm-UI
- **GEÄNDERT: `inventory_screen.dart`** — Stock-Tab zeigt Produkte
  (gruppiert über `product_id`), nicht mehr rohe Items. Nicht-verknüpfte
  Bestands-Rows erscheinen als eigene „ohne Produkt"-Gruppe. Tap → Detail.
- **NEU: `AddEditProductDialog`** für den Stammsatz; der bestehende
  Bestands-/Wareneingangs-Dialog verlinkt optional auf `product_id`.
- **GEÄNDERT: `product_detail_screen.dart`** — aggregiert jetzt über alle
  Bestands-Rows des Produkts (siehe Datenmodell-Absatz Finding 8/9).
- **States** (`AddEditProductDialog` + Produkt-Gruppen-Liste): wie oben,
  Viewer ohne Speichern-Button.
- **A11y-Keys:** `Key('productNewFab')`, `Key('productCard-<id>')`,
  `Key('productCategoryDropdown')`, `Key('productSaveButton')`.
- l10n-Keys (DE / EN):
  `productCatalogTitle` „Artikelstamm" / „Product catalog";
  `productUnit` „Einheit" / „Unit";
  `productDefaultCostPrice` „Standard-EK" / „Default cost price";
  `productNew` „Neuer Artikel" / „New product";
  `productGroupWithoutProduct` „Ohne Artikel" / „Without product";
  `productCatalogEmpty` „Kein Artikelstamm" / „Empty product catalog";
  `productCatalogEmptyHint` „Lege deinen ersten Artikel an." / „Create your first product.".

### Epic C — Bestellwesen
- **NEU: `lib/screens/purchase_orders_screen.dart`** — Liste der Bestellungen
  mit Status-Badges; FAB „Neue Bestellung". **Sub-Route des
  Warenwirtschaft-Hubs**, kein eigener `MainTab`.
- **NEU: `lib/screens/purchase_order_detail_screen.dart`** — Positionen,
  Wareneingang buchen (Mengen-Soll/Ist), Status, PDF-Beleg-Export.
- **States** (beide Screens): empty (`purchaseOrdersEmpty` +
  `purchaseOrdersEmptyHint`), loading (`skeletonizer`), error
  (`purchaseOrdersLoadError`), no-network, **no-permission** (Viewer →
  FAB + „Wareneingang buchen"-Button ausgeblendet via `has_workspace_role`).
- **A11y-Keys:** `Key('poNewFab')`, `Key('poCard-<id>')`,
  `Key('goodsReceiptBookButton')`, `Key('poItemReceivedStepper-<id>')`,
  `Key('poPdfExportButton')`.
- l10n-Keys:
  `purchaseOrdersTitle` „Bestellungen" / „Orders";
  `purchaseOrdersEmpty` „Keine Bestellungen" / „No orders";
  `purchaseOrdersEmptyHint` „Lege deine erste Bestellung an." / „Create your first order.";
  `purchaseOrdersLoadError` „Bestellungen konnten nicht geladen werden." / „Could not load orders.";
  `purchaseOrderNew` „Neue Bestellung" / „New order";
  `purchaseOrderStatusDraft` „Entwurf" / „Draft";
  `purchaseOrderStatusOrdered` „Bestellt" / „Ordered";
  `purchaseOrderStatusPartial` „Teilweise erhalten" / „Partially received";
  `purchaseOrderStatusReceived` „Erhalten" / „Received";
  `purchaseOrderStatusCancelled` „Storniert" / „Cancelled";
  `goodsReceiptBook` „Wareneingang buchen" / „Book goods receipt";
  `quantityOrdered` „Bestellt" / „Ordered";
  `quantityReceived` „Erhalten" / „Received".

### Epic D — Mehrlager + Alerts
- **NEU: `lib/screens/warehouses_screen.dart`** — Lager verwalten,
  **Sub-Route des Warenwirtschaft-Hubs**, kein eigener `MainTab`.
- **GEÄNDERT: Bestands-Dialog** — Lager-Auswahl-Dropdown.
- **GEÄNDERT: `dashboard_screen.dart`** — aktiver Mindestbestand-Alert-Block mit
  „Jetzt bestellen"-Aktion → öffnet `AddEditPurchaseOrder` vorbefüllt.
- **States** (`warehouses_screen`): empty (`warehousesEmpty` +
  `warehousesEmptyHint`), loading, error (`warehousesLoadError`),
  no-network, no-permission (Viewer → kein FAB).
- **A11y-Keys:** `Key('warehouseNewFab')`, `Key('warehouseRow-<id>')`,
  `Key('warehouseDropdown')`, `Key('lowStockReorderButton')`.
- l10n-Keys:
  `warehousesTitle` „Lager" / „Warehouses";
  `warehousesEmpty` „Keine Lager" / „No warehouses";
  `warehousesEmptyHint` „Lege dein erstes Lager an." / „Create your first warehouse.";
  `warehousesLoadError` „Lager konnten nicht geladen werden." / „Could not load warehouses.";
  `warehouseNew` „Neues Lager" / „New warehouse";
  `warehouseDefault` „Hauptlager" / „Main warehouse";
  `lowStockAlertTitle` „Niedriger Bestand" / „Low stock";
  `lowStockAlertBody` „{count} Artikel unter Mindestbestand" / „{count} items below minimum stock";
  `lowStockReorderAction` „Jetzt bestellen" / „Reorder now".

### Epic E — Inventur + Reporting
- **NEU: `lib/screens/stocktake_screen.dart`** + `stocktake_detail_screen.dart`
  — Inventur starten, zählen, abschließen, Differenz-Report.
  **Sub-Routen des Warenwirtschaft-Hubs**, kein eigener `MainTab`.
- **GEÄNDERT: `lib/widgets/statistics/tabs/inventory_suppliers_tab.dart`** —
  neue Auswertungen: Bestandsbewertung (Stichtag), Lagerumschlag, ABC-Analyse.
- **States** (`stocktake_screen` + `stocktake_detail_screen`): empty
  (`stocktakeEmpty` + `stocktakeEmptyHint`), loading, error
  (`stocktakeLoadError`), no-network, **no-permission** (Viewer → kein
  „Neue Inventur"-FAB, Zähl-Felder read-only).
- **A11y-Keys:** `Key('stocktakeNewFab')`, `Key('stocktakeRow-<id>')`,
  `Key('stocktakeCountField-<id>')`, `Key('stocktakeFilterUncounted')`,
  `Key('stocktakeCloseButton')`.

#### UX — Inventur auf dem Phone (Committee-Empfehlung 6)
- Durchscrollbare vertikale Liste, Zeilenhöhe ≥ 48 dp (Touch-Target).
- Filter-Toggle „nur ungezählte" (`Key('stocktakeFilterUncounted')`).
- Fortschritts-Header mit parametrisiertem l10n-Key
  `stocktakeProgress` „{counted}/{total} gezählt" / „{counted}/{total} counted".
- **Inkrementelles Speichern** pro Zähl-Eingabe — no-network-resilient
  (lokal puffern, bei Reconnect synchronisieren).
- Barcode-Scan-Einsprung über das **bestehende `BarcodeScannerSheet`** —
  Scan springt zur passenden `stocktake_items`-Zeile.
- Differenz-Report als **vertikale Cards** (kein horizontales Scrollen
  auf Phone).

#### UX — Wareneingang buchen (Committee-Empfehlung 6)
- Soll/Ist pro Position nebeneinander; Mengeneingabe als Touch-Stepper
  (`Key('poItemReceivedStepper-<id>')`).
- Barcode-Einsprung über `BarcodeScannerSheet` zur passenden Position.
- `SingleChildScrollView` + `SafeArea` + `MediaQuery.viewInsetsOf`.

#### UX — Reporting auf dem Phone (Committee-Empfehlung 6)
- Kennzahlen als **vertikale Kennzahl-Cards**, keine Tabellen auf Phone.
- Tabellen-Darstellung nur ≥ 800 px via `LayoutBuilder`.

- l10n-Keys:
  `stocktakeTitle` „Inventur" / „Stocktake";
  `stocktakeEmpty` „Keine Inventuren" / „No stocktakes";
  `stocktakeEmptyHint` „Starte deine erste Inventur." / „Start your first stocktake.";
  `stocktakeLoadError` „Inventuren konnten nicht geladen werden." / „Could not load stocktakes.";
  `stocktakeNew` „Neue Inventur" / „New stocktake";
  `stocktakeProgress` „{counted}/{total} gezählt" / „{counted}/{total} counted";
  `stocktakeFilterUncounted` „Nur ungezählte" / „Uncounted only";
  `stocktakeExpected` „Soll" / „Expected";
  `stocktakeCounted` „Gezählt" / „Counted";
  `stocktakeDifference` „Differenz" / „Difference";
  `reportStockValuation` „Bestandsbewertung" / „Stock valuation";
  `reportInventoryTurnover` „Lagerumschlag" / „Inventory turnover";
  `reportAbcAnalysis` „ABC-Analyse" / „ABC analysis".

### Querschnitt — Hub + Formular-Mobile-Checkliste
- **NEU: `lib/screens/warehouse_hub_screen.dart`** — Hub mit Kacheln/Listen-
  Einträgen, die auf die Sub-Routen pushen.
  - **States:** Hub selbst ist statisch (keine eigene Datenladung) — nur
    `warehouseHubEmpty` entfällt; no-permission blendet Schreib-Sub-Routen
    nicht aus (Sub-Routen regeln das selbst).
  - **A11y-Keys:** `Key('hubTilePurchaseOrders')`, `Key('hubTileWarehouses')`,
    `Key('hubTileCategories')`, `Key('hubTileStocktake')`,
    `Key('hubTileReporting')`.
  - l10n-Keys: `navWarehouse` „Warenwirtschaft" / „Warehousing";
    `warehouseHubTitle` „Warenwirtschaft" / „Warehousing".
- **Formular-Mobile-Checkliste** (verbindlich für ALLE neuen Dialoge —
  `AddEditProductDialog`, `AddEditCategoryDialog`, `AddEditPurchaseOrder`,
  `AddEditWarehouse`, Stocktake-Dialoge): jeder Dialog nutzt
  `SingleChildScrollView` + `SafeArea` + `MediaQuery.viewInsetsOf`, damit
  die Tastatur kein Feld verdeckt und nichts auf 360×640 abschneidet.

---

## Tests

> CLAUDE.md: Service-Layer Unit-Tests Pflicht, Provider mit gemockten Services,
> Widget-Tests für komplexe Custom-Widgets, `smoke-full-app-audit` vor jedem
> UI-`/ship`.

- **Unit (Model):** je neues Model `toSupabaseInsert`/`fromSupabase`/`copyWith`
  Round-Trip-Tests (`test/models/product_test.dart`,
  `purchase_order_test.dart`, `warehouse_test.dart`, `stocktake_test.dart`,
  `product_category_test.dart`, `product_supplier_test.dart`).
- **Unit (Service):** `InventoryProvider`-Erweiterungen gegen gemocktes
  `SupabaseRepository` — Buchungsart wird korrekt typisiert; Bestand wird über
  Produkt aggregiert (`product_stock`-View); Inventur-Abschluss erzeugt
  korrekte `stocktake`-Movements; PO-Wareneingang erhöht `quantity_received`
  **atomar** (Test simuliert parallele Buchung) + setzt Status.
- **Unit (KPI-Aggregation):** eigener Test, dass `criticalStockCount`,
  `InventoryItem.isCritical` und `totalStockQuantity` nach A-full **pro
  Produkt über alle Lager/Bestands-Rows** gegen `products.min_stock`
  aggregieren — Regressions-Schutz gegen falsche Dashboard-Zahlen.
- **Unit (CSV):** `csv_service_test.dart` — neue Sektionen
  (Produkte/Kategorien/Lager/Bestellungen) Round-Trip; FK-Resolve per
  SKU/Name; Legacy-CSV ohne neue Sektionen importiert weiterhin sauber
  (Rückwärtskompatibilität).
- **Migration:** `supabase db reset` muss pro Epic-Migration grün durchlaufen;
  Backfill-Assert für A-lite (jede Alt-`inventory_movement` hat danach ein
  `movement_type`); FK-Cross-Workspace-Trigger-Tests (Cross-Workspace-Insert
  wird abgewiesen). **Kein** `product_id`-Backfill-Assert — `product_id`
  bleibt nullable (Finding 2).
- **Widget:** `ProductDetailScreen`, `PurchaseOrderDetailScreen`,
  `StocktakeDetailScreen`, `WarehouseHubScreen` — Render + Phone-Overflow
  bei 360×640; no-permission-State (Viewer-Rolle).
- **Smoke:** nach A-lite, A-full, C, D, E je ein `smoke-full-app-audit`
  (Light+Dark × Desktop+Phone); neue Routen in
  `.claude/agents/_page-registry.md` eintragen. **Zwei neue Pflicht-Test-
  Schlüssel** werden in `_page-registry.md` definiert: `goods-receipt-flow`
  (Epic C) und `stocktake-count-flow` (Epic E).
- **l10n:** `/check-l10n` nach jedem Epic, DE/EN-Symmetrie; parametrisierte
  Keys (`lowStockAlertBody`, `stocktakeProgress`) mit Platzhalter-Symmetrie.

---

## Risiken

1. **Artikelstamm-Refactor (Epic A-full) ist invasiv.** `inventory_items` ist
   das zentrale Lager-Model und hängt an `checkInDeal`, CSV-Import,
   Statistiken, `TicketSummary`-Aggregation. → Mitigation: A-lite (P0)
   liefert den niedrig-riskanten Teil ohne `products`. A-full führt
   `product_id` **dauerhaft nullable, additiv** ein (kein NOT-NULL, kein
   Backfill); Alt-Spalten (`name`/`sku`) NICHT droppen. `status` bleibt auf
   der Bestands-Row, Archive-Trigger unverändert.
2. **`reason` → `movement_type`-Heuristik.** Freitext-`reason` ist
   inkonsistent; die Backfill-Heuristik mappt einige Alt-Rows auf
   `correction`. Akzeptabel, da Pre-Launch. Backfill läuft als Service-Role-
   Migration (RLS-Bypass), da `inventory_movements` insert-only ist.
3. **Doppelte Wahrheit Bestand.** Solange `inventory_items.quantity` und
   aggregierte Movements parallel existieren, können sie divergieren. →
   Mitigation: `quantity` bleibt die Wahrheit, Movements sind Journal; der
   `product_stock`-View ist die einzige Aggregations-Quelle für
   Low-Stock/Detail; Inventur gleicht ab. Keine Trigger-basierte
   Auto-Summe (zu fehleranfällig).
4. **Hub-Screen statt Tab-Explosion.** Es gibt heute schon 10 Top-Level-Tabs.
   → Mitigation (ENTSCHIEDEN): genau EIN neuer `MainTab` `warehouse` als
   Hub-Screen; Bestellungen/Lager/Kategorien/Inventur/Reporting sind
   gepushte Sub-Routen. `_navIcons`/`_navLabels`/`_navVisibility`/
   `_bottomNavTabs` werden genau einmal erweitert. Risiko verlagert sich
   auf das „Mehr"-Sheet — der Hub vermeidet genau dessen Überlauf.
5. **Cross-Workspace-FK-Leck.** Ein reiner FK erlaubt Referenzen auf Rows
   eines fremden Workspaces (RLS schützt nur Sichtbarkeit, nicht
   Integrität). → Mitigation: `BEFORE INSERT/UPDATE`-Trigger
   (`SECURITY DEFINER`, `SET search_path`) pro neuer Cross-Workspace-FK,
   Pflicht für `purchase_order_items`/`stocktake_items`/`product_suppliers`.
6. **`purchase_order_items` RLS-Pfad.** Kindtabelle muss eigene `workspace_id`
   tragen und konsistent gefüllt werden. → Mitigation: NOT NULL + App setzt
   sie aus dem Parent + FK-Cross-Workspace-Trigger.
7. **PO-Wareneingang Race.** Read-modify-write auf `quantity_received`
   verliert parallele Buchungen. → Mitigation: serverseitig atomares
   `SET quantity_received = quantity_received + :x` (oder RPC), nie
   Client-seitiges Lesen+Schreiben.
8. **Low-Stock-Push spammt / leakt PII.** Viele Produkte → viele Pushes;
   Produktnamen im FCM-Payload sind PII. → Mitigation: Sammel-Push pro
   Workspace (`GROUP BY workspace_id, product_id`), Dedup via
   `notifications_sent` (+`ref_kind='low_stock'`-Constraint-Erweiterung),
   PII-armer Body („X Artikel unter Mindestbestand"), kein `console.log`
   von Produktdaten.
9. **`seed-demo-workspace` / `demo_data_service` driften vom Schema ab.**
   Die Seed-Function inserted `inventory_items`/`inventory_movements` mit
   festem Spalten-Set. → Mitigation: Seed-Anpassung im selben Task-Cluster
   wie die jeweilige Migration (A-lite / A-full).
10. **CSV-Rückwärtskompatibilität.** Bestehende CSV-Exporte müssen weiter
    importierbar sein; FK-Spalten dürfen keine rohen UUIDs aus der CSV
    übernehmen. → Mitigation: Format-Detection wie heute (Spaltenzahl),
    FK-Resolve per SKU/Name, CHECK-Constraint-Felder client-seitig
    vorvalidieren, kein raw SQL mit String-Interpolation; Tests dafür.
11. **`_page-registry.md`-Merge-Konflikte.** Mehrere Tasks schreiben in
    dieselbe Registry-Datei. → Mitigation: registry-schreibende Tasks
    (A-lite-Registry, C-Registry, D-Registry, E-Registry) **seriell
    mergen**, nicht parallel.
12. **Scope-Explosion / Solo-Maintainer.** 6+ Epics sind viel. →
    Mitigation: strikte Phasen-Reihenfolge A-lite → B → A-full → C → D →
    E → F; A-lite (P0) liefert allein schon Mehrwert; P1/P2 können
    einzeln verschoben werden.

---

## Performance / Datenladen (Committee-Empfehlung 1 + 2)

- **`loadAll()`-Scope:** `products`, `product_categories`, `warehouses`
  kommen in den **globalen `CloudSnapshot`** (klein, workspace-weit
  relevant). `purchase_order_items`, `stocktake_items`, `product_suppliers`
  werden **lazy pro Detail-Screen** geladen — Pattern wie das bestehende
  `loadBatchesForItem` (verifiziert in `inventory_provider.dart`
  Zeilen 860–866).
- **Index** `(workspace_id, product_id)` auf `inventory_movements` (in der
  A-full-Migration) — für die Produkt-Detail-Movement-History.
- **Pagination:** Produkt-Detail-Movement-History lädt seitenweise
  (z. B. 50 Rows, „mehr laden") statt aller Movements auf einmal.

---

## Tasks

> Jeder Task ist atomar (1 PR-fähiges Increment). `agent:`-Tag = vorgesehener
> Subagent. `model:`-Tag = Modell-Routing gemäß CLAUDE.md §Subagent-Modell-
> Routing (RLS-kritische Migrationen → Opus, Routine-Coding → Sonnet).
> `depends:` = Vorbedingung. Epic-Reihenfolge = Prioritäts-Reihenfolge:
> A-lite → B → A-full → C → D → E → F.

### Epic A-lite — getypte Buchungsarten (P0)

- [x] **AL1** — Migration: `inventory_movements.movement_type`
  (NOT NULL DEFAULT `'correction'` + CHECK-Enum) + `unit_cost` (nullable)
  hinzufügen; Service-Role-Backfill `movement_type` per Heuristik aus
  `reason`; Down-Migration (`DROP COLUMN`, Datenverlust-Hinweis im
  Kommentar). `inventory_movements` behält 2-Policy-RLS (append-only).
  `supabase db reset` grün. `agent:db-migrator` · `model:Opus`
- [x] **AL2** — `seed-demo-workspace` + `demo_data_service.dart`: bei jedem
  `inventory_movements`-Insert `movement_type` setzen.
  `agent:edge-fn-coder` · `model:Sonnet` · `depends:AL1`
  *(Verifiziert: weder Seed-Function noch demo_data_service inserten
  `inventory_movements` — kein Code-Change nötig.)*
- [x] **AL3** — `InventoryMovement`-Model um `movementType`/`unitCost`
  erweitern; `InventoryMovementType`-Enum + Round-Trip-Tests.
  `agent:flutter-coder` · `model:Sonnet` · `depends:AL1`
- [x] **AL4** — `InventoryProvider`: alle 4 Schreibmethoden
  (`addInventoryItem`/`updateInventoryItem`/`adjustStock`/`checkInDeal`)
  auf getypte `movement_type` umstellen; `checkInDeal` schreibt `goods_in`,
  `adjustStock` schreibt `correction`. `agent:flutter-coder` ·
  `model:Sonnet` · `depends:AL3`
- [x] **AL5** — `product_detail_screen.dart` NEU auf der bestehenden
  `inventory_items`-Row (Stammdaten, Bestand, getypte Bewegungshistorie,
  Chargen, Lieferant); States (empty/loading/error/no-network/
  no-permission) + A11y-Keys. `agent:ui-builder` · `model:Sonnet` ·
  `depends:AL4`
- [x] **AL6** — `inventory_screen.dart`: Movement-Badge/Farbe aus
  `movement_type`. `agent:ui-builder` · `model:Sonnet` · `depends:AL4`
  *(No-Op für inventory_screen — Movements werden dort nicht angezeigt;
  Badge-Logik liegt in product_detail_screen. Toter Edit-Button gefixt.)*
- [x] **AL7** — l10n-Keys Epic A-lite in `app_de.arb` + `app_en.arb`;
  `/check-l10n` grün. `agent:ui-builder` · `model:Sonnet` · `depends:AL5`
- [x] **AL8** — Unit-Tests Model + Provider (A-lite) + `smoke-full-app-audit`;
  `_page-registry.md`: Sub-Route `product_detail` namentlich mit
  Pflicht-Tests `smoke-theme, mobile-overflow` ergänzen.
  `agent:flutter-coder` · `model:Sonnet` · `depends:AL5,AL6,AL7`
  · *(Registry-schreibend — seriell mergen)*

### Epic B — Kategorien + Lieferanten (P1)

- [x] **B1** — Migration `product_categories` (Schema + 4-Policy-RLS +
  Indexe + FK-Cross-Workspace-Trigger für `parent_id`); `suppliers` um
  Adress-/Kreditoren-Spalten erweitern; Down-Migrationen.
  `agent:db-migrator` · `model:Opus` · `depends:AL1`
- [x] **B2** — Models `ProductCategory` NEU; `Supplier`-Model um neue
  Felder erweitern + Round-Trip-Tests. `agent:flutter-coder` ·
  `model:Sonnet` · `depends:B1`
- [x] **B3** — `SupabaseRepository` + `InventoryProvider`: CRUD Kategorien;
  `product_categories` + `warehouses` in `loadAll()`-Snapshot vorbereiten
  (Snapshot-Feld). `agent:flutter-coder` · `model:Sonnet` · `depends:B2`
- [x] **B4** — `categories_screen.dart` NEU (Sub-Route Warenwirtschaft-Hub,
  States + A11y-Keys); `add_edit_supplier_dialog.dart` um „Erweitert"-
  Abschnitt erweitern (Formular-Mobile-Checkliste).
  `agent:ui-builder` · `model:Sonnet` · `depends:B3,AF6`
  *(depends auf AF6 wegen Hub-Screen — Sub-Route braucht den Hub)*
- [x] **B5** — l10n-Keys Epic B + Unit-Tests + `/check-l10n`.
  `agent:ui-builder` · `model:Sonnet` · `depends:B4`

### Epic A-full — Produkt-Stammkatalog (P1)

- [x] **AF1** — Migration `products` (Schema + 4-Policy-RLS + Indexe +
  partial-UNIQUE auf `sku`); FK-Cross-Workspace-Trigger für `category_id`
  + `default_supplier_id`; Down-Migration. `agent:db-migrator` ·
  `model:Opus` · `depends:B1`
- [x] **AF2** — Migration: `inventory_items.product_id` (**dauerhaft
  nullable**, `ON DELETE SET NULL`) + `warehouse_id` (nullable);
  `inventory_movements.product_id` (nullable) + Index
  `(workspace_id, product_id)`; FK-Cross-Workspace-Trigger für
  `inventory_items.product_id`. **Kein NOT-NULL, kein Backfill.**
  Down-Migration. `agent:db-migrator` · `model:Opus` · `depends:AF1`
- [x] **AF3** — Migration: `product_stock`-View (`security_invoker = true`,
  `GROUP BY workspace_id, product_id, warehouse_id`); Migration
  `product_suppliers`-Tabelle (Schema + 4-Policy-RLS + partial-UNIQUE
  `is_preferred` + FK-Cross-Workspace-Trigger `product_id`/`supplier_id`);
  Down-Migration. `agent:db-migrator` · `model:Opus` · `depends:AF2`
- [x] **AF4** — `seed-demo-workspace` + `demo_data_service.dart`: optional
  `products` mitanlegen + Demo-`inventory_items` über `product_id`
  verlinken. `agent:edge-fn-coder` · `model:Sonnet` · `depends:AF2`
- [x] **AF5** — Models `Product`, `ProductSupplier` NEU (`toSupabaseInsert`/
  `fromSupabase`/`copyWith` + Round-Trip-Tests); `InventoryMovement` um
  `productId` erweitern. `agent:flutter-coder` · `model:Sonnet` ·
  `depends:AF1,AF3`
- [x] **AF6** — `SupabaseRepository`: `loadProducts`/`insertProduct`/
  `updateProduct`/`deleteProduct` + `product_suppliers`-CRUD (lazy pro
  Detail-Screen) + `product_stock`-Read; `loadAll()`/`CloudSnapshot` um
  `products` erweitern. `agent:flutter-coder` · `model:Sonnet` ·
  `depends:AF5`
- [x] **AF7a** — `InventoryProvider`: Produkt-State + Produkt-CRUD-Methoden.
  `agent:flutter-coder` · `model:Sonnet` · `depends:AF6`
- [x] **AF7b** — `InventoryProvider`: `movement_type`-Schreiben aller 4
  Schreibmethoden um `product_id`-Verknüpfung erweitern (sofern Bestands-
  Row ein Produkt hat). `agent:flutter-coder` · `model:Sonnet` ·
  `depends:AF7a,AF2`
- [x] **AF7c** — `checkInDeal`-Produkt-Matching: matched ein Produkt per
  `name`+`sku`; existiert keins, legt es ein neues `products`-Row an und
  verlinkt. `status` bleibt auf der `inventory_items`-Row;
  `tg_check_ticket_archive_from_inventory` + `TicketSummary`-Aggregation
  über `ticket_number`/`inventoryItemIds` bleiben unverändert intakt;
  `inventory_batches` bleiben an der Bestands-Row, Produkt-Detail
  aggregiert über alle Bestands-Rows des Produkts.
  `agent:flutter-coder` · `model:Sonnet` · `depends:AF7b`
- [x] **AF8** — KPI-Aggregation: `criticalStockCount`,
  `InventoryItem.isCritical`, `totalStockQuantity` aggregieren pro Produkt
  über alle Lager/Bestands-Rows gegen `products.min_stock` (über
  `product_stock`-View); Unit-Tests. `agent:flutter-coder` ·
  `model:Sonnet` · `depends:AF7a,AF2`
- [x] **AF9** — `AddEditProductDialog` NEU (Formular-Mobile-Checkliste,
  States, A11y-Keys); Bestands-/Wareneingangs-Dialog optional auf
  `product_id`-Referenz erweitern. `agent:ui-builder` · `model:Sonnet` ·
  `depends:AF7a`
- [x] **AF10** — `inventory_screen.dart`: Stock-Tab zeigt Produkte
  gruppiert (+ „Ohne Artikel"-Gruppe für nicht-verknüpfte Rows).
  `agent:ui-builder` · `model:Sonnet` · `depends:AF9`
- [x] **AF11** — `warehouse_hub_screen.dart` NEU; genau EIN neuer `MainTab`
  `warehouse` in `main_screen.dart` (`_navIcons`/`_navLabels`/
  `_navVisibility`/`_bottomNavTabs` einmalig erweitern). Hub verlinkt auf
  die Sub-Routen. `agent:ui-builder` · `model:Sonnet` · `depends:AF10`
- [x] **AF12** — `product_detail_screen.dart` auf Produkt-Aggregation
  erweitern (Bestand über alle Bestands-Rows, Movement-History paginiert).
  `agent:ui-builder` · `model:Sonnet` · `depends:AF11`
- [x] **AF13** — l10n-Keys Epic A-full; `/check-l10n` grün.
  `agent:ui-builder` · `model:Sonnet` · `depends:AF9`
- [x] **AF14** — Unit-Tests Model + Provider (A-full) + KPI-Aggregations-
  Test + `smoke-full-app-audit`; `_page-registry.md`: Top-Level
  `warehouse_hub` (Pflicht-Tests `smoke-theme, mobile-overflow`) +
  Sub-Route `categories`, `AddEditProductDialog` namentlich ergänzen.
  `agent:flutter-coder` · `model:Sonnet` · `depends:AF12,AF13`
  · *(Registry-schreibend — seriell mergen)*

### Epic C — Bestellwesen (P1)

- [x] **C1** — Migration `purchase_orders` + `purchase_order_items`
  (Schema + 4-Policy-RLS + Status-Trigger + FK-Cross-Workspace-Trigger
  für `purchase_orders.supplier_id` und `purchase_order_items.product_id`/
  `purchase_order_id`); Down-Migration. `agent:db-migrator` ·
  `model:Opus` · `depends:AF1`
- [x] **C2** — Models `PurchaseOrder`, `PurchaseOrderItem` NEU +
  Round-Trip-Tests. `agent:flutter-coder` · `model:Sonnet` · `depends:C1`
- [x] **C3** — `SupabaseRepository` + Provider: PO-CRUD (client-seitige
  `order_number`-Vergabe mit Retry bei UNIQUE-Kollision);
  `purchase_order_items` lazy pro Detail-Screen.
  `agent:flutter-coder` · `model:Sonnet` · `depends:C2`
- [x] **C4** — Provider: Wareneingang buchen — **atomares** Increment von
  `quantity_received` (`SET ... = ... + :x`), schreibt `goods_in`-Movement,
  erhöht Bestand; Unit-Test mit simulierter Parallel-Buchung.
  `agent:flutter-coder` · `model:Sonnet` · `depends:C3`
- [x] **C5** — `purchase_orders_screen.dart` + `purchase_order_detail_screen.dart`
  NEU als **Sub-Routen des Warenwirtschaft-Hubs** (KEIN neuer `MainTab`);
  Wareneingang-Buchen-UX (Touch-Stepper, Barcode-Einsprung), States +
  A11y-Keys. `agent:ui-builder` · `model:Sonnet` · `depends:C4,AF11`
- [x] **C6** — PDF-Beleg: Bestell-/Lieferschein-PDF via `pdf`/`printing`
  (Pattern aus `statistics_export_service.dart`).
  `agent:flutter-coder` · `model:Sonnet` · `depends:C5`
- [x] **C7** — l10n-Keys Epic C + Unit-Tests + `smoke-full-app-audit`;
  `_page-registry.md`: Sub-Routen `purchase_orders`, `purchase_order_detail`
  + Bestell-Dialog namentlich ergänzen; neuen Pflicht-Test-Schlüssel
  `goods-receipt-flow` definieren + dem PO-Detail zuweisen.
  `agent:ui-builder` · `model:Sonnet` · `depends:C6`
  · *(Registry-schreibend — seriell mergen)*

### Epic D — Mehrlager + Alerts (P1)

- [x] **D1** — Migration `warehouses` (Schema + 4-Policy-RLS +
  partial-UNIQUE `is_default`); `inventory_items.warehouse_id`-Nutzung
  aktivieren (Index); FK-Cross-Workspace-Trigger für
  `inventory_items.warehouse_id`; Down-Migration. `agent:db-migrator` ·
  `model:Opus` · `depends:AF2`
- [x] **D2** — Migration: `notifications_sent.ref_kind`-CHECK um
  `'low_stock'` erweitern (DROP+ADD CONSTRAINT) + optional `workspace_id`-
  Spalte; als „irreversibel ab Merge" dokumentiert. `agent:db-migrator` ·
  `model:Opus` · `depends:D1`
- [x] **D3** — `Warehouse`-Model NEU; Repository + Provider CRUD +
  Default-Lager-Bootstrap App-seitig; `warehouses` im `loadAll()`-Snapshot.
  `agent:flutter-coder` · `model:Sonnet` · `depends:D1`
- [x] **D4** — `warehouses_screen.dart` NEU als **Sub-Route des
  Warenwirtschaft-Hubs** (KEIN neuer `MainTab`); Lager-Dropdown im
  Bestands-Dialog; States + A11y-Keys. `agent:ui-builder` ·
  `model:Sonnet` · `depends:D3,AF11`
- [x] **D5** — `send-notifications` Edge-Function um `low_stock`-Alert
  erweitern: aggregiert `GROUP BY workspace_id, product_id` gegen
  `product_stock` vs. `products.min_stock`; ein Sammel-Push pro Workspace
  an aktive `workspace_members` mit Preference; PII-armer Body
  („X Artikel unter Mindestbestand"); Dedup via `notifications_sent`
  (`ref_kind='low_stock'`); kein `console.log` von Produktdaten.
  `agent:edge-fn-coder` · `model:Sonnet` · `depends:D2`
- [x] **D6** — `dashboard_screen.dart`: aktiver Low-Stock-Alert-Block mit
  „Jetzt bestellen"-Aktion → öffnet PO-Dialog vorbefüllt.
  `agent:ui-builder` · `model:Sonnet` · `depends:C5,D3`
- [x] **D7** — l10n-Keys Epic D + Tests + `smoke-full-app-audit`;
  `_page-registry.md`: Sub-Route `warehouses` + Lager-Dialog namentlich
  ergänzen. `agent:ui-builder` · `model:Sonnet` · `depends:D4,D6`
  · *(Registry-schreibend — seriell mergen)*

### Epic E — Inventur + Reporting (P2)

- [x] **E1** — Migration `stocktakes` + `stocktake_items` (Schema +
  4-Policy-RLS + FK-Cross-Workspace-Trigger für `stocktakes.warehouse_id`
  und `stocktake_items.product_id`/`stocktake_id`); Down-Migration.
  `agent:db-migrator` · `model:Opus` · `depends:AF1`
- [x] **E2** — Models `Stocktake`, `StocktakeItem` NEU; Repository +
  Provider: Inventur starten (Soll-Snapshot aus `product_stock`), zählen
  (inkrementelles, no-network-resilientes Speichern), abschließen
  (Differenz-Movements `movement_type='stocktake'`, append-only).
  `agent:flutter-coder` · `model:Sonnet` · `depends:E1,AF7c`
- [x] **E3** — `stocktake_screen.dart` + `stocktake_detail_screen.dart` NEU
  als **Sub-Routen des Warenwirtschaft-Hubs** (KEIN neuer `MainTab`);
  Phone-Inventur-UX (durchscrollbare 48dp-Liste, Filter „nur ungezählte",
  Fortschritts-Header, Barcode-Einsprung via `BarcodeScannerSheet`,
  Differenz-Report als vertikale Cards), States + A11y-Keys.
  `agent:ui-builder` · `model:Sonnet` · `depends:E2,AF11`
- [x] **E4** — `inventory_suppliers_tab.dart` um Bestandsbewertung,
  Lagerumschlag, ABC-Analyse erweitern (`statistics_service.dart`
  ergänzen); Phone = vertikale Kennzahl-Cards, Tabelle nur ≥ 800 px
  via `LayoutBuilder`. `agent:flutter-coder` · `model:Sonnet` ·
  `depends:AF8`
- [x] **E5** — l10n-Keys Epic E + Tests + `smoke-full-app-audit`;
  `_page-registry.md`: Sub-Routen `stocktake`, `stocktake_detail` +
  Stocktake-Dialoge namentlich ergänzen; neuen Pflicht-Test-Schlüssel
  `stocktake-count-flow` definieren + dem `stocktake_detail` zuweisen.
  `agent:ui-builder` · `model:Sonnet` · `depends:E3,E4`
  · *(Registry-schreibend — seriell mergen)*

### Epic F — CSV + Doku (P1, querschnittlich)

- [x] **F1** — `csv_service.dart`: neue Sektionen Produkte/Kategorien/Lager/
  Bestellungen in Export + Import; FK-Referenzen per **SKU/Name** resolven
  (keine rohen UUIDs aus der CSV); CHECK-Constraint-Felder (EAN-Regex,
  Enum-Whitelist, Mengen-Vorzeichen, Längen) client-seitig vorvalidieren;
  kein raw SQL mit String-Interpolation; Legacy-CSV bleibt importierbar;
  Tests. `agent:flutter-coder` · `model:Sonnet` · `depends:AF7c,C4,D3`
- [x] **F2** — Handbuch nachziehen: `06-database.md` (neue Tabellen +
  `product_stock`-View), `03-screens-walkthrough.md` (neue Screens),
  `05-architecture.md`, `07-edge-functions.md` (`send-notifications` +
  `seed-demo-workspace`-Änderung), `10-glossary.md`.
  `agent:flutter-coder` · `model:Sonnet` · `depends:E5`
- [x] **F3** — Hilfeseite (`help_screen.dart` + ARBs) um Sektionen
  Artikelstamm, Bestellwesen, Lager, Inventur erweitern.
  `agent:ui-builder` · `model:Sonnet` · `depends:E5`

> **Task-Zahl:** 13 → 43 Tasks (Epic-A-Split, A7-3-fach-Split,
> KPI-/Seed-/FK-/PDF-Teiltasks). Registry-schreibende Tasks (AL8, AF14,
> C7, D7, E5) müssen **seriell** mergen — Merge-Konflikt-Gefahr auf
> `.claude/agents/_page-registry.md`.

---

## Offene Fragen — Stand nach Committee

1. **Nav-Struktur** — ✅ **ENTSCHIEDEN:** EIN neuer `MainTab` `warehouse`
   als Hub-Screen; alle Bereiche als gepushte Sub-Routen (siehe UI-Kapitel
   „Navigation", Finding 10).
2. **`order_number`-Vergabe** — ✅ **ENTSCHIEDEN:** client-seitige Vergabe
   mit erlaubten Lücken + UNIQUE-Constraint-Retry; `SECURITY DEFINER`-RPC
   nur als dokumentierter Fallback (siehe API-Kapitel, Finding 12).
3. **Bewertungsverfahren (L9)** — offen für P2: gleitender Durchschnitt vs.
   FIFO vs. nur `unit_cost`-Snapshot. Aktueller Plan: nur `unit_cost` pro
   Movement, echte Bewertung als spätere P2-Erweiterung.
4. **Epic-A-Split** — ✅ **ENTSCHIEDEN:** A-lite/A-full-Split. A-lite ist
   echtes P0 (getypte `movement_type` + Detail-Screen auf bestehender
   Row); A-full (`products`-Tabelle) ist P1 unmittelbar vor Epic C
   (siehe Finding 1).

---

## Committee-Review-Historie

### 2026-05-20 — `/council`-Review (5 Reviewer)

| Reviewer | Verdict |
|---|---|
| Architekt | ⚠️ — Epic A zu grob geschnitten, Nav-Frage offen gelassen, KPI-Aggregation unspezifiziert |
| Bug-Hunter / Pessimist | 🔴 KRITISCH — 9 Findings: append-only-`inventory_movements` verletzt durch generische 4-Policy-Skizze, Archive-Trigger-Bruch durch `status`-Verschiebung, `product_id`-NOT-NULL-Zwangsbackfill riskant, Cross-Workspace-FK-Leck, PO-Wareneingang-Race, fehlende `seed-demo-workspace`-Anpassung, `ref_kind`-Constraint blockiert `low_stock`, A7-Mega-Task, fehlende `depends`-Kanten |
| External-Solutions-Scout | EIGENBAU — kein passendes Fremd-Package; `data_table_2` geprüft und verworfen; PDF-Belege über bereits gebundenes `pdf`/`printing`-Package |
| Security | ⚠️ warn — Cross-Workspace-FK-Integrität fehlte, Low-Stock-Push-PII im FCM-Payload, `SECURITY DEFINER`-RPC ohne Member-Check, fehlende `search_path`-Härtung |
| UX / Mobile | ⚠️ — Nav-Tab-Explosion, fehlende States/no-permission-Behandlung pro Screen, Inventur/Wareneingang/Reporting nicht mobile-spezifiziert, fehlende A11y-Keys |

**Ergebnis:** Alle **13 Pflicht-Findings** sowie alle **6 empfohlenen
Verbesserungen** (inkl. External-Scout-Zusatz zu PDF-Belegen /
`data_table_2`) wurden in diesen Plan eingearbeitet. Verifiziert wurden
dabei direkt in der Codebase: `inventory_movements`-RLS (nur read+insert,
`20260504000500_data_workspace_scope.sql`), Archive-Trigger
(`20260509000300_archive_triggers.sql`), `notifications_sent.ref_kind`-
CHECK (`20260503001000_push_notifications.sql`), `seed-demo-workspace`-
Insert-Pfade und `InventoryProvider`-Methodensignaturen. Der Plan wird
von `[DRAFT]` auf `[Committee-Approved 2026-05-20]` gehoben und ist für
die Implementation freigegeben.
