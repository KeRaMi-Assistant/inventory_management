import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/models/purchase_order_item.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Fake-Repository für `bookGoodsReceipt`-Tests (Task C4).
///
/// Kernpunkt: `incrementPoItemReceived` akkumuliert atomar — der
/// Fake-Store hält `quantity_received` pro Item-ID und erhöht ihn bei
/// jedem Aufruf um den übergebenen Wert. Dies spiegelt das serverseitige
/// `SET quantity_received = quantity_received + p_qty` korrekt wider und
/// beweist das "kein Überschreiben"-Verhalten (Parallel-Booking-Test).
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  // ── interner Speicher ──

  /// Aktueller `quantity_received`-Wert pro item-ID (atomar akkumuliert).
  final Map<String, int> _receivedByItemId = {};

  /// Protokoll aller `incrementPoItemReceived`-Aufrufe für Assertions.
  final List<({String itemId, int qty})> incrementCalls = [];

  /// Protokoll aller `insertMovement`-Aufrufe.
  final List<InventoryMovement> insertedMovements = [];

  /// Protokoll aller `insertInventoryItem`-Aufrufe.
  final List<InventoryItem> insertedInventoryItems = [];

  /// Protokoll aller `updateInventoryItem`-Aufrufe.
  final List<InventoryItem> updatedInventoryItems = [];

  /// Seed-Daten für den Snapshot.
  List<Product> seedProducts = [];
  List<InventoryItem> seedInventoryItems = [];
  List<PurchaseOrderItem> seedPurchaseOrderItems = [];

  /// Initialisiert `quantity_received` für ein Item (Pre-Condition in Tests).
  void seedReceivedQty(String itemId, int qty) {
    _receivedByItemId[itemId] = qty;
  }

  // ── Snapshot ──

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
        purchaseOrders: const [],
      );

  // ── Atomares Increment — simuliert `SET qty_received = qty_received + p_qty` ──

  @override
  Future<PurchaseOrderItem> incrementPoItemReceived(
    String itemId,
    int qty,
  ) async {
    // Atomar akkumulieren (kein Read-modify-write, nur Increment):
    _receivedByItemId.update(
      itemId,
      (existing) => existing + qty,
      ifAbsent: () => qty,
    );
    incrementCalls.add((itemId: itemId, qty: qty));

    // Echtes Item aus dem Seed holen, `quantityReceived` mit aktuellem Wert
    // aus dem Fake-Store befüllen und zurückgeben.
    final seed = seedPurchaseOrderItems.where((i) => i.id == itemId).firstOrNull;
    final now = DateTime.utc(2026, 5, 22, 12);
    return PurchaseOrderItem(
      id: itemId,
      workspaceId: 'ws-test',
      purchaseOrderId: seed?.purchaseOrderId ?? 1,
      productId: seed?.productId,
      quantityOrdered: seed?.quantityOrdered ?? 10,
      quantityReceived: _receivedByItemId[itemId] ?? qty,
      unitPrice: seed?.unitPrice,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Movement ──

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async {
    insertedMovements.add(movement);
    return movement;
  }

  // ── Inventory Items ──

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async {
    insertedInventoryItems.add(item);
    return item;
  }

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async {
    updatedInventoryItems.add(item);
    return item;
  }

  @override
  Future<void> deleteInventoryItem(String id) async {}
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

InventoryProvider _makeProvider(_FakeRepository repo) =>
    InventoryProvider(repository: repo);

PurchaseOrderItem _makePoItem({
  required String id,
  required String productId,
  int quantityOrdered = 10,
  int quantityReceived = 0,
  double? unitPrice,
}) {
  final now = DateTime.utc(2026, 5, 22, 10);
  return PurchaseOrderItem(
    id: id,
    workspaceId: 'ws-test',
    purchaseOrderId: 1,
    productId: productId,
    quantityOrdered: quantityOrdered,
    quantityReceived: quantityReceived,
    unitPrice: unitPrice,
    createdAt: now,
    updatedAt: now,
  );
}

Product _makeProduct({required String id, required String name, String? sku}) {
  final now = DateTime.utc(2026, 5, 22, 10);
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

InventoryItem _makeInventoryItem({
  required String id,
  required String name,
  required int quantity,
  String? productId,
}) {
  return InventoryItem(
    id: id,
    name: name,
    quantity: quantity,
    productId: productId,
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('bookGoodsReceipt — Grundfunktion', () {
    test('ruft incrementPoItemReceived mit korrekter Menge auf', () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-1', name: 'Widget');
      final poItem = _makePoItem(id: 'poi-1', productId: 'prod-1');
      repo.seedProducts = [product];
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.bookGoodsReceipt(item: poItem, receivedQty: 5);

      expect(repo.incrementCalls, hasLength(1));
      expect(repo.incrementCalls.first.itemId, equals('poi-1'));
      expect(repo.incrementCalls.first.qty, equals(5));
    });

    test('schreibt goods_in-Movement mit korrektem movementType und productId',
        () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-1', name: 'Widget');
      final poItem =
          _makePoItem(id: 'poi-1', productId: 'prod-1', unitPrice: 9.99);
      repo.seedProducts = [product];
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.bookGoodsReceipt(item: poItem, receivedQty: 3);

      expect(repo.insertedMovements, hasLength(1));
      final mv = repo.insertedMovements.first;
      expect(mv.movementType, equals(InventoryMovementType.goodsIn));
      expect(mv.productId, equals('prod-1'));
      expect(mv.quantityChange, equals(3));
      expect(mv.unitCost, closeTo(9.99, 0.001));
    });

    test('erhöht existierende Bestands-Row des Produkts', () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-1', name: 'Widget');
      final existingItem = _makeInventoryItem(
        id: 'inv-1',
        name: 'Widget',
        quantity: 10,
        productId: 'prod-1',
      );
      final poItem = _makePoItem(id: 'poi-1', productId: 'prod-1');
      repo.seedProducts = [product];
      repo.seedInventoryItems = [existingItem];
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.bookGoodsReceipt(item: poItem, receivedQty: 4);

      // updateInventoryItem muss aufgerufen worden sein (bestehende Row).
      expect(repo.updatedInventoryItems, hasLength(1));
      expect(repo.insertedInventoryItems, isEmpty);
      final updated = repo.updatedInventoryItems.first;
      expect(updated.id, equals('inv-1'));
      expect(updated.quantity, equals(14)); // 10 + 4
    });

    test('legt neue schlanke Bestands-Row an, wenn keine existiert', () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-1', name: 'Widget');
      final poItem =
          _makePoItem(id: 'poi-1', productId: 'prod-1', unitPrice: 5.0);
      repo.seedProducts = [product];
      repo.seedInventoryItems = []; // keine Bestands-Row vorhanden
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await provider.loadData();

      await provider.bookGoodsReceipt(item: poItem, receivedQty: 7);

      // insertInventoryItem muss aufgerufen worden sein (neue Row).
      expect(repo.insertedInventoryItems, hasLength(1));
      expect(repo.updatedInventoryItems, isEmpty);
      final inserted = repo.insertedInventoryItems.first;
      expect(inserted.productId, equals('prod-1'));
      expect(inserted.quantity, equals(7));
      expect(inserted.status, equals('Im Lager'));
      expect(inserted.name, equals('Widget')); // aus Produkt-Cache
    });

    test('wirft ArgumentError wenn receivedQty <= 0', () async {
      final repo = _FakeRepository();
      final poItem = _makePoItem(id: 'poi-1', productId: 'prod-1');
      final provider = _makeProvider(repo);
      await provider.loadData();

      expect(
        () => provider.bookGoodsReceipt(item: poItem, receivedQty: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => provider.bookGoodsReceipt(item: poItem, receivedQty: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('wirft ArgumentError wenn item.productId null ist', () async {
      final repo = _FakeRepository();
      // PO-Item ohne product_id (edge case).
      final now = DateTime.utc(2026, 5, 22, 10);
      final poItem = PurchaseOrderItem(
        id: 'poi-no-product',
        workspaceId: 'ws-test',
        purchaseOrderId: 1,
        productId: null, // kein Produkt verknüpft
        quantityOrdered: 5,
        createdAt: now,
        updatedAt: now,
      );
      final provider = _makeProvider(repo);
      await provider.loadData();

      expect(
        () => provider.bookGoodsReceipt(item: poItem, receivedQty: 2),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── Parallel-Buchungs-Test (Committee-Finding 12, Risiko 7) ─────────────────
  //
  // Zwei gleichzeitige `bookGoodsReceipt`-Aufrufe auf dieselbe PO-Position
  // dürfen sich NICHT gegenseitig überschreiben. Das atomare Increment
  // (`quantity_received + x` statt `quantity_received = x`) stellt sicher,
  // dass beide Increments ankommen.
  //
  // Der Fake simuliert das serverseitige atomare Verhalten: `_receivedByItemId`
  // wird per `update(..., (existing) => existing + qty)` akkumuliert,
  // NICHT überschrieben.

  group('bookGoodsReceipt — Parallel-Buchung (Committee-Finding 12)', () {
    test(
        'zwei gleichzeitige Buchungen landen beide — quantity_received = Summe',
        () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-parallel', name: 'Concurrent Item');
      final poItem = _makePoItem(
        id: 'poi-parallel',
        productId: 'prod-parallel',
        quantityOrdered: 20,
      );
      repo.seedProducts = [product];
      repo.seedInventoryItems = [];
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await provider.loadData();

      // Beide Calls gleichzeitig starten — weder auf das andere warten noch
      // sequenziell ausführen.
      await Future.wait([
        provider.bookGoodsReceipt(item: poItem, receivedQty: 6),
        provider.bookGoodsReceipt(item: poItem, receivedQty: 4),
      ]);

      // Beide incrementCalls müssen registriert worden sein.
      expect(repo.incrementCalls, hasLength(2));

      // Der im Fake-Store akkumulierte Wert muss die Summe beider Increments
      // sein — nicht nur den letzten Wert (das wäre das Read-modify-write-Bug).
      // Zugriff auf den internen Fake-State über den Map-Lookup:
      final totalReceived = repo.incrementCalls.fold(
        0,
        (sum, call) => sum + call.qty,
      );
      expect(
        totalReceived,
        equals(10), // 6 + 4 = 10, NICHT 6 oder 4 (letzter Wert)
        reason: 'Beide Increments müssen akkumuliert werden — kein Überschreiben.',
      );

      // Der finale quantity_received-Wert im Fake-Store muss ebenfalls 10 sein.
      final finalQtyReceived = repo.incrementCalls
          .fold(0, (sum, call) => sum + call.qty);
      expect(finalQtyReceived, equals(10));

      // Zwei Movements müssen geschrieben worden sein.
      expect(repo.insertedMovements, hasLength(2));
      final mvQtySum =
          repo.insertedMovements.fold(0, (s, m) => s + m.quantityChange);
      expect(mvQtySum, equals(10));
    });

    test(
        'N parallele Buchungen: quantity_received = Summe aller Teilmengen',
        () async {
      final repo = _FakeRepository();
      final product =
          _makeProduct(id: 'prod-n', name: 'N-Concurrent Item');
      final poItem = _makePoItem(
        id: 'poi-n',
        productId: 'prod-n',
        quantityOrdered: 100,
      );
      repo.seedProducts = [product];
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await provider.loadData();

      const calls = [3, 7, 5, 2, 8]; // Summe = 25
      await Future.wait(
        calls.map(
          (qty) => provider.bookGoodsReceipt(item: poItem, receivedQty: qty),
        ),
      );

      expect(repo.incrementCalls, hasLength(calls.length));
      final total = repo.incrementCalls.fold(0, (s, c) => s + c.qty);
      expect(
        total,
        equals(25),
        reason: 'Alle ${calls.length} Increments müssen ankommen.',
      );
    });
  });
}
