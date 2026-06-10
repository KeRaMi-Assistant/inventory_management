import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/activity_entry.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product_stock.dart';
import 'package:inventory_management/models/warehouse.dart';
import 'package:inventory_management/providers/catalog_provider.dart';
import 'package:inventory_management/providers/purchasing_provider.dart';
import 'package:inventory_management/providers/stock_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ───────────────────────────────────────────────────────────
//
// Workspace-Switch-Regression-Guard (PR #128):
//
// Bug: StockProvider.setActiveWorkspace ruft _repository.setActiveWorkspace
// VOR loadData. Ohne dieses Set liefert loadAll() einen NULL-Workspace-
// Snapshot (leer) — die Items/Warehouses des neuen Workspaces werden silent
// verworfen.
//
// Dieser Test stellt sicher, dass das _repository.setActiveWorkspace korrekt
// vor dem loadAll-Call gesetzt ist, sodass der workspace-konditionelle Snapshot
// die richtigen Daten für den aktiven Workspace liefert.
//
// HINWEIS: activeWorkspaceId wird NICHT überschrieben — die Basisklasse pflegt
// _workspaceId via setActiveWorkspace, und activeWorkspaceId liefert diesen Wert
// zurück. So reflektiert der Fake den per setActiveWorkspace gesetzten Wert.
// Würde man activeWorkspaceId hart auf 'ws-a' überschreiben, würde der Test
// die PR-#128-Regression nicht mehr fangen — weil loadAll immer ws-a-Daten
// liefern würde, unabhängig davon ob setActiveWorkspace korrekt aufgerufen wurde.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  // activeWorkspaceId wird absichtlich NICHT überschrieben:
  // Die Basisklasse führt _workspaceId über setActiveWorkspace und
  // liefert ihn über den activeWorkspaceId-Getter zurück.
  // Das ist die korrekte Testbedingung — der Fake beobachtet, welchen
  // Workspace der Provider gesetzt hat.

  // ── Seed für ws-a ─────────────────────────────────────────────────────────
  final List<InventoryItem> _seedItemsA = [];
  final List<Warehouse> _seedWarehousesA = [];

  void addItemForWsA(InventoryItem item) => _seedItemsA.add(item);
  void addWarehouseForWsA(Warehouse warehouse) => _seedWarehousesA.add(warehouse);

  @override
  Future<CloudSnapshot> loadAll() async {
    // Workspace-konditional: nur ws-a hat Seed-Daten.
    // Für alle anderen Workspace-IDs (null, 'ws-b', etc.) → leerer Snapshot.
    // Dieser bedingte Snapshot simuliert das echte Supabase-Verhalten:
    // eq('workspace_id', ws) liefert nur Rows des aktiven Workspaces.
    if (activeWorkspaceId == 'ws-a') {
      return CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: List.of(_seedItemsA),
        movements: const [],
        activities: const [],
        warehouses: List.of(_seedWarehousesA),
      );
    }
    // Alle anderen Workspaces (ws-b, null, …) → leer.
    return const CloudSnapshot(
      deals: [],
      buyers: [],
      shops: [],
      suppliers: [],
      inventoryItems: [],
      movements: [],
      activities: [],
    );
  }

  @override
  Future<List<ProductStock>> loadProductStock(String workspaceId) async => [];

  @override
  Future<Warehouse> insertWarehouse(Warehouse warehouse) async {
    // Fallback für Bootstrap (legt Hauptlager an wenn warehouses leer).
    final now = DateTime.utc(2026, 6, 10, 10);
    return Warehouse(
      id: 'wh-bootstrap-${warehouse.name.toLowerCase()}',
      workspaceId: activeWorkspaceId ?? warehouse.workspaceId,
      userId: 'user-test',
      name: warehouse.name,
      isDefault: warehouse.isDefault,
      isActive: warehouse.isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ActivityEntry> insertActivity(ActivityEntry entry) async => entry;
}

// ── Hilfsfunktionen ───────────────────────────────────────────────────────────

StockProvider _makeProvider(_FakeRepository repo) {
  final catalog = CatalogProvider(repository: repo);
  final purchasing = PurchasingProvider(repository: repo);
  return StockProvider(
    repository: repo,
    catalogProvider: catalog,
    purchasingProvider: purchasing,
  );
}

InventoryItem _makeItem({required String id, required String name}) {
  return InventoryItem(id: id, name: name, quantity: 5);
}

Warehouse _makeWarehouse({required String id, required String name}) {
  final now = DateTime.utc(2026, 6, 10, 10);
  return Warehouse(
    id: id,
    workspaceId: 'ws-a',
    userId: 'user-test',
    name: name,
    isDefault: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── PR-#128-Regression-Guard: setActiveWorkspace setzt Repo-Workspace VOR loadData ──
  //
  // Ohne `_repository.setActiveWorkspace(workspaceId)` in StockProvider.setActiveWorkspace
  // würde loadAll() mit activeWorkspaceId == null aufgerufen und einen leeren
  // Snapshot liefern. Der Bug wäre silent — kein Fehler, nur leere Listen.
  //
  // Dieser Test fängt diesen Pfad ab, indem der Fake-Repo workspace-konditional
  // Daten liefert: nur wenn activeWorkspaceId == 'ws-a' werden Items/Warehouses
  // zurückgegeben. Für ws-b oder null bleibt alles leer.

  group('StockProvider — Workspace-Switch (PR-#128-Regression-Guard)', () {
    test(
        'setActiveWorkspace("ws-a"): Items und Warehouses werden geladen '
        '(repo.setActiveWorkspace wird VOR loadAll aufgerufen)', () async {
      final repo = _FakeRepository();
      repo.addItemForWsA(_makeItem(id: 'item-a-1', name: 'Artikel Alpha'));
      repo.addItemForWsA(_makeItem(id: 'item-a-2', name: 'Artikel Beta'));
      repo.addWarehouseForWsA(_makeWarehouse(id: 'wh-a-1', name: 'Lager A'));

      final stock = _makeProvider(repo);

      await stock.setActiveWorkspace('ws-a');

      // PR-#128-Check: wenn setActiveWorkspace _repository.setActiveWorkspace
      // NICHT aufgerufen hätte, würde loadAll()'s if (activeWorkspaceId == 'ws-a')
      // nicht matchen und beide Listen wären leer.
      expect(
        stock.inventoryItems,
        isNotEmpty,
        reason: 'Items müssen nach setActiveWorkspace("ws-a") geladen sein. '
            'Wenn leer: setActiveWorkspace hat _repository.setActiveWorkspace '
            'nicht vor loadData aufgerufen (PR-#128-Bug).',
      );
      expect(
        stock.inventoryItems.length,
        equals(2),
        reason: 'Genau 2 Items wurden für ws-a ge-seeded.',
      );
      expect(
        stock.warehouses,
        isNotEmpty,
        reason: 'Warehouses müssen nach setActiveWorkspace("ws-a") geladen sein.',
      );
    });

    test(
        'setActiveWorkspace("ws-b"): leere Listen (kein Seed für ws-b)',
        () async {
      final repo = _FakeRepository();
      repo.addItemForWsA(_makeItem(id: 'item-a-1', name: 'Artikel Alpha'));
      repo.addWarehouseForWsA(_makeWarehouse(id: 'wh-a-1', name: 'Lager A'));

      final stock = _makeProvider(repo);

      await stock.setActiveWorkspace('ws-b');

      // ws-b hat keinen Seed → beide Listen sind leer.
      // Bootstrap-Warehouse wird angelegt (da warehouses leer + wsId != null),
      // daher prüfen wir hier nur inventoryItems auf leer.
      expect(
        stock.inventoryItems,
        isEmpty,
        reason: 'ws-b hat keinen Item-Seed — inventoryItems muss leer sein.',
      );
    });

    test(
        'Workspace-Wechsel ws-a → ws-b → ws-a: '
        'Items landen konsistent im richtigen Workspace', () async {
      final repo = _FakeRepository();
      repo.addItemForWsA(_makeItem(id: 'item-a-1', name: 'Artikel Alpha'));
      repo.addItemForWsA(_makeItem(id: 'item-a-2', name: 'Artikel Beta'));
      repo.addWarehouseForWsA(
          _makeWarehouse(id: 'wh-a-1', name: 'Hauptlager'));

      final stock = _makeProvider(repo);

      // 1. ws-a laden → Items vorhanden.
      await stock.setActiveWorkspace('ws-a');
      expect(
        stock.inventoryItems,
        isNotEmpty,
        reason: 'Nach erstem ws-a-Load müssen Items vorhanden sein.',
      );
      final countAfterWsA = stock.inventoryItems.length;
      expect(countAfterWsA, equals(2));

      // 2. ws-b laden → Items leer (kein Seed für ws-b).
      await stock.setActiveWorkspace('ws-b');
      expect(
        stock.inventoryItems,
        isEmpty,
        reason: 'Nach Wechsel auf ws-b müssen Items leer sein '
            '(ws-b hat keinen Seed).',
      );

      // 3. Zurück zu ws-a → Items wieder vorhanden.
      await stock.setActiveWorkspace('ws-a');
      expect(
        stock.inventoryItems,
        isNotEmpty,
        reason: 'Nach Rückkehr zu ws-a müssen Items wieder sichtbar sein.',
      );
      expect(
        stock.inventoryItems.length,
        equals(countAfterWsA),
        reason: 'Item-Anzahl nach Rückkehr muss identisch mit erstem ws-a-Load sein.',
      );
    });

    // Dokumentierter Negativ-Pfad (nicht implementiert, nur als Kommentar):
    //
    // Würde der Fake activeWorkspaceId HART überschreiben (z.B. auf 'ws-a'),
    // dann würde loadAll() immer 'ws-a' sehen — unabhängig davon ob der Provider
    // setActiveWorkspace korrekt aufgerufen hat. In diesem Fall würde der Test
    // immer grün, selbst wenn der PR-#128-Bug vorhanden wäre. Deshalb ist
    // activeWorkspaceId im Fake NICHT überschrieben.
  });
}
