# Plan: StockProvider-Split (#3 aus der Provider-Decomposition-Roadmap)

**Datum:** 2026-06-09 · **Status:** Approved — Implementation
**Quelle:** `understand-stock-split`-Workflow (4 Mapper + Synthese), code-anchored. Muster wie #2 (PurchasingProvider, PR #128) / #1 (CatalogProvider, #120).

## Verdict
Clean one-PR Stock-Split, **weniger riskant als #2** (Hooks/FK-Remap/byDealId-Coupling bereits erprobt). Provider-Graph bleibt strikter DAG — KEIN Zyklus.

## Provider-Graph (Registrierungs-/Topo-Reihenfolge)
```
CatalogProvider     (keine deps)
PurchasingProvider  (keine deps)
StockProvider       (deps: Catalog, Purchasing)            ← NEU, ProxyProvider3
InventoryProvider   (deps: Catalog, Purchasing, Stock)     ← upgrade auf ProxyProvider4
```
Cross-Provider-Kanten danach: `Inventory→Stock` (importCsvAll, checkInDeal, _summariesByArchive), `Stock→Catalog` (criticalStock, bookGoodsReceipt), `Stock→Purchasing` (bookGoodsReceipt PO-Refresh). Azyklisch.

## 1. Was nach `lib/providers/stock_provider.dart` wandert
**Fields:** `_inventoryItems` (:111), `_movements` (:112), `_warehouses` (:118), `_stocktakes` (:123), `_productStock` (:129). + eigene Infra: `_repository`/`_uuid`/Lifecycle-Set + `_catalogProvider`+`updateCatalogProvider`+`_catalogProducts` (`?? const []`) + `_purchasingProvider`+`updatePurchasingProvider`.
**Getters:** inventoryItems (166), movements (167), warehouses (173), defaultWarehouse (176), stocktakes (180), productStock (186), criticalStockCount (251), totalStockQuantity (309), totalStockValue (312) + eigene isLoading/initialLoadAttempted/lastError.
**Methoden (stock-only, mechanisch):** _bootstrapDefaultWarehouse (529), addWarehouse (1388), updateWarehouse (1397), deleteWarehouse (1408), startInventory (1434), countStocktakeItem (1519), closeStocktake (1544), loadStocktakeItems (1646), addStocktake (1654), updateStocktake (1663), deleteStocktake (1675), addInventoryItem (1687), updateInventoryItem (1714), deleteInventoryItem (1750), adjustStock (1760), loadBatchesForItem (1960), loadAllBatches (1965), addBatch (1968), updateBatch (1975), deleteBatch (1981).
**Methode (cross-domain, MOVES):** `bookGoodsReceipt` (1252) → §4.

**Skelett = purchasing_provider.dart 1:1** (Konstruktor, in-flight-coalescing loadData/_doLoadData, clearLocalState mit `_activeWorkspaceId=null`, DB-only `_log` OHNE `_activities`-Cache, dispose, `if(!_disposed)`-Guards).
`_doLoadData`: aus `loadAll()`-Snapshot die 5 Stock-Listen mit EXAKT denselben Sort-Orders hydrieren (items by name; movements/stocktakes desc by date; warehouses by name.lower), `_bootstrapDefaultWarehouse` wenn `_warehouses.isEmpty && wsId!=null`, dann `_productStock` lazy-load (defensiver try/catch, empty fallback — InvProvider :457-469).

## 2. main.dart Wiring (ersetzt ~174-196)
- NEU `ChangeNotifierProxyProvider3<SupabaseRepository, CatalogProvider, PurchasingProvider, StockProvider>` (nach Purchasing, vor Inventory); `update` re-injected `previous.updateCatalogProvider`+`updatePurchasingProvider` (Gotcha #4).
- InventoryProvider `ProxyProvider3`→**`ProxyProvider4<Repo, Catalog, Purchasing, Stock, Inventory>`**; `update` ergänzt `previous.updateStockProvider(stock)`. Neues `_stockProvider`-Feld + `updateStockProvider` + `_stockInventoryItems`/`_stockWarehouses` (`?? const []`) Reader in InventoryProvider.
- `_hydrate` Future.wait: `stock.setActiveWorkspace(activeId)` ergänzen (+ `final stock = context.read<StockProvider>();`).
- `_onWorkspaceChanged`: `context.read<StockProvider>().setActiveWorkspace(newId)`.
- Sign-out: `context.read<StockProvider>().clearLocalState()`.

## 3. importCsvAll + checkInDeal — BLEIBEN auf InventoryProvider, schreiben Stock via Hooks (kein Zyklus)
**importCsvAll** (846-1139): Return-5-Tuple `(deals,shops,buyers,suppliers,items)` + main_screen-Call EXAKT erhalten. Warehouse-Loop (980-999) + Item-Loop (922-943): dedup-seed→`_stockProvider?.warehousesRaw/inventoryItemsRaw ?? const []`; per-row→`upsertWarehouseFromImport`/`upsertInventoryItemFromImport`; nach Loop→`sortWarehouses`/`sortInventoryItems` + `notifyAfterCrossDomainWrite`. kDebugMode-assert `_stockProvider != null`. itemCount weiter lokal zählen.
**checkInDeal** (1801) + **_matchOrCreateProduct** (1877): BLEIBEN auf Inventory (Option A — vermeidet Stock→Inventory-Kante/Zyklus). Stock-Writes via Hook: `upsertInventoryItemFromImport(item)` + NEU `insertMovementFromCheckIn(mv)` + `notifyAfterCrossDomainWrite`. Deal-`inventoryItemIds`-Write (1851-1858) bleibt lokal (Deals). `_matchOrCreateProduct` liest Catalog (Inventory hält Catalog schon).

**StockProvider-Write-Back-Hooks (mirror purchasing :85-122):**
```dart
List<Warehouse> get warehousesRaw => _warehouses;
List<InventoryItem> get inventoryItemsRaw => _inventoryItems;
void upsertWarehouseFromImport(Warehouse s) => _warehouses.add(s);
void upsertInventoryItemFromImport(InventoryItem s) => _inventoryItems.add(s);
void insertMovementFromCheckIn(InventoryMovement m) => _movements.insert(0, m);
void sortWarehouses() => _warehouses.sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
void sortInventoryItems() => _inventoryItems.sort((a,b)=>a.name.compareTo(b.name));
void notifyAfterCrossDomainWrite() { if (!_disposed) notifyListeners(); }
```
`_summariesByArchive` (347, liest _inventoryItems :366) → `_stockInventoryItems` (Inventory→Stock read).

## 4. bookGoodsReceipt (1252-1384) — MOVES to StockProvider verbatim
Writes `_inventoryItems`/`_movements` (jetzt native Stock). Liest Catalog (`_catalogProducts` :1311) via injected `_catalogProvider`. PO-Header-Refresh Phase D (1363-1376): `_purchasingProvider?.replacePurchaseOrderHeader(freshPo)` + `notifyAfterCrossDomainWrite()` (best-effort/silent-fail erhalten). Activity-Log → DB-only (§5).
**Consumer `purchase_order_detail_screen.dart`:** schon dual; nur `:101 Provider.of<InventoryProvider>`→`Provider.of<StockProvider>` für `bookGoodsReceipt`. PO-Detail = {Stock, Purchasing, Catalog}.

## 5. _activities/_log
`_activities` (113) + `_log` (638) BLEIBEN InventoryProvider. StockProvider bekommt eigenes DB-only `_log` (kein in-memory Cache) — #120 §7.5 Präzedenz. Stock-Events (warehouse/item/movement/stocktake/goods-receipt) erscheinen im activity_screen (lädt aus DB) + nach nächstem loadData, nicht instant im Dashboard-Feed. Akzeptiert, inline dokumentieren.

## 6. MANDATORY #128 Workspace-Fix in StockProvider.setActiveWorkspace
```dart
Future<void> setActiveWorkspace(String? workspaceId) async {
  if (_activeWorkspaceId == workspaceId) return;
  _activeWorkspaceId = workspaceId;
  _repository.setActiveWorkspace(workspaceId);   // ← VOR loadData() (PR #128) — sonst null-WS → still leerer Snapshot
  if (workspaceId == null) { clearLocalState(); return; }
  await loadData();
}
```

## 7. Consumer-Migration (12 Files; 6 dual-provider ⚠️)
Dual (`Consumer2<StockProvider, InventoryProvider>` bzw. context.watch beider): `inventory_screen.dart` (items/criticalStockCount/warehouses + item-CRUD + adjustStock → Stock; .deals bleibt), `dashboard_screen.dart` (criticalStockCount/inventoryItems → Stock; deals/buyers bleiben), `main_screen.dart` (inventoryItems/warehouses → Stock; deals bleibt; **importCsvAll-5-Tuple bleibt Inventory**), `settings_screen.dart` (inventoryItems + updateInventoryItem → Stock), `statistics_screen.dart` (inventoryItems/movements → Stock; purchasing bleibt), `global_search_dialog.dart` (inventoryItems → Stock; deals/purchasing bleiben).
Single→Stock: `stocktake_screen.dart`, `warehouses_screen.dart`, `widgets/inventory_batches_sheet.dart`. Partial (schon multi): `product_detail_screen.dart` (inventoryItems/productStock/movements→Stock), `stocktake_detail_screen.dart` (stocktakes→Stock), `purchase_order_detail_screen.dart` (§4).
Unverändert (Deals-only): activity/tickets/inbox/onboarding/help/deal_*/add_edit_buyer|shop|deal/buyer_legend/summary_panel/statistics/filter_bar.

## 8. Test-Plan
Move→StockProvider-SUT (Fixture wired Catalog+Purchasing wie goods-receipt-Test :195): `inventory_provider_goods_receipt_test`→`stock_provider_goods_receipt_test`, + stocktake/close-stocktake-idempotency/movement-type/warehouse-crud/kpi-aggregation Tests. Bleibt Inventory: deal-delete-undo. `inventory_provider_import_csv_test` BLEIBT (importCsvAll auf Inventory) + Fixture wired jetzt StockProvider + asserted warehouses/items landen in `stock.*` via Hooks.
NEU: (1) `stock_provider_workspace_switch_test` — #128-Guard: seed WS-A → switch WS-B → zurück → `stock.inventoryItems.isNotEmpty && warehouses.isNotEmpty` (counts>0). (2) `checkin_writes_stock_test` — checkInDeal schreibt item+movement in injected Stock + appended inventoryItemIds. (3) goods-receipt erweitern: criticalStockCount liest injected Catalog minStock post-receipt.

## 9. Risiken + Smoke
Risiken (höchste zuerst): (1) #128 silent-empty (→ §6 + Test#1, counts>0). (2) Zyklus (→ §3 Option A). (3) Dual-Provider rebuild-miss (→ Consumer2). (4) cross-write no-op bei stale/null _stockProvider (→ re-inject updateStockProvider + assert). (5) _productStock lazy-load fail (→ defensiver try/catch). (6) bookGoodsReceipt PO-Header best-effort (erhalten). (7) Activity-Feed-Regression (dokumentiert).
**smoke-full-app-audit (PFLICHT):** Goods-Receipt (qty↑, PO-Status, movement), Stocktake (start/count/close + diff), CSV-Round-Trip (warehouses+items+deals+suppliers+POs landen, 5-Tuple-Toast), Dashboard-Critical-Stock (Stock→Catalog read), **Workspace-Switch (Liste repopuliert, NICHT leer — #128-Catch)**.

## 10. #3/#4-Boundary
#3 = die substantielle Arbeit. #4 = `InventoryProvider`→`DealsProvider` Rename (~26 Files mechanisch, eigener PR) + Doc der 2 Orchestratoren (importCsvAll/checkInDeal leben auf Deals, schreiben Stock). Import-Orchestrator-Service-Extraktion → post-launch gepunted ([[feedback_security_hardening_post_launch]]).

## Fallback (falls Review die orchestrator-on-Inventory-writing-Stock-Variante ablehnt)
Slice 3a: nur pure Stock-State+CRUD moven, bookGoodsReceipt/checkInDeal/importCsvAll bleiben temporär auf Inventory (Stock-Writes via Hooks). Slice 3b: bookGoodsReceipt→Stock. Empfohlen bleibt der volle §1-§9-Pfad.
