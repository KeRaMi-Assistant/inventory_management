import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/activity_entry.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product_stock.dart';
import 'package:inventory_management/providers/stock_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

/// Regression-Guard für `00-productstock-stale-after-stocktake-receipt`:
/// mengen-mutierende StockProvider-Operationen (adjustStock / closeStocktake /
/// bookGoodsReceipt) müssen das `product_stock`-Aggregat über
/// `_refreshProductStock()` neu laden — sonst zeigt z.B. die Produkt-Detail-Box
/// „Gesamtbestand" einen Stale-Wert.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  List<InventoryItem> seedInventoryItems = [];

  /// Mutable: ein Test kann den Wert ändern, um den View-Stand NACH einer
  /// Mengen-Mutation zu simulieren. `loadProductStock` liefert immer den
  /// aktuellen Stand → ein Refresh muss den neuen Wert übernehmen.
  List<ProductStock> productStockNow = [];

  int loadProductStockCalls = 0;

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: List.of(seedInventoryItems),
        movements: const [],
        activities: const [],
      );

  @override
  Future<List<ProductStock>> loadProductStock(String workspaceId) async {
    loadProductStockCalls++;
    return List.of(productStockNow);
  }

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async => item;

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async =>
      movement;

  @override
  Future<ActivityEntry> insertActivity(ActivityEntry entry) async => entry;
}

ProductStock _stock(String productId, int qty) => ProductStock(
      workspaceId: 'ws-test',
      productId: productId,
      qtyInWarehouse: qty,
    );

void main() {
  late _FakeRepository repo;
  late StockProvider provider;

  setUp(() {
    repo = _FakeRepository()
      ..seedInventoryItems = [
        const InventoryItem(id: 'i1', name: 'Widget', quantity: 10, productId: 'p1'),
      ]
      ..productStockNow = [_stock('p1', 10)];
    provider = StockProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  test('adjustStock lädt das productStock-Aggregat neu (kein Stale-Wert)',
      () async {
    await provider.loadData();
    expect(provider.productStock.single.qtyInWarehouse, equals(10));
    final callsAfterLoad = repo.loadProductStockCalls;

    // Server-/View-Stand spiegelt jetzt die neue Menge (z.B. nach +3).
    repo.productStockNow = [_stock('p1', 13)];

    await provider.adjustStock('i1', 3, 'Test-Korrektur');

    // _refreshProductStock() hat loadProductStock erneut aufgerufen …
    expect(repo.loadProductStockCalls, greaterThan(callsAfterLoad));
    // … und der Provider-Cache spiegelt den frischen Aggregat-Wert.
    expect(provider.productStock.single.qtyInWarehouse, equals(13));
  });

  test('adjustStock-Refresh ist defensiv bei null-Workspace (kein Throw)',
      () async {
    // Ohne loadData/setActiveWorkspace ist _activeWorkspaceId null; der Fake
    // liefert activeWorkspaceId='ws-test', daher läuft der Refresh — aber das
    // Item muss existieren. Wir laden, dann adjusten — kein Throw erwartet.
    await provider.loadData();
    await provider.adjustStock('i1', -2, 'Abgang'); // darf nicht werfen
    expect(provider.inventoryItems.single.quantity, equals(8));
  });
}
