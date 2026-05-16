import 'inventory_item.dart';

/// Sort modes for the Inventory screen item list.
enum InventorySortMode {
  criticalFirst,
  nameAsc,
  stockDesc,
  stockAsc,
  valueDesc,
}

/// Reine Sortier-Funktion — kein Side-Effect, einfach testbar.
/// Lässt die Original-Liste unverändert, gibt eine neue sortierte Liste.
List<InventoryItem> sortInventoryItems(
  List<InventoryItem> items,
  InventorySortMode mode,
) {
  final sorted = List<InventoryItem>.from(items);
  switch (mode) {
    case InventorySortMode.criticalFirst:
      // Critical (quantity < minStock) zuerst, dann nach Name.
      sorted.sort((a, b) {
        if (a.isCritical != b.isCritical) return a.isCritical ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case InventorySortMode.nameAsc:
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case InventorySortMode.stockDesc:
      sorted.sort((a, b) => b.quantity.compareTo(a.quantity));
    case InventorySortMode.stockAsc:
      sorted.sort((a, b) => a.quantity.compareTo(b.quantity));
    case InventorySortMode.valueDesc:
      sorted.sort((a, b) => b.stockValue.compareTo(a.stockValue));
  }
  return sorted;
}
