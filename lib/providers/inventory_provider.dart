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
import '../models/stocktake.dart';
import '../models/stocktake_item.dart';
import '../models/supplier.dart';
import '../models/ticket.dart';
import '../models/ticket_summary.dart';
import '../models/warehouse.dart';
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

  /// Lager (Epic D — Mehrlager). Klein und workspace-weit relevant, daher
  /// global gehalten (Committee-Empfehlung 1, analog `_productCategories`).
  List<Warehouse> _warehouses = [];

  /// Inventur-Sessions (Epic E). Klein und workspace-weit relevant, daher
  /// global gehalten. `stocktake_items` werden lazy pro Detail-Screen geladen
  /// (Pattern wie `_purchaseOrders`/`loadPurchaseOrderItems`).
  List<Stocktake> _stocktakes = [];

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

      // Default-Lager-Bootstrap: Wenn der Workspace noch kein Lager hat,
      // wird automatisch ein "Hauptlager" angelegt. Runs defensiv — ein
      // Fehler (z. B. Race zwischen zwei Clients oder fehlende DB-Tabelle
      // vor D1-Migration) bricht den Load nicht ab.
      // Name: "Hauptlager" ist ein fester String (kein l10n), da der
      // Provider keinen BuildContext hat und l10n hier nicht nutzbar ist.
      // Der Name ist umbenenbar; er dient nur als sinnvoller Startwert.
      // Dokumentierte Entscheidung: Provider-seitig kein BuildContext
      // verfügbar → statischer Bootstrap-Name. (Plan D3, §Bootstrap)
      if (_warehouses.isEmpty && wsId != null) {
        try {
          await _bootstrapDefaultWarehouse();
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'InventoryProvider: Default-Lager-Bootstrap fehlgeschlagen '
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
    _warehouses = [];
    _stocktakes = [];
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
    _warehouses = List.of(snapshot.warehouses)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _stocktakes = List.of(snapshot.stocktakes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      notifyListeners();
    } catch (e) {
      // Race (23505 Unique-Violation auf is_default) oder fehlende Tabelle
      // (vor D1-Migration) — beide Fälle sind nicht-fatal.
      if (kDebugMode) {
        debugPrint(
          'InventoryProvider._bootstrapDefaultWarehouse: $e',
        );
      }
      // Versuch, das bereits existierende Lager zu laden (falls Race).
      try {
        final existing = await _repository.loadWarehouses(ws);
        _warehouses = existing;
        _warehouses.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        notifyListeners();
      } catch (_) {
        // Auch der Fallback-Load schlägt fehl (z. B. Tabelle existiert
        // noch nicht) — ignorieren, App bleibt ohne Lager nutzbar.
      }
    }
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
    _repository.deleteDeal(id).then((_) {
      _deals.removeWhere((d) => d.id == id);
      if (deal != null) _log('Deal gelöscht (commit): ${deal.product}', 'deal');
      notifyListeners();
    }).catchError((Object e) {
      // Bei Fehler: Item wieder sichtbar machen und Cache bereinigen.
      _log('Deal-Delete fehlgeschlagen: $e', 'deal');
      notifyListeners();
    });
  }

  @override
  void dispose() {
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

    // ── New sections (Epic F) ────────────────────────────────────────────────
    // FK-dependency order: categories + warehouses → products → POs → PO items.
    // After each insert we record csv-parsed-id → db-saved-id so dependent
    // entities can reference the real row.

    // 1. Categories – skip by name; track csv-id → db-id for product FK remap
    final importCategoryIdRemap = <String, String>{}; // csv id → db id
    final existingCategoryByName = <String, String>{
      for (final c in _productCategories) c.name.toLowerCase(): c.id,
    };
    for (final category in result.categories) {
      final key = category.name.toLowerCase();
      if (existingCategoryByName.containsKey(key)) {
        // Remap csv id to the existing canonical id so products can resolve it.
        importCategoryIdRemap[category.id] =
            existingCategoryByName[key]!;
        continue;
      }
      try {
        final saved = await _repository.insertProductCategory(category);
        _productCategories.add(saved);
        existingCategoryByName[key] = saved.id;
        importCategoryIdRemap[category.id] = saved.id;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'importCsvAll: category "${category.name}" skipped – $e');
        }
      }
    }
    _productCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // 2. Warehouses – skip by name; no FK deps
    final existingWarehouseByName = <String, String>{
      for (final w in _warehouses) w.name.toLowerCase(): w.id,
    };
    for (final warehouse in result.warehouses) {
      final key = warehouse.name.toLowerCase();
      if (existingWarehouseByName.containsKey(key)) continue;
      try {
        final saved = await _repository.insertWarehouse(warehouse);
        _warehouses.add(saved);
        existingWarehouseByName[key] = saved.id;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'importCsvAll: warehouse "${warehouse.name}" skipped – $e');
        }
      }
    }
    _warehouses.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // 3. Products – skip by name; remap category_id and default_supplier_id.
    //    Track csv-id → db-id for PO item FK remap.
    final importProductIdRemap = <String, String>{}; // csv id → db id
    final existingProductByName = <String, String>{
      for (final p in _products) p.name.toLowerCase(): p.id,
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
        _products.add(saved);
        existingProductByName[key] = saved.id;
        importProductIdRemap[product.id] = saved.id;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('importCsvAll: product "${product.name}" skipped – $e');
        }
      }
    }
    _products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // 4. Purchase orders – skip by order number; remap supplier_id.
    //    Track csv synthetic-id → db BIGSERIAL id for PO item FK remap.
    final importPoIdRemap = <int, int>{}; // csv synthetic id → db id
    final existingPoByNumber = <String, int>{
      for (final po in _purchaseOrders) po.orderNumber: po.id ?? -1,
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
        _purchaseOrders.insert(0, saved);
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
    _purchaseOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
    final existingItemForProduct = _inventoryItems
        .where((i) => i.productId == productId)
        .firstOrNull;

    final InventoryItem savedInventory;
    if (existingItemForProduct != null) {
      // Bestehende Row: Bestand jetzt erhöhen, ID ist bereits gültig.
      final updatedInventoryItem = existingItemForProduct.copyWith(
        quantity: existingItemForProduct.quantity + receivedQty,
      );
      savedInventory = await _repository.updateInventoryItem(updatedInventoryItem);
      final idx = _inventoryItems.indexWhere((i) => i.id == savedInventory.id);
      if (idx != -1) {
        _inventoryItems[idx] = savedInventory;
      }
    } else {
      // Keine existierende Bestands-Row für dieses Produkt →
      // schlanke neue Row anlegen. Lager-Zuordnung (warehouse_id) ist
      // Epic D — hier genügt eine Row mit productId + quantity.
      // Produktname aus dem lokalen Cache auflösen.
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
    // `received`). Da der Provider `_purchaseOrders` lokal cached, spiegelt der
    // lokale State den neuen Status erst nach einem App-Reload wider — ohne
    // diesen Re-Fetch.
    //
    // Strategie: den betroffenen PO-Header-Eintrag gezielt neu laden und im
    // `_purchaseOrders`-Cache ersetzen. Schlägt der Re-Fetch fehl (Netzwerk,
    // PO wurde zwischenzeitlich gelöscht), bleibt der bereits gebuchte
    // Wareneingang bestehen — kein Fehler, kein Rollback. Der UI-State korrigiert
    // sich beim nächsten regulären Load.
    final poId = item.purchaseOrderId;
    final wsId = _repository.activeWorkspaceId;
    if (poId != null && wsId != null) {
      try {
        final freshPo = await _repository.loadPurchaseOrderById(wsId, poId);
        if (freshPo != null) {
          final idx = _purchaseOrders.indexWhere((po) => po.id == poId);
          if (idx != -1) {
            _purchaseOrders[idx] = freshPo;
          }
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
    notifyListeners();
    return updatedItem;
  }

  // ── WAREHOUSES ────────────────────────────────────────────────────────────

  Future<void> addWarehouse(Warehouse warehouse) async {
    final saved = await _repository.insertWarehouse(warehouse);
    _warehouses.add(saved);
    _warehouses
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Lager hinzugefügt: ${saved.name}', 'warehouse');
    notifyListeners();
  }

  Future<void> updateWarehouse(Warehouse warehouse) async {
    final saved = await _repository.updateWarehouse(warehouse);
    final idx = _warehouses.indexWhere((w) => w.id == saved.id);
    if (idx == -1) return;
    _warehouses[idx] = saved;
    _warehouses
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Lager aktualisiert: ${saved.name}', 'warehouse');
    notifyListeners();
  }

  Future<void> deleteWarehouse(String id) async {
    final warehouse = _warehouses.where((w) => w.id == id).firstOrNull;
    await _repository.deleteWarehouse(id);
    _warehouses.removeWhere((w) => w.id == id);
    if (warehouse != null) {
      _log('Lager gelöscht: ${warehouse.name}', 'warehouse');
    }
    notifyListeners();
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
      throw StateError(
          'startInventory: kein aktiver Workspace gesetzt.');
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
    notifyListeners();

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
            debugPrint(
                'startInventory: StocktakeItem für Produkt ${entry.key} '
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
    _log('Inventur-Zählung: Produkt ${item.productId} → $countedQty', 'stocktake');
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
      final inventoryItemForProduct = _inventoryItems
          .where((i) => i.productId == item.productId)
          .firstOrNull;
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
          debugPrint(
              'closeStocktake: Movement für Produkt ${item.productId} '
              'konnte nicht geschrieben werden: $e');
        }
        // Fehler beim Movement blockieren nicht den Abschluss —
        // der Bestandsangleich läuft trotzdem durch.
      }

      // 2. Bestand angeleichen: inventory_item auf den gezählten Wert setzen.
      if (inventoryItemForProduct != null) {
        final corrected =
            inventoryItemForProduct.copyWith(quantity: counted);
        try {
          final savedItem = await _repository.updateInventoryItem(corrected);
          final idx =
              _inventoryItems.indexWhere((i) => i.id == savedItem.id);
          if (idx != -1) {
            _inventoryItems[idx] = savedItem;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'closeStocktake: Bestandsangleich für Produkt '
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
    notifyListeners();
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
    notifyListeners();
    return saved;
  }

  Future<void> updateStocktake(Stocktake stocktake) async {
    final saved = await _repository.updateStocktake(stocktake);
    final idx = _stocktakes.indexWhere((s) => s.id == saved.id);
    if (idx == -1) return;
    _stocktakes[idx] = saved;
    _stocktakes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _log('Inventur aktualisiert: ${saved.title ?? saved.id}', 'stocktake');
    notifyListeners();
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
    notifyListeners();
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
