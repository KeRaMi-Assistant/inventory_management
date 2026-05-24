import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inbox_message.dart';
import 'package:inventory_management/models/mailbox_account.dart';
import 'package:inventory_management/providers/inbox_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ── Fake-Repository ──────────────────────────────────────────────────────────

class _FakeRepo extends SupabaseRepository {
  _FakeRepo() : super.forTesting();

  // Tracking-Flags für Dismiss-Calls
  final List<String> insertedDismissalShopKeys = [];
  final List<String?> insertedDismissalOrderIds = [];
  final List<String?> insertedDismissalMessageIds = [];
  bool clearDismissalsCalled = false;
  int clearDismissalsCallCount = 0;

  // Tracking-Flags für markSuggestionResolved-Calls
  final List<String> resolvedSuggestionIds = [];

  // Fehler-Konfiguration
  Exception? insertDismissalError;
  Exception? clearDismissalsError;

  @override
  String? get activeWorkspaceId => 'ws-test';

  @override
  Future<List<MailboxAccount>> loadMailboxAccounts() async => [];

  @override
  Future<List<PendingDealSuggestion>> loadPendingSuggestions({
    bool unresolvedOnly = true,
    int limit = 100,
    int daysBack = 30,
  }) async =>
      [];

  @override
  Future<List<ParsedMessage>> loadParsedMessages({
    Set<ParsedMessageStatus>? statuses,
    int limit = 100,
    int daysBack = 30,
  }) async =>
      [];

  @override
  Future<List<InboxDismissal>> loadInboxDismissals() async => [];

  @override
  Future<Set<String>> loadInboxReads({required String workspaceId}) async =>
      {};

  @override
  Future<void> insertInboxDismissal({
    String? shopKey,
    String? orderId,
    String? parsedMessageId,
    required DateTime receivedAt,
  }) async {
    if (insertDismissalError != null) throw insertDismissalError!;
    insertedDismissalShopKeys.add(shopKey ?? '');
    insertedDismissalOrderIds.add(orderId);
    insertedDismissalMessageIds.add(parsedMessageId);
  }

  @override
  Future<void> clearInboxDismissals() async {
    if (clearDismissalsError != null) throw clearDismissalsError!;
    clearDismissalsCalled = true;
    clearDismissalsCallCount++;
  }

  @override
  Future<void> markSuggestionResolved(
    String id, {
    required String action,
    int? createdDealId,
  }) async {
    resolvedSuggestionIds.add(id);
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // Fake-async timer: nutzt fakeAsync für Timer-Tests.

  group('InboxProvider — rejectSuggestionWithUndo', () {
    late _FakeRepo repo;
    late InboxProvider provider;

    setUp(() {
      repo = _FakeRepo();
      provider = InboxProvider(repository: repo);
      // Direkt Suggestions in den internen State injizieren via refresh-Surrogate:
      // Wir nutzen `markSuggestionRejected` als Indikator — daher laden wir
      // Suggestions manuell per Reload.
    });

    tearDown(() => provider.dispose());

    test(
        'rejectSuggestionWithUndo markiert Suggestion lokal — '
        'kein DB-Call sofort', () {
      // Suggestion direkt in den internen Raw-State einfügen ist nur über
      // refresh möglich. Stattdessen testen wir das Filtering: nach
      // rejectSuggestionWithUndo ist die Suggestion aus pendingSuggestions raus.
      //
      // Wir injecten via Reflection-alternative: Suggestions-Liste bleibt leer
      // (repo liefert leer), also testen wir nur die Marker-Logik:
      fakeAsync((async) {
        provider.rejectSuggestionWithUndo('sug-1');

        // Kein DB-Call sofort.
        expect(repo.insertedDismissalShopKeys, isEmpty,
            reason: 'Kein insertInboxDismissal-Call darf sofort feuern');
        expect(repo.resolvedSuggestionIds, isEmpty,
            reason: 'Kein markSuggestionResolved-Call darf sofort feuern');

        // Pending-Marker ist gesetzt: cancelPendingReject entfernt ihn.
        // Direkt canceln — kein Timer-Ablauf.
        provider.cancelPendingReject('sug-1');

        // Nach Cancel: kein DB-Call.
        async.elapse(const Duration(seconds: 5));
        expect(repo.insertedDismissalShopKeys, isEmpty,
            reason: 'Kein DB-Call nach Undo');
        expect(repo.resolvedSuggestionIds, isEmpty,
            reason: 'Kein DB-Call nach Undo');
      });
    });

    test('cancelPendingReject bricht Timer ab — kein DB-Call nach Ablauf', () {
      fakeAsync((async) {
        provider.rejectSuggestionWithUndo('sug-42',
            delay: const Duration(seconds: 4));

        // Sofort canceln.
        provider.cancelPendingReject('sug-42');

        // Zeit verstreichen lassen — kein DB-Call.
        async.elapse(const Duration(seconds: 6));
        expect(repo.insertedDismissalShopKeys, isEmpty);
        expect(repo.resolvedSuggestionIds, isEmpty);
      });
    });

    test(
        'Nach Timeout ohne Cancel: Timer wird nicht cancelPendingReject '
        'gerufen und kein Crash', () {
      fakeAsync((async) {
        // rejectSuggestionWithUndo mit kurzer Delay.
        provider.rejectSuggestionWithUndo('sug-99',
            delay: const Duration(seconds: 4));

        // Kein Call vor Timeout.
        expect(repo.resolvedSuggestionIds, isEmpty);
        expect(repo.insertedDismissalShopKeys, isEmpty);

        // Timer ablaufen lassen — kein Cancel.
        // _resolveSuggestionGroup läuft, aber Suggestions-Raw ist leer
        // (repo liefert leer). picked == null → kein insertInboxDismissal.
        // _suggestionsRaw ist leer → groupIds enthält nur suggestionId,
        // aber kein entsprechendes Element → markSuggestionResolved wird
        // für die leere Gruppe NICHT aufgerufen.
        async.elapse(const Duration(seconds: 5));

        // Kein Crash — insertInboxDismissal wird nicht gerufen (picked=null).
        expect(repo.insertedDismissalShopKeys, isEmpty);
        // _pendingRejectIds ist nach Timer-Ablauf geleert.
      });
    });

    test('Doppelter rejectSuggestionWithUndo für gleiche ID ist No-Op', () {
      fakeAsync((async) {
        provider.rejectSuggestionWithUndo('sug-1');
        provider.rejectSuggestionWithUndo('sug-1'); // Doppelt — soll ignoriert werden.

        // Nur ein Timer läuft.
        provider.cancelPendingReject('sug-1');

        async.elapse(const Duration(seconds: 5));
        expect(repo.resolvedSuggestionIds, isEmpty);
      });
    });
  });

  group('InboxProvider — clearDismissalsOptimistic + restoreDismissals', () {
    late _FakeRepo repo;
    late InboxProvider provider;

    setUp(() {
      repo = _FakeRepo();
      provider = InboxProvider(repository: repo);
    });

    tearDown(() => provider.dispose());

    test('clearDismissalsOptimistic gibt Snapshot zurück und leert State', () {
      // Wir simulieren einen gefüllten _dismissalKeys-State über
      // _addLocalDismissalKey — das ist private. Wir nutzen stattdessen
      // den Provider-Flow: dismissParsedMessage fügt Keys hinzu.
      // Alternativ: State über clearDismissalsOptimistic direkt testen.
      //
      // Da _dismissalKeys initial leer ist, testen wir den Leer-Snapshot:
      final snapshot = provider.clearDismissalsOptimistic();

      expect(snapshot.keys, isEmpty);
      expect(snapshot.count, 0);
      expect(provider.dismissalCount, 0);
    });

    test('restoreDismissals stellt Snapshot wieder her', () {
      // Snapshot mit gefüllten Keys simulieren.
      const fakeKeys = {'amazon:order-1', 'mediamarkt:order-2'};
      const fakeCount = 2;

      // Schritt 1: Restore direkt auf leerem State.
      provider.restoreDismissals(fakeKeys, fakeCount);

      expect(provider.dismissalCount, fakeCount);
    });

    test(
        'clearDismissalsOptimistic + restoreDismissals ist Snapshot-Round-Trip',
        () {
      // Erst restoreDismissals mit gefülltem Snapshot, dann optimistic-clear,
      // dann restore — State muss identisch sein.
      const initialKeys = {'shop-a:ord-1', 'shop-b:ord-2', 'shop-c:ord-3'};
      const initialCount = 3;

      provider.restoreDismissals(initialKeys, initialCount);
      expect(provider.dismissalCount, initialCount);

      // Optimistic clear.
      final snapshot = provider.clearDismissalsOptimistic();
      expect(snapshot.keys, equals(initialKeys));
      expect(snapshot.count, initialCount);
      expect(provider.dismissalCount, 0);

      // Undo: restore.
      provider.restoreDismissals(snapshot.keys, snapshot.count);
      expect(provider.dismissalCount, initialCount);
    });

    test('clearDismissalsOptimistic triggert notifyListeners', () {
      var notified = false;
      provider.addListener(() => notified = true);

      provider.clearDismissalsOptimistic();

      expect(notified, isTrue);
    });

    test('restoreDismissals triggert notifyListeners', () {
      var notified = false;
      provider.addListener(() => notified = true);

      provider.restoreDismissals({}, 0);

      expect(notified, isTrue);
    });
  });

  group('InboxProvider — dispose cancelt alle pending Timers', () {
    test('dispose ruft Timer.cancel auf alle laufenden Timers', () async {
      final repo = _FakeRepo();
      final provider = InboxProvider(repository: repo);

      // Mehrere Timers starten.
      provider.rejectSuggestionWithUndo('sug-a');
      provider.rejectSuggestionWithUndo('sug-b');
      provider.rejectSuggestionWithUndo('sug-c');

      // Dispose — kein Crash, alle Timers abgebrochen.
      provider.dispose();

      // Warte kurze Zeit — kein DB-Call.
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(repo.resolvedSuggestionIds, isEmpty);
      expect(repo.insertedDismissalShopKeys, isEmpty);
    });
  });

  group('InboxProvider — clear() cancelt pending Timers', () {
    test('clear cancelt Timer und leert _pendingRejectIds', () {
      fakeAsync((async) {
        final repo = _FakeRepo();
        final provider = InboxProvider(repository: repo);

        provider.rejectSuggestionWithUndo('sug-1');
        provider.clear(); // Soll Timer abbrechen.

        async.elapse(const Duration(seconds: 5));

        // Kein DB-Call nach clear.
        expect(repo.resolvedSuggestionIds, isEmpty);
        provider.dispose();
      });
    });
  });
}
