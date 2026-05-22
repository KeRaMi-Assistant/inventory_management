import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/purchase_order.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Minimale Fake-Implementierung für PO-CRUD-Tests (Task C3 / C7).
///
/// Protokolliert alle `insertPurchaseOrder` / `updatePurchaseOrder` /
/// `deletePurchaseOrder`-Aufrufe und simuliert das Verhalten des echten
/// Repositories:
/// - Insert vergibt einen BIGSERIAL-int-PK (aufsteigend ab 1).
/// - Update gibt das übergebene Objekt mit aktuellem `updatedAt` zurück.
/// - Delete protokolliert die gelöschte id.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  // ── interne Stores ──

  int _nextId = 1;

  final List<PurchaseOrder> insertedOrders = [];
  final List<PurchaseOrder> updatedOrders = [];
  final List<int> deletedOrderIds = [];

  /// Seed-Bestellungen, die [loadAll] zurückgibt.
  List<PurchaseOrder> seedOrders = [];

  // ── Snapshot ──

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: const [],
        movements: const [],
        activities: const [],
        purchaseOrders: List.of(seedOrders),
      );

  // ── Stubs für andere von `loadData` benötigte Methoden ──

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async => item;

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async => item;

  @override
  Future<void> deleteInventoryItem(String id) async {}

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async =>
      movement;

  // ── PO-CRUD ──

  @override
  Future<PurchaseOrder> insertPurchaseOrder(PurchaseOrder order) async {
    final id = _nextId++;
    final now = DateTime.utc(2026, 5, 20, 12, 0, 0);
    final saved = PurchaseOrder(
      id: id,
      workspaceId: activeWorkspaceId ?? 'ws-test',
      userId: 'user-test',
      supplierId: order.supplierId,
      orderNumber: order.orderNumber,
      status: order.status,
      orderDate: order.orderDate,
      expectedDate: order.expectedDate,
      note: order.note,
      totalNet: order.totalNet,
      createdAt: order.createdAt,
      updatedAt: now,
    );
    insertedOrders.add(saved);
    return saved;
  }

  @override
  Future<PurchaseOrder> updatePurchaseOrder(PurchaseOrder order) async {
    final now = DateTime.utc(2026, 5, 20, 13, 0, 0);
    final saved = order.copyWith(updatedAt: now);
    updatedOrders.add(saved);
    return saved;
  }

  @override
  Future<void> deletePurchaseOrder(int id) async {
    deletedOrderIds.add(id);
  }
}

// ── Hilfsfunktion ─────────────────────────────────────────────────────────────

PurchaseOrder _makePo({
  int? id,
  String orderNumber = 'PO-2026-0001',
  PurchaseOrderStatus status = PurchaseOrderStatus.draft,
  String? supplierId,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.utc(2026, 5, 20, 10, 0, 0);
  return PurchaseOrder(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    supplierId: supplierId,
    orderNumber: orderNumber,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeRepository repo;
  late InventoryProvider provider;

  setUp(() {
    repo = _FakeRepository();
    provider = InventoryProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  // ── addPurchaseOrder ──────────────────────────────────────────────────────

  group('addPurchaseOrder', () {
    test('ruft insertPurchaseOrder auf und speichert im State', () async {
      final po = _makePo(orderNumber: 'PO-2026-0001');

      await provider.addPurchaseOrder(po);

      expect(repo.insertedOrders, hasLength(1));
      expect(provider.purchaseOrders, hasLength(1));
      expect(provider.purchaseOrders.first.orderNumber, equals('PO-2026-0001'));
    });

    test('gespeicherte Bestellung hat vom Repository vergebene id', () async {
      final po = _makePo(orderNumber: 'PO-2026-0002');

      final saved = await provider.addPurchaseOrder(po);

      // Fake-Repository vergibt id = 1 (erster Insert)
      expect(saved.id, equals(1));
      expect(provider.purchaseOrders.first.id, equals(1));
    });

    test('gibt die vom Repository zurückgegebene Bestellung zurück', () async {
      final po = _makePo(orderNumber: 'PO-2026-0003', supplierId: 'sup-uuid');

      final saved = await provider.addPurchaseOrder(po);

      expect(saved.supplierId, equals('sup-uuid'));
      expect(saved.workspaceId, equals('ws-test'));
    });

    test('neue Bestellung wird an Position 0 eingefügt', () async {
      repo.seedOrders = [
        _makePo(id: 99, orderNumber: 'PO-2026-0000'),
      ];
      await provider.loadData();

      await provider.addPurchaseOrder(_makePo(orderNumber: 'PO-2026-0001'));

      // Neue Bestellung landet vorne (insert(0, ...))
      expect(provider.purchaseOrders.first.orderNumber, equals('PO-2026-0001'));
    });

    test('mehrere addPurchaseOrder → Repository erhält jeden Aufruf', () async {
      await provider.addPurchaseOrder(_makePo(orderNumber: 'PO-A'));
      await provider.addPurchaseOrder(_makePo(orderNumber: 'PO-B'));
      await provider.addPurchaseOrder(_makePo(orderNumber: 'PO-C'));

      expect(repo.insertedOrders, hasLength(3));
      expect(provider.purchaseOrders, hasLength(3));
    });

    test('ruft notifyListeners auf', () async {
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.addPurchaseOrder(_makePo(orderNumber: 'PO-NL'));

      expect(notified, isTrue);
    });
  });

  // ── updatePurchaseOrder ───────────────────────────────────────────────────

  group('updatePurchaseOrder', () {
    test('aktualisiert bestehende Bestellung im State', () async {
      repo.seedOrders = [
        _makePo(id: 1, orderNumber: 'PO-Alt', status: PurchaseOrderStatus.draft),
      ];
      await provider.loadData();

      final updated = _makePo(
        id: 1,
        orderNumber: 'PO-Alt',
        status: PurchaseOrderStatus.ordered,
      );
      await provider.updatePurchaseOrder(updated);

      expect(repo.updatedOrders, hasLength(1));
      final statePo = provider.purchaseOrders.where((po) => po.id == 1).first;
      expect(statePo.status, equals(PurchaseOrderStatus.ordered));
    });

    test('ruft updatePurchaseOrder im Repository auf', () async {
      repo.seedOrders = [_makePo(id: 2, orderNumber: 'PO-2026-0002')];
      await provider.loadData();

      final updated = _makePo(id: 2, orderNumber: 'PO-2026-0002-UPD');
      await provider.updatePurchaseOrder(updated);

      expect(repo.updatedOrders, hasLength(1));
      expect(repo.updatedOrders.first.id, equals(2));
    });

    test('nach Update bleibt State nach createdAt absteigend sortiert',
        () async {
      final older = _makePo(
        id: 1,
        orderNumber: 'PO-ALT',
        createdAt: DateTime.utc(2026, 5, 10),
      );
      final newer = _makePo(
        id: 2,
        orderNumber: 'PO-NEU',
        createdAt: DateTime.utc(2026, 5, 15),
      );
      repo.seedOrders = [older, newer];
      await provider.loadData();

      // Update der älteren Bestellung
      await provider.updatePurchaseOrder(
        older.copyWith(status: PurchaseOrderStatus.ordered),
      );

      // neuere (id=2) steht noch vorne
      expect(provider.purchaseOrders.first.id, equals(2));
      expect(provider.purchaseOrders.last.id, equals(1));
    });

    test('mit unbekannter id → State unverändert, kein notifyListeners',
        () async {
      repo.seedOrders = [_makePo(id: 5, orderNumber: 'PO-Existiert')];
      await provider.loadData();
      final countBefore = provider.purchaseOrders.length;

      var notified = false;
      provider.addListener(() => notified = true);

      // id=9999 existiert nicht im State
      await provider.updatePurchaseOrder(
        _makePo(id: 9999, orderNumber: 'PO-Ghost'),
      );

      // State unverändert — 'PO-Existiert' bleibt
      expect(provider.purchaseOrders.length, equals(countBefore));
      expect(provider.purchaseOrders.first.id, equals(5));
      // updatePurchaseOrder gibt nach idx == -1 return zurück → kein notify
      expect(notified, isFalse);
    });

    test('ruft notifyListeners auf', () async {
      repo.seedOrders = [_makePo(id: 3, orderNumber: 'PO-NL')];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.updatePurchaseOrder(
        _makePo(id: 3, orderNumber: 'PO-NL-UPD'),
      );

      expect(notified, isTrue);
    });
  });

  // ── deletePurchaseOrder ───────────────────────────────────────────────────

  group('deletePurchaseOrder', () {
    test('entfernt Bestellung aus dem State', () async {
      repo.seedOrders = [_makePo(id: 10, orderNumber: 'PO-Del')];
      await provider.loadData();

      await provider.deletePurchaseOrder(10);

      expect(provider.purchaseOrders, isEmpty);
      expect(repo.deletedOrderIds, contains(10));
    });

    test('verbleibende Bestellungen bleiben im State', () async {
      repo.seedOrders = [
        _makePo(id: 11, orderNumber: 'PO-Keep'),
        _makePo(id: 12, orderNumber: 'PO-Del'),
      ];
      await provider.loadData();

      await provider.deletePurchaseOrder(12);

      expect(provider.purchaseOrders, hasLength(1));
      expect(provider.purchaseOrders.first.id, equals(11));
    });

    test('ruft deletePurchaseOrder im Repository auf', () async {
      repo.seedOrders = [_makePo(id: 20, orderNumber: 'PO-Repo')];
      await provider.loadData();

      await provider.deletePurchaseOrder(20);

      expect(repo.deletedOrderIds, contains(20));
    });

    test('mit unbekannter id: kein Fehler, State unverändert', () async {
      repo.seedOrders = [_makePo(id: 30, orderNumber: 'PO-Noch-Da')];
      await provider.loadData();

      // Kein Throw erwartet
      await expectLater(
        provider.deletePurchaseOrder(9999),
        completes,
      );

      expect(provider.purchaseOrders, hasLength(1));
      expect(provider.purchaseOrders.first.id, equals(30));
    });

    test('ruft notifyListeners auf', () async {
      repo.seedOrders = [_makePo(id: 40, orderNumber: 'PO-Notify')];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.deletePurchaseOrder(40);

      expect(notified, isTrue);
    });

    test('mit unbekannter id: notifyListeners wird trotzdem aufgerufen',
        () async {
      // deletePurchaseOrder ruft nach removeWhere immer notifyListeners() —
      // auch wenn die id nicht im State war (kein early-return wie update).
      repo.seedOrders = [_makePo(id: 50, orderNumber: 'PO-Base')];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.deletePurchaseOrder(9999);

      expect(notified, isTrue);
    });
  });
}
