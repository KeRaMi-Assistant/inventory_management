import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_entry.dart';
import '../models/buyer.dart';
import '../models/carrier_credential.dart';
import '../models/deal.dart';
import '../models/deal_comment.dart';
import '../models/inbox_message.dart';
import '../models/inventory_batch.dart';
import '../models/inventory_item.dart';
import '../models/mailbox_account.dart';
import '../models/shop.dart';
import '../models/supplier.dart';
import '../models/ticket.dart';

/// Snapshot of all data for the currently signed-in user, used to seed the
/// in-memory provider after login.
class CloudSnapshot {
  final List<Deal> deals;
  final List<Buyer> buyers;
  final List<Shop> shops;
  final List<Supplier> suppliers;
  final List<InventoryItem> inventoryItems;
  final List<InventoryMovement> movements;
  final List<ActivityEntry> activities;
  final List<Ticket> tickets;

  const CloudSnapshot({
    required this.deals,
    required this.buyers,
    required this.shops,
    required this.suppliers,
    required this.inventoryItems,
    required this.movements,
    required this.activities,
    this.tickets = const [],
  });

  bool get isEmpty =>
      deals.isEmpty &&
      buyers.isEmpty &&
      shops.isEmpty &&
      suppliers.isEmpty &&
      inventoryItems.isEmpty &&
      movements.isEmpty &&
      activities.isEmpty &&
      tickets.isEmpty;
}

/// Single point of contact with the Supabase backend. All RLS-scoped tables
/// expose typed CRUD methods returning domain models so the rest of the app
/// stays unaware of `supabase_flutter`.
///
/// Daten sind seit Migration `20260504000500_data_workspace_scope` per
/// Workspace gescoped. Vor jedem Load/Insert muss [setActiveWorkspace] mit
/// der ID des aktiven Workspaces aufgerufen worden sein. RLS würde die
/// Inserts ohnehin auf Mitgliedschaft prüfen, der explizite eq()-Filter
/// hier ist Performance-Optimierung + macht den Scope explizit.
class SupabaseRepository {
  SupabaseRepository(SupabaseClient client) : _clientOrNull = client;

  /// Konstruktor für Tests: Subklassen überschreiben alle relevanten Methoden
  /// und rufen `_client` niemals auf. Nie in Produktion verwenden.
  SupabaseRepository.forTesting() : _clientOrNull = null;

  final SupabaseClient? _clientOrNull;

  SupabaseClient get _client {
    final c = _clientOrNull;
    if (c == null) {
      throw StateError(
        'SupabaseRepository.forTesting: _client darf nicht aufgerufen werden '
        '— alle Methoden müssen in der Test-Subklasse überschrieben werden.',
      );
    }
    return c;
  }

  String? _workspaceId;

  /// Setzt den aktiven Workspace, an den Inserts/Loads gehen. `null` deaktiviert
  /// alle Operationen (loadAll liefert leeren Snapshot, Inserts werfen).
  void setActiveWorkspace(String? workspaceId) {
    _workspaceId = workspaceId;
  }

  /// Liefert die aktuell gesetzte Workspace-ID oder `null`, wenn kein
  /// Workspace aktiv ist. Wird von Providern benötigt, die die ID kennen
  /// müssen, ohne einen Fehler auslösen zu wollen.
  String? get activeWorkspaceId => _workspaceId;

  String get _wsId {
    final id = _workspaceId;
    if (id == null) {
      throw StateError(
          'SupabaseRepository: kein aktiver Workspace gesetzt. '
          'Vor Datenoperationen setActiveWorkspace(...) aufrufen.');
    }
    return id;
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('SupabaseRepository requires an authenticated user.');
    }
    return id;
  }

  // ── Bulk load ─────────────────────────────────────────────────────────────

  Future<CloudSnapshot> loadAll() async {
    final ws = _workspaceId;
    if (ws == null) {
      return const CloudSnapshot(
        deals: [],
        buyers: [],
        shops: [],
        suppliers: [],
        inventoryItems: [],
        movements: [],
        activities: [],
        tickets: [],
      );
    }
    final results = await Future.wait([
      _client
          .from('deals')
          .select()
          .eq('workspace_id', ws)
          .filter('deleted_at', 'is', null)
          .order('id', ascending: true),
      _client
          .from('buyers')
          .select()
          .eq('workspace_id', ws)
          .filter('deleted_at', 'is', null)
          .order('sort_order', ascending: true),
      _client
          .from('shops')
          .select()
          .eq('workspace_id', ws)
          .filter('deleted_at', 'is', null)
          .order('name', ascending: true),
      _client
          .from('suppliers')
          .select()
          .eq('workspace_id', ws)
          .filter('deleted_at', 'is', null)
          .order('name', ascending: true),
      _client
          .from('inventory_items')
          .select()
          .eq('workspace_id', ws)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: true),
      _client
          .from('inventory_movements')
          .select()
          .eq('workspace_id', ws)
          .order('date', ascending: false),
      _client
          .from('activity_log')
          .select()
          .eq('workspace_id', ws)
          .order('date', ascending: false)
          .limit(50),
      _client
          .from('tickets')
          .select()
          .eq('workspace_id', ws)
          .order('created_at', ascending: false),
    ]);

    final dealRows = (results[0] as List).cast<Map<String, dynamic>>();
    final buyerRows = (results[1] as List).cast<Map<String, dynamic>>();
    final shopRows = (results[2] as List).cast<Map<String, dynamic>>();
    final supplierRows = (results[3] as List).cast<Map<String, dynamic>>();
    final itemRows = (results[4] as List).cast<Map<String, dynamic>>();
    final movementRows = (results[5] as List).cast<Map<String, dynamic>>();
    final activityRows = (results[6] as List).cast<Map<String, dynamic>>();
    final ticketRows = (results[7] as List).cast<Map<String, dynamic>>();

    final inventoryItems =
        itemRows.map(InventoryItem.fromSupabase).toList();

    final byDealId = <int, List<String>>{};
    for (final item in inventoryItems) {
      if (item.dealId != null) {
        byDealId.putIfAbsent(item.dealId!, () => []).add(item.id);
      }
    }

    final deals = dealRows
        .map((row) => Deal.fromSupabase(
              row,
              inventoryItemIds:
                  byDealId[(row['id'] as num).toInt()] ?? const [],
            ))
        .toList();

    return CloudSnapshot(
      deals: deals,
      buyers: buyerRows.map(Buyer.fromSupabase).toList(),
      shops: shopRows.map(Shop.fromSupabase).toList(),
      suppliers: supplierRows.map(Supplier.fromSupabase).toList(),
      inventoryItems: inventoryItems,
      movements:
          movementRows.map(InventoryMovement.fromSupabase).toList(),
      activities: activityRows.map(ActivityEntry.fromSupabase).toList(),
      tickets: ticketRows.map(Ticket.fromSupabase).toList(),
    );
  }

  // ── Deals ─────────────────────────────────────────────────────────────────

  Future<Deal> insertDeal(Deal deal) async {
    final payload = deal.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('deals')
        .insert(payload)
        .select()
        .single();
    return Deal.fromSupabase(row, inventoryItemIds: deal.inventoryItemIds);
  }

  Future<List<Deal>> insertDeals(List<Deal> deals) async {
    if (deals.isEmpty) return const [];
    final ws = _wsId;
    final payload = deals
        .map((d) => d.toSupabaseInsert()
          ..['user_id'] = _userId
          ..['workspace_id'] = ws)
        .toList();
    final rows = await _client.from('deals').insert(payload).select();
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => Deal.fromSupabase(r))
        .toList();
  }

  Future<Deal> updateDeal(Deal deal) async {
    final payload = deal.toSupabaseInsert();
    final row = await _client
        .from('deals')
        .update(payload)
        .eq('id', deal.id)
        .select()
        .single();
    return Deal.fromSupabase(row, inventoryItemIds: deal.inventoryItemIds);
  }

  Future<void> updateDealsStatus(Iterable<int> ids, String status) async {
    if (ids.isEmpty) return;
    await _client
        .from('deals')
        .update({'status': status})
        .inFilter('id', ids.toList());
  }

  Future<void> updateDealsBuyer(Iterable<int> ids, String? buyer) async {
    if (ids.isEmpty) return;
    await _client
        .from('deals')
        .update({'buyer': buyer})
        .inFilter('id', ids.toList());
  }

  /// Bulk-Update: setzt Ticketnummer und/oder URL auf allen [ids]. Werte
  /// sind optional, `null` bedeutet "nicht ändern", Leerstring bedeutet "leeren".
  Future<void> updateDealsTicket(
    Iterable<int> ids, {
    String? ticketNumber,
    String? ticketUrl,
  }) async {
    if (ids.isEmpty) return;
    final payload = <String, dynamic>{};
    if (ticketNumber != null) {
      payload['ticket_number'] =
          ticketNumber.trim().isEmpty ? null : ticketNumber.trim();
    }
    if (ticketUrl != null) {
      payload['ticket_url'] =
          ticketUrl.trim().isEmpty ? null : ticketUrl.trim();
    }
    if (payload.isEmpty) return;
    await _client
        .from('deals')
        .update(payload)
        .inFilter('id', ids.toList());
  }

  Future<void> deleteDeal(int id) async {
    await _client
        .from('deals')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> deleteDeals(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from('deals')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids.toList());
  }

  // ── Tickets ───────────────────────────────────────────────────────────────

  /// Lädt Tickets eines Workspace, optional gefiltert nach Archiv-Status.
  /// `archived = null` lädt alle, `true` nur archivierte, `false` nur aktive.
  Future<List<Ticket>> loadTickets({bool? archived}) async {
    final ws = _workspaceId;
    if (ws == null) return const [];
    final query =
        _client.from('tickets').select().eq('workspace_id', ws);
    final filtered = switch (archived) {
      null => query,
      true => query.not('archived_at', 'is', null),
      false => query.filter('archived_at', 'is', null),
    };
    final rows = await filtered.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Ticket.fromSupabase)
        .toList();
  }

  /// Manuelles Archivieren. Trigger setzen `archived_at` automatisch via
  /// reasons `all_done` / `all_shipped` / `inventory_sold`; dieser Pfad
  /// nutzt zwingend `manual` und ist für User-Aktionen gedacht.
  Future<Ticket> archiveTicket(int ticketId, {String reason = 'manual'}) async {
    final row = await _client
        .from('tickets')
        .update({
          'archived_at': DateTime.now().toUtc().toIso8601String(),
          'archived_reason': reason,
          'archived_by': _userId,
        })
        .eq('id', ticketId)
        .select()
        .single();
    return Ticket.fromSupabase(row);
  }

  /// Reopen: setzt archived_at + archived_reason + archived_by zurück. Der
  /// CHECK-Constraint `tickets_archived_pair_chk` verlangt, dass beide
  /// Felder gemeinsam null werden.
  Future<Ticket> reopenTicket(int ticketId) async {
    final row = await _client
        .from('tickets')
        .update({
          'archived_at': null,
          'archived_reason': null,
          'archived_by': null,
        })
        .eq('id', ticketId)
        .select()
        .single();
    return Ticket.fromSupabase(row);
  }

  // ── Buyers ────────────────────────────────────────────────────────────────

  Future<Buyer> insertBuyer(Buyer buyer) async {
    final payload = buyer.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('buyers')
        .insert(payload)
        .select()
        .single();
    return Buyer.fromSupabase(row);
  }

  Future<Buyer> updateBuyer(Buyer buyer) async {
    final payload = buyer.toSupabaseInsert();
    final row = await _client
        .from('buyers')
        .update(payload)
        .eq('id', buyer.id)
        .select()
        .single();
    return Buyer.fromSupabase(row);
  }

  Future<void> deleteBuyer(String id) async {
    await _client
        .from('buyers')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Shops ─────────────────────────────────────────────────────────────────

  Future<Shop> insertShop(Shop shop) async {
    final payload = shop.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('shops')
        .insert(payload)
        .select()
        .single();
    return Shop.fromSupabase(row);
  }

  Future<Shop> updateShop(Shop shop) async {
    final payload = shop.toSupabaseInsert();
    final row = await _client
        .from('shops')
        .update(payload)
        .eq('id', shop.id)
        .select()
        .single();
    return Shop.fromSupabase(row);
  }

  Future<void> deleteShop(String id) async {
    await _client
        .from('shops')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Suppliers ─────────────────────────────────────────────────────────────

  Future<Supplier> insertSupplier(Supplier supplier) async {
    final payload = supplier.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('suppliers')
        .insert(payload)
        .select()
        .single();
    return Supplier.fromSupabase(row);
  }

  Future<Supplier> updateSupplier(Supplier supplier) async {
    final payload = supplier.toSupabaseInsert();
    final row = await _client
        .from('suppliers')
        .update(payload)
        .eq('id', supplier.id)
        .select()
        .single();
    return Supplier.fromSupabase(row);
  }

  Future<void> deleteSupplier(String id) async {
    await _client
        .from('suppliers')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Inventory items ───────────────────────────────────────────────────────

  Future<InventoryItem> insertInventoryItem(InventoryItem item) async {
    final payload = item.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('inventory_items')
        .insert(payload)
        .select()
        .single();
    return InventoryItem.fromSupabase(row);
  }

  Future<InventoryItem> updateInventoryItem(InventoryItem item) async {
    final payload = item.toSupabaseInsert();
    final row = await _client
        .from('inventory_items')
        .update(payload)
        .eq('id', item.id)
        .select()
        .single();
    return InventoryItem.fromSupabase(row);
  }

  Future<void> deleteInventoryItem(String id) async {
    await _client
        .from('inventory_items')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Inventory movements ───────────────────────────────────────────────────

  Future<InventoryMovement> insertMovement(InventoryMovement movement) async {
    final payload = movement.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('inventory_movements')
        .insert(payload)
        .select()
        .single();
    return InventoryMovement.fromSupabase(row);
  }

  // ── Inventory batches ─────────────────────────────────────────────────────

  Future<List<InventoryBatch>> loadBatchesForItem(String itemId) async {
    final rows = await _client
        .from('inventory_batches')
        .select()
        .eq('item_id', itemId)
        .filter('deleted_at', 'is', null)
        .order('mhd', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InventoryBatch.fromSupabase)
        .toList();
  }

  Future<List<InventoryBatch>> loadAllBatches() async {
    final ws = _workspaceId;
    if (ws == null) return const [];
    final rows = await _client
        .from('inventory_batches')
        .select()
        .eq('workspace_id', ws)
        .filter('deleted_at', 'is', null)
        .order('mhd', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InventoryBatch.fromSupabase)
        .toList();
  }

  Future<InventoryBatch> insertBatch(InventoryBatch batch) async {
    final payload = batch.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('inventory_batches')
        .insert(payload)
        .select()
        .single();
    return InventoryBatch.fromSupabase(row);
  }

  Future<InventoryBatch> updateBatch(InventoryBatch batch) async {
    final payload = batch.toSupabaseInsert();
    final row = await _client
        .from('inventory_batches')
        .update(payload)
        .eq('id', batch.id)
        .select()
        .single();
    return InventoryBatch.fromSupabase(row);
  }

  Future<void> deleteBatch(String id) async {
    await _client
        .from('inventory_batches')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Activity log ──────────────────────────────────────────────────────────

  Future<ActivityEntry> insertActivity(ActivityEntry entry) async {
    final payload = entry.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('activity_log')
        .insert(payload)
        .select()
        .single();
    return ActivityEntry.fromSupabase(row);
  }

  // ── Deal comments ────────────────────────────────────────────────────────

  Future<List<DealComment>> loadCommentsForDeal(int dealId) async {
    final rows = await _client
        .from('deal_comments')
        .select()
        .eq('deal_id', dealId)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(DealComment.fromSupabase)
        .toList();
  }

  Future<DealComment> insertComment(DealComment comment) async {
    final payload = comment.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('deal_comments')
        .insert(payload)
        .select()
        .single();
    return DealComment.fromSupabase(row);
  }

  Future<void> deleteComment(String id) async {
    await _client
        .from('deal_comments')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> trimActivityLog({int keep = 50}) async {
    final rows = await _client
        .from('activity_log')
        .select('id')
        .order('date', ascending: false)
        .range(keep, keep + 999);
    final ids = (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['id'] as String)
        .toList();
    if (ids.isEmpty) return;
    await _client.from('activity_log').delete().inFilter('id', ids);
  }

  // ── Mailbox accounts (Sprint 6) ──────────────────────────────────────────

  Future<List<MailboxAccount>> loadMailboxAccounts() async {
    final ws = _workspaceId;
    if (ws == null) return const [];
    final rows = await _client
        .from('mailbox_accounts')
        .select()
        .eq('workspace_id', ws)
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MailboxAccount.fromSupabase)
        .toList();
  }

  /// Legt einen IMAP-Account an und setzt das Passwort über die SECURITY-
  /// DEFINER-RPC. Klartext bleibt nirgends gespeichert.
  Future<MailboxAccount> insertMailboxAccount(
    MailboxAccount account, {
    required String password,
  }) async {
    final payload = account.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('mailbox_accounts')
        .insert(payload)
        .select()
        .single();
    final saved = MailboxAccount.fromSupabase(row);
    await _client.rpc(
      'set_mailbox_password',
      params: {'_account_id': saved.id, '_password': password},
    );
    return saved;
  }

  Future<MailboxAccount> updateMailboxAccount(
    MailboxAccount account, {
    String? newPassword,
  }) async {
    final payload = account.toSupabaseInsert();
    final row = await _client
        .from('mailbox_accounts')
        .update(payload)
        .eq('id', account.id)
        .select()
        .single();
    final saved = MailboxAccount.fromSupabase(row);
    if (newPassword != null && newPassword.isNotEmpty) {
      await _client.rpc(
        'set_mailbox_password',
        params: {'_account_id': saved.id, '_password': newPassword},
      );
    }
    return saved;
  }

  Future<void> deleteMailboxAccount(String id) async {
    await _client.from('mailbox_accounts').delete().eq('id', id);
  }

  /// Triggert die `inbox-poll` Edge Function manuell, statt auf den
  /// 5-Min-Cron-Tick zu warten. Wird nach `insertMailboxAccount` automatisch
  /// gerufen + ist im Inbox-Screen als "Jetzt pollen"-Button exponiert.
  /// Wirft mit Klartext-Message bei Function-Fehlern, damit die UI eine
  /// SnackBar mit Diagnose anzeigen kann.
  Future<InboxPollResult> triggerInboxPoll() async {
    final response = await _client.functions.invoke('inbox-poll');
    if (response.status >= 400) {
      throw StateError(
        'Polling fehlgeschlagen (HTTP ${response.status}). '
        'Pruefe in Supabase Studio: 1) Edge Function "inbox-poll" deployed? '
        '2) pg_cron-Job "inbox-poll-5min" aktiv? 3) IMAP-Credentials korrekt?',
      );
    }
    final data = response.data;
    if (data is Map) {
      final stored = (data['total_stored'] as num?)?.toInt() ?? 0;
      final fetched = (data['total_fetched'] as num?)?.toInt() ?? 0;
      final accounts = (data['accounts_processed'] as num?)?.toInt() ?? 0;
      return InboxPollResult(
        stored: stored,
        fetched: fetched,
        accountsProcessed: accounts,
      );
    }
    return const InboxPollResult(stored: 0, fetched: 0, accountsProcessed: 0);
  }

  // ── Carrier-API-Credentials (Sprint 7) ───────────────────────────────────

  /// Lädt die maskierten Credentials aller Carrier des aktiven Workspaces
  /// via SECURITY-DEFINER-RPC. Klartext bleibt serverseitig.
  Future<List<CarrierCredential>> loadCarrierCredentials() async {
    final ws = _workspaceId;
    if (ws == null) return const [];
    final rows = await _client.rpc(
      'list_carrier_credentials',
      params: {'_workspace_id': ws},
    );
    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(CarrierCredential.fromSupabase)
        .toList();
  }

  /// Setzt einen API-Key für [carrierId] im aktiven Workspace. Validierung
  /// (Mindestlänge, Carrier-Whitelist) macht die RPC.
  Future<void> setCarrierApiKey({
    required String carrierId,
    required String apiKey,
  }) async {
    final ws = _wsId;
    await _client.rpc(
      'set_carrier_api_key',
      params: {
        '_workspace_id': ws,
        '_carrier_id': carrierId,
        '_api_key': apiKey,
      },
    );
  }

  /// Entfernt den gespeicherten API-Key für [carrierId] im aktiven Workspace.
  Future<void> deleteCarrierApiKey(String carrierId) async {
    final ws = _wsId;
    await _client.rpc(
      'delete_carrier_api_key',
      params: {
        '_workspace_id': ws,
        '_carrier_id': carrierId,
      },
    );
  }

  // ── Parsed messages / suggestions ────────────────────────────────────────

  /// Inbox-Sichtbarkeit: 30 Tage rolling, deckt sich mit dem DB-Cleanup-
  /// Cron. Server-side Filter spart Bytes, der UI-Countdown sagt dem User
  /// wie lange ein Eintrag noch sichtbar ist.
  static const _inboxVisibilityDays = 30;

  static String _isoCutoff(int daysBack) =>
      DateTime.now().toUtc().subtract(Duration(days: daysBack)).toIso8601String();

  Future<List<ParsedMessage>> loadParsedMessages({
    Set<ParsedMessageStatus>? statuses,
    int limit = 100,
    int daysBack = _inboxVisibilityDays,
  }) async {
    final ws = _workspaceId;
    if (ws == null) return const [];
    final filterValues = (statuses ?? const {})
        .map((s) => s.name)
        .toList();
    var query = _client
        .from('parsed_messages')
        .select()
        .eq('workspace_id', ws)
        .gte('received_at', _isoCutoff(daysBack));
    if (filterValues.isNotEmpty) {
      query = query.inFilter('status', filterValues);
    }
    final rows = await query
        .order('received_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ParsedMessage.fromSupabase)
        .toList();
  }

  Future<List<PendingDealSuggestion>> loadPendingSuggestions({
    bool unresolvedOnly = true,
    int limit = 100,
    int daysBack = _inboxVisibilityDays,
  }) async {
    final ws = _workspaceId;
    if (ws == null) return const [];
    final cutoff = _isoCutoff(daysBack);
    var query = _client
        .from('pending_deal_suggestions')
        .select()
        .eq('workspace_id', ws)
        // received_at fehlt nur bei Pre-Migration-Daten — mit gte+or
        // bekommen wir beide Fälle.
        .or('received_at.gte.$cutoff,and(received_at.is.null,created_at.gte.$cutoff)');
    if (unresolvedOnly) {
      query = query.filter('resolved_at', 'is', null);
    }
    final rows = await query
        .order('received_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PendingDealSuggestion.fromSupabase)
        .toList();
  }

  Future<void> markSuggestionResolved(
    String suggestionId, {
    required String action,
    int? createdDealId,
  }) async {
    await _client
        .from('pending_deal_suggestions')
        .update({
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'resolved_action': action,
          'created_deal_id': ?createdDealId,
        })
        .eq('id', suggestionId);
  }

  /// User-getriggert: Mail "wegwerfen". Bleibt im Audit, taucht im UI nicht
  /// mehr auf.
  Future<void> dismissParsedMessage(String id) async {
    await _client
        .from('parsed_messages')
        .update({
          'status': 'dismissed',
          'processed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  // ── Inbox dismissals (persistent ignore-list) ────────────────────────────

  /// Persistente Dismiss-Marke. Wenn (shopKey, orderId) gesetzt sind, werden
  /// auch zukünftige Mails zur selben Bestellung ignoriert. Ohne Order-Schlüssel
  /// wirkt der Dismiss nur auf die einzelne parsed_message_id.
  ///
  /// Wir nutzen einen plain INSERT (kein UPSERT), weil unsere Unique-
  /// Indexes partial sind (nur wo die Schlüssel-Spalten NOT NULL sind) —
  /// PostgREST findet bei `ON CONFLICT` keinen passenden Constraint.
  /// Duplikate werden über 23505 abgefangen, das Verhalten ist ohnehin
  /// idempotent ("schon dismissed → kein Fehler nötig").
  Future<void> insertInboxDismissal({
    String? shopKey,
    String? orderId,
    String? parsedMessageId,
    required DateTime receivedAt,
  }) async {
    final hasOrder = shopKey != null && orderId != null && orderId.isNotEmpty;
    if (!hasOrder && parsedMessageId == null) return;
    final ws = _wsId;
    final payload = {
      'workspace_id': ws,
      'shop_key': hasOrder ? shopKey : null,
      'order_id': hasOrder ? orderId : null,
      'parsed_message_id': hasOrder ? null : parsedMessageId,
      'received_at': receivedAt.toUtc().toIso8601String(),
    };
    try {
      await _client.from('inbox_dismissals').insert(payload);
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already dismissed
      rethrow;
    }
  }

  Future<List<InboxDismissal>> loadInboxDismissals() async {
    final ws = _workspaceId;
    if (ws == null) return const [];
    final rows = await _client
        .from('inbox_dismissals')
        .select('shop_key, order_id, parsed_message_id')
        .eq('workspace_id', ws);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InboxDismissal.fromSupabase)
        .toList();
  }

  Future<void> clearInboxDismissals() async {
    final ws = _workspaceId;
    if (ws == null) return;
    await _client.from('inbox_dismissals').delete().eq('workspace_id', ws);
  }

  // ── Inbox reads (pro-User Lese-Status) ───────────────────────────────────

  /// Lädt die Set der bereits gelesenen parsed_message_ids für den
  /// eingeloggten User. RLS auf `inbox_reads` filtert automatisch auf
  /// `read_by = auth.uid()` — kein expliziter Filter nötig.
  Future<Set<String>> loadInboxReads({required String workspaceId}) async {
    final rows = await _client
        .from('inbox_reads')
        .select('parsed_message_id')
        .eq('workspace_id', workspaceId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['parsed_message_id'] as String)
        .toSet();
  }

  /// Ruft die RPC `mark_all_inbox_read` auf, die alle aktuell sichtbaren
  /// parsed_messages des Workspace als gelesen markiert (rolling 30-Tage-
  /// Fenster). Gibt die Anzahl neu inserierter Read-Marker zurück.
  /// Idempotent via `ON CONFLICT DO NOTHING`.
  Future<int> markAllInboxRead({required String workspaceId}) async {
    final result = await _client.rpc(
      'mark_all_inbox_read',
      params: {'_workspace_id': workspaceId},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  /// User wendet Tracking + (optional) Carrier + ETA aus einer Mail auf
  /// einen bestehenden Deal an, ohne neuen Deal anzulegen. Markiert die
  /// Mail als matched + verlinkt sie mit dem Deal.
  Future<void> applyTrackingToDeal({
    required String parsedMessageId,
    required int dealId,
    required String tracking,
    String? carrier,
    DateTime? eta,
    String? statusOverride,
  }) async {
    final dealUpdate = <String, dynamic>{'tracking': tracking};
    if (eta != null) {
      dealUpdate['arrival_date'] = eta.toUtc().toIso8601String();
    }
    if (statusOverride != null) {
      dealUpdate['status'] = statusOverride;
    } else {
      dealUpdate['status'] = 'Unterwegs';
    }
    await _client.from('deals').update(dealUpdate).eq('id', dealId);
    await _client
        .from('parsed_messages')
        .update({
          'status': 'matched',
          'match_deal_id': dealId,
          'processed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', parsedMessageId);
  }

  /// Verlinkt eine offene Suggestion mit einem bestehenden Deal — der
  /// User sagt: "das gehört zu Deal #X". Suggestion wird resolved (accepted),
  /// `match_deal_id` auf der zugehörigen parsed_message gesetzt, und falls
  /// Tracking/ETA in der Suggestion vorhanden waren, werden sie auf den
  /// Deal übernommen.
  Future<void> linkSuggestionToExistingDeal({
    required String suggestionId,
    required String parsedMessageId,
    required int dealId,
    String? tracking,
    String? orderId,
    DateTime? eta,
  }) async {
    final dealUpdate = <String, dynamic>{};
    if (tracking != null && tracking.isNotEmpty) {
      dealUpdate['tracking'] = tracking;
      dealUpdate['status'] = 'Unterwegs';
    }
    if (eta != null) {
      dealUpdate['arrival_date'] = eta.toUtc().toIso8601String();
    }
    if (orderId != null && orderId.isNotEmpty) {
      dealUpdate['ticket_number'] = orderId;
    }
    if (dealUpdate.isNotEmpty) {
      await _client.from('deals').update(dealUpdate).eq('id', dealId);
    }
    await _client
        .from('pending_deal_suggestions')
        .update({
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'resolved_action': 'accepted',
          'created_deal_id': dealId,
        })
        .eq('id', suggestionId);
    await _client
        .from('parsed_messages')
        .update({
          'status': 'matched',
          'match_deal_id': dealId,
          'processed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', parsedMessageId);
  }
}

/// Rückgabe von [SupabaseRepository.triggerInboxPoll]. Felder enthalten die
/// Aggregat-Statistik aus der `inbox-poll`-Edge-Function.
class InboxPollResult {
  final int stored;
  final int fetched;
  final int accountsProcessed;
  const InboxPollResult({
    required this.stored,
    required this.fetched,
    required this.accountsProcessed,
  });
}
