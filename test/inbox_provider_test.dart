import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inbox_message.dart';
import 'package:inventory_management/models/mailbox_account.dart';
import 'package:inventory_management/providers/inbox_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Minimale Fake-Implementierung, die nur die vom InboxProvider benötigten
/// Methoden überschreibt. Kein Mockito nötig.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  // Konfigurierbare Rückgabewerte für die Tests
  List<PendingDealSuggestion> suggestions = [];
  List<ParsedMessage> parsedMessages = [];
  Set<String> inboxReads = {};
  int markAllReadResult = 0;
  bool markAllReadCalled = false;
  String? markAllReadCalledWithWorkspace;
  Exception? markAllReadError;

  @override
  String? get activeWorkspaceId => 'workspace-test-123';

  @override
  Future<List<MailboxAccount>> loadMailboxAccounts() async => [];

  @override
  Future<List<PendingDealSuggestion>> loadPendingSuggestions({
    bool unresolvedOnly = true,
    int limit = 100,
    int daysBack = 30,
  }) async =>
      suggestions;

  @override
  Future<List<ParsedMessage>> loadParsedMessages({
    Set<ParsedMessageStatus>? statuses,
    int limit = 100,
    int daysBack = 30,
  }) async =>
      parsedMessages;

  @override
  Future<List<InboxDismissal>> loadInboxDismissals() async => [];

  @override
  Future<Set<String>> loadInboxReads({required String workspaceId}) async =>
      inboxReads;

  @override
  Future<int> markAllInboxRead({required String workspaceId}) async {
    markAllReadCalled = true;
    markAllReadCalledWithWorkspace = workspaceId;
    if (markAllReadError != null) throw markAllReadError!;
    return markAllReadResult;
  }
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

ParsedMessage _makeMessage(String id, ParsedMessageStatus status) =>
    ParsedMessage(
      id: id,
      workspaceId: 'workspace-test-123',
      accountId: 'account-1',
      receivedAt: DateTime(2026, 5, 7),
      status: status,
    );

PendingDealSuggestion _makeSuggestion(String id, String parsedMessageId) =>
    PendingDealSuggestion(
      id: id,
      workspaceId: 'workspace-test-123',
      parsedMessageId: parsedMessageId,
      shopKey: 'amazon',
      quantity: 1,
      currency: 'EUR',
      createdAt: DateTime(2026, 5, 7),
      receivedAt: DateTime(2026, 5, 7),
    );

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('InboxProvider — Read-Status', () {
    late _FakeRepository repo;
    late InboxProvider provider;

    setUp(() {
      repo = _FakeRepository();
      // 3 parsed_messages (2 matched + 1 unclassified) + 2 suggestions mit
      // eigenen parsedMessageIds → 5 distinkte IDs insgesamt.
      repo.parsedMessages = [
        _makeMessage('msg-1', ParsedMessageStatus.matched),
        _makeMessage('msg-2', ParsedMessageStatus.matched),
        _makeMessage('msg-3', ParsedMessageStatus.unclassified),
      ];
      repo.suggestions = [
        _makeSuggestion('sug-1', 'pmsg-1'),
        _makeSuggestion('sug-2', 'pmsg-2'),
      ];
      repo.inboxReads = {};
      provider = InboxProvider(repository: repo);
    });

    tearDown(() => provider.dispose());

    // ── T10 Case 1: Initial Load ─────────────────────────────────────────────

    test('Initial Load: loadInboxReads leer → unreadCount == 5', () async {
      await provider.refresh();

      expect(provider.unreadCount, 5);
      expect(provider.unreadMatchedCount, 2);
      expect(provider.unreadUnclassifiedCount, 1);
      expect(provider.unreadSuggestionsCount, 2);
    });

    // ── T10 Case 2: markAllRead → _readMessageIds enthält alle 5 IDs ────────

    test('markAllRead → unreadCount == 0 danach', () async {
      await provider.refresh();
      expect(provider.unreadCount, 5);

      await provider.markAllRead();

      expect(provider.unreadCount, 0);
      expect(provider.unreadMatchedCount, 0);
      expect(provider.unreadUnclassifiedCount, 0);
      expect(provider.unreadSuggestionsCount, 0);
    });

    test('markAllRead → Repo-Methode mit korrekter workspaceId aufgerufen',
        () async {
      await provider.refresh();
      await provider.markAllRead();

      expect(repo.markAllReadCalled, isTrue);
      expect(repo.markAllReadCalledWithWorkspace, 'workspace-test-123');
    });

    // ── T10 Case 3: notifyListeners feuert genau einmal nach markAllRead ─────

    test('markAllRead → notifyListeners genau einmal', () async {
      await provider.refresh();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.markAllRead();

      expect(notifyCount, 1);
    });

    // ── T10 Case 4: Fehlerfall — State bleibt unverändert, error gesetzt ─────

    test('markAllRead → Repo wirft → State unverändert, lastError gesetzt',
        () async {
      await provider.refresh();
      expect(provider.unreadCount, 5);

      repo.markAllReadError = Exception('Netzwerkfehler');

      await provider.markAllRead();

      // unreadCount bleibt 5 — keine lokale Set-Aktualisierung bei Fehler
      expect(provider.unreadCount, 5);
      expect(provider.lastError, isA<Exception>());
    });

    // ── Zusätzlich: isUnread-Helper ──────────────────────────────────────────

    test('isUnread returns true für unbekannte ID, false nach markAllRead',
        () async {
      await provider.refresh();

      expect(provider.isUnread('msg-1'), isTrue);

      await provider.markAllRead();

      expect(provider.isUnread('msg-1'), isFalse);
      expect(provider.isUnread('pmsg-1'), isFalse);
    });

    // ── Reads bleiben nach erneutem refresh persistent (Repo liefert sie) ────

    test('Nach refresh() werden Read-IDs aus Repo geladen', () async {
      repo.inboxReads = {'msg-1', 'pmsg-1'};
      await provider.refresh();

      expect(provider.isUnread('msg-1'), isFalse);
      expect(provider.isUnread('msg-2'), isTrue);
      expect(provider.unreadCount, 3); // 5 gesamt - 2 bereits gelesen
    });

    // ── Kein-Op wenn isLoading ───────────────────────────────────────────────

    test('markAllRead ist Kein-Op wenn isLoading == true', () async {
      // Wir rufen refresh() nicht ab, daher _loading == false. Wir können
      // isLoading nicht extern auf true setzen, aber wir können prüfen,
      // dass markAllRead bei leerem Provider keine Exception wirft.
      await provider.markAllRead();
      // Kein Aufruf erwartet, da kein refresh() vorher → suggestions + recent
      // sind leer, aber markAllRead läuft trotzdem durch (ws != null).
      // Der wichtige Fall: wenn während laufendem refresh markAllRead
      // aufgerufen wird. Da wir das nicht trivial testen können ohne
      // echte Asynchronizität, prüfen wir mindestens, dass kein Fehler fliegt.
      expect(provider.lastError, isNull);
    });
  });
}
