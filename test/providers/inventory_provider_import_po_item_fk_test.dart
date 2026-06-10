import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/models/purchase_order.dart';
import 'package:inventory_management/models/purchase_order_item.dart';
import 'package:inventory_management/providers/catalog_provider.dart';
import 'package:inventory_management/providers/deals_provider.dart';
import 'package:inventory_management/providers/purchasing_provider.dart';
import 'package:inventory_management/providers/stock_provider.dart';
import 'package:inventory_management/services/csv_service.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

/// Regression-Test für den importCsvAll-PO-Item-FK-Bug:
/// PO-Items, deren Parent-PO NICHT importiert wurde (Insert fehlgeschlagen oder
/// nicht im CSV), dürfen NICHT mit der synthetischen csv-Parent-id geinsertet
/// werden — das verletzt den FK `purchase_order_items.purchase_order_id` und
/// der Fehler wurde vorher still verschluckt (lautloser Datenverlust). Erwartet:
/// sauberes Überspringen, KEIN Insert-Versuch mit synthetischer id.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository({this.poInsertSucceeds = true}) : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  /// Wenn false, schlägt insertPurchaseOrder fehl → PO landet nicht im Remap.
  final bool poInsertSucceeds;

  int _poSeq = 1000;

  final List<PurchaseOrderItem> insertedPoItems = [];

  @override
  Future<CloudSnapshot> loadAll() async => const CloudSnapshot(
        deals: [],
        buyers: [],
        shops: [],
        suppliers: [],
        inventoryItems: [],
        movements: [],
        activities: [],
      );

  @override
  Future<Product> insertProduct(Product product) async =>
      product.copyWith(id: 'db-${product.name.toLowerCase()}');

  @override
  Future<PurchaseOrder> insertPurchaseOrder(PurchaseOrder order) async {
    if (!poInsertSucceeds) {
      throw StateError('simulierter PO-Insert-Fehler');
    }
    return order.copyWith(id: ++_poSeq);
  }

  @override
  Future<PurchaseOrderItem> insertPurchaseOrderItem(
      PurchaseOrderItem item) async {
    insertedPoItems.add(item);
    return item;
  }
}

Product _makeProduct(String csvId, String name) {
  final now = DateTime.utc(2026, 6, 9, 10);
  return Product(
    id: csvId,
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

PurchaseOrder _makePo(int csvId, String number) {
  final now = DateTime.utc(2026, 6, 9, 10);
  return PurchaseOrder(
    id: csvId,
    workspaceId: 'ws-test',
    userId: 'user-test',
    orderNumber: number,
    status: PurchaseOrderStatus.draft,
    createdAt: now,
    updatedAt: now,
  );
}

PurchaseOrderItem _makePoItem({
  required int csvPoId,
  required String csvProductId,
}) {
  final now = DateTime.utc(2026, 6, 9, 10);
  return PurchaseOrderItem(
    id: 'csv-item-$csvPoId',
    workspaceId: 'ws-test',
    purchaseOrderId: csvPoId,
    productId: csvProductId,
    quantityOrdered: 5,
    createdAt: now,
    updatedAt: now,
  );
}

DealsProvider _wire(_FakeRepository repo) {
  final catalog = CatalogProvider(repository: repo);
  final purchasing = PurchasingProvider(repository: repo);
  final stock = StockProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: purchasing,
  );
  return DealsProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: purchasing,
    stockProvider: stock,
  );
}

void main() {
  test(
      'PO-Item mit Parent-PO ohne Remap (nicht importiert) wird übersprungen — '
      'KEIN Insert mit synthetischer Parent-id', () async {
    // Produkt löst auf (importProductIdRemap), aber KEINE PO im Result →
    // importPoIdRemap[99] bleibt leer. Vor dem Fix hätte der `?? csvPoId`-
    // Fallback poId=99 (synthetisch) geinsertet → FK-Violation/Datenverlust.
    final repo = _FakeRepository();
    final inventory = _wire(repo);

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: const [],
      inventoryItems: const [],
      products: [_makeProduct('p-csv', 'Widget')],
      purchaseOrders: const [], // Parent-PO 99 fehlt!
      purchaseOrderItems: [_makePoItem(csvPoId: 99, csvProductId: 'p-csv')],
    );

    await inventory.importCsvAll(result);

    expect(repo.insertedPoItems, isEmpty,
        reason: 'Orphan-PO-Item darf NICHT mit synthetischer id geinsertet '
            'werden');
  });

  test('PO-Item mit fehlgeschlagenem Parent-PO-Insert wird übersprungen',
      () async {
    final repo = _FakeRepository(poInsertSucceeds: false);
    final inventory = _wire(repo);

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: const [],
      inventoryItems: const [],
      products: [_makeProduct('p-csv', 'Widget')],
      purchaseOrders: [_makePo(99, 'PO-FAIL')], // Insert wirft → kein Remap
      purchaseOrderItems: [_makePoItem(csvPoId: 99, csvProductId: 'p-csv')],
    );

    await inventory.importCsvAll(result);

    expect(repo.insertedPoItems, isEmpty);
  });

  test('valides PO-Item (Parent-PO importiert) wird mit echter DB-id geinsertet',
      () async {
    final repo = _FakeRepository();
    final inventory = _wire(repo);

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: const [],
      inventoryItems: const [],
      products: [_makeProduct('p-csv', 'Widget')],
      purchaseOrders: [_makePo(99, 'PO-OK')],
      purchaseOrderItems: [_makePoItem(csvPoId: 99, csvProductId: 'p-csv')],
    );

    await inventory.importCsvAll(result);

    expect(repo.insertedPoItems, hasLength(1));
    // Echte BIGSERIAL-DB-id (1001), nicht die synthetische 99.
    expect(repo.insertedPoItems.single.purchaseOrderId, equals(1001));
    expect(repo.insertedPoItems.single.productId, equals('db-widget'));
  });
}
