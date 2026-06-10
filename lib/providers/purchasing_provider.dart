import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_entry.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/supplier.dart';
import '../services/carrier_service.dart';
import '../services/supabase_repository.dart';

/// Holds the purchasing domain state for the signed-in user:
/// [Supplier] and [PurchaseOrder] (header) lists. `purchase_order_items` are
/// NOT held globally — they are loaded lazily per detail-screen via
/// [loadPurchaseOrderItems] (mirrors the pattern in [DealsProvider] for
/// `loadBatchesForItem`). All mutations are routed through
/// [SupabaseRepository]; local lists are caches kept in sync with the server.
///
/// Extracted from [DealsProvider] as the second provider-split increment
/// (after [CatalogProvider], PR #120). Registers as
/// [ChangeNotifierProxyProvider<SupabaseRepository, PurchasingProvider>] in
/// `main.dart`, as a sibling of [CatalogProvider] and BEFORE [DealsProvider]
/// (registration order matters — DealsProvider depends on this provider via
/// a [ChangeNotifierProxyProvider3]). Workspace lifecycle mirrors the other two
/// providers: [setActiveWorkspace] is driven by the same `_AuthGateState`
/// listener.
///
/// **Cross-domain note:** This provider reads NOTHING from other domains, so it
/// is a simple single-dependency proxy. The inverse direction — other providers
/// writing INTO purchasing state — is exposed via the public write-back hooks
/// below ([upsertSupplierFromImport], [insertPurchaseOrderFromImport],
/// [replacePurchaseOrderHeader], …). These exist because two cross-domain
/// orchestrators stay in [DealsProvider]:
///   1. `bookGoodsReceipt` — writes inventory state, refreshes the PO header
///      here via [replacePurchaseOrderHeader] + [notifyAfterCrossDomainWrite].
///   2. `importCsvAll` — writes suppliers + POs here via the import hooks while
///      keeping the FK-remap tables local to the orchestrator.
class PurchasingProvider extends ChangeNotifier {
  PurchasingProvider({required SupabaseRepository repository})
      : _repository = repository;

  final SupabaseRepository _repository;
  final _uuid = const Uuid();

  List<Supplier> _suppliers = [];

  /// Bestellköpfe (Epic C). `purchase_order_items` werden NICHT global
  /// gehalten — sie werden lazy pro Detail-Screen geladen (Committee-
  /// Empfehlung 1, analog `loadBatchesForItem`).
  List<PurchaseOrder> _purchaseOrders = [];

  bool _loading = false;
  bool _initialLoadAttempted = false;
  Object? _lastError;
  bool _disposed = false;

  /// In-flight load guard — coalesces concurrent [loadData] calls.
  Future<void>? _loadDataInFlight;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isLoading => _loading;

  /// True as soon as the first [loadData] call has returned.
  bool get initialLoadAttempted => _initialLoadAttempted;

  Object? get lastError => _lastError;

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);

  List<Supplier> get activeSuppliers =>
      List.unmodifiable(_suppliers.where((s) => s.active));

  /// Bestellköpfe, absteigend nach Erstellungsdatum sortiert.
  List<PurchaseOrder> get purchaseOrders => List.unmodifiable(_purchaseOrders);

  // ── Cross-domain write-back hooks ─────────────────────────────────────────
  // Public surface for DealsProvider orchestrators (importCsvAll,
  // bookGoodsReceipt) that must write into purchasing state while keeping their
  // FK-remap tables local. Raw (non-copied) reads are intentional — the
  // orchestrator builds dedup-seed sets from them and must observe the same
  // backing list the import then mutates via the insert hooks below.

  /// Raw (uncopied) supplier list for dedup-seed lookups in import orchestrators.
  List<Supplier> get suppliersRaw => _suppliers;

  /// Raw (uncopied) PO list for dedup-seed lookups in import orchestrators.
  List<PurchaseOrder> get purchaseOrdersRaw => _purchaseOrders;

  /// Appends an import-saved supplier. Caller re-sorts via [sortSuppliers] and
  /// notifies via [notifyAfterCrossDomainWrite] once the batch completes.
  void upsertSupplierFromImport(Supplier saved) {
    _suppliers.add(saved);
  }

  /// Re-sorts suppliers by lowercased name (= load-time order). Called by the
  /// import orchestrator after a supplier batch.
  void sortSuppliers() {
    _suppliers
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Inserts an import-saved PO at the front (newest-first). Caller re-sorts via
  /// [sortPurchaseOrders] and notifies via [notifyAfterCrossDomainWrite] later.
  void insertPurchaseOrderFromImport(PurchaseOrder saved) {
    _purchaseOrders.insert(0, saved);
  }

  /// Re-sorts POs by descending `createdAt` (= load-time order).
  void sortPurchaseOrders() {
    _purchaseOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Replaces a PO header in-place by id — used by `bookGoodsReceipt` after the
  /// DB status-trigger has updated `purchase_orders.status`. No-op if the PO is
  /// no longer cached locally.
  void replacePurchaseOrderHeader(PurchaseOrder fresh) {
    final i = _purchaseOrders.indexWhere((p) => p.id == fresh.id);
    if (i != -1) _purchaseOrders[i] = fresh;
  }

  /// notifyListeners() guarded by [_disposed] — used by cross-domain
  /// orchestrators after they have mutated purchasing state via the hooks above.
  void notifyAfterCrossDomainWrite() {
    if (!_disposed) notifyListeners();
  }

  // ── Workspace lifecycle ───────────────────────────────────────────────────

  String? _activeWorkspaceId;

  /// Called by [_AuthGateState._onWorkspaceChanged] whenever the active
  /// workspace changes — mirrors the pattern in [CatalogProvider] /
  /// [DealsProvider].
  Future<void> setActiveWorkspace(String? workspaceId) async {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    // Den geteilten Repo-Workspace setzen BEVOR loadData/loadAll läuft — sonst
    // liest loadAll() einen null-Workspace und liefert still einen LEEREN
    // Snapshot (supabase_repository.dart:192-195). In main._hydrate laufen
    // Catalog/Purchasing/Inventory parallel via Future.wait; ohne dieses Set
    // verliert Purchasing das Race → Suppliers/POs landen leer. Mirror
    // DealsProvider.setActiveWorkspace.
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
    notifyListeners();
    try {
      final snapshot = await _repository.loadAll();
      // Sort order mirrors the original DealsProvider._hydrateFrom:
      //   suppliers by lowercased name, POs by descending createdAt.
      _suppliers = List.of(snapshot.suppliers)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _purchaseOrders = List.of(snapshot.purchaseOrders)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('PurchasingProvider.loadData failed: $e');
    } finally {
      _loading = false;
      _initialLoadAttempted = true;
      _loadDataInFlight = null;
      if (!_disposed) notifyListeners();
    }
  }

  /// Wipes local caches — used on sign-out so the next user starts clean.
  void clearLocalState() {
    _suppliers = [];
    _purchaseOrders = [];
    _lastError = null;
    _initialLoadAttempted = false;
    _activeWorkspaceId = null;
    notifyListeners();
  }

  // ── Activity helper ───────────────────────────────────────────────────────

  /// Fire-and-forget activity log. Writes directly to the DB via the
  /// repository — DB-ONLY, with NO in-memory `_activities` cache.
  ///
  /// **Gotcha (PR #120 #6, intentional):** The original `_log` in
  /// [DealsProvider] also prepended the entry to an in-memory `_activities`
  /// list that the dashboard's recent-activity widget reads. Purchasing
  /// activities logged here therefore no longer appear instantly in that
  /// in-memory list — they surface only after the next DB load (the activity
  /// screen loads from DB anyway). This is an accepted, documented behavioural
  /// regression scoped to supplier/PO activity entries; see plan §7.5.
  void _log(String message, String type) {
    final entry = ActivityEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      message: message,
      type: type,
    );
    unawaited(_repository.insertActivity(entry).catchError((Object e) {
      if (kDebugMode) {
        debugPrint('PurchasingProvider: activity_log insert failed: $e');
      }
      return entry;
    }));
  }

  // ── SUPPLIERS ─────────────────────────────────────────────────────────────

  Future<void> addSupplier(Supplier supplier) async {
    final saved = await _repository.insertSupplier(supplier);
    _suppliers.add(saved);
    _suppliers
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Lieferant hinzugefügt: ${saved.name}', 'supplier');
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final saved = await _repository.updateSupplier(supplier);
    final idx = _suppliers.indexWhere((s) => s.id == saved.id);
    if (idx == -1) return;
    _suppliers[idx] = saved;
    _suppliers
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Lieferant aktualisiert: ${saved.name}', 'supplier');
    notifyListeners();
  }

  Future<void> deleteSupplier(String id) async {
    final supplier = _suppliers.where((s) => s.id == id).firstOrNull;
    await _repository.deleteSupplier(id);
    _suppliers.removeWhere((s) => s.id == id);
    if (supplier != null) {
      _log('Lieferant gelöscht: ${supplier.name}', 'supplier');
    }
    notifyListeners();
  }

  /// Fügt die Standard-Versanddienste (DHL, UPS, Hermes, etc.) als Supplier
  /// hinzu. Idempotent: Einträge, deren Name (case-insensitive) bereits
  /// vorhanden ist, werden übersprungen.
  ///
  /// Liefert ein Tupel `(added, skipped)` für die UI-Rückmeldung zurück.
  Future<({int added, int skipped})> seedCarrierSuppliers() async {
    final existing =
        _suppliers.map((s) => s.name.trim().toLowerCase()).toSet();
    var added = 0;
    var skipped = 0;
    for (final seed in carrierSupplierSeeds) {
      if (existing.contains(seed.name.toLowerCase())) {
        skipped++;
        continue;
      }
      final supplier = Supplier(
        id: '',
        name: seed.name,
        website: seed.website,
        note: 'Versanddienstleister',
      );
      final saved = await _repository.insertSupplier(supplier);
      _suppliers.add(saved);
      added++;
    }
    if (added > 0) {
      _suppliers
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _log('$added Versanddienst-Lieferanten hinzugefügt', 'supplier');
      notifyListeners();
    }
    return (added: added, skipped: skipped);
  }

  // ── PURCHASE ORDERS ───────────────────────────────────────────────────────

  /// Legt eine neue Bestellung an. Die `order_number` wird im Repository
  /// client-seitig vergeben (mit UNIQUE-Constraint-Retry — siehe
  /// `SupabaseRepository.insertPurchaseOrder`). Der zurückgegebene
  /// `PurchaseOrder` hat die server-seitig zugewiesene `id` (BIGSERIAL).
  Future<PurchaseOrder> addPurchaseOrder(PurchaseOrder order) async {
    final saved = await _repository.insertPurchaseOrder(order);
    _purchaseOrders.insert(0, saved);
    _log('Bestellung angelegt: ${saved.orderNumber}', 'purchase_order');
    notifyListeners();
    return saved;
  }

  Future<void> updatePurchaseOrder(PurchaseOrder order) async {
    final saved = await _repository.updatePurchaseOrder(order);
    final idx = _purchaseOrders.indexWhere((po) => po.id == saved.id);
    if (idx == -1) return;
    _purchaseOrders[idx] = saved;
    _purchaseOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _log('Bestellung aktualisiert: ${saved.orderNumber}', 'purchase_order');
    notifyListeners();
  }

  /// Soft-Delete. Entfernt die Bestellung aus dem lokalen Cache.
  /// Bestellpositionen (`purchase_order_items`) werden DB-seitig
  /// durch `ON DELETE CASCADE` entfernt — sie liegen nicht im globalen
  /// Cache, daher ist kein lokales Aufräumen nötig.
  Future<void> deletePurchaseOrder(int id) async {
    final order = _purchaseOrders.where((po) => po.id == id).firstOrNull;
    await _repository.deletePurchaseOrder(id);
    _purchaseOrders.removeWhere((po) => po.id == id);
    if (order != null) {
      _log('Bestellung gelöscht: ${order.orderNumber}', 'purchase_order');
    }
    notifyListeners();
  }

  // ── PURCHASE ORDER ITEMS (lazy — nur pro Detail-Screen) ──────────────────

  /// Lädt alle Positionen einer Bestellung on-demand.
  /// Pattern analog `loadBatchesForItem`: kein globaler State, der
  /// Detail-Screen hält den State selbst (oder via Provider-Slot).
  Future<List<PurchaseOrderItem>> loadPurchaseOrderItems(
    int purchaseOrderId,
  ) {
    final wsId = _repository.activeWorkspaceId;
    if (wsId == null) return Future.value(const []);
    return _repository.loadPurchaseOrderItems(wsId, purchaseOrderId);
  }

  Future<PurchaseOrderItem> addPurchaseOrderItem(PurchaseOrderItem item) async {
    final saved = await _repository.insertPurchaseOrderItem(item);
    _log('Bestellposition hinzugefügt', 'purchase_order');
    return saved;
  }

  Future<PurchaseOrderItem> updatePurchaseOrderItem(
      PurchaseOrderItem item) async {
    final saved = await _repository.updatePurchaseOrderItem(item);
    _log('Bestellposition aktualisiert', 'purchase_order');
    return saved;
  }

  Future<void> deletePurchaseOrderItem(String id) async {
    await _repository.deletePurchaseOrderItem(id);
    _log('Bestellposition gelöscht', 'purchase_order');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
