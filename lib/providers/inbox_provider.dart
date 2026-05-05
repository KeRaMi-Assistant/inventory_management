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

  /// Sichtbarkeitsfenster der Inbox in Tagen. Der Countdown auf der Card
  /// zählt von hier runter. Deckt sich aktuell mit dem DB-Cleanup-Job
  /// (cleanup_inbox_history_daily, 30 Tage), d.h. Karten verschwinden
  /// aus der UI ungefähr zeitgleich mit dem Datenbank-Delete.
  static const int visibilityDays = 30;

  List<MailboxAccount> _accounts = [];
  List<PendingDealSuggestion> _suggestionsRaw = [];
  List<PendingDealSuggestion> _suggestions = [];
  List<ParsedMessage> _recent = [];
  DateTime _lastRefreshedAt = DateTime.now();

  bool _loading = false;
  Object? _lastError;

  bool get isLoading => _loading;
  Object? get lastError => _lastError;

  /// Wann die letzten DB-Daten reingekommen sind. Der Countdown der UI
  /// rechnet relativ dazu, damit er nicht jede Sekunde tickt — er
  /// aktualisiert erst beim nächsten Refresh.
  DateTime get lastRefreshedAt => _lastRefreshedAt;

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
      _suggestionsRaw = results[1] as List<PendingDealSuggestion>;
      _suggestions = _dedupByOrderId(_suggestionsRaw);
      _recent = results[2] as List<ParsedMessage>;
      _lastRefreshedAt = DateTime.now();
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InboxProvider.refresh failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Reduziert mehrere Mails zur selben (shop_key, order_id) auf eine
  /// gemergte Card. Status + Datum kommen vom NEUESTEN Eintrag (das ist
  /// der aktuelle Zustand der Bestellung), Detail-Felder wie Produkt,
  /// Tracking, Carrier, Total werden aus älteren Mails ergänzt, falls
  /// die neueste sie nicht hat — Versandbestätigungen tragen z.B. die
  /// Tracking-Nr, spätere Status-Updates aber nicht mehr.
  ///
  /// Suggestions ohne order_id bleiben einzeln stehen — wir haben keinen
  /// verlässlichen Schlüssel zum Mergen.
  static List<PendingDealSuggestion> _dedupByOrderId(
    List<PendingDealSuggestion> all,
  ) {
    final groups = <String, List<PendingDealSuggestion>>{};
    final standalone = <PendingDealSuggestion>[];
    for (final s in all) {
      if (s.orderId == null || s.orderId!.isEmpty) {
        standalone.add(s);
        continue;
      }
      final key = '${s.shopKey}:${s.orderId}';
      groups.putIfAbsent(key, () => []).add(s);
    }
    final merged = <PendingDealSuggestion>[];
    for (final group in groups.values) {
      group.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      merged.add(_mergeGroup(group));
    }
    merged.addAll(standalone);
    merged.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return merged;
  }

  /// Erste in der Liste = neueste Mail. Detail-Felder fallen back auf
  /// ältere Einträge. Quantity max() weil Versand- und Storno-Mails oft
  /// nur Teilmengen referenzieren — wir wollen die ursprüngliche Anzahl.
  /// Trackings werden über alle Mails als Set vereinigt (Reihenfolge:
  /// neueste zuerst).
  static PendingDealSuggestion _mergeGroup(List<PendingDealSuggestion> sorted) {
    final newest = sorted.first;
    String? product = newest.product;
    double? total = newest.total;
    String? carrier = newest.carrier;
    DateTime? eta = newest.eta;
    int quantity = newest.quantity;
    final mergedTrackings = <String>{};
    for (final tn in newest.trackings) {
      if (tn.isNotEmpty) mergedTrackings.add(tn);
    }
    for (final s in sorted.skip(1)) {
      if ((product == null || product.isEmpty) &&
          (s.product?.isNotEmpty ?? false)) {
        product = s.product;
      }
      total ??= s.total;
      for (final tn in s.trackings) {
        if (tn.isNotEmpty) mergedTrackings.add(tn);
      }
      carrier ??= s.carrier;
      eta ??= s.eta;
      if (s.quantity > quantity) quantity = s.quantity;
    }
    final trackingsList = mergedTrackings.toList(growable: false);
    return PendingDealSuggestion(
      id: newest.id,
      workspaceId: newest.workspaceId,
      parsedMessageId: newest.parsedMessageId,
      messageId: newest.messageId,
      shopKey: newest.shopKey,
      shopLabel: newest.shopLabel,
      orderId: newest.orderId,
      product: product,
      quantity: quantity,
      total: total,
      currency: newest.currency,
      tracking: trackingsList.firstOrNull,
      trackings: trackingsList,
      carrier: carrier,
      eta: eta,
      status: newest.status,
      createdAt: newest.createdAt,
      receivedAt: newest.receivedAt,
      resolvedAt: newest.resolvedAt,
      resolvedAction: newest.resolvedAction,
      createdDealId: newest.createdDealId,
    );
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

  /// Wenn der User einen geclusterten Vorschlag (z.B. via Dedup-Merge
  /// "letzter Versand der Bestellung X") auflöst, sollen alle anderen
  /// Suggestions mit derselben (shop_key, order_id) ebenfalls verschwinden
  /// — sie repräsentieren dieselbe Bestellung, der User hat eine
  /// Entscheidung getroffen.
  Future<void> _resolveSuggestionGroup(
    String suggestionId, {
    required String action,
    int? createdDealId,
  }) async {
    final picked = _suggestionsRaw
        .where((s) => s.id == suggestionId)
        .firstOrNull;
    final orderKey = picked != null && picked.orderId != null
        ? '${picked.shopKey}:${picked.orderId}'
        : null;
    final groupIds = <String>{suggestionId};
    if (orderKey != null) {
      for (final s in _suggestionsRaw) {
        if (s.orderId != null && '${s.shopKey}:${s.orderId}' == orderKey) {
          groupIds.add(s.id);
        }
      }
    }
    for (final id in groupIds) {
      await _repository.markSuggestionResolved(
        id,
        action: action,
        createdDealId: id == suggestionId ? createdDealId : null,
      );
    }
    _suggestionsRaw = _suggestionsRaw
        .where((s) => !groupIds.contains(s.id))
        .toList(growable: false);
    _suggestions = _dedupByOrderId(_suggestionsRaw);
    notifyListeners();
  }

  Future<void> markSuggestionAccepted(
    String suggestionId, {
    required int createdDealId,
  }) async {
    await _resolveSuggestionGroup(
      suggestionId,
      action: 'accepted',
      createdDealId: createdDealId,
    );
  }

  Future<void> markSuggestionRejected(String suggestionId) async {
    await _resolveSuggestionGroup(suggestionId, action: 'rejected');
  }

  Future<void> dismissParsedMessage(String id) async {
    await _repository.dismissParsedMessage(id);
    _recent = _recent.where((m) => m.id != id).toList(growable: false);
    notifyListeners();
  }

  /// Wendet Tracking aus der Mail/Suggestion auf einen bestehenden Deal an.
  /// Die zugehörige parsed_message wird matched, alle Suggestions zur
  /// selben Bestellung werden als accepted markiert.
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
    await _resolveSuggestionGroup(
      suggestion.id,
      action: 'accepted',
      createdDealId: dealId,
    );
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
    // Andere Mails zur selben Bestellung mit-resolve, damit das Cluster
    // nicht weiter im UI hängt. linkSuggestionToExistingDeal hat den
    // primären Eintrag bereits resolved → action='accepted' ohne
    // createdDealId für die Reste.
    final orderKey = suggestion.orderId != null
        ? '${suggestion.shopKey}:${suggestion.orderId}'
        : null;
    final extraIds = <String>{};
    if (orderKey != null) {
      for (final s in _suggestionsRaw) {
        if (s.id == suggestion.id) continue;
        if (s.orderId != null && '${s.shopKey}:${s.orderId}' == orderKey) {
          extraIds.add(s.id);
        }
      }
    }
    for (final id in extraIds) {
      await _repository.markSuggestionResolved(id, action: 'accepted',
          createdDealId: dealId);
    }
    final removed = {suggestion.id, ...extraIds};
    _suggestionsRaw = _suggestionsRaw
        .where((s) => !removed.contains(s.id))
        .toList(growable: false);
    _suggestions = _dedupByOrderId(_suggestionsRaw);
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
    _suggestionsRaw = [];
    _suggestions = [];
    _recent = [];
    _lastError = null;
    notifyListeners();
  }
}
