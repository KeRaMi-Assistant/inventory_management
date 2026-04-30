import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/activity_entry.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/inventory_item.dart';
import '../models/shop.dart';
import '../models/ticket_summary.dart';
import '../services/storage_service.dart';

class InventoryProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  List<Deal> _deals = [];
  List<Buyer> _buyers = [];
  List<Shop> _shops = [];
  List<InventoryItem> _inventoryItems = [];
  List<InventoryMovement> _movements = [];
  List<ActivityEntry> _activities = [];

  List<Deal> get deals => List.unmodifiable(
        List.from(_deals)..sort((a, b) => b.id.compareTo(a.id)),
      );
  List<Buyer> get buyers => List.unmodifiable(
        List.from(_buyers)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
  List<Shop> get shops => List.unmodifiable(_shops);
  List<InventoryItem> get inventoryItems => List.unmodifiable(
        List.from(_inventoryItems)..sort((a, b) => a.name.compareTo(b.name)),
      );
  List<InventoryMovement> get movements => List.unmodifiable(
        List.from(_movements)..sort((a, b) => b.date.compareTo(a.date)),
      );
  List<ActivityEntry> get activities => List.unmodifiable(
        List.from(_activities)..sort((a, b) => b.date.compareTo(a.date)),
      );

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

  int get openOrdersCount =>
      _deals.where((d) => d.status == 'Bestellt').length;

  double get totalProfit => _deals.fold(
        0,
        (sum, d) => sum + (d.totalProfit ?? 0),
      );

  double get openAmount => _deals
      .where((d) => d.status != 'Done')
      .fold(0, (sum, d) => sum + (d.zuBekommen ?? 0));

  int get openDeliveriesCount =>
      _deals.where((d) => d.status == 'Unterwegs').length;

  int get arrivedTodayCount {
    final now = DateTime.now();
    return _deals.where((d) {
      final a = d.arrivalDate;
      return a != null && a.year == now.year && a.month == now.month && a.day == now.day;
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

  int get nextDealId =>
      _deals.isEmpty ? 1 : (_deals.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1);

  /// All non-null ticketNumbers used as Amazon order IDs.
  Set<String> get existingAmazonOrderIds =>
      _deals.where((d) => d.ticketNumber != null && d.ticketNumber!.isNotEmpty).map((d) => d.ticketNumber!).toSet();

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

  Future<void> loadData() async {
    final data = await _storage.loadData();
    if (data != null) {
      _deals = (data['deals'] as List<dynamic>? ?? [])
          .map((e) => Deal.fromJson(e as Map<String, dynamic>))
          .toList();
      _buyers = (data['buyers'] as List<dynamic>? ?? [])
          .map((e) => Buyer.fromJson(e as Map<String, dynamic>))
          .toList();
      _shops = (data['shops'] as List<dynamic>? ?? [])
          .map((e) => Shop.fromJson(e as Map<String, dynamic>))
          .toList();
      _inventoryItems = (data['inventoryItems'] as List<dynamic>? ?? [])
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _movements = (data['movements'] as List<dynamic>? ?? [])
          .map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>))
          .toList();
      _activities = (data['activities'] as List<dynamic>? ?? [])
          .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _initDefaults();
    }
    notifyListeners();
  }

  void _initDefaults() {
    _initDemoData();
  }

  void _initDemoData() {
    const serverId = '1028341004480286883';
    const channelId = '1463456615847170224';
    const ticketUrl =
        'https://discord.com/channels/$serverId/$channelId';

    _shops = [
      const Shop(
        id: 'shop-amazon-de',
        name: 'Amazon DE',
        region: 'DE',
        url: 'https://www.amazon.de',
      ),
      const Shop(
        id: 'shop-amazon-es',
        name: 'Amazon ES',
        region: 'ES',
        url: 'https://www.amazon.es',
      ),
    ];

    _buyers = [
      const Buyer(
        id: 'buyer-max',
        name: 'Max Mustermann',
        rowFillColor: Color(0xFFEFF6FF),
        buyerCellColor: Color(0xFF2563EB),
        fontColor: Color(0xFFFFFFFF),
        sortOrder: 0,
        discordServerIds: [serverId],
      ),
      const Buyer(
        id: 'buyer-anna',
        name: 'Anna Schmidt',
        rowFillColor: Color(0xFFF5F3FF),
        buyerCellColor: Color(0xFF7C3AED),
        fontColor: Color(0xFFFFFFFF),
        sortOrder: 1,
        discordServerIds: [serverId],
      ),
      const Buyer(
        id: 'buyer-tom',
        name: 'Tom Weber',
        rowFillColor: Color(0xFFF0FDF4),
        buyerCellColor: Color(0xFF16A34A),
        fontColor: Color(0xFFFFFFFF),
        sortOrder: 2,
        discordServerIds: [serverId],
      ),
    ];

    final now = DateTime.now();
    _deals = [
      Deal(
        id: 1,
        product: 'PlayStation 5 Disc Edition',
        quantity: 2,
        shippingType: 'Dropship',
        shop: 'Amazon DE',
        orderDate: now.subtract(const Duration(days: 20)),
        ekNetto: 410.00,
        ekBrutto: 487.90,
        vk: 550.00,
        buyer: 'Max Mustermann',
        ticketNumber: 'TICKET-001',
        ticketUrl: ticketUrl,
        arrivalDate: now.subtract(const Duration(days: 10)),
        status: 'Done',
        beleg: 'Ja',
      ),
      Deal(
        id: 2,
        product: 'Xbox Series X',
        quantity: 1,
        shippingType: 'Reship',
        shop: 'Amazon DE',
        orderDate: now.subtract(const Duration(days: 14)),
        ekNetto: 420.00,
        ekBrutto: 499.80,
        vk: 540.00,
        buyer: 'Anna Schmidt',
        ticketNumber: 'TICKET-002',
        ticketUrl: ticketUrl,
        arrivalDate: now.subtract(const Duration(days: 5)),
        status: 'Angekommen',
        beleg: 'Nein',
      ),
      Deal(
        id: 3,
        product: 'Nintendo Switch OLED',
        quantity: 3,
        shippingType: 'Dropship',
        shop: 'Amazon ES',
        orderDate: now.subtract(const Duration(days: 10)),
        ekNetto: 280.00,
        ekBrutto: 333.20,
        vk: 380.00,
        buyer: 'Tom Weber',
        ticketNumber: 'TICKET-003',
        ticketUrl: ticketUrl,
        status: 'Unterwegs',
        beleg: 'Ja',
      ),
      Deal(
        id: 4,
        product: 'Apple iPhone 15 Pro 256GB',
        quantity: 1,
        shippingType: 'Dropship',
        shop: 'Amazon DE',
        orderDate: now.subtract(const Duration(days: 7)),
        ekNetto: 900.00,
        ekBrutto: 1071.00,
        vk: 1150.00,
        buyer: 'Max Mustermann',
        ticketNumber: 'TICKET-004',
        ticketUrl: ticketUrl,
        status: 'Bestellt',
        beleg: 'Nein',
      ),
      Deal(
        id: 5,
        product: 'Sony WH-1000XM5 Kopfhörer',
        quantity: 2,
        shippingType: 'Reship',
        shop: 'Amazon ES',
        orderDate: now.subtract(const Duration(days: 6)),
        ekNetto: 270.00,
        ekBrutto: 321.30,
        vk: 370.00,
        buyer: 'Anna Schmidt',
        ticketNumber: 'TICKET-005',
        ticketUrl: ticketUrl,
        status: 'Rechnung gestellt',
        beleg: 'Ja',
      ),
      Deal(
        id: 6,
        product: 'Samsung Galaxy S24 Ultra',
        quantity: 1,
        shippingType: 'Dropship',
        shop: 'Amazon DE',
        orderDate: now.subtract(const Duration(days: 4)),
        ekNetto: 1100.00,
        ekBrutto: 1309.00,
        vk: 1400.00,
        buyer: 'Tom Weber',
        ticketNumber: 'TICKET-006',
        ticketUrl: ticketUrl,
        status: 'Bestellt',
        beleg: 'Nein',
      ),
      Deal(
        id: 7,
        product: 'Apple MacBook Pro M3 14"',
        quantity: 1,
        shippingType: 'Dropship',
        shop: 'Amazon ES',
        orderDate: now.subtract(const Duration(days: 2)),
        ekNetto: 1800.00,
        ekBrutto: 2142.00,
        vk: 2300.00,
        buyer: 'Max Mustermann',
        ticketNumber: 'TICKET-007',
        ticketUrl: ticketUrl,
        status: 'Unterwegs',
        beleg: 'Ja',
        note: 'Spacegrau, DE-Tastatur',
      ),
      Deal(
        id: 8,
        product: 'Dyson V15 Detect',
        quantity: 2,
        shippingType: 'Reship',
        shop: 'Amazon DE',
        orderDate: now.subtract(const Duration(days: 1)),
        ekNetto: 500.00,
        ekBrutto: 595.00,
        vk: 650.00,
        buyer: 'Anna Schmidt',
        ticketNumber: 'TICKET-008',
        ticketUrl: ticketUrl,
        status: 'Bestellt',
        beleg: 'Nein',
      ),
    ];

    _inventoryItems = [];
    _movements = [];
    _activities = [];
  }

  Future<void> loadDemoData() async {
    _initDemoData();
    notifyListeners();
    await _save();
  }

  Map<String, dynamic> exportData() => {
        'deals': _deals.map((d) => d.toJson()).toList(),
        'buyers': _buyers.map((b) => b.toJson()).toList(),
        'shops': _shops.map((s) => s.toJson()).toList(),
        'inventoryItems': _inventoryItems.map((i) => i.toJson()).toList(),
        'movements': _movements.map((m) => m.toJson()).toList(),
        'activities': _activities.map((a) => a.toJson()).toList(),
      };

  Future<void> _save() async {
    await _storage.saveData(exportData());
  }

  Future<void> restoreData(Map<String, dynamic> data) async {
    _deals = (data['deals'] as List<dynamic>? ?? [])
        .map((e) => Deal.fromJson(e as Map<String, dynamic>))
        .toList();
    _buyers = (data['buyers'] as List<dynamic>? ?? [])
        .map((e) => Buyer.fromJson(e as Map<String, dynamic>))
        .toList();
    _shops = (data['shops'] as List<dynamic>? ?? [])
        .map((e) => Shop.fromJson(e as Map<String, dynamic>))
        .toList();
    _inventoryItems = (data['inventoryItems'] as List<dynamic>? ?? [])
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    _movements = (data['movements'] as List<dynamic>? ?? [])
        .map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>))
        .toList();
    _activities = (data['activities'] as List<dynamic>? ?? [])
        .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
    await _save();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(exportData());

  void _log(String message, String type) {
    _activities.add(ActivityEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      message: message,
      type: type,
    ));
    if (_activities.length > 50) {
      _activities = (List<ActivityEntry>.from(_activities)
            ..sort((a, b) => b.date.compareTo(a.date)))
          .take(50)
          .toList();
    }
  }

  // DEALS
  Future<void> addDeal(Deal deal) async {
    final saved = deal.copyWith(id: nextDealId);
    _deals.add(saved);
    _log('Deal hinzugefügt: ${saved.product}', 'deal');
    notifyListeners();
    await _save();
  }

  Future<void> updateDeal(Deal deal) async {
    final idx = _deals.indexWhere((d) => d.id == deal.id);
    if (idx != -1) {
      final oldStatus = _deals[idx].status;
      _deals[idx] = deal;
      if (oldStatus != deal.status) {
        _log('Status geändert: ${deal.product} → ${deal.status}', 'status');
      } else {
        _log('Deal aktualisiert: ${deal.product}', 'deal');
      }
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteDeal(int id) async {
    final deal = _deals.where((d) => d.id == id).firstOrNull;
    _deals.removeWhere((d) => d.id == id);
    if (deal != null) _log('Deal gelöscht: ${deal.product}', 'deal');
    notifyListeners();
    await _save();
  }

  Future<void> updateDealsStatus(Iterable<int> ids, String status) async {
    final idSet = ids.toSet();
    _deals = _deals
        .map((d) => idSet.contains(d.id) ? d.copyWith(status: status) : d)
        .toList();
    _log('${idSet.length} Deals auf "$status" gesetzt', 'bulk');
    notifyListeners();
    await _save();
  }

  Future<void> assignDealsBuyer(Iterable<int> ids, String? buyer) async {
    final idSet = ids.toSet();
    _deals = _deals
        .map((d) => idSet.contains(d.id) ? d.copyWith(buyer: buyer) : d)
        .toList();
    _log('${idSet.length} Deals Käufer zugewiesen', 'bulk');
    notifyListeners();
    await _save();
  }

  Future<void> deleteDeals(Iterable<int> ids) async {
    final idSet = ids.toSet();
    _deals.removeWhere((d) => idSet.contains(d.id));
    _log('${idSet.length} Deals gelöscht', 'bulk');
    notifyListeners();
    await _save();
  }

  /// Merges imported deals (new IDs assigned sequentially).
  Future<void> importDeals(List<Deal> imported) async {
    int id = nextDealId;
    for (final d in imported) {
      _deals.add(d.copyWith(id: id++));
    }
    _log('${imported.length} Deals importiert', 'import');
    notifyListeners();
    await _save();
  }

  // BUYERS
  Future<void> addBuyer(Buyer buyer) async {
    _buyers.add(buyer.copyWith(id: _uuid.v4()));
    notifyListeners();
    await _save();
  }

  Future<void> updateBuyer(Buyer buyer) async {
    final idx = _buyers.indexWhere((b) => b.id == buyer.id);
    if (idx != -1) {
      _buyers[idx] = buyer;
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteBuyer(String id) async {
    _buyers.removeWhere((b) => b.id == id);
    notifyListeners();
    await _save();
  }

  // SHOPS
  Future<void> addShop(Shop shop) async {
    _shops.add(shop.copyWith(id: _uuid.v4()));
    notifyListeners();
    await _save();
  }

  Future<void> updateShop(Shop shop) async {
    final idx = _shops.indexWhere((s) => s.id == shop.id);
    if (idx != -1) {
      _shops[idx] = shop;
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteShop(String id) async {
    _shops.removeWhere((s) => s.id == id);
    notifyListeners();
    await _save();
  }

  // INVENTORY
  Future<void> addInventoryItem(InventoryItem item) async {
    final saved = item.copyWith(id: item.id.isEmpty ? _uuid.v4() : item.id);
    _inventoryItems.add(saved);
    _movements.add(InventoryMovement(
      id: _uuid.v4(),
      itemId: saved.id,
      date: DateTime.now(),
      quantityChange: saved.quantity,
      reason: 'Einbuchung',
      dealId: saved.dealId,
      ticketNumber: saved.ticketNumber,
    ));
    _log('Artikel eingebucht: ${saved.name}', 'stock');
    notifyListeners();
    await _save();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final idx = _inventoryItems.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;
    final old = _inventoryItems[idx];
    _inventoryItems[idx] = item;
    final delta = item.quantity - old.quantity;
    if (delta != 0) {
      _movements.add(InventoryMovement(
        id: _uuid.v4(),
        itemId: item.id,
        date: DateTime.now(),
        quantityChange: delta,
        reason: delta > 0 ? 'Einbuchung' : 'Ausbuchung',
        dealId: item.dealId,
        ticketNumber: item.ticketNumber,
      ));
    }
    _log('Lagerartikel aktualisiert: ${item.name}', 'stock');
    notifyListeners();
    await _save();
  }

  Future<void> deleteInventoryItem(String id) async {
    final item = _inventoryItems.where((i) => i.id == id).firstOrNull;
    _inventoryItems.removeWhere((i) => i.id == id);
    _movements.removeWhere((m) => m.itemId == id);
    if (item != null) _log('Lagerartikel gelöscht: ${item.name}', 'stock');
    notifyListeners();
    await _save();
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
    final item = _inventoryItems[idx];
    _inventoryItems[idx] = item.copyWith(
      quantity: (item.quantity + delta).clamp(0, 1 << 31).toInt(),
      dealId: dealId ?? item.dealId,
      ticketNumber: ticketNumber ?? item.ticketNumber,
    );
    _movements.add(InventoryMovement(
      id: _uuid.v4(),
      itemId: id,
      date: DateTime.now(),
      quantityChange: delta,
      reason: reason,
      dealId: dealId,
      ticketNumber: ticketNumber,
    ));
    _log('Lagerbewegung: ${item.name} ${delta > 0 ? '+' : ''}$delta', 'stock');
    notifyListeners();
    await _save();
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
    _inventoryItems.add(item);
    final idx = _deals.indexWhere((d) => d.id == deal.id);
    if (idx != -1) {
      _deals[idx] = _deals[idx].copyWith(
        inventoryItemIds: [..._deals[idx].inventoryItemIds, item.id],
      );
    }
    _movements.add(InventoryMovement(
      id: _uuid.v4(),
      itemId: item.id,
      date: DateTime.now(),
      quantityChange: item.quantity,
      reason: 'Einbuchung via Deal',
      dealId: deal.id,
      ticketNumber: deal.ticketNumber,
    ));
    _log('Artikel via Deal eingebucht: ${deal.product}', 'stock');
    notifyListeners();
    await _save();
  }
}
