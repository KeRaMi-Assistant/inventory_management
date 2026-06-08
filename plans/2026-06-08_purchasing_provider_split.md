# Plan: PurchasingProvider-Split (#2 aus der Provider-Decomposition-Roadmap)

**Datum:** 2026-06-08
**Status:** [x] Implemented — §1-§8 done (PurchasingProvider + 12 consumers + tests; `flutter analyze lib/ test/` clean, `flutter test` 966 green, `flutter build web` ok). bookGoodsReceipt stayed in InventoryProvider, importCsvAll 5-tuple unchanged, no backend change, Activity-Log-Gotcha (§7.5) documented inline.
**Quelle:** `understand-purchasing-split`-Workflow (4 parallele Mapper + Synthese), code-anchored.
**Vorgänger-Muster:** PR #120 (CatalogProvider-Split). 1:1 spiegeln.

## Entscheidung
**Full one-PR Split:** `suppliers` + `purchaseOrders` + `purchaseOrderItems` wandern in einen neuen
`lib/providers/purchasing_provider.dart`. Zwei bewusste Kompromisse (wie schon #120):
1. **`bookGoodsReceipt` bleibt in `InventoryProvider`** — schreibt Inventory-State (`_inventoryItems`/`_movements`),
   liest Purchasing (PO-Header-Refresh via Hook).
2. **`importCsvAll` bleibt Orchestrator in `InventoryProvider`** — schreibt Suppliers/POs via public Write-Back-Hooks
   auf PurchasingProvider, FK-Remap-Tabellen bleiben lokal im Orchestrator (sonst korrumpierte Remap-State + redundante notifies).

**Fallback** falls PO/goods-receipt-Seam im Review/Smoke Probleme macht: nur Suppliers shippen (§9), POs als Follow-up.

## 1. Was nach `purchasing_provider.dart` wandert
**Fields:** `_suppliers` (L81), `_purchaseOrders` (L90). (PO-Items sind lazy, kein Field.)
**Getters:** `suppliers` (142), `activeSuppliers` (143-144), `purchaseOrders` (151-152).
**Methods (verbatim, `_log` auf neuen DB-only-`_log` tauschen):** addSupplier (1187), updateSupplier (1196),
deleteSupplier (1207), seedCarrierSuppliers (1222, importiert `carrierSupplierSeeds` aus carrier_service.dart:293),
addPurchaseOrder (1258), updatePurchaseOrder (1266), deletePurchaseOrder (1280), loadPurchaseOrderItems (1295,
liest `_repository.activeWorkspaceId`), addPurchaseOrderItem (1303), updatePurchaseOrderItem (1310),
deletePurchaseOrderItem (1317).
**Bleibt (cross-domain):** `bookGoodsReceipt` (1348-1481), `importCsvAll` (835-1104).

**Klassen-Skelett = `catalog_provider.dart` 1:1:** Konstruktor `({required SupabaseRepository repository})`,
`_uuid`, `_loading/_initialLoadAttempted/_lastError/_disposed/_loadDataInFlight/_activeWorkspaceId`,
in-flight-coalescing `loadData()/_doLoadData()`, `clearLocalState()` (muss `_activeWorkspaceId=null` setzen),
DB-only `_log()` (KEIN in-memory `_activities`-Cache — #120-Gotcha #6, inline dokumentieren), `dispose()`.
`_doLoadData()`: `snapshot=loadAll()`; suppliers sort by name.lower (=Inv 490-491), POs sort by createdAt desc (=Inv 499-500).

## 2. Cross-Domain-Contract
PurchasingProvider liest **nichts** aus anderen Domains → einfacher Single-Dependency-Proxy wie CatalogProvider.
**Inverse (andere schreiben in Purchasing):** public Hooks für InventoryProvider-Orchestratoren:
```dart
List<Supplier> get suppliersRaw => _suppliers;
List<PurchaseOrder> get purchaseOrdersRaw => _purchaseOrders;
void upsertSupplierFromImport(Supplier saved) { _suppliers.add(saved); }
void sortSuppliers() { _suppliers.sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase())); }
void insertPurchaseOrderFromImport(PurchaseOrder saved) { _purchaseOrders.insert(0, saved); }
void sortPurchaseOrders() { _purchaseOrders.sort((a,b)=>b.createdAt.compareTo(a.createdAt)); }
void replacePurchaseOrderHeader(PurchaseOrder fresh) { final i=_purchaseOrders.indexWhere((p)=>p.id==fresh.id); if(i!=-1)_purchaseOrders[i]=fresh; }
void notifyAfterCrossDomainWrite() { if (!_disposed) notifyListeners(); }
```
**Injection in InventoryProvider (Muster wie `updateCatalogProvider` 50-58):**
```dart
PurchasingProvider? _purchasingProvider;
void updatePurchasingProvider(PurchasingProvider? p) => _purchasingProvider = p;
List<Supplier> get _purchSuppliers => _purchasingProvider?.suppliersRaw ?? const [];
List<PurchaseOrder> get _purchPurchaseOrders => _purchasingProvider?.purchaseOrdersRaw ?? const [];
```

## 3. importCsvAll (835-1104) — minimale Edits
1. Supplier-Section (871-885): dedup-seed `_suppliers`→`_purchSuppliers`; `_suppliers.add(saved)`→`upsertSupplierFromImport`;
   `_suppliers.sort` (884)→`sortSuppliers()`. `existingSupplierByName`+`importSupplierIdRemap` (889-893) bleiben lokal.
2. PO-Section (1016-1049): dedup-seed (1017) `_purchaseOrders`→`_purchPurchaseOrders`; `.insert(0,saved)` (1038)→`insertPurchaseOrderFromImport`;
   `.sort` (1049)→`sortPurchaseOrders()`.
3. PO-Item-Section (1052-1075): unverändert (pure repo).
4. Nach Import: `_purchasingProvider?.notifyAfterCrossDomainWrite()` neben catalog-resync (1081) + `notifyListeners()` (1101).
5. **Return-Contract exakt erhalten** — `supplierCount` weiter im Loop gezählt; Tuple-Shape + `main_screen.dart:150`-Destructuring unverändert.

## 4. bookGoodsReceipt (1348-1481) — bleibt InventoryProvider
Step A (1387-1421 `_inventoryItems`), B (1429-1440 `_movements`), C (1443 RPC), D (1458-1473 PO-Header).
Edit Step D (1462-1467): `_purchaseOrders.indexWhere/[idx]=fresh`→`_purchasingProvider?.replacePurchaseOrderHeader(freshPo)`
+ danach `_purchasingProvider?.notifyAfterCrossDomainWrite()`. `loadPurchaseOrderById` (1462) bleibt (repo). `notifyListeners()` (1479) bleibt.
Consumer `purchase_order_detail_screen.dart:123` ruft `bookGoodsReceipt` weiter auf InventoryProvider — braucht jetzt BEIDE Provider.

## 5. main.dart Wiring
- Neue Registration als Sibling von CatalogProvider (vor InventoryProvider): `ChangeNotifierProxyProvider<SupabaseRepository, PurchasingProvider>`.
- InventoryProvider: `ChangeNotifierProxyProvider2`→**`ChangeNotifierProxyProvider3<SupabaseRepository, CatalogProvider, PurchasingProvider, InventoryProvider>`**;
  `update` ruft `previous.updateCatalogProvider(catalog)` UND `previous.updatePurchasingProvider(purchasing)` (Gotcha #4, Pflicht).
- `_hydrate()`: `purchasing.setActiveWorkspace(activeId)` in `Future.wait`.
- `_onWorkspaceChanged()`: `context.read<PurchasingProvider>().setActiveWorkspace(newId)`.
- Sign-out: `context.read<PurchasingProvider>().clearLocalState()`.
- Reihenfolge fragil (Gotcha #5/#9): PurchasingProvider VOR InventoryProvider registrieren.

## 6. Consumer-Migration (12 Files)
- `suppliers_screen.dart` (Consumer<Inv>→Consumer<Purchasing>; deleteSupplier/seedCarrierSuppliers) — clean.
- `purchase_orders_screen.dart` (Consumer2<Inv,Ws>→Consumer2<Purchasing,Ws>; purchaseOrders/suppliers + addPurchaseOrder/addPurchaseOrderItem).
- `purchase_order_detail_screen.dart` — **dual:** loadPurchaseOrderItems/updatePurchaseOrder/deletePurchaseOrder/purchaseOrders/suppliers→Purchasing; **bookGoodsReceipt bleibt Inventory** → beide Provider.of nötig.
- `add_edit_supplier_dialog.dart` (addSupplier/updateSupplier→Purchasing).
- `onboarding_screen.dart` — dual (suppliers→Purchasing, addShop→Inventory).
- `main_screen.dart` `_export` (suppliers/purchaseOrders→Purchasing); **importCsvAll-Call bleibt auf Inventory**.
- `product_detail_screen.dart` — dual (suppliers→Purchasing).
- `statistics_screen.dart` (Consumer3→+Purchasing oder watch; `inv.suppliers`→purchasing). StatisticsService-Signatur unverändert.
- `inventory_screen.dart` — dual (activeSuppliers dropdown→Purchasing).
- `add_edit_product_dialog.dart` (activeSuppliers→Purchasing).
- `global_search_dialog.dart` — multi (suppliers→Purchasing).
- `widgets/statistics/filter_bar.dart` (suppliers dropdown→Purchasing).
- `services/statistics_service.dart` + `services/csv_service.dart`: **keine Änderung** (pure params, Quelle ändert sich beim Caller).

## 7. Risiken (geordnet)
1. Provider-Reihenfolge/ProxyProvider3 dep-order → boot/provider-not-found.
2. `updatePurchasingProvider` muss bei rebuild re-injected werden (sonst stale/null → importCsvAll/bookGoodsReceipt silent no-op).
3. importCsvAll silent data-loss falls `_purchasingProvider` null (early init) — `?? const []` maskiert; `kDebugMode`-assert ergänzen.
4. PO-Header-Status-Staleness nach goods-receipt ohne `replacePurchaseOrderHeader`+notify.
5. Activity-Log-Regression (#120-Gotcha #6) — akzeptiert, dokumentieren.
6. Dual-Provider-Screens (PO-Detail) — doppeltes notify, kein Doppel-Snackbar verifizieren.
7. Disposal-Guards (`if(!_disposed)`).
8. Sign-out clearLocalState + `_activeWorkspaceId=null`.
9. `loadAll()` 3× — akzeptierte Perf-Kosten, Follow-up shared-snapshot.

## 8. Test/Smoke
- `inventory_provider_po_crud_test.dart` → **move/rename** `purchasing_provider_po_crud_test.dart` (PurchasingProvider(repository: fake)).
- `inventory_provider_goods_receipt_test.dart` → PurchasingProvider injecten, POs seeden, assert `replacePurchaseOrderHeader`.
- **NEU** `purchasing_provider_test.dart` (supplier CRUD, seedCarrierSuppliers-Idempotenz, loadData sort, clearLocalState).
- **NEU/erweitern** importCsvAll-Test: 5-Tuple + Write-Back in injizierten PurchasingProvider.
- Gates: `flutter analyze lib/ test/` clean, `flutter test` grün.
- **smoke-full-app-audit (PFLICHT):** PO-Liste, PO-Detail (**goods-receipt → Stock+Movement+quantity_received+PO-Status-Badge**),
  suppliers-screen (delete+seed), supplier-Dropdowns (inventory/product), statistics supplier-filter, global-search supplier,
  onboarding supplier-add, **CSV-Export+Import-Round-Trip (höchstes Risiko: FK-Remap suppliers+products+POs+items)**. Phone 390 zuerst.

## 9. Fallback-Slice (falls full split zu groß): nur Suppliers
`_suppliers`/getters/supplier-CRUD/seedCarrierSuppliers → Purchasing; POs/PO-items/bookGoodsReceipt bleiben Inventory;
nur importCsvAll-Supplier-Section nutzt Hook. PO-Screens unberührt. Slice 2 = POs+PO-items+goods-receipt-Seam. Slice 3 = CsvImportService.
