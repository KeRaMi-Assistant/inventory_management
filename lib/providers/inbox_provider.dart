import 'package:flutter/foundation.dart';

import '../models/inbox_message.dart';
import '../models/mailbox_account.dart';
import '../services/supabase_repository.dart';

/// Hält den lokalen Cache rund um die Postfach-Integration: konfigurierte
/// IMAP-Accounts, vorgeschlagene Deals, kürzliche geparste Mails. Lade-
/// Methoden werden vom Inbox-Screen + Settings-Postfach-Tab aufgerufen.
class InboxProvider extends ChangeNotifier {
  InboxProvider({required SupabaseRepository repository})
      : _repository = repository;

  final SupabaseRepository _repository;

  List<MailboxAccount> _accounts = [];
  List<PendingDealSuggestion> _suggestions = [];
  List<ParsedMessage> _recent = [];

  bool _loading = false;
  Object? _lastError;

  bool get isLoading => _loading;
  Object? get lastError => _lastError;

  List<MailboxAccount> get accounts => List.unmodifiable(_accounts);
  List<PendingDealSuggestion> get pendingSuggestions =>
      List.unmodifiable(_suggestions);
  List<ParsedMessage> get recentMessages => List.unmodifiable(_recent);

  List<ParsedMessage> get matchedRecently => _recent
      .where((m) => m.status == ParsedMessageStatus.matched)
      .toList(growable: false);

  List<ParsedMessage> get unclassified => _recent
      .where((m) => m.status == ParsedMessageStatus.unclassified)
      .toList(growable: false);

  int get unresolvedCount => _suggestions
      .where((s) => s.resolvedAt == null)
      .length;

  Future<void> refresh() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.loadMailboxAccounts(),
        _repository.loadPendingSuggestions(),
        _repository.loadParsedMessages(
          statuses: const {
            ParsedMessageStatus.matched,
            ParsedMessageStatus.unclassified,
          },
          limit: 100,
        ),
      ]);
      _accounts = results[0] as List<MailboxAccount>;
      _suggestions = results[1] as List<PendingDealSuggestion>;
      _recent = results[2] as List<ParsedMessage>;
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InboxProvider.refresh failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<MailboxAccount> addAccount(
    MailboxAccount draft, {
    required String password,
  }) async {
    final saved = await _repository.insertMailboxAccount(
      draft,
      password: password,
    );
    _accounts = [..._accounts, saved];
    notifyListeners();
    return saved;
  }

  Future<MailboxAccount> updateAccount(
    MailboxAccount account, {
    String? newPassword,
  }) async {
    final saved = await _repository.updateMailboxAccount(
      account,
      newPassword: newPassword,
    );
    _accounts = [
      for (final a in _accounts)
        if (a.id == saved.id) saved else a,
    ];
    notifyListeners();
    return saved;
  }

  Future<void> deleteAccount(String id) async {
    await _repository.deleteMailboxAccount(id);
    _accounts = _accounts.where((a) => a.id != id).toList();
    notifyListeners();
  }

  Future<void> markSuggestionAccepted(
    String suggestionId, {
    required int createdDealId,
  }) async {
    await _repository.markSuggestionResolved(
      suggestionId,
      action: 'accepted',
      createdDealId: createdDealId,
    );
    _suggestions = _suggestions
        .where((s) => s.id != suggestionId)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> markSuggestionRejected(String suggestionId) async {
    await _repository.markSuggestionResolved(
      suggestionId,
      action: 'rejected',
    );
    _suggestions = _suggestions
        .where((s) => s.id != suggestionId)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> dismissParsedMessage(String id) async {
    await _repository.dismissParsedMessage(id);
    _recent = _recent.where((m) => m.id != id).toList(growable: false);
    notifyListeners();
  }

  /// Wendet Tracking aus der Mail/Suggestion auf einen bestehenden Deal an.
  /// Die zugehörige parsed_message wird matched, optional eine offene
  /// Suggestion resolved.
  Future<void> applyTrackingFromSuggestion({
    required PendingDealSuggestion suggestion,
    required int dealId,
  }) async {
    if (suggestion.tracking == null || suggestion.tracking!.isEmpty) {
      throw StateError('Suggestion enthält kein Tracking.');
    }
    await _repository.applyTrackingToDeal(
      parsedMessageId: suggestion.parsedMessageId,
      dealId: dealId,
      tracking: suggestion.tracking!,
      carrier: suggestion.carrier,
      eta: suggestion.eta,
    );
    await _repository.markSuggestionResolved(
      suggestion.id,
      action: 'accepted',
      createdDealId: dealId,
    );
    _suggestions = _suggestions
        .where((s) => s.id != suggestion.id)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> linkSuggestionToDeal({
    required PendingDealSuggestion suggestion,
    required int dealId,
  }) async {
    await _repository.linkSuggestionToExistingDeal(
      suggestionId: suggestion.id,
      parsedMessageId: suggestion.parsedMessageId,
      dealId: dealId,
      tracking: suggestion.tracking,
      orderId: suggestion.orderId,
      eta: suggestion.eta,
    );
    _suggestions = _suggestions
        .where((s) => s.id != suggestion.id)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> applyTrackingFromMessage({
    required ParsedMessage message,
    required int dealId,
    required String tracking,
    String? carrier,
    DateTime? eta,
  }) async {
    await _repository.applyTrackingToDeal(
      parsedMessageId: message.id,
      dealId: dealId,
      tracking: tracking,
      carrier: carrier,
      eta: eta,
    );
    _recent = _recent.where((m) => m.id != message.id).toList(growable: false);
    notifyListeners();
  }

  void clear() {
    _accounts = [];
    _suggestions = [];
    _recent = [];
    _lastError = null;
    notifyListeners();
  }
}
