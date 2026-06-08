# App-Umbau: Navigation & Informationsarchitektur (frontend-only, leicht umsetzbar)

**Datum:** 2026-06-05
**Author (Draft):** Opus (Design-Panel-Synthese: 2 Redesign-Ansätze + Pain-Point-Analyse + Flutter-Machbarkeit → Judge)
**Status:** Draft — bereit für `/council` (Tier 2) bzw. direkte Umsetzung (Tier 1)
**Original-User-Wunsch (DE, sinngemäß):**
> „Plane, wie die App umgebaut werden könnte — Navigation etc., professionell und gute Funktionalität. Alles was **leicht** umzusetzen ist. **Keine Schnittstellen-Anbindung** / kein Backend/API. **Nur direkt in der App** (Frontend/UI/UX)."

**Harte Scope-Filter (für jede Maßnahme):**
1. **Frontend-only** — keine Tabelle/RLS/Edge-Function/3rd-party-API/Provider-Logik.
2. **Niedriger Aufwand** — Flutter-nativ, bestehende Widgets/Pattern wiederverwenden, kein neues Nav-Package.
3. **Professionell + bessere Usability.**
4. **Mobile-First UND Desktop** sauber.

**Leit-Entscheidung:** IA-Gerüst von **Ansatz A** (4 konsolidierte Sektionen + EINE Sub-Nav-Konvention) + Phone-Slot-Belegung & Command-First-Beschleuniger von **Ansatz B** (4 Task-Slots + Cmd+K-Palette als Tiefen-Kompensator). **`MainTab`-Enum bleibt stabil** — wir ändern nur die Sichtbarkeits-/Gruppierungs-Arrays, nicht das Enum (reorder-robust, kein lautloser Runtime-Bruch).

---

## 0. Ist-Analyse — gravierendste Pain-Points (geerdet am Code)

| # | Befund | Schwere | Beleg |
|---|---|---|---|
| **A1** | **Inventory vs. Warehouse**: zwei parallele „Bestands"-Welten, gleiches Icon | **P0** | `main_screen.dart:51` + `warehouse_hub_screen.dart:124` |
| **B1** | **Settings = 8 fachfremde Tabs** in einer Scroll-TabBar (Käufer/Shops sind Verkaufs-Stammdaten, kein „Setting") | **P0** | `settings_screen.dart:49-104` |
| **E1** | **Warehouse-Hub auf Phone im „Mehr"-Sheet versteckt** (nicht in Bottom-Nav) — Mobile-First-Verstoß | **P1** | `main_screen.dart:209-215`, `:932-936` |
| **D2** | CSV-Import/Export nur Desktop; Logout Desktop-Header vs. Phone-Settings — echte Funktions-Divergenz | **P1** | `main_screen.dart:560-572` vs. `settings_screen.dart` |
| **A2/A3** | Statistics & PurchaseOrders je **doppelt** erreichbar, mit abweichendem Verhalten | **P1** | `warehouse_hub_screen.dart:196`, `dashboard_screen.dart:181` |
| **C1** | Tap-Verhalten (Push vs. Master-Detail-Split) hängt unsichtbar von Screen+Viewport ab | **P1** | `warehouse_hub_screen.dart:108-117`, `inventory_screen.dart:524` |
| **D1** | Keine Breadcrumbs; Bottom-Nav verliert aktiven Tab in gepushten Sub-Screens | **P1** | `_page-registry.md` (keine Pfad-UI) |
| **B2** | `isScrollable:true`-TabBar → Settings-Tabs wischen off-screen, schlecht auffindbar | **P1** | `settings_screen.dart` |
| **D3** | Zwei „Suchen" gleicher Optik, völlig verschiedener Scope (Nav-Filter vs. Daten-Suche) | **P1/P2** | `main_screen.dart:1045` vs. `global_search_dialog.dart:183` |
| **E3** | Desktop-Rail: 11 Tabs „passen knapp", `scrollable` als Notlösung | **P2** | `app_nav_rail.dart` |
| **A4** | Suppliers konzeptionell verwaist (Top-Level statt unter Procurement) | **P2** | — |
| **B3** | Doppelter, fast identischer TabBar-Code (embedded vs. non-embedded) → Drift-Risiko | **P3** | `settings_screen.dart:56-71` vs `:76-93` |
| **F2** | `MainTab.warehouse` als Anhängsel im Icon-/Label-Array (Code-Geruch) | **P3** | `main_screen.dart` |

**Kern-Diagnose:** zu viele heterogene Top-Level-Ziele (11), Doppelstrukturen (Inventory/Warehouse, Stats/Reporting, PO-Zweit-Einstieg), **drei rivalisierende Sub-Nav-Muster** (Settings-TabBar · Warehouse-Hub-Kacheln · „Mehr"-Sheet), Settings-Mega-Screen, fehlende Wegweiser.

---

## 1. Ziel-Navigation (final)

**Mentales Modell: 4 Arbeits-Domänen + Konto** — nach Tun strukturiert, als saubere Sektionen verortet.

| Sektion | Enthält (heutige MainTabs) | Phone | Desktop-Rail-Gruppe |
|---|---|---|---|
| **Dashboard** | dashboard | Slot 1 | ARBEITEN |
| **Verkauf** | deals · tickets · inbox | Slot 2 | ARBEITEN |
| **Lager** | inventory · warehouse-Hub (products, POs, warehouses, categories, stocktake) · suppliers | Slot 3 | ARBEITEN |
| **Auswertung** | statistics · activity | Slot 4 | ARBEITEN |
| **Konto** | settings · help · pricing · billing-profile · public-profile | Slot 5 (Drawer/Hub) | STAMMDATEN + KONTO |

### Phone-Bottom-Nav: 5 echte Ziele, KEINE „Mehr"-Resterampe
```
[ Dashboard ] [ Verkauf ] [ Lager ] [ Auswertung ] [ Konto ]
```
- Passt exakt in die M3-NavigationBar-5-Slot-Empfehlung (heute effektiv 6: 5 + „Mehr").
- **Warehouse-Hub bekommt einen festen Slot** (behebt E1 — heute im „Mehr" versteckt).
- **Inbox-Plan-Gating ohne Index-Shift-Bug:** Inbox wird **Sub-Tab der Verkauf-Sektion** (SegmentedButton). Bei Free-Plan verschwindet nur das Segment, die 5 Bottom-Slots bleiben stabil → die fragile `_bottomNavTabs`-`where`-Logik + `_bottomNavSelectedIndex`-Fallback (`main_screen.dart:216-225`) entfällt.

### Desktop-Rail (≥900px): in 3 Gruppen, kein `scrollable` mehr
```
ARBEITEN     Dashboard · Verkauf · Lager · Auswertung
STAMMDATEN   Lieferanten · Käufer · Shops      (Deep-Links in Sektions-Kontext)
KONTO        Einstellungen · Hilfe
```
- **Bei `NavigationRail` bleiben** + Section-Labels via `leading`/Divider zwischen Destination-Blöcken (additiver Array-Umbau; KEIN Drawer-Umstieg). 4 Arbeits-Destinations statt 11 → Rail scrollt nicht mehr (behebt E3).

---

## 2. EINE Sub-Nav-Konvention (statt heute drei)

**Entscheidung:** das bereits bewährte, getestete **Warehouse-Hub-Muster** (`warehouse_hub_screen.dart` — `_HubTile` + `_DesktopMasterDetail` + `selectOrPush`-Logik) wird als generisches **`SectionHubScreen`-Widget** extrahiert und ist die **einzige** Sub-Nav-Konvention für ALLE Sektionen:
- **Phone:** Hub-Kacheln-Liste → Tap pusht den Sub-Screen (Vollbild).
- **Desktop (≥1200px):** Master-Detail-Split (Kachel-Spalte links, embeddable Sub-Screen rechts).

Ersetzt die drei rivalisierenden Muster (Settings-TabBar, Warehouse-Kacheln, „Mehr"-Sheet) durch eine konsistente Mechanik. (C1 — Push-vs-Split bleibt viewport-abhängig, das ist Flutter-Adaptive-Standard und akzeptabel — wird aber **über alle Sektionen einheitlich**.)

---

## 3. Sektions- & Sub-Struktur

### Lager-Sektion — konsolidiert (behebt A1, A3, A4)
Auf Basis des heutigen `WarehouseHubScreen`, Kacheln (Default zuerst):
1. **Bestand** ← `InventoryScreen` (neue Default-Kachel; ist via `_selectedItemId`-Owner-Pattern schon Master-Detail-fähig, braucht nur `embedded:true`).
2. **Artikelstamm** ← `ProductCatalogScreen`. **Icon-Disambiguierung Pflicht** (beide nutzen heute `Icons.inventory_2_outlined`): Bestand `Icons.inventory_2`, Artikelstamm `Icons.qr_code_2`/`style_outlined`.
3. **Bestellungen** ← `PurchaseOrdersScreen`.
4. **Lieferanten** ← `SuppliersScreen` (heute Top-Level; braucht `embedded:true` — Muster existiert 5×). Behebt A4.
5. **Lager/Standorte** ← `WarehousesScreen`.
6. **Warengruppen** ← `CategoriesScreen`.
7. **Inventur** ← `StocktakeScreen`.

→ Eine Bestands-Welt (A1), Suppliers korrekt verortet (A4), Dashboard-PO-Deep-Link (`dashboard_screen.dart:181`) bleibt als Shortcut, zeigt aber Lager-Kontext via Breadcrumb (A3).

### Verkauf-Sektion
Deals/Tickets/Inbox als M3 **`SegmentedButton`** oben im Verkauf-Screen. Badge (`provider.trackingNeedsReviewCount`) wandert ans Inbox-Segment + aggregiert an den Verkauf-Bottom-Slot. Downgrade-Redirect (`main_screen.dart:345-350`) wandert in den Header. Mobile-Risiko: 3 Labels auf 360px → Icon-only-Segmente unter `isCompact`.

### Auswertung-Sektion (behebt A2)
Statistik (Default) + Aktivität, via Vollbild-Push (`StatisticsScreen` ist nicht embeddable — bewusst nicht umbauen). **Reporting-Kachel im Warehouse-Hub wird entfernt** → Deep-Link hierher (killt die A2-Doppelung ohne `StatisticsScreen` anzufassen).

### Konto-Sektion — Settings-Mega-Screen aufgeteilt (behebt B1, B2, B3)
`DefaultTabController(length:8)` + `isScrollable`-TabBar → **`SectionHubScreen`-Kacheln**. Die 8 `_XxxTab`-Widgets bleiben inhaltlich unverändert, wandern nur von `TabBarView`-Child zu Detail-Pane/Body:
- **Stammdaten** (Deep-Link-gespiegelt): Käufer, Shops — konzeptionell raus aus „Konto", CRUD-Code bleibt im Settings-Modul (low-effort). Behebt B1.
- **Konfiguration:** Postfach, Versand, Push.
- **Konto:** Team, Öffentliches Profil, Allgemein (Logout, Account-Löschen, Sprache).
- **+ Hilfe, Pricing, Billing-Profil** als weitere Kacheln.

→ Kein Off-Screen-Wischen mehr (B2), Doppel-TabBar-Code weg (B3). **Risiko:** `_XxxTab`-Widgets haben teils eigene Scaffolds/FABs → beim Umhängen auf Panes Scaffold-/FAB-Kollisionen prüfen.

### Verortungs-Tabelle
| Element | Heute | Ziel |
|---|---|---|
| Inventory (Bestand) | Top-Level-Tab | Lager → Kachel „Bestand" (Default) |
| Warehouse-Hub | Top-Level (im „Mehr") | = Lager-Sektion selbst |
| Suppliers | Top-Level-Tab | Lager → „Lieferanten" + Desktop-STAMMDATEN-Rail |
| Categories/Stocktake/POs/Warehouses | Warehouse-Kacheln | bleiben Lager-Kacheln (jetzt konsistent) |
| Statistics | Top-Level + Warehouse→Reporting | Auswertung → „Statistik" (eine Quelle) |
| Activity | Top-Level (im „Mehr") | Auswertung → „Aktivität" |
| Buyers/Shops | Settings-Tab 1+2 | Stammdaten-Kacheln (Deep-Link), CRUD bleibt im Settings-Modul |
| Settings (8 Tabs) | Mega-TabBar | Konto-Sektion, Hub-Kacheln |
| Help | Top-Level + AppBar-Icon + Mehr | Konto-Kachel + AppBar-Icon (Top-Level-Tab entfällt) |

---

## 4. Priorisierte Maßnahmen-Roadmap

**Reihenfolge:** Tier 1 liefert sofort Wert ohne IA-Risiko **und legt die Bausteine** (`SectionHubScreen`-Extraktion, Palette-Navigation), auf denen Tier 2 (die eigentliche Konsolidierung) low-risk aufsetzt.

### TIER 1 — Quick-Wins (S, additiv, risikoarm, sofort)
| # | Was | Files | Aufwand | Impact |
|---|---|---|---|---|
| [x] T1.1 | **Command-Palette → Navigations-/Aktions-Gruppe.** `_ResultGroup("Navigation")` listet alle Sektionen+Sub-Bereiche + Quick-Actions (Neuer Deal, Re-Parse, Export, Theme); springt via `selectTab`/Push. Auch bei leerem Query zeigen. | `global_search_dialog.dart` | S–M | Hoch (Tiefen-Kompensator; behebt D3) |
| [x] T1.2 | **Keyboard-Shortcuts** im bestehenden `CallbackShortcuts`: `Cmd+1..5`→Sektionen, `/`→Suche, `n`→kontextuelles Neu (über stabile Enums). | `main_screen.dart:~506` | S | Mittel (Desktop/Web), 0 Risiko |
| T1.3 | **Reporting-Doppelung killen** — Warehouse→Reporting-Kachel → Deep-Link in Auswertung. | `warehouse_hub_screen.dart:189-205` | S | Hoch (A2) |
| T1.4 | **`SectionHubScreen` extrahieren** (reines Refactor, kein Verhalten) — `_HubTile`/`_DesktopMasterDetail`/`_DetailPane` generalisieren. Enabler für Tier 2. | neu `lib/widgets/section_hub_screen.dart` | S–M | Hoch |
| T1.5 | **Settings-TabBar entdoppeln** (`:56-71` vs `:76-93` → eine Definition). | `settings_screen.dart` | S | Mittel (B3) |
| [x] T1.6 | **Breadcrumb-Zeile** im Desktop-`_ContentHeader` (`Lager › Bestellungen`, AppTheme-Tokens). | `main_screen.dart:522-582` | S | Mittel (D1) |
| [x] T1.7 | **CSV-Import/Export auch auf Phone** (heute nur Desktop) — via Command-Palette + Konto-Sheet. | `main_screen.dart`, `global_search_dialog.dart` | S | Mittel (D2-Parität) |
| [x] T1.8a | **Icon-Disambiguierung** Bestand (bleibt `inventory_2`) vs. Artikelstamm (parallel auf `qr_code_2` gesetzt). | `main_screen.dart:51`, `warehouse_hub_screen.dart:124` | S | Mittel (A1 visuell) |

### TIER 2 — Strukturelle Umbauten (M, die eigentliche IA-Konsolidierung)
| # | Was | Files | Aufwand | Impact |
|---|---|---|---|---|
| T2.1 | **Phone-Bottom-Nav 11→5 Slots** (Dashboard/Verkauf/Lager/Auswertung/Konto); `_bottomNavTabs`/`_navIcons`/`_navLabels` neu gruppieren, „Mehr"-Sheet → Konto. Inbox-Gating → Sub-Tab. | `main_screen.dart:46-72, 208-304` | M | **Sehr hoch** (E1/E2/F2/Mobile-First) |
| T2.2 | **Lager-Konsolidierung** — `InventoryScreen`+`SuppliersScreen` (`embedded:true`) als Hub-Kacheln; Top-Level-Tabs Inventory/Suppliers aus sichtbarer Nav (Enum + `_buildBody`-Cases bleiben als Deep-Link-Ziele). | `warehouse_hub_screen.dart`, `inventory_screen.dart`, `suppliers_screen.dart`, `main_screen.dart` | M | **Sehr hoch** (A1/A4) |
| T2.3 | **Verkauf-Sektion** mit `SegmentedButton` (Deals/Tickets/Inbox); Gating+Redirect+Badge in den Header. | `main_screen.dart`, Verkauf-Wrapper | M | Hoch |
| T2.4 | **Settings → Konto-Hub** (`SectionHubScreen`); 8 `_XxxTab` als Panes umhängen (Scaffold/FAB-Kollisionen prüfen!); Käufer/Shops als Stammdaten-Deep-Links. | `settings_screen.dart` (3851 LOC) | M–L | **Hoch** (B1/B2) |
| T2.5 | **Desktop-Rail gruppieren** (ARBEITEN/STAMMDATEN/KONTO via `leading`/Divider), `scrollable` entfernen. | `app_nav_rail.dart`, `main_screen.dart` | M | Hoch (E2/E3) |
| T2.6 | **Auswertung-Sektion** (Statistik+Activity, Vollbild-Push). | `main_screen.dart` | S–M | Mittel |
| T2.7 | **`_page-registry.md` + A11y-Keys + l10n DE/EN + `smoke-full-app-audit`** nachziehen (PFLICHT-Gate, sonst kein Merge). | `_page-registry.md`, `app_*.arb` | M | Pflicht |

### TIER 3 — Optional / größer (L, niedrigerer ROI)
- **T3.1** `StatisticsScreen` embeddable machen → Auswertung als Master-Detail (statt Push). *(M–L)*
- **T3.2** `AdaptiveNavScaffold` extrahieren (Shell-Switch kapseln, Index-Logik entfernen). *(M)*
- **T3.3** `AppScreenScaffold` als Single-Source Phone-AppBar + Desktop-Header. *(M)*
- **T3.4** `SliverAppBar` (collapse-on-scroll) für lange Listen. *(S–M)*
- **T3.5** Hero/`AnimatedSwitcher` für Master-Detail-Transitions. *(S; Vorsicht Desktop-Regression)*
- **T3.6** Sektions-Default-Memory (zuletzt geöffnete Kachel pro Sektion). *(S)*
- **T3.7** Speed-Dial-FAB / BottomSheet-Quick-Actions pro Sektion. *(S)*

---

## 5. Was bewusst NICHT (Scope-Grenzen)
- **Kein neues Nav-Package.** `flutter_adaptive_scaffold` ist offiziell **discontinued** (Issue #162965). Die App hat mit `lib/utils/responsive.dart` (Zwei-Achsen-API) bereits die framework-konforme Lösung → erweitern, nicht ersetzen.
- **Keine Backend-/Schema-/Provider-/Edge-/API-Änderung.** Alles oben ist reine Frontend-Re-Verdrahtung (Nav-Arrays, Widget-Wrapping, l10n).
- **Kein `MainTab`-Enum-Refactor** — stabiler State-Schlüssel; nur Sichtbarkeits-/Gruppierungs-Arrays ändern sich.
- **`StatisticsScreen` embeddable = Tier 3**, nicht Pflicht (Vollbild-Push akzeptabel).
- **Kein Settings-Rewrite** — die 3851 LOC werden **umgehängt** (Container TabBarView → Hub-Panes), Tab-Inhalts-Logik unverändert.
- **C1 (Push-vs-Split viewport-abhängig)** wird vereinheitlicht, nicht „gelöst" (Flutter-Adaptive-Standard).
- **Kein Drawer statt Rail** auf Desktop (Rail-Gruppierung via `leading`/Divider reicht).

---

## 6. Umsetzungs-Empfehlung & Pflicht-Gate
- **Tier 1 separat shippen** (additiv, risikoarm — je eigener kleiner PR, `flutter test` + `dart analyze` reichen, kein IA-Risiko).
- **Tier 2 als eigener Plan durch `/council`** (UX/Mobile + Pessimist/Bug-Hunter Pflicht), weil sichtbare Nav-Struktur + A11y-Keys geändert werden.
- **Pflicht vor Tier-2-Merge (CLAUDE.md):** `smoke-full-app-audit` grün, `_page-registry.md` synchron (`main-tab-<name>`, `navRailDestination-<name>`, neue Sub-Nav-Keys), DE/EN-ARBs via `/check-l10n`.

## 7. Anhang
- **Ansatz A** (gewählt als IA-Gerüst): 4 konsolidierte Sektionen + EINE Sub-Nav-Konvention (Hub+Master-Detail).
- **Ansatz B** (gewählt für Phone-Slots + Command-First): Task-orientiert, Cmd+K-Palette als Beschleuniger, Bottom-Nav nur Kern-Tasks.
- **Quellen:** Flutter M3 NavigationBar/Rail/Drawer, `responsive.dart` (vorhanden), `warehouse_hub_screen.dart` Master-Detail-Pattern (vorhanden), `global_search_dialog.dart` (vorhanden).

**Relevante Dateien:** `main_screen.dart`, `main_tab.dart`, `app_nav_rail.dart`, `warehouse_hub_screen.dart`, `inventory_screen.dart`, `suppliers_screen.dart`, `settings_screen.dart`, `statistics_screen.dart`, `dashboard_screen.dart`, `global_search_dialog.dart`, `utils/responsive.dart`, `.claude/agents/_page-registry.md`, `lib/l10n/app_de.arb`+`app_en.arb`.
