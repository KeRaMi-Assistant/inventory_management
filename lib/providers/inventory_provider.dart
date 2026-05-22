import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_entry.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/tracking_confidence.dart';
import '../models/deal_comment.dart';
import '../models/inventory_batch.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/product_stock.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/shop.dart';
import '../models/supplier.dart';
import '../models/ticket.dart';
import '../models/ticket_summary.dart';
import '../services/carrier_service.dart';
import '../services/csv_service.dart';
import '../services/supabase_repository.dart';

/// Holds the full working set of cloud data for the signed-in user and routes
/// every mutation through [SupabaseRepository]. Local lists are caches kept in
/// sync with the server so the rest of the UI can stay synchronous.
class InventoryProvider extends ChangeNotifier {
  InventoryProvider({required SupabaseRepository repository})
      : _repository = repository;

  final SupabaseRepository _repository;
  final _uuid = const Uuid();

  List<Deal> _deals = [];
  List<Buyer> _buyers = [];
  List<Shop> _shops = [];
  List<Supplier> _suppliers = [];
  List<InventoryItem> _inventoryItems = [];
  List<InventoryMovement> _movements = [];
  List<ActivityEntry> _activities = [];
  List<Ticket> _tickets = [];
  List<ProductCategory> _productCategories = [];
  List<Product> _products = [];

  /// Bestellköpfe (Epic C). `purchase_order_items` werden NICHT global
  /// gehalten — sie werden lazy pro Detail-Screen geladen (Committee-
  /// Empfehlung 1, analog `loadBatchesForItem`).
  List<PurchaseOrder> _purchaseOrders = [];

  /// Aggregierter Lagerbestand aus dem DB-View `product_stock` (Epic A-full,
  /// read-only). Jede Row = Bestand eines Produkts pro Lager. Wird in
  /// [loadData] nach [loadAll] geladen — der View ist klein (workspace-weit)
  /// und wird für KPI-Aggregation in [criticalStockCount] benötigt.
  List<ProductStock> _productStock = [];

  bool _loading = false;
  Object? _lastError;

  bool get isLoading => _loading;
  Object? get lastError => _lastError;

  /// Sorted views — the underlying lists are pre-sorted on every load so the
  /// getters are O(n) wraps, not O(n log n) re-sorts.
  List<Deal> get deals => List.unmodifiable(_deals);
  List<Buyer> get buyers => List.unmodifiable(_buyers);
  List<Shop> get shops => List.unmodifiable(_shops);
  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  List<Supplier> get activeSuppliers =>
      List.unmodifiable(_suppliers.where((s) => s.active));
  List<InventoryItem> get inventoryItems => List.unmodifiable(_inventoryItems);
  List<InventoryMovement> get movements => List.unmodifiable(_movements);
  List<ActivityEntry> get activities => List.unmodifiable(_activities);
  List<Ticket> get tickets => List.unmodifiable(_tickets);
  List<ProductCategory> get productCategories =>
      List.unmodifiable(_productCategories);
  List<Product> get products => List.unmodifiable(_products);

  /// Bestellköpfe, absteigend nach Erstellungsdatum sortiert.
  List<PurchaseOrder> get purchaseOrders =>
      List.unmodifiable(_purchaseOrders);

  /// Aggregierter Lagerbestand pro Produkt/Lager aus dem View `product_stock`.
  /// Nur Rows mit `product_id IS NOT NULL` — nicht-verknüpfte Items fehlen
  /// hier bewusst (sie fallen nicht in den View). Für KPI-Nutzung in
  /// [criticalStockCount] und später im Produkt-Detail-Screen (AF12).
  List<ProductStock> get productStock => List.unmodifiable(_productStock);

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

  /// Anzahl der Artikel/Produkte, deren Gesamtbestand unter dem Mindestbestand
  /// liegt (Kritisch-Bewertung).
  ///
  /// **Aggregations-Logik (Epic A-full / Committee-Finding 9):**
  /// - Produkt-verknüpfte Items (`product_id != null`) werden pro Produkt
  ///   aggregiert: Gesamtbestand = Summe aller `product_stock.qty_in_warehouse`
  ///   über alle Lager eines Produkts. Verglichen wird gegen
  ///   `products.min_stock`. Ein Produkt zählt genau einmal — auch wenn es
  ///   mehrere `inventory_items`-Rows hat (z. B. unterschiedliche Lager/Chargen).
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
    final productIds = _products.map((p) => p.id).toSet();
    final productMinStock = <String, int>{
      for (final p in _products) p.id: p.minStock,
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

  int get missingInvoiceCount =>
      _deals.where((d) => !d.hasReceipt && d.status != 'Done').length;

  /// Gesamtmenge aller Lagerartikel (Summe aller `inventory_items.quantity`).
  ///
  /// `quantity` ist die physische Wahrheit pro Bestands-Row — die Summierung
  /// hier ist korrekt. Nur die *kritisch*-Bewertung muss aggregieren (per
  /// Produkt), die Gesamtmenge nicht. Enthält auch nicht-verknüpfte Rows.
  int get totalStockQuantity =>
      _inventoryItems.fold(0, (sum, item) => sum + item.quantity);

  double get totalStockValue =>
      _inventoryItems.fold(0, (sum, item) => sum + item.stockValue);

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
      final items = _inventoryItems
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

  Future<void> loadData() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      // Workspace-ID aus dem Repository holen (der Single Source of Truth für
      // den aktiven Workspace): `_repository.activeWorkspaceId` ist auch für
      // Test-Fakes korrekt befüllt, während `_activeWorkspaceId` bei direkten
      // `loadData()`-Aufrufen (ohne vorangehendes `setActiveWorkspace`) null
      // sein kann.
      final wsId = _repository.activeWorkspaceId ?? _activeWorkspaceId;

      // Hauptdaten laden.
      final snapshot = await _repository.loadAll();
      _hydrateFrom(snapshot);

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
            debugPrint('InventoryProvider: product_stock konnte nicht geladen '
                'werden (non-fatal): $e');
          }
        }
      } else {
        _productStock = [];
      }
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InventoryProvider.loadData failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Wipes local caches — used on sign-out so the next user starts clean.
  void clearLocalState() {
    _deals = [];
    _buyers = [];
    _shops = [];
    _suppliers = [];
    _inventoryItems = [];
    _movements = [];
    _activities = [];
    _tickets = [];
    _productCategories = [];
    _products = [];
    _purchaseOrders = [];
    _productStock = [];
    _lastError = null;
    _activeWorkspaceId = null;
    _repository.setActiveWorkspace(null);
    notifyListeners();
  }

  void _hydrateFrom(CloudSnapshot snapshot) {
    _deals = List.of(snapshot.deals)..sort((a, b) => b.id.compareTo(a.id));
    _buyers = List.of(snapshot.buyers)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _shops = List.of(snapshot.shops);
    _suppliers = List.of(snapshot.suppliers)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _inventoryItems = List.of(snapshot.inventoryItems)
      ..sort((a, b) => a.name.compareTo(b.name));
    _movements = List.of(snapshot.movements)
      ..sort((a, b) => b.date.compareTo(a.date));
    _activities = List.of(snapshot.activities)
      ..sort((a, b) => b.date.compareTo(a.date));
    _tickets = List.of(snapshot.tickets);
    _productCategories = List.of(snapshot.productCategories)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _products = List.of(snapshot.products)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _purchaseOrders = List.of(snapshot.purchaseOrders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  /// Imports all five tables from a [CsvImportResult].
  /// Deals are always appended. Shops, buyers, suppliers and inventory items
  /// are only added when no existing entry with the same name exists.
  /// Returns counts in order: (deals, shops, buyers, suppliers, items).
  Future<(int, int, int, int, int)> importCsvAll(CsvImportResult result) async {
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

    // Suppliers – skip names that already exist; build name→id map for inventory remap
    int supplierCount = 0;
    final existingSupplierByName = <String, String>{
      for (final s in _suppliers) s.name.toLowerCase(): s.id,
    };
    for (final supplier in result.suppliers) {
      final key = supplier.name.toLowerCase();
      if (existingSupplierByName.containsKey(key)) continue;
      final withId =
          supplier.id.isEmpty ? supplier.copyWith(id: _uuid.v4()) : supplier;
      final saved = await _repository.insertSupplier(withId);
      _suppliers.add(saved);
      existingSupplierByName[key] = saved.id;
      supplierCount++;
    }
    _suppliers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Map import-supplier-id → existing supplier-id by name (so items
    // referencing an import-time supplier-id resolve to the canonical row).
    final importSupplierIdRemap = <String, String>{};
    for (final s in result.suppliers) {
      final canonical = existingSupplierByName[s.name.toLowerCase()];
      if (canonical != null) importSupplierIdRemap[s.id] = canonical;
    }

    // Inventory items – skip names that already exist; skip items that fail to insert
    int itemCount = 0;
    final existingItemNames = _inventoryItems.map((i) => i.name.toLowerCase()).toSet();
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
        _inventoryItems.add(saved);
        existingItemNames.add(saved.name.toLowerCase());
        itemCount++;
      } catch (e) {
        if (kDebugMode) debugPrint('importCsvAll: item "${item.name}" skipped – $e');
      }
    }
    _inventoryItems.sort((a, b) => a.name.compareTo(b.name));

    if (dealCount > 0 ||
        shopCount > 0 ||
        buyerCount > 0 ||
        supplierCount > 0 ||
        itemCount > 0) {
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

  // ── SUPPLIERS ─────────────────────────────────────────────────────────────

  Future<void> addSupplier(Supplier supplier) async {
    final saved = await _repository.insertSupplier(supplier);
    _suppliers.add(saved);
    _suppliers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Lieferant hinzugefügt: ${saved.name}', 'supplier');
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final saved = await _repository.updateSupplier(supplier);
    final idx = _suppliers.indexWhere((s) => s.id == saved.id);
    if (idx == -1) return;
    _suppliers[idx] = saved;
    _suppliers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
    final existing = _suppliers
        .map((s) => s.name.trim().toLowerCase())
        .toSet();
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
      _suppliers.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _log('$added Versanddienst-Lieferanten hinzugefügt', 'supplier');
      notifyListeners();
    }
    return (added: added, skipped: skipped);
  }

  // ── PRODUCT CATEGORIES ────────────────────────────────────────────────────

  Future<void> addProductCategory(ProductCategory category) async {
    final saved = await _repository.insertProductCategory(category);
    _productCategories.add(saved);
    _productCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _log('Warengruppe hinzugefügt: ${saved.name}', 'category');
    notifyListeners();
  }

  Future<void> updateProductCategory(ProductCategory category) async {
    final saved = await _repository.updateProductCategory(category);
    final idx = _productCategories.indexWhere((c) => c.id == saved.id);
    if (idx == -1) return;
    _productCategories[idx] = saved;
    _productCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _log('Warengruppe aktualisiert: ${saved.name}', 'category');
    notifyListeners();
  }

  Future<void> deleteProductCategory(String id) async {
    final category =
        _productCategories.where((c) => c.id == id).firstOrNull;
    await _repository.deleteProductCategory(id);
    _productCategories.removeWhere((c) => c.id == id);
    if (category != null) {
      _log('Warengruppe gelöscht: ${category.name}', 'category');
    }
    notifyListeners();
  }

  // ── PRODUCTS ──────────────────────────────────────────────────────────────

  Future<void> addProduct(Product product) async {
    final saved = await _repository.insertProduct(product);
    _products.add(saved);
    _products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Artikel hinzugefügt: ${saved.name}', 'product');
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final saved = await _repository.updateProduct(product);
    final idx = _products.indexWhere((p) => p.id == saved.id);
    if (idx == -1) return;
    _products[idx] = saved;
    _products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Artikel aktualisiert: ${saved.name}', 'product');
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    final product = _products.where((p) => p.id == id).firstOrNull;
    await _repository.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    if (product != null) {
      _log('Artikel gelöscht: ${product.name}', 'product');
    }
    notifyListeners();
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

  Future<PurchaseOrderItem> addPurchaseOrderItem(
      PurchaseOrderItem item) async {
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
  ///    schlanke neue Row an (`insertInventoryItem`). Das Anlegen einer
  ///    vollständigen Lager-Row (inkl. Lager/Warehouse) ist Epic D —
  ///    für C4 genügt eine schlanke Row mit `productId`, `quantity` und
  ///    `status = 'Im Lager'`.
  ///
  /// Wirft, wenn `item.productId == null` (PO-Position ohne verknüpftes
  /// Produkt), wenn `receivedQty <= 0`, oder wenn die RPC fehlschlägt.
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

    // 1. Atomares Increment auf der Datenbank-Seite.
    final updatedItem =
        await _repository.incrementPoItemReceived(item.id, receivedQty);

    // 2. goods_in-Movement für das Produkt schreiben.
    //    itemId: wir verwenden die item.id der Bestellposition als Referenz.
    //    Da inventory_movements.item_id auf inventory_items verweist und hier
    //    eine PO-Position die Quelle ist, setzen wir itemId optional auf die
    //    erste existierende Bestands-Row des Produkts (oder leer, falls keine).
    //    Das Movement ist primär über product_id auswertbar (Epic A-full).
    // _inventoryItems enthält nur aktive Items (deleted_at IS NULL ist beim
    // Load bereits gefiltert). Kein deletedAt auf InventoryItem-Model nötig.
    final existingItemForProduct = _inventoryItems
        .where((i) => i.productId == productId)
        .firstOrNull;

    final movement = InventoryMovement(
      id: _uuid.v4(),
      itemId: existingItemForProduct?.id ?? item.id,
      date: DateTime.now(),
      quantityChange: receivedQty,
      reason: 'Wareneingang gegen Bestellung',
      movementType: InventoryMovementType.goodsIn,
      unitCost: item.unitPrice,
      productId: productId,
    );
    final savedMovement = await _repository.insertMovement(movement);
    _movements.insert(0, savedMovement);

    // 3. Bestand erhöhen.
    if (existingItemForProduct != null) {
      // Bestehende Row erhöhen.
      final updatedInventory = existingItemForProduct.copyWith(
        quantity: existingItemForProduct.quantity + receivedQty,
      );
      final savedInventory =
          await _repository.updateInventoryItem(updatedInventory);
      final idx =
          _inventoryItems.indexWhere((i) => i.id == savedInventory.id);
      if (idx != -1) {
        _inventoryItems[idx] = savedInventory;
      }
    } else {
      // Keine existierende Bestands-Row für dieses Produkt →
      // schlanke neue Row anlegen. Lager-Zuordnung (warehouse_id) ist
      // Epic D — hier genügt eine Row mit productId + quantity.
      // Der Produktname wird aus dem lokalen Cache gelöst.
      final product = _products.where((p) => p.id == productId).firstOrNull;
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
      final savedInventory = await _repository.insertInventoryItem(newItem);
      _inventoryItems.add(savedInventory);
      _inventoryItems.sort((a, b) => a.name.compareTo(b.name));
    }

    _log(
      'Wareneingang gebucht: +$receivedQty für Produkt $productId',
      'purchase_order',
    );
    notifyListeners();
    return updatedItem;
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
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    final item = _inventoryItems.where((i) => i.id == id).firstOrNull;
    await _repository.deleteInventoryItem(id);
    _inventoryItems.removeWhere((i) => i.id == id);
    // ON DELETE CASCADE removes movements server-side; mirror that locally.
    _movements.removeWhere((m) => m.itemId == id);
    if (item != null) _log('Lagerartikel gelöscht: ${item.name}', 'stock');
    notifyListeners();
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
      unitCost: movementType == InventoryMovementType.goodsIn
          ? current.costPrice
          : null,
      dealId: dealId,
      ticketNumber: ticketNumber,
      productId: current.productId,
    );
    final savedMovement = await _repository.insertMovement(movement);
    _movements.insert(0, savedMovement);

    _log('Lagerbewegung: ${current.name} ${delta > 0 ? '+' : ''}$delta',
        'stock');
    notifyListeners();
  }

  Future<void> checkInDeal(
    Deal deal, {
    String? location,
    String? sku,
  }) async {
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
    _inventoryItems.add(savedItem);
    _inventoryItems.sort((a, b) => a.name.compareTo(b.name));

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
    _movements.insert(0, savedMovement);

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
  /// Name (sekundär, case-insensitiv) in `_products`. Wird kein Treffer
  /// gefunden, wird ein neues Produkt über das Repository angelegt und in
  /// `_products` aufgenommen. Schlägt das Anlegen fehl (z. B. SKU-UNIQUE-
  /// Kollision durch Race), wird `null` zurückgegeben — der Caller bucht
  /// das Item dann ohne `product_id` ein.
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

    // 1. Primäres Matching: SKU (case-insensitiv) — nur wenn SKU vorhanden.
    if (skuLower != null && skuLower.isNotEmpty) {
      final bysku = _products.where((p) {
        final pSku = p.sku?.toLowerCase().trim();
        return pSku != null && pSku == skuLower;
      }).firstOrNull;
      if (bysku != null) return bysku.id;
    }

    // 2. Sekundäres Matching: Name (exakt, case-insensitiv).
    final byName = _products.where((p) {
      return p.name.toLowerCase().trim() == nameLower;
    }).firstOrNull;
    if (byName != null) return byName.id;

    // 3. Kein Treffer → neues Produkt anlegen.
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
      _products.add(saved);
      _products.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  // ── BATCHES ───────────────────────────────────────────────────────────────

  Future<List<InventoryBatch>> loadBatchesForItem(String itemId) =>
      _repository.loadBatchesForItem(itemId);

  /// Lädt alle Chargen über alle Items. Für die Statistik-Tabs (Lager-KPIs).
  /// Wird gecached im StatisticsService.
  Future<List<InventoryBatch>> loadAllBatches() =>
      _repository.loadAllBatches();

  Future<InventoryBatch> addBatch(InventoryBatch batch) async {
    final saved = await _repository.insertBatch(batch);
    _log('Charge hinzugefügt: ${saved.batchNumber}', 'batch');
    notifyListeners();
    return saved;
  }

  Future<InventoryBatch> updateBatch(InventoryBatch batch) async {
    final saved = await _repository.updateBatch(batch);
    notifyListeners();
    return saved;
  }

  Future<void> deleteBatch(String id) async {
    await _repository.deleteBatch(id);
    notifyListeners();
  }

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
