import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ───────────────────────────────────────────────────────────

/// Fake-Repository für Deal-Delete-Undo-Tests (A5).
/// Protokolliert `deleteDeal`-Aufrufe ohne echten Supabase-Aufruf.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  List<Deal> seedDeals = [];

  /// Protokoll der aufgerufenen `deleteDeal`-IDs.
  final List<int> deletedDealIds = [];

  /// Optionaler Completer, um `deleteDeal` auf Wunsch blockieren zu können
  /// (nicht in diesen Tests genutzt, aber hilfreich für Future-Erweiterungen).
  Completer<void>? deleteCompleter;

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: List.of(seedDeals),
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: const [],
        movements: const [],
        activities: const [],
      );

  @override
  Future<void> deleteDeal(int id) async {
    if (deleteCompleter != null) await deleteCompleter!.future;
    deletedDealIds.add(id);
  }

  // ── Stubs für loadData ────────────────────────────────────────────────────

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async => item;

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async => item;

  @override
  Future<void> deleteInventoryItem(String id) async {}

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async =>
      movement;
}

// ── Hilfsfunktion ─────────────────────────────────────────────────────────────

Deal _makeDeal({required int id, String product = 'Test-Deal'}) {
  return Deal(
    id: id,
    product: product,
    quantity: 1,
    isDropship: false,
    shop: 'Testshop',
    orderDate: DateTime(2026, 1, 1),
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

  // ── deleteDealWithUndo — Optimistic-Hide ─────────────────────────────────

  group('deleteDealWithUndo — Optimistic-Hide', () {
    test('Deal wird sofort aus dem deals-Getter gefiltert', () async {
      repo.seedDeals = [_makeDeal(id: 1)];
      await provider.loadData();
      expect(provider.deals, hasLength(1));

      provider.deleteDealWithUndo(1, delay: const Duration(seconds: 60));

      expect(provider.deals, isEmpty,
          reason: 'Deal muss sofort aus dem Getter verschwinden');
    });

    test('Deal bleibt im internen Cache erhalten (kein DB-Call sofort)', () async {
      repo.seedDeals = [_makeDeal(id: 2)];
      await provider.loadData();

      provider.deleteDealWithUndo(2, delay: const Duration(seconds: 60));

      // Kein deleteDeal-Aufruf darf stattgefunden haben
      expect(repo.deletedDealIds, isEmpty,
          reason: 'DB-Call darf NICHT sofort erfolgen');
    });

    test('notifyListeners wird bei Markierung ausgelöst', () async {
      repo.seedDeals = [_makeDeal(id: 3)];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      provider.deleteDealWithUndo(3, delay: const Duration(seconds: 60));

      expect(notified, isTrue);
    });

    test('mehrere Deals können gleichzeitig pending sein', () async {
      repo.seedDeals = [_makeDeal(id: 10), _makeDeal(id: 11), _makeDeal(id: 12)];
      await provider.loadData();

      provider.deleteDealWithUndo(10, delay: const Duration(seconds: 60));
      provider.deleteDealWithUndo(11, delay: const Duration(seconds: 60));

      // Deal 12 ist nicht pending
      expect(provider.deals, hasLength(1));
      expect(provider.deals.first.id, equals(12));
    });
  });

  // ── cancelPendingDelete — Undo ────────────────────────────────────────────

  group('cancelPendingDelete — Undo', () {
    test('Deal kommt nach Cancel wieder in die Liste zurück', () async {
      repo.seedDeals = [_makeDeal(id: 20)];
      await provider.loadData();

      provider.deleteDealWithUndo(20, delay: const Duration(seconds: 60));
      expect(provider.deals, isEmpty, reason: 'Vor Undo: Deal unsichtbar');

      provider.cancelPendingDelete(20);

      expect(provider.deals, hasLength(1),
          reason: 'Nach Undo: Deal wieder sichtbar');
      expect(provider.deals.first.id, equals(20));
    });

    test('kein DB-Call erfolgt nach Cancel', () async {
      repo.seedDeals = [_makeDeal(id: 21)];
      await provider.loadData();

      provider.deleteDealWithUndo(21, delay: const Duration(seconds: 60));
      provider.cancelPendingDelete(21);

      // Kurz warten — Timer sollte gecancelt sein
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.deletedDealIds, isEmpty,
          reason: 'Nach Undo darf KEIN DB-Call erfolgen');
    });

    test('notifyListeners wird bei Cancel ausgelöst', () async {
      repo.seedDeals = [_makeDeal(id: 22)];
      await provider.loadData();

      provider.deleteDealWithUndo(22, delay: const Duration(seconds: 60));

      var notified = false;
      provider.addListener(() => notified = true);

      provider.cancelPendingDelete(22);

      expect(notified, isTrue);
    });

    test('Cancel auf unbekannte ID: kein Fehler, State unverändert', () async {
      repo.seedDeals = [_makeDeal(id: 23)];
      await provider.loadData();

      // Kein Pending-Delete gesetzt für ID 999
      expect(() => provider.cancelPendingDelete(999), returnsNormally);
      expect(provider.deals, hasLength(1));
    });
  });

  // ── _commitPendingDelete — Timer-Ablauf → DB-Call ─────────────────────────

  group('Timer-Ablauf → DB-Call', () {
    test('deleteDeal wird im Repository gerufen nach Timer-Ablauf', () async {
      repo.seedDeals = [_makeDeal(id: 30)];
      await provider.loadData();

      // Sehr kurzer Delay für Tests
      provider.deleteDealWithUndo(30, delay: const Duration(milliseconds: 50));

      // Vor Timer-Ablauf: kein DB-Call
      expect(repo.deletedDealIds, isEmpty);

      // Timer ablaufen lassen
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repo.deletedDealIds, contains(30),
          reason: 'Nach Timer-Ablauf muss deleteDeal im Repo aufgerufen werden');
    });

    test('Deal wird nach DB-Commit endgültig aus Cache entfernt', () async {
      repo.seedDeals = [_makeDeal(id: 31)];
      await provider.loadData();

      provider.deleteDealWithUndo(31, delay: const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Deal ist aus dem internen Cache raus (Getter gibt sowieso leer zurück,
      // aber sicherheitshalber: kein Cancel nach Commit möglich ohne Effekt)
      provider.cancelPendingDelete(31); // sollte idempotent sein
      expect(provider.deals, isEmpty);
    });
  });

  // ── Doppel-Delete idempotent ──────────────────────────────────────────────

  group('Doppel-Delete idempotent', () {
    test('zweites deleteDealWithUndo auf gleicher ID: kein Fehler, Timer neu', () async {
      repo.seedDeals = [_makeDeal(id: 40)];
      await provider.loadData();

      // Erster Aufruf
      provider.deleteDealWithUndo(40, delay: const Duration(seconds: 60));
      expect(provider.deals, isEmpty);

      // Zweiter Aufruf (Doppel-Delete) — soll idempotent sein
      expect(
        () => provider.deleteDealWithUndo(40, delay: const Duration(seconds: 60)),
        returnsNormally,
      );

      // Immer noch pending, Deal weiterhin unsichtbar
      expect(provider.deals, isEmpty);
    });

    test('nach Doppel-Delete: Cancel bringt Deal zurück', () async {
      repo.seedDeals = [_makeDeal(id: 41)];
      await provider.loadData();

      provider.deleteDealWithUndo(41, delay: const Duration(seconds: 60));
      provider.deleteDealWithUndo(41, delay: const Duration(seconds: 60));

      provider.cancelPendingDelete(41);

      expect(provider.deals, hasLength(1),
          reason: 'Nach Cancel (trotz Doppel-Delete) soll Deal zurückkommen');
    });

    test('nach Doppel-Delete: nur ein DB-Call nach Timer-Ablauf', () async {
      repo.seedDeals = [_makeDeal(id: 42)];
      await provider.loadData();

      // Beide mit kurzem Delay
      provider.deleteDealWithUndo(42, delay: const Duration(milliseconds: 50));
      provider.deleteDealWithUndo(42, delay: const Duration(milliseconds: 50));

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Genau ein DB-Call (erster Timer wurde durch zweiten Aufruf gecancelt)
      expect(repo.deletedDealIds.where((id) => id == 42), hasLength(1),
          reason: 'Nur ein DB-Call, kein Doppel-Delete in DB');
    });
  });

  // ── Getter-Konsistenz ─────────────────────────────────────────────────────

  group('deals-Getter-Konsistenz', () {
    test('pending-delete Items werden korrekt herausgefiltert, andere bleiben', () async {
      repo.seedDeals = [
        _makeDeal(id: 50, product: 'Bleibe'),
        _makeDeal(id: 51, product: 'Gehe'),
        _makeDeal(id: 52, product: 'Bleibe auch'),
      ];
      await provider.loadData();

      provider.deleteDealWithUndo(51, delay: const Duration(seconds: 60));

      final visible = provider.deals.map((d) => d.id).toList();
      expect(visible, containsAll([50, 52]));
      expect(visible, isNot(contains(51)));
    });
  });
}
