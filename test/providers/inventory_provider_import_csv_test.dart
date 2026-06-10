import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/buyer.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/purchase_order.dart';
import 'package:inventory_management/models/shop.dart';
import 'package:inventory_management/models/supplier.dart';
import 'package:inventory_management/models/warehouse.dart';
import 'package:inventory_management/providers/catalog_provider.dart';
import 'package:inventory_management/providers/deals_provider.dart';
import 'package:inventory_management/providers/purchasing_provider.dart';
import 'package:inventory_management/providers/stock_provider.dart';
import 'package:inventory_management/services/csv_service.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Fake-Repository für den importCsvAll-Write-Back-Contract-Test.
///
/// Verifiziert, dass `importCsvAll` (Orchestrator in [DealsProvider]) die
/// importierten Suppliers/POs über die public Write-Back-Hooks in den
/// injizierten [PurchasingProvider] schreibt, importierte Warehouses/Items
/// in den [StockProvider] schreibt — und das 5-Tuple-Return-Format unverändert
/// bleibt.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  int _supplierSeq = 0;
  int _poSeq = 0;

  final List<Supplier> insertedSuppliers = [];
  final List<PurchaseOrder> insertedPurchaseOrders = [];

  @override
  Future<CloudSnapshot> loadAll() async => const CloudSnapshot(
        deals: [],
        buyers: [],
        shops: [],
        suppliers: [],
        inventoryItems: [],
        movements: [],
        activities: [],
        purchaseOrders: [],
      );

  @override
  Future<List<Deal>> insertDeals(List<Deal> deals) async => deals;

  @override
  Future<Shop> insertShop(Shop shop) async => shop;

  @override
  Future<Buyer> insertBuyer(Buyer buyer) async => buyer;

  @override
  Future<Supplier> insertSupplier(Supplier supplier) async {
    final saved = supplier.copyWith(id: 'db-sup-${++_supplierSeq}');
    insertedSuppliers.add(saved);
    return saved;
  }

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async => item;

  @override
  Future<PurchaseOrder> insertPurchaseOrder(PurchaseOrder order) async {
    final saved = order.copyWith(id: ++_poSeq);
    insertedPurchaseOrders.add(saved);
    return saved;
  }

  @override
  Future<Warehouse> insertWarehouse(Warehouse warehouse) async {
    final now = DateTime.utc(2026, 6, 8, 10);
    return Warehouse(
      id: 'wh-${warehouse.name.toLowerCase().replaceAll(' ', '-')}',
      workspaceId: activeWorkspaceId ?? 'ws-test',
      userId: 'user-test',
      name: warehouse.name,
      isDefault: warehouse.isDefault,
      isActive: warehouse.isActive,
      createdAt: now,
      updatedAt: now,
    );
  }
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

Supplier _makeSupplier(String name) => Supplier(id: '', name: name);

PurchaseOrder _makePo(String orderNumber, {DateTime? createdAt}) {
  final created = createdAt ?? DateTime.utc(2026, 6, 8, 10);
  return PurchaseOrder(
    id: null,
    workspaceId: '',
    userId: '',
    orderNumber: orderNumber,
    status: PurchaseOrderStatus.draft,
    createdAt: created,
    updatedAt: created,
  );
}

/// Wires all four providers sharing the same [repo].
/// Returns a named record so callers can destructure only what they need.
({
  DealsProvider inventory,
  PurchasingProvider purchasing,
  StockProvider stock,
}) _wire(_FakeRepository repo) {
  final catalog = CatalogProvider(repository: repo);
  final purchasing = PurchasingProvider(repository: repo);
  final stock = StockProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: purchasing,
  );
  final inventory = DealsProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: purchasing,
    stockProvider: stock,
  );
  return (inventory: inventory, purchasing: purchasing, stock: stock);
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  test(
      'importCsvAll: 5-Tuple-Return unverändert (deals, shops, buyers, '
      'suppliers, items)', () async {
    final repo = _FakeRepository();
    final wired = _wire(repo);

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: [_makeSupplier('Acme'), _makeSupplier('Bravo')],
      inventoryItems: const [],
    );

    final tuple = await wired.inventory.importCsvAll(result);

    // Tuple-Shape: genau 5 Felder, supplierCount = 2.
    expect(tuple.$1, equals(0)); // deals
    expect(tuple.$2, equals(0)); // shops
    expect(tuple.$3, equals(0)); // buyers
    expect(tuple.$4, equals(2)); // suppliers
    expect(tuple.$5, equals(0)); // items
  });

  test(
      'importCsvAll: importierte Suppliers landen im injizierten '
      'PurchasingProvider (Write-Back-Contract)', () async {
    final repo = _FakeRepository();
    final wired = _wire(repo);

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: [_makeSupplier('Zeta'), _makeSupplier('alpha')],
      inventoryItems: const [],
    );

    await wired.inventory.importCsvAll(result);

    // Suppliers wurden über die Hooks in den PurchasingProvider geschrieben …
    expect(wired.purchasing.suppliers, hasLength(2));
    // … und alphabetisch (case-insensitive) sortiert (sortSuppliers-Hook).
    expect(
      wired.purchasing.suppliers.map((s) => s.name).toList(),
      equals(['alpha', 'Zeta']),
    );
  });

  test(
      'importCsvAll: importierte POs landen im injizierten PurchasingProvider',
      () async {
    final repo = _FakeRepository();
    final wired = _wire(repo);

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: const [],
      inventoryItems: const [],
      // PO-A älter, PO-B neuer → der sortPurchaseOrders-Hook muss B vor A bringen.
      purchaseOrders: [
        _makePo('PO-A', createdAt: DateTime.utc(2026, 1, 1)),
        _makePo('PO-B', createdAt: DateTime.utc(2026, 6, 1)),
      ],
    );

    await wired.inventory.importCsvAll(result);

    expect(wired.purchasing.purchaseOrders, hasLength(2));
    expect(repo.insertedPurchaseOrders, hasLength(2));
    // PO-Insert-Hook + sortPurchaseOrders-Hook → newest-first nach createdAt
    // (geordnete Assertion, NICHT toSet — sonst bliebe der Sort ungetestet).
    expect(
      wired.purchasing.purchaseOrders.map((p) => p.orderNumber).toList(),
      equals(['PO-B', 'PO-A']),
    );
  });

  test(
      'importCsvAll: dedup-seed liest aus PurchasingProvider — vorhandener '
      'Supplier wird übersprungen', () async {
    final repo = _FakeRepository();
    final wired = _wire(repo);

    // Vorhandener Supplier im PurchasingProvider-Cache (via Hook).
    wired.purchasing.upsertSupplierFromImport(
      Supplier(id: 'existing', name: 'Acme'),
    );

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      // 'Acme' existiert bereits (case-insensitive) → wird übersprungen.
      suppliers: [_makeSupplier('acme'), _makeSupplier('Newco')],
      inventoryItems: const [],
    );

    final tuple = await wired.inventory.importCsvAll(result);

    // Nur 'Newco' wurde neu eingefügt.
    expect(tuple.$4, equals(1));
    expect(repo.insertedSuppliers, hasLength(1));
    expect(repo.insertedSuppliers.first.name, equals('Newco'));
    // Cache: bestehender + neuer Supplier = 2.
    expect(wired.purchasing.suppliers, hasLength(2));
  });

  // ── Stock Write-Back Contract ─────────────────────────────────────────────
  // Asserts that importCsvAll writes imported warehouses and inventory items
  // into the injected StockProvider via its write-back hooks
  // (upsertWarehouseFromImport / upsertInventoryItemFromImport +
  // sortWarehouses / sortInventoryItems + notifyAfterCrossDomainWrite).
  // Mirrors the PurchasingProvider write-back assertions above (plan §3).

  test(
      'importCsvAll: importierte Warehouses landen im injizierten StockProvider '
      '(Write-Back-Contract)', () async {
    final repo = _FakeRepository();
    final wired = _wire(repo);

    final wh = Warehouse(
      id: '',
      workspaceId: '',
      userId: '',
      name: 'Zentrallager',
      isDefault: false,
      isActive: true,
      createdAt: DateTime.utc(2026, 6, 8),
      updatedAt: DateTime.utc(2026, 6, 8),
    );

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: const [],
      inventoryItems: const [],
      warehouses: [wh],
    );

    await wired.inventory.importCsvAll(result);

    // The warehouse was written into StockProvider via the hook.
    expect(wired.stock.warehouses, hasLength(1));
    expect(wired.stock.warehouses.first.name, equals('Zentrallager'));
  });

  test(
      'importCsvAll: importierte InventoryItems landen im injizierten '
      'StockProvider (Write-Back-Contract)', () async {
    final repo = _FakeRepository();
    final wired = _wire(repo);

    final item = InventoryItem(
      id: 'item-csv-1',
      name: 'Importierter Artikel',
      quantity: 5,
    );

    final result = CsvImportResult(
      deals: const [],
      shops: const [],
      buyers: const [],
      suppliers: const [],
      inventoryItems: [item],
    );

    await wired.inventory.importCsvAll(result);

    // The item was written into StockProvider via the hook.
    expect(wired.stock.inventoryItems, hasLength(1));
    expect(wired.stock.inventoryItems.first.name, equals('Importierter Artikel'));
  });
}
