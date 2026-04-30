import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_entry.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/inventory_item.dart';
import '../models/shop.dart';
import '../models/ticket_summary.dart';
import '../services/csv_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_repository.dart';

/// Holds the full working set of cloud data for the signed-in user and routes
/// every mutation through [SupabaseRepository]. Local lists are caches kept in
/// sync with the server so the rest of the UI can stay synchronous.
class InventoryProvider extends ChangeNotifier {
  InventoryProvider({required SupabaseRepository repository})
      : _repository = repository;

  final SupabaseRepository _repository;
  final StorageService _legacyStorage = StorageService();
  final _uuid = const Uuid();

  List<Deal> _deals = [];
  List<Buyer> _buyers = [];
  List<Shop> _shops = [];
  List<InventoryItem> _inventoryItems = [];
  List<InventoryMovement> _movements = [];
  List<ActivityEntry> _activities = [];

  bool _loading = false;
  Object? _lastError;

  bool get isLoading => _loading;
  Object? get lastError => _lastError;

  /// Sorted views — the underlying lists are pre-sorted on every load so the
  /// getters are O(n) wraps, not O(n log n) re-sorts.
  List<Deal> get deals => List.unmodifiable(_deals);
  List<Buyer> get buyers => List.unmodifiable(_buyers);
  List<Shop> get shops => List.unmodifiable(_shops);
  List<InventoryItem> get inventoryItems => List.unmodifiable(_inventoryItems);
  List<InventoryMovement> get movements => List.unmodifiable(_movements);
  List<ActivityEntry> get activities => List.unmodifiable(_activities);

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
  static const List<String> shippingTypes = ['Reship', 'Dropship'];
  static const List<String> belegOptions = ['Ja', 'Nein'];

  // ── Derived KPIs ──────────────────────────────────────────────────────────

  int get openOrdersCount =>
      _deals.where((d) => d.status == 'Bestellt').length;

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

  int get criticalStockCount =>
      _inventoryItems.where((item) => item.isCritical).length;

  int get missingInvoiceCount =>
      _deals.where((d) => d.beleg == 'Nein' && d.status != 'Done').length;

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

  List<TicketSummary> get ticketSummaries {
    final grouped = <String, List<Deal>>{};
    for (final deal in _deals) {
      final key = (deal.ticketNumber == null || deal.ticketNumber!.trim().isEmpty)
          ? 'Kein Ticket'
          : deal.ticketNumber!.trim();
      grouped.putIfAbsent(key, () => []).add(deal);
    }
    final summaries = grouped.entries.map((entry) {
      final items = _inventoryItems
          .where((item) =>
              item.ticketNumber == entry.key ||
              entry.value.any((deal) => deal.inventoryItemIds.contains(item.id)))
          .toList();
      return TicketSummary(
        ticketNumber: entry.key,
        deals: entry.value,
        items: items,
      );
    }).toList();
    summaries.sort((a, b) => b.newestDate.compareTo(a.newestDate));
    return summaries;
  }

  // ── Load / clear ──────────────────────────────────────────────────────────

  Future<void> loadData() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final snapshot = await _repository.loadAll();
      _hydrateFrom(snapshot);
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
    _inventoryItems = [];
    _movements = [];
    _activities = [];
    _lastError = null;
    notifyListeners();
  }

  void _hydrateFrom(CloudSnapshot snapshot) {
    _deals = List.of(snapshot.deals)..sort((a, b) => b.id.compareTo(a.id));
    _buyers = List.of(snapshot.buyers)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _shops = List.of(snapshot.shops);
    _inventoryItems = List.of(snapshot.inventoryItems)
      ..sort((a, b) => a.name.compareTo(b.name));
    _movements = List.of(snapshot.movements)
      ..sort((a, b) => b.date.compareTo(a.date));
    _activities = List.of(snapshot.activities)
      ..sort((a, b) => b.date.compareTo(a.date));
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

  Future<void> addDeal(Deal deal) async {
    final saved = await _repository.insertDeal(deal);
    _deals.insert(0, saved);
    _log('Deal hinzugefügt: ${saved.product}', 'deal');
    notifyListeners();
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

  /// Imports all four tables from a [CsvImportResult].
  /// Deals are always appended. Shops, buyers and inventory items are only
  /// added when no existing entry with the same name exists (avoids duplicates).
  Future<(int, int, int, int)> importCsvAll(CsvImportResult result) async {
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

    // Inventory items – skip names that already exist; skip items that fail to insert
    int itemCount = 0;
    final existingItemNames = _inventoryItems.map((i) => i.name.toLowerCase()).toSet();
    for (final item in result.inventoryItems) {
      if (existingItemNames.contains(item.name.toLowerCase())) continue;
      final withId = item.id.isEmpty ? item.copyWith(id: _uuid.v4()) : item;
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

    if (dealCount > 0 || shopCount > 0 || buyerCount > 0 || itemCount > 0) {
      _log('CSV-Import: $dealCount Deals, $shopCount Shops, $buyerCount Käufer, $itemCount Lagerartikel', 'import');
      notifyListeners();
    }
    return (dealCount, shopCount, buyerCount, itemCount);
  }

  /// Seeds 6 example inventory items into the DB.
  /// Safe to call multiple times — skips items whose name already exists.
  Future<int> seedDemoInventory() async {
    final now = DateTime.now();
    final demos = [
      InventoryItem(id: _uuid.v4(), name: 'Nike Air Max 90', sku: 'AIR-MAX-90', quantity: 2, minStock: 1, location: 'Regal A-1', costPrice: 89.0, arrivalDate: now.subtract(const Duration(days: 1)), status: 'Im Lager', note: 'Demo-Artikel'),
      InventoryItem(id: _uuid.v4(), name: 'New Balance 550 White', sku: 'NB-550-WHT', quantity: 1, minStock: 0, location: 'Regal B-3', costPrice: 75.0, arrivalDate: now.subtract(const Duration(days: 15)), status: 'Reserviert', note: 'Reserviert für Käufer'),
      InventoryItem(id: _uuid.v4(), name: 'Supreme Box Logo Tee', sku: 'SUP-BOX-TEE', quantity: 5, minStock: 0, costPrice: 42.0, arrivalDate: now.subtract(const Duration(days: 22)), status: 'Im Lager'),
      InventoryItem(id: _uuid.v4(), name: 'Puma Suede Classic', sku: 'PUMA-SDE-CLS', quantity: 4, minStock: 0, costPrice: 35.0, arrivalDate: now.subtract(const Duration(days: 20)), status: 'Im Lager'),
      InventoryItem(id: _uuid.v4(), name: 'Vintage Levi\'s 501', sku: 'LEV-501-VTG', quantity: 3, minStock: 2, location: 'Regal C-2', costPrice: 45.0, arrivalDate: now.subtract(const Duration(days: 41)), status: 'Im Lager', note: 'Direkteinkauf'),
      InventoryItem(id: _uuid.v4(), name: 'Lagerartikel Kritisch', sku: 'KRIT-SNK-001', quantity: 0, minStock: 2, location: 'Regal D-1', costPrice: 80.0, arrivalDate: now.subtract(const Duration(days: 60)), status: 'Im Lager', note: 'Mindestbestand unterschritten'),
    ];
    int added = 0;
    final existingNames = _inventoryItems.map((i) => i.name.toLowerCase()).toSet();
    for (final item in demos) {
      if (existingNames.contains(item.name.toLowerCase())) continue;
      try {
        final saved = await _repository.insertInventoryItem(item);
        _inventoryItems.add(saved);
        existingNames.add(saved.name.toLowerCase());
        added++;
      } catch (e) {
        if (kDebugMode) debugPrint('seedDemoInventory: "${item.name}" skipped – $e');
      }
    }
    if (added > 0) {
      _inventoryItems.sort((a, b) => a.name.compareTo(b.name));
      _log('Demo-Lager: $added Artikel angelegt', 'seed');
      notifyListeners();
    }
    return added;
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
        dealId: saved.dealId,
        ticketNumber: saved.ticketNumber,
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
      final movement = InventoryMovement(
        id: _uuid.v4(),
        itemId: saved.id,
        date: DateTime.now(),
        quantityChange: delta,
        reason: delta > 0 ? 'Einbuchung' : 'Ausbuchung',
        dealId: saved.dealId,
        ticketNumber: saved.ticketNumber,
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
      dealId: dealId,
      ticketNumber: ticketNumber,
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
    final item = InventoryItem(
      id: _uuid.v4(),
      name: deal.product,
      sku: sku?.trim().isEmpty ?? true ? null : sku!.trim(),
      quantity: deal.quantity,
      minStock: 0,
      location: location?.trim().isEmpty ?? true ? null : location!.trim(),
      costPrice: deal.ekBrutto,
      arrivalDate: deal.arrivalDate ?? DateTime.now(),
      dealId: deal.id,
      ticketNumber: deal.ticketNumber,
      ticketUrl: deal.ticketUrl,
      status: 'Im Lager',
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
      dealId: deal.id,
      ticketNumber: deal.ticketNumber,
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

  // ── JSON backup / restore (across the whole user-scoped dataset) ──────────

  Map<String, dynamic> exportData() => {
        'deals': _deals.map((d) => d.toJson()).toList(),
        'buyers': _buyers.map((b) => b.toJson()).toList(),
        'shops': _shops.map((s) => s.toJson()).toList(),
        'inventoryItems': _inventoryItems.map((i) => i.toJson()).toList(),
        'movements': _movements.map((m) => m.toJson()).toList(),
        'activities': _activities.map((a) => a.toJson()).toList(),
      };

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(exportData());

  /// Replaces the user's cloud dataset with the contents of [data]. Used by
  /// the JSON-Restore flow in Settings.
  Future<void> restoreData(Map<String, dynamic> data) async {
    final deals = (data['deals'] as List<dynamic>? ?? [])
        .map((e) => Deal.fromJson(e as Map<String, dynamic>))
        .toList();
    final buyers = (data['buyers'] as List<dynamic>? ?? [])
        .map((e) => Buyer.fromJson(e as Map<String, dynamic>))
        .toList();
    final shops = (data['shops'] as List<dynamic>? ?? [])
        .map((e) => Shop.fromJson(e as Map<String, dynamic>))
        .toList();
    final items = (data['inventoryItems'] as List<dynamic>? ?? [])
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final movements = (data['movements'] as List<dynamic>? ?? [])
        .map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>))
        .toList();
    final activities = (data['activities'] as List<dynamic>? ?? [])
        .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    await _repository.deleteAllForCurrentUser();
    final snapshot = await _repository.bulkImport(
      buyers: buyers,
      shops: shops,
      deals: deals,
      items: items,
      movements: movements,
      activities: activities,
    );
    _hydrateFrom(snapshot);
    notifyListeners();
  }

  /// One-shot migration: pulls the legacy shared_preferences JSON blob (if
  /// any) into the current user's Supabase tables and clears the local copy.
  /// Returns the number of imported deals (or null if nothing was imported).
  Future<int?> migrateLegacyLocalData() async {
    final legacy = await _legacyStorage.loadData();
    if (legacy == null) return null;
    final dealsList = legacy['deals'] as List<dynamic>? ?? [];
    final buyersList = legacy['buyers'] as List<dynamic>? ?? [];
    final shopsList = legacy['shops'] as List<dynamic>? ?? [];
    final itemsList = legacy['inventoryItems'] as List<dynamic>? ?? [];
    final movementsList = legacy['movements'] as List<dynamic>? ?? [];
    final activitiesList = legacy['activities'] as List<dynamic>? ?? [];
    if (dealsList.isEmpty &&
        buyersList.isEmpty &&
        shopsList.isEmpty &&
        itemsList.isEmpty &&
        movementsList.isEmpty &&
        activitiesList.isEmpty) {
      return null;
    }

    final snapshot = await _repository.bulkImport(
      buyers: buyersList
          .map((e) => Buyer.fromJson(e as Map<String, dynamic>))
          .toList(),
      shops: shopsList
          .map((e) => Shop.fromJson(e as Map<String, dynamic>))
          .toList(),
      deals: dealsList
          .map((e) => Deal.fromJson(e as Map<String, dynamic>))
          .toList(),
      items: itemsList
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      movements: movementsList
          .map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>))
          .toList(),
      activities: activitiesList
          .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _hydrateFrom(snapshot);
    notifyListeners();
    await _legacyStorage.clear();
    return snapshot.deals.length;
  }
}
