import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/providers/catalog_provider.dart';
import 'package:inventory_management/providers/deals_provider.dart';
import 'package:inventory_management/providers/stock_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Minimale Fake-Implementierung die alle Supabase-Calls abfängt.
/// Verfolgt die letzten insertMovement-Aufrufe damit die Tests den
/// erzeugten movementType prüfen können.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  // Konfigurierbar: welche workspaceId der Provider "sieht"
  @override
  String? get activeWorkspaceId => 'ws-test';

  // Bewegungen, die per insertMovement eingebracht wurden
  final List<InventoryMovement> insertedMovements = [];

  // Letztes Item, das per insert/update gespeichert wurde
  InventoryItem? lastInsertedItem;
  InventoryItem? lastUpdatedItem;

  // Produkte, die per insertProduct eingebracht wurden
  final List<Product> insertedProducts = [];

  // Produkte, die via loadAll() in den Provider-State vorgeladen werden.
  List<Product> seedProducts = [];

  // Wenn gesetzt, wirft insertProduct diese Exception (simuliert Race/Fehler).
  Object? insertProductError;

  // ── Snapshot-Load ──

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: const [],
        movements: const [],
        activities: const [],
        products: List.of(seedProducts),
      );

  // ── Item-CRUD ──

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async {
    lastInsertedItem = item;
    // Gib das Item unverändert zurück (als wäre es vom Server gespeichert).
    return item;
  }

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async {
    lastUpdatedItem = item;
    return item;
  }

  @override
  Future<void> deleteInventoryItem(String id) async {}

  // ── Movement-Insert ──

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async {
    insertedMovements.add(movement);
    return movement;
  }

  // ── Product-Insert ──

  @override
  Future<Product> insertProduct(Product product) async {
    final err = insertProductError;
    if (err != null) throw err;
    final now = DateTime.now().toUtc();
    final saved = Product(
      id: 'product-${insertedProducts.length + 1}',
      workspaceId: activeWorkspaceId ?? 'ws-test',
      userId: 'user-test',
      name: product.name,
      sku: product.sku,
      ean: product.ean,
      createdAt: now,
      updatedAt: now,
    );
    insertedProducts.add(saved);
    return saved;
  }
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

InventoryItem _makeItem({
  String id = 'item-1',
  String name = 'Test-Artikel',
  int quantity = 10,
  double? costPrice = 5.0,
}) =>
    InventoryItem(
      id: id,
      name: name,
      quantity: quantity,
      costPrice: costPrice,
      status: 'Im Lager',
    );

Deal _makeDeal({
  int id = 42,
  String product = 'Deal-Artikel',
  int quantity = 3,
  double? ekBrutto = 12.0,
}) =>
    Deal(
      id: id,
      product: product,
      quantity: quantity,
      isDropship: false,
      shop: 'Amazon',
      orderDate: DateTime(2026, 5, 20),
      ekBrutto: ekBrutto,
    );

Product _makeProduct({
  String id = 'prod-1',
  String name = 'Deal-Artikel',
  String? sku,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: name,
    sku: sku,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── StockProvider — addInventoryItem / updateInventoryItem / adjustStock ───

  late _FakeRepository repo;
  late StockProvider stock;

  setUp(() {
    repo = _FakeRepository();
    stock = StockProvider(repository: repo);
  });

  tearDown(() => stock.dispose());

  // ── addInventoryItem ──────────────────────────────────────────────────────

  group('addInventoryItem — movementType', () {
    test('addInventoryItem mit quantity > 0 erzeugt goodsIn-Movement', () async {
      final item = _makeItem(quantity: 5);
      await stock.addInventoryItem(item);

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.goodsIn),
      );
    });

    test('addInventoryItem mit quantity == 0 erzeugt kein Movement', () async {
      final item = _makeItem(quantity: 0);
      await stock.addInventoryItem(item);

      expect(repo.insertedMovements, isEmpty);
    });

    test('addInventoryItem: Movement-quantityChange == item.quantity', () async {
      final item = _makeItem(quantity: 7);
      await stock.addInventoryItem(item);

      expect(repo.insertedMovements.first.quantityChange, equals(7));
    });
  });

  // ── updateInventoryItem ───────────────────────────────────────────────────

  group('updateInventoryItem — movementType', () {
    /// Wir müssen das Item zunächst in den Provider-State laden, damit
    /// updateInventoryItem den "old"-Wert ermitteln kann. Dazu rufen wir
    /// addInventoryItem zuerst auf und leeren dann insertedMovements.
    Future<void> seed(InventoryItem item) async {
      await stock.addInventoryItem(item);
      repo.insertedMovements.clear();
    }

    test('delta > 0 → goodsIn-Movement', () async {
      final item = _makeItem(id: 'i1', quantity: 5);
      await seed(item);

      final updated = item.copyWith(quantity: 8); // delta = +3
      await stock.updateInventoryItem(updated);

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.goodsIn),
      );
      expect(repo.insertedMovements.first.quantityChange, equals(3));
    });

    test('delta < 0 → goodsOut-Movement', () async {
      final item = _makeItem(id: 'i2', quantity: 10);
      await seed(item);

      final updated = item.copyWith(quantity: 6); // delta = -4
      await stock.updateInventoryItem(updated);

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.goodsOut),
      );
      expect(repo.insertedMovements.first.quantityChange, equals(-4));
    });

    test('delta == 0 → kein Movement', () async {
      final item = _makeItem(id: 'i3', quantity: 5);
      await seed(item);

      final updated = item.copyWith(name: 'Neuer Name'); // quantity unverändert
      await stock.updateInventoryItem(updated);

      expect(repo.insertedMovements, isEmpty);
    });
  });

  // ── adjustStock ───────────────────────────────────────────────────────────

  group('adjustStock — movementType-Parameter wird durchgereicht', () {
    Future<void> seed(InventoryItem item) async {
      await stock.addInventoryItem(item);
      repo.insertedMovements.clear();
    }

    test('Default (kein movementType-Argument) → correction', () async {
      final item = _makeItem(id: 'j1', quantity: 5);
      await seed(item);

      await stock.adjustStock('j1', 2, 'Manuelle Korrektur');

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.correction),
      );
    });

    test('movementType: sale → sale wird durchgereicht', () async {
      final item = _makeItem(id: 'j2', quantity: 10);
      await seed(item);

      await stock.adjustStock(
        'j2',
        -3,
        'Verkauf',
        movementType: InventoryMovementType.sale,
      );

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.sale),
      );
      expect(repo.insertedMovements.first.quantityChange, equals(-3));
    });

    test('movementType: goodsIn → goodsIn', () async {
      final item = _makeItem(id: 'j3', quantity: 5);
      await seed(item);

      await stock.adjustStock(
        'j3',
        5,
        'Wareneingang',
        movementType: InventoryMovementType.goodsIn,
      );

      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.goodsIn),
      );
    });

    test('adjustStock mit delta == 0 erzeugt kein Movement (Frühzeitig-Exit)',
        () async {
      final item = _makeItem(id: 'j4', quantity: 5);
      await seed(item);

      await stock.adjustStock('j4', 0, 'Keine Änderung');

      expect(repo.insertedMovements, isEmpty);
    });

    test('adjustStock mit unbekannter id erzeugt kein Movement', () async {
      // Provider hat das Item nicht im State → idx == -1 → kein Movement
      await stock.adjustStock('non-existent', 5, 'Irrtum');

      expect(repo.insertedMovements, isEmpty);
    });
  });

  // ── checkInDeal — bleibt auf DealsProvider ────────────────────────────
  // checkInDeal ist ein Cross-Domain-Orchestrator (Plan §3 Option A) der auf
  // DealsProvider verbleibt und Stock über Write-Back-Hooks beschreibt.

  group('checkInDeal — movementType', () {
    late _FakeRepository invRepo;
    late CatalogProvider catalog;
    late StockProvider stockProv;
    late DealsProvider inventory;

    setUp(() {
      invRepo = _FakeRepository();
      catalog = CatalogProvider(repository: invRepo);
      stockProv = StockProvider(repository: invRepo, catalogProvider: catalog);
      inventory = DealsProvider(
        repository: invRepo,
        catalogProvider: catalog,
        stockProvider: stockProv,
      );
    });

    tearDown(() {
      inventory.dispose();
      stockProv.dispose();
      catalog.dispose();
    });

    test('checkInDeal erzeugt goodsIn-Movement', () async {
      final deal = _makeDeal(quantity: 4);
      await inventory.checkInDeal(deal);

      expect(invRepo.insertedMovements, hasLength(1));
      expect(
        invRepo.insertedMovements.first.movementType,
        equals(InventoryMovementType.goodsIn),
      );
    });

    test('checkInDeal: Movement-quantityChange == deal.quantity', () async {
      final deal = _makeDeal(quantity: 7);
      await inventory.checkInDeal(deal);

      expect(invRepo.insertedMovements.first.quantityChange, equals(7));
    });

    test('checkInDeal: unitCost entspricht deal.ekBrutto', () async {
      final deal = _makeDeal(ekBrutto: 19.99);
      await inventory.checkInDeal(deal);

      expect(invRepo.insertedMovements.first.unitCost, equals(19.99));
    });

    test('checkInDeal mit ekBrutto == null → unitCost == null im Movement',
        () async {
      final deal = _makeDeal(ekBrutto: null);
      await inventory.checkInDeal(deal);

      expect(invRepo.insertedMovements.first.unitCost, isNull);
    });
  });

  // ── checkInDeal — Produkt-Matching ────────────────────────────────────────

  group('checkInDeal — Produkt-Matching', () {
    late _FakeRepository invRepo;
    late CatalogProvider catalog;
    late StockProvider stockProv;
    late DealsProvider inventory;

    setUp(() {
      invRepo = _FakeRepository();
      catalog = CatalogProvider(repository: invRepo);
      stockProv = StockProvider(repository: invRepo, catalogProvider: catalog);
      inventory = DealsProvider(
        repository: invRepo,
        catalogProvider: catalog,
        stockProvider: stockProv,
      );
    });

    tearDown(() {
      inventory.dispose();
      stockProv.dispose();
      catalog.dispose();
    });

    /// Lädt einen Seed-Produkt-State in CatalogProvider + DealsProvider.
    Future<void> seedWithProducts(List<Product> products) async {
      invRepo.seedProducts = products;
      await Future.wait([catalog.loadData(), inventory.loadData()]);
      invRepo.insertedMovements.clear();
    }

    test('kein bestehendes Produkt → neues Produkt wird angelegt', () async {
      final deal = _makeDeal(product: 'Neuer Artikel');
      await inventory.checkInDeal(deal);

      // insertProduct wurde aufgerufen
      expect(invRepo.insertedProducts, hasLength(1));
      expect(invRepo.insertedProducts.first.name, equals('Neuer Artikel'));
    });

    test('neues Produkt: Item und Movement tragen die productId', () async {
      final deal = _makeDeal(product: 'Neuer Artikel');
      await inventory.checkInDeal(deal);

      final savedProductId = invRepo.insertedProducts.first.id;
      expect(invRepo.lastInsertedItem?.productId, equals(savedProductId));
      expect(invRepo.insertedMovements.first.productId, equals(savedProductId));
    });

    test('Treffer per Name (case-insensitiv) → kein insertProduct', () async {
      final existing = _makeProduct(id: 'prod-existing', name: 'Deal-Artikel');
      await seedWithProducts([existing]);

      final deal = _makeDeal(product: 'deal-artikel'); // Kleinbuchstaben
      await inventory.checkInDeal(deal);

      // Kein neues Produkt angelegt
      expect(invRepo.insertedProducts, isEmpty);
      // Bestehende productId verknüpft
      expect(invRepo.lastInsertedItem?.productId, equals('prod-existing'));
      expect(invRepo.insertedMovements.first.productId, equals('prod-existing'));
    });

    test('Treffer per SKU (case-insensitiv) hat Vorrang vor Name', () async {
      // Produkt mit SKU-ABC123 aber anderem Namen
      final existing = _makeProduct(
        id: 'prod-sku',
        name: 'Anderer Name',
        sku: 'ABC123',
      );
      // Weiteres Produkt mit passendem Namen aber ohne SKU
      final byName = _makeProduct(
        id: 'prod-name',
        name: 'Deal-Artikel',
      );
      await seedWithProducts([existing, byName]);

      // Deal mit SKU, die auf prod-sku matcht
      final deal = _makeDeal(product: 'Deal-Artikel');
      await inventory.checkInDeal(deal, sku: 'abc123'); // case-insensitiv

      // SKU-Treffer hat Vorrang
      expect(invRepo.lastInsertedItem?.productId, equals('prod-sku'));
    });

    test(
        'insertProduct-Fehler → defensiv: Item wird ohne productId eingebucht',
        () async {
      invRepo.insertProductError = Exception('UNIQUE Violation SKU');
      final deal = _makeDeal(product: 'Fehler-Artikel');
      // Kein throw — checkInDeal schlägt nicht fehl
      await expectLater(inventory.checkInDeal(deal), completes);

      // Item wurde eingebucht, aber ohne productId
      expect(invRepo.lastInsertedItem?.productId, isNull);
      // Movement trotzdem vorhanden
      expect(invRepo.insertedMovements, hasLength(1));
      expect(invRepo.insertedMovements.first.productId, isNull);
    });

    test('checkInDeal: product_id liegt VOR der Movement-Erzeugung am Item',
        () async {
      // Stellt sicher, dass savedItem.productId zur Zeit der Movement-Erstellung
      // bereits gesetzt ist (AF7b-Anforderung).
      final deal = _makeDeal(product: 'Reihenfolge-Test');
      await inventory.checkInDeal(deal);

      // insertProduct liefert eine ID; diese muss im Movement stehen.
      expect(invRepo.insertedProducts, hasLength(1));
      final productId = invRepo.insertedProducts.first.id;
      expect(invRepo.insertedMovements.first.productId, equals(productId));
    });
  });
}
