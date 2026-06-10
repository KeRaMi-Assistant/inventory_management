import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_entry.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/tracking_confidence.dart';
import '../models/deal_comment.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/shop.dart';
import '../models/supplier.dart';
import '../models/ticket.dart';
import '../models/ticket_summary.dart';
import '../models/warehouse.dart';
import '../services/carrier_service.dart';
import '../services/csv_service.dart';
import '../services/supabase_repository.dart';
import '../utils/error_messages.dart';
import 'catalog_provider.dart';
import 'purchasing_provider.dart';
import 'stock_provider.dart';

/// Holds the full working set of cloud data for the signed-in user and routes
/// every mutation through [SupabaseRepository]. Local lists are caches kept in
/// sync with the server so the rest of the UI can stay synchronous.
///
/// The catalog domain (products + categories) has been extracted into
/// [CatalogProvider], the purchasing domain (suppliers + purchase orders) into
/// [PurchasingProvider] and the stock domain (inventory items + movements +
/// warehouses + stocktakes + product-stock) into [StockProvider].
/// InventoryProvider receives references via [updateCatalogProvider] /
/// [updatePurchasingProvider] / [updateStockProvider] (called from `main.dart`
/// via [ChangeNotifierProxyProvider4]) and delegates the corresponding reads
/// to them. Two cross-domain orchestrators stay here — `importCsvAll` and
/// `checkInDeal` — and write into purchasing/stock state through the public
/// write-back hooks on [PurchasingProvider] / [StockProvider]. `bookGoodsReceipt`
/// has moved to [StockProvider] (it is purely a stock + PO-header write).
class InventoryProvider extends ChangeNotifier {
  InventoryProvider({
    required SupabaseRepository repository,
    CatalogProvider? catalogProvider,
    PurchasingProvider? purchasingProvider,
    StockProvider? stockProvider,
  })  : _repository = repository,
        _catalogProvider = catalogProvider,
        _purchasingProvider = purchasingProvider,
        _stockProvider = stockProvider;

  final SupabaseRepository _repository;
  final _uuid = const Uuid();

  CatalogProvider? _catalogProvider;
  PurchasingProvider? _purchasingProvider;
  StockProvider? _stockProvider;

  /// Called by [ChangeNotifierProxyProvider3] in `main.dart` whenever the
  /// upstream [CatalogProvider] instance is replaced. Safe to call repeatedly
  /// with the same instance.
  void updateCatalogProvider(CatalogProvider? catalog) {
    _catalogProvider = catalog;
    // No notifyListeners() here — callers that depend on products read via
    // the CatalogProvider directly; InventoryProvider only uses the reference
    // for internal cross-domain reads (criticalStockCount, importCsvAll, etc.).
  }

  /// Called by [ChangeNotifierProxyProvider3] in `main.dart` whenever the
  /// upstream [PurchasingProvider] instance is replaced. Safe to call
  /// repeatedly with the same instance. MUST be re-injected on every rebuild
  /// (Gotcha #4) — otherwise importCsvAll/bookGoodsReceipt silently no-op
  /// against a stale/null reference.
  void updatePurchasingProvider(PurchasingProvider? purchasing) {
    _purchasingProvider = purchasing;
    // No notifyListeners() here — callers that depend on suppliers/POs read via
    // the PurchasingProvider directly; InventoryProvider only uses the
    // reference for cross-domain writes (importCsvAll).
  }

  /// Called by [ChangeNotifierProxyProvider4] in `main.dart` whenever the
  /// upstream [StockProvider] instance is replaced. Safe to call repeatedly
  /// with the same instance. MUST be re-injected on every rebuild (Gotcha #4) —
  /// otherwise importCsvAll/checkInDeal silently no-op against a stale/null
  /// reference, losing imported warehouses/items + the check-in stock row.
  void updateStockProvider(StockProvider? stock) {
    _stockProvider = stock;
    // No notifyListeners() here — callers that depend on inventory items /
    // warehouses read via the StockProvider directly; InventoryProvider only
    // uses the reference for cross-domain reads (_summariesByArchive) and
    // writes (importCsvAll, checkInDeal).
  }

  /// Convenience read — returns the product list from [CatalogProvider] if
  /// available, otherwise an empty list. Used internally by methods that
  /// operate across the Catalog + Inventory domains.
  List<Product> get _catalogProducts =>
      _catalogProvider?.products ?? const [];

  /// Null-safe raw supplier list from [PurchasingProvider]. The `?? const []`
  /// masks an early-init null reference — see the kDebugMode assert in
  /// [importCsvAll] which surfaces that case loudly in debug (Risk §7.3).
  List<Supplier> get _purchSuppliers =>
      _purchasingProvider?.suppliersRaw ?? const [];

  /// Null-safe raw PO list from [PurchasingProvider].
  List<PurchaseOrder> get _purchPurchaseOrders =>
      _purchasingProvider?.purchaseOrdersRaw ?? const [];

  /// Null-safe raw inventory-item list from [StockProvider]. Used by
  /// [_summariesByArchive] (Inventory→Stock read) and as the dedup-seed source
  /// in [importCsvAll]. The `?? const []` masks an early-init null reference —
  /// see the kDebugMode assert in [importCsvAll].
  List<InventoryItem> get _stockInventoryItems =>
      _stockProvider?.inventoryItemsRaw ?? const [];

  /// Null-safe raw warehouse list from [StockProvider]. Dedup-seed source for
  /// the warehouse loop in [importCsvAll].
  List<Warehouse> get _stockWarehouses =>
      _stockProvider?.warehousesRaw ?? const [];

  List<Deal> _deals = [];

  /// IDs von Deals, für die ein verzögertes Löschen (Delayed-Commit) aussteht.
  /// Diese Deals sind lokal noch im Cache vorhanden, werden aber aus dem
  /// [deals]-Getter gefiltert (optimistic hide). Der DB-Call erfolgt erst
  /// nach Ablauf des Timers in [_pendingDeleteTimers].
  final Set<int> _pendingDeleteIds = {};

  /// Aktive Timer für verzögerte Deal-Löschungen.
  /// Key: Deal-ID. Value: aktiver Timer, der nach Ablauf [_commitPendingDelete]
  /// aufruft.
  final Map<int, Timer> _pendingDeleteTimers = {};

  List<Buyer> _buyers = [];
  List<Shop> _shops = [];
  List<ActivityEntry> _activities = [];
  List<Ticket> _tickets = [];

  bool _loading = false;
  bool _initialLoadAttempted = false;
  Object? _lastError;
  // Gesetzt in dispose() — alle async-Continuations prüfen dieses Flag
  // vor notifyListeners(), um post-dispose-Notifies zu verhindern.
  bool _disposed = false;

  /// In-flight Future des laufenden [loadData]-Calls. Solange ein Load läuft,
  /// gibt jeder weitere Aufrufer dasselbe Future zurück (Coalescing), statt
  /// einen zweiten konkurrierenden Load zu starten. Wird in [loadData] gesetzt
  /// und im finally-Block auf null zurückgesetzt.
  Future<void>? _loadDataInFlight;

  bool get isLoading => _loading;

  /// True as soon as the first [loadData] call has returned — regardless of
  /// whether it succeeded or failed. Used by skeleton-loading logic to
  /// distinguish the cold-start race (provider not yet fired) from the
  /// empty-state after a completed load.
  bool get initialLoadAttempted => _initialLoadAttempted;

  Object? get lastError => _lastError;

  /// Sorted views — the underlying lists are pre-sorted on every load so the
  /// getters are O(n) wraps, not O(n log n) re-sorts.
  ///
  /// Deals mit ausstehendem Delayed-Commit-Delete ([_pendingDeleteIds]) werden
  /// optimistisch herausgefiltert — sie sind im Cache, aber nicht sichtbar.
  List<Deal> get deals => _pendingDeleteIds.isEmpty
      ? List.unmodifiable(_deals)
      : List.unmodifiable(
          _deals.where((d) => !_pendingDeleteIds.contains(d.id)),
        );
  List<Buyer> get buyers => List.unmodifiable(_buyers);
  List<Shop> get shops => List.unmodifiable(_shops);
  List<ActivityEntry> get activities => List.unmodifiable(_activities);
  List<Ticket> get tickets => List.unmodifiable(_tickets);

  // NOTE: inventoryItems / movements / warehouses / defaultWarehouse /
  // stocktakes / productStock have moved to [StockProvider]. Consumers read
  // them from there now (see plan §1/§7).

  static const List<String> statusOptions = [
    'Bestellt',
    'Unterwegs',
    'Angekommen',
    'Rechnung gestellt',
    'Done',
  ];
  static const List<String> inventoryStatusOptions = [
    'Im Lager',
    'Reserviert',
    'Versandt',
    'Verkauft',
  ];

  // ── Derived KPIs ──────────────────────────────────────────────────────────

  int get openOrdersCount =>
      _deals.where((d) => d.status == 'Bestellt').length;

  /// Number of deals with `tracking_needs_review = true`.
  /// Used for the counter badge on the Inbox nav tab and the Deals filter chip.
  int get trackingNeedsReviewCount =>
      _deals.where((d) => d.trackingNeedsReview).length;

  double get totalProfit =>
      _deals.fold(0, (sum, d) => sum + (d.totalProfit ?? 0));

  double get openAmount => _deals
      .where((d) => d.status != 'Done')
      .fold(0, (sum, d) => sum + (d.zuBekommen ?? 0));

  int get openDeliveriesCount =>
      _deals.where((d) => d.status == 'Unterwegs').length;

  int get arrivedTodayCount {
    final now = DateTime.now();
    return _deals.where((d) {
      final a = d.arrivalDate;
      return a != null &&
          a.year == now.year &&
          a.month == now.month &&
          a.day == now.day;
    }).length;
  }

  // NOTE: criticalStockCount / totalStockQuantity / totalStockValue have moved
  // to [StockProvider] (they aggregate inventory items + product_stock). Read
  // them from there now.

  int get missingInvoiceCount =>
      _deals.where((d) => !d.hasReceipt && d.status != 'Done').length;

  /// Kept for UI callers that historically asked for an id ahead of save.
  /// With BIGSERIAL the id is server-assigned — this is a hint only.
  int get nextDealId => _deals.isEmpty
      ? 1
      : (_deals.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1);

  Set<String> get existingTicketNumbers => _deals
      .where((d) => d.ticketNumber != null && d.ticketNumber!.isNotEmpty)
      .map((d) => d.ticketNumber!)
      .toSet();

  /// Aktive Tickets (archived_at IS NULL) — bisheriges Default-Verhalten.
  /// Für die Archiv-Liste siehe [archivedTicketSummaries].
  List<TicketSummary> get ticketSummaries =>
      _summariesByArchive(archived: false);

  /// Archivierte Tickets (archived_at IS NOT NULL), gruppiert nach Monat
  /// rendert das UI selbst — hier bekommt der Caller die flache, nach
  /// `archivedAt DESC` sortierte Liste.
  List<TicketSummary> get archivedTicketSummaries {
    final list = _summariesByArchive(archived: true);
    list.sort((a, b) {
      final ad = a.archivedAt;
      final bd = b.archivedAt;
      if (ad == null && bd == null) return b.newestDate.compareTo(a.newestDate);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return list;
  }

  List<TicketSummary> _summariesByArchive({required bool archived}) {
    final ticketByNumber = <String, Ticket>{
      for (final t in _tickets) t.ticketNumber: t,
    };
    final grouped = <String, List<Deal>>{};
    for (final deal in _deals) {
      final key = (deal.ticketNumber == null || deal.ticketNumber!.trim().isEmpty)
          ? 'Kein Ticket'
          : deal.ticketNumber!.trim();
      grouped.putIfAbsent(key, () => []).add(deal);
    }
    final summaries = <TicketSummary>[];
    for (final entry in grouped.entries) {
      final ticketRow = ticketByNumber[entry.key];
      final isArchived = ticketRow?.archivedAt != null;
      // "Kein Ticket" hat keinen Row in der `tickets`-Tabelle und ist daher
      // immer aktiv. Auf der Archiv-Seite wird es entsprechend ausgeblendet.
      if (archived && !isArchived) continue;
      if (!archived && isArchived) continue;
      // Inventory items live in [StockProvider] now (Inventory→Stock read via
      // the null-safe [_stockInventoryItems] hook).
      final items = _stockInventoryItems
          .where((item) =>
              item.ticketNumber == entry.key ||
              entry.value.any((deal) => deal.inventoryItemIds.contains(item.id)))
          .toList();
      summaries.add(TicketSummary(
        ticketNumber: entry.key,
        deals: entry.value,
        items: items,
        ticketId: ticketRow?.id,
        archivedAt: ticketRow?.archivedAt,
        archivedReason: ticketRow?.archivedReason,
      ));
    }
    summaries.sort((a, b) => b.newestDate.compareTo(a.newestDate));
    return summaries;
  }

  // ── Load / clear ──────────────────────────────────────────────────────────

  String? _activeWorkspaceId;

  /// Wechselt den Workspace, gegen den geladen + geschrieben wird. Wird vom
  /// ActiveWorkspaceProvider-Listener im AuthGate aufgerufen. Setzt die
  /// neue Workspace-ID am Repository, leert die lokalen Caches und lädt
  /// frisch — damit nach einem Switch nicht kurz die alten Deals stehen
  /// bleiben.
  Future<void> setActiveWorkspace(String? workspaceId) async {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    _repository.setActiveWorkspace(workspaceId);
    if (workspaceId == null) {
      clearLocalState();
      return;
    }
    await loadData();
  }

  Future<void> loadData() {
    // Concurrent-call guard via Future-Coalescing: wenn ein Load bereits läuft,
    // dasselbe Future zurückgeben statt einen zweiten zu starten. Verhindert,
    // dass ein Workspace-Switch + gleichzeitiges retrackDeal den Cache
    // inkonsistent überschreiben und _loading falsch zurücksetzen.
    if (_loadDataInFlight != null) return _loadDataInFlight!;
    _loadDataInFlight = _doLoadData();
    return _loadDataInFlight!;
  }

  Future<void> _doLoadData() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      // Hauptdaten laden. Stock-Listen (inventory items, movements, warehouses,
      // stocktakes, product_stock) + Default-Lager-Bootstrap leben jetzt in
      // [StockProvider] und werden dort parallel geladen (main._hydrate).
      final snapshot = await _repository.loadAll();
      _hydrateFrom(snapshot);
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InventoryProvider.loadData failed: $e');
    } finally {
      _loading = false;
      _initialLoadAttempted = true;
      _loadDataInFlight = null;
      notifyListeners();
    }
  }

  /// Wipes local caches — used on sign-out so the next user starts clean.
  void clearLocalState() {
    _deals = [];
    _buyers = [];
    _shops = [];
    _activities = [];
    _tickets = [];
    _lastError = null;
    _initialLoadAttempted = false;
    _activeWorkspaceId = null;
    _repository.setActiveWorkspace(null);
    notifyListeners();
  }

  void _hydrateFrom(CloudSnapshot snapshot) {
    _deals = List.of(snapshot.deals)..sort((a, b) => b.id.compareTo(a.id));
    _buyers = List.of(snapshot.buyers)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _shops = List.of(snapshot.shops);
    _activities = List.of(snapshot.activities)
      ..sort((a, b) => b.date.compareTo(a.date));
    _tickets = List.of(snapshot.tickets);
  }

  // ── TICKETS ───────────────────────────────────────────────────────────────

  /// Refresh tickets aus der DB. Wird vom Tickets-Screen gerufen, wenn der
  /// User zwischen Aktiv/Archiv wechselt — Auto-Archive-Trigger im
  /// Backend könnten den Status nach einem Deal-Update verändert haben,
  /// ohne dass der Client das mitbekommt.
  Future<void> loadTickets({bool? archived}) async {
    try {
      final fetched = await _repository.loadTickets(archived: archived);
      if (archived == null) {
        _tickets = fetched;
      } else {
        // Teil-Refresh: alte Rows mit dem Filter überschreiben, andere
        // (= Komplement) erhalten.
        final keepIds = fetched.map((t) => t.id).toSet();
        final retained = _tickets.where((t) {
          final isArch = t.archivedAt != null;
          // Drop only rows die im Filter waren — sonst behalten.
          if (archived && isArch) return false;
          if (!archived && !isArch) return false;
          return !keepIds.contains(t.id);
        }).toList();
        _tickets = [...retained, ...fetched];
      }
      notifyListeners();
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InventoryProvider.loadTickets failed: $e');
      rethrow;
    }
  }

  /// Manuelles Archivieren via UI. Auto-Triggers (`all_done`, `all_shipped`,
  /// `inventory_sold`) sind separat — diese Methode hier setzt immer
  /// `manual` und schreibt einen Activity-Log-Eintrag.
  Future<void> archiveTicket(int ticketId, {String reason = 'manual'}) async {
    final updated = await _repository.archiveTicket(ticketId, reason: reason);
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) {
      _tickets.add(updated);
    } else {
      _tickets[idx] = updated;
    }
    _log('Ticket archiviert: ${updated.ticketNumber}', 'ticket');
    notifyListeners();
  }

  /// Reopen: archived_at + archived_reason + archived_by zurücksetzen.
  Future<void> reopenTicket(int ticketId) async {
    final updated = await _repository.reopenTicket(ticketId);
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) {
      _tickets.add(updated);
    } else {
      _tickets[idx] = updated;
    }
    _log('Ticket wieder geöffnet: ${updated.ticketNumber}', 'ticket');
    notifyListeners();
  }

  // ── Activity helper ───────────────────────────────────────────────────────

  /// Append-and-fire-and-forget log; persistence failure must never block a
  /// user-visible action, so we swallow errors after surfacing in debug.
  void _log(String message, String type) {
    final entry = ActivityEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      message: message,
      type: type,
    );
    _activities.insert(0, entry);
    if (_activities.length > 50) {
      _activities = _activities.take(50).toList();
    }
    unawaited(_repository.insertActivity(entry).catchError((Object e) {
      if (kDebugMode) debugPrint('activity_log insert failed: $e');
      return entry;
    }));
  }

  // ── DEALS ─────────────────────────────────────────────────────────────────

  Future<Deal> addDeal(Deal deal) async {
    final saved = await _repository.insertDeal(deal);
    _deals.insert(0, saved);
    _log('Deal hinzugefügt: ${saved.product}', 'deal');
    notifyListeners();
    return saved;
  }

  Future<void> updateDeal(Deal deal) async {
    final updated = await _repository.updateDeal(deal);
    final idx = _deals.indexWhere((d) => d.id == updated.id);
    if (idx == -1) return;
    final old = _deals[idx];
    _deals[idx] = updated.copyWith(inventoryItemIds: old.inventoryItemIds);
    if (old.status != updated.status) {
      _log('Status geändert: ${updated.product} → ${updated.status}', 'status');
    } else {
      _log('Deal aktualisiert: ${updated.product}', 'deal');
    }
    notifyListeners();
  }

  Future<void> deleteDeal(int id) async {
    final deal = _deals.where((d) => d.id == id).firstOrNull;
    await _repository.deleteDeal(id);
    _deals.removeWhere((d) => d.id == id);
    if (deal != null) _log('Deal gelöscht: ${deal.product}', 'deal');
    notifyListeners();
  }

  // ── Optimistic-Delete mit Delayed-Commit (Undo-Pattern) ──────────────────

  /// Startet einen verzögerten Lösch-Vorgang für einen Deal.
  ///
  /// Der Deal wird sofort aus dem [deals]-Getter gefiltert (optimistisch
  /// unsichtbar), aber der DB-Call erfolgt erst nach [delay] (Default: 4 s).
  /// Während dieser Zeit kann der User via [cancelPendingDelete] rückgängig
  /// machen — ohne DB-Touch.
  ///
  /// Wenn für dieselbe [id] bereits ein Timer läuft, wird er zuerst
  /// gecancelt und ein neuer gestartet (idempotentes Doppel-Delete).
  void deleteDealWithUndo(
    int id, {
    Duration delay = const Duration(seconds: 4),
  }) {
    // Idempotent: bereits laufenden Timer canceln, Marker bleibt aber gesetzt.
    _pendingDeleteTimers[id]?.cancel();

    _pendingDeleteIds.add(id);
    notifyListeners();

    _pendingDeleteTimers[id] = Timer(delay, () => _commitPendingDelete(id));
  }

  /// Bricht den verzögerten Lösch-Vorgang ab — der Deal kommt zurück in die
  /// Liste. Kein DB-Touch.
  void cancelPendingDelete(int id) {
    _pendingDeleteTimers.remove(id)?.cancel();
    _pendingDeleteIds.remove(id);
    notifyListeners();
  }

  /// Führt den tatsächlichen DB-Delete aus und entfernt das Item endgültig
  /// aus dem lokalen Cache. Wird nach Timer-Ablauf gerufen.
  void _commitPendingDelete(int id) {
    _pendingDeleteTimers.remove(id);
    _pendingDeleteIds.remove(id);

    final deal = _deals.where((d) => d.id == id).firstOrNull;
    // Async fire-and-forget — Fehler werden geloggt, aber kein UI-State
    // wechselt (Item ist bereits aus der Ansicht verschwunden).
    // _disposed-Check verhindert notifyListeners() nach dispose().
    _repository.deleteDeal(id).then((_) {
      if (_disposed) return;
      _deals.removeWhere((d) => d.id == id);
      if (deal != null) _log('Deal gelöscht (commit): ${deal.product}', 'deal');
      notifyListeners();
    }).catchError((Object e) {
      if (_disposed) return;
      // _log() persistiert in `activity_log` und rendert via
      // _ActivityItem im Dashboard — sanitizeError verhindert
      // PostgresException-Stacktrace-Leaks in UI + DB.
      _log('Deal-Delete fehlgeschlagen: ${sanitizeError(e)}', 'deal');
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // Laufende Timers beim Dispose canceln — sie würden sonst nach Dispose
    // auf einem ungültigen Provider feuern.
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    _pendingDeleteTimers.clear();
    _pendingDeleteIds.clear();
    super.dispose();
  }

  Future<void> updateDealsStatus(Iterable<int> ids, String status) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    await _repository.updateDealsStatus(idSet, status);
    _deals = _deals
        .map((d) => idSet.contains(d.id) ? d.copyWith(status: status) : d)
        .toList();
    _log('${idSet.length} Deals auf "$status" gesetzt', 'bulk');
    notifyListeners();
  }

  Future<void> assignDealsBuyer(Iterable<int> ids, String? buyer) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    await _repository.updateDealsBuyer(idSet, buyer);
    _deals = _deals
        .map((d) => idSet.contains(d.id) ? d.copyWith(buyer: buyer) : d)
        .toList();
    _log('${idSet.length} Deals Käufer zugewiesen', 'bulk');
    notifyListeners();
  }

  /// Bulk-Update Ticketnummer/URL für mehrere Deals — z.B. wenn der User ein
  /// Ticket im Tickets-Tab umbenennt oder die Ticket-URL ändert.
  Future<void> updateDealsTicket(
    Iterable<int> ids, {
    String? ticketNumber,
    String? ticketUrl,
  }) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    await _repository.updateDealsTicket(
      idSet,
      ticketNumber: ticketNumber,
      ticketUrl: ticketUrl,
    );
    _deals = _deals.map((d) {
      if (!idSet.contains(d.id)) return d;
      return d.copyWith(
        ticketNumber: ticketNumber == null
            ? d.ticketNumber
            : (ticketNumber.trim().isEmpty ? null : ticketNumber.trim()),
        ticketUrl: ticketUrl == null
            ? d.ticketUrl
            : (ticketUrl.trim().isEmpty ? null : ticketUrl.trim()),
      );
    }).toList();
    _log('${idSet.length} Deals: Ticket aktualisiert', 'bulk');
    notifyListeners();
  }

  Future<void> deleteDeals(Iterable<int> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    await _repository.deleteDeals(idSet);
    _deals.removeWhere((d) => idSet.contains(d.id));
    _log('${idSet.length} Deals gelöscht', 'bulk');
    notifyListeners();
  }

  /// Bulk insert via Supabase. Server assigns ids; local list is then
  /// re-sorted by descending id.
  Future<void> importDeals(List<Deal> imported) async {
    if (imported.isEmpty) return;
    final saved = await _repository.insertDeals(imported);
    _deals = [...saved, ..._deals]..sort((a, b) => b.id.compareTo(a.id));
    _log('${saved.length} Deals importiert', 'import');
    notifyListeners();
  }

  /// Imports all tables from a [CsvImportResult].
  ///
  /// **Legacy sections** (deals, shops, buyers, suppliers, inventory items) are
  /// imported as before: deals always appended, the others deduped by name.
  ///
  /// **New sections** (categories, products, warehouses, purchase orders, PO
  /// items) are imported in FK-dependency order:
  ///   1. Categories (no FK deps on new tables)
  ///   2. Warehouses (no FK deps on new tables)
  ///   3. Suppliers already handled above
  ///   4. Products (category_id → categories, default_supplier_id → suppliers)
  ///   5. Purchase orders (supplier_id → suppliers)
  ///   6. PO items (product_id → products, purchase_order_id → POs)
  ///
  /// After each insert the server-assigned id is recorded in a remap table so
  /// that dependent items can use the real DB id (not the CSV-time UUID or
  /// synthetic BIGSERIAL-style id).
  ///
  /// Returns counts in order: (deals, shops, buyers, suppliers, items).
  Future<(int, int, int, int, int)> importCsvAll(CsvImportResult result) async {
    // Risk §7.3: suppliers/POs are written into PurchasingProvider and
    // warehouses/items into StockProvider via their public write-back hooks. If
    // a reference was never injected (early-init race / mis-wired ProxyProvider),
    // those writes silently no-op and CSV rows would be lost. The `?? const []`
    // getters mask the null, so surface it loudly in debug builds. Release
    // builds tolerate it (deals/shops/buyers/products still run).
    assert(
      _purchasingProvider != null,
      'importCsvAll: _purchasingProvider is null — supplier/PO write-back would '
      'silently no-op. Check the ChangeNotifierProxyProvider4 wiring in '
      'main.dart (updatePurchasingProvider must be called on rebuild).',
    );
    assert(
      _stockProvider != null,
      'importCsvAll: _stockProvider is null — warehouse/item write-back would '
      'silently no-op. Check the ChangeNotifierProxyProvider4 wiring in '
      'main.dart (updateStockProvider must be called on rebuild).',
    );

    // Deals
    int dealCount = 0;
    if (result.deals.isNotEmpty) {
      final saved = await _repository.insertDeals(result.deals);
      _deals = [...saved, ..._deals]..sort((a, b) => b.id.compareTo(a.id));
      dealCount = saved.length;
    }

    // Shops – skip names that already exist
    int shopCount = 0;
    final existingShopNames = _shops.map((s) => s.name.toLowerCase()).toSet();
    for (final shop in result.shops) {
      if (existingShopNames.contains(shop.name.toLowerCase())) continue;
      final withId = shop.id.isEmpty ? shop.copyWith(id: _uuid.v4()) : shop;
      final saved = await _repository.insertShop(withId);
      _shops.add(saved);
      existingShopNames.add(saved.name.toLowerCase());
      shopCount++;
    }

    // Buyers – skip names that already exist
    int buyerCount = 0;
    final existingBuyerNames = _buyers.map((b) => b.name.toLowerCase()).toSet();
    for (final buyer in result.buyers) {
      if (existingBuyerNames.contains(buyer.name.toLowerCase())) continue;
      final withId = buyer.id.isEmpty ? buyer.copyWith(id: _uuid.v4()) : buyer;
      final saved = await _repository.insertBuyer(withId);
      _buyers.add(saved);
      existingBuyerNames.add(saved.name.toLowerCase());
      buyerCount++;
    }
    _buyers.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Suppliers – skip names that already exist; build name→id map for inventory
    // remap. Suppliers live in PurchasingProvider now: dedup-seed reads the raw
    // list via [_purchSuppliers]; saved rows are written back through the
    // public import hooks. The remap tables (existingSupplierByName /
    // importSupplierIdRemap) stay local to this orchestrator.
    int supplierCount = 0;
    final existingSupplierByName = <String, String>{
      for (final s in _purchSuppliers) s.name.toLowerCase(): s.id,
    };
    for (final supplier in result.suppliers) {
      final key = supplier.name.toLowerCase();
      if (existingSupplierByName.containsKey(key)) continue;
      final withId =
          supplier.id.isEmpty ? supplier.copyWith(id: _uuid.v4()) : supplier;
      final saved = await _repository.insertSupplier(withId);
      _purchasingProvider?.upsertSupplierFromImport(saved);
      existingSupplierByName[key] = saved.id;
      supplierCount++;
    }
    _purchasingProvider?.sortSuppliers();

    // Map import-supplier-id → existing supplier-id by name (so items
    // referencing an import-time supplier-id resolve to the canonical row).
    final importSupplierIdRemap = <String, String>{};
    for (final s in result.suppliers) {
      final canonical = existingSupplierByName[s.name.toLowerCase()];
      if (canonical != null) importSupplierIdRemap[s.id] = canonical;
    }

    // Inventory items – skip names that already exist; skip items that fail to
    // insert. Items live in StockProvider now: dedup-seed reads the raw list
    // via [_stockInventoryItems]; saved rows are written back through the
    // public import hooks ([StockProvider.upsertInventoryItemFromImport] +
    // [StockProvider.sortInventoryItems]). itemCount stays local to this
    // orchestrator (drives the 5-tuple return + toast).
    int itemCount = 0;
    final existingItemNames =
        _stockInventoryItems.map((i) => i.name.toLowerCase()).toSet();
    for (final item in result.inventoryItems) {
      if (existingItemNames.contains(item.name.toLowerCase())) continue;
      final remappedSupplier = item.supplierId == null
          ? null
          : (importSupplierIdRemap[item.supplierId!] ?? item.supplierId);
      final withId = item.copyWith(
        id: item.id.isEmpty ? _uuid.v4() : item.id,
        supplierId: remappedSupplier,
      );
      try {
        final saved = await _repository.insertInventoryItem(withId);
        _stockProvider?.upsertInventoryItemFromImport(saved);
        existingItemNames.add(saved.name.toLowerCase());
        itemCount++;
      } catch (e) {
        if (kDebugMode) debugPrint('importCsvAll: item "${item.name}" skipped – $e');
      }
    }
    _stockProvider?.sortInventoryItems();

    // ── New sections (Epic F) ────────────────────────────────────────────────
    // FK-dependency order: categories + warehouses → products → POs → PO items.
    // After each insert we record csv-parsed-id → db-saved-id so dependent
    // entities can reference the real row.

    // 1. Categories – delegated to CatalogProvider; track csv-id → db-id for
    //    product FK remap. Direct repository calls are used here because
    //    importCsvAll needs to build the remap table incrementally during a
    //    single async operation — delegating each insert via CatalogProvider
    //    would cause multiple redundant notifyListeners() calls. After the
    //    import completes, CatalogProvider.loadData() is called to resync.
    final importCategoryIdRemap = <String, String>{}; // csv id → db id
    final existingCategoryByName = <String, String>{
      for (final c in _catalogProvider?.productCategories ?? const [])
        c.name.toLowerCase(): c.id,
    };
    for (final category in result.categories) {
      final key = category.name.toLowerCase();
      if (existingCategoryByName.containsKey(key)) {
        // Remap csv id to the existing canonical id so products can resolve it.
        importCategoryIdRemap[category.id] = existingCategoryByName[key]!;
        continue;
      }
      try {
        final saved = await _repository.insertProductCategory(category);
        existingCategoryByName[key] = saved.id;
        importCategoryIdRemap[category.id] = saved.id;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'importCsvAll: category "${category.name}" skipped – $e');
        }
      }
    }

    // 2. Warehouses – skip by name; no FK deps. Warehouses live in
    //    StockProvider now: dedup-seed reads the raw list via [_stockWarehouses];
    //    saved rows are written back through the public import hooks
    //    ([StockProvider.upsertWarehouseFromImport] +
    //    [StockProvider.sortWarehouses]).
    final existingWarehouseByName = <String, String>{
      for (final w in _stockWarehouses) w.name.toLowerCase(): w.id,
    };
    for (final warehouse in result.warehouses) {
      final key = warehouse.name.toLowerCase();
      if (existingWarehouseByName.containsKey(key)) continue;
      try {
        final saved = await _repository.insertWarehouse(warehouse);
        _stockProvider?.upsertWarehouseFromImport(saved);
        existingWarehouseByName[key] = saved.id;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'importCsvAll: warehouse "${warehouse.name}" skipped – $e');
        }
      }
    }
    _stockProvider?.sortWarehouses();

    // 3. Products – delegated via direct repository calls (same rationale as
    //    categories above). CatalogProvider is resynced via loadData() after
    //    the import. Track csv-id → db-id for PO item FK remap.
    final importProductIdRemap = <String, String>{}; // csv id → db id
    final existingProductByName = <String, String>{
      for (final p in _catalogProvider?.products ?? const [])
        p.name.toLowerCase(): p.id,
    };
    for (final product in result.products) {
      final key = product.name.toLowerCase();
      if (existingProductByName.containsKey(key)) {
        importProductIdRemap[product.id] = existingProductByName[key]!;
        continue;
      }
      // Remap FKs: category_id and default_supplier_id may carry csv-time ids
      // that need to be translated to real DB ids.
      final remappedCategoryId = product.categoryId == null
          ? null
          : (importCategoryIdRemap[product.categoryId!] ??
              product.categoryId);
      final remappedSupplierId = product.defaultSupplierId == null
          ? null
          : (importSupplierIdRemap[product.defaultSupplierId!] ??
              product.defaultSupplierId);
      final remapped = product.copyWith(
        categoryId: remappedCategoryId,
        defaultSupplierId: remappedSupplierId,
      );
      try {
        final saved = await _repository.insertProduct(remapped);
        existingProductByName[key] = saved.id;
        importProductIdRemap[product.id] = saved.id;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('importCsvAll: product "${product.name}" skipped – $e');
        }
      }
    }

    // 4. Purchase orders – skip by order number; remap supplier_id.
    //    Track csv synthetic-id → db BIGSERIAL id for PO item FK remap.
    final importPoIdRemap = <int, int>{}; // csv synthetic id → db id
    final existingPoByNumber = <String, int>{
      for (final po in _purchPurchaseOrders) po.orderNumber: po.id ?? -1,
    };
    for (final po in result.purchaseOrders) {
      final number = po.orderNumber;
      if (existingPoByNumber.containsKey(number)) {
        final existingId = existingPoByNumber[number];
        if (po.id != null && existingId != null) {
          importPoIdRemap[po.id!] = existingId;
        }
        continue;
      }
      final remappedSupplierId = po.supplierId == null
          ? null
          : (importSupplierIdRemap[po.supplierId!] ?? po.supplierId);
      // Strip the synthetic csv-time id so the repository uses BIGSERIAL.
      final withoutId = po.copyWith(
        id: null,
        supplierId: remappedSupplierId,
      );
      try {
        final saved = await _repository.insertPurchaseOrder(withoutId);
        _purchasingProvider?.insertPurchaseOrderFromImport(saved);
        if (saved.id != null) {
          existingPoByNumber[number] = saved.id!;
          if (po.id != null) importPoIdRemap[po.id!] = saved.id!;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('importCsvAll: purchase order "$number" skipped – $e');
        }
      }
    }
    _purchasingProvider?.sortPurchaseOrders();

    // 5. PO items – remap product_id and purchase_order_id.
    for (final item in result.purchaseOrderItems) {
      final remappedProductId = item.productId == null
          ? null
          : (importProductIdRemap[item.productId!] ?? item.productId);
      final csvPoId = item.purchaseOrderId;
      final remappedPoId = csvPoId == null
          ? null
          : (importPoIdRemap[csvPoId] ?? csvPoId);
      if (remappedPoId == null || remappedProductId == null) {
        // FK not resolved — skip silently (parser already reported FK errors)
        continue;
      }
      final remapped = item.copyWith(
        productId: remappedProductId,
        purchaseOrderId: remappedPoId,
      );
      try {
        await _repository.insertPurchaseOrderItem(remapped);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('importCsvAll: PO item skipped – $e');
        }
      }
    }
    // ── End new sections ─────────────────────────────────────────────────────

    // Resync CatalogProvider after import so its in-memory cache is consistent
    // with the newly inserted categories and products.
    if (result.categories.isNotEmpty || result.products.isNotEmpty) {
      unawaited(_catalogProvider?.loadData().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('importCsvAll: CatalogProvider resync failed (non-fatal): $e');
        }
      }));
    }

    // Notify PurchasingProvider listeners once after the suppliers/POs were
    // written back through its hooks above (the hooks themselves don't notify,
    // to avoid a notify-storm per inserted row).
    if (result.suppliers.isNotEmpty ||
        result.purchaseOrders.isNotEmpty) {
      _purchasingProvider?.notifyAfterCrossDomainWrite();
    }

    // Notify StockProvider listeners once after the warehouses/items were
    // written back through its hooks above (same notify-storm avoidance).
    if (result.warehouses.isNotEmpty ||
        result.inventoryItems.isNotEmpty) {
      _stockProvider?.notifyAfterCrossDomainWrite();
    }

    if (dealCount > 0 ||
        shopCount > 0 ||
        buyerCount > 0 ||
        supplierCount > 0 ||
        itemCount > 0 ||
        result.categories.isNotEmpty ||
        result.products.isNotEmpty ||
        result.warehouses.isNotEmpty ||
        result.purchaseOrders.isNotEmpty ||
        result.purchaseOrderItems.isNotEmpty) {
      _log(
          'CSV-Import: $dealCount Deals, $shopCount Shops, $buyerCount Käufer, $supplierCount Lieferanten, $itemCount Lagerartikel',
          'import');
      notifyListeners();
    }
    return (dealCount, shopCount, buyerCount, supplierCount, itemCount);
  }

  // ── BUYERS ────────────────────────────────────────────────────────────────

  Future<void> addBuyer(Buyer buyer) async {
    final withId =
        buyer.id.isEmpty ? buyer.copyWith(id: _uuid.v4()) : buyer;
    final saved = await _repository.insertBuyer(withId);
    _buyers.add(saved);
    _buyers.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> updateBuyer(Buyer buyer) async {
    final saved = await _repository.updateBuyer(buyer);
    final idx = _buyers.indexWhere((b) => b.id == saved.id);
    if (idx == -1) return;
    _buyers[idx] = saved;
    _buyers.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> deleteBuyer(String id) async {
    await _repository.deleteBuyer(id);
    _buyers.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  // ── SHOPS ─────────────────────────────────────────────────────────────────

  Future<void> addShop(Shop shop) async {
    final withId = shop.id.isEmpty ? shop.copyWith(id: _uuid.v4()) : shop;
    final saved = await _repository.insertShop(withId);
    _shops.add(saved);
    notifyListeners();
  }

  Future<void> updateShop(Shop shop) async {
    final saved = await _repository.updateShop(shop);
    final idx = _shops.indexWhere((s) => s.id == saved.id);
    if (idx == -1) return;
    _shops[idx] = saved;
    notifyListeners();
  }

  Future<void> deleteShop(String id) async {
    await _repository.deleteShop(id);
    _shops.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Fügt die Amazon-Country-Shops (`Amazon-DE`, `Amazon-FR`, …) idempotent
  /// in die Shop-Liste ein. Bestehende Shops mit demselben Namen (case-
  /// insensitive) werden übersprungen.
  Future<({int added, int skipped})> seedAmazonShops() async {
    final existing =
        _shops.map((s) => s.name.trim().toLowerCase()).toSet();
    var added = 0;
    var skipped = 0;
    for (final seed in amazonShopSeeds) {
      if (existing.contains(seed.name.toLowerCase())) {
        skipped++;
        continue;
      }
      final shop = Shop(
        id: _uuid.v4(),
        name: seed.name,
        region: seed.region,
        url: 'https://www.amazon.${seed.region}',
      );
      final saved = await _repository.insertShop(shop);
      _shops.add(saved);
      added++;
    }
    if (added > 0) {
      _log('$added Amazon-Shops hinzugefügt', 'shop');
      notifyListeners();
    }
    return (added: added, skipped: skipped);
  }

  // ── STOCK DOMAIN moved to StockProvider ──────────────────────────────────
  // bookGoodsReceipt, warehouse CRUD, stocktake CRUD, inventory-item CRUD
  // (add/update/delete), adjustStock and the batch helpers now live in
  // lib/providers/stock_provider.dart. checkInDeal below stays here
  // (cross-domain: matches/creates a catalog product, then writes the inventory
  // item + movement into StockProvider via its write-back hooks while keeping
  // the deal `inventoryItemIds` link local to the deals domain — plan §3
  // Option A, avoids a Stock→Inventory dependency edge).

  Future<void> checkInDeal(
    Deal deal, {
    String? location,
    String? sku,
  }) async {
    // Defensiv (wie importCsvAll): Item + Movement werden über die Stock-Hooks
    // in den injizierten StockProvider geschrieben. Ist die Injection fehlend
    // (Gotcha #4), würden die `?.`-Hooks still no-op-en und die DB-Rows wären
    // vom Stock-Cache entkoppelt. Im Debug-Build laut machen.
    assert(
      _stockProvider != null,
      'checkInDeal: _stockProvider ist null — Item/Movement-Write-Back würde '
      'still no-op. ChangeNotifierProxyProvider4-Wiring in main.dart prüfen.',
    );
    final effectiveSku = sku?.trim().isEmpty ?? true ? null : sku!.trim();

    // Produkt-Matching: erst im lokalen Cache suchen, dann ggf. neu anlegen.
    // Ein Wareneingang darf NIEMALS an der Produkt-Verknüpfung scheitern —
    // Fehler beim Anlegen des Produkts werden defensiv behandelt.
    final matchedProductId = await _matchOrCreateProduct(
      name: deal.product,
      sku: effectiveSku,
    );

    final item = InventoryItem(
      id: _uuid.v4(),
      name: deal.product,
      sku: effectiveSku,
      quantity: deal.quantity,
      minStock: 0,
      location: location?.trim().isEmpty ?? true ? null : location!.trim(),
      costPrice: deal.ekBrutto,
      arrivalDate: deal.arrivalDate ?? DateTime.now(),
      dealId: deal.id,
      ticketNumber: deal.ticketNumber,
      ticketUrl: deal.ticketUrl,
      status: 'Im Lager',
      productId: matchedProductId,
    );

    final savedItem = await _repository.insertInventoryItem(item);
    // Stock state lives in StockProvider now — write the item + movement via
    // its cross-domain hooks (plan §3 Option A: keep checkInDeal on the deals
    // domain, write INTO stock to avoid a Stock→Inventory edge/cycle).
    _stockProvider?.upsertInventoryItemFromImport(savedItem);
    _stockProvider?.sortInventoryItems();

    final movement = InventoryMovement(
      id: _uuid.v4(),
      itemId: savedItem.id,
      date: DateTime.now(),
      quantityChange: savedItem.quantity,
      reason: 'Einbuchung via Deal',
      movementType: InventoryMovementType.goodsIn,
      unitCost: deal.ekBrutto,
      dealId: deal.id,
      ticketNumber: deal.ticketNumber,
      productId: savedItem.productId,
    );
    final savedMovement = await _repository.insertMovement(movement);
    _stockProvider?.insertMovementFromCheckIn(savedMovement);
    _stockProvider?.notifyAfterCrossDomainWrite();

    // Deal ↔ inventory-item link stays local to the deals domain.
    final dealIdx = _deals.indexWhere((d) => d.id == deal.id);
    if (dealIdx != -1) {
      _deals[dealIdx] = _deals[dealIdx].copyWith(
        inventoryItemIds: [
          ..._deals[dealIdx].inventoryItemIds,
          savedItem.id,
        ],
      );
    }

    _log('Artikel via Deal eingebucht: ${deal.product}', 'stock');
    notifyListeners();
  }

  /// Sucht ein bestehendes [Product] per SKU (primär, case-insensitiv) oder
  /// Name (sekundär, case-insensitiv) in [CatalogProvider]. Wird kein Treffer
  /// gefunden, wird ein neues Produkt über das Repository angelegt und
  /// anschließend in [CatalogProvider] nachgezogen. Schlägt das Anlegen fehl
  /// (z. B. SKU-UNIQUE-Kollision durch Race), wird `null` zurückgegeben —
  /// der Caller bucht das Item dann ohne `product_id` ein.
  ///
  /// `status` wird NICHT auf das Produkt verschoben — es bleibt auf der
  /// `inventory_items`-Bestands-Row. Der Archive-Trigger
  /// `tg_check_ticket_archive_from_inventory` und die
  /// `TicketSummary`-Aggregation über `ticket_number`/`inventoryItemIds`
  /// bleiben unberührt.
  Future<String?> _matchOrCreateProduct({
    required String name,
    String? sku,
  }) async {
    final nameLower = name.toLowerCase().trim();
    final skuLower = sku?.toLowerCase().trim();
    final catalogProducts = _catalogProducts;

    // 1. Primäres Matching: SKU (case-insensitiv) — nur wenn SKU vorhanden.
    if (skuLower != null && skuLower.isNotEmpty) {
      final bysku = catalogProducts.where((p) {
        final pSku = p.sku?.toLowerCase().trim();
        return pSku != null && pSku == skuLower;
      }).firstOrNull;
      if (bysku != null) return bysku.id;
    }

    // 2. Sekundäres Matching: Name (exakt, case-insensitiv).
    final byName = catalogProducts.where((p) {
      return p.name.toLowerCase().trim() == nameLower;
    }).firstOrNull;
    if (byName != null) return byName.id;

    // 3. Kein Treffer → neues Produkt anlegen; CatalogProvider resync async.
    try {
      final now = DateTime.now().toUtc();
      final newProduct = Product(
        id: '',
        workspaceId: _repository.activeWorkspaceId ?? '',
        userId: '',
        name: name.trim(),
        sku: sku?.trim().isEmpty ?? true ? null : sku!.trim(),
        createdAt: now,
        updatedAt: now,
      );
      final saved = await _repository.insertProduct(newProduct);
      // Resync CatalogProvider so subsequent calls see the new product.
      unawaited(_catalogProvider?.loadData().catchError((Object e) {
        if (kDebugMode) {
          debugPrint(
              '_matchOrCreateProduct: CatalogProvider resync failed (non-fatal): $e');
        }
      }));
      return saved.id;
    } catch (e) {
      // Defensiv: Wareneingang darf nicht an der Produkt-Verknüpfung scheitern.
      // Mögliche Ursachen: SKU-UNIQUE-Kollision durch Race-Condition, kein
      // aktiver Workspace, Netzwerkfehler. Item wird ohne product_id eingebucht.
      if (kDebugMode) {
        debugPrint('checkInDeal: Produkt-Anlegen fehlgeschlagen ($e) '
            '— Item wird ohne product_id eingebucht.');
      }
      return null;
    }
  }

  // ── DEAL COMMENTS ────────────────────────────────────────────────────────

  Future<List<DealComment>> loadCommentsForDeal(int dealId) =>
      _repository.loadCommentsForDeal(dealId);

  Future<DealComment> addComment({
    required int dealId,
    required String author,
    required String body,
  }) async {
    final entry = DealComment(
      id: _uuid.v4(),
      dealId: dealId,
      author: author,
      body: body,
      createdAt: DateTime.now().toUtc(),
    );
    final saved = await _repository.insertComment(entry);
    _log('Kommentar zu Deal #$dealId', 'comment');
    return saved;
  }

  Future<void> deleteComment(String id) =>
      _repository.deleteComment(id);

  // NOTE: the batch helpers (loadBatchesForItem / loadAllBatches / addBatch /
  // updateBatch / deleteBatch) have moved to [StockProvider].

  // ── Tracking-Confidence-Updates ──────────────────────────────────────────

  /// Akzeptiert das `needs_review`-Tracking eines Deals als korrekt (manual).
  /// Setzt `tracking_confidence = 'manual'`, `tracking_needs_review = false`.
  Future<void> acceptDealTrackingAsManual(int dealId) async {
    await _repository.acceptDealTrackingAsManual(dealId);
    _patchDeal(dealId, trackingConfidence: TrackingConfidence.manual, trackingNeedsReview: false);
  }

  /// Verwirft das Tracking eines Deals.
  Future<void> discardDealTracking(int dealId) async {
    await _repository.discardDealTracking(dealId);
    _patchDeal(dealId, tracking: null, trackingConfidence: TrackingConfidence.none, trackingNeedsReview: false);
  }

  /// Setzt eine manuell eingegebene Tracking-Nummer auf einem Deal.
  Future<void> updateDealTrackingManually(int dealId, String tracking) async {
    await _repository.updateDealTrackingManually(dealId, tracking);
    _patchDeal(dealId, tracking: tracking, trackingConfidence: TrackingConfidence.manual, trackingNeedsReview: false);
  }

  /// User-initiiertes Re-Tracking eines einzelnen Deals (Klarna-Pattern).
  /// Triggert die `tracking-poll` Edge-Function mit `{ deal_id }`, was den
  /// regulären Cron-Pfad für genau diesen Deal sofort ausführt. Bei Erfolg
  /// wird der lokale Cache via `loadData()` resynchronisiert — kein delta-
  /// Patch, weil der Server live_status, last_event, updated_at,
  /// arrival_date + status atomar setzt.
  Future<RetrackResult> retrackDeal(int dealId) async {
    final result = await _repository.retrackDeal(dealId);
    if (result == RetrackResult.success) {
      await loadData();
    }
    return result;
  }

  void _patchDeal(
    int dealId, {
    Object? tracking = _kSentinel,
    TrackingConfidence? trackingConfidence,
    bool? trackingNeedsReview,
  }) {
    final idx = _deals.indexWhere((d) => d.id == dealId);
    if (idx == -1) return;
    final old = _deals[idx];
    _deals[idx] = old.copyWith(
      tracking: tracking == _kSentinel ? old.tracking : tracking as String?,
      trackingConfidence: trackingConfidence ?? old.trackingConfidence,
      trackingNeedsReview: trackingNeedsReview ?? old.trackingNeedsReview,
    );
    notifyListeners();
  }

  static const Object _kSentinel = Object();

}
