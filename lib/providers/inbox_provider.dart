import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/inbox_message.dart';
import '../models/mailbox_account.dart';
import '../models/tracking_confidence.dart';
import '../services/supabase_repository.dart';
import '../utils/error_messages.dart';

/// Hält den lokalen Cache rund um die Postfach-Integration: konfigurierte
/// IMAP-Accounts, vorgeschlagene Deals, kürzliche geparste Mails. Lade-
/// Methoden werden vom Inbox-Screen + Settings-Postfach-Tab aufgerufen.
class InboxProvider extends ChangeNotifier {
  InboxProvider({required SupabaseRepository repository})
      : _repository = repository;

  final SupabaseRepository _repository;

  /// Default-Sichtbarkeit, wenn noch kein Plan geladen wurde. Der echte
  /// Wert kommt aus dem Pricing-Tier (siehe `applyPlanQuota`) und kann
  /// sich beim Upgrade/Downgrade ändern. DB-Cleanup-Cron läuft mit
  /// 30 Tagen davon unabhängig.
  static const int defaultVisibilityDays = 30;

  /// Maximale Anzahl IMAP-Konten, die der User nach aktuellem Plan
  /// anlegen darf. -1 = unlimited.
  int _mailboxLimit = -1;
  int get mailboxLimit => _mailboxLimit;

  int _visibilityDays = defaultVisibilityDays;
  int get visibilityDays => _visibilityDays;

  /// Setzt die Plan-Quotas. Wird vom AuthGate aufgerufen, wenn der
  /// BillingProvider seinen Plan lädt oder der User upgraded.
  void applyPlanQuota({
    required int mailboxLimit,
    required int visibilityDays,
  }) {
    var changed = false;
    if (_mailboxLimit != mailboxLimit) {
      _mailboxLimit = mailboxLimit;
      changed = true;
    }
    if (_visibilityDays != visibilityDays) {
      _visibilityDays = visibilityDays;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  List<MailboxAccount> _accounts = [];
  List<PendingDealSuggestion> _suggestionsRaw = [];
  List<PendingDealSuggestion> _suggestions = [];
  List<ParsedMessage> _recentRaw = [];
  List<ParsedMessage> _recent = [];
  Set<String> _dismissalKeys = const {};
  int _dismissalCount = 0;
  String? _shopFilter;
  SuggestionShipStatus? _statusFilter;
  DateTime _lastRefreshedAt = DateTime.now();

  /// IDs aller parsed_messages, die der eingeloggte User bereits gesehen hat.
  Set<String> _readMessageIds = {};

  /// Vorschlag-IDs, die lokal als "zu-verwerfen" markiert sind, aber noch
  /// nicht per DB-Call committed wurden. Wird verwendet für Optimistic-Undo.
  final Set<String> _pendingRejectIds = {};

  /// Timers, die nach Ablauf den DB-Commit auslösen (4 Sek. Default).
  final Map<String, Timer> _pendingRejectTimers = {};

  bool _loading = false;
  bool _initialLoadAttempted = false;
  Object? _lastError;

  bool get isLoading => _loading;

  /// True as soon as the first [refresh] call has returned — regardless of
  /// whether it succeeded or failed. Used by skeleton-loading logic to
  /// distinguish the cold-start race (provider not yet fired) from the
  /// empty-state after a completed load.
  bool get initialLoadAttempted => _initialLoadAttempted;

  Object? get lastError => _lastError;

  /// Wann die letzten DB-Daten reingekommen sind. Der Countdown der UI
  /// rechnet relativ dazu, damit er nicht jede Sekunde tickt — er
  /// aktualisiert erst beim nächsten Refresh.
  DateTime get lastRefreshedAt => _lastRefreshedAt;

  List<MailboxAccount> get accounts => List.unmodifiable(_accounts);

  /// Sichtbare Vorschläge — ohne die, die gerade optimistisch als verworfen
  /// markiert sind (pending-reject via [rejectSuggestionWithUndo]).
  List<PendingDealSuggestion> get pendingSuggestions {
    if (_pendingRejectIds.isEmpty) return List.unmodifiable(_suggestions);
    return List.unmodifiable(
      _suggestions.where((s) => !_pendingRejectIds.contains(s.id)),
    );
  }
  List<ParsedMessage> get recentMessages => List.unmodifiable(_recent);

  // ── Read-Status-Helpers ──────────────────────────────────────────────────

  /// Gibt `true` zurück, wenn die parsed_message mit [parsedMessageId] noch
  /// nicht vom eingeloggten User als gelesen markiert wurde.
  bool isUnread(String parsedMessageId) =>
      !_readMessageIds.contains(parsedMessageId);

  /// Anzahl aller sichtbaren Einträge (Suggestions + matched + unclassified),
  /// die noch nicht als gelesen markiert sind. Duplikate (gleiche
  /// parsedMessageId in mehreren Tabs) werden dedupliziert.
  int get unreadCount {
    final allIds = <String>{};
    for (final s in _suggestions) {
      allIds.add(s.parsedMessageId);
    }
    for (final m in _recent) {
      allIds.add(m.id);
    }
    return allIds.where(isUnread).length;
  }

  /// Anzahl ungelesener Einträge im Suggestions-Tab.
  int get unreadSuggestionsCount =>
      _suggestions.where((s) => isUnread(s.parsedMessageId)).length;

  /// Anzahl ungelesener Einträge im Matched-Tab.
  int get unreadMatchedCount => _recent
      .where(
        (m) =>
            m.status == ParsedMessageStatus.matched && isUnread(m.id),
      )
      .length;

  /// Anzahl ungelesener Einträge im Unclassified-Tab.
  int get unreadUnclassifiedCount => _recent
      .where(
        (m) =>
            m.status == ParsedMessageStatus.unclassified && isUnread(m.id),
      )
      .length;

  List<ParsedMessage> get matchedRecently => _recent
      .where((m) => m.status == ParsedMessageStatus.matched)
      .toList(growable: false);

  List<ParsedMessage> get unclassified => _recent
      .where((m) => m.status == ParsedMessageStatus.unclassified)
      .toList(growable: false);

  int get unresolvedCount => _suggestions
      .where((s) => s.resolvedAt == null)
      .length;

  /// Wieviele Dismissals der User aktuell aktiv hat. UI benutzt das fürs
  /// Reset-Button-Label ("Filter zurücksetzen (12)").
  int get dismissalCount => _dismissalCount;

  String? get shopFilter => _shopFilter;
  SuggestionShipStatus? get statusFilter => _statusFilter;

  /// Distinkte Shop-Keys aus den aktuellen Roh-Daten (Suggestions + Recent
  /// Messages), sortiert. Liefert dem UI die Optionen für den Shop-Picker —
  /// so tauchen nur Shops auf, zu denen wirklich Mails da sind.
  List<String> get availableShopKeys {
    final keys = <String>{};
    for (final s in _suggestionsRaw) {
      keys.add(s.shopKey);
    }
    for (final m in _recentRaw) {
      if (m.shopKey != null && m.shopKey!.isNotEmpty) keys.add(m.shopKey!);
    }
    return keys.toList()..sort();
  }

  /// Lese-freundliches Label für einen Shop-Key. Suggestions tragen ein
  /// `shopLabel` (z.B. "MediaMarkt"); fallback ist der Key kapitalisiert.
  String shopLabelFor(String shopKey) {
    for (final s in _suggestionsRaw) {
      if (s.shopKey == shopKey && s.shopLabel != null) return s.shopLabel!;
    }
    if (shopKey.isEmpty) return shopKey;
    return shopKey[0].toUpperCase() + shopKey.substring(1);
  }

  void setShopFilter(String? shopKey) {
    if (_shopFilter == shopKey) return;
    _shopFilter = shopKey;
    _recomputeViews();
    notifyListeners();
  }

  void setStatusFilter(SuggestionShipStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _recomputeViews();
    notifyListeners();
  }

  void clearFilters() {
    if (_shopFilter == null && _statusFilter == null) return;
    _shopFilter = null;
    _statusFilter = null;
    _recomputeViews();
    notifyListeners();
  }

  bool get hasActiveFilter =>
      _shopFilter != null || _statusFilter != null;

  Future<void> refresh() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      // loadInboxReads benötigt die Workspace-ID. Falls kein Workspace aktiv
      // ist, wirft _repository._wsId bereits — konsistent mit den anderen
      // Repo-Calls. Workspace-ID über den Repository-Getter holen ist nicht
      // möglich (privat), deshalb versuchen wir den Reads-Load und fangen
      // StateError separat ab.
      final ws = _repository.activeWorkspaceId;
      final results = await Future.wait([
        _repository.loadMailboxAccounts(),
        _repository.loadPendingSuggestions(daysBack: _visibilityDays),
        _repository.loadParsedMessages(
          statuses: const {
            ParsedMessageStatus.matched,
            ParsedMessageStatus.unclassified,
          },
          limit: 100,
          daysBack: _visibilityDays,
        ),
        _repository.loadInboxDismissals(),
        if (ws != null)
          _repository.loadInboxReads(workspaceId: ws)
        else
          Future.value(<String>{}),
      ]);
      _accounts = results[0] as List<MailboxAccount>;
      _suggestionsRaw = results[1] as List<PendingDealSuggestion>;
      _recentRaw = results[2] as List<ParsedMessage>;
      final dismissals = results[3] as List<InboxDismissal>;
      _dismissalKeys = dismissals.map((d) => d.cacheKey).toSet();
      _dismissalCount = dismissals.length;
      _readMessageIds = results[4] as Set<String>;
      _recomputeViews();
      _lastRefreshedAt = DateTime.now();
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InboxProvider.refresh failed: $e');
    } finally {
      _loading = false;
      _initialLoadAttempted = true;
      notifyListeners();
    }
  }

  /// Baut `_suggestions` und `_recent` aus den Roh-Listen neu auf, indem
  /// Dedup, Dismiss-Filter und User-Filter angewendet werden. Wird beim
  /// Refresh und bei jeder Filter-Änderung aufgerufen — keine erneute
  /// DB-Query.
  void _recomputeViews() {
    _suggestions = _applyFilters(_dedupByOrderId(_suggestionsRaw));
    _recent = _filterMessages(_recentRaw);
  }

  /// Filtert Suggestions, deren (shopKey, orderId) auf der Dismiss-Liste
  /// stehen, und wendet die User-Filter (Shop, Status) an.
  List<PendingDealSuggestion> _applyFilters(
    List<PendingDealSuggestion> suggestions,
  ) {
    if (_dismissalKeys.isEmpty &&
        _shopFilter == null &&
        _statusFilter == null) {
      return suggestions;
    }
    return suggestions.where((s) {
      if (_shopFilter != null && s.shopKey != _shopFilter) return false;
      if (_statusFilter != null && s.status != _statusFilter) return false;
      if (s.orderId != null && s.orderId!.isNotEmpty) {
        if (_dismissalKeys
            .contains(InboxDismissal.orderKey(s.shopKey, s.orderId!))) {
          return false;
        }
      }
      if (_dismissalKeys
          .contains(InboxDismissal.messageKey(s.parsedMessageId))) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// Status-Filter gilt nicht für matched/unclassified Mails — die haben
  /// keinen vergleichbaren Shipment-Status. Shop-Filter + Dismissals dagegen
  /// schon.
  List<ParsedMessage> _filterMessages(List<ParsedMessage> messages) {
    if (_dismissalKeys.isEmpty && _shopFilter == null) return messages;
    return messages.where((m) {
      if (_shopFilter != null && m.shopKey != _shopFilter) return false;
      // Wenn die Mail einen erkannten Shop+OrderId hat, gilt der Order-
      // Dismiss auch hier (z.B. Zustell-Bestätigung von dismissed Order).
      final orderId = m.parsedPayload?['order_id'] as String?;
      if (m.shopKey != null && orderId != null && orderId.isNotEmpty) {
        if (_dismissalKeys
            .contains(InboxDismissal.orderKey(m.shopKey!, orderId))) {
          return false;
        }
      }
      if (_dismissalKeys.contains(InboxDismissal.messageKey(m.id))) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// Markiert alle aktuell sichtbaren Inbox-Einträge als gelesen.
  /// Ruft die RPC `mark_all_inbox_read` auf und aktualisiert lokal das
  /// `_readMessageIds`-Set, ohne einen erneuten Refresh auszulösen
  /// (verhindert UI-Flackern). Kein-Op wenn ein Ladevorgang läuft.
  Future<void> markAllRead() async {
    if (_loading) return;
    final ws = _repository.activeWorkspaceId;
    if (ws == null) return;
    try {
      await _repository.markAllInboxRead(workspaceId: ws);
      // Lokal alle sichtbaren parsed_message_ids als gelesen markieren —
      // genau das, was die RPC serverseitig ebenfalls tut.
      final nowRead = <String>{};
      for (final s in _suggestions) {
        nowRead.add(s.parsedMessageId);
      }
      for (final m in _recent) {
        nowRead.add(m.id);
      }
      _readMessageIds = {..._readMessageIds, ...nowRead};
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InboxProvider.markAllRead failed: $e');
    }
    notifyListeners();
  }

  /// Leert die Dismiss-Liste komplett — alle bisher verworfenen
  /// Vorschläge/Mails kommen beim nächsten Refresh zurück. UI ruft das
  /// vom "Filter zurücksetzen"-Button.
  Future<void> clearDismissals() async {
    await _repository.clearInboxDismissals();
    _dismissalKeys = const {};
    _dismissalCount = 0;
    notifyListeners();
    await refresh();
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
      // Confidence vom neuesten Eintrag beibehalten (der hat die aktuellste
      // Bewertung). needs_review = true wenn IRGENDEIN Eintrag needs_review
      // hat — so bleibt der Hinweis sichtbar bis alle bestätigt sind.
      trackingConfidence: newest.trackingConfidence,
      trackingNeedsReview: sorted.any((s) => s.trackingNeedsReview),
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
    // Sofort einmal pollen statt auf den 5-Min-Cron-Tick zu warten —
    // User sieht innerhalb Sekunden ob die Credentials passen oder ob
    // ein Setup-Bug (Function nicht deployed, Cron tot) den Loop blockt.
    // Fehler werden geswallowed, damit ein fehlender Polling-Job nicht
    // den erfolgreichen IMAP-Account-Insert torpediert. Die App kann
    // den Status nachträglich via [pollNow] anzeigen.
    unawaited(_pollSilently());
    return saved;
  }

  /// Live-Status des laufenden Bootstrap-Pumps. Während `triggerInboxPoll`
  /// in mehreren Iterationen Mails nachzieht, halten wir hier die kumulierte
  /// Zahl der bereits gespeicherten Mails fest, damit die UI ein Banner
  /// "Lade Mails (X bisher)…" rendern kann statt "Noch nicht gepollt".
  bool _pumping = false;
  int _pumpStored = 0;
  bool get isPumping => _pumping;
  int get pumpStored => _pumpStored;

  Future<void> _pollSilently() async {
    try {
      await _runPump(silent: true);
    } catch (_) {
      // Stille — UI hat ohnehin den "Jetzt pollen"-Button für lautes Retry.
    }
  }

  /// Manueller Polling-Trigger (Inbox-Header-Button). Setzt [lastError]
  /// bei Fehlern + ruft [refresh] bei Erfolg, damit neue Vorschläge
  /// sofort sichtbar sind.
  Future<InboxPollResult?> pollNow() async {
    if (_loading || _pumping) return null;
    _lastError = null;
    notifyListeners();
    try {
      return await _runPump(silent: false);
    } catch (e) {
      // UI zeigt nur null-Check auf lastError (AppFeedback.errorDefault),
      // kein roher String wird angezeigt. sanitizeError verhindert dennoch
      // interne Stacktraces im Heap.
      _lastError = sanitizeError(e);
      notifyListeners();
      return null;
    }
  }

  /// Re-Parse aller Suggestions mit `_raw_html` durch die aktuelle
  /// Adapter-Registry. User-Trigger nach Adapter-Bug-Fixes (z.B. wenn
  /// eine FALSCHE Tracking-Nummer im Vorschlag steht). Setzt [lastError]
  /// bei Fehlern + refresht die Inbox bei Erfolg.
  Future<InboxReparseResult?> reparseTracking({
    String? shopKey,
    bool forceOverwrite = true,
  }) async {
    if (_loading || _pumping) return null;
    _lastError = null;
    notifyListeners();
    try {
      final result = await _repository.triggerReparseTracking(
        shopKey: shopKey,
        forceOverwrite: forceOverwrite,
      );
      await refresh();
      return result;
    } catch (e) {
      // UI zeigt nur null-Check auf lastError (AppFeedback.errorDefault),
      // kein roher String wird angezeigt. sanitizeError verhindert dennoch
      // interne Stacktraces im Heap.
      _lastError = sanitizeError(e);
      notifyListeners();
      return null;
    }
  }

  /// Wrapper um [SupabaseRepository.triggerInboxPoll], der den Pump-State
  /// pflegt und nach jeder Server-Iteration einen [refresh] auslöst —
  /// so wachsen die Tab-Counter live mit, anstatt erst nach dem Loop-Ende
  /// einmal zu springen.
  Future<InboxPollResult> _runPump({required bool silent}) async {
    _pumping = true;
    _pumpStored = 0;
    notifyListeners();
    try {
      final result = await _repository.triggerInboxPoll(
        onProgress: (partial) {
          _pumpStored = partial.stored;
          notifyListeners();
          // Live-Refresh fire-and-forget: Counter im Inbox-Header steigen
          // mit jeder Iteration sichtbar an. Wir warten NICHT auf das
          // SELECT, damit der nächste Server-Call sofort starten kann.
          // Fehler schlucken, damit ein flackerndes SELECT den Pump nicht
          // killt.
          unawaited(refresh().catchError((Object _) {}));
        },
      );
      await refresh();
      return result;
    } finally {
      _pumping = false;
      _pumpStored = 0;
      notifyListeners();
    }
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

  /// User wirft den Vorschlag weg. Schreibt zusätzlich zur normalen Resolve-
  /// Logik einen `inbox_dismissals`-Eintrag (Order-basiert wenn möglich,
  /// sonst per parsed_message_id), damit zukünftige Mails zur selben
  /// Bestellung NICHT wieder als Vorschlag erscheinen.
  Future<void> markSuggestionRejected(String suggestionId) async {
    final picked =
        _suggestionsRaw.where((s) => s.id == suggestionId).firstOrNull;
    if (picked != null) {
      await _repository.insertInboxDismissal(
        shopKey: picked.shopKey,
        orderId: picked.orderId,
        parsedMessageId: picked.orderId == null || picked.orderId!.isEmpty
            ? picked.parsedMessageId
            : null,
        receivedAt: picked.receivedAt,
      );
      _addLocalDismissal(picked);
    }
    await _resolveSuggestionGroup(suggestionId, action: 'rejected');
  }

  /// User wirft eine einzelne Mail weg (matched/unclassified). Wenn die
  /// Mail einer Bestellung zugeordnet ist, wird der Order-Key als Dismiss
  /// gespeichert — sonst nur die Message-ID.
  Future<void> dismissParsedMessage(String id) async {
    final picked = _recent.where((m) => m.id == id).firstOrNull;
    if (picked != null) {
      final orderId = picked.parsedPayload?['order_id'] as String?;
      final hasOrder = picked.shopKey != null &&
          orderId != null &&
          orderId.isNotEmpty;
      await _repository.insertInboxDismissal(
        shopKey: hasOrder ? picked.shopKey : null,
        orderId: hasOrder ? orderId : null,
        parsedMessageId: hasOrder ? null : picked.id,
        receivedAt: picked.receivedAt,
      );
      _addLocalDismissalKey(
        hasOrder
            ? InboxDismissal.orderKey(picked.shopKey!, orderId)
            : InboxDismissal.messageKey(picked.id),
      );
    }
    await _repository.dismissParsedMessage(id);
    _recent = _recent.where((m) => m.id != id).toList(growable: false);
    notifyListeners();
  }

  void _addLocalDismissal(PendingDealSuggestion s) {
    final key = (s.orderId != null && s.orderId!.isNotEmpty)
        ? InboxDismissal.orderKey(s.shopKey, s.orderId!)
        : InboxDismissal.messageKey(s.parsedMessageId);
    _addLocalDismissalKey(key);
  }

  void _addLocalDismissalKey(String key) {
    if (_dismissalKeys.contains(key)) return;
    _dismissalKeys = {..._dismissalKeys, key};
    _dismissalCount = _dismissalKeys.length;
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

  // ── Tracking-Confidence-Updates ──────────────────────────────────────────

  /// Akzeptiert das `needs_review`-Tracking einer Suggestion als korrekt.
  /// Setzt `tracking_confidence = 'manual'`, `tracking_needs_review = false`.
  /// Aktualisiert lokal den Cache, ohne einen vollen Refresh auszulösen.
  Future<void> acceptSuggestionTrackingAsManual(String suggestionId) async {
    await _repository.acceptSuggestionTrackingAsManual(suggestionId);
    _updateSuggestionLocally(
      suggestionId,
      trackingConfidence: TrackingConfidence.manual,
      trackingNeedsReview: false,
    );
  }

  /// Verwirft das Tracking einer Suggestion.
  Future<void> discardSuggestionTracking(String suggestionId) async {
    await _repository.discardSuggestionTracking(suggestionId);
    _updateSuggestionLocally(
      suggestionId,
      tracking: null,
      trackingConfidence: TrackingConfidence.none,
      trackingNeedsReview: false,
    );
  }

  /// Setzt eine manuell eingegebene Tracking-Nummer auf einer Suggestion.
  Future<void> updateSuggestionTrackingManually(
    String suggestionId,
    String tracking,
  ) async {
    await _repository.updateSuggestionTrackingManually(suggestionId, tracking);
    _updateSuggestionLocally(
      suggestionId,
      tracking: tracking,
      trackingConfidence: TrackingConfidence.manual,
      trackingNeedsReview: false,
    );
  }

  /// Hilfsmethode: aktualisiert eine Suggestion lokal in beiden Caches.
  void _updateSuggestionLocally(
    String suggestionId, {
    Object? tracking = _kSentinel,
    TrackingConfidence? trackingConfidence,
    bool? trackingNeedsReview,
  }) {
    PendingDealSuggestion patch(PendingDealSuggestion s) {
      if (s.id != suggestionId) return s;
      return PendingDealSuggestion(
        id: s.id,
        workspaceId: s.workspaceId,
        parsedMessageId: s.parsedMessageId,
        messageId: s.messageId,
        shopKey: s.shopKey,
        shopLabel: s.shopLabel,
        orderId: s.orderId,
        product: s.product,
        quantity: s.quantity,
        total: s.total,
        currency: s.currency,
        tracking: tracking == _kSentinel ? s.tracking : tracking as String?,
        trackings: tracking == _kSentinel
            ? s.trackings
            : (tracking == null
                ? const []
                : [tracking as String]),
        carrier: s.carrier,
        eta: s.eta,
        status: s.status,
        createdAt: s.createdAt,
        receivedAt: s.receivedAt,
        resolvedAt: s.resolvedAt,
        resolvedAction: s.resolvedAction,
        createdDealId: s.createdDealId,
        trackingConfidence: trackingConfidence ?? s.trackingConfidence,
        trackingNeedsReview: trackingNeedsReview ?? s.trackingNeedsReview,
      );
    }

    _suggestionsRaw = _suggestionsRaw.map(patch).toList(growable: false);
    _suggestions = _suggestions.map(patch).toList(growable: false);
    notifyListeners();
  }

  static const Object _kSentinel = Object();

  // ── Optimistic-Undo: Suggestion-Verwerfen ───────────────────────────────

  /// Markiert [suggestionId] lokal als pending-reject und startet einen Timer,
  /// der nach [delay] den echten DB-Commit ([markSuggestionRejected]) ausführt.
  ///
  /// Solange der Timer läuft, filtert [pendingSuggestions] die Suggestion
  /// aus der UI-Liste heraus — sie ist damit sofort "weg", ohne DB-Touch.
  ///
  /// Aufruf von [cancelPendingReject] stoppt den Timer und lässt die
  /// Suggestion wieder erscheinen (Undo).
  ///
  /// Bei Fehler im Delayed-Commit wird der Marker trotzdem entfernt, damit
  /// die Suggestion wieder sichtbar wird — der User kann es erneut versuchen.
  void rejectSuggestionWithUndo(
    String suggestionId, {
    Duration delay = const Duration(seconds: 4),
  }) {
    // Kein Doppel-Commit: falls schon pending, ignorieren.
    if (_pendingRejectIds.contains(suggestionId)) return;
    _pendingRejectIds.add(suggestionId);
    notifyListeners();

    final timer = Timer(delay, () async {
      _pendingRejectTimers.remove(suggestionId);
      try {
        await markSuggestionRejected(suggestionId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('InboxProvider: delayed reject commit failed: $e');
        }
      } finally {
        _pendingRejectIds.remove(suggestionId);
        notifyListeners();
      }
    });
    _pendingRejectTimers[suggestionId] = timer;
  }

  /// Bricht den pendenden Reject für [suggestionId] ab (Undo).
  /// Der DB-Commit wird NICHT ausgeführt — die Suggestion erscheint
  /// sofort wieder in [pendingSuggestions].
  void cancelPendingReject(String suggestionId) {
    final timer = _pendingRejectTimers.remove(suggestionId);
    timer?.cancel();
    if (_pendingRejectIds.remove(suggestionId)) {
      notifyListeners();
    }
  }

  // ── Optimistic-Undo: Discard-Filter leeren ──────────────────────────────

  /// Leert den Verworfen-Filter rein lokal und gibt einen Snapshot des
  /// vorherigen Zustands zurück.
  ///
  /// Der DB-DELETE (`clearInboxDismissals`) muss NICHT sofort aufgerufen
  /// werden — die UI zeigt die Dismissals jetzt als nicht mehr aktiv an.
  /// Mit [restoreDismissals] kann der vorherige Zustand wiederhergestellt
  /// werden (Undo, kein DB-Touch).
  ///
  /// Falls kein Undo gedrückt wird, ruft die UI [clearDismissals] auf dem
  /// Provider auf, sobald die SnackBar geschlossen wird.
  ({Set<String> keys, int count}) clearDismissalsOptimistic() {
    final snapshot = (keys: _dismissalKeys, count: _dismissalCount);
    _dismissalKeys = const {};
    _dismissalCount = 0;
    _recomputeViews();
    notifyListeners();
    return snapshot;
  }

  /// Stellt einen vorherigen Dismissal-Snapshot wieder her (Undo nach
  /// [clearDismissalsOptimistic]).
  void restoreDismissals(Set<String> keys, int count) {
    _dismissalKeys = keys;
    _dismissalCount = count;
    _recomputeViews();
    notifyListeners();
  }

  @override
  void dispose() {
    // Alle laufenden pending-reject Timers abbrechen, damit keine
    // DB-Calls nach dispose() mehr gefeuert werden.
    for (final timer in _pendingRejectTimers.values) {
      timer.cancel();
    }
    _pendingRejectTimers.clear();
    _pendingRejectIds.clear();
    super.dispose();
  }

  void clear() {
    // Alle pending-reject Timers abbrechen.
    for (final timer in _pendingRejectTimers.values) {
      timer.cancel();
    }
    _pendingRejectTimers.clear();
    _pendingRejectIds.clear();

    _accounts = [];
    _suggestionsRaw = [];
    _suggestions = [];
    _recentRaw = [];
    _recent = [];
    _dismissalKeys = const {};
    _dismissalCount = 0;
    _readMessageIds = {};
    _shopFilter = null;
    _statusFilter = null;
    _lastError = null;
    _initialLoadAttempted = false;
    notifyListeners();
  }
}
