import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/activity_entry.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/models/product_stock.dart';
import 'package:inventory_management/models/warehouse.dart';
import 'package:inventory_management/providers/catalog_provider.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/providers/purchasing_provider.dart';
import 'package:inventory_management/providers/stock_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Fake-Repository für den `checkInDeal`-Cross-Domain-Write-Contract (Split #3).
///
/// `checkInDeal` bleibt Orchestrator auf [InventoryProvider] (Deals-Domäne),
/// schreibt aber Item + Movement über die public Write-Back-Hooks
/// (`upsertInventoryItemFromImport` / `insertMovementFromCheckIn`) in den
/// injizierten [StockProvider] — Plan §3 Option A (kein Stock→Inventory-Edge,
/// damit der Provider-Graph azyklisch bleibt). Der Deal↔Item-Link
/// (`inventoryItemIds`) bleibt lokal in der Deals-Domäne.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  List<Deal> seedDeals = [];
  List<Product> seedProducts = [];
  List<Warehouse> seedWarehouses = [];

  final List<InventoryItem> insertedItems = [];
  final List<InventoryMovement> insertedMovements = [];

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: List.of(seedDeals),
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: const [],
        movements: const [],
        activities: const [],
        products: List.of(seedProducts),
        warehouses: List.of(seedWarehouses),
      );

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async {
    insertedItems.add(item);
    return item;
  }

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async {
    insertedMovements.add(movement);
    return movement;
  }

  // ── loadData-Stubs für StockProvider._doLoadData ──
  @override
  Future<List<ProductStock>> loadProductStock(String workspaceId) async =>
      const [];

  @override
  Future<ActivityEntry> insertActivity(ActivityEntry entry) async => entry;
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

Deal _makeDeal({required int id, String product = 'Widget'}) => Deal(
      id: id,
      product: product,
      quantity: 3,
      isDropship: false,
      shop: 'Testshop',
      orderDate: DateTime.utc(2026, 1, 1),
      ekBrutto: 12.5,
    );

Product _makeProduct({required String id, required String name}) {
  final now = DateTime.utc(2026, 5, 22, 10);
  return Product(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Warehouse _makeWarehouse() {
  final now = DateTime.utc(2026, 5, 22, 10);
  return Warehouse(
    id: 'wh-default',
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: 'Hauptlager',
    isDefault: true,
    createdAt: now,
    updatedAt: now,
  );
}

({
  InventoryProvider inventory,
  StockProvider stock,
  CatalogProvider catalog,
}) _wire(_FakeRepository repo) {
  final catalog = CatalogProvider(repository: repo);
  final purchasing = PurchasingProvider(repository: repo);
  final stock = StockProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: purchasing,
  );
  final inventory = InventoryProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: purchasing,
    stockProvider: stock,
  );
  return (inventory: inventory, stock: stock, catalog: catalog);
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  test(
      'checkInDeal schreibt Item + Movement in den injizierten StockProvider '
      'und verlinkt den Deal (Cross-Domain-Hooks)', () async {
    final repo = _FakeRepository()
      ..seedDeals = [_makeDeal(id: 1, product: 'Widget')]
      // Passendes Katalog-Produkt → _matchOrCreateProduct trifft (kein insertProduct).
      ..seedProducts = [_makeProduct(id: 'prod-1', name: 'Widget')]
      // Warehouse geseedet → _bootstrapDefaultWarehouse wird übersprungen.
      ..seedWarehouses = [_makeWarehouse()];

    final w = _wire(repo);
    await w.catalog.loadData();
    await w.stock.loadData();
    await w.inventory.loadData();

    // Vorbedingung: Stock-Caches leer, Deal vorhanden.
    expect(w.stock.inventoryItems, isEmpty);
    expect(w.stock.movements, isEmpty);
    final deal = w.inventory.deals.firstWhere((d) => d.id == 1);
    expect(deal.inventoryItemIds, isEmpty);

    await w.inventory.checkInDeal(deal);

    // Item landete via upsertInventoryItemFromImport im StockProvider …
    expect(w.stock.inventoryItems, hasLength(1));
    expect(w.stock.inventoryItems.first.name, equals('Widget'));
    expect(w.stock.inventoryItems.first.quantity, equals(3));
    // … Movement via insertMovementFromCheckIn …
    expect(w.stock.movements, hasLength(1));
    expect(w.stock.movements.first.quantityChange, equals(3));
    expect(
      w.stock.movements.first.movementType,
      equals(InventoryMovementType.goodsIn),
    );
    // … und der Deal-↔-Item-Link bleibt lokal in der Deals-Domäne.
    final linked = w.inventory.deals.firstWhere((d) => d.id == 1);
    expect(linked.inventoryItemIds, hasLength(1));
    expect(
      linked.inventoryItemIds.single,
      equals(w.stock.inventoryItems.first.id),
    );
    // Produkt-Matching gegen den Katalog-Seed (kein neues Produkt angelegt).
    expect(w.stock.inventoryItems.first.productId, equals('prod-1'));
  });
}
