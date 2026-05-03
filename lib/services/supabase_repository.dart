import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_entry.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/inventory_item.dart';
import '../models/shop.dart';

/// Snapshot of all data for the currently signed-in user, used to seed the
/// in-memory provider after login.
class CloudSnapshot {
  final List<Deal> deals;
  final List<Buyer> buyers;
  final List<Shop> shops;
  final List<InventoryItem> inventoryItems;
  final List<InventoryMovement> movements;
  final List<ActivityEntry> activities;

  const CloudSnapshot({
    required this.deals,
    required this.buyers,
    required this.shops,
    required this.inventoryItems,
    required this.movements,
    required this.activities,
  });

  bool get isEmpty =>
      deals.isEmpty &&
      buyers.isEmpty &&
      shops.isEmpty &&
      inventoryItems.isEmpty &&
      movements.isEmpty &&
      activities.isEmpty;
}

/// Single point of contact with the Supabase backend. All RLS-scoped tables
/// expose typed CRUD methods returning domain models so the rest of the app
/// stays unaware of `supabase_flutter`.
class SupabaseRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('SupabaseRepository requires an authenticated user.');
    }
    return id;
  }

  // ── Bulk load ─────────────────────────────────────────────────────────────

  Future<CloudSnapshot> loadAll() async {
    // Soft-Delete-Filter: nur aktive Datensätze laden. Der Papierkorb-View
    // (separater Ladepfad, später) zeigt deleted_at IS NOT NULL.
    final results = await Future.wait([
      _client
          .from('deals')
          .select()
          .filter('deleted_at', 'is', null)
          .order('id', ascending: true),
      _client
          .from('buyers')
          .select()
          .filter('deleted_at', 'is', null)
          .order('sort_order', ascending: true),
      _client
          .from('shops')
          .select()
          .filter('deleted_at', 'is', null)
          .order('name', ascending: true),
      _client
          .from('inventory_items')
          .select()
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: true),
      _client.from('inventory_movements').select().order('date', ascending: false),
      _client
          .from('activity_log')
          .select()
          .order('date', ascending: false)
          .limit(50),
    ]);

    final dealRows = (results[0] as List).cast<Map<String, dynamic>>();
    final buyerRows = (results[1] as List).cast<Map<String, dynamic>>();
    final shopRows = (results[2] as List).cast<Map<String, dynamic>>();
    final itemRows = (results[3] as List).cast<Map<String, dynamic>>();
    final movementRows = (results[4] as List).cast<Map<String, dynamic>>();
    final activityRows = (results[5] as List).cast<Map<String, dynamic>>();

    final inventoryItems =
        itemRows.map(InventoryItem.fromSupabase).toList();

    // Reverse-derive Deal.inventoryItemIds from inventory_items.deal_id.
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
      inventoryItems: inventoryItems,
      movements:
          movementRows.map(InventoryMovement.fromSupabase).toList(),
      activities: activityRows.map(ActivityEntry.fromSupabase).toList(),
    );
  }

  // ── Deals ─────────────────────────────────────────────────────────────────

  Future<Deal> insertDeal(Deal deal) async {
    final payload = deal.toSupabaseInsert()..['user_id'] = _userId;
    final row = await _client
        .from('deals')
        .insert(payload)
        .select()
        .single();
    return Deal.fromSupabase(row, inventoryItemIds: deal.inventoryItemIds);
  }

  Future<List<Deal>> insertDeals(List<Deal> deals) async {
    if (deals.isEmpty) return const [];
    final payload = deals
        .map((d) => d.toSupabaseInsert()..['user_id'] = _userId)
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

  Future<void> deleteDeal(int id) async {
    // Soft-Delete: setzt deleted_at, statt physisch zu löschen.
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

  // ── Buyers ────────────────────────────────────────────────────────────────

  Future<Buyer> insertBuyer(Buyer buyer) async {
    final payload = buyer.toSupabaseInsert()..['user_id'] = _userId;
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
    final payload = shop.toSupabaseInsert()..['user_id'] = _userId;
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

  // ── Inventory items ───────────────────────────────────────────────────────

  Future<InventoryItem> insertInventoryItem(InventoryItem item) async {
    final payload = item.toSupabaseInsert()..['user_id'] = _userId;
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
    final payload = movement.toSupabaseInsert()..['user_id'] = _userId;
    final row = await _client
        .from('inventory_movements')
        .insert(payload)
        .select()
        .single();
    return InventoryMovement.fromSupabase(row);
  }

  // ── Activity log ──────────────────────────────────────────────────────────

  Future<ActivityEntry> insertActivity(ActivityEntry entry) async {
    final payload = entry.toSupabaseInsert()..['user_id'] = _userId;
    final row = await _client
        .from('activity_log')
        .insert(payload)
        .select()
        .single();
    return ActivityEntry.fromSupabase(row);
  }

  /// Trims `activity_log` so we never grow it beyond [keep] entries per user.
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

  // ── Bulk wipe (used before restoring a JSON backup) ───────────────────────

  Future<void> deleteAllForCurrentUser() async {
    final uid = _userId;
    // Order matters: child tables first (FKs cascade, but explicit is safer).
    await _client.from('inventory_movements').delete().eq('user_id', uid);
    await _client.from('inventory_items').delete().eq('user_id', uid);
    await _client.from('activity_log').delete().eq('user_id', uid);
    await _client.from('deals').delete().eq('user_id', uid);
    await _client.from('buyers').delete().eq('user_id', uid);
    await _client.from('shops').delete().eq('user_id', uid);
  }

  // ── Bulk import (used by JSON restore + legacy migration) ─────────────────

  Future<CloudSnapshot> bulkImport({
    required List<Buyer> buyers,
    required List<Shop> shops,
    required List<Deal> deals,
    required List<InventoryItem> items,
    required List<InventoryMovement> movements,
    required List<ActivityEntry> activities,
  }) async {
    final uid = _userId;
    final dealIdMap = <int, int>{};

    if (buyers.isNotEmpty) {
      await _client.from('buyers').insert(
        buyers.map((b) => b.toSupabaseInsert()..['user_id'] = uid).toList(),
      );
    }
    if (shops.isNotEmpty) {
      await _client.from('shops').insert(
        shops.map((s) => s.toSupabaseInsert()..['user_id'] = uid).toList(),
      );
    }

    if (deals.isNotEmpty) {
      // Insert deals one-by-one so we can map old → new BIGSERIAL ids.
      // Items + movements reference deals by id; without the mapping their
      // foreign key would silently dangle.
      for (final deal in deals) {
        final payload = deal.toSupabaseInsert()..['user_id'] = uid;
        final row = await _client
            .from('deals')
            .insert(payload)
            .select('id')
            .single();
        dealIdMap[deal.id] = (row['id'] as num).toInt();
      }
    }

    if (items.isNotEmpty) {
      // Items already carry client-side UUIDs; we keep them so movements
      // resolve via item_id without an extra mapping step.
      final payload = items.map((item) {
        final mappedDealId =
            item.dealId != null ? dealIdMap[item.dealId!] : null;
        return (item.toSupabaseInsert()
          ..['user_id'] = uid
          ..['deal_id'] = mappedDealId);
      }).toList();
      await _client.from('inventory_items').insert(payload);
    }

    if (movements.isNotEmpty) {
      final payload = movements.map((m) {
        final mappedDealId = m.dealId != null ? dealIdMap[m.dealId!] : null;
        return (m.toSupabaseInsert()
          ..['user_id'] = uid
          ..['deal_id'] = mappedDealId);
      }).toList();
      await _client.from('inventory_movements').insert(payload);
    }

    if (activities.isNotEmpty) {
      await _client.from('activity_log').insert(
            activities
                .map((a) => a.toSupabaseInsert()..['user_id'] = uid)
                .toList(),
          );
    }

    return loadAll();
  }
}
