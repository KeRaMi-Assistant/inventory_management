import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_entry.dart';
import '../models/inventory_batch.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
import '../models/product_stock.dart';
import '../models/purchase_order_item.dart';
import '../models/stocktake.dart';
import '../models/stocktake_item.dart';
import '../models/warehouse.dart';
import '../services/supabase_repository.dart';
import 'catalog_provider.dart';
import 'purchasing_provider.dart';

/// Holds the stock/inventory domain state for the signed-in user:
/// [InventoryItem] + [InventoryMovement] lists, [Warehouse]s, [Stocktake]
/// sessions and the aggregated [ProductStock] view. `stocktake_items` and
/// `inventory_batches` are NOT held globally — they are loaded lazily per
/// detail-screen via [loadStocktakeItems] / [loadBatchesForItem] (mirrors the
/// `loadPurchaseOrderItems` pattern in [PurchasingProvider]). All mutations are
/// routed through [SupabaseRepository]; local lists are caches kept in sync
/// with the server.
///
/// Extracted from [DealsProvider] as the third provider-split increment
/// (after [CatalogProvider] PR #120 and [PurchasingProvider] PR #128).
/// Registers as a [ChangeNotifierProxyProvider3<SupabaseRepository,
/// CatalogProvider, PurchasingProvider, StockProvider>] in `main.dart`, AFTER
/// [CatalogProvider] + [PurchasingProvider] and BEFORE [DealsProvider]
/// (registration order = dependency order — the provider graph is a strict DAG:
/// `Stock → Catalog`, `Stock → Purchasing`, `Inventory → Stock`).
///
/// **Cross-domain reads:** [criticalStockCount] reads `products.min_stock` from
/// the injected [CatalogProvider]; `bookGoodsReceipt` reads the product name/sku
/// from it too. The injected [PurchasingProvider] is used by `bookGoodsReceipt`
/// to refresh the affected PO header in-place after a goods-receipt
/// ([PurchasingProvider.replacePurchaseOrderHeader] +
/// [PurchasingProvider.notifyAfterCrossDomainWrite]).
///
/// **Cross-domain writes INTO this provider:** the two orchestrators that stay
/// in [DealsProvider] — `importCsvAll` and `checkInDeal` — write warehouses,
/// inventory items and movements here through the public write-back hooks below
/// ([warehousesRaw], [inventoryItemsRaw], [upsertWarehouseFromImport],
/// [upsertInventoryItemFromImport], [insertMovementFromCheckIn], [sortWarehouses],
/// [sortInventoryItems], [notifyAfterCrossDomainWrite]). Keeping those
/// orchestrators on [DealsProvider] (and writing INTO stock via hooks)
/// avoids a `Stock → Inventory` edge that would create a dependency cycle
/// (plan §3 Option A).
class StockProvider extends ChangeNotifier {
  StockProvider({
    required SupabaseRepository repository,
    CatalogProvider? catalogProvider,
    PurchasingProvider? purchasingProvider,
  })  : _repository = repository,
        _catalogProvider = catalogProvider,
        _purchasingProvider = purchasingProvider;

  final SupabaseRepository _repository;
  final _uuid = const Uuid();

  CatalogProvider? _catalogProvider;
  PurchasingProvider? _purchasingProvider;

  /// Called by [ChangeNotifierProxyProvider3] in `main.dart` whenever the
  /// upstream [CatalogProvider] instance is replaced. Safe to call repeatedly
  /// with the same instance. MUST be re-injected on every rebuild — otherwise
  /// [criticalStockCount] / `bookGoodsReceipt` would read against a stale/null
  /// reference (Gotcha #4).
  void updateCatalogProvider(CatalogProvider? catalog) {
    _catalogProvider = catalog;
    // No notifyListeners() here — listeners that need products read via the
    // CatalogProvider directly; StockProvider only uses the reference for
    // internal cross-domain reads (criticalStockCount, bookGoodsReceipt).
  }

  /// Called by [ChangeNotifierProxyProvider3] in `main.dart` whenever the
  /// upstream [PurchasingProvider] instance is replaced. Safe to call
  /// repeatedly with the same instance. MUST be re-injected on every rebuild
  /// (Gotcha #4) — otherwise `bookGoodsReceipt`'s PO-header refresh silently
  /// no-ops against a stale/null reference.
  void updatePurchasingProvider(PurchasingProvider? purchasing) {
    _purchasingProvider = purchasing;
    // No notifyListeners() here — PO state is read via the PurchasingProvider
    // directly; StockProvider only uses the reference for the cross-domain
    // PO-header refresh in bookGoodsReceipt.
  }

  /// Convenience read — returns the product list from [CatalogProvider] if
  /// available, otherwise an empty list. The `?? const []` masks an early-init
  /// null reference; cross-domain reads degrade gracefully (KPIs show 0 rather
  /// than crashing).
  List<Product> get _catalogProducts => _catalogProvider?.products ?? const [];

  List<InventoryItem> _inventoryItems = [];
  List<InventoryMovement> _movements = [];

  /// Lager (Epic D — Mehrlager). Klein und workspace-weit relevant, daher
  /// global gehalten (Committee-Empfehlung 1, analog `_productCategories`).
  List<Warehouse> _warehouses = [];

  /// Inventur-Sessions (Epic E). Klein und workspace-weit relevant, daher
  /// global gehalten. `stocktake_items` werden lazy pro Detail-Screen geladen
  /// (Pattern wie `_purchaseOrders`/`loadPurchaseOrderItems`).
  List<Stocktake> _stocktakes = [];

  /// Aggregierter Lagerbestand aus dem DB-View `product_stock` (Epic A-full,
  /// read-only). Jede Row = Bestand eines Produkts pro Lager. Wird in
  /// [loadData] nach [SupabaseRepository.loadAll] geladen — der View ist klein
  /// (workspace-weit) und wird für KPI-Aggregation in [criticalStockCount]
  /// benötigt.
  List<ProductStock> _productStock = [];

  bool _loading = false;
  bool _initialLoadAttempted = false;
  Object? _lastError;
  // Gesetzt in dispose() — alle async-Continuations prüfen dieses Flag
  // vor notifyListeners(), um post-dispose-Notifies zu verhindern.
  bool _disposed = false;

  /// In-flight load guard — coalesces concurrent [loadData] calls.
  Future<void>? _loadDataInFlight;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isLoading => _loading;

  /// True as soon as the first [loadData] call has returned.
  bool get initialLoadAttempted => _initialLoadAttempted;

  Object? get lastError => _lastError;

  List<InventoryItem> get inventoryItems => List.unmodifiable(_inventoryItems);
  List<InventoryMovement> get movements => List.unmodifiable(_movements);

  /// Lager des aktiven Workspaces, alphabetisch nach Name sortiert.
  /// Das Default-Lager (falls vorhanden) ist via `w.isDefault` erkennbar.
  List<Warehouse> get warehouses => List.unmodifiable(_warehouses);

  /// Gibt das Default-Lager zurück, oder `null` falls keins vorhanden.
  Warehouse? get defaultWarehouse =>
      _warehouses.where((w) => w.isDefault).firstOrNull;

  /// Inventur-Sessions des aktiven Workspaces, absteigend nach Erstellungsdatum.
  List<Stocktake> get stocktakes => List.unmodifiable(_stocktakes);

  /// Aggregierter Lagerbestand pro Produkt/Lager aus dem View `product_stock`.
  /// Nur Rows mit `product_id IS NOT NULL` — nicht-verknüpfte Items fehlen
  /// hier bewusst (sie fallen nicht in den View). Für KPI-Nutzung in
  /// [criticalStockCount] und im Produkt-Detail-Screen (AF12).
  List<ProductStock> get productStock => List.unmodifiable(_productStock);

  // ── Derived KPIs ──────────────────────────────────────────────────────────

  /// Anzahl der Artikel/Produkte, deren Gesamtbestand unter dem Mindestbestand
  /// liegt (Kritisch-Bewertung).
  ///
  /// **Aggregations-Logik (Epic A-full / Committee-Finding 9):**
  /// - Produkt-verknüpfte Items (`product_id != null`) werden pro Produkt
  ///   aggregiert: Gesamtbestand = Summe aller `product_stock.qty_in_warehouse`
  ///   über alle Lager eines Produkts. Verglichen wird gegen
  ///   `products.min_stock` (gelesen aus dem injizierten [CatalogProvider]).
  ///   Ein Produkt zählt genau einmal — auch wenn es mehrere
  ///   `inventory_items`-Rows hat (z. B. unterschiedliche Lager/Chargen).
  ///   Dies verhindert überhöhte KPI-Werte (Regressions-Schutz Committee-Bug #9).
  /// - Nicht-verknüpfte Items (`product_id == null`) behalten die Item-Level-
  ///   Logik: `item.isCritical` (`quantity < minStock`) — jede Row für sich,
  ///   da kein Produkt-Mindestbestand vorhanden ist.
  /// - Gesamtwert = (kritische Produkte) + (kritische nicht-verknüpfte Items).
  ///
  /// Solange `_productStock` leer ist (View noch nicht geladen oder kein aktiver
  /// Workspace), fällt die Logik für alle Items auf Item-Level zurück (Safe
  /// Fallback).
  int get criticalStockCount {
    // 1. Aggregierten Bestand pro Produkt aus product_stock aufbauen.
    //    productId → Gesamtbestand über alle Lager/Rows.
    final Map<String, int> totalByProduct = {};
    for (final stock in _productStock) {
      totalByProduct.update(
        stock.productId,
        (existing) => existing + stock.qtyInWarehouse,
        ifAbsent: () => stock.qtyInWarehouse,
      );
    }

    // 2. Produkte mit aggregiertem Bestand < min_stock zählen.
    //    Nur Produkte, für die auch mindestens eine product_stock-Row existiert,
    //    werden hier berücksichtigt — Produkte ohne jegliche Bestands-Rows haben
    //    implizit qty = 0, aber der View gibt sie nicht zurück (sie fehlen im
    //    View, da alle Bestands-Rows deleted_at haben oder keine existieren).
    //    Das ist akzeptabel: 0 Bestand bei 0 Mindestbestand = nicht kritisch;
    //    und Produkte mit echter min_stock-Anforderung aber ohne Bestands-Rows
    //    werden in D4 (Low-Stock-Alerts) separat behandelt.
    final products = _catalogProducts;
    final productIds = products.map((p) => p.id).toSet();
    final productMinStock = <String, int>{
      for (final p in products) p.id: p.minStock,
    };

    int criticalProductCount = 0;
    final countedProductIds = <String>{};
    for (final productId in totalByProduct.keys) {
      // Nur zählen wenn das Produkt noch im lokalen Cache ist (nicht gelöscht).
      if (!productIds.contains(productId)) continue;
      if (countedProductIds.contains(productId)) continue;
      countedProductIds.add(productId);

      final totalQty = totalByProduct[productId] ?? 0;
      final minStock = productMinStock[productId] ?? 0;
      if (totalQty < minStock) {
        criticalProductCount++;
      }
    }

    // 3. Nicht-verknüpfte Items (product_id == null) → Item-Level-Logik.
    //    isCritical ist für diese Items die korrekte Wahrheit.
    final criticalUnlinkedCount = _inventoryItems
        .where((item) => item.productId == null && item.isCritical)
        .length;

    return criticalProductCount + criticalUnlinkedCount;
  }

  /// Gesamtmenge aller Lagerartikel (Summe aller `inventory_items.quantity`).
  ///
  /// `quantity` ist die physische Wahrheit pro Bestands-Row — die Summierung
  /// hier ist korrekt. Nur die *kritisch*-Bewertung muss aggregieren (per
  /// Produkt), die Gesamtmenge nicht. Enthält auch nicht-verknüpfte Rows.
  int get totalStockQuantity =>
      _inventoryItems.fold(0, (sum, item) => sum + item.quantity);

  double get totalStockValue =>
      _inventoryItems.fold(0, (sum, item) => sum + item.stockValue);

  // ── Cross-domain write-back hooks ─────────────────────────────────────────
  // Public surface for the DealsProvider orchestrators (importCsvAll,
  // checkInDeal) that must write into stock state while keeping their FK-remap /
  // deal-link tables local. Raw (non-copied) reads are intentional — the
  // orchestrator builds dedup-seed sets from them and must observe the same
  // backing list the import then mutates via the insert hooks below. Mirrors
  // the PurchasingProvider hook surface (purchasing_provider.dart §78-127).

  /// Raw (uncopied) warehouse list for dedup-seed lookups in import orchestrators.
  List<Warehouse> get warehousesRaw => _warehouses;

  /// Raw (uncopied) inventory-item list for dedup-seed lookups in import
  /// orchestrators.
  List<InventoryItem> get inventoryItemsRaw => _inventoryItems;

  /// Appends an import-saved warehouse. Caller re-sorts via [sortWarehouses] and
  /// notifies via [notifyAfterCrossDomainWrite] once the batch completes.
  void upsertWarehouseFromImport(Warehouse saved) {
    _warehouses.add(saved);
  }

  /// Appends an import-saved inventory item. Caller re-sorts via
  /// [sortInventoryItems] and notifies via [notifyAfterCrossDomainWrite] later.
  void upsertInventoryItemFromImport(InventoryItem saved) {
    _inventoryItems.add(saved);
  }

  /// Inserts a check-in movement at the front (newest-first). Used by
  /// `checkInDeal` after it has written the item via [upsertInventoryItemFromImport].
  void insertMovementFromCheckIn(InventoryMovement movement) {
    _movements.insert(0, movement);
  }

  /// Re-sorts warehouses by lowercased name (= load-time order). Called by the
  /// import orchestrator after a warehouse batch.
  void sortWarehouses() {
    _warehouses
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Re-sorts inventory items by name (= load-time order).
  void sortInventoryItems() {
    _inventoryItems.sort((a, b) => a.name.compareTo(b.name));
  }

  /// notifyListeners() guarded by [_disposed] — used by cross-domain
  /// orchestrators after they have mutated stock state via the hooks above.
  void notifyAfterCrossDomainWrite() {
    if (!_disposed) notifyListeners();
  }

  // ── Workspace lifecycle ───────────────────────────────────────────────────

  String? _activeWorkspaceId;

  /// Called by [_AuthGateState._onWorkspaceChanged] whenever the active
  /// workspace changes — mirrors the pattern in [CatalogProvider] /
  /// [PurchasingProvider] / [DealsProvider].
  Future<void> setActiveWorkspace(String? workspaceId) async {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    // Den geteilten Repo-Workspace setzen BEVOR loadData/loadAll läuft — sonst
    // liest loadAll() einen null-Workspace und liefert still einen LEEREN
    // Snapshot (supabase_repository.dart:192-195). In main._hydrate laufen
    // Catalog/Purchasing/Stock/Inventory parallel via Future.wait; ohne dieses
    // Set verliert Stock das Race → Items/Warehouses landen leer. (PR #128)
    _repository.setActiveWorkspace(workspaceId);
    if (workspaceId == null) {
      clearLocalState();
      return;
    }
    await loadData();
  }

  Future<void> loadData() {
    if (_loadDataInFlight != null) return _loadDataInFlight!;
    _loadDataInFlight = _doLoadData();
    return _loadDataInFlight!;
  }

  Future<void> _doLoadData() async {
    _loading = true;
    _lastError = null;
    if (!_disposed) notifyListeners();
    try {
      // Workspace-ID aus dem Repository holen (Single Source of Truth):
      // `_repository.activeWorkspaceId` ist auch für Test-Fakes korrekt
      // befüllt, während `_activeWorkspaceId` bei direkten `loadData()`-
      // Aufrufen (ohne vorangehendes `setActiveWorkspace`) null sein kann.
      final wsId = _repository.activeWorkspaceId ?? _activeWorkspaceId;

      final snapshot = await _repository.loadAll();
      // Sort order mirrors the original DealsProvider._hydrateFrom:
      //   items by name; movements/stocktakes desc by date; warehouses by
      //   lowercased name.
      _inventoryItems = List.of(snapshot.inventoryItems)
        ..sort((a, b) => a.name.compareTo(b.name));
      _movements = List.of(snapshot.movements)
        ..sort((a, b) => b.date.compareTo(a.date));
      _warehouses = List.of(snapshot.warehouses)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _stocktakes = List.of(snapshot.stocktakes)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Default-Lager-Bootstrap: Wenn der Workspace noch kein Lager hat,
      // wird automatisch ein "Hauptlager" angelegt. Runs defensiv — ein
      // Fehler (z. B. Race zwischen zwei Clients oder fehlende DB-Tabelle
      // vor D1-Migration) bricht den Load nicht ab.
      if (_warehouses.isEmpty && wsId != null) {
        try {
          await _bootstrapDefaultWarehouse();
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'StockProvider: Default-Lager-Bootstrap fehlgeschlagen '
              '(non-fatal): $e',
            );
          }
        }
      }

      // product_stock separat laden — read-only View, kann defensiv fehlschlagen.
      // Fehler (z. B. fehlende Implementierung in Test-Fakes oder Netzwerkfehler)
      // fallen auf einen leeren Cache zurück; die App bleibt nutzbar, nur die
      // Produkt-aggregierten KPIs (criticalStockCount für verknüpfte Produkte)
      // zeigen 0 statt korrekter Werte.
      if (wsId != null) {
        try {
          _productStock = await _repository.loadProductStock(wsId);
        } catch (e) {
          _productStock = [];
          if (kDebugMode) {
            debugPrint('StockProvider: product_stock konnte nicht geladen '
                'werden (non-fatal): $e');
          }
        }
      } else {
        _productStock = [];
      }
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('StockProvider.loadData failed: $e');
    } finally {
      _loading = false;
      _initialLoadAttempted = true;
      _loadDataInFlight = null;
      if (!_disposed) notifyListeners();
    }
  }

  /// Wipes local caches — used on sign-out so the next user starts clean.
  void clearLocalState() {
    _inventoryItems = [];
    _movements = [];
    _warehouses = [];
    _stocktakes = [];
    _productStock = [];
    _lastError = null;
    _initialLoadAttempted = false;
    _activeWorkspaceId = null;
    if (!_disposed) notifyListeners();
  }

  /// Lädt das `product_stock`-Aggregat (View `qtyInWarehouse`) neu, nachdem
  /// eine mengen-mutierende Operation (closeStocktake / bookGoodsReceipt /
  /// adjustStock) `inventory_items.quantity` geändert hat. Ohne diesen Refresh
  /// zeigte z.B. die Produkt-Detail-Box „Gesamtbestand" einen Stale-Wert, weil
  /// nur `_inventoryItems`/`_movements` aktualisiert wurden, nicht das Aggregat.
  /// Defensiv: schlägt der Reload fehl, bleibt der bisherige Cache erhalten.
  Future<void> _refreshProductStock() async {
    final wsId = _repository.activeWorkspaceId ?? _activeWorkspaceId;
    if (wsId == null) return;
    try {
      _productStock = await _repository.loadProductStock(wsId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StockProvider._refreshProductStock failed (non-fatal): $e');
      }
    }
  }

  // ── Activity helper ───────────────────────────────────────────────────────

  /// Fire-and-forget activity log. Writes directly to the DB via the
  /// repository — DB-ONLY, with NO in-memory `_activities` cache.
  ///
  /// **Gotcha (PR #120 §7.5, intentional):** The original `_log` in
  /// [DealsProvider] also prepended the entry to an in-memory `_activities`
  /// list that the dashboard's recent-activity widget reads. Stock activities
  /// (warehouse/item/movement/stocktake/goods-receipt) logged here therefore no
  /// longer appear instantly in that in-memory list — they surface only after
  /// the next DB load (the activity screen loads from DB anyway). This is an
  /// accepted, documented behavioural regression scoped to stock activity
  /// entries; see plan §5.
  void _log(String message, String type) {
    final entry = ActivityEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      message: message,
      type: type,
    );
    unawaited(_repository.insertActivity(entry).catchError((Object e) {
      if (kDebugMode) {
        debugPrint('StockProvider: activity_log insert failed: $e');
      }
      return entry;
    }));
  }

  /// Legt beim ersten Workspace-Touch ein Default-Lager an, falls noch keins
  /// existiert. Wird defensiv aufgerufen — Fehler werden geloggt, nicht
  /// geworfen.
  ///
  /// **Name:** "Hauptlager" ist ein fester Bootstrap-String ohne l10n, da
  /// der Provider keinen `BuildContext` hat und `AppLocalizations` hier nicht
  /// nutzbar ist. Der Plan (D3) erlaubt das explizit und dokumentiert die
  /// Entscheidung: der User kann den Namen nach dem Anlegen umbenennen.
  /// Das DB-Partial-UNIQUE-Constraint garantiert, dass auch bei einem Race
  /// zwischen zwei Clients maximal ein Default-Lager entsteht — ein zweiter
  /// Insert würde mit 23505 fehlschlagen und wird hier silently ignoriert.
  Future<void> _bootstrapDefaultWarehouse() async {
    // Doppelter Guard: nur wenn die lokale Liste wirklich leer ist.
    if (_warehouses.isNotEmpty) return;
    final ws = _repository.activeWorkspaceId;
    if (ws == null) return;

    final defaultWarehouse = Warehouse(
      id: _uuid.v4(),
      workspaceId: ws,
      userId: '', // wird im Repository durch _userId ersetzt
      name: 'Hauptlager',
      isDefault: true,
      isActive: true,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    try {
      final saved = await _repository.insertWarehouse(defaultWarehouse);
      _warehouses.add(saved);
      _warehouses
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _log('Standard-Lager angelegt: ${saved.name}', 'warehouse');
      if (!_disposed) notifyListeners();
    } catch (e) {
      // Race (23505 Unique-Violation auf is_default) oder fehlende Tabelle
      // (vor D1-Migration) — beide Fälle sind nicht-fatal.
      if (kDebugMode) {
        debugPrint('StockProvider._bootstrapDefaultWarehouse: $e');
      }
      // Versuch, das bereits existierende Lager zu laden (falls Race).
      try {
        final existing = await _repository.loadWarehouses(ws);
        _warehouses = existing;
        _warehouses.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (!_disposed) notifyListeners();
      } catch (_) {
        // Auch der Fallback-Load schlägt fehl (z. B. Tabelle existiert
        // noch nicht) — ignorieren, App bleibt ohne Lager nutzbar.
      }
    }
  }

  // ── WARENEINGANG BUCHEN (C4) ──────────────────────────────────────────────

  /// Bucht einen Wareneingang gegen eine Bestellposition.
  ///
  /// Pro Aufruf:
  ///
  /// 1. **Atomares Increment** von `purchase_order_items.quantity_received`
  ///    via SECURITY-DEFINER-RPC `increment_po_item_received` —
  ///    kein Read-modify-write (Committee-Finding 12, Risiko 7).
  ///    Der DB-Status-Trigger (`purchase_order_items_status_trg`) pflegt
  ///    `purchase_orders.status` automatisch; die App setzt den Status
  ///    NICHT manuell.
  ///
  /// 2. **`goods_in`-Movement** für das verknüpfte `product_id` der
  ///    Bestellposition, mit `unitCost` aus `unit_price` der Position.
  ///
  /// 3. **Bestandserhöhung**: Sucht eine aktive `inventory_items`-Row für
  ///    das Produkt in `_inventoryItems` (lokaler Cache). Findet sie:
  ///    erhöht via `updateInventoryItem`. Findet sie nicht: legt eine
  ///    schlanke neue Row an (`insertInventoryItem`).
  ///
  /// Wirft, wenn `item.productId == null` (PO-Position ohne verknüpftes
  /// Produkt), wenn `receivedQty <= 0`, oder wenn die RPC fehlschlägt.
  ///
  /// **Cross-domain (plan §4):** liest den Produktnamen aus dem injizierten
  /// [CatalogProvider]; refresht den PO-Header im injizierten
  /// [PurchasingProvider] (Phase D, best-effort).
  Future<PurchaseOrderItem> bookGoodsReceipt({
    required PurchaseOrderItem item,
    required int receivedQty,
  }) async {
    if (receivedQty <= 0) {
      throw ArgumentError.value(
          receivedQty, 'receivedQty', 'Menge muss > 0 sein.');
    }
    final productId = item.productId;
    if (productId == null) {
      throw ArgumentError(
          'bookGoodsReceipt: PurchaseOrderItem hat keine product_id — '
          'Wareneingang ohne Produkt-Verknüpfung nicht möglich.');
    }
    // Defensiv (wie importCsvAll): macht eine fehlende Cross-Domain-Injection
    // im Debug-Build laut, statt den PO-Header-Refresh still per `?.` zu
    // verschlucken (Gotcha #4 — updatePurchasingProvider muss bei jedem Rebuild
    // re-injizieren). Release-Build degradiert best-effort (Wareneingang
    // persistiert, PO-Header bleibt ggf. stale bis zum nächsten Load).
    assert(
      _purchasingProvider != null,
      'bookGoodsReceipt: _purchasingProvider ist null — PO-Header-Refresh würde '
      'still no-op. ChangeNotifierProxyProvider3-Wiring in main.dart prüfen.',
    );

    // Reihenfolge (Konsistenz-Begründung):
    //   A. inventory_items-Row auflösen ODER neu anlegen → liefert gültige
    //      inventory_items.id für den FK in inventory_movements.item_id.
    //   B. goods_in-Movement mit der gültigen inventory_items.id schreiben.
    //   C. Atomares Increment von purchase_order_items.quantity_received via RPC.
    //
    // Begründung der Reihenfolge A→B→C:
    //   - inventory_movements.item_id REFERENCES public.inventory_items(id) NOT NULL.
    //     Das Movement darf ERST nach der existierenden/neu angelegten Row
    //     geschrieben werden — sonst FK-Verletzung (HTTP 409).
    //   - Fällt C (RPC) nach B aus, existiert das Movement, aber quantity_received
    //     ist nicht erhöht. Das ist ein Partial-Failure, aber kein Datenverlust:
    //     quantity_received kann retrograd korrigiert werden; ein Movement ohne
    //     Bestandszeile wäre schwerer zu reparieren.
    //   - Fällt B (Movement) aus, ist nur die Bestands-Row angelegt. Benigne —
    //     kein FK-Schaden, Bestand ist korrekt, Movement fehlt (Audit-Lücke,
    //     aber kein Datenfehler).
    //   - Ein echter Transaktions-Wrapper über alle 3 Schritte ist clientseitig
    //     nicht möglich; die Reihenfolge minimiert den worst-case-Schaden.
    //
    // _inventoryItems enthält nur aktive Items (deleted_at IS NULL ist beim
    // Load bereits gefiltert).

    // ── A. inventory_items-Row auflösen oder anlegen ─────────────────────────
    final existingItemForProduct =
        _inventoryItems.where((i) => i.productId == productId).firstOrNull;

    final InventoryItem savedInventory;
    if (existingItemForProduct != null) {
      // Bestehende Row: Bestand jetzt erhöhen, ID ist bereits gültig.
      final updatedInventoryItem = existingItemForProduct.copyWith(
        quantity: existingItemForProduct.quantity + receivedQty,
      );
      savedInventory =
          await _repository.updateInventoryItem(updatedInventoryItem);
      final idx = _inventoryItems.indexWhere((i) => i.id == savedInventory.id);
      if (idx != -1) {
        _inventoryItems[idx] = savedInventory;
      }
    } else {
      // Keine existierende Bestands-Row für dieses Produkt →
      // schlanke neue Row anlegen. Produktname aus dem Catalog-Cache auflösen.
      final product =
          _catalogProducts.where((p) => p.id == productId).firstOrNull;
      final newItem = InventoryItem(
        id: _uuid.v4(),
        name: product?.name ?? productId,
        sku: product?.sku,
        quantity: receivedQty,
        minStock: product?.minStock ?? 0,
        costPrice: item.unitPrice,
        arrivalDate: DateTime.now(),
        status: 'Im Lager',
        productId: productId,
      );
      savedInventory = await _repository.insertInventoryItem(newItem);
      _inventoryItems.add(savedInventory);
      _inventoryItems.sort((a, b) => a.name.compareTo(b.name));
    }

    // ── B. goods_in-Movement mit der GÜLTIGEN inventory_items.id schreiben ───
    //    savedInventory.id ist immer eine gültige inventory_items-ID —
    //    entweder die bestehende Row oder die soeben angelegte neue Row.
    //    NIEMALS item.id (= purchase_order_items-ID) verwenden, da
    //    inventory_movements.item_id → inventory_items(id) referenziert.
    final movement = InventoryMovement(
      id: _uuid.v4(),
      itemId: savedInventory.id,
      date: DateTime.now(),
      quantityChange: receivedQty,
      reason: 'Wareneingang gegen Bestellung',
      movementType: InventoryMovementType.goodsIn,
      unitCost: item.unitPrice,
      productId: productId,
    );
    final savedMovement = await _repository.insertMovement(movement);
    _movements.insert(0, savedMovement);

    // ── C. Atomares Increment auf der Datenbank-Seite (purchase_order_items) ─
    final updatedItem =
        await _repository.incrementPoItemReceived(item.id, receivedQty);

    // ── D. PO-Header-Refresh (Best-Effort) ──────────────────────────────────
    // Der DB-Trigger `purchase_order_items_status_trg` aktualisiert serverseitig
    // `purchase_orders.status` (z. B. `ordered` → `partially_received` →
    // `received`). Da der PO-Header-Cache in [PurchasingProvider] liegt,
    // spiegelt dessen lokaler State den neuen Status erst nach einem App-Reload
    // wider — ohne diesen Re-Fetch.
    //
    // Strategie: den betroffenen PO-Header-Eintrag gezielt neu laden und im
    // PurchasingProvider-Cache ersetzen ([PurchasingProvider.replacePurchaseOrderHeader])
    // + dort notifizieren ([PurchasingProvider.notifyAfterCrossDomainWrite]).
    // Schlägt der Re-Fetch fehl (Netzwerk, PO zwischenzeitlich gelöscht), bleibt
    // der bereits gebuchte Wareneingang bestehen — kein Fehler, kein Rollback.
    // Der UI-State korrigiert sich beim nächsten regulären Load.
    final poId = item.purchaseOrderId;
    final wsId = _repository.activeWorkspaceId;
    if (poId != null && wsId != null) {
      try {
        final freshPo = await _repository.loadPurchaseOrderById(wsId, poId);
        if (freshPo != null) {
          _purchasingProvider?.replacePurchaseOrderHeader(freshPo);
          _purchasingProvider?.notifyAfterCrossDomainWrite();
        }
      } catch (_) {
        // Best-Effort: Re-Fetch-Fehler still schlucken.
        // Der Buchungs-Erfolg ist bereits abgeschlossen.
      }
    }

    _log(
      'Wareneingang gebucht: +$receivedQty für Produkt $productId',
      'purchase_order',
    );
    await _refreshProductStock();
    if (!_disposed) notifyListeners();
    return updatedItem;
  }

  // ── WAREHOUSES ────────────────────────────────────────────────────────────

  Future<void> addWarehouse(Warehouse warehouse) async {
    final saved = await _repository.insertWarehouse(warehouse);
    _warehouses.add(saved);
    _warehouses
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Lager hinzugefügt: ${saved.name}', 'warehouse');
    if (!_disposed) notifyListeners();
  }

  Future<void> updateWarehouse(Warehouse warehouse) async {
    final saved = await _repository.updateWarehouse(warehouse);
    final idx = _warehouses.indexWhere((w) => w.id == saved.id);
    if (idx == -1) return;
    _warehouses[idx] = saved;
    _warehouses
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Lager aktualisiert: ${saved.name}', 'warehouse');
    if (!_disposed) notifyListeners();
  }

  Future<void> deleteWarehouse(String id) async {
    final warehouse = _warehouses.where((w) => w.id == id).firstOrNull;
    await _repository.deleteWarehouse(id);
    _warehouses.removeWhere((w) => w.id == id);
    if (warehouse != null) {
      _log('Lager gelöscht: ${warehouse.name}', 'warehouse');
    }
    if (!_disposed) notifyListeners();
  }

  // ── STOCKTAKES (Inventur — Epic E) ───────────────────────────────────────

  /// Legt eine neue Inventur-Session an und erzeugt sofort den Soll-Snapshot
  /// als `stocktake_items`-Rows.
  ///
  /// Der Soll-Snapshot aggregiert den aktuellen Bestand pro Produkt aus
  /// `_productStock`. Ist `warehouseId` gesetzt, werden nur Produkte
  /// berücksichtigt, die in diesem Lager Bestand haben. Andernfalls werden
  /// alle Produkte mit Bestand > 0 eingeschlossen.
  ///
  /// Jede `stocktake_items`-Row erhält `counted_qty = null` (noch nicht gezählt).
  ///
  /// Gibt die gespeicherte [Stocktake] zurück (mit server-seitig vergebenem
  /// BIGSERIAL-`id`). Die zugehörigen [StocktakeItem]s werden **nicht** im
  /// globalen Provider-State gehalten — sie werden lazy im Detail-Screen
  /// verwaltet.
  Future<Stocktake> startInventory({
    String? warehouseId,
    String? title,
  }) async {
    final ws = _repository.activeWorkspaceId;
    if (ws == null) {
      throw StateError('startInventory: kein aktiver Workspace gesetzt.');
    }

    final now = DateTime.now().toUtc();

    // 1. Stocktake-Kopf anlegen.
    final stocktake = Stocktake(
      workspaceId: ws,
      userId: '', // wird im Repository durch _userId ersetzt
      warehouseId: warehouseId,
      status: StocktakeStatus.counting,
      title: title,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final savedStocktake = await _repository.insertStocktake(stocktake);
    _stocktakes.insert(0, savedStocktake);
    _stocktakes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!_disposed) notifyListeners();

    // 2. Soll-Snapshot als stocktake_items erzeugen.
    //    Bestand pro Produkt aggregieren (Summe aller productStock-Rows mit
    //    gleicher productId, optional gefiltert nach warehouseId).
    final stockByProduct = <String, int>{};
    for (final stock in _productStock) {
      if (warehouseId != null && stock.warehouseId != warehouseId) continue;
      stockByProduct.update(
        stock.productId,
        (existing) => existing + stock.qtyInWarehouse,
        ifAbsent: () => stock.qtyInWarehouse,
      );
    }

    // Nur Produkte mit Bestand > 0 einschließen.
    final stocktakeId = savedStocktake.id;
    if (stocktakeId != null) {
      for (final entry in stockByProduct.entries) {
        if (entry.value <= 0) continue;
        final item = StocktakeItem(
          id: _uuid.v4(),
          workspaceId: ws,
          stocktakeId: stocktakeId,
          productId: entry.key,
          expectedQty: entry.value,
          countedQty: null,
          createdAt: now,
          updatedAt: now,
        );
        // Fehler beim Anlegen eines einzelnen Items sind nicht fatal —
        // der Benutzer kann fehlende Items manuell ergänzen.
        try {
          await _repository.insertStocktakeItem(item);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('startInventory: StocktakeItem für Produkt ${entry.key} '
                'konnte nicht angelegt werden: $e');
          }
        }
      }
    }

    _log('Inventur gestartet: ${savedStocktake.title ?? savedStocktake.id}',
        'stocktake');
    return savedStocktake;
  }

  /// Setzt `counted_qty` einer Inventur-Position und persistiert sofort
  /// (inkrementelles Speichern — kein Verbindungsabbruch verliert Daten).
  ///
  /// Bei einem Netzwerkfehler bleibt der lokale Wert in [item] erhalten
  /// (der Caller hält das aktualisierte Objekt); der Fehler wird sauber
  /// als Exception nach oben weitergegeben, damit der UI-Layer ihn anzeigen
  /// kann. Die App crasht nicht.
  ///
  /// Gibt das server-seitig gespeicherte [StocktakeItem] zurück, oder
  /// wirft bei einem dauerhaften Fehler.
  Future<StocktakeItem> countStocktakeItem(
    StocktakeItem item,
    int countedQty,
  ) async {
    final updated = item.copyWith(countedQty: countedQty);
    final saved = await _repository.updateStocktakeItem(updated);
    _log('Inventur-Zählung: Produkt ${item.productId} → $countedQty',
        'stocktake');
    return saved;
  }

  /// Schließt eine Inventur-Session ab.
  ///
  /// Pro Position mit einer Differenz (`counted_qty != expected_qty`) wird
  /// eine `inventory_movements`-Row mit `movement_type = stocktake`
  /// geschrieben (append-only — nur INSERT). Die Differenzmenge ist
  /// `counted_qty - expected_qty`.
  ///
  /// Außerdem wird der tatsächliche Bestand der betroffenen
  /// `inventory_items`-Rows angeglichen: Die erste Bestands-Row des Produkts
  /// (aus `_inventoryItems`) wird auf den gezählten Wert korrigiert.
  ///
  /// Positions ohne gezählte Menge (`counted_qty == null`) werden
  /// übersprungen (noch nicht gezählt → keine Buchung).
  ///
  /// Setzt abschließend `stocktakes.status = 'closed'` und `closed_at`.
  Future<Stocktake> closeStocktake(
    Stocktake stocktake,
    List<StocktakeItem> items,
  ) async {
    final stocktakeId = stocktake.id;
    if (stocktakeId == null) {
      throw ArgumentError('closeStocktake: Stocktake hat keine id.');
    }
    final ws = _repository.activeWorkspaceId;
    if (ws == null) {
      throw StateError('closeStocktake: kein aktiver Workspace gesetzt.');
    }

    // Idempotenz-Guard: bereits abgeschlossene Inventuren nicht nochmals buchen.
    // Verhindert Doppel-Buchung bei Doppel-Tap oder Retry.
    if (stocktake.status == StocktakeStatus.closed) {
      return stocktake;
    }

    final now = DateTime.now().toUtc();

    // 1. Pro gezählte Position mit Differenz: Differenz-Movement schreiben.
    for (final item in items) {
      final counted = item.countedQty;
      if (counted == null) continue; // noch nicht gezählt — überspringen

      final diff = counted - item.expectedQty;
      if (diff == 0) continue; // keine Differenz — keine Buchung nötig

      // inventory_movements ist append-only (kein UPDATE/DELETE).
      // Differenz-Movement mit movement_type='stocktake'.
      // itemId: erste passende Bestands-Row des Produkts, oder Fallback-UUID.
      final inventoryItemForProduct =
          _inventoryItems.where((i) => i.productId == item.productId).firstOrNull;
      final itemId = inventoryItemForProduct?.id ?? _uuid.v4();

      final movement = InventoryMovement(
        id: _uuid.v4(),
        itemId: itemId,
        date: now,
        quantityChange: diff,
        reason: 'Inventur-Abschluss',
        movementType: InventoryMovementType.stocktake,
        productId: item.productId,
      );
      try {
        final savedMovement = await _repository.insertMovement(movement);
        _movements.insert(0, savedMovement);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('closeStocktake: Movement für Produkt ${item.productId} '
              'konnte nicht geschrieben werden: $e');
        }
        // Fehler beim Movement blockieren nicht den Abschluss —
        // der Bestandsangleich läuft trotzdem durch.
      }

      // 2. Bestand angeleichen: inventory_item auf den gezählten Wert setzen.
      if (inventoryItemForProduct != null) {
        final corrected = inventoryItemForProduct.copyWith(quantity: counted);
        try {
          final savedItem = await _repository.updateInventoryItem(corrected);
          final idx = _inventoryItems.indexWhere((i) => i.id == savedItem.id);
          if (idx != -1) {
            _inventoryItems[idx] = savedItem;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('closeStocktake: Bestandsangleich für Produkt '
                '${item.productId} fehlgeschlagen: $e');
          }
        }
      }
    }

    // 3. Stocktake auf 'closed' setzen.
    final closed = stocktake.copyWith(
      status: StocktakeStatus.closed,
      closedAt: now,
    );
    final savedStocktake = await _repository.updateStocktake(closed);
    final idx = _stocktakes.indexWhere((s) => s.id == savedStocktake.id);
    if (idx != -1) {
      _stocktakes[idx] = savedStocktake;
    }

    _log(
      'Inventur abgeschlossen: ${savedStocktake.title ?? savedStocktake.id}',
      'stocktake',
    );
    await _refreshProductStock();
    if (!_disposed) notifyListeners();
    return savedStocktake;
  }

  /// Lädt alle Zähl-Positionen einer Inventur-Session on-demand.
  /// Pattern analog `loadPurchaseOrderItems`: kein globaler State, der
  /// Detail-Screen hält den State selbst.
  Future<List<StocktakeItem>> loadStocktakeItems(int stocktakeId) {
    final wsId = _repository.activeWorkspaceId;
    if (wsId == null) return Future.value(const []);
    return _repository.loadStocktakeItems(wsId, stocktakeId);
  }

  /// CRUD: neue Inventur-Session hinzufügen (direkter Weg ohne Soll-Snapshot).
  /// Für einfache Tests / manuelle Sessions ohne Produkt-Aggregation.
  Future<Stocktake> addStocktake(Stocktake stocktake) async {
    final saved = await _repository.insertStocktake(stocktake);
    _stocktakes.insert(0, saved);
    _stocktakes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _log('Inventur hinzugefügt: ${saved.title ?? saved.id}', 'stocktake');
    if (!_disposed) notifyListeners();
    return saved;
  }

  Future<void> updateStocktake(Stocktake stocktake) async {
    final saved = await _repository.updateStocktake(stocktake);
    final idx = _stocktakes.indexWhere((s) => s.id == saved.id);
    if (idx == -1) return;
    _stocktakes[idx] = saved;
    _stocktakes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _log('Inventur aktualisiert: ${saved.title ?? saved.id}', 'stocktake');
    if (!_disposed) notifyListeners();
  }

  /// Soft-Delete. Entfernt die Inventur aus dem lokalen Cache.
  /// `stocktake_items` werden DB-seitig durch `ON DELETE CASCADE` entfernt.
  Future<void> deleteStocktake(int id) async {
    final st = _stocktakes.where((s) => s.id == id).firstOrNull;
    await _repository.deleteStocktake(id);
    _stocktakes.removeWhere((s) => s.id == id);
    if (st != null) {
      _log('Inventur gelöscht: ${st.title ?? st.id}', 'stocktake');
    }
    if (!_disposed) notifyListeners();
  }

  // ── INVENTORY ITEMS ───────────────────────────────────────────────────────

  Future<void> addInventoryItem(InventoryItem item) async {
    final withId = item.id.isEmpty ? item.copyWith(id: _uuid.v4()) : item;
    final saved = await _repository.insertInventoryItem(withId);
    _inventoryItems.add(saved);
    _inventoryItems.sort((a, b) => a.name.compareTo(b.name));

    if (saved.quantity > 0) {
      final movement = InventoryMovement(
        id: _uuid.v4(),
        itemId: saved.id,
        date: DateTime.now(),
        quantityChange: saved.quantity,
        reason: 'Einbuchung',
        movementType: InventoryMovementType.goodsIn,
        unitCost: saved.costPrice,
        dealId: saved.dealId,
        ticketNumber: saved.ticketNumber,
        productId: saved.productId,
      );
      final savedMovement = await _repository.insertMovement(movement);
      _movements.insert(0, savedMovement);
    }

    _log('Artikel eingebucht: ${saved.name}', 'stock');
    if (!_disposed) notifyListeners();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final old = _inventoryItems.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );
    final saved = await _repository.updateInventoryItem(item);
    final idx = _inventoryItems.indexWhere((i) => i.id == saved.id);
    if (idx == -1) return;
    _inventoryItems[idx] = saved;
    _inventoryItems.sort((a, b) => a.name.compareTo(b.name));

    final delta = saved.quantity - old.quantity;
    if (delta != 0) {
      final isIncoming = delta > 0;
      final movement = InventoryMovement(
        id: _uuid.v4(),
        itemId: saved.id,
        date: DateTime.now(),
        quantityChange: delta,
        reason: isIncoming ? 'Einbuchung' : 'Ausbuchung',
        movementType: isIncoming
            ? InventoryMovementType.goodsIn
            : InventoryMovementType.goodsOut,
        unitCost: isIncoming ? saved.costPrice : null,
        dealId: saved.dealId,
        ticketNumber: saved.ticketNumber,
        productId: saved.productId,
      );
      final savedMovement = await _repository.insertMovement(movement);
      _movements.insert(0, savedMovement);
    }

    _log('Lagerartikel aktualisiert: ${saved.name}', 'stock');
    if (!_disposed) notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    final item = _inventoryItems.where((i) => i.id == id).firstOrNull;
    await _repository.deleteInventoryItem(id);
    _inventoryItems.removeWhere((i) => i.id == id);
    // ON DELETE CASCADE removes movements server-side; mirror that locally.
    _movements.removeWhere((m) => m.itemId == id);
    if (item != null) _log('Lagerartikel gelöscht: ${item.name}', 'stock');
    if (!_disposed) notifyListeners();
  }

  Future<void> adjustStock(
    String id,
    int delta,
    String reason, {
    InventoryMovementType movementType = InventoryMovementType.correction,
    int? dealId,
    String? ticketNumber,
  }) async {
    final idx = _inventoryItems.indexWhere((i) => i.id == id);
    if (idx == -1 || delta == 0) return;
    final current = _inventoryItems[idx];
    final updated = current.copyWith(
      quantity: (current.quantity + delta).clamp(0, 1 << 31).toInt(),
      dealId: dealId ?? current.dealId,
      ticketNumber: ticketNumber ?? current.ticketNumber,
    );
    final saved = await _repository.updateInventoryItem(updated);
    _inventoryItems[idx] = saved;

    final movement = InventoryMovement(
      id: _uuid.v4(),
      itemId: id,
      date: DateTime.now(),
      quantityChange: delta,
      reason: reason,
      movementType: movementType,
      unitCost:
          movementType == InventoryMovementType.goodsIn ? current.costPrice : null,
      dealId: dealId,
      ticketNumber: ticketNumber,
      productId: current.productId,
    );
    final savedMovement = await _repository.insertMovement(movement);
    _movements.insert(0, savedMovement);

    _log('Lagerbewegung: ${current.name} ${delta > 0 ? '+' : ''}$delta',
        'stock');
    await _refreshProductStock();
    if (!_disposed) notifyListeners();
  }

  // ── BATCHES ───────────────────────────────────────────────────────────────

  Future<List<InventoryBatch>> loadBatchesForItem(String itemId) =>
      _repository.loadBatchesForItem(itemId);

  /// Lädt alle Chargen über alle Items. Für die Statistik-Tabs (Lager-KPIs).
  /// Wird gecached im StatisticsService.
  Future<List<InventoryBatch>> loadAllBatches() => _repository.loadAllBatches();

  Future<InventoryBatch> addBatch(InventoryBatch batch) async {
    final saved = await _repository.insertBatch(batch);
    _log('Charge hinzugefügt: ${saved.batchNumber}', 'batch');
    if (!_disposed) notifyListeners();
    return saved;
  }

  Future<InventoryBatch> updateBatch(InventoryBatch batch) async {
    final saved = await _repository.updateBatch(batch);
    if (!_disposed) notifyListeners();
    return saved;
  }

  Future<void> deleteBatch(String id) async {
    await _repository.deleteBatch(id);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
