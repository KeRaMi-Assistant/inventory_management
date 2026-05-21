import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

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

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _FakeRepository repo;
  late InventoryProvider provider;

  setUp(() {
    repo = _FakeRepository();
    provider = InventoryProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  // ── addInventoryItem ──────────────────────────────────────────────────────

  group('addInventoryItem — movementType', () {
    test('addInventoryItem mit quantity > 0 erzeugt goodsIn-Movement', () async {
      final item = _makeItem(quantity: 5);
      await provider.addInventoryItem(item);

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.goodsIn),
      );
    });

    test('addInventoryItem mit quantity == 0 erzeugt kein Movement', () async {
      final item = _makeItem(quantity: 0);
      await provider.addInventoryItem(item);

      expect(repo.insertedMovements, isEmpty);
    });

    test('addInventoryItem: Movement-quantityChange == item.quantity', () async {
      final item = _makeItem(quantity: 7);
      await provider.addInventoryItem(item);

      expect(repo.insertedMovements.first.quantityChange, equals(7));
    });
  });

  // ── updateInventoryItem ───────────────────────────────────────────────────

  group('updateInventoryItem — movementType', () {
    /// Wir müssen das Item zunächst in den Provider-State laden, damit
    /// updateInventoryItem den "old"-Wert ermitteln kann. Dazu rufen wir
    /// addInventoryItem zuerst auf und leeren dann insertedMovements.
    Future<void> seed(InventoryItem item) async {
      await provider.addInventoryItem(item);
      repo.insertedMovements.clear();
    }

    test('delta > 0 → goodsIn-Movement', () async {
      final item = _makeItem(id: 'i1', quantity: 5);
      await seed(item);

      final updated = item.copyWith(quantity: 8); // delta = +3
      await provider.updateInventoryItem(updated);

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
      await provider.updateInventoryItem(updated);

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
      await provider.updateInventoryItem(updated);

      expect(repo.insertedMovements, isEmpty);
    });
  });

  // ── adjustStock ───────────────────────────────────────────────────────────

  group('adjustStock — movementType-Parameter wird durchgereicht', () {
    Future<void> seed(InventoryItem item) async {
      await provider.addInventoryItem(item);
      repo.insertedMovements.clear();
    }

    test('Default (kein movementType-Argument) → correction', () async {
      final item = _makeItem(id: 'j1', quantity: 5);
      await seed(item);

      await provider.adjustStock('j1', 2, 'Manuelle Korrektur');

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.correction),
      );
    });

    test('movementType: sale → sale wird durchgereicht', () async {
      final item = _makeItem(id: 'j2', quantity: 10);
      await seed(item);

      await provider.adjustStock(
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

      await provider.adjustStock(
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

      await provider.adjustStock('j4', 0, 'Keine Änderung');

      expect(repo.insertedMovements, isEmpty);
    });

    test('adjustStock mit unbekannter id erzeugt kein Movement', () async {
      // Provider hat das Item nicht im State → idx == -1 → kein Movement
      await provider.adjustStock('non-existent', 5, 'Irrtum');

      expect(repo.insertedMovements, isEmpty);
    });
  });

  // ── checkInDeal ───────────────────────────────────────────────────────────

  group('checkInDeal — movementType', () {
    test('checkInDeal erzeugt goodsIn-Movement', () async {
      final deal = _makeDeal(quantity: 4);
      await provider.checkInDeal(deal);

      expect(repo.insertedMovements, hasLength(1));
      expect(
        repo.insertedMovements.first.movementType,
        equals(InventoryMovementType.goodsIn),
      );
    });

    test('checkInDeal: Movement-quantityChange == deal.quantity', () async {
      final deal = _makeDeal(quantity: 7);
      await provider.checkInDeal(deal);

      expect(repo.insertedMovements.first.quantityChange, equals(7));
    });

    test('checkInDeal: unitCost entspricht deal.ekBrutto', () async {
      final deal = _makeDeal(ekBrutto: 19.99);
      await provider.checkInDeal(deal);

      expect(repo.insertedMovements.first.unitCost, equals(19.99));
    });

    test('checkInDeal mit ekBrutto == null → unitCost == null im Movement',
        () async {
      final deal = _makeDeal(ekBrutto: null);
      await provider.checkInDeal(deal);

      expect(repo.insertedMovements.first.unitCost, isNull);
    });
  });
}
