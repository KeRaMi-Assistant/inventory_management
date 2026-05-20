# Warenverwaltung Feature-Parity (Lexware-Stil)

> **[DRAFT — Pending Committee Review]**
> Erstellt: 2026-05-20 · Branch-Vorschlag: `feature/warenverwaltung-feature-parity`
> Status: Erstentwurf, noch nicht durch `/council` gelaufen.

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
| L1 | **Kein Produktkatalog getrennt vom Lagerbestand** — jeder `inventory_item` ist eine konkrete physische Charge, kein wiederverwendbarer Artikel-Stammsatz. Gleiches Produkt = mehrere Rows mit dupliziertem Namen/SKU | Pro Wareneingang neue Row | Stammartikel 1×, Bestand n× referenziert darauf | P0 |
| L2 | **Keine Artikel-Kategorien / Warengruppen** | — | Hierarchische Warengruppen, Filter danach | P1 |
| L3 | **Bestandsbuchungs-`reason` ist Freitext** — keine typisierte, auswertbare Buchungsart (Wareneingang/Warenausgang/Korrektur/Inventur/Umlagerung) | Freitext `reason` | Enum-Buchungsarten, je auswertbar | P0 |
| L4 | **Kein Mehrlager / strukturierte Lagerorte** — `location` ist ein freier String pro Artikel | Freitext | Lager + Lagerplatz-Hierarchie, Bestand pro Lager | P1 |
| L5 | **Kein Bestellwesen** — keine Nachbestellungen / Purchase Orders an Lieferanten | — | Bestellung anlegen, Status verfolgen, an Wareneingang koppeln | P1 |
| L6 | **Kein dedizierter Wareneingang/Lieferschein** — nur `checkInDeal` (Deal-zentriert), kein PO-basierter Wareneingang mit Teil-/Mengenabgleich | Deal → Item | Wareneingangsbeleg gegen Bestellung, Soll/Ist | P1 |
| L7 | **Keine echte Inventur** — kein geführter Zähl-/Korrektur-Workflow mit Differenz-Report | manuelles `adjustStock` | Inventur-Session, Soll/Ist, Sammel-Korrekturbuchung | P2 |
| L8 | **Mindestbestand-Alerts nur passiv** — `criticalStockCount` ist ein KPI, kein Push, keine Nachbestell-Aktion | KPI | Aktiver Alert + Nachbestellvorschlag | P1 |
| L9 | **Keine Einstandspreis-Bewertung** — nur `cost_price` als Momentwert; keine gewichtete Durchschnittsbewertung über Wareneingänge | Snapshot | Gleitender Durchschnitt / FIFO-Bewertung | P2 |
| L10 | **Lieferanten-Stammdaten dünn** — keine Adresse, USt-IdNr, Zahlungsbedingungen, Lieferzeit, Mindestbestellwert, Artikel-Lieferanten-Zuordnung mit Lieferant-SKU/-Preis | 7 Felder | Vollständige Kreditoren-Stammdaten | P1 |
| L11 | **Kein Artikel-Detail-Screen** — Artikel werden nur in Listen-Cards + Edit-Dialog gezeigt; keine 360°-Sicht (Bewegungshistorie, Chargen, Lieferant, Bestellungen) | Card + Dialog | Detail mit Tabs/Historie | P0 |
| L12 | **Reporting flach** — keine Lagerumschlag-/Reichweiten-/Ladenhüter-/ABC-Analyse, kein dedizierter Inventurwert-Report mit Stichtag | 5 Stat-Tabs | Bestandsbewertung, Umschlag, ABC | P2 |
| L13 | **CSV-Import/Export deckt neues Schema nicht ab** — `CsvService` kennt nur die heutigen Spalten | 5 Sektionen | muss mit Katalog/Kategorien/Lager/PO mitwachsen | P1 |

---

## Scope

### In Scope (dieser Plan, alle Epics)

- **Epic A (P0):** Artikelstamm-Refactor — `products` als Stammkatalog,
  `inventory_items` wird Bestands-Row die auf `products` referenziert; getypte
  Buchungsarten auf `inventory_movements`; Artikel-Detail-Screen.
- **Epic B (P1):** Kategorien/Warengruppen + erweiterte Lieferanten-Stammdaten
  + Artikel-Lieferanten-Zuordnung.
- **Epic C (P1):** Bestellwesen (Purchase Orders) + Wareneingang gegen
  Bestellung.
- **Epic D (P1):** Mehrlager/Lagerorte (strukturiert) + aktive
  Mindestbestand-Alerts/Nachbestellvorschläge.
- **Epic E (P2):** Inventur-Workflow + erweitertes Reporting (Bestandsbewertung,
  Umschlag, ABC) + Bewertungsverfahren.
- **Epic F (P1, querschnittlich):** CSV-Import/Export an das neue Schema
  anpassen; Handbuch + Hilfeseite nachziehen.

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
  Nutzer; Backfill bleibt simpel.
- **Rückstandsverwaltung / Reservierungs-Engine** über mehrere Aufträge.

---

## Datenmodell + RLS

> Alle neuen Tabellen sind **NEU**. RLS-Pattern strikt nach
> `20260504000500_data_workspace_scope.sql`: `workspace_id NOT NULL` + FK,
> `user_id` als Erfasser-Spalte, Policies über `is_workspace_member` (read) und
> `has_workspace_role(...,['owner','admin','member'])` (write). Audit-Spalten
> `created_at`/`updated_at`/`deleted_at` + Touch-Trigger wie bei `suppliers`.
> Migration-Namensschema `YYYYMMDDHHMMSS_<slug>.sql`.

### Epic A — Artikelstamm

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
- RLS: `products_ws_read/insert/update/delete` (Standard-Pattern).
- Index: `(workspace_id)`, partial `UNIQUE (workspace_id, lower(sku)) WHERE sku IS NOT NULL AND deleted_at IS NULL`, `(workspace_id, category_id)`.

**GEÄNDERT: `inventory_items`** wird zur Bestands-Row
- NEUE Spalte: `product_id UUID → products(id) ON DELETE RESTRICT` (nullable in
  der ersten Migration für Backfill, danach NOT NULL).
- Backfill: für jeden bestehenden `inventory_item` einen `products`-Eintrag
  anlegen (name/sku/ean/min_stock kopieren) und `product_id` setzen. Pre-Launch
  → simpler 1:1-Backfill, kein Dedup nötig.
- `inventory_items.name`/`sku`/`ean`/`min_stock` bleiben physisch erhalten
  (kein DROP — Risiko-Minimierung), werden aber von der App nicht mehr als
  primäre Quelle gelesen; als deprecated markiert (SQL-Kommentar).
- NEUE Spalte: `warehouse_id UUID → warehouses(id)` (nullable, Epic D füllt).

**GEÄNDERT: `inventory_movements`** — getypte Buchungsart
- NEUE Spalte: `movement_type TEXT NOT NULL DEFAULT 'correction'
  CHECK (movement_type IN ('goods_in','goods_out','correction','stocktake','transfer','sale'))`.
- NEUE Spalte: `product_id UUID → products(id) ON DELETE SET NULL` (parallel zum
  bestehenden `item_id`, für katalogweite Auswertung).
- NEUE Spalte: `unit_cost NUMERIC(12,2)` — Einstandspreis der Buchung (für L9).
- `reason` (Freitext) bleibt als optionale Detail-Notiz.
- Backfill: bestehende Rows bekommen `movement_type` per Heuristik aus `reason`
  (`'Einbuchung*'`→`goods_in`, `'Ausbuchung*'`→`goods_out`, sonst `correction`).

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
- RLS Standard-Pattern. Index `(workspace_id)`, `(workspace_id, parent_id)`.
- Tiefe in der App auf 2 Ebenen begrenzen (App-seitige Validierung, kein
  DB-Constraint).

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
- RLS Standard-Pattern.

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
- RLS für beide: Standard-Pattern. `purchase_order_items` filtert über eigene
  `workspace_id`-Spalte (nicht über Parent), konsistent mit `inventory_movements`.
- Trigger: bei `purchase_order_items`-Update von `quantity_received` →
  `purchase_orders.status` automatisch auf `partially_received`/`received`
  setzen (analog `archive_triggers.sql`).

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
- RLS Standard-Pattern. Beim ersten Workspace-Touch via App ein Default-Lager
  „Hauptlager" anlegen (App-seitig, nicht per DB-Trigger — vermeidet komplexe
  Migration).
- `inventory_items.warehouse_id` (aus Epic A) wird hier aktiv genutzt;
  `inventory_items.location` (Freitext) bleibt als „Lagerplatz" innerhalb des
  Lagers erhalten.
- Mindestbestand-Alerts brauchen **keine** neue Tabelle — sie nutzen
  `products.min_stock` vs. aggregierten Bestand. Push-Versand reuse der
  bestehenden `send-notifications`-Function + `notification_preferences`.

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
- RLS Standard-Pattern. Beim Schließen einer Inventur erzeugt die App pro
  Differenz eine `inventory_movements`-Row mit `movement_type='stocktake'`.

### RLS-Policy-Skizze (gilt für alle NEU-Tabellen)

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

---

## API / Edge Functions

- **Keine zwingend neue Edge Function für Epic A–C/E.** CRUD läuft über den
  Supabase-Client via `SupabaseRepository` (RLS schützt). Das ist konsistent
  mit dem bestehenden Inventory-/Supplier-Pfad.
- **GEÄNDERT: `send-notifications`** (Epic D) — neuer Notification-Typ
  `low_stock_alert`. Die Function prüft pro Workspace, ob aggregierter
  Produkt-Bestand `< products.min_stock`, und versendet (entprellt via
  bestehender `notifications_sent`-Dedup-Tabelle) einen Push. Kein neuer
  Cron-Job nötig, an bestehenden `send-notifications`-Schedule andocken.
- **NEU optional (Epic C, P1, kann auch DB-Funktion sein):** RPC
  `next_purchase_order_number(workspace_id)` als `SECURITY DEFINER`-Function für
  lückenlose `order_number`-Vergabe (Race-frei via `SELECT ... FOR UPDATE` auf
  einem Counter). Alternative: client-seitige Vergabe akzeptiert kleine Lücken
  → für Pre-Launch ausreichend; Entscheidung dem Council überlassen.
- Kein neues Secret, kein `supabase secrets set` nötig.

---

## UI + l10n-Keys

> Mobile-First Pflicht (CLAUDE.md): Phone-Viewport 360/390 zuerst, Touch-Targets
> ≥ 48 dp, Bottom-Nav vs. Sidebar via `MediaQuery.sizeOf`. Alle Strings in
> `lib/l10n/app_de.arb` UND `app_en.arb`. Vor `/ship`:
> `smoke-full-app-audit` + `/check-l10n`.

### Epic A — Artikelstamm + Detail
- **GEÄNDERT: `inventory_screen.dart`** — Stock-Tab zeigt Produkte (gruppiert),
  nicht mehr rohe Items. Tap → Detail.
- **NEU: `lib/screens/product_detail_screen.dart`** — 360°-Sicht mit Sektionen:
  Stammdaten, aktueller Bestand, Bewegungshistorie, Chargen, Lieferant(en),
  offene Bestellungen.
- **GEÄNDERT: `lib/widgets/add_edit_*`** — neuer `AddEditProductDialog` für den
  Stammsatz; `AddEditInventoryItemDialog` (falls vorhanden) wird zum
  Bestands-/Wareneingangs-Dialog der auf `product_id` referenziert.
- l10n-Keys (DE / EN):
  `productCatalogTitle` „Artikelstamm" / „Product catalog";
  `productDetailTitle` „Artikeldetails" / „Product details";
  `productUnit` „Einheit" / „Unit";
  `productDefaultCostPrice` „Standard-EK" / „Default cost price";
  `productNew` „Neuer Artikel" / „New product";
  `movementTypeGoodsIn` „Wareneingang" / „Goods in";
  `movementTypeGoodsOut` „Warenausgang" / „Goods out";
  `movementTypeCorrection` „Korrektur" / „Correction";
  `movementTypeStocktake` „Inventur" / „Stocktake";
  `movementTypeTransfer` „Umlagerung" / „Transfer";
  `movementTypeSale` „Verkauf" / „Sale";
  `movementHistoryTitle` „Bewegungshistorie" / „Movement history".

### Epic B — Kategorien + Lieferanten
- **NEU: `lib/screens/categories_screen.dart`** (oder Sub-Route in Settings) —
  Warengruppen-Baum verwalten.
- **GEÄNDERT: `add_edit_supplier_dialog.dart`** — neue Felder Adresse, USt-IdNr,
  Zahlungsziel, Lieferzeit, Mindestbestellwert (zusammenklappbarer Abschnitt
  „Erweitert" damit der Dialog auf Phone nicht überläuft).
- l10n-Keys:
  `categoriesTitle` „Warengruppen" / „Categories";
  `categoryNew` „Neue Warengruppe" / „New category";
  `categoryParent` „Übergeordnet" / „Parent category";
  `supplierAddress` „Adresse" / „Address";
  `supplierVatId` „USt-IdNr" / „VAT ID";
  `supplierPaymentTerms` „Zahlungsziel (Tage)" / „Payment terms (days)";
  `supplierLeadTime` „Lieferzeit (Tage)" / „Lead time (days)";
  `supplierMinOrderValue` „Mindestbestellwert" / „Minimum order value";
  `supplierAdvancedSection` „Erweiterte Angaben" / „Advanced details".

### Epic C — Bestellwesen
- **NEU: `lib/screens/purchase_orders_screen.dart`** — Liste der Bestellungen
  mit Status-Badges; FAB „Neue Bestellung".
- **NEU: `lib/screens/purchase_order_detail_screen.dart`** — Positionen,
  Wareneingang buchen (Mengen-Soll/Ist), Status.
- Bottom-Nav/Sidebar: neuen Tab `navPurchaseOrders` ergänzen (Reihenfolge in
  `main_screen.dart` `_navIcons`/`_navLabels` 1:1 anpassen — Achtung
  Index-Lookup, siehe Kommentar dort).
- l10n-Keys:
  `navPurchaseOrders` „Bestellungen" / „Orders";
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
- **NEU: `lib/screens/warehouses_screen.dart`** — Lager verwalten (oder
  Sub-Route in Settings).
- **GEÄNDERT: Bestands-Dialog** — Lager-Auswahl-Dropdown.
- **GEÄNDERT: `dashboard_screen.dart`** — aktiver Mindestbestand-Alert-Block mit
  „Jetzt bestellen"-Aktion → öffnet `AddEditPurchaseOrder` vorbefüllt.
- l10n-Keys:
  `warehousesTitle` „Lager" / „Warehouses";
  `warehouseNew` „Neues Lager" / „New warehouse";
  `warehouseDefault` „Hauptlager" / „Main warehouse";
  `lowStockAlertTitle` „Niedriger Bestand" / „Low stock";
  `lowStockReorderAction` „Jetzt bestellen" / „Reorder now".

### Epic E — Inventur + Reporting
- **NEU: `lib/screens/stocktake_screen.dart`** + `stocktake_detail_screen.dart`
  — Inventur starten, zählen, abschließen, Differenz-Report.
- **GEÄNDERT: `lib/widgets/statistics/tabs/inventory_suppliers_tab.dart`** —
  neue Auswertungen: Bestandsbewertung (Stichtag), Lagerumschlag, ABC-Analyse.
- l10n-Keys:
  `stocktakeTitle` „Inventur" / „Stocktake";
  `stocktakeNew` „Neue Inventur" / „New stocktake";
  `stocktakeExpected` „Soll" / „Expected";
  `stocktakeCounted` „Gezählt" / „Counted";
  `stocktakeDifference` „Differenz" / „Difference";
  `reportStockValuation` „Bestandsbewertung" / „Stock valuation";
  `reportInventoryTurnover` „Lagerumschlag" / „Inventory turnover";
  `reportAbcAnalysis` „ABC-Analyse" / „ABC analysis".

---

## Tests

> CLAUDE.md: Service-Layer Unit-Tests Pflicht, Provider mit gemockten Services,
> Widget-Tests für komplexe Custom-Widgets, `smoke-full-app-audit` vor jedem
> UI-`/ship`.

- **Unit (Model):** je neues Model `toSupabaseInsert`/`fromSupabase`/`copyWith`
  Round-Trip-Tests (`test/models/product_test.dart`,
  `purchase_order_test.dart`, `warehouse_test.dart`, `stocktake_test.dart`,
  `product_category_test.dart`).
- **Unit (Service):** `InventoryProvider`-Erweiterungen gegen gemocktes
  `SupabaseRepository` — Buchungsart wird korrekt typisiert; Bestand wird über
  Produkt aggregiert; Inventur-Abschluss erzeugt korrekte `stocktake`-Movements;
  PO-Wareneingang erhöht `quantity_received` + setzt Status.
- **Unit (CSV):** `csv_service_test.dart` — neue Sektionen
  (Produkte/Kategorien/Lager/Bestellungen) Round-Trip; Legacy-CSV ohne neue
  Sektionen importiert weiterhin sauber (Rückwärtskompatibilität).
- **Migration:** `supabase db reset` muss pro Epic-Migration grün durchlaufen;
  Backfill-Asserts (jeder Alt-`inventory_item` hat danach ein `product_id`;
  jede Alt-`inventory_movement` hat ein `movement_type`).
- **Widget:** `ProductDetailScreen`, `PurchaseOrderDetailScreen`,
  `StocktakeDetailScreen` — Render + Phone-Overflow bei 360×640.
- **Smoke:** nach Epic A, C, D, E je ein `smoke-full-app-audit` (Light+Dark ×
  Desktop+Phone); neue Routen in `.claude/agents/_page-registry.md` eintragen.
- **l10n:** `/check-l10n` nach jedem Epic, DE/EN-Symmetrie.

---

## Risiken

1. **Artikelstamm-Refactor (Epic A) ist invasiv.** `inventory_items` ist heute
   das zentrale Lager-Model und hängt an `checkInDeal`, CSV-Import, Statistiken,
   `TicketSummary`-Aggregation. Eine `product_id`-Pflichtspalte falsch
   eingeführt bricht den ganzen Inventory-Pfad. → Mitigation: `product_id`
   zuerst nullable + Backfill in derselben Migration, NOT NULL erst danach;
   Alt-Spalten (`name`/`sku`) NICHT droppen.
2. **Backfill-Korrektheit.** 1:1-Backfill erzeugt pro Item ein Produkt — bei
   vielen Items mit identischem Namen entstehen Duplikate im Katalog.
   Pre-Launch akzeptabel (keine echten Daten), aber als bekannte Schuld
   dokumentieren; spätere Dedup-Funktion optional.
3. **`reason` → `movement_type`-Heuristik.** Freitext-`reason` ist
   inkonsistent; die Backfill-Heuristik mappt einige Alt-Rows auf
   `correction`. Akzeptabel, da Pre-Launch.
4. **Bottom-Nav wird voll.** Es gibt heute schon 10 Top-Level-Tabs. Bestellwesen
   + Lager + Inventur als eigene Tabs sprengt die Phone-Nav. → Mitigation:
   Lager/Kategorien/Inventur als Sub-Routen unter einem „Warenwirtschaft"-
   Hub-Screen oder unter Settings; nur Bestellwesen ggf. als eigener Tab.
   Entscheidung dem Council überlassen.
5. **Scope-Explosion / Solo-Maintainer.** 6 Epics sind viel. → Mitigation:
   strikte Phasen-Reihenfolge, P0 (Epic A) liefert allein schon Mehrwert; P1/P2
   können einzeln verschoben werden.
6. **`purchase_order_items` RLS-Pfad.** Kindtabelle muss eigene `workspace_id`
   tragen und konsistent gefüllt werden (sonst RLS-Leck oder Insert-Fail). →
   Mitigation: NOT NULL + App setzt sie aus dem Parent.
7. **Doppelte Wahrheit Bestand.** Solange `inventory_items.quantity` und
   aggregierte Movements parallel existieren, können sie divergieren. →
   Mitigation: `quantity` bleibt die Wahrheit, Movements sind Journal; Inventur
   gleicht ab. Keine Trigger-basierte Auto-Summe (zu fehleranfällig).
8. **CSV-Rückwärtskompatibilität.** Bestehende Nutzer-CSV-Exporte müssen weiter
   importierbar sein. → Mitigation: Format-Detection wie heute (Spaltenzahl),
   Tests dafür.
9. **Edge-Function-Änderung `send-notifications`.** Low-Stock-Push kann bei
   vielen Produkten spammen. → Mitigation: Dedup via `notifications_sent`,
   aggregierter Sammel-Push statt pro Produkt.

---

## Tasks

> Jeder Task ist atomar (1 PR-fähiges Increment). `agent:`-Tag = vorgesehener
> Subagent. `depends:` = Vorbedingung. Epic-Reihenfolge = Prioritäts-Reihenfolge.

### Epic A — Artikelstamm (P0)

- [ ] **A1** — Migration `products`-Tabelle anlegen (Schema + RLS + Indexe).
  `agent:db-migrator`
- [ ] **A2** — Migration: `inventory_items.product_id` (nullable) +
  `inventory_movements.movement_type`/`product_id`/`unit_cost` (nullable/Default)
  hinzufügen, inkl. CHECK-Constraints. `agent:db-migrator` · `depends:A1`
- [ ] **A3** — Migration: Backfill — pro `inventory_item` ein `products`-Row
  anlegen + `product_id` setzen; `inventory_movements.movement_type` per
  Heuristik aus `reason` füllen; danach `inventory_items.product_id` NOT NULL.
  `supabase db reset` grün. `agent:db-migrator` · `depends:A2`
- [ ] **A4** — `lib/models/product.dart` NEU (Felder, `toSupabaseInsert`,
  `fromSupabase`, `copyWith`, `toJson`/`fromJson`). `agent:flutter-coder` ·
  `depends:A1`
- [ ] **A5** — `InventoryMovement`-Model um `movementType`/`productId`/`unitCost`
  erweitern; `InventoryMovementType`-Enum. `agent:flutter-coder` · `depends:A2`
- [ ] **A6** — `SupabaseRepository`: `loadProducts`/`insertProduct`/
  `updateProduct`/`deleteProduct` + `loadAll()` um Produkte erweitern;
  `CloudSnapshot` ergänzen. `agent:flutter-coder` · `depends:A4`
- [ ] **A7** — `InventoryProvider`: Produkt-State + CRUD-Methoden; Bestands-/
  Movement-Logik auf getypte `movement_type` umstellen; `checkInDeal` schreibt
  `goods_in`. `agent:flutter-coder` · `depends:A5,A6`
- [ ] **A8** — `AddEditProductDialog` NEU; Bestands-/Wareneingangs-Dialog auf
  `product_id`-Referenz umstellen. `agent:ui-builder` · `depends:A7`
- [ ] **A9** — `inventory_screen.dart`: Stock-Tab zeigt Produkte gruppiert.
  `agent:ui-builder` · `depends:A8`
- [ ] **A10** — `product_detail_screen.dart` NEU (Stammdaten, Bestand,
  Bewegungshistorie, Chargen, Lieferant). `agent:ui-builder` · `depends:A9`
- [ ] **A11** — l10n-Keys Epic A in `app_de.arb` + `app_en.arb`; `/check-l10n`
  grün. `agent:ui-builder` · `depends:A8`
- [ ] **A12** — Unit-Tests Model + Provider (Epic A) + `smoke-full-app-audit`;
  `_page-registry.md` um `ProductDetailScreen` ergänzen.
  `agent:flutter-coder` · `depends:A10,A11`

### Epic B — Kategorien + Lieferanten (P1)

- [ ] **B1** — Migration `product_categories` + `product_suppliers` (Schema +
  RLS + Indexe); `suppliers` um Adress-/Kreditoren-Spalten erweitern.
  `agent:db-migrator` · `depends:A3`
- [ ] **B2** — Models `ProductCategory`, `ProductSupplier` NEU; `Supplier`-Model
  um neue Felder erweitern. `agent:flutter-coder` · `depends:B1`
- [ ] **B3** — `SupabaseRepository` + `InventoryProvider`: CRUD Kategorien +
  Artikel-Lieferanten-Zuordnung. `agent:flutter-coder` · `depends:B2`
- [ ] **B4** — `categories_screen.dart` NEU; `add_edit_supplier_dialog.dart` um
  „Erweitert"-Abschnitt erweitern; `AddEditProductDialog` um Kategorie-Auswahl.
  `agent:ui-builder` · `depends:B3`
- [ ] **B5** — l10n-Keys Epic B + Unit-Tests + `/check-l10n`.
  `agent:ui-builder` · `depends:B4`

### Epic C — Bestellwesen (P1)

- [ ] **C1** — Migration `purchase_orders` + `purchase_order_items` (Schema +
  RLS + Status-Trigger). `agent:db-migrator` · `depends:B1`
- [ ] **C2** — (optional) RPC `next_purchase_order_number` als
  `SECURITY DEFINER`-Function. `agent:db-migrator` · `depends:C1`
- [ ] **C3** — Models `PurchaseOrder`, `PurchaseOrderItem` NEU.
  `agent:flutter-coder` · `depends:C1`
- [ ] **C4** — `SupabaseRepository` + Provider: PO-CRUD + Wareneingang buchen
  (erhöht `quantity_received`, schreibt `goods_in`-Movement, erhöht Bestand).
  `agent:flutter-coder` · `depends:C3`
- [ ] **C5** — `purchase_orders_screen.dart` + `purchase_order_detail_screen.dart`
  NEU; neuen Nav-Tab `navPurchaseOrders` in `main_screen.dart` einfügen
  (Index-Reihenfolge sorgfältig). `agent:ui-builder` · `depends:C4`
- [ ] **C6** — l10n-Keys Epic C + Unit-Tests + `smoke-full-app-audit` +
  `_page-registry.md` ergänzen. `agent:ui-builder` · `depends:C5`

### Epic D — Mehrlager + Alerts (P1)

- [ ] **D1** — Migration `warehouses` (Schema + RLS); `inventory_items`-Nutzung
  von `warehouse_id` aktivieren (Index). `agent:db-migrator` · `depends:A3`
- [ ] **D2** — `Warehouse`-Model NEU; Repository + Provider CRUD + Default-Lager
  Bootstrap App-seitig. `agent:flutter-coder` · `depends:D1`
- [ ] **D3** — `warehouses_screen.dart` NEU; Lager-Dropdown im Bestands-Dialog.
  `agent:ui-builder` · `depends:D2`
- [ ] **D4** — `send-notifications` Edge-Function um `low_stock_alert`
  erweitern (aggregierter Sammel-Push, Dedup via `notifications_sent`).
  `agent:edge-fn-coder` · `depends:A3`
- [ ] **D5** — `dashboard_screen.dart`: aktiver Low-Stock-Alert-Block mit
  „Jetzt bestellen"-Aktion. `agent:ui-builder` · `depends:C5,D2`
- [ ] **D6** — l10n-Keys Epic D + Tests + `smoke-full-app-audit`.
  `agent:ui-builder` · `depends:D3,D5`

### Epic E — Inventur + Reporting (P2)

- [ ] **E1** — Migration `stocktakes` + `stocktake_items` (Schema + RLS).
  `agent:db-migrator` · `depends:A3`
- [ ] **E2** — Models `Stocktake`, `StocktakeItem` NEU; Repository + Provider:
  Inventur starten (Soll-Snapshot), zählen, abschließen (Differenz-Movements
  `movement_type='stocktake'`). `agent:flutter-coder` · `depends:E1,A7`
- [ ] **E3** — `stocktake_screen.dart` + `stocktake_detail_screen.dart` NEU
  (Zähl-Workflow, Differenz-Report). `agent:ui-builder` · `depends:E2`
- [ ] **E4** — `inventory_suppliers_tab.dart` um Bestandsbewertung,
  Lagerumschlag, ABC-Analyse erweitern (`statistics_service.dart` ergänzen).
  `agent:flutter-coder` · `depends:A7`
- [ ] **E5** — l10n-Keys Epic E + Tests + `smoke-full-app-audit` +
  `_page-registry.md`. `agent:ui-builder` · `depends:E3,E4`

### Epic F — CSV + Doku (P1, querschnittlich)

- [ ] **F1** — `csv_service.dart`: neue Sektionen Produkte/Kategorien/Lager/
  Bestellungen in Export + Import; Legacy-CSV bleibt importierbar; Tests.
  `agent:flutter-coder` · `depends:C4,D2`
- [ ] **F2** — Handbuch nachziehen: `06-database.md` (neue Tabellen),
  `03-screens-walkthrough.md` (neue Screens), `05-architecture.md`,
  `07-edge-functions.md` (`send-notifications`-Erweiterung), `10-glossary.md`.
  `agent:flutter-coder` · `depends:E5`
- [ ] **F3** — Hilfeseite (`help_screen.dart` + ARBs) um Sektionen Artikelstamm,
  Bestellwesen, Lager, Inventur erweitern. `agent:ui-builder` · `depends:E5`

---

## Offene Fragen für das Committee

1. **Nav-Struktur** — eigener „Warenwirtschaft"-Hub-Screen vs. mehrere
   Top-Level-Tabs vs. Sub-Routen unter Settings? (Risiko 4)
2. **`order_number`-Vergabe** — `SECURITY DEFINER`-RPC (lückenlos) vs.
   client-seitig (kleine Lücken erlaubt)? (Task C2)
3. **Bewertungsverfahren (L9)** — gleitender Durchschnitt vs. FIFO vs. nur
   `unit_cost`-Snapshot? Aktuell Plan: nur `unit_cost` pro Movement, echte
   Bewertung als P2-Erweiterung.
4. **Soll Epic A wirklich P0 sein**, oder reicht ein schlankerer Erst-Schritt
   (nur getypte `movement_type` + Artikel-Detail-Screen, ohne `products`-
   Tabelle)? Der `products`-Refactor ist der teuerste/riskanteste Block.
