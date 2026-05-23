# UI/UX Responsive Overhaul — Laptop/Phone-Struktur

**[Committee-Approved 2026-05-23]**

Datum: 2026-05-22
Slug: `ui-ux-responsive-overhaul`
Autor: planner (Opus)
Stakeholder-Wunsch (Original, EN): _"analyze the project UI/UX what should be better, how should it be structured regarding laptop / phone usage"_

---

## 0. IST-Analyse (Codebase-Fakten, Stand `feature/brand-canlogistics`)

Diese Sektion ist die Grundlage des Plans. Alle Befunde sind mit Datei/Zeile belegt.
Es ist eine Bestandsaufnahme einer existierenden App — kein Greenfield.

### 0.1 Was heute gut ist

- **Theme-System ist solide.** `lib/app_theme.dart` hat konsequente Light/Dark-Tokens,
  `*Of(context)`-Helper, 5 Paletten. Kein Anlass für eine Theme-Überarbeitung.
- **Mobile-First-Grundgerüst existiert.** `main_screen.dart` hat eine echte
  `NavigationBar` für Phone (`Key('mainBottomNav')`) und eine Custom-Sidebar für
  Desktop. Bottom-Nav erzwingt Single-Line-Labels (Z. 381–395) — durchdacht.
- **`LayoutBuilder` statt `Platform.is*` für Layout** wird breit eingehalten.
  `Platform.is*` taucht nur in `push_service.dart` und `auth_provider.dart` auf
  (legitim — Plattform-Capability, kein Layout). CLAUDE.md-Regel ist hier erfüllt.
- **Master-Detail existiert ansatzweise.** `deals_screen.dart` (Summary-Panel ab
  1100px), `tickets_screen.dart` (Detail-Panel ab 1100px) zeigen, dass das Muster
  bekannt ist.
- **Warehouse-Hub-Pattern.** `warehouse_hub_screen.dart` bündelt **6 Sub-Bereiche**
  unter einem MainTab — verhindert ein Überlaufen der Top-Level-Nav.
- **Touch-Targets im Hub korrekt.** `_HubTile` baut bewusst 48×48-dp-Targets
  (Kommentar Z. 156, 161).

### 0.2 Schwachstellen — priorisiert

#### P0 — Breakpoint-Chaos (harte Inkonsistenz, messbar)

Es gibt **keinen** zentralen Breakpoint. Jeder Screen erfindet eigene Schwellen.
Belegte Werte aus `grep` über `lib/`:

| Wert | Fundstelle |
|---|---|
| `< 800` Phone/Desktop-Shell-Switch | `main_screen.dart:321` |
| `>= 1100` Sidebar-extended | `main_screen.dart:322` |
| `< 700` | `inventory_screen.dart:52`, `deal_table.dart:130` |
| `< 650` | `tickets_screen.dart:167` |
| `>= 1100` Detail-Panel | `deals_screen.dart:17`, `tickets_screen.dart:188` |
| `< 600` | `public_profile_screen.dart:112/189`, `settings_screen.dart:623`, `onboarding_screen.dart:187` |
| `< 520` | `dashboard_screen.dart:116/254` |
| `< 500 / < 900 / < 1200` KPI-Spalten | `dashboard_screen.dart:337` |
| `< 480` | `add_edit_deal_dialog.dart:383`, `settings_screen.dart:804/962`, `inventory_suppliers_tab.dart` (mehrfach) |
| `> 960` | `dashboard_screen.dart:60` |
| `> 900` | `statistics/filter_bar.dart:33`, `overview_tab.dart:116/148` |
| `> 800` | `finance_tab.dart:31`, `inventory_suppliers_tab.dart:261/697` |
| `< 340 / < 320` | `inbox_screen.dart:1249`, `tracking_status_block.dart:601` |

**Konkretes Problem:** CLAUDE.md schreibt `< 600` als Bottom-Nav-Grenze vor,
`main_screen.dart` nutzt aber `< 800`. Auf einem 600–800px-Viewport (kleines
Tablet, geteiltes Browser-Fenster) zeigt die App also Bottom-Nav, obwohl die
CLAUDE.md-Regel Sidebar erwarten lässt. Jeder Screen entscheidet zudem für sich,
ab wann er „schmal" ist — ein 760px-Fenster bekommt Bottom-Nav (`<800`), aber
die Deal-Tabelle rendert dort schon „breit" (`>700`). Inkonsistente
Wahrnehmung über Screens hinweg.

**Latenter Bug — Viewport-vs-Container-Verwechslung.** `deals_screen.dart:17`
nutzt `MediaQuery.of(context).size.width >= 1100`, obwohl der Body in einem
`Expanded` neben der 220px-Sidebar sitzt. Damit prüft der Code die
**Viewport-Breite** (1440 inkl. Sidebar) und nicht die **Container-Breite**
(1220). Das ist heute unauffällig, weil die Schwelle bei 1100 liegt — auf
einem 1280px-Viewport blendet die Sidebar das Summary-Panel aber neben einer
nur 1060px breiten Tabelle ein. Identische Fehlklasse muss bei der Migration
explizit auseinandersortiert werden (siehe §5.1 Zwei-Achsen-API).

#### P0 — Desktop verschenkt horizontalen Raum massiv

Auf 1440px-Viewport ist der Großteil der Screens eine **einspaltige Phone-Säule**,
die über die volle Breite gestreckt wird oder linksbündig ausläuft:

- `dashboard_screen.dart`: `SingleChildScrollView` mit `EdgeInsets.all(24)` —
  KPI-Grid geht bis 7 Spalten (Z. 337), aber kein `maxWidth`-Constraint → auf
  einem Ultrawide werden KPI-Karten unleserlich breit/dünn.
- `inventory_screen.dart`, `warehouse_hub_screen.dart`, `suppliers_screen.dart`,
  `purchase_orders_screen.dart`, `warehouses_screen.dart`, `stocktake_screen.dart`,
  `categories_screen.dart`: vertikale Card-Listen ohne `maxWidth`-Container und
  ohne Master-Detail-Split. Auf Desktop = eine sehr breite Card-Liste, kein
  Detail-Bereich. Tap auf Item pusht einen Vollbild-Screen (`product_detail_screen.dart`)
  statt eine Detail-Spalte zu füllen.
- Nur `deals_screen.dart` + `tickets_screen.dart` haben überhaupt ein
  Detail-/Summary-Panel — und auch nur ab 1100px.
- `settings_screen.dart`, `help_screen.dart`, `pricing_screen.dart`: kein
  `maxWidth`, Content läuft potenziell über die volle Fensterbreite.

#### P1 — Warehouse-Hub ist auf Desktop eine Sackgasse

Der Hub hat **6 Kacheln** (`warehouse_hub_screen.dart:36–126`):
`ProductCatalog`, `PurchaseOrders`, `Warehouses`, `Categories`, `Stocktake`,
`Reporting`. Alle werden per `Navigator.push` als **Vollbild-Routen** geöffnet.

Detail-Screens (`purchase_order_detail`, `stocktake_detail`) werden _nicht_ vom
Hub gepusht, sondern aus ihren Listen heraus.

Sonderfall **Reporting-Tile** (Z. 111–125): pusht ein **inline `Scaffold` mit
eigener `AppBar`** statt einen normalen Screen. Damit ist Reporting heute
strukturell _nicht_ embeddable — der Wrapper-`Scaffold` müsste vor einem
Master-Detail-Embed entfernt werden. Für T3.4 ist Reporting deshalb
**ausgenommen** oder bekommt einen eigenen Sub-Task (siehe Tasks).

Auf Phone ist der Vollbild-Push korrekt. Auf Desktop verdeckt der gepushte
Vollbild-Screen die Sidebar/Rail komplett — der User verliert die
Top-Level-Navigation und muss über einen AppBar-Back-Button zurück. Das
bricht das Shell-Modell, das `main_screen.dart` für alle anderen Tabs
konsequent durchhält (Tab-Wechsel ohne Navigator-Push).

#### P1 — Navigations-Architektur: 11 MainTabs, unklare Priorisierung

`MainTab` hat 11 Werte (`main_tab.dart`). Auf Phone sind 5 in der Bottom-Nav
(Dashboard, Deals, Tickets, Inbox, Inventory) — der Rest (Suppliers, Stats,
Activity, Settings, Help, Warehouse = **6 Einträge**) liegt im „Mehr"-Sheet
(`_MoreNavSheet`). Beobachtungen:

- **Inhaltliche Doppelung Inventory vs. Warehouse:** Es gibt einen Top-Level-Tab
  `Inventory` UND einen Top-Level-Tab `Warehouse`, der u.a. „Artikelstamm" und
  „Lager" enthält. Für einen neuen Nutzer ist der Unterschied zwischen
  „Inventory" und „Warehouse → Artikelstamm" nicht selbsterklärbar. Das ist ein
  Informationsarchitektur-Problem, kein reines Layout-Problem.
- **`Suppliers` als eigener Top-Level-Tab** ist fraglich — Lieferanten gehören
  konzeptionell zur Warenwirtschaft (Hub), nicht auf dieselbe Ebene wie
  Dashboard/Deals.
- Das „Mehr"-Sheet mit 6 Einträgen ist grenzwertig voll; jeder neue Screen
  verschärft das.
- Auf Desktop listet die Sidebar alle 11 Tabs flach untereinander
  (`_Sidebar`, `main_screen.dart:517–537`) — keine Gruppierung
  (z.B. „Vertrieb" vs. „Lager" vs. „System").

#### P1 — Desktop-Navigation ist eine Custom-Sidebar statt `NavigationRail`

`_Sidebar` (`main_screen.dart:456–545`) ist handgebaut: feste Breiten 64/220 px,
`MouseRegion`-Hover, `_NavItem`-State pro Item. Funktioniert, aber:

- Kein `NavigationRail` → keine Material-3-Standard-A11y (Semantics,
  Keyboard-Traversal sind teils selbstgebaut).
- Hover-Logik ist okay (kein Hover-**Only**), aber zusätzlicher Wartungs-Code.
- Collapse/Expand ist rein breitenabhängig (`extended = width >= 1100`),
  nicht vom User steuerbar.

#### P2 — Konsistenz alte vs. neue Screens

- Die Warenwirtschafts-Screens (neu) nutzen durchgehend `SafeArea` +
  Card-Listen + FABs mit `Key(...)`. Die älteren Screens (`deals`, `inventory`,
  `inbox`) mischen `TabBar`-Patterns, Tabellen und eigene Such-Bars. Es gibt kein
  gemeinsames „Screen-Scaffold"-Widget → jeder Screen baut Header/Such-Bar/
  Empty-State neu.
- Empty-States: `dashboard_screen.dart` hat `_EmptyStateCard`, andere Screens
  haben eigene oder keine. Kein geteiltes `EmptyState`-Widget.
- KPI-Karten existieren doppelt: `lib/widgets/kpi_card.dart` UND
  `lib/widgets/statistics/kpi_card.dart`.

#### P2 — Phone-Ergonomie-Detailrisiken

- `_MoreNavSheet` ist `isScrollControlled: true`, aber `mainAxisSize.min` —
  bei 6 Einträgen + Handle + Titel auf 360×640 noch okay, aber wenig Puffer.
- **Reachability** (Account-Menü, Search, Help-Action sitzen oben rechts in der
  AppBar; auf großen Phones >6,5" mit Daumen schwer erreichbar) wird in
  diesem Plan **nicht** behandelt — siehe §2 Out-of-Scope.
- Tabellen-Patterns: `deal_table.dart` schaltet ab `<700` auf schmal — gut.
  Statistics-Tabs (`sortable_table.dart`) sollten auf Phone geprüft werden
  (horizontaler Scroll-Verdacht).

### 0.3 Fazit der IST-Analyse

Das Fundament (Theme, Shell, Mobile-First-Intention) ist gesund. Die zwei
größten realen Probleme sind: **(1) kein zentraler Breakpoint** → Inkonsistenz
und CLAUDE.md-Regelbruch, und **(2) Desktop verschenkt Raum** → die App fühlt
sich auf dem Laptop wie eine hochskalierte Phone-App an. Die Navigations-IA
(11 Tabs, Inventory/Warehouse-Doppelung) ist ein eigenes, größeres Thema und
wird hier bewusst nur teilweise adressiert (siehe Out-of-Scope).

---

## 1. Ziel

Eine konsistente, zentral gesteuerte Responsive-Architektur etablieren: ein
einziger Satz Breakpoints für die gesamte App, eine echte Desktop-Navigation
(`NavigationRail`), und Master-Detail- bzw. `maxWidth`-Layouts auf großen
Screens — **ohne** die bestehende Phone-Erfahrung zu verschlechtern. Mobile-First
bleibt die Priorität; Desktop wird vom „gestreckten Phone" zum eigenständig
gut nutzbaren Layout.

## 2. Scope

### In Scope

- Zentrale Breakpoint-Infrastruktur (`lib/utils/responsive.dart`, NEU) mit
  **zwei klar getrennten Achsen** (Viewport für Shell, Container für
  Screen-internes Layout).
- Migration aller bestehenden Magic-Number-Breakpoints auf die zentralen Werte
  **zweiphasig** (siehe Task-Sektion):
  - Phase A: rein indirekt (Wert bleibt identisch, nur Konstante statt Zahl).
  - Phase B: bewusste Konsolidierung (Wert ändert sich, Verhaltensänderung
    explizit dokumentiert).
- Desktop-Navigation: Ablösung der Custom-`_Sidebar` durch `NavigationRail`
  (Material-3), inkl. optionaler Gruppierung der Tab-Liste.
- `maxWidth`-Content-Container für „lange Säulen"-Screens auf Desktop.
- Master-Detail-Pattern für mind. 2 Listen-Screens, die heute Vollbild-Push
  nutzen (`inventory_screen` → `product_detail_screen`; Warehouse-Sub-Listen).
- Warehouse-Hub auf Desktop: Sub-Routen nicht mehr als Vollbild-Push, sondern
  innerhalb der Shell (Hub als Master, Sub-Bereich als Detail) — **ausgenommen
  Reporting** (siehe T3.4-Note).
- Geteiltes `AppScreenScaffold`- / `EmptyState`-Widget für Konsistenz (NEU,
  verbindlich als eigene Epic-Voraussetzung, kein „optional" mehr).
- Browser-Audit über alle 4 Viewports nach jeder Epic.

### Out of Scope (bewusst)

- **Informationsarchitektur-Redesign** (Inventory-vs-Warehouse-Merge,
  Suppliers in den Hub verschieben). Das ist ein eigener Plan — hier nur als
  Risiko/Empfehlung dokumentiert, nicht implementiert. Begründung: hohe
  Daten-/Routing-Auswirkung, eigener Council nötig.
- **Reachability-Befund** (AppBar-Aktionen Account/Search/Help oben rechts,
  Daumen-Erreichbarkeit auf großen Phones). Eigener Folge-Plan, falls
  Stakeholder das priorisiert.
- Neue Features, neue Screens, neue Datentabellen.
- Theme-/Farb-Überarbeitung (`app_theme.dart` ist gesund).
- l10n-Vollaudit (separater `/check-l10n`-Lauf).
- Animations-/Motion-Polish über das Nötigste hinaus.
- Tablet-spezifische Sonder-Layouts (Tablet folgt dem Desktop- oder
  Phone-Pfad je nach Breakpoint — kein dritter, eigener Layout-Zweig).

## 3. Datenmodell + RLS

**Keine.** Dies ist ein reiner UI/UX-/Frontend-Plan. Es werden keine Tabellen,
Spalten oder RLS-Policies angelegt oder geändert. `supabase/migrations/` wird
nicht angefasst.

## 4. API / Edge Functions

**Keine.** Es werden keine Edge Functions angelegt oder geändert. Keine
Änderungen an `supabase/functions/`.

## 5. UI + l10n-Keys

### 5.1 Neue Infrastruktur-Datei (NEU) — Zwei-Achsen-API

`lib/utils/responsive.dart` — zentrale Breakpoint-Konstanten + **zwei getrennte
Helper-Achsen**:

**Achse 1: Viewport (nur für die App-Shell in `main_screen.dart`)**

Diese Helper kapseln `MediaQuery.sizeOf(context)` und liefern die
Viewport-Größe des gesamten Fensters. Sie dürfen **ausschließlich** in
`main_screen.dart` für den Shell-Switch (Bottom-Nav vs. NavigationRail)
benutzt werden — überall sonst sind sie falsch, weil die Desktop-Sidebar
die nutzbare Breite reduziert.

**Achse 2: Container (für alles innerhalb eines Screens)**

Pure Funktionen auf `double`. Werden mit `constraints.maxWidth` aus einem
`LayoutBuilder` aufgerufen — **nie** mit einem `BuildContext`. Damit ist es
strukturell unmöglich, versehentlich die Viewport-Breite für ein
Screen-internes Layout zu nutzen.

```dart
// lib/utils/responsive.dart

/// Geteilte Schwellen für beide Achsen. Material-3-Window-Size-Classes als
/// Referenz: Compact <600 / Medium 600-840 / Expanded ≥840 / Large ≥1200.
/// Wir setzen [navRail] auf 900 statt 840, weil die Top-Bar + 11 Tabs auf
/// 840px noch nicht komfortabel als Rail rendern (siehe Council-Notiz §5.1).
class Breakpoints {
  /// Phone vs. nicht-Phone. CLAUDE.md-konform (Bottom-Nav-Grenze).
  static const double phone   = 600;
  /// Shell-Switch: ab hier zeigt main_screen.dart die NavigationRail
  /// statt Bottom-Nav. Verhaltensändernd ggü. heute (alt: 800).
  static const double navRail = 900;
  /// Master-Detail-Schwelle für Screen-interne Splits (Deals-Summary,
  /// Tickets-Detail, Inventory-Detail, Warehouse-Hub-Detail).
  static const double master  = 1200;
  /// NavigationRail extended (Labels sichtbar) statt collapsed.
  static const double railExtended = 1200;
}

enum ScreenSize { phone, tablet, desktop }

// ── Viewport-Achse (App-Shell only) ──────────────────────────────────
/// NUR für [main_screen.dart] benutzen — die einzige Stelle, an der die
/// volle Viewport-Breite die richtige Größe ist. Überall sonst:
/// [widthClassOf] aus einem [LayoutBuilder] verwenden.
ScreenSize screenSizeOf(BuildContext context);
bool isPhoneViewport(BuildContext context);
bool isDesktopViewport(BuildContext context);

// ── Container-Achse (Screen-intern) ──────────────────────────────────
enum WidthClass { compact, medium, expanded, large }
/// Bestimmt die Breitenklasse aus einer expliziten Pixel-Breite —
/// typischerweise `constraints.maxWidth` aus einem [LayoutBuilder].
/// Nimmt KEINEN BuildContext, damit Viewport-vs-Container-Bugs
/// unmöglich werden.
WidthClass widthClassOf(double width);
bool isCompact(double width);
bool isMedium(double width);
bool isExpanded(double width);
bool isLarge(double width);
```

**Dartdoc-Pflicht-Hinweis im File-Header von `responsive.dart`:**

> Für Layout-Entscheidungen INNERHALB eines Screens IMMER
> `widthClassOf(constraints.maxWidth)` aus einem `LayoutBuilder` —
> NIE `MediaQuery`, da die Desktop-Sidebar/Rail die nutzbare Breite
> reduziert. `MediaQuery`-basierte Helper (`screenSizeOf`,
> `isPhoneViewport`, `isDesktopViewport`) sind ausschließlich in
> `main_screen.dart` für den Shell-Switch erlaubt.

**Begründung der Werte (M3-Window-Size-Classes als Referenz):**

| Klasse | M3-Schwelle | Unsere Schwelle | Begründung |
|---|---|---|---|
| Compact | <600 | `Breakpoints.phone = 600` | identisch — CLAUDE.md-Regel |
| Medium | 600–840 | (kein eigener Helper, fällt unter Container-Achse) | wir brauchen für Shell keinen Medium-Bucket |
| Expanded | ≥840 | `Breakpoints.navRail = 900` | bewusst 900 statt 840: 840px Viewport entspricht ~620px Body neben einer 220px-Rail → noch nicht komfortabel zwei-spaltig. 900 gibt der Rail Atem. |
| Large | ≥1200 | `Breakpoints.master = railExtended = 1200` | Master-Detail rendert erst ab ~1200 sauber (Liste 360 + Detail 800 + Padding) |

Diese Entscheidung — `navRail = 900` als Shell-Switch — ist die wichtigste
strukturelle Festlegung des Plans. Sie ist **verhaltensändernd** gegenüber
heute (`<800` Sidebar) und wird in T1.3 explizit als Verhaltens-Diff
auditiert (siehe Phase-B-Task T1.3b).

### 5.2 Migrations-Inventar (Vorher/Nachher-Wert-Tabelle)

Verbindliche Mapping-Tabelle pro zentraler Schwelle. „Verhalten" = ändert sich
das gerenderte Layout an irgendeinem Pixel?

| Symbol (neu) | Heute | Neu | Verhaltensänderung? |
|---|---|---|---|
| `main_screen` shell narrow | `< 800` (Viewport) | `< Breakpoints.navRail` = `< 900` | **JA** — im Band 800–899 wechselt die Shell heute auf Sidebar, künftig erst ab 900. Phase B, separater Audit. |
| `main_screen` rail extended | `>= 1100` (Viewport) | `>= Breakpoints.railExtended` = `>= 1200` | **JA** — Band 1100–1199 zeigt heute Labels, künftig collapsed. Phase B. |
| `deals_screen` summary panel | `>= 1100` (`MediaQuery.size`) | `>= Breakpoints.master` = `>= 1200` (`constraints.maxWidth` via LayoutBuilder) | **JA, doppelt** — (a) Schwelle wandert 1100→1200, (b) Bug-Fix: heute Viewport-Breite, künftig Container-Breite. Phase B. |
| `tickets_screen` detail panel | `> 1100` (`constraints.maxWidth`) | `>= Breakpoints.master` = `>= 1200` | **JA** — Schwelle wandert. Phase B. |
| `inventory_screen` narrow | `< 700` (`constraints.maxWidth`) | Phase A: `< 700` als Konstante. Phase B: später ggf. konsolidieren. | Phase A: nein. |
| `deal_table` narrow | `< 700` (`constraints.maxWidth`) | Phase A: `< 700` als Konstante. | Phase A: nein. |
| `tickets_screen` mobile-layout switch | `< 650` (`constraints.maxWidth`) | Phase A: `< 650` als Konstante. | Phase A: nein. |
| `tickets_screen` filter-pane wide | `> 1100` (`constraints.maxWidth`, Filter 440 statt 360) | Phase A: `> 1100` als Konstante. | Phase A: nein. |
| `dashboard_screen` KPI-Spalten | `< 500 / < 900 / < 1200` (`constraints.maxWidth`) | Phase A: jeweils als Konstanten. | Phase A: nein. |
| `dashboard_screen` Z. 60 | `> 960` | Phase A: als Konstante. | Phase A: nein. |
| `dashboard_screen` Z. 116/254 | `< 520` | Phase A: als Konstante. | Phase A: nein. |
| `settings_screen` Z. 623 | `< 600` | Phase A: `Breakpoints.phone`. | nein (identisch). |
| `settings_screen` Z. 804/962 | `< 480` | Phase A: als Konstante. | Phase A: nein. |
| `public_profile_screen` Z. 112/189 | `< 600` | Phase A: `Breakpoints.phone`. | nein. |
| `onboarding_screen` Z. 187 | `< 600` | Phase A: `Breakpoints.phone`. | nein. |
| `inbox_screen` Z. 1249 | `< 340` | Phase A: als Konstante. | Phase A: nein. |
| `tracking_status_block` Z. 601 | `< 320` | Phase A: als Konstante. | Phase A: nein. |
| `statistics/filter_bar` Z. 33, `overview_tab` Z. 116/148 | `> 900` | Phase A: als Konstante. | Phase A: nein. |
| `finance_tab` Z. 31, `inventory_suppliers_tab` Z. 261/697 | `> 800` | Phase A: als Konstante. | Phase A: nein. |
| `add_edit_deal_dialog` Z. 383, `inventory_suppliers_tab` (mehrfach) | `< 480` | Phase A: als Konstante. | Phase A: nein. |

**Spalten-Definitionen für Implementer:**
- _Heute (MQ / Constraint)_ = welche Quelle (`MediaQuery` oder `LayoutBuilder.constraints`).
- _Wert_ = aktuelle Pixel-Zahl im Code.
- _Ziel-Helper_ = Viewport-Achse (`isPhoneViewport`, `isDesktopViewport`,
  `screenSizeOf`) oder Container-Achse (`widthClassOf`, `isCompact`,
  `isMedium`, `isExpanded`, `isLarge`).

**Implementer-Hilfe — Inventar vervollständigen:**

```bash
grep -rn "MediaQuery\.of\|MediaQuery\.size\|MediaQuery\.sizeOf\|constraints\.maxWidth" lib/screens lib/widgets
```

Falls bei der Migration zusätzliche Fundstellen auftauchen, gehören sie in die
Tabelle nachgetragen, bevor der entsprechende Phase-A-Task gemerged wird.

### 5.3 Screen-/Widget-Änderungen

| Bereich | Änderung |
|---|---|
| `main_screen.dart` | `narrow`/`extended` via `Breakpoints` (`isPhoneViewport`/`isDesktopViewport`). `_Sidebar` → `AppNavRail` (M3 `NavigationRail` gekapselt). Optional: Gruppierung der Rail-Items. |
| `warehouse_hub_screen.dart` | Auf Desktop: Sub-Bereich als Detail-Spalte statt `Navigator.push`. Auf Phone: Verhalten unverändert. **Reporting-Tile ausgenommen** (siehe T3.4-Note). |
| `inventory_screen.dart` | Desktop: Master-Detail (Liste links, `product_detail` rechts) über beide TabBar-Tabs (Stock/Sold). Phone: unverändert. Lokale `<700`-Schwelle → Phase-A-Konstante. |
| `dashboard_screen.dart` | `maxWidth`-Container (z.B. 1400). KPI-Spalten-Logik via Container-Achse. |
| `deals_screen.dart`, `tickets_screen.dart` | Detail-Panel-Grenze `1100` → `Breakpoints.master`. **`deals_screen` Bug-Fix:** `MediaQuery.of().size.width` → `LayoutBuilder` + `constraints.maxWidth`. |
| `settings_screen.dart`, `help_screen.dart`, `pricing_screen.dart` | `maxWidth`-Container auf Desktop; lokale Breakpoints migrieren. |
| `purchase_orders/warehouses/categories/stocktake/product_catalog_screen.dart` | `maxWidth`-Container; ggf. Master-Detail via Hub-Detail-Pattern (Reporting ausgenommen). |
| `lib/widgets/` (statistics-Tabs, `add_edit_deal_dialog`, `inbox_screen`, `tracking_status_block`) | Lokale Magic-Number-Breakpoints auf `Breakpoints`/Konstanten migrieren. |
| `lib/widgets/app_screen_scaffold.dart` (NEU, verbindlich) | Geteiltes Scaffold mit Such-Bar/Header-Slot/Empty-State-Slot, `maxWidth`-Container. |
| `lib/widgets/empty_state.dart` (NEU, verbindlich) | Geteiltes Empty-State-Widget mit l10n-Slots. |

### 5.4 A11y-Anker (verbindliche `Key`s für neue Widgets)

Browser-Tester nutzt Accessibility-Names + `Key(...)` (CLAUDE.md Selector-Regel).
Neue/umgebaute Widgets brauchen folgende Pflicht-Keys, damit Smoke-Tests
sie auch nach dem Rail-Umbau ansprechen können:

| Widget | Key | Zweck |
|---|---|---|
| `AppNavRail` Root | `Key('mainNavRail')` | Container — ersetzt `_Sidebar`-Anker in Tests. |
| `NavigationRailDestination` pro Tab | `Key('navRailDestination-<tabname>')` | Tab-spezifisches Anklicken, analog `main-tab-<name>` der Bottom-Nav. **Zusätzlich** der bestehende `Key('main-tab-<name>')` bleibt erhalten (bestehende Tests greifen darauf zu). |
| Inbox-Badge in Rail | `Key('mobile-nav-inbox-badge')` | identisch zum Phone-Badge. **Muss durch den Umbau überleben** — `NavigationRailDestination` umschließt das Icon nicht automatisch mit einem Badge; das Wrapping ist Pflicht pro Destination, der `Key` wird auf den `Badge` gesetzt. |
| Rail Collapse/Expand Toggle | `Key('navRailCollapseToggle')` | für Keyboard- + Click-Tests. |
| Master-Detail Detail-Pane Root | `Key('detailPane')` | für Master-Detail-Widget-Tests. |
| Master-Detail Empty-Placeholder | `Key('detailPaneEmpty')` | empty-State-Anker. |

### 5.5 Master-Detail State-Matrix (T3.3 + T3.4)

Pro Master-Detail-Screen müssen folgende 5 States explizit gerendert werden
(jeweils Widget-Test + visueller Audit-Pass):

| State | Beschreibung | l10n-Key (DE / EN) |
|---|---|---|
| `empty` | Kein Item gewählt → Placeholder im Detail-Pane. | `detailPaneNoSelection` = "Kein Eintrag ausgewählt" / "No item selected" |
| `loading` | Detail-Nachlade läuft — Skeleton-Loader im Detail-Pane. | `detailPaneLoading` = "Wird geladen…" / "Loading…" |
| `error` | Detail-Nachlade fehlgeschlagen / kein Netz. | `detailPaneError` = "Eintrag konnte nicht geladen werden" / "Could not load entry" |
| `no-permission` | Aktive Rolle (z.B. Viewer) darf das Detail nicht bearbeiten — FAB/Edit-Verhalten muss identisch zur Vollbild-Version sein (kein Bypass des bestehenden Rechte-Checks). | `detailPaneNoPermission` = "Keine Berechtigung zum Bearbeiten" / "No permission to edit" |
| `success` | Normaler Detail-Inhalt rendert. | — (kein zusätzlicher l10n-Key, übernimmt bestehende Detail-Strings) |

**State-Erhalt über Breakpoint-Grenzen:** Bei einem Resize Phone → Desktop
(z.B. Browser-Window-Resize, Geräte-Rotation auf Tablet) darf der
Selektions-, Scroll- und Such-State nicht verloren gehen. Mitigation:
`PageStorageKey` auf der Master-Liste + Detail-State in einem
gemeinsamen Provider/Owner-Widget oberhalb des `LayoutBuilder`-Switches.
Wird in T3.3a (Selektions-State-Lift) explizit getestet.

### 5.6 NavigationRail Index-Mapping + Visibility-Filter (Security-relevant)

`NavigationRail` erwartet einen dichten `int selectedIndex` über die
**gerenderten** Destinations — der ist **nicht** identisch mit `MainTab.index`,
weil:

- Inbox ist auf Free-Plan ausgeblendet (`_navVisibility[MainTab.inbox] == false`).
- Optionale Gruppierung (T2.3) ändert die Reihenfolge bzw. fügt Separators ein.

**Pflicht-Mapping-Schicht** (analog zur bestehenden Bottom-Nav, siehe
`_bottomNavTabs` / `_bottomNavSelectedIndex` / `_bottomNavOnTap` in
`main_screen.dart:201–228`):

```dart
List<MainTab> _railTabs(Map<MainTab, bool> visibility) {
  // Filtert visibility[tab] == false raus. Reihenfolge = MainTab.values
  // (bzw. Gruppen-Reihenfolge bei T2.3).
}
int _railSelectedIndex(MainTab current, List<MainTab> railTabs);
MainTab _railOnTap(int railIndex, List<MainTab> railTabs);
```

**Security-Pflicht (kein Feature-Gating-Bypass):**

- `AppNavRail` MUSS `visibility[tab] != false` filtern, **bevor** die
  `NavigationRailDestination`-Liste aufgebaut wird — identisch zur
  bestehenden `_Sidebar`-Logik (`main_screen.dart:521–522`).
- Auf Free-Plan (`BillingProvider.currentPlan == BillingPlan.free`,
  `PricingPlan.hasInbox == false`) darf der Inbox-Tab **nicht** in der
  Rail erscheinen. Sonst hätte der Free-Nutzer einen Klick-Weg zum
  Paid-Feature.
- T2.4 enthält einen expliziten Widget-Test mit Free-Plan-`BillingProvider`
  → Rail-Destinations dürfen keinen `MainTab.inbox`-Eintrag haben.
- Bei T2.3 (Rail-Gruppierung) wird der Visibility-Filter **vor** der
  Gruppierung angewandt — wenn eine Gruppe nach dem Filter leer ist, wird
  sie **komplett** ausgeblendet (kein leerer Gruppen-Header).

### 5.7 NavigationRail Theme-Anpassung (Branding-Erhalt)

M3 `NavigationRail` folgt by-default `ColorScheme.surface` /
`ColorScheme.onSurface` — das ist nicht identisch mit der heutigen
`_Sidebar`, die explizit `AppTheme.navBg` (dunkles Branding) und
`AppTheme.navIcon` / `AppTheme.navLabel` nutzt.

Damit das Branding nach dem Umbau identisch bleibt:

- `AppNavRail` wickelt den `NavigationRail` in ein
  `NavigationRailTheme(data: NavigationRailThemeData(...))` mit folgenden
  Tokens:
  - `backgroundColor: AppTheme.navBg`
  - `unselectedIconTheme.color: AppTheme.navIcon`
  - `selectedIconTheme.color: Colors.white`
  - `unselectedLabelTextStyle.color: AppTheme.navLabel`
  - `selectedLabelTextStyle.color: Colors.white`
  - `indicatorColor: Colors.white.withAlpha(20)` (entspricht heutigem
    Selected-Background in `_NavItem`).
- Im Browser-Audit der Epic 2 wird Light + Dark verglichen — Pixel-Diff
  gegen das heutige Branding sollte minimal sein (Indicator-Form ändert
  sich von „linker Strich" zu M3-Pill — bewusste Material-3-Konvention,
  als Verhaltensänderung im Audit dokumentiert).

### 5.8 Neue l10n-Keys (DE + EN, beide Pflicht)

| Key | DE | EN |
|---|---|---|
| `navGroupSales` | "Vertrieb" | "Sales" |
| `navGroupWarehouse` | "Lager" | "Warehouse" |
| `navGroupSystem` | "System" | "System" |
| `navRailCollapse` | "Menü einklappen" | "Collapse menu" |
| `navRailExpand` | "Menü ausklappen" | "Expand menu" |
| `detailPaneNoSelection` | "Kein Eintrag ausgewählt" | "No item selected" |
| `detailPaneLoading` | "Wird geladen…" | "Loading…" |
| `detailPaneError` | "Eintrag konnte nicht geladen werden" | "Could not load entry" |
| `detailPaneNoPermission` | "Keine Berechtigung zum Bearbeiten" | "No permission to edit" |

Falls die Rail-Gruppierung im Council verworfen wird, entfallen die
`navGroup*`-Keys. Bestehende `nav*`-Label-Keys (`navDashboard` …
`navWarehouse`) werden wiederverwendet — keine Umbenennung.

## 6. Tests

### 6.1 Widget-Tests (`test/`)

- `test/responsive_test.dart` (NEU) — beide Achsen:
  - Viewport-Achse: `screenSizeOf` / `isPhoneViewport` / `isDesktopViewport`
    gegen 360, 390, 768, 1440 + Grenzwerte 599/600, 899/900, 1199/1200.
  - Container-Achse: `widthClassOf` / `isCompact` / `isMedium` / `isExpanded` /
    `isLarge` als pure-function-Tests (keine Widgets) — über dieselben Werte.
  - **Pflicht-Test gegen Constraint-vs-Viewport-Bug:** Widget-Test, der einen
    Migrations-Ziel-Screen (z.B. `DealsScreen`) in einem **schmalen
    `Expanded`-Container bei breitem Viewport** rendert (z.B. Viewport 1400,
    Container 800 — simuliert Sidebar-Abzug). Erwartung: Detail-Panel
    **nicht** sichtbar (Container ist <1200, auch wenn Viewport >1200).
    Sonst ist die schwerste Regressionsklasse testfrei.
- `test/main_screen_nav_test.dart` (erweitern falls vorhanden, sonst NEU):
  - Phone-Viewport (`width < 600`) zeigt Bottom-Nav.
  - Desktop-Viewport (`width >= 900`) zeigt `AppNavRail`.
  - Tab-Wechsel ändert den Body; „Mehr"-Sheet öffnet auf Phone.
  - **Feature-Gating-Test:** Free-Plan-`BillingProvider` → Rail-Destinations
    enthalten keinen `MainTab.inbox`-Eintrag (Security).
  - **Badge-Erhalt-Test:** `Key('mobile-nav-inbox-badge')` ist nach Rail-Umbau
    findbar.
  - **Keyboard-Tests:** Cmd/Ctrl+K-Shortcut wirkt nach dem Umbau weiter
    (Search-Dialog öffnet); Tab-Traversal erreicht Rail-Destinations;
    Pfeiltasten (Up/Down) wechseln innerhalb der Rail.
  - **Window-Resize-Live-Test:** Resize Phone-Viewport → Desktop-Viewport in
    einem Test (z.B. via `tester.binding.setSurfaceSize`) — aktive Tab-Auswahl
    überlebt den Switch.
- Master-Detail (T3.3): Widget-Test für `InventoryScreen` —
  - Desktop-Viewport (`constraints.maxWidth >= 1200`): Detail-Spalte sichtbar
    nach Item-Tap, Vollbild-Push wird **nicht** ausgelöst.
  - Phone-Viewport: Vollbild-Push (alter Pfad) wird ausgelöst.
  - 5-State-Matrix aus §5.5: empty / loading / error / no-permission / success
    je ein Test.
  - State-Erhalt bei TabBar-Wechsel (Stock ↔ Sold): Selektion im Detail
    bleibt erhalten oder wird sauber resettet (entscheidet T3.3a).
- Master-Detail (T3.4): analog für `WarehouseHubScreen` — Hub als Master,
  Sub-Bereich als Detail; State-Matrix; Reporting-Tile **nicht** im Test
  (ausgenommen).

### 6.2 Browser-Smoke / Audit-Szenarien

- Nach **jeder Epic** ein `/test-ui smoke-full-app-audit` (Pflicht laut
  CLAUDE.md bei UI-Änderungen) — Light+Dark × Phone(390×844)+Desktop(1440×900).
- Zusätzlich gezielt:
  - `smoke-theme` + `mobile-overflow` für `main_screen`, `dashboard`,
    `inventory`, `warehouse` (Hub + alle Sub-Routen).
  - Manuelle Viewport-Stichprobe an den 4 Referenzgrößen aus CLAUDE.md
    (360×640 / 390×844 / 768×1024 / 1440×900) — kein horizontaler Scroll,
    kein Overflow, Touch-Targets ≥48 dp.
  - **Grenz-Viewport-Audit nach Phase-B-Tasks**: gezielt 599/600, 799/800
    (heute Shell-Switch), 899/900 (neuer Shell-Switch), 1099/1100 (heute
    extended), 1199/1200 (neue Master-Detail-Schwelle). Layout-Switch
    sauber, kein Doppel-Nav, kein Flackern.
- `bash .claude/scripts/check-smoke-passed.sh` als Pre-Merge-Gate (UI-Pfad).

### 6.3 Regressionsschutz

- `deal-flow`, `goods-receipt-flow`, `stocktake-count-flow` müssen nach dem
  Master-Detail-Umbau weiter grün sein (diese Flows berühren genau die
  umgebauten Screens).

## 7. Risiken

1. **Phone-Regression durch Desktop-Arbeit.** Größtes Risiko. Master-Detail-
   und Rail-Umbauten dürfen den Phone-Pfad nicht anfassen. Mitigation: jeder
   Task hält den Phone-Zweig explizit unverändert; Audit nach jeder Epic auf
   Phone-Viewport zuerst.
2. **Breakpoint-Migration ist breit.** ~15 Dateien mit Magic Numbers. Risiko:
   subtile Layout-Verschiebungen, wo Schwellen wandern. **Mitigation: Phase A
   (indirekt, Wert identisch) und Phase B (bewusste Konsolidierung, Wert
   ändert sich) sind getrennte Tasks**. Phase A ist trivial reviewbar, Phase
   B bekommt Vorher/Nachher-Screenshots und explizite Verhaltens-Diff-Doku.
3. **Constraint-vs-Viewport-Verwechslung.** `deals_screen.dart:17` ist heute
   schon falsch (Viewport statt Container). Die Migration darf weitere Stellen
   nicht in die gleiche Falle laufen lassen. Mitigation: Zwei-Achsen-API in
   `responsive.dart` (§5.1) macht den Fehler strukturell unmöglich +
   dedizierter Widget-Test (§6.1).
4. **`NavigationRail`-Umbau berührt den Kern.** `main_screen.dart` ist der
   Navigations-Kern; Regressionen treffen die ganze App. Mitigation: Rail in
   eigenes `AppNavRail`-Widget kapseln, Tab-Index-Logik (`MainTab`-Enum) und
   `_navVisibility` unverändert lassen, eigener Mapping-Helper (§5.6),
   Widget-Tests inkl. Free-Plan-Gating.
5. **`NavigationRail`-Branding-Drift.** M3-Default-Farben ≠ heutige
   `AppTheme.nav*`-Tokens. Ohne explizites `NavigationRailTheme` würde die
   dunkle Branding-Sidebar zu einer hellen M3-Surface — sichtbarer
   Branding-Bruch. Mitigation: §5.7 Theme-Mapping ist Pflicht-Teil von T2.1.
6. **Warehouse-Hub-Detail-Umbau ändert das Routing-Modell.** Heute
   `Navigator.push`, künftig Shell-intern auf Desktop. Risiko: Zurück-Navigation,
   Deep-Links, FAB-Verhalten brechen. Mitigation: Phone behält Push;
   Desktop-Detail nur additiv; Hub-Sub-State sauber kapseln. **Reporting-Tile
   ausgenommen** (eigener Sub-Scaffold, nicht embeddable ohne weitere Arbeit).
7. **Scope-Creep Richtung IA-Redesign.** Die Inventory/Warehouse-Doppelung
   verleitet zum „mal eben mergen". Bewusst Out-of-Scope — sonst wird der Plan
   unkontrollierbar. Mitigation: striktes Scope-Gate im Council.
8. **Solo-Maintainer / Pre-Launch.** Begrenzte Review-Kapazität. Mitigation:
   Pausenpunkt nach **Epic 1 + Epic 3** (siehe „Reihenfolge / Pausenpunkte").
   Epic 2 (Rail-Umbau) ist A11y-Politur, kein Blocker für die Kernprobleme
   aus §0.3.
9. **`maxWidth`-Container können auf Tablet zu schmal wirken.** Mitigation:
   Werte im Council festklopfen, an Tablet-Viewport (768) testen.
10. **Master-Detail State-Verlust beim Resize.** Beim Wechsel Phone↔Desktop
    (Resize, Rotation) könnte Selektions-/Scroll-State verloren gehen.
    Mitigation: §5.5 State-Erhalt-Strategie (`PageStorageKey` +
    State-Owner über LayoutBuilder).
11. **Epics teilen Dateien.** Phase-B-Konsolidierung (T1.3b/T1.4b) berührt
    Files, die Epic 3 ebenfalls umbaut (`inventory_screen`, `dashboard_screen`,
    `settings/help/pricing`). Mitigation: explizite `depends:`-Kanten
    (siehe Task-Liste) — Epics sind **nicht** beliebig unabhängig mergebar.
    Registry-schreibende Tasks (`_page-registry.md`, Handbook) werden
    **seriell** gemerged.

## 8. Tasks

Atomar geschnitten, in 4 Epics. Jeder Task = 1 PR-fähiges Increment.
`agent:` / `model:` / `depends:` gemäß CLAUDE.md-Routing.

**Konvention Phase A / Phase B (siehe §2 Scope):**
- _Phase A_ = reine Indirektion. Magic Number → zentrale Konstante mit
  **identischem Wert**. Verhaltensneutral. Pixel-identischer Audit.
- _Phase B_ = bewusste Konsolidierung. Wert ändert sich, Verhaltens-Diff wird
  explizit dokumentiert + per Vorher/Nachher-Screenshot auditiert.

### Epic 1 — Zentrale Responsive-Infrastruktur

- [x] **T1.1** `lib/utils/responsive.dart` anlegen mit
  **Zwei-Achsen-API** (§5.1): `Breakpoints`-Konstanten,
  `ScreenSize`/`WidthClass`-Enums, Viewport-Helper (`screenSizeOf`,
  `isPhoneViewport`, `isDesktopViewport`), Container-Helper
  (`widthClassOf`, `isCompact`/`isMedium`/`isExpanded`/`isLarge` auf
  `double`). Dartdoc-Pflicht-Hinweis im File-Header (§5.1 Schlussabsatz).
  — `agent:flutter-coder` `model:Sonnet`
- [x] **T1.2** `test/responsive_test.dart` — beide Achsen + Grenzwerte +
  **Pflicht-Test gegen Constraint-vs-Viewport-Bug** (Widget-Test:
  Migrations-Ziel-Screen in schmalem `Expanded` bei breitem Viewport
  rendern, Detail-Panel darf nicht erscheinen). —
  `agent:flutter-coder` `model:Sonnet` `depends:T1.1`
- [x] **T1.3a** _Phase A_ — `main_screen.dart`: `narrow`/`extended`-Logik
  (Z. 321–322) durch `isPhoneViewport`/`isDesktopViewport` ersetzen,
  **identische Schwellen** (800/1100 als temporäre `_legacyShellNarrow`/
  `_legacyShellExtended`-Konstanten in `responsive.dart`). Pixel-identisches
  Verhalten. — `agent:flutter-coder` `model:Sonnet` `depends:T1.1`
- [ ] **T1.3b** _Phase B_ — `main_screen.dart`: Shell-Switch auf
  `Breakpoints.navRail` (900) und Rail-Extended auf
  `Breakpoints.railExtended` (1200) umstellen. **Verhaltensändernd**:
  Band 800–899 und Band 1100–1199 ändern ihr Layout. Vorher/Nachher-
  Screenshots an 760/820/900/1100/1180/1220-Viewports im PR. Legacy-
  Konstanten aus `responsive.dart` entfernen. —
  `agent:flutter-coder` `model:Opus` `depends:T1.3a,T1.7a`
- [x] **T1.4a** _Phase A_ — Breakpoint-Migration Cluster A (Listen-Screens):
  `inventory_screen.dart` (Z. 52), `deals_screen.dart` (Z. 17 — inkl.
  Bug-Fix `MediaQuery` → `LayoutBuilder.constraints.maxWidth`),
  `tickets_screen.dart` (Z. 167 + Z. 188), `deal_table.dart` (Z. 130).
  Magic Numbers → benannte Konstanten in `responsive.dart`, **Werte
  identisch**. — `agent:flutter-coder` `model:Sonnet` `depends:T1.1`
- [ ] **T1.4b** _Phase B_ — Cluster A konsolidieren: `deals_screen` +
  `tickets_screen` Detail-Schwelle 1100 → `Breakpoints.master` (1200).
  Verhaltens-Diff (Band 1100–1199 verliert Detail-Panel) im PR. —
  `agent:flutter-coder` `model:Opus` `depends:T1.4a,T1.7a`
- [x] **T1.5a** _Phase A_ — Breakpoint-Migration Cluster B (Dashboard +
  Settings + Auth): `dashboard_screen.dart` (Z. 60/116/254/337),
  `settings_screen.dart` (Z. 623/804/962), `onboarding_screen.dart`
  (Z. 187), `public_profile_screen.dart` (Z. 112/189). Magic Numbers →
  Konstanten, **Werte identisch**. `< 600` → `Breakpoints.phone`. —
  `agent:flutter-coder` `model:Sonnet` `depends:T1.1`
- [x] **T1.6a** _Phase A_ — Breakpoint-Migration Cluster C (Widgets):
  `statistics/*` (filter_bar, overview_tab, finance_tab,
  inventory_suppliers_tab, donut_chart), `add_edit_deal_dialog.dart` (Z. 383),
  `inbox_screen.dart` (Z. 1249), `tracking_status_block.dart` (Z. 601).
  Magic Numbers → Konstanten, **Werte identisch**. —
  `agent:flutter-coder` `model:Sonnet` `depends:T1.1`
- [ ] **T1.7a** Browser-Audit `smoke-full-app-audit` nach Phase-A-Cluster
  (Pixel-Identitäts-Check — keine Layout-Verschiebung erlaubt). —
  `agent:browser-tester` `model:Sonnet`
  `depends:T1.3a,T1.4a,T1.5a,T1.6a`
- [ ] **T1.7b** Browser-Audit `smoke-full-app-audit` nach Phase-B-Konsolidierung
  (gezielter Diff an Grenz-Viewports: 760/820/900/1100/1180/1220, Light+Dark
  × Phone+Desktop). — `agent:browser-tester` `model:Sonnet`
  `depends:T1.3b,T1.4b`

### Epic 2 — Desktop-Navigation (`NavigationRail`) — _A11y-Politur, optional_

> **Hinweis:** Epic 2 löst keines der §0.3-Kernprobleme direkt. Es ist
> A11y-/Wartbarkeits-Politur (M3-Standard statt Custom-Sidebar). Wenn
> Budget knapp wird, kann diese Epic auf einen reduzierten Task
> „A11y-Verbesserungen an bestehender `_Sidebar`" geschrumpft oder ganz
> verschoben werden. Der natürliche Pausenpunkt ist **nach Epic 1 + Epic
> 3** (siehe „Reihenfolge / Pausenpunkte").

- [ ] **T2.1** `lib/widgets/app_nav_rail.dart` (NEU): M3-`NavigationRail`-
  basiertes Desktop-Nav-Widget. Pflicht-Inhalte:
  - Mapping-Schicht (§5.6): `_railTabs(visibility)`,
    `_railSelectedIndex`, `_railOnTap`.
  - Visibility-Filter (§5.6) **vor** dem Aufbau der Destinations.
  - **Badge-Wrapping pro Destination** (§5.4) — `NavigationRail` macht
    das nicht von selbst. `Key('mobile-nav-inbox-badge')` muss überleben.
  - A11y-Anker: `Key('mainNavRail')`, `Key('navRailDestination-<tabname>')`
    (zusätzlich zum bestehenden `Key('main-tab-<name>')`),
    `Key('navRailCollapseToggle')`.
  - **`NavigationRailTheme`-Mapping** (§5.7) auf `AppTheme.nav*`-Tokens.
  — `agent:ui-builder` `model:Sonnet` `depends:T1.1`
- [ ] **T2.2** `main_screen.dart`: `_Sidebar`/`_NavItem` durch `AppNavRail`
  ersetzen. Branding-Header + Collapse/Expand erhalten. **Akzeptanzbedingung:**
  Mapping-Schicht aus §5.6 ist eingebaut (nicht `MainTab.index` direkt an
  `NavigationRail.selectedIndex`). — `agent:flutter-coder` `model:Opus`
  `depends:T2.1,T1.3b`
- [ ] **T2.3** (Optional, Council-Entscheid) Rail-Gruppierung: Items in
  „Vertrieb / Lager / System" gruppieren; neue l10n-Keys `navGroup*`,
  `navRailCollapse/Expand`. Visibility-Filter **vor** Gruppierung; leere
  Gruppen werden komplett ausgeblendet (kein leerer Gruppen-Header).
  **Konsistenz-Hinweis:** Halbe IA nur im Desktop-Nav wäre inkonsistent.
  Wenn T2.3 genommen wird, gehört das `_MoreNavSheet` (Phone) ebenso
  gruppiert — oder T2.3 wird in einen separaten IA-Folge-Plan
  verschoben. Council entscheidet. — `agent:ui-builder` `model:Sonnet`
  `depends:T2.2`
- [ ] **T2.4** `test/main_screen_nav_test.dart`: erweitern um
  - Phone → Bottom-Nav, Desktop → `AppNavRail`.
  - Tab-Wechsel ändert den Body; „Mehr"-Sheet öffnet auf Phone.
  - **Feature-Gating-Test (Security):** Free-Plan-`BillingProvider` →
    Rail-Destinations enthalten keinen `MainTab.inbox`.
  - **Badge-Erhalt-Test:** `Key('mobile-nav-inbox-badge')` findbar nach Umbau.
  - **Keyboard-Tests:** Cmd/Ctrl+K wirkt; Tab-Traversal erreicht Rail;
    Pfeiltasten Up/Down innerhalb der Rail.
  - **Window-Resize-Live-Test:** Phone→Desktop ohne Tab-Selektions-Verlust.
  — `agent:flutter-coder` `model:Sonnet` `depends:T2.2`
- [ ] **T2.5** `_page-registry.md` aktualisieren — Route `/main` mit den neuen
  A11y-Keys (`mainNavRail`, `navRailDestination-<tabname>`,
  `navRailCollapseToggle`) und der Notiz „Desktop-Nav ist M3
  `NavigationRail` (gekapselt in `AppNavRail`)". —
  `agent:flutter-coder` `model:Sonnet` `depends:T2.2`
- [ ] **T2.6** Browser-Audit `smoke-full-app-audit` nach Epic 2. Branding-
  Diff (M3-Indicator-Pill statt linker Strich) explizit dokumentieren. —
  `agent:browser-tester` `model:Sonnet` `depends:T2.2,T2.5`

### Epic 3 — Desktop-Raumnutzung (maxWidth + Master-Detail)

- [ ] **T3.1** `lib/widgets/app_screen_scaffold.dart` + `lib/widgets/empty_state.dart`
  (NEU, **verbindlich**): geteiltes Scaffold mit `maxWidth`-Content-Container,
  Header-/Search-/Empty-Slot. `EmptyState` als eigenständiges Widget mit
  l10n-Slots (übernimmt `dashboard`-`_EmptyStateCard`-Schnittstelle). —
  `agent:ui-builder` `model:Sonnet` `depends:T1.1`
- [ ] **T3.2** `dashboard_screen.dart`: `maxWidth`-Container (z.B. 1400), KPI-
  Grid auf großen Viewports begrenzen (keine ultrabreiten Karten). Nutzt die
  Container-Achse (`widthClassOf` aus `LayoutBuilder`) — keine `MediaQuery`. —
  `agent:ui-builder` `model:Sonnet` `depends:T1.5a`
- [ ] **T3.3a** **Selektions-State + embeddable `product_detail`**:
  - `InventoryScreen`-Selektions-State (`_selectedItemId`) auf Owner-Widget
    oberhalb des `LayoutBuilder`-Switches liften — überlebt Resize Phone↔Desktop.
  - `product_detail_screen.dart` so refaktorieren, dass es **embeddable** ist
    (kein eigener `Scaffold`/`AppBar`, wenn `embedded: true` übergeben wird —
    Pattern analog `SettingsScreen(embedded: true)`).
  - **TabBar-Frage geklärt:** Detail-Spalte lebt **über beiden TabBar-Tabs**
    (Stock/Sold) — eine geteilte Detail-Spalte, deren Inhalt vom aktiven Tab
    + Selektion abhängt. Wenn der User in Stock ein Item wählt und auf Sold
    wechselt, wird die Selektion zurückgesetzt (das ist ein anderer Item-Pool).
    Alternative „Detail pro Tab" wurde verworfen — verdoppelt State und ist
    UX-inkonsistent.
  - `PageStorageKey` auf der Master-Liste; Scroll- + Such-State bleibt.
  — `agent:flutter-coder` `model:Opus` `depends:T1.1,T1.4a`
- [ ] **T3.3b** **Master-Detail-Split-Layout `inventory_screen`**:
  - Desktop (`isExpanded(constraints.maxWidth)` bzw. `>= Breakpoints.master`):
    Liste links (z.B. 360px), Detail rechts (`Expanded`); Tap pusht **nicht**.
  - Phone: unverändert — Tap pusht Vollbild-`ProductDetailScreen`.
  - 5-State-Matrix (§5.5) implementiert mit Keys `Key('detailPane')`,
    `Key('detailPaneEmpty')`. — `agent:flutter-coder` `model:Opus`
  `depends:T3.3a`
- [ ] **T3.4** `warehouse_hub_screen.dart`: Desktop zeigt Hub als Master +
  Sub-Bereich als Detail-Spalte (kein Vollbild-Push); Phone behält Push.
  Sub-Screens (`purchase_orders`, `warehouses`, `categories`, `stocktake`,
  `product_catalog`) embeddable machen (Pattern wie T3.3a). **Reporting-Tile
  ausgenommen** — das aktuelle Hub-Reporting-Tile (Z. 111–125) wickelt
  `StatisticsScreen` in ein inline `Scaffold` mit `AppBar`; das embeddable
  zu machen ist eine eigene, größere Refaktor-Aufgabe und wird hier
  bewusst nicht angefasst. Auf Desktop bleibt das Reporting-Tile beim
  Vollbild-Push (klein dokumentierte Inkonsistenz, akzeptierter Trade-off).
  Falls Council das anders entscheidet → eigener Sub-Task „Reporting
  embeddable machen" anlegen. State-Matrix §5.5 gilt analog. —
  `agent:flutter-coder` `model:Opus` `depends:T1.1,T3.1`
- [ ] **T3.5** `settings_screen.dart`, `help_screen.dart`,
  `pricing_screen.dart`: `maxWidth`-Container auf Desktop via
  `AppScreenScaffold`. — `agent:ui-builder` `model:Sonnet`
  `depends:T3.1,T1.5a`
- [ ] **T3.6** `_page-registry.md` + `docs/handbook/03-screens-walkthrough.md`
  aktualisieren — `/inventory` und `/warehouse` mit Master-Detail-Pattern,
  neue A11y-Keys (`detailPane`, `detailPaneEmpty`). —
  `agent:flutter-coder` `model:Sonnet` `depends:T3.3b,T3.4`
- [ ] **T3.7** Browser-Audit `smoke-full-app-audit` nach Epic 3, plus
  gezielte Master-Detail-Prüfung an 768/1200/1440 + Regressions-Check
  `deal-flow` / `goods-receipt-flow` / `stocktake-count-flow`. —
  `agent:browser-tester` `model:Sonnet`
  `depends:T3.2,T3.3b,T3.4,T3.5,T3.6`

### Epic 4 — Konsistenz-Politur

- [ ] **T4.1** KPI-Karten-Dedupe: `lib/widgets/kpi_card.dart` vs.
  `lib/widgets/statistics/kpi_card.dart` zusammenführen oder klar abgrenzen
  (Doku-Kommentar wenn bewusst getrennt). — `agent:flutter-coder`
  `model:Sonnet`
- [ ] **T4.2** Bestehende Ad-hoc-Empty-States (`dashboard`-`_EmptyStateCard`,
  Empty-Renderings in `inventory`, `tickets`, `inbox` etc.) auf das
  `EmptyState`-Widget aus T3.1 migrieren. — `agent:ui-builder`
  `model:Sonnet` `depends:T3.1`
- [ ] **T4.3** Warenwirtschafts-Screens (`product_catalog`, `purchase_orders`,
  `warehouses`, `categories`, `stocktake`) auf `AppScreenScaffold`
  migrieren (Konsistenz mit Such-Bar/Header). — `agent:ui-builder`
  `model:Sonnet` `depends:T3.1,T3.4`
- [ ] **T4.4** `docs/handbook/05-architecture.md` aktualisieren —
  Responsive-Utility (Zwei-Achsen-API), `AppNavRail`, `AppScreenScaffold`,
  `EmptyState`, Master-Detail-Pattern erwähnen. _Hinweis: `_page-registry.md`
  wird in den Epics gepflegt, die die Screens ändern (T2.5 für Rail,
  T3.6 für Master-Detail) — nicht hier zentral._ —
  `agent:flutter-coder` `model:Sonnet` `depends:T2.5,T3.6`
- [ ] **T4.5** Abschluss-Audit `smoke-full-app-audit` (Light+Dark ×
  Phone+Desktop, alle Routen). — `agent:browser-tester` `model:Sonnet`
  `depends:T4.1,T4.2,T4.3,T4.4`

### Reihenfolge / Pausenpunkte

Epic 1 ist Voraussetzung für alles. **Epic 3 ist der eigentliche Wertbringer**
(Desktop-Raumnutzung, Master-Detail). **Epic 2 ist A11y-Politur** und kann
verschoben oder reduziert werden, ohne die §0.3-Kernprobleme zu verfehlen.
Epic 4 ist reine Konsistenz-Politur.

**Natürlicher Pausenpunkt: nach Epic 1 + Epic 3.** An diesem Punkt ist die
App in einem deutlich besseren Desktop-Zustand, hat einen zentralen
Breakpoint-Apparat, und hat keine kaputten Zwischenzustände.

**Abhängigkeits-Hinweise** (siehe `depends:`-Kanten):

- T1.3b/T1.4b (Phase B) brauchen T1.7a (Phase-A-Audit grün), weil sie
  Verhaltens-Diffs einführen, die nur auf grünem Phase-A-Fundament prüfbar
  sind.
- T2.2 hängt zusätzlich an T1.3b (`main_screen`-Datei wird in beiden
  geändert).
- T3.2 hängt an T1.5a, T3.3b hängt an T1.4a, T3.5 hängt an T1.5a — Epic 3
  ist **nicht** vollständig unabhängig von Epic 1.
- T4.4 hängt an T2.5 + T3.6 — Handbook-Updates kommen am Schluss, nicht
  parallel zu den Implementierungs-Tasks.
- Registry-schreibende Tasks (T2.5, T3.6, T4.4) werden **seriell** gemerged
  (gleiche Files: `_page-registry.md`, `docs/handbook/`).

---

## 9. Offene Entscheidungen für das Committee

1. **Rail-Gruppierung (T2.3):** Gruppierte Rail oder flache Liste? Wenn ja,
   muss das `_MoreNavSheet` (Phone) konsistent mitgruppiert werden — sonst
   in den IA-Folge-Plan schieben.
2. **Master-Detail-Umfang:** Inventory + Warehouse-Hub (Plan) reichen, oder
   auch Suppliers/PO-Listen mit? Empfehlung: erst die zwei, dann nachziehen.
3. **Reporting-Tile im Hub:** akzeptierte Inkonsistenz (bleibt Push) — oder
   Sub-Task „Reporting embeddable machen" zu T3.4 ergänzen?
4. **IA-Redesign (Inventory/Warehouse-Doppelung):** bewusst Out-of-Scope —
   Committee bestätigt, dass das ein eigener Folge-Plan wird.
5. **Reachability (AppBar oben rechts):** bewusst Out-of-Scope — eigener
   Folge-Plan, falls Stakeholder das priorisiert.

---

## 10. Committee-Review-Historie

### Phase-2-Review — 2026-05-23

5-Reviewer-Committee (Architekt, Pessimist/Bug-Hunter, External-Solutions-Scout,
Security, UX/Mobile) hat den Draft vom 2026-05-22 bewertet.

**Verdicts:**

| Reviewer | Verdict | Kernpunkt |
|---|---|---|
| Architekt | ⚠️ | `responsive.dart` brauchte zweite Achse (Viewport vs. Container); Phase-A/-B-Trennung fehlte; Wert-Diff-Tabelle fehlte. |
| Pessimist/Bug-Hunter | KRITISCH (9 Findings) | u.a. `deals_screen.dart:17`-Latent-Bug (MediaQuery statt Constraint), NavigationRail-Index-Mismatch ohne Mapping, Badge-Key-Verlust durch Rail-Umbau, Free-Plan-Inbox-Bypass-Risiko, falsche Tile-Zahl im Warehouse-Hub, Reporting-Tile-Sonderfall ignoriert, fehlende `depends:`-Kanten zwischen Epics, Master-Detail-State-Verlust beim Resize, fehlender Test gegen Constraint-vs-Viewport-Bug. |
| External-Solutions-Scout | EIGENBAU BESTÄTIGT | M3-`NavigationRail` ist der richtige Standard-Weg (kein externes Paket sinnvoll); M3-Window-Size-Classes als Referenz nennen; sonst kein Drittpaket nötig. |
| Security | warn | Visibility-Filter im Rail muss vor dem Aufbau der Destinations greifen — sonst Feature-Gating-Bypass für Paid-Inbox-Tab auf Free-Plan. Explizit als Pflicht-Test verlangt. |
| UX/Mobile | ⚠️ | Reachability-Befund war im Plan nur erwähnt, nicht aus dem Scope ausgeschlossen → bewusst Out-of-Scope listen. Branding-Drift durch M3-Default-Farben (`NavigationRailThemeData`) als Risiko aufnehmen. State-Erhalt über Breakpoint-Grenzen explizit machen. Keyboard-Nav-Tests einfordern. |

**Status:** Alle Pflicht-Findings (14) in die jeweiligen Sektionen eingearbeitet
(§5.1 Zwei-Achsen-API, §5.2 Migrations-Inventar/Wert-Diff-Tabelle, §5.4 A11y-Keys,
§5.5 State-Matrix, §5.6 NavRail-Mapping + Security-Filter, §5.7 Theme-Mapping,
§6.1 Constraint-vs-Viewport-Pflicht-Test, §7 Risiken erweitert, §8 Tasks
zweiphasig + `depends:`-Kanten ergänzt + Reporting-Tile ausgenommen). Empfohlene
Verbesserungen (Epic-2-Entschärfung, Pausenpunkt-Änderung, Reachability
Out-of-Scope, T2.3-Konsistenz-Hinweis, Registry-Pflege pro Epic, M3-Window-
Size-Classes-Referenz, State-Erhalt-Strategie, Keyboard-Tests) ebenfalls
übernommen.

**Header-Wechsel** `[DRAFT — Pending Committee Review]` → `[Committee-Approved 2026-05-23]`.
