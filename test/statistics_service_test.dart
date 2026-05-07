import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/inventory_batch.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/supplier.dart';
import 'package:inventory_management/providers/statistics_filter_provider.dart';
import 'package:inventory_management/services/statistics_service.dart';

StatisticsFilterProvider _customFilter(DateTime from, DateTime to) {
  final f = StatisticsFilterProvider();
  f.setCustomRange(from, to);
  return f;
}

Deal _deal({
  int id = 1,
  String product = 'Widget',
  int quantity = 1,
  double? ekBrutto = 80.0,
  double? vk = 100.0,
  String status = 'Done',
  String shop = 'Amazon-DE',
  String? buyer,
  DateTime? orderDate,
  String currency = 'EUR',
  List<String> inventoryItemIds = const [],
  double? ekNetto,
}) {
  return Deal(
    id: id,
    product: product,
    quantity: quantity,
    isDropship: false,
    shop: shop,
    orderDate: orderDate ?? DateTime(2024, 3, 15),
    ekBrutto: ekBrutto,
    ekNetto: ekNetto,
    vk: vk,
    status: status,
    buyer: buyer,
    currency: currency,
    inventoryItemIds: inventoryItemIds,
  );
}
void main() {
  final from = DateTime(2024, 1, 1);
  final to = DateTime(2024, 12, 31, 23, 59, 59);

  StatisticsService make({
    List<Deal> deals = const [],
    List<InventoryItem> items = const [],
    List<Supplier> suppliers = const [],
    List<InventoryBatch> batches = const [],
    StatisticsFilterProvider? filter,
  }) {
    return StatisticsService(
      allDeals: deals,
      allItems: items,
      suppliers: suppliers,
      batches: batches,
      filter: filter ?? _customFilter(from, to),
    );
  }

  // deltaPct
  group('StatisticsService.deltaPct', () {
    test('positive delta: current=120, previous=100 yields +20%', () {
      expect(StatisticsService.deltaPct(120, 100), closeTo(20.0, 0.001));
    });

    test('both zero yields 0', () {
      expect(StatisticsService.deltaPct(0, 0), 0.0);
    });

    test('previous=0 current>0 yields null', () {
      expect(StatisticsService.deltaPct(50, 0), isNull);
    });

    test('negative delta: current=80, previous=100 yields -20%', () {
      expect(StatisticsService.deltaPct(80, 100), closeTo(-20.0, 0.001));
    });
  });

  // KPIs empty
  group('KPIs with empty deals', () {
    test('all KPIs are zero when no deals', () {
      final svc = make();
      expect(svc.revenue, 0.0);
      expect(svc.profit, 0.0);
      expect(svc.ekTotal, 0.0);
      expect(svc.margin, 0.0);
      expect(svc.roi, 0.0);
      expect(svc.openReceivables, 0.0);
      expect(svc.dealCount, 0);
    });
  });

  // Single deal
  group('Single deal quantity=2 ekBrutto=80 vk=100', () {
    late StatisticsService svc;

    setUp(() {
      svc = make(deals: [
        _deal(quantity: 2, ekBrutto: 80.0, vk: 100.0),
      ]);
    });

    test('revenue = vk * quantity = 200', () {
      expect(svc.revenue, closeTo(200.0, 0.001));
    });

    test('profit = (vk - ekBrutto) * quantity = 40', () {
      expect(svc.profit, closeTo(40.0, 0.001));
    });

    test('margin = profit/revenue*100 = 20%', () {
      expect(svc.margin, closeTo(20.0, 0.001));
    });

    test('roi = profit/ekTotal*100 = 25%', () {
      expect(svc.roi, closeTo(25.0, 0.001));
    });
  });

  // Date range
  group('Date range filtering', () {
    test('deals outside date range are excluded', () {
      final inside = _deal(id: 1, orderDate: DateTime(2024, 6, 1));
      final outside = _deal(id: 2, orderDate: DateTime(2023, 6, 1));
      final svc = make(deals: [inside, outside]);
      expect(svc.dealCount, 1);
      expect(svc.revenue, closeTo(100.0, 0.001));
    });

    test('deals exactly on range boundaries are included', () {
      final onFrom = _deal(id: 1, orderDate: DateTime(2024, 1, 1));
      final onTo = _deal(id: 2, orderDate: DateTime(2024, 12, 31));
      final svc = make(deals: [onFrom, onTo]);
      expect(svc.dealCount, 2);
    });
  });

  // openReceivables
  group('openReceivables', () {
    test('only includes non-Done deals', () {
      final done = _deal(id: 1, status: 'Done', vk: 100.0, quantity: 1);
      final open = _deal(id: 2, status: 'Bestellt', vk: 50.0, quantity: 1);
      final svc = make(deals: [done, open]);
      expect(svc.openReceivables, closeTo(50.0, 0.001));
    });

    test('zero when all deals are Done', () {
      final svc = make(deals: [_deal(status: 'Done', vk: 100.0)]);
      expect(svc.openReceivables, 0.0);
    });
  });

  // Buyer filter
  group('Filter by buyer', () {
    test('only matching deals are counted', () {
      final alice = _deal(id: 1, buyer: 'Alice', vk: 100.0);
      final bob = _deal(id: 2, buyer: 'Bob', vk: 200.0);
      final filter = _customFilter(from, to);
      filter.setBuyer('Alice');
      final svc = make(deals: [alice, bob], filter: filter);
      expect(svc.dealCount, 1);
      expect(svc.revenue, closeTo(100.0, 0.001));
    });
  });

  // Shop filter
  group('Filter by shop', () {
    test('only matching deals are counted', () {
      final amazon = _deal(id: 1, shop: 'Amazon-DE', vk: 100.0);
      final ebay = _deal(id: 2, shop: 'eBay-DE', vk: 300.0);
      final filter = _customFilter(from, to);
      filter.setShop('Amazon-DE');
      final svc = make(deals: [amazon, ebay], filter: filter);
      expect(svc.dealCount, 1);
      expect(svc.revenue, closeTo(100.0, 0.001));
    });
  });

  // TaxReports
  group('TaxReports', () {
    test('two deals in different quarters give 2 reports ordered desc', () {
      final q1 = _deal(id: 1, orderDate: DateTime(2024, 2, 15));
      final q3 = _deal(id: 2, orderDate: DateTime(2024, 8, 10));
      final svc = make(deals: [q1, q3]);
      expect(svc.taxReports.length, 2);
      expect(svc.taxReports.first.quarter, 3);
      expect(svc.taxReports.last.quarter, 1);
    });

    test('tax calculation ekBrutto=119 ekNetto=100 gives tax=19', () {
      final d = _deal(
        id: 1,
        quantity: 1,
        ekBrutto: 119.0,
        ekNetto: 100.0,
        orderDate: DateTime(2024, 3, 1),
      );
      final svc = make(deals: [d]);
      expect(svc.taxReports.length, 1);
      expect(svc.taxReports.first.tax, closeTo(19.0, 0.001));
    });

    test('empty deals give no tax reports', () {
      final svc = make();
      expect(svc.taxReports, isEmpty);
    });
  });

  // inventoryHealth
  group('inventoryHealth', () {
    test('lowStock counts items with quantity below lowStockThreshold=5', () {
      const lowItem = InventoryItem(
        id: 'item-1',
        name: 'Low Item',
        quantity: 2,
      );
      const okItem = InventoryItem(
        id: 'item-2',
        name: 'OK Item',
        quantity: 10,
      );
      final svc = make(items: [lowItem, okItem]);
      expect(svc.inventoryHealth.lowStock, 1);
    });

    test('stockValueEk with costPrice=10 quantity=3 gives 30.0', () {
      const item = InventoryItem(
        id: 'item-1',
        name: 'Test Item',
        quantity: 3,
        costPrice: 10.0,
      );
      final svc = make(items: [item]);
      expect(svc.inventoryHealth.stockValueEk, closeTo(30.0, 0.001));
    });

    test('empty items give zero health values', () {
      final svc = make();
      expect(svc.inventoryHealth.stockValueEk, 0.0);
      expect(svc.inventoryHealth.lowStock, 0);
      expect(svc.inventoryHealth.deadStock, 0);
    });
  });
}
