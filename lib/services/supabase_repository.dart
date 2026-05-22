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
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/product_stock.dart';
import '../models/product_supplier.dart';
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
  final List<ProductCategory> productCategories;

  /// Artikelstamm (Epic A-full). Lazy-Detail-Tabellen wie `product_suppliers`
  /// und `product_stock` sind NICHT im globalen Snapshot — sie werden
  /// on-demand pro Detail-Screen geladen (Committee-Empfehlung 1).
  final List<Product> products;

  const CloudSnapshot({
    required this.deals,
    required this.buyers,
    required this.shops,
    required this.suppliers,
    required this.inventoryItems,
    required this.movements,
    required this.activities,
    this.tickets = const [],
    this.productCategories = const [],
    this.products = const [],
  });

  bool get isEmpty =>
      deals.isEmpty &&
      buyers.isEmpty &&
      shops.isEmpty &&
      suppliers.isEmpty &&
      inventoryItems.isEmpty &&
      movements.isEmpty &&
      activities.isEmpty &&
      tickets.isEmpty &&
      productCategories.isEmpty &&
      products.isEmpty;
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
        productCategories: [],
        products: [],
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
      _client
          .from('product_categories')
          .select()
          .eq('workspace_id', ws)
          .filter('deleted_at', 'is', null)
          .order('sort_order', ascending: true),
      _client
          .from('products')
          .select()
          .eq('workspace_id', ws)
          .filter('deleted_at', 'is', null)
          .order('name', ascending: true),
    ]);

    final dealRows = (results[0] as List).cast<Map<String, dynamic>>();
    final buyerRows = (results[1] as List).cast<Map<String, dynamic>>();
    final shopRows = (results[2] as List).cast<Map<String, dynamic>>();
    final supplierRows = (results[3] as List).cast<Map<String, dynamic>>();
    final itemRows = (results[4] as List).cast<Map<String, dynamic>>();
    final movementRows = (results[5] as List).cast<Map<String, dynamic>>();
    final activityRows = (results[6] as List).cast<Map<String, dynamic>>();
    final ticketRows = (results[7] as List).cast<Map<String, dynamic>>();
    final categoryRows = (results[8] as List).cast<Map<String, dynamic>>();
    final productRows = (results[9] as List).cast<Map<String, dynamic>>();

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
      productCategories:
          categoryRows.map(ProductCategory.fromSupabase).toList(),
      products: productRows.map(Product.fromSupabase).toList(),
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

  // ── Product categories ────────────────────────────────────────────────────

  /// Lädt alle aktiven Kategorien des Workspaces, sortiert nach `sort_order`.
  Future<List<ProductCategory>> loadProductCategories(
      String workspaceId) async {
    final rows = await _client
        .from('product_categories')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('deleted_at', 'is', null)
        .order('sort_order', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ProductCategory.fromSupabase)
        .toList();
  }

  Future<ProductCategory> insertProductCategory(
      ProductCategory category) async {
    final payload = category.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('product_categories')
        .insert(payload)
        .select()
        .single();
    return ProductCategory.fromSupabase(row);
  }

  Future<ProductCategory> updateProductCategory(
      ProductCategory category) async {
    final payload = category.toSupabaseInsert();
    final row = await _client
        .from('product_categories')
        .update(payload)
        .eq('id', category.id)
        .select()
        .single();
    return ProductCategory.fromSupabase(row);
  }

  /// Soft-Delete: setzt `deleted_at` auf die aktuelle UTC-Zeit (konsistent
  /// mit dem Pattern aller anderen workspace-scoped Entitäten in diesem
  /// Repository — kein Hard-Delete).
  Future<void> deleteProductCategory(String id) async {
    await _client
        .from('product_categories')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Products (Artikelstamm) ───────────────────────────────────────────────

  /// Lädt alle aktiven Artikel-Stammsätze des Workspaces, sortiert nach Name.
  /// Analog `loadProductCategories` — filtert `deleted_at IS NULL`.
  Future<List<Product>> loadProducts(String workspaceId) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Product.fromSupabase)
        .toList();
  }

  Future<Product> insertProduct(Product product) async {
    final payload = product.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('products')
        .insert(payload)
        .select()
        .single();
    return Product.fromSupabase(row);
  }

  Future<Product> updateProduct(Product product) async {
    final payload = product.toSupabaseInsert();
    final row = await _client
        .from('products')
        .update(payload)
        .eq('id', product.id)
        .select()
        .single();
    return Product.fromSupabase(row);
  }

  /// Soft-Delete: setzt `deleted_at` auf die aktuelle UTC-Zeit.
  /// Bestands-Rows (`inventory_items`) mit dieser `product_id` behalten die
  /// Referenz — der FK ist `ON DELETE SET NULL`, d. h. die DB setzt
  /// `product_id` nur beim Hard-Delete; unser Soft-Delete lässt die Items
  /// unverändert. Konsistent mit dem allgemeinen Soft-Delete-Pattern.
  Future<void> deleteProduct(String id) async {
    await _client
        .from('products')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Product suppliers (lazy — nur pro Detail-Screen) ─────────────────────
  //
  // `product_suppliers` ist eine Detail-Tabelle (n:m, pro Produkt wenige Rows).
  // Sie wird NICHT in `loadAll()`/`CloudSnapshot` aufgenommen (Committee-
  // Empfehlung 1 — Detail-Tabellen lazy laden). Pattern analog
  // `loadBatchesForItem`.

  /// Lädt alle aktiven Lieferanten-Zuordnungen eines Produkts.
  /// Lazy: wird pro `product_detail_screen` on-demand aufgerufen.
  Future<List<ProductSupplier>> loadProductSuppliers(
    String workspaceId,
    String productId,
  ) async {
    final rows = await _client
        .from('product_suppliers')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('product_id', productId)
        .filter('deleted_at', 'is', null)
        .order('is_preferred', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ProductSupplier.fromSupabase)
        .toList();
  }

  Future<ProductSupplier> insertProductSupplier(
      ProductSupplier productSupplier) async {
    final payload = productSupplier.toSupabaseInsert()
      ..['user_id'] = _userId
      ..['workspace_id'] = _wsId;
    final row = await _client
        .from('product_suppliers')
        .insert(payload)
        .select()
        .single();
    return ProductSupplier.fromSupabase(row);
  }

  Future<ProductSupplier> updateProductSupplier(
      ProductSupplier productSupplier) async {
    final payload = productSupplier.toSupabaseInsert();
    final row = await _client
        .from('product_suppliers')
        .update(payload)
        .eq('id', productSupplier.id)
        .select()
        .single();
    return ProductSupplier.fromSupabase(row);
  }

  /// Soft-Delete einer Artikel-Lieferanten-Zuordnung.
  Future<void> deleteProductSupplier(String id) async {
    await _client
        .from('product_suppliers')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Product stock (read-only View) ────────────────────────────────────────
  //
  // Der View `product_stock` ist die einzige Aggregations-Quelle für
  // Lagerbestand pro Produkt/Lager. Er ist read-only (kein insert/update).
  //
  // Zwei Varianten werden angeboten:
  //   • `loadProductStock(workspaceId)` — workspace-weit; der Provider
  //     kann daraus per `productId` gruppieren (für AF8 / KPI-Aggregation).
  //   • `loadProductStockForProduct(workspaceId, productId)` — nur ein
  //     Produkt; für AF12 (Produkt-Detail) effizienter.
  //
  // Signatur für AF8 + AF12 abstimmt:
  //   • AF8 nutzt `loadProductStock` → GroupBy im Provider.
  //   • AF12 nutzt `loadProductStockForProduct` → direkte Summe im
  //     Detail-Screen-Provider-Slot.

  /// Lädt den aggregierten Lagerbestand aller Produkte des Workspaces aus dem
  /// View `product_stock`. Nicht-verknüpfte Bestands-Rows (`product_id IS NULL`)
  /// sind nicht enthalten — dies ist Absicht gemäß Plan-Datenmodell.
  ///
  /// Wird von AF8 für die workspace-weite KPI-Aggregation genutzt.
  Future<List<ProductStock>> loadProductStock(String workspaceId) async {
    final rows = await _client
        .from('product_stock')
        .select()
        .eq('workspace_id', workspaceId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ProductStock.fromSupabase)
        .toList();
  }

  /// Lädt den aggregierten Lagerbestand eines einzelnen Produkts aus dem
  /// View `product_stock`. Jede Row entspricht einem Lager (oder `null`-Lager
  /// für nicht-zugeordnete Items).
  ///
  /// Wird von AF12 (Produkt-Detail-Screen) für die effiziente Einzel-Abfrage
  /// genutzt; Gesamtbestand = Summe von `qtyInWarehouse` aller zurückgegebenen
  /// Rows.
  Future<List<ProductStock>> loadProductStockForProduct(
    String workspaceId,
    String productId,
  ) async {
    final rows = await _client
        .from('product_stock')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('product_id', productId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ProductStock.fromSupabase)
        .toList();
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
  ///
  /// Bootstrap-Pump: bei einem frisch hinzugefügten Account hat IMAP oft
  /// >100 ungesehene UIDs im 90-Tage-Lookback-Fenster. Die Edge Function
  /// holt pro Lauf max ~200 Mails (Memory-/Timeout-Cap), signalisiert
  /// aber `more=true` solange es weitere UIDs gibt. Wir loopen client-
  /// seitig bis `more=false` ODER [maxIterations] erreicht ist (Cap gegen
  /// Pathological-Mailboxen). Optionaler [onProgress]-Callback meldet
  /// nach jeder Iteration den kumulativen Zwischenstand, damit das UI
  /// "Lade noch X" rendern kann.
  ///
  /// Wirft mit Klartext-Message bei Function-Fehlern (HTTP 4xx/5xx im
  /// allerersten Call), damit die UI eine SnackBar mit Diagnose anzeigen
  /// kann. Schlägt ein Folge-Call mid-pump fehl, geben wir das bisher
  /// erreichte Aggregat zurück (Best-Effort).
  Future<InboxPollResult> triggerInboxPoll({
    int maxIterations = 12,
    void Function(InboxPollResult partial)? onProgress,
  }) async {
    int totalStored = 0;
    int totalFetched = 0;
    int? totalSuggested;
    int? totalMatched;
    int accountsProcessed = 0;
    var iterations = 0;
    var more = true;

    while (more && iterations < maxIterations) {
      iterations++;
      final response = await _client.functions.invoke('inbox-poll');
      if (response.status >= 400) {
        if (iterations == 1) {
          throw StateError(
            'Polling fehlgeschlagen (HTTP ${response.status}). '
            'Pruefe in Supabase Studio: 1) Edge Function "inbox-poll" deployed? '
            '2) pg_cron-Job "inbox-poll-5min" aktiv? 3) IMAP-Credentials korrekt?',
          );
        }
        // Mid-pump Failure: brich ab, gib Best-Effort-Aggregat zurück.
        break;
      }
      final data = response.data;
      if (data is! Map) {
        if (iterations == 1) {
          return const InboxPollResult(
            stored: 0,
            fetched: 0,
            accountsProcessed: 0,
          );
        }
        break;
      }
      // Felder mit Fallback aus stats[] für Schema-Drift-Robustheit.
      final stats = (data['stats'] as List?) ?? const [];
      var storedFromStats = 0;
      var fetchedFromStats = 0;
      for (final s in stats) {
        if (s is Map) {
          storedFromStats += (s['stored'] as num?)?.toInt() ?? 0;
          fetchedFromStats += (s['fetched'] as num?)?.toInt() ?? 0;
        }
      }
      final iterStored =
          (data['total_stored'] as num?)?.toInt() ?? storedFromStats;
      final iterFetched =
          (data['total_fetched'] as num?)?.toInt() ?? fetchedFromStats;
      final iterAccounts =
          (data['accounts_processed'] as num?)?.toInt() ??
              (data['accounts'] as num?)?.toInt() ??
              stats.length;

      totalStored += iterStored;
      totalFetched += iterFetched;
      // Parser-Stats kumulieren wenn der Server sie liefert.
      final parseMap = data['parse'];
      if (parseMap is Map) {
        final s = (parseMap['suggested'] as num?)?.toInt();
        final m = (parseMap['matched'] as num?)?.toInt();
        if (s != null) totalSuggested = (totalSuggested ?? 0) + s;
        if (m != null) totalMatched = (totalMatched ?? 0) + m;
      }
      // accountsProcessed = max über alle Iterations (Anzahl Accounts bleibt
      // stabil; aufsummieren würde verfälschen).
      if (iterAccounts > accountsProcessed) accountsProcessed = iterAccounts;

      // Pump-Signal vom Server. Default false → kein Loop für ältere
      // Function-Versionen, die das Feld noch nicht senden.
      more = (data['more'] as bool?) ?? false;

      // Zwischenstand nach JEDER Iteration melden — ermöglicht dem UI
      // ein "Lade weiter…"-Banner mit live-aktualisiertem Counter.
      onProgress?.call(
        InboxPollResult(
          stored: totalStored,
          fetched: totalFetched,
          accountsProcessed: accountsProcessed,
          suggested: totalSuggested,
          matched: totalMatched,
          more: more && iterations < maxIterations,
        ),
      );
    }

    return InboxPollResult(
      stored: totalStored,
      fetched: totalFetched,
      accountsProcessed: accountsProcessed,
      suggested: totalSuggested,
      matched: totalMatched,
      more: more && iterations >= maxIterations,
    );
  }

  /// Re-Parse aller Vorschläge mit `_raw_html` durch die aktuelle Adapter-
  /// Registry. Wird genutzt, wenn ein Adapter-Bug eine FALSCHE Tracking-
  /// Nummer gespeichert hat (z.B. interne Amazon-`orderingShipmentId`
  /// statt der echten Carrier-Nummer aus dem Plain-Text-Body).
  ///
  /// `forceOverwrite=true` überschreibt auch bereits gesetzte Tracking-
  /// Werte. Server-seitig ist der Aufruf hart auf die Workspaces des
  /// eingeloggten Users gescoped — kein Cross-Workspace-Zugriff möglich.
  Future<InboxReparseResult> triggerReparseTracking({
    String? shopKey,
    bool forceOverwrite = false,
  }) async {
    final response = await _client.functions.invoke(
      'inbox-parse',
      body: {
        'reparse_no_tracking': true,
        if (forceOverwrite) 'force_overwrite': true,
        'shop_key': ?shopKey,
      },
    );
    if (response.status >= 400) {
      throw StateError(
        'Re-Parse fehlgeschlagen (HTTP ${response.status}). '
        'Pruefe in Supabase Studio: Edge Function "inbox-parse" deployed?',
      );
    }
    final data = response.data;
    if (data is Map) {
      return InboxReparseResult(
        scanned: (data['scanned'] as num?)?.toInt() ?? 0,
        rescued: (data['rescued'] as num?)?.toInt() ?? 0,
        unchanged: (data['unchanged'] as num?)?.toInt() ?? 0,
        errors: (data['errors'] as num?)?.toInt() ?? 0,
      );
    }
    return const InboxReparseResult(
      scanned: 0, rescued: 0, unchanged: 0, errors: 0,
    );
  }

  /// Hard-Reset des Inbox-Postfachs eines Workspace.
  ///
  /// Loescht ALLE `parsed_messages` (cascade: pending_suggestions, reads,
  /// dismissals) + setzt `mailbox_accounts.last_uid = NULL` zurueck, damit
  /// der naechste IMAP-Poll alle Mails neu importiert.
  ///
  /// **Nicht reversibel.** UI muss vor Aufruf einen Confirm-Dialog
  /// einblenden. Server prueft, ob der angemeldete User Workspace-Member
  /// ist (Cross-Workspace-Aufrufe → 403).
  Future<InboxResetResult> triggerInboxReset({
    required String workspaceId,
  }) async {
    final response = await _client.functions.invoke(
      'inbox-parse',
      body: {
        'reset_all': true,
        'workspace_id': workspaceId,
      },
    );
    if (response.status >= 400) {
      throw StateError(
        'Inbox-Reset fehlgeschlagen (HTTP ${response.status}). '
        'Pruefe in Supabase Studio: Edge Function "inbox-parse" deployed?',
      );
    }
    final data = response.data;
    if (data is Map) {
      return InboxResetResult(
        deletedMessages: (data['deleted_messages'] as num?)?.toInt() ?? 0,
        resetAccounts: (data['reset_accounts'] as num?)?.toInt() ?? 0,
      );
    }
    return const InboxResetResult(deletedMessages: 0, resetAccounts: 0);
  }

  /// Triggert `tracking-poll` Edge-Function für genau einen Deal (Klarna-
  /// Pattern: User-initiierter Refresh statt 4h-Cron-Tick).
  ///
  /// Server-seitig:
  ///   * JWT-User-Auth wird gegen workspace_members geprüft (Cross-Workspace-
  ///     Aufruf → 403).
  ///   * 30s-Cooldown pro Deal via `deals.live_status_updated_at` → 429.
  ///   * Bei Erfolg läuft genau die gleiche `pollWorkspace`-Logik wie im
  ///     4h-Cron, nur eq('id', dealId) statt full Workspace-Scan.
  ///
  /// Wirft nie — alle Fehler werden in einen [RetrackResult] gemappt, damit
  /// die UI nicht try/catch um den Provider-Call legen muss.
  Future<RetrackResult> retrackDeal(int dealId) async {
    try {
      final response = await _client.functions.invoke(
        'tracking-poll',
        body: {'deal_id': dealId},
      );
      final status = response.status;
      if (status == 429) return RetrackResult.rateLimited;
      if (status >= 400) return RetrackResult.failed;
      return RetrackResult.success;
    } on Exception {
      return RetrackResult.offline;
    }
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

  // ── Tracking-Confidence-Updates ──────────────────────────────────────────

  /// Akzeptiert das `needs_review`-Tracking einer Suggestion als korrekt.
  /// Setzt `tracking_confidence = 'manual'`, `tracking_needs_review = false`.
  Future<void> acceptSuggestionTrackingAsManual(String suggestionId) async {
    await _client
        .from('pending_deal_suggestions')
        .update({
          'tracking_confidence': 'manual',
          'tracking_needs_review': false,
        })
        .eq('id', suggestionId);
  }

  /// Verwirft das Tracking einer Suggestion.
  /// Setzt `tracking = null`, `tracking_confidence = 'none'`,
  /// `tracking_needs_review = false`.
  Future<void> discardSuggestionTracking(String suggestionId) async {
    await _client
        .from('pending_deal_suggestions')
        .update({
          'tracking': null,
          'tracking_confidence': 'none',
          'tracking_needs_review': false,
        })
        .eq('id', suggestionId);
  }

  /// Setzt eine manuell eingegebene Tracking-Nummer auf einer Suggestion.
  Future<void> updateSuggestionTrackingManually(
    String suggestionId,
    String tracking,
  ) async {
    await _client
        .from('pending_deal_suggestions')
        .update({
          'tracking': tracking,
          'tracking_confidence': 'manual',
          'tracking_needs_review': false,
        })
        .eq('id', suggestionId);
  }

  /// Akzeptiert das `needs_review`-Tracking eines Deals als korrekt (manual).
  Future<void> acceptDealTrackingAsManual(int dealId) async {
    await _client
        .from('deals')
        .update({
          'tracking_confidence': 'manual',
          'tracking_needs_review': false,
        })
        .eq('id', dealId);
  }

  /// Verwirft das Tracking eines Deals.
  Future<void> discardDealTracking(int dealId) async {
    await _client
        .from('deals')
        .update({
          'tracking': null,
          'tracking_confidence': 'none',
          'tracking_needs_review': false,
        })
        .eq('id', dealId);
  }

  /// Setzt eine manuell eingegebene Tracking-Nummer auf einem Deal.
  Future<void> updateDealTrackingManually(int dealId, String tracking) async {
    await _client
        .from('deals')
        .update({
          'tracking': tracking,
          'tracking_confidence': 'manual',
          'tracking_needs_review': false,
        })
        .eq('id', dealId);
  }
}

/// Rückgabe von [SupabaseRepository.triggerInboxPoll]. Felder enthalten die
/// Aggregat-Statistik aus der `inbox-poll`-Edge-Function. `suggested` und
/// `matched` sind nullable, weil ältere Function-Versionen den Parser-Sub-
/// Status nicht in der Antwort mitliefern (UI fällt dann auf Refresh zurück).
///
/// `more=true` signalisiert: der Pump hat das clientseitige Iterations-Cap
/// erreicht, im IMAP-Postfach liegen aber noch ungesehene UIDs. Der nächste
/// Cron-Tick (oder ein erneuter "Jetzt pollen"-Klick) holt sie nach.
class InboxPollResult {
  final int stored;
  final int fetched;
  final int accountsProcessed;
  final int? suggested;
  final int? matched;
  final bool more;
  const InboxPollResult({
    required this.stored,
    required this.fetched,
    required this.accountsProcessed,
    this.suggested,
    this.matched,
    this.more = false,
  });
}

/// Rückgabe von [SupabaseRepository.triggerReparseTracking]. `rescued` =
/// Anzahl Suggestions, deren `tracking`/`carrier` durch den Re-Parse
/// neu gesetzt oder überschrieben wurden.
class InboxReparseResult {
  final int scanned;
  final int rescued;
  final int unchanged;
  final int errors;
  const InboxReparseResult({
    required this.scanned,
    required this.rescued,
    required this.unchanged,
    required this.errors,
  });
}

/// Rueckgabe von [SupabaseRepository.triggerInboxReset]. `deletedMessages` =
/// Anzahl geloeschter `parsed_messages`-Rows (cascade: pending_suggestions,
/// inbox_reads, inbox_dismissals). `resetAccounts` = Anzahl
/// `mailbox_accounts`, deren `last_uid` auf NULL gesetzt wurde.
class InboxResetResult {
  final int deletedMessages;
  final int resetAccounts;
  const InboxResetResult({
    required this.deletedMessages,
    required this.resetAccounts,
  });
}

/// Ergebnis eines manuellen Re-Track-Triggers für einen einzelnen Deal.
/// Wird in der UI in SnackBars übersetzt (siehe `trackingRetrack*` ARB-Keys).
enum RetrackResult {
  /// Edge-Function hat den Status erfolgreich aktualisiert (oder zumindest
  /// gepollt — UI lädt Deal neu).
  success,

  /// 429: 30-Sekunden-Cooldown noch nicht abgelaufen.
  rateLimited,

  /// 4xx/5xx (außer 429) — Adapter/Carrier-API-Fehler, fehlende Credentials,
  /// fehlende Auth (sollte UI nie sehen, weil App-Auth da ist).
  failed,

  /// Netzwerk-Exception (kein HTTP-Status).
  offline,
}
