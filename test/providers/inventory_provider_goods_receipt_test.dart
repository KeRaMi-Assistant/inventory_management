import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/models/purchase_order.dart';
import 'package:inventory_management/models/purchase_order_item.dart';
import 'package:inventory_management/providers/catalog_provider.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/providers/purchasing_provider.dart';
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

  /// Bekannte `inventory_items`-IDs im Fake-Store.
  /// Wird beim Insert/Update gepflegt.
  /// `insertMovement` wirft einen [StateError], wenn `itemId` nicht drin ist —
  /// simuliert so die echte FK-Constraint
  /// (`inventory_movements.item_id REFERENCES inventory_items(id)`).
  final Set<String> _knownInventoryItemIds = {};

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
  List<PurchaseOrder> seedPurchaseOrders = [];

  /// Optionale Überschreibung: wenn gesetzt, liefert `loadPurchaseOrderById`
  /// für die entsprechende PO-ID diesen Wert (simuliert den trigger-aktualisierten
  /// PO-Header, den der DB-Trigger nach einem Wareneingang schreibt).
  final Map<int, PurchaseOrder> _poRefetchResults = {};

  /// IDs aller POs, für die `loadPurchaseOrderById` aufgerufen wurde.
  final List<int> refetchedPoIds = [];

  /// Seed: legt fest, welchen PO-Header `loadPurchaseOrderById` für [poId]
  /// zurückliefert (simuliert den trigger-aktualisierten Status).
  void seedPoRefetch(int poId, PurchaseOrder po) {
    _poRefetchResults[poId] = po;
  }

  /// Initialisiert `quantity_received` für ein Item (Pre-Condition in Tests).
  void seedReceivedQty(String itemId, int qty) {
    _receivedByItemId[itemId] = qty;
  }

  // ── Snapshot ──

  @override
  Future<CloudSnapshot> loadAll() async {
    // Seed-IDs der Inventory-Items in den FK-Satz aufnehmen.
    for (final i in seedInventoryItems) {
      _knownInventoryItemIds.add(i.id);
    }
    return CloudSnapshot(
      deals: const [],
      buyers: const [],
      shops: const [],
      suppliers: const [],
      inventoryItems: List.of(seedInventoryItems),
      movements: const [],
      activities: const [],
      products: List.of(seedProducts),
      purchaseOrders: List.of(seedPurchaseOrders),
    );
  }

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

  /// Simuliert die Datenbank-FK-Constraint
  /// `inventory_movements.item_id REFERENCES public.inventory_items(id)`.
  ///
  /// Wirft [StateError] (analog zu HTTP 409 auf echter DB) wenn `itemId`
  /// keine bekannte `inventory_items`-ID ist — z.B. wenn fälschlicherweise
  /// eine `purchase_order_items`-ID übergeben wird.
  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async {
    if (!_knownInventoryItemIds.contains(movement.itemId)) {
      throw StateError(
        'FK-Verletzung (simuliert): inventory_movements.item_id="${movement.itemId}" '
        'ist keine bekannte inventory_items-ID. '
        'Bekannte IDs: ${_knownInventoryItemIds.toList()}',
      );
    }
    insertedMovements.add(movement);
    return movement;
  }

  // ── Inventory Items ──

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async {
    // Neue ID als bekannte inventory_items-ID registrieren, damit
    // nachfolgende Movement-Inserts diese ID als gültig akzeptieren.
    _knownInventoryItemIds.add(item.id);
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

  // ── PO-Header-Refetch (Stale-State-Fix) ──

  @override
  Future<PurchaseOrder?> loadPurchaseOrderById(
    String workspaceId,
    int id,
  ) async {
    refetchedPoIds.add(id);
    return _poRefetchResults[id];
  }
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

/// The [PurchasingProvider] injected into the most recently created
/// [InventoryProvider] via [_makeProvider]. After the split, the PO-header
/// cache lives in [PurchasingProvider]; `bookGoodsReceipt` refreshes it via
/// [PurchasingProvider.replacePurchaseOrderHeader]. Tests read PO state from
/// here. Each [_makeProvider] call resets it (tests are single-provider).
late PurchasingProvider _purchasing;

/// Creates an [InventoryProvider] wired to a [CatalogProvider] AND a
/// [PurchasingProvider] that all share the same [repo]. Use [_loadBoth] to
/// populate all three providers from the repo.
InventoryProvider _makeProvider(_FakeRepository repo) {
  final catalog = CatalogProvider(repository: repo);
  _purchasing = PurchasingProvider(repository: repo);
  return InventoryProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: _purchasing,
  );
}

/// Loads the [CatalogProvider] (products), the injected [PurchasingProvider]
/// (POs/suppliers) and [InventoryProvider] from the same repo. Because
/// [InventoryProvider] reads products via the injected [CatalogProvider] and
/// writes PO-header refreshes into the injected [PurchasingProvider], both
/// upstream providers must be loaded so the seeded data is visible during
/// [bookGoodsReceipt].
Future<void> _loadBoth(InventoryProvider provider, _FakeRepository repo) =>
    Future.wait([
      CatalogProvider(repository: repo).loadData().then((_) {
        // Re-inject a freshly loaded catalog so the provider's cross-domain
        // reads use the seeded products.
        provider.updateCatalogProvider(
          CatalogProvider(repository: repo)..loadData(),
        );
      }),
      _purchasing.loadData(),
      provider.loadData(),
    ]);

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

PurchaseOrder _makePurchaseOrder({
  required int id,
  PurchaseOrderStatus status = PurchaseOrderStatus.ordered,
}) {
  final now = DateTime.utc(2026, 5, 22, 10);
  return PurchaseOrder(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    orderNumber: 'PO-2026-000$id',
    status: status,
    createdAt: now,
    updatedAt: now,
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
      await _loadBoth(provider, repo);

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
      await _loadBoth(provider, repo);

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
      await _loadBoth(provider, repo);

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
      await _loadBoth(provider, repo);

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

    // ── FK-Regression-Test (Browser-Bug: itemId war PO-Item-ID statt inventory-ID) ──
    //
    // Vorher: `itemId: existingItemForProduct?.id ?? item.id` — bei fehlendem
    // Inventory-Eintrag wurde `item.id` (purchase_order_items-ID) verwendet.
    // Das verursacht eine FK-Verletzung (HTTP 409) auf echter DB, weil
    // `inventory_movements.item_id` auf `inventory_items(id)` referenziert.
    //
    // Jetzt: inventory_items-Row wird VOR dem Movement-INSERT angelegt/aufgelöst.
    // Das Movement bekommt immer die gültige inventory_items-ID.
    test(
        'FK-Constraint: Movement.itemId ist eine gültige inventory_items-ID — '
        'NICHT die purchase_order_items-ID (Regression: Browser-Bug goods-receipt-flow)',
        () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-fk', name: 'FK-Test-Produkt');
      // PO-Item mit ANDERER ID als das Produkt — soll NICHT als Movement.itemId landen.
      final poItem = _makePoItem(
        id: 'poi-fk-id', // purchase_order_items-ID — DARF NICHT in movement.itemId landen
        productId: 'prod-fk',
        unitPrice: 12.50,
      );
      repo.seedProducts = [product];
      repo.seedInventoryItems = []; // keine Bestands-Row → neuer Artikel
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await _loadBoth(provider, repo);

      // Würde mit altem Code StateError werfen (FK-Simulation),
      // weil 'poi-fk-id' keine inventory_items-ID ist.
      await provider.bookGoodsReceipt(item: poItem, receivedQty: 5);

      // Eine neue Bestands-Row muss angelegt worden sein.
      expect(repo.insertedInventoryItems, hasLength(1));
      final newInventoryId = repo.insertedInventoryItems.first.id;

      // Das Movement muss mit der ID der neu angelegten Inventory-Row arbeiten.
      expect(repo.insertedMovements, hasLength(1));
      final mv = repo.insertedMovements.first;
      expect(
        mv.itemId,
        equals(newInventoryId),
        reason: 'movement.itemId muss die inventory_items-ID sein, '
            'nicht die purchase_order_items-ID "poi-fk-id".',
      );
      expect(mv.itemId, isNot(equals('poi-fk-id')),
          reason: 'PO-Item-ID darf NIEMALS als movement.itemId verwendet werden.');
    });

    test(
        'FK-Constraint: Movement.itemId ist eine gültige inventory_items-ID — '
        'auch wenn existierende Bestands-Row vorhanden (Update-Pfad)',
        () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-fk2', name: 'FK-Update-Produkt');
      final existingItem = _makeInventoryItem(
        id: 'inv-fk2',
        name: 'FK-Update-Produkt',
        quantity: 20,
        productId: 'prod-fk2',
      );
      final poItem = _makePoItem(
        id: 'poi-fk2-id', // purchase_order_items-ID — DARF NICHT in movement.itemId
        productId: 'prod-fk2',
        unitPrice: 8.00,
      );
      repo.seedProducts = [product];
      repo.seedInventoryItems = [existingItem];
      repo.seedPurchaseOrderItems = [poItem];

      final provider = _makeProvider(repo);
      await _loadBoth(provider, repo);

      await provider.bookGoodsReceipt(item: poItem, receivedQty: 3);

      expect(repo.insertedMovements, hasLength(1));
      final mv = repo.insertedMovements.first;
      expect(
        mv.itemId,
        equals('inv-fk2'),
        reason: 'movement.itemId muss die existierende inventory_items-ID sein.',
      );
      expect(mv.itemId, isNot(equals('poi-fk2-id')));
    });

    test('wirft ArgumentError wenn receivedQty <= 0', () async {
      final repo = _FakeRepository();
      final poItem = _makePoItem(id: 'poi-1', productId: 'prod-1');
      final provider = _makeProvider(repo);
      await _loadBoth(provider, repo);

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
      await _loadBoth(provider, repo);

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
      await _loadBoth(provider, repo);

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
      await _loadBoth(provider, repo);

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

  // ── Stale-State-Fix: PO-Header-Refresh nach Wareneingang ────────────────────
  //
  // Browser-Test (Epic C) fand: nach `bookGoodsReceipt` zeigte die UI weiterhin
  // den alten `status` des PO-Headers (z. B. `ordered`), obwohl der DB-Trigger
  // `purchase_order_items_status_trg` den Status serverseitig auf `received`
  // gesetzt hatte. Erst ein App-Reload zog den korrekten Status.
  //
  // Fix: nach erfolgreichem `incrementPoItemReceived` wird der PO-Header via
  // `loadPurchaseOrderById` frisch aus der DB geladen und im `_purchaseOrders`-
  // Cache ersetzt. Dieser Test prüft, dass der Provider nach dem Buchen den
  // refresh-aktualisierten Status im State zeigt.

  group('bookGoodsReceipt — PO-Header-Refresh (Stale-State-Fix)', () {
    test(
        'lädt PO-Header neu nach Buchung und übernimmt trigger-aktualisierten Status',
        () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-refresh', name: 'Refresh-Test');

      // PO-Header initial mit Status `ordered` im lokalen Cache.
      final poHeader = _makePurchaseOrder(
        id: 1,
        status: PurchaseOrderStatus.ordered,
      );
      final poItem = _makePoItem(
        id: 'poi-refresh',
        productId: 'prod-refresh',
        quantityOrdered: 5,
      );

      repo.seedProducts = [product];
      repo.seedPurchaseOrders = [poHeader];
      repo.seedPurchaseOrderItems = [poItem];

      // Fake: DB-Trigger hat Status auf `received` gesetzt — das ist das Ergebnis,
      // das `loadPurchaseOrderById` nach dem Buchen zurückliefert.
      final refreshedPoHeader = _makePurchaseOrder(
        id: 1,
        status: PurchaseOrderStatus.received,
      );
      repo.seedPoRefetch(1, refreshedPoHeader);

      final provider = _makeProvider(repo);
      await _loadBoth(provider, repo);

      // Vor dem Buchen: Status ist `ordered` im PurchasingProvider-Cache.
      expect(
        _purchasing.purchaseOrders.first.status,
        equals(PurchaseOrderStatus.ordered),
      );

      await provider.bookGoodsReceipt(item: poItem, receivedQty: 5);

      // Nach dem Buchen: `loadPurchaseOrderById` muss aufgerufen worden sein.
      expect(repo.refetchedPoIds, contains(1));

      // Der PurchasingProvider-Cache-Status muss nun `received` zeigen
      // (trigger-Wert) — bookGoodsReceipt hat replacePurchaseOrderHeader auf
      // dem injizierten PurchasingProvider aufgerufen.
      expect(
        _purchasing.purchaseOrders.first.status,
        equals(PurchaseOrderStatus.received),
        reason: 'PO-Header-Status muss nach dem Buchungs-Re-Fetch aktuell sein '
            '(kein Stale-State bis zum nächsten App-Reload). '
            'bookGoodsReceipt schreibt via replacePurchaseOrderHeader in den '
            'PurchasingProvider.',
      );
    });

    test(
        'Buchungs-Erfolg bleibt bestehen, wenn PO-Header-Re-Fetch fehlschlägt',
        () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-nofetch', name: 'No-Fetch-Test');
      final poHeader =
          _makePurchaseOrder(id: 2, status: PurchaseOrderStatus.ordered);
      final poItem = _makePoItem(
        id: 'poi-nofetch',
        productId: 'prod-nofetch',
        quantityOrdered: 3,
      );

      repo.seedProducts = [product];
      repo.seedPurchaseOrders = [poHeader];
      repo.seedPurchaseOrderItems = [poItem];
      // Kein `seedPoRefetch` → `loadPurchaseOrderById` gibt `null` zurück.
      // Dies simuliert einen Re-Fetch-Fehler oder eine gelöschte PO.

      final provider = _makeProvider(repo);
      await _loadBoth(provider, repo);

      // Der Aufruf darf NICHT werfen — Re-Fetch-Fehler sind Best-Effort.
      final result = await provider.bookGoodsReceipt(
        item: poItem,
        receivedQty: 3,
      );

      // Das Increment muss trotzdem durchgegangen sein.
      expect(repo.incrementCalls, hasLength(1));
      expect(result.quantityReceived, equals(3));

      // Der PurchasingProvider-PO-Status bleibt auf dem alten Wert (kein Crash,
      // kein Rollback — UI korrigiert sich beim nächsten Load).
      expect(
        _purchasing.purchaseOrders.first.status,
        equals(PurchaseOrderStatus.ordered),
      );
    });

    test('kein Re-Fetch wenn item.purchaseOrderId null ist', () async {
      final repo = _FakeRepository();
      final product = _makeProduct(id: 'prod-nullpo', name: 'Null-PO-Test');
      final now = DateTime.utc(2026, 5, 22, 10);
      // PO-Item ohne purchaseOrderId (edge case).
      final poItemNullPoId = PurchaseOrderItem(
        id: 'poi-nullpo',
        workspaceId: 'ws-test',
        purchaseOrderId: null, // kein PO-Bezug
        productId: 'prod-nullpo',
        quantityOrdered: 2,
        createdAt: now,
        updatedAt: now,
      );

      repo.seedProducts = [product];
      repo.seedPurchaseOrderItems = [poItemNullPoId];

      final provider = _makeProvider(repo);
      await _loadBoth(provider, repo);

      // Kein Fehler, kein Re-Fetch-Versuch.
      await provider.bookGoodsReceipt(item: poItemNullPoId, receivedQty: 2);

      expect(repo.refetchedPoIds, isEmpty,
          reason: 'Kein Re-Fetch wenn purchaseOrderId null ist.');
      expect(repo.incrementCalls, hasLength(1));
    });
  });
}
