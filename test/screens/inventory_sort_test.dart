import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/inventory_sort_mode.dart';

InventoryItem _i(
  String name,
  int qty, {
  int minStock = 0,
  double? costPrice,
}) {
  return InventoryItem(
    id: name,
    name: name,
    quantity: qty,
    minStock: minStock,
    costPrice: costPrice,
  );
}

void main() {
  group('sortInventoryItems', () {
    final items = [
      _i('Bravo', 10, minStock: 5, costPrice: 2.0), // value=20
      _i('alpha', 2, minStock: 5, costPrice: 10.0), // critical, value=20
      _i('Charlie', 50, minStock: 0, costPrice: 1.0), // value=50
      _i('delta', 1, minStock: 10, costPrice: null), // critical, value=0
    ];

    test('criticalFirst sortiert kritische zuerst, dann alphabetisch', () {
      final sorted = sortInventoryItems(items, InventorySortMode.criticalFirst);
      // Critical (alpha, delta) zuerst nach Name (a < d).
      expect(sorted.map((e) => e.name).toList(),
          ['alpha', 'delta', 'Bravo', 'Charlie']);
    });

    test('nameAsc sortiert case-insensitive', () {
      final sorted = sortInventoryItems(items, InventorySortMode.nameAsc);
      expect(sorted.map((e) => e.name).toList(),
          ['alpha', 'Bravo', 'Charlie', 'delta']);
    });

    test('stockDesc sortiert höchster zuerst', () {
      final sorted = sortInventoryItems(items, InventorySortMode.stockDesc);
      expect(sorted.map((e) => e.quantity).toList(), [50, 10, 2, 1]);
    });

    test('stockAsc sortiert niedrigster zuerst', () {
      final sorted = sortInventoryItems(items, InventorySortMode.stockAsc);
      expect(sorted.map((e) => e.quantity).toList(), [1, 2, 10, 50]);
    });

    test('valueDesc sortiert nach stockValue, NULL als 0', () {
      final sorted = sortInventoryItems(items, InventorySortMode.valueDesc);
      // Charlie 50, Bravo 20 oder alpha 20 (tie), delta 0.
      expect(sorted.first.name, 'Charlie');
      expect(sorted.last.name, 'delta');
    });

    test('lässt Original-Liste unverändert', () {
      final original = List<InventoryItem>.from(items);
      sortInventoryItems(items, InventorySortMode.stockDesc);
      expect(items, original);
    });
  });
}
