import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Lädt die Demo-Daten-Fixture aus `assets/demo_data.json` und seedet sie
/// in den aktiven Workspace. Alle eingefügten Rows werden mit `is_demo=true`
/// markiert, sodass [wipeDemoData] sie selektiv entfernen kann, ohne echte
/// User-Daten anzufassen.
class DemoDataService {
  DemoDataService(this._client, {String assetPath = 'assets/demo_data.json'})
      : _assetPath = assetPath;

  final SupabaseClient _client;
  final String _assetPath;
  static const _uuid = Uuid();

  /// Liest die Fixture und legt buyers/shops/suppliers/tickets/items/deals
  /// im angegebenen Workspace an. Rückgabe: Anzahl der Inserts pro Tabelle.
  Future<DemoSeedResult> loadDemoData({required String workspaceId}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('DemoDataService.loadDemoData: kein eingeloggter User.');
    }
    final raw = await rootBundle.loadString(_assetPath);
    final fixture = json.decode(raw) as Map<String, dynamic>;

    final buyersIn = (fixture['buyers'] as List).cast<Map<String, dynamic>>();
    final shopsIn = (fixture['shops'] as List).cast<Map<String, dynamic>>();
    final suppliersIn =
        (fixture['suppliers'] as List).cast<Map<String, dynamic>>();
    final ticketsIn =
        (fixture['tickets'] as List).cast<Map<String, dynamic>>();
    final itemsIn =
        (fixture['inventory_items'] as List).cast<Map<String, dynamic>>();
    final dealsIn = (fixture['deals'] as List).cast<Map<String, dynamic>>();

    // Buyers
    final buyersPayload = buyersIn
        .map((b) => {
              'id': _uuid.v4(),
              'workspace_id': workspaceId,
              'user_id': user.id,
              'name': b['name'],
              'row_fill_color': b['row_fill_color'],
              'buyer_cell_color': b['buyer_cell_color'],
              'font_color': b['font_color'],
              'sort_order': b['sort_order'],
              'active': b['active'] ?? true,
              'discord_server_ids': b['discord_server_ids'] ?? const [],
              'payment_status': b['payment_status'] ?? 'OK',
              'is_demo': true,
            })
        .toList();
    final buyersOut = await _insert('buyers', buyersPayload, 'name');

    // Shops
    final shopsPayload = shopsIn
        .map((s) => {
              'id': _uuid.v4(),
              'workspace_id': workspaceId,
              'user_id': user.id,
              'name': s['name'],
              'region': s['region'] ?? '',
              'channel': s['channel'] ?? '',
              'active': s['active'] ?? true,
              'is_demo': true,
            })
        .toList();
    final shopsOut = await _insert('shops', shopsPayload, 'name');

    // Suppliers
    final suppliersPayload = suppliersIn
        .map((s) => {
              'id': _uuid.v4(),
              'workspace_id': workspaceId,
              'user_id': user.id,
              'name': s['name'],
              'contact_name': s['contact_name'],
              'email': s['email'],
              'phone': s['phone'],
              'website': s['website'],
              'note': s['note'],
              'active': s['active'] ?? true,
              'is_demo': true,
            })
        .toList();
    final suppliersOut = await _insert('suppliers', suppliersPayload, 'name');
    final supplierIdByIdx = <int, String>{
      for (var i = 0; i < suppliersOut.length; i++)
        i: suppliersOut[i]['id'] as String,
    };

    // Tickets
    final ticketsPayload = ticketsIn
        .map((t) => {
              'workspace_id': workspaceId,
              'ticket_number': t['ticket_number'],
              'is_demo': true,
            })
        .toList();
    final ticketsOut =
        await _insert('tickets', ticketsPayload, 'id, ticket_number');
    final ticketNumberByIdx = <int, String>{
      for (var i = 0; i < ticketsOut.length; i++)
        i: ticketsOut[i]['ticket_number'] as String,
    };

    // Products (Stammkatalog) — optional: überspringen, wenn die Tabelle noch
    // nicht existiert (schema-additive, kein Hard-Fail).
    // productIdByIdx[i] → UUID des angelegten Produkts für itemsIn[i].
    final productIdByIdx = <int, String>{};
    try {
      final productsPayload = <Map<String, dynamic>>[];
      for (var i = 0; i < itemsIn.length; i++) {
        final it = itemsIn[i];
        final supplierIdx = it['supplier_idx'] as int? ?? 0;
        final productId = _uuid.v4();
        productsPayload.add({
          'id': productId,
          'workspace_id': workspaceId,
          'user_id': user.id,
          'name': it['name'] as String,
          'sku': it['sku'] as String?,
          'default_cost_price': it['cost_price'],
          'default_sale_price': it['cost_price'] != null
              ? (((it['cost_price'] as num) * 1.25 * 100).round() / 100)
              : null,
          'default_supplier_id': supplierIdByIdx[supplierIdx],
          'min_stock': it['min_stock'] ?? 0,
          'is_active': true,
          'is_demo': true,
        });
        productIdByIdx[i] = productId;
      }
      await _insert('products', productsPayload, 'id');
    } catch (_) {
      // products-Tabelle existiert noch nicht — additive, kein Hard-Fail.
      productIdByIdx.clear();
    }

    // Inventory items
    final itemsPayload = <Map<String, dynamic>>[];
    for (var idx = 0; idx < itemsIn.length; idx++) {
      final it = itemsIn[idx];
      final supplierIdx = it['supplier_idx'] as int? ?? 0;
      final row = <String, dynamic>{
        'id': _uuid.v4(),
        'workspace_id': workspaceId,
        'user_id': user.id,
        'name': it['name'],
        'sku': it['sku'],
        'quantity': it['quantity'] ?? 0,
        'min_stock': it['min_stock'] ?? 0,
        'location': it['location'],
        'cost_price': it['cost_price'],
        'arrival_date': null,
        'supplier_id': supplierIdByIdx[supplierIdx],
        'note': 'Demo-Lagerartikel',
        'status': 'Im Lager',
        'is_demo': true,
      };
      // Verlinkung auf Produktstamm (additive, nullable)
      if (productIdByIdx.containsKey(idx)) {
        row['product_id'] = productIdByIdx[idx];
      }
      itemsPayload.add(row);
    }
    final itemsOut = await _insert('inventory_items', itemsPayload, 'id');

    // Deals
    final now = DateTime.now().toUtc();
    final dealsPayload = dealsIn.map((d) {
      final shopIdx = d['shop_idx'] as int? ?? 0;
      final buyerIdx = d['buyer_idx'] as int? ?? 0;
      final ticketIdx = d['ticket_idx'] as int?;
      final orderOffset = d['order_offset_days'] as int? ?? 0;
      final orderDate = now.add(Duration(days: orderOffset));
      final shopName = shopIdx < shopsOut.length
          ? shopsOut[shopIdx]['name'] as String
          : (d['product'] as String);
      final buyerName = buyerIdx < buyersOut.length
          ? buyersOut[buyerIdx]['name'] as String?
          : null;
      return {
        'workspace_id': workspaceId,
        'user_id': user.id,
        'product': d['product'],
        'quantity': d['quantity'] ?? 1,
        'is_dropship': d['is_dropship'] ?? false,
        'shop': shopName,
        'order_date': orderDate.toIso8601String(),
        'ek_brutto': d['ek_brutto'],
        'vk': d['vk'],
        'buyer': buyerName,
        'ticket_number':
            ticketIdx != null ? ticketNumberByIdx[ticketIdx] : null,
        'tracking': null,
        'arrival_date': null,
        'status': d['status'] ?? 'Bestellt',
        'has_receipt': d['has_receipt'] ?? false,
        'note': d['note'],
        'tax_rate': d['tax_rate'],
        'currency': d['currency'] ?? 'EUR',
        'is_demo': true,
      };
    }).toList();
    final dealsOut = await _insert('deals', dealsPayload, 'id');

    return DemoSeedResult(
      buyers: buyersOut.length,
      shops: shopsOut.length,
      suppliers: suppliersOut.length,
      tickets: ticketsOut.length,
      products: productIdByIdx.length,
      inventoryItems: itemsOut.length,
      deals: dealsOut.length,
    );
  }

  /// Löscht alle Rows mit `is_demo=true` im angegebenen Workspace.
  /// Reihenfolge: Kinder vor Eltern. RLS schützt vor Cross-Workspace-Wipes;
  /// der zusätzliche `eq('workspace_id', …)` ist defense-in-depth.
  Future<DemoWipeResult> wipeDemoData({required String workspaceId}) async {
    int deals = 0, items = 0, products = 0, tickets = 0, buyers = 0, shops = 0, suppliers = 0;
    deals = await _wipe('deals', workspaceId);
    // inventory_items.product_id → products: items zuerst löschen, dann Stamm.
    items = await _wipe('inventory_items', workspaceId);
    // products optional mitlöschen — graceful bei fehlendem Schema.
    try {
      products = await _wipe('products', workspaceId);
    } catch (_) {
      products = 0;
    }
    tickets = await _wipe('tickets', workspaceId);
    buyers = await _wipe('buyers', workspaceId);
    shops = await _wipe('shops', workspaceId);
    suppliers = await _wipe('suppliers', workspaceId);
    // activity_log defensiv mitlöschen (auto-eingefügte demo-spezifische Logs).
    await _wipe('activity_log', workspaceId);
    return DemoWipeResult(
      deals: deals,
      inventoryItems: items,
      products: products,
      tickets: tickets,
      buyers: buyers,
      shops: shops,
      suppliers: suppliers,
    );
  }

  /// True, wenn der angegebene Workspace mindestens eine `is_demo`-Row hält.
  /// Wird vom Settings-Tab genutzt, um den Wipe-Button nur dann anzuzeigen,
  /// wenn er etwas zu tun hat.
  Future<bool> hasDemoData({required String workspaceId}) async {
    for (final t in const [
      'deals',
      'inventory_items',
      'products',
      'buyers',
      'shops',
      'suppliers',
      'tickets',
    ]) {
      try {
        final rows = await _client
            .from(t)
            .select('workspace_id')
            .eq('workspace_id', workspaceId)
            .eq('is_demo', true)
            .limit(1);
        if ((rows as List).isNotEmpty) return true;
      } catch (_) {
        // Tabelle existiert noch nicht — überspringen.
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _insert(
    String table,
    List<Map<String, dynamic>> rows,
    String returning,
  ) async {
    if (rows.isEmpty) return const [];
    final user = _client.auth.currentUser;
    final firstHasName = rows.first.containsKey('name');

    // Tabellen mit (user_id, lower(name))-Unique-Constraints (shops, buyers,
    // suppliers): existierende Rows mit gleichem Namen NICHT erneut einfügen,
    // sondern als "OK, ist schon da" durchwinken. Sonst stürzt das Onboarding
    // ab wenn der User die App schon einmal benutzt + Shops manuell angelegt
    // hat (siehe shops_user_name_unique on (user_id, lower(name))).
    if (firstHasName && user != null) {
      final existingRes = await _client
          .from(table)
          .select(returning.contains('name') ? returning : '$returning, name')
          .eq('user_id', user.id);
      final existingByName = <String, Map<String, dynamic>>{};
      for (final row in (existingRes as List).cast<Map<String, dynamic>>()) {
        final name = (row['name'] as String?)?.toLowerCase();
        if (name != null) existingByName[name] = row;
      }

      final outputs = List<Map<String, dynamic>?>.filled(rows.length, null);
      final toInsert = <Map<String, dynamic>>[];
      final insertSlots = <int>[];
      for (var i = 0; i < rows.length; i++) {
        final name = (rows[i]['name'] as String?)?.toLowerCase();
        if (name != null && existingByName.containsKey(name)) {
          outputs[i] = existingByName[name];
        } else {
          insertSlots.add(i);
          toInsert.add(rows[i]);
        }
      }
      if (toInsert.isNotEmpty) {
        final res =
            await _client.from(table).insert(toInsert).select(returning);
        final inserted = (res as List).cast<Map<String, dynamic>>();
        for (var j = 0; j < inserted.length && j < insertSlots.length; j++) {
          outputs[insertSlots[j]] = inserted[j];
        }
      }
      return outputs.whereType<Map<String, dynamic>>().toList();
    }

    final res = await _client.from(table).insert(rows).select(returning);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<int> _wipe(String table, String workspaceId) async {
    final res = await _client
        .from(table)
        .delete()
        .eq('workspace_id', workspaceId)
        .eq('is_demo', true)
        .select('workspace_id');
    return (res as List).length;
  }
}

class DemoSeedResult {
  final int buyers;
  final int shops;
  final int suppliers;
  final int tickets;
  final int products;
  final int inventoryItems;
  final int deals;
  const DemoSeedResult({
    required this.buyers,
    required this.shops,
    required this.suppliers,
    required this.tickets,
    required this.products,
    required this.inventoryItems,
    required this.deals,
  });

  int get total =>
      buyers + shops + suppliers + tickets + products + inventoryItems + deals;
}

class DemoWipeResult {
  final int buyers;
  final int shops;
  final int suppliers;
  final int tickets;
  final int products;
  final int inventoryItems;
  final int deals;
  const DemoWipeResult({
    required this.buyers,
    required this.shops,
    required this.suppliers,
    required this.tickets,
    required this.products,
    required this.inventoryItems,
    required this.deals,
  });

  int get total =>
      buyers + shops + suppliers + tickets + products + inventoryItems + deals;
}
