import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/inventory_batch.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/supplier.dart';
import 'package:inventory_management/providers/statistics_filter_provider.dart';
import 'package:inventory_management/services/statistics_service.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────────

StatisticsFilterProvider _anyFilter() {
  final f = StatisticsFilterProvider();
  f.setCustomRange(DateTime(2024, 1, 1), DateTime(2024, 12, 31));
  return f;
}

InventoryItem _item({
  String id = 'item-1',
  String name = 'Widget',
  String? sku,
  int quantity = 10,
  double? costPrice = 5.0,
}) {
  return InventoryItem(
    id: id,
    name: name,
    sku: sku,
    quantity: quantity,
    costPrice: costPrice,
  );
}

InventoryMovement _movement({
  required String id,
  required String itemId,
  required int quantityChange,
  InventoryMovementType movementType = InventoryMovementType.correction,
  DateTime? date,
}) {
  return InventoryMovement(
    id: id,
    itemId: itemId,
    date: date ?? DateTime(2024, 6, 1),
    quantityChange: quantityChange,
    reason: 'Test',
    movementType: movementType,
  );
}

StatisticsService _make({
  List<InventoryItem> items = const [],
  List<InventoryMovement> movements = const [],
}) {
  return StatisticsService(
    allDeals: const <Deal>[],
    allItems: items,
    suppliers: const <Supplier>[],
    batches: const <InventoryBatch>[],
    filter: _anyFilter(),
    allMovements: movements,
  );
}

// ── Bestandsbewertung (reportStockValuation) ──────────────────────────────────

void main() {
  group('StockValuationReport', () {
    test('leere Artikelliste: totalValue = 0, totalUnits = 0', () {
      final svc = _make();
      final r = svc.reportStockValuation;
      expect(r.totalValue, 0.0);
      expect(r.totalUnits, 0);
      expect(r.items, isEmpty);
    });

    test('ein Artikel: quantity × costPrice', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'Artikel A', quantity: 4, costPrice: 12.50),
      ]);
      final r = svc.reportStockValuation;
      expect(r.totalValue, closeTo(50.0, 0.001)); // 4 × 12.50
      expect(r.totalUnits, 4);
      expect(r.items.length, 1);
      expect(r.items.first.name, 'Artikel A');
      expect(r.items.first.costPrice, 12.50);
    });

    test('mehrere Artikel: Summe aller Werte korrekt', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 3, costPrice: 10.0), // 30
        _item(id: 'b', name: 'B', quantity: 5, costPrice: 20.0), // 100
        _item(id: 'c', name: 'C', quantity: 2, costPrice: 0.0),  // 0
      ]);
      final r = svc.reportStockValuation;
      expect(r.totalValue, closeTo(130.0, 0.001));
      expect(r.totalUnits, 10);
    });

    test('Artikel ohne costPrice (null) wird mit 0 bewertet', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 5, costPrice: null),
      ]);
      final r = svc.reportStockValuation;
      expect(r.totalValue, 0.0);
      expect(r.items.first.costPrice, 0.0);
    });

    test('Items sind absteigend nach Wert sortiert', () {
      final svc = _make(items: [
        _item(id: 'low', name: 'Low', quantity: 1, costPrice: 5.0),   // 5
        _item(id: 'high', name: 'High', quantity: 2, costPrice: 50.0), // 100
        _item(id: 'mid', name: 'Mid', quantity: 3, costPrice: 10.0),  // 30
      ]);
      final r = svc.reportStockValuation;
      expect(r.items.map((i) => i.name).toList(), ['High', 'Mid', 'Low']);
    });

    test('exakte Berechnung: quantity 7 × costPrice 3.99', () {
      final svc = _make(items: [
        _item(id: 'x', name: 'X', quantity: 7, costPrice: 3.99),
      ]);
      final r = svc.reportStockValuation;
      expect(r.totalValue, closeTo(27.93, 0.001));
    });
  });

  // ── Lagerumschlag (reportInventoryTurnover) ───────────────────────────────

  group('InventoryTurnoverReport', () {
    test('keine Artikel und keine Movements: Umschlag 0.0', () {
      final svc = _make();
      final r = svc.reportInventoryTurnover;
      expect(r.turnoverRate, 0.0);
      expect(r.totalOutflowUnits, 0);
      expect(r.movementCount, 0);
    });

    test('nur goodsIn-Movements: kein Abgang, Umschlag 0', () {
      final svc = _make(
        items: [_item(id: 'a', quantity: 10)],
        movements: [
          _movement(id: 'm1', itemId: 'a', quantityChange: 5,
              movementType: InventoryMovementType.goodsIn),
        ],
      );
      final r = svc.reportInventoryTurnover;
      expect(r.turnoverRate, 0.0);
      expect(r.totalOutflowUnits, 0);
    });

    test('goodsOut-Movements werden summiert', () {
      final svc = _make(
        items: [_item(id: 'a', quantity: 10)],
        movements: [
          _movement(id: 'm1', itemId: 'a', quantityChange: -3,
              movementType: InventoryMovementType.goodsOut),
          _movement(id: 'm2', itemId: 'a', quantityChange: -7,
              movementType: InventoryMovementType.goodsOut),
        ],
      );
      final r = svc.reportInventoryTurnover;
      expect(r.totalOutflowUnits, 10); // |−3| + |−7|
      expect(r.movementCount, 2);
    });

    test('sale-Movements werden ebenfalls als Abgang gezählt', () {
      final svc = _make(
        items: [_item(id: 'a', quantity: 10)],
        movements: [
          _movement(id: 'm1', itemId: 'a', quantityChange: -4,
              movementType: InventoryMovementType.sale),
        ],
      );
      final r = svc.reportInventoryTurnover;
      expect(r.totalOutflowUnits, 4);
      expect(r.movementCount, 1);
    });

    test('Umschlagsrate: Abgang=20, avgBestand=10 → Rate=2.0', () {
      // 2 Artikel mit je 10 Stück → avgStock = 10
      // 20 Abgangsstücke → Umschlag = 20/10 = 2.0
      final svc = _make(
        items: [
          _item(id: 'a', quantity: 10),
          _item(id: 'b', quantity: 10),
        ],
        movements: [
          _movement(id: 'm1', itemId: 'a', quantityChange: -20,
              movementType: InventoryMovementType.goodsOut),
        ],
      );
      final r = svc.reportInventoryTurnover;
      expect(r.avgStockUnits, closeTo(10.0, 0.001));
      expect(r.totalOutflowUnits, 20);
      expect(r.turnoverRate, closeTo(2.0, 0.001));
    });

    test('Umschlagsrate: Abgang=6, avgBestand=4 → Rate=1.5', () {
      final svc = _make(
        items: [
          _item(id: 'a', quantity: 2),
          _item(id: 'b', quantity: 6),
        ],
        movements: [
          _movement(id: 'm1', itemId: 'a', quantityChange: -2,
              movementType: InventoryMovementType.goodsOut),
          _movement(id: 'm2', itemId: 'b', quantityChange: -4,
              movementType: InventoryMovementType.sale),
        ],
      );
      final r = svc.reportInventoryTurnover;
      // avgStock = (2+6)/2 = 4, outflow = 2+4 = 6, rate = 6/4 = 1.5
      expect(r.avgStockUnits, closeTo(4.0, 0.001));
      expect(r.totalOutflowUnits, 6);
      expect(r.turnoverRate, closeTo(1.5, 0.001));
    });

    test('correction/transfer/stocktake-Movements nicht als Abgang gezählt', () {
      final svc = _make(
        items: [_item(id: 'a', quantity: 10)],
        movements: [
          _movement(id: 'm1', itemId: 'a', quantityChange: -5,
              movementType: InventoryMovementType.correction),
          _movement(id: 'm2', itemId: 'a', quantityChange: -3,
              movementType: InventoryMovementType.transfer),
          _movement(id: 'm3', itemId: 'a', quantityChange: -2,
              movementType: InventoryMovementType.stocktake),
        ],
      );
      final r = svc.reportInventoryTurnover;
      expect(r.totalOutflowUnits, 0);
      expect(r.turnoverRate, 0.0);
    });

    test('0 Bestand (avgStock=0): Umschlag bleibt 0 (kein Divisionsfehler)', () {
      final svc = _make(
        items: [_item(id: 'a', quantity: 0)],
        movements: [
          _movement(id: 'm1', itemId: 'a', quantityChange: -5,
              movementType: InventoryMovementType.goodsOut),
        ],
      );
      final r = svc.reportInventoryTurnover;
      expect(r.turnoverRate, 0.0);
    });
  });

  // ── ABC-Analyse (reportAbcAnalysis) ──────────────────────────────────────

  group('AbcAnalysisReport', () {
    test('leere Artikelliste: alle 0, items leer', () {
      final svc = _make();
      final r = svc.reportAbcAnalysis;
      expect(r.totalCount, 0);
      expect(r.totalValue, 0.0);
      expect(r.items, isEmpty);
    });

    test('alle Artikel ohne Wert: alle Klasse C', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 5, costPrice: 0.0),
        _item(id: 'b', name: 'B', quantity: 3, costPrice: null),
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.countA, 0);
      expect(r.countB, 0);
      expect(r.countC, 2);
      expect(r.items.every((i) => i.abcClass == AbcClass.c), isTrue);
    });

    test('ein Artikel mit Wert: fällt in Klasse A (100 % Anteil ≤ 80 %? nein, 100%)', () {
      // Ein einzelner Artikel mit 100% kumul. Anteil → der Anteil ist 100%,
      // welcher > 95% ist → Klasse C.
      // Grund: Der Grenzwert ist kumulierend — wenn nur ein Artikel da ist,
      // beträgt sein kumulierter Anteil 100% > 95% → er ist C.
      // Aber nach der Implementierung: cumulative = value, cumulativePct = 100%,
      // 100 > 80 → nicht A, 100 > 95 → nicht B → C.
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 10, costPrice: 10.0), // 100
      ]);
      final r = svc.reportAbcAnalysis;
      // Einziger Artikel: kumulierter Anteil = 100% → Klasse C
      expect(r.items.first.abcClass, AbcClass.c);
      expect(r.countC, 1);
    });

    test('A=80%-Grenze: Artikel mit höchstem Wert in A, Rest B/C', () {
      // Artikel: X=800, Y=100, Z=100 → Gesamt=1000
      // kumulativ: X=80% → A (≤80%), Y=90% → B (80–95%), Z=100% → C (>95%)
      final svc = _make(items: [
        _item(id: 'x', name: 'X', quantity: 80, costPrice: 10.0),  // 800
        _item(id: 'y', name: 'Y', quantity: 10, costPrice: 10.0),  // 100
        _item(id: 'z', name: 'Z', quantity: 10, costPrice: 10.0),  // 100
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.countA, 1);
      expect(r.countB, 1);
      expect(r.countC, 1);
      final itemX = r.items.firstWhere((i) => i.name == 'X');
      final itemY = r.items.firstWhere((i) => i.name == 'Y');
      final itemZ = r.items.firstWhere((i) => i.name == 'Z');
      expect(itemX.abcClass, AbcClass.a);
      expect(itemY.abcClass, AbcClass.b);
      expect(itemZ.abcClass, AbcClass.c);
    });

    test('Items sind absteigend nach Wert sortiert (Voraussetzung für korrekte Kumulierung)', () {
      final svc = _make(items: [
        _item(id: 'low', name: 'Low', quantity: 1, costPrice: 5.0),
        _item(id: 'high', name: 'High', quantity: 10, costPrice: 50.0),
        _item(id: 'mid', name: 'Mid', quantity: 5, costPrice: 20.0),
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.items.first.name, 'High');
      expect(r.items.last.name, 'Low');
    });

    test('valueA + valueB + valueC = totalValue (Summen korrekt)', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 80, costPrice: 10.0),
        _item(id: 'b', name: 'B', quantity: 10, costPrice: 10.0),
        _item(id: 'c', name: 'C', quantity: 10, costPrice: 10.0),
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.valueA + r.valueB + r.valueC,
          closeTo(r.totalValue, 0.001));
      expect(r.totalValue, closeTo(1000.0, 0.001));
    });

    test('cumulativeSharePct des letzten Items liegt bei ~100%', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 60, costPrice: 10.0),
        _item(id: 'b', name: 'B', quantity: 20, costPrice: 10.0),
        _item(id: 'c', name: 'C', quantity: 20, costPrice: 10.0),
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.items.last.cumulativeSharePct, closeTo(100.0, 0.001));
    });

    test('countA + countB + countC = totalCount', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 80, costPrice: 10.0),
        _item(id: 'b', name: 'B', quantity: 10, costPrice: 10.0),
        _item(id: 'c', name: 'C', quantity: 10, costPrice: 10.0),
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.countA + r.countB + r.countC, r.totalCount);
      expect(r.totalCount, 3);
    });

    test('Grenzfall: 4 Artikel, exakte 80%-Grenze nach erstem', () {
      // Artikel: A=8000, B=1000, C=500, D=500 → Gesamt=10000
      // kumulativ: A=80% → A-Klasse (≤80%)
      //            B=90% → B-Klasse (80–95%)
      //            C=95% → B-Klasse (80–95%)
      //            D=100% → C-Klasse (>95%)
      final svc = _make(items: [
        _item(id: 'a', name: 'A', quantity: 80, costPrice: 100.0), // 8000
        _item(id: 'b', name: 'B', quantity: 10, costPrice: 100.0), // 1000
        _item(id: 'c', name: 'C', quantity: 5, costPrice: 100.0),  // 500
        _item(id: 'd', name: 'D', quantity: 5, costPrice: 100.0),  // 500
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.countA, 1); // nur A
      expect(r.countB, 2); // B und C (je ≤95%)
      expect(r.countC, 1); // D (100% > 95%)
    });

    test('SKU wird korrekt durchgereicht', () {
      final svc = _make(items: [
        _item(id: 'a', name: 'A', sku: 'SKU-001',
            quantity: 10, costPrice: 10.0),
      ]);
      final r = svc.reportAbcAnalysis;
      expect(r.items.first.sku, 'SKU-001');
    });
  });
}
