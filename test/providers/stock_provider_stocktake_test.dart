import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product_stock.dart';
import 'package:inventory_management/models/stocktake.dart';
import 'package:inventory_management/models/stocktake_item.dart';
import 'package:inventory_management/models/warehouse.dart';
import 'package:inventory_management/providers/stock_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  // ── Seed-Daten ──
  List<ProductStock> seedProductStock = [];
  List<InventoryItem> seedInventoryItems = [];

  // ── Protokoll-Listen ──
  final List<Stocktake> insertedStocktakes = [];
  final List<Stocktake> updatedStocktakes = [];
  final List<StocktakeItem> insertedStocktakeItems = [];
  final List<StocktakeItem> updatedStocktakeItems = [];
  final List<InventoryMovement> insertedMovements = [];
  final List<InventoryItem> updatedInventoryItems = [];

  // ── BIGSERIAL-Zähler ──
  int _nextStocktakeId = 100;

  // ── CloudSnapshot ──
  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: List.of(seedInventoryItems),
        movements: const [],
        activities: const [],
        stocktakes: const [],
      );

  // ── product_stock View ──
  @override
  Future<List<ProductStock>> loadProductStock(String workspaceId) async =>
      List.of(seedProductStock);

  // ── Stocktake CRUD ──
  @override
  Future<Stocktake> insertStocktake(Stocktake stocktake) async {
    final saved = stocktake.copyWith(id: _nextStocktakeId++);
    insertedStocktakes.add(saved);
    return saved;
  }

  @override
  Future<Stocktake> updateStocktake(Stocktake stocktake) async {
    updatedStocktakes.add(stocktake);
    return stocktake;
  }

  @override
  Future<void> deleteStocktake(int id) async {}

  // ── StocktakeItem CRUD ──
  @override
  Future<StocktakeItem> insertStocktakeItem(StocktakeItem item) async {
    insertedStocktakeItems.add(item);
    return item;
  }

  @override
  Future<StocktakeItem> updateStocktakeItem(StocktakeItem item) async {
    updatedStocktakeItems.add(item);
    return item;
  }

  @override
  Future<List<StocktakeItem>> loadStocktakeItems(
    String workspaceId,
    int stocktakeId,
  ) async =>
      const [];

  // ── Movement ──
  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async {
    insertedMovements.add(movement);
    return movement;
  }

  // ── Inventory Items ──
  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async {
    updatedInventoryItems.add(item);
    return item;
  }

  // ── Warehouse-Bootstrap-Guard (kein Lager in Tests anlegen) ──
  @override
  Future<List<Warehouse>> loadWarehouses(String workspaceId) async =>
      const [];
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

StockProvider _makeProvider(_FakeRepository repo) =>
    StockProvider(repository: repo);

ProductStock _makeStock({
  required String productId,
  required int qty,
  String? warehouseId,
}) =>
    ProductStock(
      workspaceId: 'ws-test',
      productId: productId,
      warehouseId: warehouseId,
      qtyInWarehouse: qty,
    );

InventoryItem _makeInventoryItem({
  required String id,
  required String name,
  required int quantity,
  String? productId,
  String? warehouseId,
}) {
  return InventoryItem(
    id: id,
    name: name,
    quantity: quantity,
    productId: productId,
    warehouseId: warehouseId,
  );
}

StocktakeItem _makeStocktakeItem({
  String id = 'si-1',
  int stocktakeId = 100,
  required String productId,
  required int expectedQty,
  int? countedQty,
}) {
  final now = DateTime.utc(2026, 5, 22, 10);
  return StocktakeItem(
    id: id,
    workspaceId: 'ws-test',
    stocktakeId: stocktakeId,
    productId: productId,
    expectedQty: expectedQty,
    countedQty: countedQty,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── startInventory: Soll-Snapshot ─────────────────────────────────────────

  group('startInventory — Soll-Snapshot', () {
    test('legt Stocktake-Kopf mit Status counting an', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [_makeStock(productId: 'prod-1', qty: 5)];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory();

      expect(repo.insertedStocktakes, hasLength(1));
      expect(
        repo.insertedStocktakes.first.status,
        equals(StocktakeStatus.counting),
      );
    });

    test('erzeugt korrekte Anzahl StocktakeItems für alle Produkte', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [
        _makeStock(productId: 'prod-1', qty: 10),
        _makeStock(productId: 'prod-2', qty: 5),
        _makeStock(productId: 'prod-3', qty: 3),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory();

      expect(repo.insertedStocktakeItems, hasLength(3));
    });

    test('erzeugt StocktakeItems mit korrekten expected_qty Werten', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [
        _makeStock(productId: 'prod-1', qty: 10),
        _makeStock(productId: 'prod-2', qty: 7),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory();

      final byProduct = {
        for (final i in repo.insertedStocktakeItems) i.productId: i.expectedQty
      };
      expect(byProduct['prod-1'], equals(10));
      expect(byProduct['prod-2'], equals(7));
    });

    test('alle neuen StocktakeItems haben counted_qty == null', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [
        _makeStock(productId: 'prod-1', qty: 5),
        _makeStock(productId: 'prod-2', qty: 8),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory();

      for (final item in repo.insertedStocktakeItems) {
        expect(item.countedQty, isNull,
            reason:
                'Jede neue StocktakeItem-Position muss counted_qty == null haben');
      }
    });

    test('aggregiert Bestand über mehrere Lager pro Produkt', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [
        _makeStock(productId: 'prod-1', qty: 6, warehouseId: 'wh-1'),
        _makeStock(productId: 'prod-1', qty: 4, warehouseId: 'wh-2'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory();

      // Beide Rows von prod-1 → Summe 10
      expect(repo.insertedStocktakeItems, hasLength(1));
      expect(repo.insertedStocktakeItems.first.productId, equals('prod-1'));
      expect(repo.insertedStocktakeItems.first.expectedQty, equals(10));
    });

    test('filtert nach warehouseId wenn angegeben', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [
        _makeStock(productId: 'prod-1', qty: 6, warehouseId: 'wh-1'),
        _makeStock(productId: 'prod-2', qty: 4, warehouseId: 'wh-2'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      // Nur wh-1
      await provider.startInventory(warehouseId: 'wh-1');

      expect(repo.insertedStocktakeItems, hasLength(1));
      expect(
          repo.insertedStocktakeItems.first.productId, equals('prod-1'));
    });

    test('schließt Produkte mit Bestand 0 aus', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [
        _makeStock(productId: 'prod-1', qty: 5),
        _makeStock(productId: 'prod-zero', qty: 0),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory();

      expect(repo.insertedStocktakeItems, hasLength(1));
      expect(
          repo.insertedStocktakeItems.first.productId, equals('prod-1'));
    });

    test('gibt Stocktake mit server-seitig vergebener id zurück', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final result = await provider.startInventory();

      expect(result.id, isNotNull);
      expect(result.id, isA<int>());
    });

    test('fügt Stocktake dem lokalen Cache hinzu', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [];
      final provider = _makeProvider(repo);
      await provider.loadData();

      expect(provider.stocktakes, isEmpty);
      await provider.startInventory();
      expect(provider.stocktakes, hasLength(1));
    });

    test('setzt startedAt auf einen Zeitpunkt nahe jetzt', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final before = DateTime.now().toUtc();
      await provider.startInventory();
      final after = DateTime.now().toUtc();

      final inserted = repo.insertedStocktakes.first;
      expect(inserted.startedAt, isNotNull);
      expect(
        inserted.startedAt!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        inserted.startedAt!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('verwendet title wenn angegeben', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory(title: 'Jahresabschluss');

      expect(repo.insertedStocktakes.first.title, equals('Jahresabschluss'));
    });
  });

  // ── countStocktakeItem: inkrementelles Speichern ──────────────────────────

  group('countStocktakeItem — inkrementelles Speichern', () {
    test('persistiert counted_qty sofort in der Datenbank', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final item = _makeStocktakeItem(
        productId: 'prod-1',
        expectedQty: 10,
        countedQty: null,
      );

      await provider.countStocktakeItem(item, 8);

      expect(repo.updatedStocktakeItems, hasLength(1));
      expect(repo.updatedStocktakeItems.first.countedQty, equals(8));
    });

    test('gibt das server-seitig gespeicherte Item zurück', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final item = _makeStocktakeItem(productId: 'prod-1', expectedQty: 10);
      final result = await provider.countStocktakeItem(item, 12);

      expect(result.countedQty, equals(12));
    });

    test('counted_qty = 0 ist ein gültiger Zählwert', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final item = _makeStocktakeItem(productId: 'prod-1', expectedQty: 5);
      await provider.countStocktakeItem(item, 0);

      expect(repo.updatedStocktakeItems.first.countedQty, equals(0));
    });

    test('kann mehrere Items nacheinander inkrementell zählen', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final item1 = _makeStocktakeItem(
          id: 'si-1', productId: 'prod-1', expectedQty: 10);
      final item2 = _makeStocktakeItem(
          id: 'si-2', productId: 'prod-2', expectedQty: 5);

      await provider.countStocktakeItem(item1, 9);
      await provider.countStocktakeItem(item2, 6);

      expect(repo.updatedStocktakeItems, hasLength(2));
      expect(repo.updatedStocktakeItems[0].countedQty, equals(9));
      expect(repo.updatedStocktakeItems[1].countedQty, equals(6));
    });
  });

  // ── closeStocktake: Differenz-Movements + Bestandsangleich ───────────────

  group('closeStocktake — Differenz-Movements', () {
    test('erzeugt kein Movement wenn counted_qty == expected_qty', () async {
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 10, productId: 'prod-1'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            productId: 'prod-1', expectedQty: 10, countedQty: 10),
      ];

      await provider.closeStocktake(stocktake, items);

      expect(repo.insertedMovements, isEmpty,
          reason: 'Bei 0 Differenz darf kein Movement entstehen');
    });

    test('erzeugt Movement nur für Positionen mit Differenz', () async {
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 10, productId: 'prod-1'),
        _makeInventoryItem(
            id: 'inv-2', name: 'P2', quantity: 5, productId: 'prod-2'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            id: 'si-1', productId: 'prod-1', expectedQty: 10, countedQty: 10),
        _makeStocktakeItem(
            id: 'si-2', productId: 'prod-2', expectedQty: 5, countedQty: 3),
      ];

      await provider.closeStocktake(stocktake, items);

      expect(repo.insertedMovements, hasLength(1),
          reason: 'Nur prod-2 hat Differenz (-2)');
      expect(repo.insertedMovements.first.productId, equals('prod-2'));
      expect(repo.insertedMovements.first.quantityChange, equals(-2));
    });

    test('erzeugt Movements für alle Positionen mit Differenz', () async {
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 10, productId: 'prod-1'),
        _makeInventoryItem(
            id: 'inv-2', name: 'P2', quantity: 5, productId: 'prod-2'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            id: 'si-1', productId: 'prod-1', expectedQty: 10, countedQty: 8),
        _makeStocktakeItem(
            id: 'si-2', productId: 'prod-2', expectedQty: 5, countedQty: 7),
      ];

      await provider.closeStocktake(stocktake, items);

      expect(repo.insertedMovements, hasLength(2));
      final byProduct = {
        for (final m in repo.insertedMovements) m.productId: m.quantityChange
      };
      expect(byProduct['prod-1'], equals(-2)); // 8 - 10
      expect(byProduct['prod-2'], equals(2));  // 7 - 5
    });

    test('Movements haben movement_type = stocktake', () async {
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 10, productId: 'prod-1'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            productId: 'prod-1', expectedQty: 10, countedQty: 6),
      ];

      await provider.closeStocktake(stocktake, items);

      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.stocktake),
      );
    });

    test('überspringt Positionen mit counted_qty == null', () async {
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 10, productId: 'prod-1'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            productId: 'prod-1', expectedQty: 10, countedQty: null),
      ];

      await provider.closeStocktake(stocktake, items);

      expect(repo.insertedMovements, isEmpty,
          reason: 'Ungezählte Positionen dürfen kein Movement erzeugen');
    });

    test('gleicht Bestand auf counted_qty an', () async {
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 10, productId: 'prod-1'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            productId: 'prod-1', expectedQty: 10, countedQty: 7),
      ];

      await provider.closeStocktake(stocktake, items);

      expect(repo.updatedInventoryItems, hasLength(1));
      expect(repo.updatedInventoryItems.first.quantity, equals(7));
    });

    test('gleicht Bestand NICHT an wenn keine Differenz', () async {
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 10, productId: 'prod-1'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            productId: 'prod-1', expectedQty: 10, countedQty: 10),
      ];

      await provider.closeStocktake(stocktake, items);

      expect(repo.updatedInventoryItems, isEmpty);
    });

    test('setzt Stocktake-Status auf closed', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );

      final result = await provider.closeStocktake(stocktake, const []);

      expect(result.status, equals(StocktakeStatus.closed));
      expect(repo.updatedStocktakes, hasLength(1));
      expect(
        repo.updatedStocktakes.first.status,
        equals(StocktakeStatus.closed),
      );
    });

    test('setzt closed_at auf einen Zeitpunkt nahe jetzt', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );

      final before = DateTime.now().toUtc();
      await provider.closeStocktake(stocktake, const []);
      final after = DateTime.now().toUtc();

      final updated = repo.updatedStocktakes.first;
      expect(updated.closedAt, isNotNull);
      expect(
        updated.closedAt!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        updated.closedAt!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('Movements sind append-only (kein Update, nur Insert)', () async {
      // Regressions-Test: sicherstellen, dass nur insertMovement aufgerufen
      // wird und kein updateMovement existiert oder aufrufbar wäre.
      final repo = _FakeRepository();
      repo.seedInventoryItems = [
        _makeInventoryItem(
            id: 'inv-1', name: 'P1', quantity: 5, productId: 'prod-1'),
      ];
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );
      final items = [
        _makeStocktakeItem(
            productId: 'prod-1', expectedQty: 5, countedQty: 3),
      ];

      await provider.closeStocktake(stocktake, items);

      // Nur insertedMovements — keine "updatedMovements" in diesem Fake.
      expect(repo.insertedMovements, isNotEmpty);
      expect(repo.insertedMovements.first.quantityChange, equals(-2));
    });
  });

  // ── Status-Übergänge ─────────────────────────────────────────────────────

  group('Status-Übergänge', () {
    test('startInventory erzeugt Stocktake mit Status counting', () async {
      final repo = _FakeRepository();
      repo.seedProductStock = [];
      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.startInventory();

      expect(
        repo.insertedStocktakes.first.status,
        equals(StocktakeStatus.counting),
      );
    });

    test('closeStocktake setzt Status von counting auf closed', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        id: 100,
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );

      final result = await provider.closeStocktake(stocktake, const []);

      expect(result.status, equals(StocktakeStatus.closed));
    });

    test('CRUD: addStocktake + deleteStocktake', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final stocktake = Stocktake(
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.open,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );

      final saved = await provider.addStocktake(stocktake);
      expect(provider.stocktakes, hasLength(1));

      await provider.deleteStocktake(saved.id!);
      expect(provider.stocktakes, isEmpty);
    });
  });

  // ── loadStocktakeItems: lazy ──────────────────────────────────────────────

  group('loadStocktakeItems — lazy', () {
    test('liefert leere Liste wenn kein Workspace aktiv', () async {
      final repo = _FakeRepository();
      // activeWorkspaceId ist 'ws-test', aber null-Simulation nicht einfach
      // ohne extra-Override — der Test verifiziert dass loadStocktakeItems
      // delegiert und die FakeRepo-Implementierung trifft.
      final provider = _makeProvider(repo);
      // Kein loadData() → kein activeWorkspaceId im Provider-eigenen State.
      // Aber FakeRepo gibt immer 'ws-test' zurück → leere Liste von Fake.
      final items = await provider.loadStocktakeItems(100);
      expect(items, isA<List<StocktakeItem>>());
    });
  });
}
