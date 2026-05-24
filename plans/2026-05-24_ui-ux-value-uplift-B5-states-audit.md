# B5 States-Audit — Listen-Screens

**Datum:** 2026-05-24  
**Aufgabe:** B5 aus `plans/2026-05-24_ui-ux-value-uplift.md`  
**Scope:** 5 B2/B3/B4-migrierte Screens + 4 weitere Listen-Screens (Referenz)

---

## 1. Methodik

Grep-Analyse über folgende Patterns:
- `shouldShowSkeleton` / `isLoading` / `initialLoadAttempted` → loading-State
- `EmptyState(` / `_EmptyState(` / `Center(child: Column/Text` → empty-State
- `provider.lastError` / `_ErrorState(` in UI-Build-Pfaden → error-State  
- `canEdit` / `wsProvider.role` / `ActiveWorkspaceProvider` / FAB-Gating → no-permission-State
- `SocketException` / `offline` / `Connectivity` / `NetworkException` → no-network-State

---

## 2. Audit-Tabelle

| Screen | success | loading (Skeleton) | empty | error | no-permission | no-network |
|---|---|---|---|---|---|---|
| **inventory** (`inventory_screen.dart`) | ✓ | ✓ B2 Skeleton | ✓ `EmptyState` (Stock + Sold Tab, inkl. Filter-Leer) | ✗ `lastError` wird NICHT im UI gerendert — data-leer + error = ununterscheidbar EmptyState | ✗ FAB fehlt komplett (liegt in `main_screen.dart`, kein canEdit-Gate) | ✗ kein Hinweis |
| **inbox** (`inbox_screen.dart`) | ✓ | ✓ B4 Skeleton (alle 3 Tabs) | ✓ `EmptyState` pro Tab (Suggestions, Matched, Unclassified) | ~ `lastError` nur in Action-Callbacks (AppFeedback.error bei Poll/Reparse), nicht als persistenter In-Screen-State nach Initial-Load-Fehler | ✗ kein canEdit-Gate, Verwerfen/Akzeptieren immer aktiv | ✗ kein Hinweis |
| **tickets** (`tickets_screen.dart` via `InventoryProvider`) | ✓ | ✓ B4 Skeleton (Active + Archive Tab) | ✓ `EmptyState` (Active Desktop + Mobile, Archive) | ✗ `lastError` wird NICHT im UI gerendert — identisch zu inventory | ✗ kein canEdit-Gate auf FAB (liegt in main_screen, immer sichtbar) | ✗ kein Hinweis |
| **suppliers** (`suppliers_screen.dart` via `InventoryProvider`) | ✓ | ✗ kein Skeleton — `isLoading` wird ignoriert, direkt `suppliers.isEmpty` geprüft | ✓ `_EmptyState` (eigene lokale Klasse, kein shared EmptyState-Widget) | ✗ `lastError` wird nicht geprüft; bei Ladefehler bleibt `suppliers == []` → EmptyState fälschlich angezeigt | ✗ FAB immer sichtbar, kein canEdit-Gate | ✗ kein Hinweis |
| **deals** (`deals_screen.dart` + `deal_table.dart`) | ✓ | ✗ kein Skeleton in `DealTable` — B3 ist laut Plan noch offen (`[ ]`) | ✓ `_EmptyState` in `DealTable` (lokale Klasse) | ✗ `lastError` nicht geprüft in `DealTable`; bei Fehler sieht User leere Liste | ✗ kein canEdit-Gate auf FAB (in `main_screen.dart`) | ✗ kein Hinweis |

### Referenz-Screens (nicht B2/B3/B4-migriert, aber informativ)

| Screen | loading | empty | error | no-permission |
|---|---|---|---|---|
| **warehouses** (`warehouses_screen.dart`) | `CircularProgressIndicator` (kein Skeleton) | ✓ `_EmptyState` mit canEdit-Flag | ✓ `_ErrorState` mit Retry-Button | ✓ FAB und Edit/Delete per `canEdit` |
| **categories** (`categories_screen.dart`) | `CircularProgressIndicator` (kein Skeleton) | ✓ `_EmptyState` mit canEdit-Flag | ✓ `_ErrorState` mit Retry-Button | ✓ FAB per `canEdit`, Edit/Delete-Actions disabled |
| **stocktake** (`stocktake_screen.dart`) | `CircularProgressIndicator` (kein Skeleton) | ✓ `_EmptyState` mit canEdit-Flag | ✓ `_ErrorState` mit Retry-Button | ✓ FAB per `canEdit` |
| **purchase_orders** (`purchase_orders_screen.dart`) | `CircularProgressIndicator` (kein Skeleton) | ✓ EmptyState | ✓ `_ErrorState` mit Retry | ✓ FAB per `canEdit` |

---

## 3. Findings — Pflicht-Lücken

### F1: Error-State fehlt in inventory, inbox (Initial-Load), tickets, suppliers, deals

**Beschreibung:** `InventoryProvider.lastError` und `InboxProvider.lastError` werden von der `loadData()`-Methode gesetzt wenn der initiale Load fehlschlägt (catch → `_lastError = e`). In den 5 B-migrierten Screens wird `lastError` im **Build-Pfad** jedoch nie geprüft. Ergebnis: Ein Netzwerkfehler beim ersten Load führt zu einer `EmptyState`-Anzeige (`data.isEmpty == true`), obwohl kein leerer State sondern ein Ladefehler vorliegt — kein Retry-Button, keine Fehlerdiagnose.

Betroffene Dateien:
- `lib/screens/inventory_screen.dart` — `_buildStockTab` und `_buildSoldTab` prüfen `lastError` nicht
- `lib/screens/tickets_screen.dart` — `_ActiveTicketsView` und `_ArchiveTicketsView` prüfen `lastError` nicht
- `lib/screens/inbox_screen.dart` — `_SuggestionsTab`, `_MatchedTab`, `_UnclassifiedTab` prüfen `lastError` nicht
- `lib/screens/suppliers_screen.dart` — Build-Methode prüft `lastError` nicht
- `lib/widgets/deal_table.dart` — `DealTable.build` prüft `lastError` nicht

**Referenz-Pattern (korrekt, aus `warehouses_screen.dart` Z. 96–103):**
```dart
final bodyContent = provider.isLoading
    ? const Center(child: CircularProgressIndicator())
    : provider.lastError != null
        ? _ErrorState(message: l10n.warehousesLoadError, onRetry: () => provider.loadData())
        : warehouses.isEmpty
            ? _EmptyState(canEdit: canEdit)
            : _WarehouseList(/* ... */);
```

**Empfehlung:** In den Skeleton-basierten Screens muss der `error`-State nach dem Skeleton-Block ergänzt werden:
```dart
child: showSkeleton
    ? ListSkeleton(/* ... */)
    : provider.lastError != null && items.isEmpty
        ? _ErrorEmptyState(onRetry: () => provider.loadData())  // NEU
        : items.isEmpty
            ? EmptyState(/* ... */)
            : _buildList(/* ... */),
```
Oder als übergebener Parameter in den Sub-Widgets (Skeleton-Widgets kennen `lastError` dann über den Parameter).

ARB-Keys nötig: `inventoryLoadError`, `ticketsLoadError`, `inboxLoadError`, `suppliersLoadError`, `dealsLoadError` (DE + EN, Retry-CTA über `appRetry`-Key oder neu).

---

### F2: Skeleton fehlt in suppliers

**Beschreibung:** `suppliers_screen.dart` nutzt `provider` aus `InventoryProvider`, hat aber keinen Skeleton. Der Build-Pfad (Z. 102–103) prüft direkt `suppliers.isEmpty` — `isLoading` und `initialLoadAttempted` werden ignoriert. B4 hat suppliers als noch offen markiert.

**Betroffene Datei:** `lib/screens/suppliers_screen.dart` Z. 102  
**Empfehlung:** `shouldShowSkeleton(isLoading, hasData: suppliers.isNotEmpty, initialLoadAttempted)` einbauen, `ListSkeleton` rendern. Ist Teil des offenen B4-Tasks.

---

### F3: no-permission — FABs in inventory, tickets, deals, inbox, suppliers nicht role-gegated

**Beschreibung:** Die FABs für die 5 Screens liegen in `main_screen.dart` (deals/tickets-FAB, Z. 350–366) oder direkt im Screen-Scaffold (suppliers-FAB Z. 68–78). Keiner dieser FABs prüft `wsProvider.role?.canEdit`. Ein `observer`-User sieht also den „New"-FAB für Deals/Tickets/Suppliers und kann ihn antippen — der Dialog öffnet sich, und erst der Submit-Call scheitert an RLS.

Referenz-Pattern (korrekt, aus `warehouses_screen.dart`):
```dart
final fab = canEdit ? FloatingActionButton.extended(/* ... */) : null;
```

**Betroffene Dateien:**
- `lib/screens/main_screen.dart` Z. 350–366 — Deals/Tickets-FAB ohne canEdit-Gate
- `lib/screens/suppliers_screen.dart` Z. 68–78 — Suppliers-FAB ohne canEdit-Gate
- `lib/widgets/deal_table.dart` — Edit/Delete-Actions in `_DealRow` nicht role-gegated (ähnlich wie Suppliers)

**Empfehlung:** `ActiveWorkspaceProvider` per `context.watch` in den jeweiligen Scope holen; `canEdit = wsProvider.role?.canEdit ?? false`; FAB nur rendern wenn `canEdit`. Für `main_screen.dart` muss `Consumer2` um `ActiveWorkspaceProvider` erweitert werden (oder ein separater Consumer im FAB-Build-Pfad).

**Wichtig:** `inventory_screen.dart` selbst hat keinen eigenen FAB (Add-Item-Aktion ist vermutlich im Product-Detail-Kontext). Kein Finding für inventory FAB — nur deal_table Actions.

---

### F4: no-network — kein Screen zeigt Offline-Hinweis

**Beschreibung:** Die App nutzt Supabase über HTTP. Bei Netzwerkausfall scheitert `loadData()` mit einer Exception (in `_lastError` gespeichert), die in den meisten Screens nicht gerendert wird (siehe F1). Es gibt kein globales Offline-Banner oder Screen-spezifisches Offline-Signal. Das einzige Offline-Pattern im Code ist `RetrackResult.offline` im Tracking-Kontext (supabase_repository.dart Z. 2089) — ein Sonderfall.

**Empfehlung:** Kurzfristig: F1-Fix deckt den häufigsten Fall ab (Fehler beim Initial-Load inkl. Offline → `_ErrorState` mit Retry). Mittelfristig: Prüfen ob `SocketException`-Pattern aus der Exception erkennbar ist → dedizierter Offline-Text im Error-State. Kein eigenes `connectivity_plus`-Package nötig — `SocketException is Exception` aus `lastError.toString()` reicht für einen Hinweis.

---

## 4. Schnell-Fixes (1–2 Zeilen, sofort möglich)

### Fix A: suppliers_screen.dart — Error-State ergänzen (2 Zeilen + l10n)

Die `suppliers_screen.dart` ist klein (228 Zeilen), hat keine Skeleton-Logik, und ein Error-State lässt sich minimal mit 2 Zeilen im Body-Build-Pfad ergänzen. Da jedoch der `lastError`-Text noch keinen eigenen ARB-Key hat, ist dieser Fix ohne neuen l10n-Key nur unvollständig umsetzbar. Daher: als **Finding dokumentiert, kein Fix hier** — Folge-Task.

### Fix B: suppliers_screen.dart — isLoading prüfen (trivial)

Aktuell: `suppliers.isEmpty ? const _EmptyState() : _buildList(...)`. Wenn `isLoading && suppliers.isEmpty`, zeigt der Screen den `_EmptyState` während der Provider noch lädt — Flickern. Fix: `if (provider.isLoading && suppliers.isEmpty) return const Center(child: CircularProgressIndicator());` als erste Bedingung. Das ist ein **1-Zeilen-Fix ohne l10n-Bedarf**.

Da `suppliers_screen.dart` noch kein B4-Skeleton hat (B4 offen), mache ich diesen minimalen Fix jetzt, um zumindest das Loading-Flicker-Problem zu beheben:

**Status: Fix B wird angewendet** (siehe Abschnitt 5).

---

## 5. Angewendeter Fix

### Fix B — `suppliers_screen.dart`: isLoading-Guard

Datei: `lib/screens/suppliers_screen.dart`  
Stelle: `build`-Methode, Body-Conditional (Z. 102)  
Änderung: Loading-Guard vor der isEmpty-Prüfung eingebaut.

---

## 6. Zusammenfassung Findings

| Finding | Schwere | Screen(s) | Folge-Task empfohlen |
|---|---|---|---|
| F1: Error-State fehlt (Initial-Load-Fehler = fälschlich EmptyState) | Hoch | inventory, tickets, inbox (tabs), suppliers, deals | Ja — B5-Followup oder A6b/A6c |
| F2: Skeleton fehlt in suppliers | Mittel | suppliers | Ja — offener B4-Task |
| F3: FAB/Actions nicht role-gegated | Mittel | deals, tickets (main_screen FAB), suppliers, deal_table rows | Ja — eigener Permission-Task |
| F4: no-network — kein Hinweis | Niedrig | alle Screens | Ja — nach F1, ggf. als Teil des Error-State-Texts |

**Fixes gemacht:** Fix B (suppliers isLoading-Guard — 1 Zeile).  
Keine Test-Änderungen in diesem Task.
