import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/models/product_stock.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository (AF8) ─────────────────────────────────────────────────────

/// Fake-Repository für KPI-Aggregations-Tests.
/// Konfigurierbar: seedInventoryItems, seedProducts, seedProductStock.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  List<InventoryItem> seedInventoryItems = [];
  List<Product> seedProducts = [];

  /// ProductStock-Rows, die `loadProductStock` zurückliefert.
  /// Entspricht dem, was der DB-View `product_stock` zurückgeben würde.
  List<ProductStock> seedProductStock = [];

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: List.of(seedInventoryItems),
        movements: const [],
        activities: const [],
        products: List.of(seedProducts),
      );

  @override
  Future<List<ProductStock>> loadProductStock(String workspaceId) async =>
      List.of(seedProductStock);

  // ── Schreib-Methoden (kein Supabase-Aufruf im Test) ──

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async => item;

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async => item;

  @override
  Future<void> deleteInventoryItem(String id) async {}

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async =>
      movement;

  @override
  Future<Product> insertProduct(Product product) async {
    final now = DateTime.now().toUtc();
    return Product(
      id: 'product-generated',
      workspaceId: activeWorkspaceId ?? 'ws-test',
      userId: 'user-test',
      name: product.name,
      sku: product.sku,
      createdAt: now,
      updatedAt: now,
    );
  }
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

Product _makeProduct({
  required String id,
  required String name,
  int minStock = 0,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: name,
    minStock: minStock,
    createdAt: now,
    updatedAt: now,
  );
}

InventoryItem _makeItem({
  required String id,
  required String name,
  int quantity = 0,
  int minStock = 0,
  String? productId,
}) =>
    InventoryItem(
      id: id,
      name: name,
      quantity: quantity,
      minStock: minStock,
      status: 'Im Lager',
      productId: productId,
    );

ProductStock _makeStock({
  required String productId,
  String? warehouseId,
  required int qty,
}) =>
    ProductStock(
      workspaceId: 'ws-test',
      productId: productId,
      warehouseId: warehouseId,
      qtyInWarehouse: qty,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeRepository repo;
  late InventoryProvider provider;

  setUp(() {
    repo = _FakeRepository();
    provider = InventoryProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  // ── Kern-Regressions-Test (Committee-Bug #9) ──────────────────────────────

  group('criticalStockCount — Produkt-Aggregation (Committee-Finding 9)', () {
    /// Regressions-Schutz: ein Produkt mit 3 Bestands-Rows à 2 Stück
    /// (Gesamtbestand = 6 ≥ minStock 5) darf NICHT als 3× kritisch zählen.
    test(
        'Produkt mit 3 Rows à 2 Stk (gesamt 6), minStock 5 → NICHT kritisch (0)',
        () async {
      const productId = 'prod-multi-warehouse';

      repo.seedProducts = [
        _makeProduct(id: productId, name: 'Multi-Lager-Artikel', minStock: 5),
      ];
      repo.seedInventoryItems = [
        _makeItem(id: 'i1', name: 'Artikel', quantity: 2, productId: productId),
        _makeItem(id: 'i2', name: 'Artikel', quantity: 2, productId: productId),
        _makeItem(id: 'i3', name: 'Artikel', quantity: 2, productId: productId),
      ];
      // View aggregiert pro (workspace_id, product_id, warehouse_id).
      // Drei separate Lager → drei product_stock-Rows.
      repo.seedProductStock = [
        _makeStock(productId: productId, warehouseId: 'wh-a', qty: 2),
        _makeStock(productId: productId, warehouseId: 'wh-b', qty: 2),
        _makeStock(productId: productId, warehouseId: 'wh-c', qty: 2),
      ];

      await provider.loadData();

      // Gesamt = 6, minStock = 5 → NICHT kritisch → 0
      expect(provider.criticalStockCount, equals(0),
          reason:
              'Aggregierter Bestand 6 >= minStock 5 → Produkt darf NICHT '
              'als kritisch zählen (Regressions-Test Committee-Bug #9)');
    });

    test(
        'Produkt mit 3 Rows à 2 Stk (gesamt 6), minStock 7 → 1× kritisch',
        () async {
      const productId = 'prod-under';

      repo.seedProducts = [
        _makeProduct(id: productId, name: 'Unterdecktes Produkt', minStock: 7),
      ];
      repo.seedInventoryItems = [
        _makeItem(id: 'i1', name: 'Artikel', quantity: 2, productId: productId),
        _makeItem(id: 'i2', name: 'Artikel', quantity: 2, productId: productId),
        _makeItem(id: 'i3', name: 'Artikel', quantity: 2, productId: productId),
      ];
      repo.seedProductStock = [
        _makeStock(productId: productId, warehouseId: 'wh-a', qty: 2),
        _makeStock(productId: productId, warehouseId: 'wh-b', qty: 2),
        _makeStock(productId: productId, warehouseId: 'wh-c', qty: 2),
      ];

      await provider.loadData();

      // Gesamt = 6, minStock = 7 → kritisch → 1
      expect(provider.criticalStockCount, equals(1));
    });
  });

  // ── Kombiniertes Szenario ─────────────────────────────────────────────────

  group('criticalStockCount — Kombination Produkt + nicht-verknüpfte Items', () {
    test(
        'unterdecktes Produkt + 1 kritisches nicht-verknüpftes Item → gesamt 2',
        () async {
      const productId = 'prod-critical';

      repo.seedProducts = [
        _makeProduct(id: productId, name: 'Kritisches Produkt', minStock: 10),
      ];
      // Produkt-verknüpftes Item: gesamt 5, minStock 10 → kritisch
      repo.seedInventoryItems = [
        _makeItem(
          id: 'linked-1',
          name: 'Verknüpft',
          quantity: 3,
          productId: productId,
        ),
        _makeItem(
          id: 'linked-2',
          name: 'Verknüpft 2',
          quantity: 2,
          productId: productId,
        ),
        // Nicht-verknüpft: quantity=0 < minStock=5 → kritisch
        _makeItem(
          id: 'unlinked',
          name: 'Ohne Produkt',
          quantity: 0,
          minStock: 5,
          productId: null,
        ),
        // Nicht-verknüpft: quantity=10, minStock=5 → NICHT kritisch
        _makeItem(
          id: 'unlinked-ok',
          name: 'Ohne Produkt OK',
          quantity: 10,
          minStock: 5,
          productId: null,
        ),
      ];
      repo.seedProductStock = [
        _makeStock(productId: productId, qty: 5), // gesamt 5 < minStock 10
      ];

      await provider.loadData();

      // 1 kritisches Produkt + 1 kritisches nicht-verknüpftes Item = 2
      expect(provider.criticalStockCount, equals(2));
    });

    test(
        'Produkt ausreichend gedeckt + 0 kritische nicht-verknüpfte Items → 0',
        () async {
      const productId = 'prod-ok';

      repo.seedProducts = [
        _makeProduct(id: productId, name: 'Gedecktes Produkt', minStock: 5),
      ];
      repo.seedInventoryItems = [
        _makeItem(
          id: 'linked',
          name: 'Verknüpft',
          quantity: 8,
          productId: productId,
        ),
        _makeItem(
          id: 'unlinked',
          name: 'Ohne Produkt',
          quantity: 10,
          minStock: 3,
          productId: null,
        ),
      ];
      repo.seedProductStock = [
        _makeStock(productId: productId, qty: 8), // 8 >= 5 → OK
      ];

      await provider.loadData();

      expect(provider.criticalStockCount, equals(0));
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('criticalStockCount — Edge Cases', () {
    test('kein product_stock (View leer) → Fallback auf Item-Level für alle',
        () async {
      const productId = 'prod-no-stock';

      repo.seedProducts = [
        _makeProduct(id: productId, name: 'Ohne Stock-View', minStock: 5),
      ];
      // Produkt hat Items, aber product_stock ist leer (View nicht geladen).
      // In diesem Fall kann das Produkt NICHT als kritisch zählen, da
      // keine Aggregation möglich ist — das ist der Safe Fallback.
      repo.seedInventoryItems = [
        _makeItem(
          id: 'linked',
          name: 'Verknüpft',
          quantity: 2,
          minStock: 5,
          productId: productId,
        ),
      ];
      repo.seedProductStock = []; // leer

      await provider.loadData();

      // product_stock leer → für Produkt keine Aggregation → 0 kritische Produkte
      // Nicht-verknüpfte Items gibt es keine → gesamt 0
      expect(provider.criticalStockCount, equals(0));
    });

    test('minStock == 0 → Produkt nie kritisch', () async {
      const productId = 'prod-zero-min';

      repo.seedProducts = [
        _makeProduct(id: productId, name: 'Nullbestand OK', minStock: 0),
      ];
      repo.seedInventoryItems = [
        _makeItem(
          id: 'item',
          name: 'Nullbestand',
          quantity: 0,
          productId: productId,
        ),
      ];
      repo.seedProductStock = [
        _makeStock(productId: productId, qty: 0),
      ];

      await provider.loadData();

      // 0 >= 0 → nicht kritisch
      expect(provider.criticalStockCount, equals(0));
    });

    test('Produkt-Row in product_stock ohne passendes Produkt im Cache → ignoriert',
        () async {
      repo.seedProducts = []; // kein Produkt im Cache

      repo.seedInventoryItems = [];
      // product_stock hat eine Row für ein Produkt, das nicht im Cache ist
      // (z. B. gelöscht oder noch nicht geladen)
      repo.seedProductStock = [
        _makeStock(productId: 'stale-product-id', qty: 0),
      ];

      await provider.loadData();

      // Stale product_stock-Rows ohne Cache-Produkt → ignoriert → 0
      expect(provider.criticalStockCount, equals(0));
    });

    test('mehrere Produkte: nur eines kritisch → zählt genau 1', () async {
      repo.seedProducts = [
        _makeProduct(id: 'prod-ok', name: 'OK Artikel', minStock: 3),
        _makeProduct(id: 'prod-crit', name: 'Kritisch Artikel', minStock: 10),
      ];
      repo.seedInventoryItems = [];
      repo.seedProductStock = [
        _makeStock(productId: 'prod-ok', qty: 5),   // 5 >= 3 → OK
        _makeStock(productId: 'prod-crit', qty: 4),  // 4 < 10 → kritisch
      ];

      await provider.loadData();

      expect(provider.criticalStockCount, equals(1));
    });
  });

  // ── totalStockQuantity — bleibt physische Summe ────────────────────────────

  group('totalStockQuantity — Summe aller inventory_items.quantity', () {
    test('Summe aller Rows unabhängig von product_id', () async {
      repo.seedInventoryItems = [
        _makeItem(id: 'i1', name: 'A', quantity: 10, productId: 'prod-1'),
        _makeItem(id: 'i2', name: 'B', quantity: 5, productId: 'prod-1'),
        _makeItem(id: 'i3', name: 'C', quantity: 3, productId: null),
      ];
      repo.seedProductStock = [];

      await provider.loadData();

      expect(provider.totalStockQuantity, equals(18));
    });
  });

  // ── InventoryItem.isCritical — Per-Row bleibt erhalten ───────────────────

  group('InventoryItem.isCritical — Per-Row-Logik', () {
    test('isCritical ist true wenn quantity < minStock', () {
      final item = _makeItem(id: 'x', name: 'Test', quantity: 2, minStock: 5);
      expect(item.isCritical, isTrue);
    });

    test('isCritical ist false wenn quantity >= minStock', () {
      final item = _makeItem(id: 'x', name: 'Test', quantity: 5, minStock: 5);
      expect(item.isCritical, isFalse);
    });

    test('isCritical funktioniert unabhängig von productId (bleibt nutzbar)',
        () {
      final linked = _makeItem(
        id: 'linked',
        name: 'Test',
        quantity: 1,
        minStock: 5,
        productId: 'some-product',
      );
      // isCritical ist per Row korrekt — nur für die Dashboard-Aggregation
      // darf man ihn nicht für produkt-verknüpfte Rows verwenden.
      // Der Getter selbst bleibt unverändert.
      expect(linked.isCritical, isTrue);
    });
  });
}
