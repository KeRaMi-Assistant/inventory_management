# UX Quickwins Audit — Pre-Launch Polish Sweep

> **[Committee-Approved 2026-05-16]**
>
> Erstellt: 2026-05-16
> Slug: `ux-quickwins-audit`
> Status: Approved — Council-Verdict ÜBERARBEITUNG umgesetzt (7 Pflicht-Änderungen + 6 Verbesserungen eingearbeitet).
>
> Methodik: Audit der wichtigsten User-sichtbaren Screens (Page-Registry
> als Checkliste) auf Friction-Points, Empty-State-Lücken, Discoverability-
> Probleme und Mobile-Phone-Reibung. Jeder Task ist als einzelner PR
> mergebar, max. 4h Implementation, mit klarem UX-Gewinn pro Stunde.
> Keine Architektur-Refactors, keine neuen Carrier, keine DB-Schema-
> Erweiterungen über das Nötigste hinaus.

## Ziel

Eine fokussierte Sammlung kleiner, sichtbarer UX-Verbesserungen
liefern, die das Pre-Launch-Polish-Niveau der App auf Phone (390×844)
spürbar anheben — ohne Architektur-Risiko, ohne Datenmodell-Brüche, in
einer einzigen Sprint-Welle ausrollbar.

## Betroffener Scope

**Touch-Files (lib):**
- `lib/screens/main_tab.dart` — **[NEW]** `enum MainTab` (Pflicht-Pre-Refactor für #00 → #01)
- `lib/screens/main_screen.dart` — Bottom-Nav-Switch, FAB, Help-Quick-Link, Enum-Migration
- `lib/screens/inbox_screen.dart` — Suggestion-Card Long-Press, Header-Compaction
- `lib/screens/inventory_screen.dart` — Sort/Filter, Empty-State, Low-Stock-Quick-Filter
- `lib/screens/statistics_screen.dart` — Phone-Charts (Filterbar-Sticky)
- `lib/screens/settings_screen.dart` — Tab-Discoverability auf Phone (Scroll-Indicator)
- `lib/screens/dashboard_screen.dart` — Skeleton/Loading-State statt Spinner
- `lib/screens/help_screen.dart` — kontextuelle Help-Sprünge
- `lib/screens/onboarding_screen.dart` — Skip-Konsistenz prüfen
- `lib/widgets/deal_card.dart` — Long-Press → Quick-Status-Sheet + Checkbox-Surface-Extraction
- `lib/widgets/deal_table.dart` — Inline-Status-Cycle-Action
- `lib/widgets/add_edit_deal_dialog.dart` (read-only Referenz)
- `lib/widgets/global_search_dialog.dart` — Recent-Searches-Persistenz + Enum-Indizes
- `lib/widgets/tracking_status_block.dart` — Retrack-Button-Cooldown-Tooltip
- `lib/widgets/inbox_message_details.dart` — Snackbar nach Accept

**Touch-Files (l10n):**
- `lib/l10n/app_de.arb` — neue Keys (Liste je Task, alle mit `[NEW]`-Marker im Task-Block)
- `lib/l10n/app_en.arb` — Mirror

**Touch-Files (tests):**
- `test/widgets/deal_card_quick_status_test.dart` **[NEW]**
- `test/widgets/inbox_suggestion_long_press_test.dart` **[NEW]**
- `test/screens/inventory_sort_test.dart` **[NEW]**
- `test/screens/main_tab_enum_test.dart` **[NEW]** (Enum-Migration für #00)
- `test/widgets/recent_searches_pii_filter_test.dart` **[NEW]** (PII-Filter für #11)
- `test/widgets/empty_state_role_gate_test.dart` **[NEW]** (Role-Gate für #10)

**Touch-Files (providers):**
- `lib/providers/inventory_provider.dart` — Sort-Mode-State, `isReloading`-Flag für Skeleton-Mitigation
- `lib/providers/app_preferences_provider.dart` — Last-Sort-Persistenz, Recent-Searches (mit PII-Filter)
- `lib/providers/auth_provider.dart` — `signOut()`-Clear für Recent-Searches
- `lib/providers/active_workspace_provider.dart` (read-only) — Role-Gate-Konsumer

**Touch-Files (docs/registry):**
- `.claude/agents/_page-registry.md` — Sub-Routes-Tabelle (Quick-Status-Sheet, More-Nav-Sheet, Sort-Pill-Sheet, Inbox-Suggestion-Sheet), Top-Level-Notizen (Bottom-Nav-Reihenfolge), Pflicht-Test-Spalte (`mobile-overflow` Pflicht).

## Datenmodell

**Keine** neuen Tabellen, keine Migrations.

Optional persistierte UI-Prefs (Sort-Mode, Recent-Searches) gehen
ausschließlich in `shared_preferences` lokal — kein DB-Schema-Touch,
keine RLS-Diskussion nötig.

**Workspace-Role-Gate (#10):** read-only Konsum von
`ActiveWorkspaceProvider.role` (existiert bereits, `lib/services/workspace_service.dart:63-106`). Keine neuen Felder.

**RLS-Policies:** keine Änderungen.

## API / Edge Functions

**Keine** neuen Edge Functions. Keine Änderung am `tracking-poll`,
`mail-poll`, oder anderen bestehenden Functions.

Eventuell genutzt (read-only): bestehender `tracking-poll` für den
Retrack-Cooldown-Indicator — nur UI-Polish, kein Backend-Touch.

## UI-Änderungen

Detail pro Task siehe `Tasks`-Sektion. Übergreifende Prinzipien:

- **Mobile-First:** jeder Task wird auf 360×640 + 390×844 verifiziert,
  bevor PR gemerged wird (Pflicht-Smoke `mobile-overflow`).
- **Theme-Compliance:** ausschließlich `AppTheme.*`-Tokens, kein
  `Colors.blue` o.ä. Bei jedem Task `smoke-theme` Pflicht (Light +
  Dark).
- **l10n-Pflicht:** jeder neue UI-Text geht in `app_de.arb` UND
  `app_en.arb` — der `l10n-checker`-Hook blockiert sonst den Ship.
  Alle neuen Keys mit `[NEW]`-Marker im Task-Block aufgelistet.
- **Touch-Targets ≥ 48 dp.**
- **Keine Hover-Only-Logik** — alle neuen Quick-Actions per Long-Press
  oder explizitem Icon erreichbar.
- **Accessibility-Keys:** jedes neue interaktive Widget bekommt einen
  stabilen `Key('...')` (Liste pro Task) — Browser-Tester nutzt
  ausschließlich diese Anker.
- **AppBar-Action-Overflow:** auf 360×640 max. 2 Direkt-Actions;
  ab 3 (z. B. InvitesBell + Search + Help) → `PopupMenuButton`-Overflow.
- **PII-Linie:** Keine User-Daten (Tracking-Nr, Deal-IDs, Käufer-
  E-Mails, Suchstrings, Inventory-Item-Namen) in `print`/`debugPrint`/
  `console` — nur in UI rendern, nie loggen. Gilt für jeden neuen
  Code-Pfad in diesem Plan.
- **State-Matrix:** state-modifizierende Tasks dokumentieren ihre
  Zustands-Matrix (empty / loading / error / offline / success) mit
  ARB-Key + Verhalten pro Zustand (siehe Task-Body).

## Tests

Pro Task:
- 1 Widget-Test (wo state-modifizierend), 1 Golden für reine
  Cosmetic-Tasks darf entfallen.
- `smoke-theme` + `mobile-overflow` (browser-tester) als Pflicht-Audit
  vor Ship.
- Für UI-Pfade: `smoke-full-app-audit`-Pass (< 24h alt) als Pre-Merge-
  Gate (Bug-Fix C aus CLAUDE.md).

Coverage-Ziel:
- Neue Widget-Tests bringen `lib/widgets/deal_card.dart` und
  `lib/screens/inventory_screen.dart` jeweils auf mind. 1 Test pro
  neuem Quick-Action-Pfad.
- Enum-Migration #00 hat eigenen Test, der jeden alten
  `_selectedIndex == N`-Pfad gegen das Enum spiegelt.

## Risiken

1. **Long-Press-Konflikte mit Auswahl/Drag** — Long-Press wird heute
   z.T. für `Checkbox.toggleSelected` genutzt (Inventory, Deals).
   **Mitigation (Task #02):** Pre-Step Refactor in `deal_card.dart:69-94`:
   Checkbox aus dem äußeren `InkWell` extrahieren in eigenes
   `GestureDetector(behavior: HitTestBehavior.opaque, …)`.
   Long-Press auf Checkbox-Area = kein Sheet. Wenn
   `filters.selectedDealIds.isNotEmpty` → Long-Press = `toggleSelected`
   (Bulk-Select-Modus). Sonst → Quick-Status-Sheet.

2. **Bottom-Nav-Umbau verschiebt FAB** — `Scaffold.
   floatingActionButtonLocation: endFloat` explizit (kein centerDocked
   wegen Inbox-Slot-Filtering bei `!hasInbox`). FAB-Sonderlogik
   und `_openTicket`-Deep-Link bleiben funktional.
   **Mitigation:** Indices nicht hardcoden — `enum MainTab` (Task #00)
   als Single-Source. Inbox-Slot wird bei `!hasInbox` aus der Liste
   gefiltert (keine Index-Shift-Bugs mehr).

3. **Help-Discoverability vs. Drawer-Hierarchie** — Help-Icon im AppBar
   plus „Mehr"-Sheet-Eintrag = zwei Pfade. **Pflicht-Reihenfolge:**
   #05 (Help-Icon im AppBar) MUSS vor #01 (Bottom-Nav-Umbau) gemerged
   sein, damit First-Run-User Help nicht 3 Taps tief in „Mehr" sucht.

4. **Sort-Persistenz via SharedPrefs** kann bei Schema-Drift zu
   „unbekanntem Sort-Key" führen. **Mitigation:** enum-basiert, mit
   `fallback: default` wenn Key unbekannt.

5. **Skeleton-Loader Race-Condition (Bug-Hunter-Finding):**
   `InventoryProvider.isLoading` ist `true` auch bei Re-Loads mit
   existierenden Daten — Skeleton würde dann die echten Daten
   verdecken. **Mitigation (Task #06):** Skeleton nur zeigen wenn
   `isLoading && deals.isEmpty` (no-data-state). Bei Re-Load mit
   Daten: bestehende Liste rendern, optional kleines Refresh-Spinner-
   Icon in der AppBar.

6. **Quick-Status-Sheet Race / Optimistic-Lock:** Sheet schreibt direkt
   via `InventoryProvider.updateDeal()`. Wenn parallel ein anderer
   Tab (Browser, anderes Device) schreibt → Stale-Update.
   **Mitigation (Task #02):** Optimistic-Update + Try/Catch + Snackbar-
   on-Error. **Follow-Up (out-of-scope):** `deal.updated_at`-Vergleich
   in eigenem Task, weil das einen Backend-RPC braucht.

7. **Inbox-Header-Compaction** kann wichtige Status-Hinweise verstecken.
   **Mitigation:** Compaction nur auf Phone, ExpansionTile für Details.

8. **Merge-Konflikt zwischen #04 und #10:** beide editieren
   `inventory_screen.dart`. **Pflicht-Reihenfolge:** `#04 → #10`.

9. **PII-Leak in Recent-Searches (Security medium):** User tippt
   E-Mails, Tracking-Codes, Phone-Nummern in den Search → landen
   in SharedPrefs (kein Encryption-at-Rest auf Android pre-API-23,
   Web `localStorage` per se nicht encrypted). **Mitigation
   (Task #11):** Pre-Write Regex-Filter (`@`, `\d{8,}`,
   `^[A-Z0-9]{10,}$` → skip). `AuthProvider.signOut()` cleared
   Recent-Searches.

10. **Empty-State-CTA ohne Role-Check (Security medium):** Viewer-
    Workspace-User sieht „Ersten Deal anlegen", drückt, bekommt RLS-
    Reject → schlechte UX + Verwirrung. **Mitigation (Task #10):**
    `ActiveWorkspaceProvider.role` Pre-Check, CTA hidden oder mit
    Tooltip für Viewer.

11. **Bottom-Nav-Indizes hard-coded brechen lautlos (Bug-Hunter):**
    `GlobalSearchDialog`, `_inboxNavIndex`, `_openTicket` und alle
    `_selectedIndex == N`-Vergleiche referenzieren heute Magic-Numbers.
    **Mitigation (Task #00, NEU):** Pre-Refactor auf `enum MainTab`
    bevor #01 gemerged wird. Andernfalls: Compile-OK, Runtime-Sprung
    in falschen Tab.

12. **`skeletonizer`-Package-Add (External-Solution):** neuer
    pubspec.yaml-Entry. **Mitigation:** ^2.1.3 ist MIT, ~30-60 KB
    Bundle, stabile API seit 1.0. `PaintingEffect.solid` = keine
    Shimmer-Animation (statische Boxen).

## Tasks

> Jeder Task ist **atomic** (= 1 PR-fähiges Increment), hat einen
> klaren UX-Gewinn pro Stunde, hat einen `agent:<name>`-Tag, und ist
> auf Phone (390×844) testbar. Task-Dependency-Graph siehe Sektion
> unter den Tasks.

---

### [ ] Task 00 [NEW] — Pre-Refactor: `enum MainTab` einführen

- **Was:** Neue Datei `lib/screens/main_tab.dart` mit
  ```dart
  enum MainTab {
    dashboard, deals, tickets, inbox, inventory,
    suppliers, stats, activity, settings, help,
  }
  ```
  Alle `_selectedIndex == N`-Vergleiche, `GlobalSearchDialog`-Indices,
  `_inboxNavIndex`, `_openTicket`-Deep-Link auf das Enum umstellen.
  Aktuell stehen Magic-Numbers in `main_screen.dart:38-65`,
  `global_search_dialog.dart`, `inbox_screen.dart` und mehr.
- **Warum (Pflicht):** ohne Enum-Migration bricht jede
  Bottom-Nav-Reorder lautlos zur Runtime — Compile bleibt grün,
  aber Navigation springt in falschen Tab. Bug-Hunter im Council hat
  6 hard-coded Indizes ausserhalb von `main_screen.dart` gefunden.
- **Touch-Points:**
  - `lib/screens/main_tab.dart` **[NEW]**
  - `lib/screens/main_screen.dart` — `_selectedIndex` Typ `int → MainTab`,
    `_navIcons`/`_navLabels` als `Map<MainTab, ...>`
  - `lib/widgets/global_search_dialog.dart` — Index-Sprünge auf Enum
  - `lib/screens/inbox_screen.dart` — `_inboxNavIndex` → `MainTab.inbox`
  - Browser-Tester: stabile `Key('main-tab-dashboard')`,
    `Key('main-tab-deals')`, `Key('main-tab-tickets')`,
    `Key('main-tab-inbox')`, `Key('main-tab-inventory')`,
    `Key('main-tab-more')` an die Nav-Items.
- **ARB-Keys:** keine.
- **Accessibility-Keys:** `Key('main-tab-<name>')` pro Enum-Wert.
- **Tests:** `test/screens/main_tab_enum_test.dart` — jeder Enum-Wert
  hat erwartete Icon + Label + Screen-Mapping; Round-Trip Old-Index
  → Enum → New-Index für die 5 neuen Bottom-Nav-Plätze.
- **State-Matrix:** N/A (Refactor, kein neuer State).
- **agent:** flutter-coder
- **Aufwand:** 3h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` unverändert (Refactor, keine Sub-Routes)
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert (390×844 + 360×640)

---

### [ ] Task 01 — Bottom-Nav statt Drawer auf Phone (RE-DESIGNED)

- **Pre-Requirement:** Task #00 (Enum) UND Task #05 (Help-AppBar-Icon)
  müssen vor diesem Task gemerged sein.
- **Was:** `MainScreen` baut auf Phone (`width < 600`) eine echte
  `NavigationBar` mit **5 Top-Level-Tabs in dieser Reihenfolge**:
  **Dashboard, Deals, Tickets, Inbox, Inventory**. Die übrigen 5
  (Suppliers, Stats, Activity, Settings, Help) wandern in einen
  „Mehr"-Bottom-Sheet (`Key('moreNavSheet')`), erreichbar über einen
  6. Slot mit `more_horiz`-Icon.
  - **Tickets bleibt in der Bottom-Nav (Position 3):** FAB-Sonderlogik
    und `_openTicket`-Deep-Link bleiben funktional.
  - `floatingActionButtonLocation: endFloat` explizit (kein
    centerDocked).
  - Inbox-Visibility-Gating (`hasInbox`): Inbox-Slot bei `!hasInbox`
    aus Liste filtern, Indizes via Enum → kein Index-Shift-Bug.
- **Warum es UX verbessert:** aktuell ist die Top-Level-Navigation
  hinter einem Hamburger-Drawer versteckt — Standard-Phone-Nutzer
  erwarten Bottom-Nav (iOS HIG + Material 3).
- **Touch-Points:**
  - `lib/screens/main_screen.dart` — Phone-Scaffold-Branch
    (Zeile 233-261), `_MobileNavList` (Zeile 907-1035) wandert ins
    `_MoreNavSheet`-Widget
  - `.claude/agents/_page-registry.md` — Top-Level-Tabelle: Reihenfolge
    Dashboard/Deals/Tickets/Inbox/Inventory dokumentieren; Sub-Routes-
    Tabelle: neuer Eintrag „More Sheet" mit Pflicht-Tests
    `smoke-theme, mobile-overflow`.
- **ARB-Keys:**
  - `[NEW] navMore` („Mehr" / „More")
  - `[NEW] navMoreSheetTitle` („Weitere Bereiche" / „More sections")
- **Accessibility-Keys:** `Key('main-tab-more')`, `Key('moreNavSheet')`,
  `Key('moreNavSheet-suppliers')` etc.
- **State-Matrix:** keine (Navigation pur).
- **agent:** ui-builder
- **Aufwand:** 5h (Re-Design auf 5 Tabs + More-Sheet + Inbox-Gate +
  FAB-Placement-Test über 4 Viewports)
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean (DE+EN)
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` aktualisiert (Top-Level + More-Sheet
    Sub-Route)
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert (390×844 + 360×640)
  - [ ] `smoke-full-app-audit` < 24h grün (UI-Pflicht)

---

### [ ] Task 02 — DealCard Long-Press → Quick-Status-Sheet (RE-DESIGNED)

- **Was:** Long-Press auf eine `DealCard` öffnet ein
  `showModalBottomSheet` (`Key('quickStatusSheet')`) mit 5 Status-
  Optionen. Tap auf Option ruft `InventoryProvider.updateDeal()`
  **optimistisch** auf, zeigt Snackbar mit Undo (5s).
- **Pre-Step Pflicht-Refactor (`deal_card.dart:69-94`):**
  Checkbox aus dem äußeren `InkWell` extrahieren in eigenes
  `GestureDetector(behavior: HitTestBehavior.opaque, onTap: …)`.
  Long-Press auf Checkbox-Area = kein Sheet.
- **Mode-Logic:**
  - `filters.selectedDealIds.isNotEmpty` → Long-Press = `toggleSelected`
    (Bulk-Select erweitern).
  - Sonst → Quick-Status-Sheet öffnen.
- **SafeArea** am Sheet-Bottom (Home-Indicator).
- **Optimistic-Update + Try/Catch + Snackbar-on-Error:** Bei
  Update-Failure rollback im UI, Snackbar mit Fehlertext und Retry.
- **Out-of-scope (Follow-Up-Task notieren):** Optimistic-Lock-Check
  via `deal.updated_at`-Vergleich (braucht RPC).
- **Warum es UX verbessert:** 80% der Status-Updates sind 1-Klick-
  Wechsel — voller `AddEditDealDialog` ist Overkill.
- **Touch-Points:**
  - `lib/widgets/deal_card.dart` — Zeile 69-94 Checkbox-Extraction
    + neuer `_QuickStatusSheet`
  - `lib/utils/status_l10n.dart` — Status-Labels
  - `.claude/agents/_page-registry.md` — Sub-Routes-Tabelle: neuer
    Eintrag „Quick-Status-Sheet (DealCard Long-Press)".
- **ARB-Keys:**
  - `[NEW] dealQuickStatusTitle` („Status ändern" / „Change status")
  - `[NEW] dealQuickStatusUndo` („Rückgängig" / „Undo")
  - `[NEW] dealQuickStatusChanged` („Status auf {status} geändert" /
    „Status changed to {status}") mit Platzhalter `{status}`
  - `[NEW] dealQuickStatusError` („Status konnte nicht geändert werden:
    {error}" / „Could not change status: {error}")
- **Accessibility-Keys:** `Key('quickStatusSheet')`,
  `Key('dealCardCheckbox-${deal.id}')`,
  `Key('quickStatusOption-${status.name}')`.
- **State-Matrix:**
  - empty (kein selektierter Deal): N/A — Sheet öffnet nur auf
    Long-Press eines konkreten Cards.
  - loading: Sheet zeigt `CircularProgressIndicator` während Update.
  - error: Snackbar `dealQuickStatusError` + Rollback.
  - offline: Snackbar mit Hinweis „Offline — wird nachgeholt".
  - success: Snackbar `dealQuickStatusChanged` + Undo-Action.
- **Tests:** `test/widgets/deal_card_quick_status_test.dart` —
  Long-Press im selected-Modus toggelt Bulk; Long-Press im normalen
  Modus öffnet Sheet; Tap auf Status ruft Provider.updateDeal mit
  korrektem Status; Error rolled back.
- **agent:** ui-builder
- **Aufwand:** 3h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün (inkl. neuem Test)
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Sub-Routes-Tabelle erweitert
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert (390×844 + 360×640)

---

### [ ] Task 03 — Inbox-Suggestion-Card: 3-Aktionen-Layout statt 2

- **Was:** Suggestion-Card im Inbox-Screen bekommt eine sichtbare
  Drei-Action-Reihe (Verwerfen, Bearbeiten, Als Deal übernehmen).
  Long-Press → identisches Bottom-Sheet (Discoverability).
- **Long-Press-Konsistenz (Pflicht):** Long-Press öffnet IMMER das
  Sheet mit allen 3 Aktionen, nie direkten Accept ohne Dialog —
  Konsistenz mit Task #02 Pattern.
- **Warum es UX verbessert:** „Bearbeiten vor Übernehmen" ist heute
  versteckt.
- **Touch-Points:**
  - `lib/screens/inbox_screen.dart` — `_SuggestionsTab`-Card
  - `.claude/agents/_page-registry.md` — Sub-Routes-Tabelle: neuer
    Eintrag „Inbox Suggestion Sheet (Long-Press)".
- **ARB-Keys:**
  - `[NEW] inboxSuggestionEdit` („Vor Übernahme bearbeiten" / „Edit
    before accepting")
  - `inboxSuggestionAccept` (existiert)
  - `inboxSuggestionDismiss` (existiert)
- **Accessibility-Keys:** `Key('inboxSuggestionSheet')`,
  `Key('inboxSuggestion-edit-${id}')`,
  `Key('inboxSuggestion-accept-${id}')`,
  `Key('inboxSuggestion-dismiss-${id}')`.
- **Tests:** `test/widgets/inbox_suggestion_long_press_test.dart` —
  Long-Press öffnet Sheet, alle 3 Buttons vorhanden, kein
  Direkt-Accept-Pfad.
- **State-Matrix:** loading (Accept in flight) → Card disabled;
  error → Snackbar; success → Card entfernt + Snackbar (siehe #12).
- **agent:** ui-builder
- **Aufwand:** 2.5h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Sub-Routes-Tabelle erweitert
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert

---

### [ ] Task 04 — Inventory: Sort-Dropdown (Stock, Name, Wert, kritisch zuerst)

- **Was:** Sort-Pill („Sortieren: {sortMode} ▾",
  `Key('inventorySortPill')`) über der Suchleiste öffnet Sheet mit
  4 Optionen. Default: „Kritisch zuerst" wenn `criticalStockCount > 0`,
  sonst „Name (A→Z)". Persistiert via `SharedPreferences`.
- **Pre-Requirement für #10:** dieser Task bestimmt das Layout der
  Empty-State-Position — #04 zuerst, dann #10.
- **Warum es UX verbessert:** Inventory-Liste ist fix sortiert; User
  scrollt blind bei > 20 Items.
- **Touch-Points:**
  - `lib/screens/inventory_screen.dart` — Zeile 187-216 (Search-Bar)
  - `lib/providers/app_preferences_provider.dart` — Enum-Getter/Setter
  - `lib/providers/inventory_provider.dart` — `sortedItems(mode)`
- **ARB-Keys:**
  - `[NEW] inventorySortLabel` („Sortieren: {mode}" / „Sort: {mode}")
  - `[NEW] inventorySortByStockDesc`
  - `[NEW] inventorySortByStockAsc`
  - `[NEW] inventorySortByName`
  - `[NEW] inventorySortByValue`
  - `[NEW] inventorySortByCritical`
- **Accessibility-Keys:** `Key('inventorySortPill')`,
  `Key('inventorySortSheet')`, `Key('inventorySortOption-${mode}')`.
- **State-Matrix:** Sort-Pref bei Unknown-Key → Fallback `default`
  (siehe Risiko #4).
- **Tests:** `test/screens/inventory_sort_test.dart` — alle Modes
  rendern korrekte Reihenfolge; Persistenz lädt zuletzt gewählten
  Mode; Unknown-Key fällt auf Default zurück.
- **agent:** flutter-coder
- **Aufwand:** 3h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Sub-Routes-Tabelle: „Inventory Sort Sheet"
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert

---

### [ ] Task 05 — Help-Icon im Phone-AppBar (AppBar-Action)

- **Pre-Requirement für #01:** muss vor Bottom-Nav-Umbau gemerged sein.
- **Was:** Auf Phone-Viewport (`width < 800`) erhält die `AppBar` in
  `MainScreen` einen zusätzlichen `IconButton` mit `Icons.help_outline`,
  der direkt `MainTab.help` selektiert (Enum-basiert nach #00).
- **AppBar-Action-Overflow (Pflicht-Check):** auf 360×640 sind dann
  InvitesBell + Search + Help = 3 Actions — wenn das eng wird,
  PopupMenuButton (`Key('appBarOverflow')`) für Search+Help nutzen.
- **Warum:** First-Run-User sucht „Wie geht das?" unter dem
  Fragezeichen-Icon.
- **Touch-Points:**
  - `lib/screens/main_screen.dart` — Phone-AppBar `actions`
- **ARB-Keys:**
  - `actionHelp` (existiert vermutlich, sonst `[NEW]` „Hilfe" / „Help")
- **Accessibility-Keys:** `Key('appBar-help-action')`.
- **State-Matrix:** N/A.
- **agent:** ui-builder
- **Aufwand:** 1.5h (inkl. Overflow-Check)
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Top-Level-Notiz: Help-Icon AppBar
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert (360×640 Overflow geprüft)

---

### [ ] Task 06 — Dashboard: Skeleton-Loader via `skeletonizer` (RE-DESIGNED)

- **Was:** `pubspec.yaml` ergänzen: `skeletonizer: ^2.1.3` **[NEW]**
  (MIT, ~30-60 KB Bundle). Statt `_LoadingSkeleton`-Eigenbau:
  `Skeletonizer(enabled: isLoading, child: <real-widget-tree>)`.
  Eliminiert Sync-Drift zwischen Skeleton und realem Layout.
- **External-Solutions-Scout (Council):** `skeletonizer` ersetzt
  ~200 Zeilen Eigenbau und löst das Layout-Drift-Problem.
- **Statische Variante (kein Shimmer):** `PaintingEffect.solid` (oder
  default constructor mit `effect: SoldColorEffect`-Pendant) — keine
  Animation, kein Bloat.
- **Dark-Mode-Token:** `AppTheme.bgSubtleOf(context)` explizit als
  `containersColor` an Skeletonizer übergeben.
- **Race-Condition-Mitigation (Bug-Hunter):** Skeleton nur zeigen
  wenn `InventoryProvider.isLoading && inventoryProvider.deals.isEmpty`
  — NICHT bei Re-Load mit existierenden Daten. Re-Load zeigt
  bestehende Daten plus optionalen Refresh-Indicator in der AppBar.
- **Touch-Points:**
  - `pubspec.yaml` — Dependency-Add
  - `pubspec.lock` — wird durch `flutter pub get` aktualisiert
  - `lib/screens/dashboard_screen.dart` — `build`-Loop
  - `lib/widgets/kpi_card.dart` — sicherstellen dass Widget
    skeletonizer-kompatibel ist (Text und Icon haben sinnvolle
    Bone-Shapes)
- **ARB-Keys:** keine (Skeletons sind sprachlos).
- **Accessibility-Keys:** `Key('skeletonLoader')` auf Wrapper.
- **State-Matrix:**
  - empty (no data, isLoading=false): Empty-State (existierendes
    Widget)
  - loading (isLoading=true, data=empty): Skeletonizer aktiv
  - re-loading (isLoading=true, data=present): Daten + AppBar-Spinner
  - error: Empty-Error-Widget (existierend)
  - success: Daten gerendert
- **Tests:** Widget-Test für Race-Condition: bei
  (isLoading=true, data=[x,y]) wird KEIN Skeleton gezeigt.
- **agent:** ui-builder
- **Aufwand:** 2.5h (inkl. pubspec, Bone-Shapes, Race-Test)
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün (inkl. Race-Test)
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Notiz: Skeleton-Loader-Variante
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
    (Light + Dark Skeleton)
  - [ ] Mobile-First verifiziert
  - [ ] `pubspec.lock` committed

---

### [ ] Task 07 — Inbox-Header-Compaction auf Phone

- **Was:** Auf Phone (`width < 600`) wird der `_InboxHeader` auf eine
  kompakte Zeile reduziert. Subtext in expandierbarem Bereich
  (`ExpansionTile`-Pattern).
- **Touch-Points:**
  - `lib/screens/inbox_screen.dart` — Zeile 150-290
- **ARB-Keys:**
  - `[NEW] inboxHeaderShowDetails` („Details anzeigen" / „Show details")
  - `[NEW] inboxHeaderHideDetails` („Details verbergen" / „Hide details")
- **Accessibility-Keys:** `Key('inboxHeader-expand')`,
  `Key('inboxHeader-details')`.
- **State-Matrix:** collapsed (default) / expanded — beide testen.
- **agent:** ui-builder
- **Aufwand:** 2h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Inbox-Notiz: kompakter Header auf Phone
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert

---

### [ ] Task 08 — Settings-Tabs: Scroll-Indicator (Phone)

- **Was:** Rechter Edge-Gradient + Pfeil-Chevron als
  Scrollbarkeit-Affordance auf `TabBar(isScrollable: true)`.
- **Touch-Points:**
  - `lib/screens/settings_screen.dart` — Zeile 64-84
- **ARB-Keys:** keine.
- **Accessibility-Keys:** `Key('settingsTabsScrollHint')`.
- **State-Matrix:** indicator visible / hidden je nach Scroll-Position.
- **agent:** ui-builder
- **Aufwand:** 1.5h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Settings-Notiz: Scroll-Indicator
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert

---

### [ ] Task 09 — Statistics: Sticky-Filter-Bar auf Phone

- **Was:** `StatisticsFilterBar` klebt am AppBar-Bottom via
  `SliverPersistentHeader`.
- **Touch-Points:**
  - `lib/screens/statistics_screen.dart` — Zeile 144-190
- **ARB-Keys:** keine.
- **Accessibility-Keys:** `Key('statisticsFilterBarSticky')`.
- **State-Matrix:** sticky immer aktiv auf Phone.
- **agent:** flutter-coder
- **Aufwand:** 2.5h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Stats-Notiz: Sticky-Filter
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
    (`charts-render` Pflicht-Test)
  - [ ] Mobile-First verifiziert

---

### [ ] Task 10 — Empty-State: aktionierbare CTAs mit Role-Gate (RE-DESIGNED)

- **Pre-Requirement:** Task #04 (Sort-Pill) zuerst — Merge-Konflikt
  in `inventory_screen.dart`.
- **Was:** Empty-States bekommen primären CTA-Button.
  **Pflicht: Workspace-Role-Gate pro CTA.**
- **Role-Gate-Pattern (`active_workspace_provider.dart` →
  `workspace_service.dart:63-106`):**
  - Owner / Admin / Editor → CTA sichtbar + aktiv
  - Viewer → CTA hidden ODER disabled mit Tooltip
    `dealsEmptyCtaViewer = "Nur Workspace-Admins können Deals anlegen"`.
- **CTAs:**
  - `inventory_screen.dart` `_EmptyInventoryState`: „Artikel anlegen"
  - `settings_screen.dart` `_BuyersTab`: „Käufer anlegen"
  - `inbox_screen.dart` Tab-Empties: nur freundliche Copy + Icon
    (kein CTA, passive Tabs)
  - `deals_screen.dart`/`summary_panel.dart`: „Ersten Deal anlegen"
- **Touch-Points:**
  - `lib/screens/inventory_screen.dart` — `_EmptyInventoryState`
  - `lib/screens/settings_screen.dart` — Zeile 133-147 `_BuyersTab`
  - `lib/screens/inbox_screen.dart` — Tab-Empty-States
  - `lib/widgets/summary_panel.dart` / `lib/widgets/deal_table.dart`
- **ARB-Keys:**
  - `[NEW] inventoryEmptyCta` („Ersten Artikel anlegen" / „Add your
    first item")
  - `[NEW] dealsEmptyCta` („Ersten Deal anlegen" / „Add your first
    deal")
  - `[NEW] buyersEmptyCta` („Ersten Käufer anlegen" / „Add your first
    buyer")
  - `[NEW] inventoryEmptyCtaViewer` („Nur Workspace-Admins können
    Artikel anlegen" / „Only workspace admins can add items")
  - `[NEW] dealsEmptyCtaViewer` („Nur Workspace-Admins können Deals
    anlegen" / „Only workspace admins can add deals")
  - `[NEW] buyersEmptyCtaViewer` („Nur Workspace-Admins können Käufer
    anlegen" / „Only workspace admins can add buyers")
- **Accessibility-Keys:** `Key('emptyState-inventory-cta')`,
  `Key('emptyState-deals-cta')`, `Key('emptyState-buyers-cta')`.
- **State-Matrix:**
  - empty + role≥editor: CTA sichtbar + aktiv
  - empty + role=viewer: CTA hidden oder disabled+tooltip
  - empty + offline: CTA mit Snackbar „Offline" on Tap
- **Tests:** `test/widgets/empty_state_role_gate_test.dart` — pro
  Empty-State testen, dass Viewer-Rolle kein aktives CTA sieht.
- **agent:** ui-builder
- **Aufwand:** 3h (inkl. Role-Gate-Tests)
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün (inkl. Role-Gate-Test)
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Notizen: CTA-Empty-States
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert

---

### [ ] Task 11 — Global-Search: Recent-Searches mit PII-Filter (RE-DESIGNED)

- **Was:** Recent-Searches-Section vor dem Search-Input,
  `SharedPreferences`-persistiert (max. 5).
- **Pflicht-PII-Filter vor Write:**
  - Skip wenn String enthält `@` (E-Mail)
  - Skip wenn `\d{8,}` matched (Tracking/Phone)
  - Skip wenn `^[A-Z0-9]{10,}$` (alphanumerische Tracking-Codes)
- **Logout-Clear (Pflicht):** in `AuthProvider.signOut()` Recent-
  Searches BEVOR State gelöscht wird.
- **In-Memory-Cache** im Provider (kein `FutureBuilder` bei jedem
  Render).
- **Korrektur an Offene-Frage #4 (war Zeile 487 alt):** das Risiko
  sind die Input-Strings, nicht die Results — daher Filter auf
  Input-Side.
- **Touch-Points:**
  - `lib/widgets/global_search_dialog.dart` — Pre-Input-Section
    + In-Memory-Cache
  - `lib/providers/app_preferences_provider.dart` —
    `recentSearches` Getter/Setter mit PII-Filter
  - `lib/providers/auth_provider.dart` — `signOut()`-Clear
- **ARB-Keys:**
  - `[NEW] searchRecentTitle` („Letzte Suchen" / „Recent searches")
  - `[NEW] searchRecentEmpty` („Noch keine Suchen" / „No recent
    searches")
  - `[NEW] searchRecentClear` („Zurücksetzen" / „Clear")
- **Accessibility-Keys:** `Key('recentSearchesSection')`,
  `Key('recentSearchItem-$index')`, `Key('recentSearchesClear')`.
- **State-Matrix:**
  - empty (keine Recent): „searchRecentEmpty" Copy
  - populated: Liste der letzten 5 (filtered)
  - cleared: zurück auf empty
  - logout: cleared via AuthProvider-Hook
- **Tests:** `test/widgets/recent_searches_pii_filter_test.dart` —
  E-Mail-Input wird nicht persistiert; 10+ Digits wird nicht
  persistiert; signOut() leert die Liste; In-Memory-Cache erspart
  zweiten SharedPrefs-Read.
- **agent:** flutter-coder
- **Aufwand:** 2.5h (PII-Filter + Logout-Hook + Cache + Test-Coverage)
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün (inkl. PII-Filter-Test)
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Sub-Routes: GlobalSearchDialog erweitert
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert

---

### [ ] Task 12 — Snackbar-Feedback nach Tracking-Suggestion-Accept

- **Was:** Snackbar mit „Tracking #{nr} → Deal #{dealId} übernommen" +
  „Anzeigen"-Action, die in Deals-Tab mit Filter springt.
- **Touch-Points:**
  - `lib/widgets/inbox_message_details.dart` — Accept-Handler
  - `lib/screens/inbox_screen.dart` — Callback
- **ARB-Keys:**
  - `[NEW] inboxAcceptedSnack` („Tracking {nr} → Deal #{dealId}
    übernommen" / „Tracking {nr} → Deal #{dealId} accepted")
  - `[NEW] inboxAcceptedShowDeal` („Anzeigen" / „Show")
- **Accessibility-Keys:** `Key('inboxAcceptedSnack')`,
  `Key('inboxAcceptedShowDealAction')`.
- **State-Matrix:** success only (Failure-State zeigt Error-Snack
  aus bestehendem Pfad).
- **agent:** ui-builder
- **Aufwand:** 1.5h
- **Definition-of-Done:**
  - [ ] `flutter analyze` clean
  - [ ] `flutter test` grün
  - [ ] `python3 .claude/scripts/check-l10n.py` clean
  - [ ] `bash .claude/scripts/check-smoke-passed.sh` (<24h)
  - [ ] `_page-registry.md` Inbox-Notiz: Accept-Snackbar
  - [ ] Browser-Smoke: `mobile-overflow` + `smoke-theme` bestanden
  - [ ] Mobile-First verifiziert

---

## Task-Dependency-Graph

```
#00 (Enum MainTab)                  ← PRE-REQ für #01
   └─► #01 (Bottom-Nav 5-Tab)       ← braucht zusätzlich #05

#05 (Help-AppBar-Icon)              ← PRE-REQ für #01

#04 (Inventory Sort-Pill)           ← PRE-REQ für #10 (selbe Datei)
   └─► #10 (Empty-State + Role-Gate)

#02 (Quick-Status-Sheet)            ← isoliert (DealCard)
#03 (Inbox-Suggestion 3-Action)     ← isoliert
#06 (Dashboard Skeleton)            ← isoliert (+ pubspec.yaml)
#07 (Inbox-Header Compact)          ← isoliert
#08 (Settings Tab Scroll-Hint)      ← isoliert
#09 (Stats Sticky-Filter)           ← isoliert
#11 (Recent-Searches + PII)         ← isoliert (SearchDialog)
#12 (Inbox Accept-Snackbar)         ← isoliert
```

**Empfohlene Worker-Reihenfolge** (Topologisch + Quick-Wins first):

1. **#00** Enum MainTab (3h) — Pre-Refactor, freischaltet #01.
2. **#05** Help-AppBar-Icon (1.5h) — Pre-Req für #01, Quick-Win.
3. **#08** Settings-Scroll-Hint (1.5h) — isoliert, Quick-Win.
4. **#12** Accept-Snackbar (1.5h) — isoliert.
5. **#06** Dashboard Skeleton (2.5h) — pubspec-Add, isoliert.
6. **#07** Inbox-Header-Compact (2h) — isoliert.
7. **#02** Quick-Status-Sheet (3h) — DealCard, isoliert.
8. **#03** Inbox-Suggestion-3-Action (2.5h) — isoliert.
9. **#11** Recent-Searches+PII (2.5h) — isoliert.
10. **#09** Stats-Sticky-Filter (2.5h) — isoliert.
11. **#04** Inventory-Sort-Pill (3h) — Pre-Req für #10.
12. **#10** Empty-State-CTAs+Role-Gate (3h) — letzter Inventory-Touch.
13. **#01** Bottom-Nav (5h) — größtes Increment, am Schluss nach #00+#05.

## Subagent-Routing-Summary

| Task | Agent | Modell |
|---|---|---|
| 00 Enum MainTab | `flutter-coder` | Sonnet |
| 01 Bottom-Nav 5-Tab | `ui-builder` | Sonnet |
| 02 DealCard Quick-Status | `ui-builder` | Sonnet |
| 03 Inbox-Suggestion-Layout | `ui-builder` | Sonnet |
| 04 Inventory-Sort | `flutter-coder` | Sonnet |
| 05 Help-AppBar-Icon | `ui-builder` | Haiku |
| 06 Dashboard-Skeleton | `ui-builder` | Sonnet |
| 07 Inbox-Header-Compaction | `ui-builder` | Sonnet |
| 08 Settings-Tabs-Scroll-Hint | `ui-builder` | Haiku |
| 09 Stats-Sticky-Filter | `flutter-coder` | Sonnet |
| 10 Empty-State+Role-Gate | `ui-builder` | Sonnet |
| 11 Recent-Searches+PII | `flutter-coder` | Sonnet |
| 12 Inbox-Accept-Snackbar | `ui-builder` | Sonnet |

**Total Aufwand:** ~32-35h (13 Tasks). Steigerung vs. Draft (26h):
- +3h Task #00 (Enum-Migration, neu)
- +2h Task #01 (5-Tab-Re-Design + FAB-Placement-Test)
- +0.5h Task #02 (Checkbox-Extraction Pre-Step + Error-Pfad)
- +0.5h Task #03 (Long-Press-Konsistenz)
- +0.5h Task #05 (AppBar-Overflow-Check)
- +0.5h Task #06 (pubspec + Race-Test)
- +0.5h Task #10 (Role-Gate + Tests)
- +0.5h Task #11 (PII-Filter + Logout-Hook + Tests)

## Council-Iteration-Footer

- **Council-Runs:** 1× Phase-2 Full-Review (5 Reviewer: Architekt,
  Bug-Hunter, External-Solutions-Scout, Security, UX/Mobile)
- **Verdict:** ÜBERARBEITUNG (7 Pflicht-Änderungen, 6 empfohlene
  Verbesserungen)
- **Pflicht-Iterationen:** 1 (dieses Dokument)
- **Geschätzte Council-Kosten:** ~$3-4 (1× Phase-2 mit 5 Opus-Reviewern
  à 600-800 Tokens System-Prompt)
- **Validate-Plan-Resultat:** siehe Run-Output am Ende des
  Approval-Reports (manuell ausgeführt via
  `bash .claude/scripts/validate-plan.sh plans/2026-05-16_ux_quickwins_audit.md`).

## Offene Fragen (für Follow-Up, nicht blockierend)

1. **Task #02 Optimistic-Lock:** `deal.updated_at`-Vergleich braucht
   einen RPC oder einen Versions-Check via PostgreSQL `xmin`. Eigener
   Follow-Up-Task nach #02.
2. **Task #04 Sort-Persistenz Scope:** global vs. workspace-scoped.
   Vorschlag: global, da Sort-Mode UI-Präferenz (nicht workspace-
   spezifisches Datum).
3. **Task #11 Recent-Searches Sync:** über Devices syncen? Nein —
   `shared_preferences` only. Wenn Multi-Device-Sync gewünscht → eigene
   Tabelle, eigener Plan.
