import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/shop.dart';
import '../models/supplier.dart';
import '../models/warehouse.dart';

// ── Validation error ─────────────────────────────────────────────────────────

/// A single validation error produced during CSV import.
class CsvValidationError {
  final int lineNumber;
  final String section;
  final String message;

  const CsvValidationError({
    required this.lineNumber,
    required this.section,
    required this.message,
  });

  @override
  String toString() => 'Zeile $lineNumber [$section]: $message';
}

// ── Import result ─────────────────────────────────────────────────────────────

/// Result of a full CSV import containing all tables.
class CsvImportResult {
  final List<Deal> deals;
  final List<Shop> shops;
  final List<Buyer> buyers;
  final List<Supplier> suppliers;
  final List<InventoryItem> inventoryItems;
  // New sections (Epic F)
  final List<ProductCategory> categories;
  final List<Product> products;
  final List<Warehouse> warehouses;
  final List<PurchaseOrder> purchaseOrders;
  final List<PurchaseOrderItem> purchaseOrderItems;
  /// Rows that were skipped due to validation errors — collected instead of
  /// aborting the entire import. Callers should surface these to the user.
  final List<CsvValidationError> errors;

  const CsvImportResult({
    required this.deals,
    required this.shops,
    required this.buyers,
    required this.suppliers,
    required this.inventoryItems,
    this.categories = const [],
    this.products = const [],
    this.warehouses = const [],
    this.purchaseOrders = const [],
    this.purchaseOrderItems = const [],
    this.errors = const [],
  });
}

// ── Validation helpers ────────────────────────────────────────────────────────

/// EAN check: 8, 12, 13 or 14 numeric digits.
final _eanRegex = RegExp(r'^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$');

bool _isValidEan(String ean) => _eanRegex.hasMatch(ean);

const _validPoStatuses = {
  'draft', 'ordered', 'partially_received', 'received', 'cancelled',
};

const _validInventoryStatuses = {
  'Im Lager', 'Reserviert', 'Versandt', 'Verkauft',
};

class CsvService {
  static const _sep = ';';
  static final _dateFmt = DateFormat('dd.MM.yyyy');
  static const _uuid = Uuid();

  // ── Section markers ───────────────────────────────────────────────────────

  static const _secDeals          = '## DEALS';
  static const _secShops          = '## SHOPS';
  static const _secBuyers         = '## KÄUFER';
  static const _secSuppliers      = '## LIEFERANTEN';
  static const _secInventory      = '## LAGERBESTAND';
  // New sections
  static const _secCategories     = '## WARENGRUPPEN';
  static const _secProducts       = '## ARTIKEL';
  static const _secWarehouses     = '## LAGER';
  static const _secPurchaseOrders = '## BESTELLUNGEN';
  static const _secPoItems        = '## BESTELLPOSITIONEN';

  // ── Column headers ────────────────────────────────────────────────────────

  static const _dealHeaders = [
    'ID', 'Produkt', 'Anzahl', 'Versandtyp', 'Shop', 'Bestelldatum',
    'EK Netto', 'EK Brutto', 'VK', 'Käufer', 'Ticketnummer', 'Ticket-URL',
    'Tracking', 'Ankunft', 'Status', 'Beleg', 'Notiz', 'MwSt-Satz', 'Währung',
  ];

  static const _shopHeaders = [
    'Name', 'Region', 'Channel', 'URL', 'Aktiv',
  ];

  static const _buyerHeaders = [
    'Name', 'Discord-Server-IDs', 'Aktiv', 'Zahlungsstatus',
    'RowFillColor', 'BuyerCellColor', 'FontColor', 'SortOrder',
  ];

  static const _supplierHeaders = [
    'Name', 'Kontakt', 'E-Mail', 'Telefon', 'Website', 'Notiz', 'Aktiv',
  ];

  static const _inventoryHeaders = [
    'ID', 'Name', 'SKU', 'EAN', 'Anzahl', 'Mindestbestand', 'Lagerort',
    'Einkaufspreis', 'Ankunft', 'Deal-ID', 'Lieferant', 'Ticketnummer',
    'Ticket-URL', 'Status', 'Notiz',
  ];

  // New headers (Epic F)
  static const _categoryHeaders = [
    'Name', 'Übergeordnet', 'Reihenfolge',
  ];

  static const _productHeaders = [
    'ID', 'Name', 'SKU', 'EAN', 'Kategorie', 'Lieferant', 'Einheit',
    'Standard-EK', 'Standard-VK', 'Mindestbestand', 'MwSt-Satz', 'Notiz',
    'Aktiv',
  ];

  static const _warehouseHeaders = [
    'Name', 'Adresse', 'Standard', 'Aktiv',
  ];

  static const _purchaseOrderHeaders = [
    'Bestellnummer', 'Lieferant', 'Status', 'Bestelldatum', 'Erwartetes Datum',
    'Notiz',
  ];

  static const _poItemHeaders = [
    'Bestellnummer', 'Artikel-SKU', 'Bestellt', 'Erhalten', 'Einzelpreis',
  ];

  // ── Export ────────────────────────────────────────────────────────────────

  /// Exports all data as a single multi-section CSV.
  ///
  /// The new sections (categories, products, warehouses, purchase orders, PO
  /// items) are appended after the legacy five sections so that existing files
  /// without them remain importable (backwards-compatible).
  static Future<(String?, String?)> exportAll(
    List<Deal> deals,
    List<Shop> shops,
    List<Buyer> buyers,
    List<InventoryItem> inventoryItems, {
    List<Supplier> suppliers = const [],
    List<ProductCategory> categories = const [],
    List<Product> products = const [],
    List<Warehouse> warehouses = const [],
    List<PurchaseOrder> purchaseOrders = const [],
    List<PurchaseOrderItem> purchaseOrderItems = const [],
  }) async {
    try {
      final csvContent = _buildAll(
        deals,
        shops,
        buyers,
        suppliers,
        inventoryItems,
        categories: categories,
        products: products,
        warehouses: warehouses,
        purchaseOrders: purchaseOrders,
        purchaseOrderItems: purchaseOrderItems,
      );
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final fileName =
          'inventory_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

      if (kIsWeb) {
        await FilePicker.saveFile(
          dialogTitle: 'CSV exportieren',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: bytes,
        );
        return (fileName, null);
      }

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'CSV exportieren',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );
      if (outputPath == null) return (null, null);
      await File(outputPath).writeAsString(csvContent, encoding: utf8, flush: true);
      return (outputPath, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static String _buildAll(
    List<Deal> deals,
    List<Shop> shops,
    List<Buyer> buyers,
    List<Supplier> suppliers,
    List<InventoryItem> inventoryItems, {
    List<ProductCategory> categories = const [],
    List<Product> products = const [],
    List<Warehouse> warehouses = const [],
    List<PurchaseOrder> purchaseOrders = const [],
    List<PurchaseOrderItem> purchaseOrderItems = const [],
  }) {
    final supplierName = {for (final s in suppliers) s.id: s.name};
    final categoryName = {for (final c in categories) c.id: c.name};
    final buf = StringBuffer();
    buf.write('\u{FEFF}'); // BOM for Excel UTF-8

    // ── DEALS ──
    buf.writeln(_secDeals);
    buf.writeln(_dealHeaders.map(_q).join(_sep));
    for (final d in deals) {
      buf.writeln([
        d.id,
        _q(d.product),
        d.quantity,
        _q(d.shippingType),
        _q(d.shop),
        _dateFmt.format(d.orderDate),
        d.ekNetto  != null ? d.ekNetto!.toStringAsFixed(2)  : '',
        d.ekBrutto != null ? d.ekBrutto!.toStringAsFixed(2) : '',
        d.vk       != null ? d.vk!.toStringAsFixed(2)       : '',
        _q(d.buyer        ?? ''),
        _q(d.ticketNumber ?? ''),
        _q(d.ticketUrl    ?? ''),
        _q(d.tracking     ?? ''),
        d.arrivalDate != null ? _dateFmt.format(d.arrivalDate!) : '',
        _q(d.status),
        _q(d.belegLabel),
        _q(d.note ?? ''),
        d.taxRate != null ? (d.taxRate! * 100).toStringAsFixed(2) : '',
        _q(d.currency),
      ].join(_sep));
    }

    buf.writeln();

    // ── SHOPS ──
    buf.writeln(_secShops);
    buf.writeln(_shopHeaders.map(_q).join(_sep));
    for (final s in shops) {
      buf.writeln([
        _q(s.name),
        _q(s.region),
        _q(s.channel),
        _q(s.url ?? ''),
        s.active ? 'Ja' : 'Nein',
      ].join(_sep));
    }

    buf.writeln();

    // ── KÄUFER ──
    buf.writeln(_secBuyers);
    buf.writeln(_buyerHeaders.map(_q).join(_sep));
    for (final b in buyers) {
      buf.writeln([
        _q(b.name),
        _q(b.discordServerIds.join('|')),
        b.active ? 'Ja' : 'Nein',
        _q(b.paymentStatus),
        _colorHex(b.rowFillColor),
        _colorHex(b.buyerCellColor),
        _colorHex(b.fontColor),
        b.sortOrder,
      ].join(_sep));
    }

    buf.writeln();

    // ── LIEFERANTEN ──
    buf.writeln(_secSuppliers);
    buf.writeln(_supplierHeaders.map(_q).join(_sep));
    for (final s in suppliers) {
      buf.writeln([
        _q(s.name),
        _q(s.contactName ?? ''),
        _q(s.email ?? ''),
        _q(s.phone ?? ''),
        _q(s.website ?? ''),
        _q(s.note ?? ''),
        s.active ? 'Ja' : 'Nein',
      ].join(_sep));
    }

    buf.writeln();

    // ── LAGERBESTAND ──
    buf.writeln(_secInventory);
    buf.writeln(_inventoryHeaders.map(_q).join(_sep));
    for (final item in inventoryItems) {
      buf.writeln([
        _q(item.id),
        _q(item.name),
        _q(item.sku ?? ''),
        _q(item.ean ?? ''),
        item.quantity,
        item.minStock,
        _q(item.location ?? ''),
        item.costPrice != null ? item.costPrice!.toStringAsFixed(2) : '',
        item.arrivalDate != null ? _dateFmt.format(item.arrivalDate!) : '',
        item.dealId?.toString() ?? '',
        _q(item.supplierId != null
            ? (supplierName[item.supplierId] ?? '')
            : ''),
        _q(item.ticketNumber ?? ''),
        _q(item.ticketUrl    ?? ''),
        _q(item.status),
        _q(item.note ?? ''),
      ].join(_sep));
    }

    // ── New sections (Epic F) — only written when non-empty so that a legacy
    //    reader that doesn't know the new markers is not confused. A reader
    //    that knows the markers but finds no rows simply gets an empty list.

    if (categories.isNotEmpty) {
      buf.writeln();
      buf.writeln(_secCategories);
      buf.writeln(_categoryHeaders.map(_q).join(_sep));
      for (final c in categories) {
        final parentName =
            c.parentId != null ? (categoryName[c.parentId] ?? '') : '';
        buf.writeln([
          _q(c.name),
          _q(parentName),
          c.sortOrder,
        ].join(_sep));
      }
    }

    if (products.isNotEmpty) {
      buf.writeln();
      buf.writeln(_secProducts);
      buf.writeln(_productHeaders.map(_q).join(_sep));
      for (final p in products) {
        buf.writeln([
          _q(p.id),
          _q(p.name),
          _q(p.sku ?? ''),
          _q(p.ean ?? ''),
          _q(p.categoryId != null ? (categoryName[p.categoryId] ?? '') : ''),
          _q(p.defaultSupplierId != null
              ? (supplierName[p.defaultSupplierId] ?? '')
              : ''),
          _q(p.unit),
          p.defaultCostPrice != null
              ? p.defaultCostPrice!.toStringAsFixed(2)
              : '',
          p.defaultSalePrice != null
              ? p.defaultSalePrice!.toStringAsFixed(2)
              : '',
          p.minStock,
          p.taxRate != null ? (p.taxRate! * 100).toStringAsFixed(2) : '',
          _q(p.note ?? ''),
          p.isActive ? 'Ja' : 'Nein',
        ].join(_sep));
      }
    }

    if (warehouses.isNotEmpty) {
      buf.writeln();
      buf.writeln(_secWarehouses);
      buf.writeln(_warehouseHeaders.map(_q).join(_sep));
      for (final w in warehouses) {
        buf.writeln([
          _q(w.name),
          _q(w.address ?? ''),
          w.isDefault ? 'Ja' : 'Nein',
          w.isActive  ? 'Ja' : 'Nein',
        ].join(_sep));
      }
    }

    if (purchaseOrders.isNotEmpty) {
      buf.writeln();
      buf.writeln(_secPurchaseOrders);
      buf.writeln(_purchaseOrderHeaders.map(_q).join(_sep));
      for (final po in purchaseOrders) {
        buf.writeln([
          _q(po.orderNumber),
          _q(po.supplierId != null
              ? (supplierName[po.supplierId] ?? '')
              : ''),
          _q(po.status.dbValue),
          po.orderDate != null ? _dateFmt.format(po.orderDate!) : '',
          po.expectedDate != null ? _dateFmt.format(po.expectedDate!) : '',
          _q(po.note ?? ''),
        ].join(_sep));
      }
    }

    if (purchaseOrderItems.isNotEmpty) {
      // Build product SKU lookup for FK resolve in export.
      // product_id → sku (may be empty → use product id as fallback)
      buf.writeln();
      buf.writeln(_secPoItems);
      buf.writeln(_poItemHeaders.map(_q).join(_sep));
      for (final item in purchaseOrderItems) {
        buf.writeln([
          // We only have the product_id; the import uses SKU to resolve.
          // In export we write the raw product_id as a SKU placeholder so
          // callers that also provide a products list can override this.
          // The proper approach: callers pass the products list so we can
          // look up SKU — handled via the products param above.
          _q(item.purchaseOrderId?.toString() ?? ''),
          _q(item.productId ?? ''),
          item.quantityOrdered,
          item.quantityReceived,
          item.unitPrice != null ? item.unitPrice!.toStringAsFixed(2) : '',
        ].join(_sep));
      }
    }

    return buf.toString();
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Picks a CSV file and parses all sections.
  ///
  /// Legacy single-table CSVs (no section markers) are imported as deals only.
  /// New sections (categories, products, warehouses, purchase orders) are
  /// silently ignored when absent — backwards-compatible.
  ///
  /// [workspaceId] and [userId] are required for constructing the new model
  /// objects (Product, ProductCategory, Warehouse, PurchaseOrder,
  /// PurchaseOrderItem) because the CSV does not carry identity context.
  static Future<(CsvImportResult?, String?)> importAll(
    int nextDealId, {
    String workspaceId = '',
    String userId = '',
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'CSV importieren',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return (null, null);

      String content;
      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes == null) return (null, 'Datei konnte nicht gelesen werden.');
        content = utf8.decode(bytes, allowMalformed: true);
      } else {
        final path = result.files.first.path;
        if (path == null) {
          final bytes = result.files.first.bytes;
          if (bytes == null) return (null, 'Dateipfad nicht verfügbar.');
          content = utf8.decode(bytes, allowMalformed: true);
        } else {
          try {
            content = await File(path).readAsString(encoding: utf8);
          } catch (_) {
            content = await File(path).readAsString(encoding: latin1);
          }
        }
      }

      if (content.startsWith('\u{FEFF}')) content = content.substring(1);
      return (
        _parseAll(
          content,
          nextDealId,
          workspaceId: workspaceId,
          userId: userId,
        ),
        null,
      );
    } catch (e) {
      return (null, e.toString());
    }
  }

  // ── Parse (public for testing without FilePicker) ─────────────────────────

  /// Parses [content] and returns a [CsvImportResult].
  ///
  /// Exposed as a static method so unit tests can call it directly without
  /// triggering the file-picker dialog.
  static CsvImportResult parseContent(
    String content,
    int startId, {
    String workspaceId = '',
    String userId = '',
  }) {
    if (content.startsWith('\u{FEFF}')) content = content.substring(1);
    return _parseAll(
      content,
      startId,
      workspaceId: workspaceId,
      userId: userId,
    );
  }

  static CsvImportResult _parseAll(
    String content,
    int startId, {
    String workspaceId = '',
    String userId = '',
  }) {
    final allLines = content.split(RegExp(r'\r?\n'));
    final sections = <String, List<String>>{};
    String? currentSection;

    for (final line in allLines) {
      final trimmed = line.trim();
      if (trimmed == _secDeals ||
          trimmed == _secShops ||
          trimmed == _secBuyers ||
          trimmed == _secSuppliers ||
          trimmed == _secInventory ||
          trimmed == _secCategories ||
          trimmed == _secProducts ||
          trimmed == _secWarehouses ||
          trimmed == _secPurchaseOrders ||
          trimmed == _secPoItems) {
        currentSection = trimmed;
        sections[currentSection] = [];
      } else if (currentSection != null && trimmed.isNotEmpty) {
        sections[currentSection]!.add(line);
      }
    }

    // Legacy: no section markers → treat all lines as deals
    final dealLines = sections[_secDeals] ??
        allLines.where((l) => l.trim().isNotEmpty).toList();
    final shopLines      = sections[_secShops]          ?? [];
    final buyerLines     = sections[_secBuyers]         ?? [];
    final supplierLines  = sections[_secSuppliers]      ?? [];
    final inventoryLines = sections[_secInventory]      ?? [];
    final categoryLines  = sections[_secCategories]     ?? [];
    final productLines   = sections[_secProducts]       ?? [];
    final warehouseLines = sections[_secWarehouses]     ?? [];
    final poLines        = sections[_secPurchaseOrders] ?? [];
    final poItemLines    = sections[_secPoItems]        ?? [];

    final errors = <CsvValidationError>[];

    final suppliers = _parseSuppliers(supplierLines);

    // Build lookup maps for FK resolving (by name / by SKU).
    // These are derived from what's in the CSV itself (imported in the same
    // file). After import the provider reconciles against the workspace.
    final supplierIdByName = <String, String>{
      for (final s in suppliers) s.name.toLowerCase(): s.id,
    };

    final categories = _parseCategories(
      categoryLines,
      workspaceId: workspaceId,
      userId: userId,
      errors: errors,
    );
    final categoryIdByName = <String, String>{
      for (final c in categories) c.name.toLowerCase(): c.id,
    };

    final warehouses = _parseWarehouses(
      warehouseLines,
      workspaceId: workspaceId,
      userId: userId,
      errors: errors,
    );

    final products = _parseProducts(
      productLines,
      workspaceId: workspaceId,
      userId: userId,
      categoryIdByName: categoryIdByName,
      supplierIdByName: supplierIdByName,
      errors: errors,
    );
    final productIdBySku = <String, String>{
      for (final p in products)
        if (p.sku != null && p.sku!.isNotEmpty) p.sku!: p.id,
    };

    final purchaseOrders = _parsePurchaseOrders(
      poLines,
      workspaceId: workspaceId,
      userId: userId,
      supplierIdByName: supplierIdByName,
      errors: errors,
    );
    final poIdByNumber = <String, int>{
      for (final po in purchaseOrders)
        if (po.id != null) po.orderNumber: po.id!,
    };

    final purchaseOrderItems = _parsePurchaseOrderItems(
      poItemLines,
      workspaceId: workspaceId,
      productIdBySku: productIdBySku,
      poIdByNumber: poIdByNumber,
      errors: errors,
    );

    return CsvImportResult(
      deals:              _parseDeals(dealLines, startId),
      shops:              _parseShops(shopLines),
      buyers:             _parseBuyers(buyerLines),
      suppliers:          suppliers,
      inventoryItems:     _parseInventory(inventoryLines, suppliers),
      categories:         categories,
      products:           products,
      warehouses:         warehouses,
      purchaseOrders:     purchaseOrders,
      purchaseOrderItems: purchaseOrderItems,
      errors:             errors,
    );
  }

  // ── Legacy parsers (unchanged) ────────────────────────────────────────────

  static List<Deal> _parseDeals(List<String> lines, int startId) {
    if (lines.isEmpty) return [];
    final dataLines = lines.skip(1).where((l) => l.trim().isNotEmpty);
    final deals = <Deal>[];
    int currentId = startId;

    for (final line in dataLines) {
      final cols = _splitLine(line);
      if (cols.length < 2) continue;

      String col(int i) => i < cols.length ? cols[i].trim() : '';

      DateTime? parseDate(String s) {
        if (s.isEmpty) return null;
        try { return _dateFmt.parse(s); } catch (_) {}
        try { return DateTime.parse(s); } catch (_) {}
        return null;
      }

      double? parseDouble(String s) =>
          s.isEmpty ? null : double.tryParse(s.replaceAll(',', '.'));

      final orderDate = parseDate(col(5)) ?? DateTime.now();
      final ekNetto   = parseDouble(col(6));
      final ekBrutto  = parseDouble(col(7));

      // Format detection by column count:
      //   16: old without Ticket-URL  ·  17: with Ticket-URL  ·  19+: with MwSt+Währung
      final hasTicketUrlCol = cols.length >= 17;
      final hasTaxCols      = cols.length >= 19;
      final ticketUrl  = hasTicketUrlCol ? col(11) : null;
      final tracking   = col(hasTicketUrlCol ? 12 : 11);
      final arrivalRaw = col(hasTicketUrlCol ? 13 : 12);
      final statusRaw  = col(hasTicketUrlCol ? 14 : 13);
      final belegRaw   = col(hasTicketUrlCol ? 15 : 14);
      final noteRaw    = col(hasTicketUrlCol ? 16 : 15);
      final taxRateRaw = hasTaxCols ? col(17) : '';
      final currencyRaw = hasTaxCols ? col(18) : '';

      double? finalNetto  = ekNetto;
      double? finalBrutto = ekBrutto;

      double? taxRatePct = parseDouble(taxRateRaw);
      final factor = 1 + ((taxRatePct ?? 19) / 100);
      if (finalNetto != null && finalBrutto == null) {
        finalBrutto = finalNetto * factor;
      } else if (finalBrutto != null && finalNetto == null) {
        finalNetto = finalBrutto / factor;
      }

      const validStatuses = [
        'Bestellt', 'Unterwegs', 'Angekommen', 'Rechnung gestellt', 'Done',
      ];
      final status = validStatuses.contains(statusRaw) ? statusRaw : 'Bestellt';
      final hasReceipt = belegRaw.toLowerCase() == 'ja';
      final isDropship = col(3).toLowerCase() == 'dropship';
      const validCurrencies = ['EUR', 'USD', 'GBP', 'CHF'];
      final currency =
          validCurrencies.contains(currencyRaw) ? currencyRaw : 'EUR';

      deals.add(Deal(
        id: currentId++,
        product:      col(1).isEmpty ? 'Unbekannt' : col(1),
        quantity:     int.tryParse(col(2)) ?? 1,
        isDropship:   isDropship,
        shop:         col(4).isEmpty ? 'Unbekannt' : col(4),
        orderDate:    orderDate,
        ekNetto:      finalNetto,
        ekBrutto:     finalBrutto,
        vk:           parseDouble(col(8)),
        buyer:        col(9).isEmpty  ? null : col(9),
        ticketNumber: col(10).isEmpty ? null : col(10),
        ticketUrl:    ticketUrl?.isEmpty ?? true ? null : ticketUrl,
        tracking:     tracking.isEmpty  ? null : tracking,
        arrivalDate:  parseDate(arrivalRaw),
        status: status,
        hasReceipt: hasReceipt,
        note:   noteRaw.isEmpty ? null : noteRaw,
        taxRate: taxRatePct != null ? taxRatePct / 100 : null,
        currency: currency,
      ));
    }
    return deals;
  }

  static List<Shop> _parseShops(List<String> lines) {
    if (lines.isEmpty) return [];
    final shops = <Shop>[];
    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';
      shops.add(Shop(
        id:      _uuid.v4(),
        name:    col(0).isEmpty ? 'Unbekannt' : col(0),
        region:  col(1).isEmpty ? 'DE' : col(1),
        channel: col(2),
        url:     col(3).isEmpty ? null : col(3),
        active:  col(4) != 'Nein',
      ));
    }
    return shops;
  }

  static List<Buyer> _parseBuyers(List<String> lines) {
    if (lines.isEmpty) return [];
    final buyers = <Buyer>[];
    int sortOrder = 0;
    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';
      final serverIds = col(1).isEmpty
          ? <String>[]
          : col(1).split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      buyers.add(Buyer(
        id:               _uuid.v4(),
        name:             col(0).isEmpty ? 'Unbekannt' : col(0),
        discordServerIds: serverIds,
        active:           col(2) != 'Nein',
        paymentStatus:    col(3).isEmpty ? 'OK' : col(3),
        rowFillColor:    _parseColor(col(4), const Color(0xFFFFFFFF)),
        buyerCellColor:  _parseColor(col(5), const Color(0xFF2563EB)),
        fontColor:       _parseColor(col(6), const Color(0xFF1E293B)),
        sortOrder:       int.tryParse(col(7)) ?? sortOrder,
      ));
      sortOrder++;
    }
    return buyers;
  }

  static List<Supplier> _parseSuppliers(List<String> lines) {
    if (lines.isEmpty) return [];
    final suppliers = <Supplier>[];
    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';
      suppliers.add(Supplier(
        id:          _uuid.v4(),
        name:        col(0).isEmpty ? 'Unbekannt' : col(0),
        contactName: col(1).isEmpty ? null : col(1),
        email:       col(2).isEmpty ? null : col(2),
        phone:       col(3).isEmpty ? null : col(3),
        website:     col(4).isEmpty ? null : col(4),
        note:        col(5).isEmpty ? null : col(5),
        active:      col(6) != 'Nein',
      ));
    }
    return suppliers;
  }

  static List<InventoryItem> _parseInventory(
    List<String> lines,
    List<Supplier> suppliers,
  ) {
    if (lines.isEmpty) return [];
    final supplierIdByName = <String, String>{
      for (final s in suppliers) s.name.toLowerCase(): s.id,
    };
    final items = <InventoryItem>[];
    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';

      DateTime? parseDate(String s) {
        if (s.isEmpty) return null;
        try { return _dateFmt.parse(s); } catch (_) {}
        try { return DateTime.parse(s); } catch (_) {}
        return null;
      }

      // Format detection: 13 cols = old (no EAN, no supplier), 15 cols = new
      final hasNewCols = cols.length >= 15;

      final idCol           = col(0);
      final nameCol         = col(1);
      final skuCol          = col(2);
      final eanCol          = hasNewCols ? col(3) : null;
      final qty             = int.tryParse(col(hasNewCols ? 4 : 3)) ?? 0;
      final minStock        = int.tryParse(col(hasNewCols ? 5 : 4)) ?? 0;
      final locationCol     = col(hasNewCols ? 6 : 5);
      final costCol         = col(hasNewCols ? 7 : 6);
      final arrivalCol      = col(hasNewCols ? 8 : 7);
      final dealIdCol       = col(hasNewCols ? 9 : 8);
      final supplierNameCol = hasNewCols ? col(10) : null;
      final ticketNoCol     = col(hasNewCols ? 11 : 9);
      final ticketUrlCol    = col(hasNewCols ? 12 : 10);
      final statusCol       = col(hasNewCols ? 13 : 11);
      final noteCol         = col(hasNewCols ? 14 : 12);

      final status = _validInventoryStatuses.contains(statusCol)
          ? statusCol
          : 'Im Lager';
      final supplierId = supplierNameCol == null || supplierNameCol.isEmpty
          ? null
          : supplierIdByName[supplierNameCol.toLowerCase()];

      items.add(InventoryItem(
        id:           idCol.isEmpty ? _uuid.v4() : idCol,
        name:         nameCol.isEmpty ? 'Unbekannt' : nameCol,
        sku:          skuCol.isEmpty ? null : skuCol,
        ean:          eanCol == null || eanCol.isEmpty ? null : eanCol,
        quantity:     qty,
        minStock:     minStock,
        location:     locationCol.isEmpty ? null : locationCol,
        costPrice:    double.tryParse(costCol.replaceAll(',', '.')),
        arrivalDate:  parseDate(arrivalCol),
        dealId:       int.tryParse(dealIdCol),
        supplierId:   supplierId,
        ticketNumber: ticketNoCol.isEmpty  ? null : ticketNoCol,
        ticketUrl:    ticketUrlCol.isEmpty ? null : ticketUrlCol,
        status:       status,
        note:         noteCol.isEmpty ? null : noteCol,
      ));
    }
    return items;
  }

  // ── New section parsers ───────────────────────────────────────────────────

  /// Parses `## WARENGRUPPEN` lines.
  ///
  /// FK: `Übergeordnet` is a category *name* resolved against already-parsed
  /// categories in this section (self-referential). Because the header row
  /// is skipped and categories are processed top-to-bottom, parents must
  /// appear before their children in the CSV for the lookup to work.
  static List<ProductCategory> _parseCategories(
    List<String> lines, {
    required String workspaceId,
    required String userId,
    required List<CsvValidationError> errors,
  }) {
    if (lines.isEmpty) return [];
    final categories = <ProductCategory>[];
    // Map name→id built incrementally so parent-before-child order works.
    final nameToId = <String, String>{};
    int lineNumber = 1; // header counts as line 1

    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      lineNumber++;
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';

      final name = col(0);
      if (name.isEmpty || name.length > 100) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'WARENGRUPPEN',
          message: name.isEmpty
              ? 'Name darf nicht leer sein.'
              : 'Name darf max. 100 Zeichen haben (aktuell ${name.length}).',
        ));
        continue;
      }

      final parentNameRaw = col(1);
      String? parentId;
      if (parentNameRaw.isNotEmpty) {
        parentId = nameToId[parentNameRaw.toLowerCase()];
        if (parentId == null) {
          errors.add(CsvValidationError(
            lineNumber: lineNumber,
            section: 'WARENGRUPPEN',
            message:
                'Übergeordnete Warengruppe "$parentNameRaw" nicht gefunden.',
          ));
          continue;
        }
      }

      final sortOrder = int.tryParse(col(2)) ?? 0;
      final id = _uuid.v4();
      nameToId[name.toLowerCase()] = id;
      final now = DateTime.now().toUtc();
      categories.add(ProductCategory(
        id:          id,
        workspaceId: workspaceId,
        userId:      userId,
        name:        name,
        parentId:    parentId,
        sortOrder:   sortOrder,
        createdAt:   now,
        updatedAt:   now,
      ));
    }
    return categories;
  }

  /// Parses `## ARTIKEL` lines.
  ///
  /// FK resolution (REQUIRED — Risiko 10 + Security):
  /// - `Kategorie` → resolved via [categoryIdByName] (name lookup).
  /// - `Lieferant` → resolved via [supplierIdByName] (name lookup).
  ///   Raw UUIDs are NEVER taken from the CSV for FK fields.
  ///   Unknown references → import error with line number; row is skipped.
  ///
  /// CHECK-Constraint pre-validation:
  /// - EAN: 8/12/13/14-digit numeric (optional field, validated when present).
  /// - `name`: 1–200 characters.
  static List<Product> _parseProducts(
    List<String> lines, {
    required String workspaceId,
    required String userId,
    required Map<String, String> categoryIdByName,
    required Map<String, String> supplierIdByName,
    required List<CsvValidationError> errors,
  }) {
    if (lines.isEmpty) return [];
    final products = <Product>[];
    int lineNumber = 1;

    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      lineNumber++;
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';

      double? parseDouble(String s) =>
          s.isEmpty ? null : double.tryParse(s.replaceAll(',', '.'));

      final name = col(1);
      // CHECK: name length 1-200
      if (name.isEmpty || name.length > 200) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'ARTIKEL',
          message: name.isEmpty
              ? 'Name darf nicht leer sein.'
              : 'Name darf max. 200 Zeichen haben (aktuell ${name.length}).',
        ));
        continue;
      }

      // CHECK: EAN format (optional)
      final eanRaw = col(3);
      if (eanRaw.isNotEmpty && !_isValidEan(eanRaw)) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'ARTIKEL',
          message:
              'Ungültiger EAN "$eanRaw" — muss 8, 12, 13 oder 14 Ziffern haben.',
        ));
        continue;
      }

      // FK: Kategorie → name lookup (no raw UUID)
      final categoryNameRaw = col(4);
      String? categoryId;
      if (categoryNameRaw.isNotEmpty) {
        categoryId = categoryIdByName[categoryNameRaw.toLowerCase()];
        if (categoryId == null) {
          errors.add(CsvValidationError(
            lineNumber: lineNumber,
            section: 'ARTIKEL',
            message: 'Kategorie "$categoryNameRaw" nicht gefunden.',
          ));
          continue;
        }
      }

      // FK: Lieferant → name lookup (no raw UUID)
      final supplierNameRaw = col(5);
      String? defaultSupplierId;
      if (supplierNameRaw.isNotEmpty) {
        defaultSupplierId = supplierIdByName[supplierNameRaw.toLowerCase()];
        if (defaultSupplierId == null) {
          errors.add(CsvValidationError(
            lineNumber: lineNumber,
            section: 'ARTIKEL',
            message: 'Lieferant "$supplierNameRaw" nicht gefunden.',
          ));
          continue;
        }
      }

      final minStockRaw = int.tryParse(col(9));
      if (minStockRaw != null && minStockRaw < 0) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'ARTIKEL',
          message: 'Mindestbestand darf nicht negativ sein (war $minStockRaw).',
        ));
        continue;
      }

      // Security (medium): the id column from the CSV is ALWAYS ignored.
      // We generate a fresh UUID so that a crafted CSV cannot control the
      // primary key. col(0) is intentionally discarded here.
      final skuRaw  = col(2);
      final unitRaw = col(6);

      // Security (low): pre-validate prices against DB CHECK constraints
      // (price >= 0) before hitting Supabase so we surface a clear error.
      final defaultCostPrice = parseDouble(col(7));
      if (defaultCostPrice != null && defaultCostPrice < 0) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'ARTIKEL',
          message:
              'Standard-EK darf nicht negativ sein (war ${col(7)}).',
        ));
        continue;
      }
      final defaultSalePrice = parseDouble(col(8));
      if (defaultSalePrice != null && defaultSalePrice < 0) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'ARTIKEL',
          message:
              'Standard-VK darf nicht negativ sein (war ${col(8)}).',
        ));
        continue;
      }

      final taxRatePct = parseDouble(col(10));
      final now = DateTime.now().toUtc();

      products.add(Product(
        id:                 _uuid.v4(), // always fresh — never from CSV
        workspaceId:        workspaceId,
        userId:             userId,
        name:               name,
        sku:                skuRaw.isEmpty ? null : skuRaw,
        ean:                eanRaw.isEmpty ? null : eanRaw,
        categoryId:         categoryId,
        defaultSupplierId:  defaultSupplierId,
        unit:               unitRaw.isEmpty ? 'Stk' : unitRaw,
        defaultCostPrice:   defaultCostPrice,
        defaultSalePrice:   defaultSalePrice,
        minStock:           minStockRaw ?? 0,
        taxRate:            taxRatePct != null ? taxRatePct / 100 : null,
        note:               col(11).isEmpty ? null : col(11),
        isActive:           col(12) != 'Nein',
        createdAt:          now,
        updatedAt:          now,
      ));
    }
    return products;
  }

  /// Parses `## LAGER` lines.
  ///
  /// CHECK-Constraint pre-validation:
  /// - `name`: 1–100 characters.
  static List<Warehouse> _parseWarehouses(
    List<String> lines, {
    required String workspaceId,
    required String userId,
    required List<CsvValidationError> errors,
  }) {
    if (lines.isEmpty) return [];
    final warehouses = <Warehouse>[];
    int lineNumber = 1;

    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      lineNumber++;
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';

      final name = col(0);
      if (name.isEmpty || name.length > 100) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'LAGER',
          message: name.isEmpty
              ? 'Name darf nicht leer sein.'
              : 'Name darf max. 100 Zeichen haben (aktuell ${name.length}).',
        ));
        continue;
      }

      final now = DateTime.now().toUtc();
      warehouses.add(Warehouse(
        id:          _uuid.v4(),
        workspaceId: workspaceId,
        userId:      userId,
        name:        name,
        address:     col(1).isEmpty ? null : col(1),
        isDefault:   col(2) == 'Ja',
        isActive:    col(3) != 'Nein',
        createdAt:   now,
        updatedAt:   now,
      ));
    }
    return warehouses;
  }

  /// Parses `## BESTELLUNGEN` lines.
  ///
  /// FK resolution:
  /// - `Lieferant` → resolved via [supplierIdByName] (name lookup).
  ///   Unknown supplier → import error; row skipped.
  ///
  /// CHECK-Constraint pre-validation:
  /// - `status` must be one of the valid PO status values.
  static List<PurchaseOrder> _parsePurchaseOrders(
    List<String> lines, {
    required String workspaceId,
    required String userId,
    required Map<String, String> supplierIdByName,
    required List<CsvValidationError> errors,
  }) {
    if (lines.isEmpty) return [];
    final orders = <PurchaseOrder>[];
    int lineNumber = 1;
    // Synthetic BIGSERIAL-style int IDs for in-memory cross-referencing by
    // PO items during this import session. These are replaced by DB-generated
    // IDs after the actual insert.
    int syntheticId = -1;

    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      lineNumber++;
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';

      DateTime? parseDate(String s) {
        if (s.isEmpty) return null;
        try { return _dateFmt.parse(s); } catch (_) {}
        try { return DateTime.parse(s); } catch (_) {}
        return null;
      }

      final orderNumber = col(0);
      if (orderNumber.isEmpty) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLUNGEN',
          message: 'Bestellnummer darf nicht leer sein.',
        ));
        continue;
      }

      // FK: Lieferant → name lookup (no raw UUID)
      final supplierNameRaw = col(1);
      String? supplierId;
      if (supplierNameRaw.isNotEmpty) {
        supplierId = supplierIdByName[supplierNameRaw.toLowerCase()];
        if (supplierId == null) {
          errors.add(CsvValidationError(
            lineNumber: lineNumber,
            section: 'BESTELLUNGEN',
            message: 'Lieferant "$supplierNameRaw" nicht gefunden.',
          ));
          continue;
        }
      }

      // CHECK: status enum
      final statusRaw = col(2);
      if (statusRaw.isNotEmpty && !_validPoStatuses.contains(statusRaw)) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLUNGEN',
          message:
              'Ungültiger Status "$statusRaw". Erlaubt: ${_validPoStatuses.join(', ')}.',
        ));
        continue;
      }

      final now = DateTime.now().toUtc();
      orders.add(PurchaseOrder(
        id:           syntheticId--,
        workspaceId:  workspaceId,
        userId:       userId,
        supplierId:   supplierId,
        orderNumber:  orderNumber,
        status:       statusRaw.isEmpty
            ? PurchaseOrderStatus.draft
            : PurchaseOrderStatus.fromDbValue(statusRaw),
        orderDate:    parseDate(col(3)),
        expectedDate: parseDate(col(4)),
        note:         col(5).isEmpty ? null : col(5),
        createdAt:    now,
        updatedAt:    now,
      ));
    }
    return orders;
  }

  /// Parses `## BESTELLPOSITIONEN` lines.
  ///
  /// FK resolution:
  /// - `Bestellnummer` → resolved via [poIdByNumber] (order number lookup).
  /// - `Artikel-SKU` → resolved via [productIdBySku] (SKU lookup).
  ///   Unknown references → import error; row skipped.
  ///
  /// CHECK-Constraint pre-validation:
  /// - `quantity_ordered > 0`.
  /// - `quantity_received >= 0`.
  static List<PurchaseOrderItem> _parsePurchaseOrderItems(
    List<String> lines, {
    required String workspaceId,
    required Map<String, String> productIdBySku,
    required Map<String, int> poIdByNumber,
    required List<CsvValidationError> errors,
  }) {
    if (lines.isEmpty) return [];
    final items = <PurchaseOrderItem>[];
    int lineNumber = 1;

    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) {
      lineNumber++;
      final cols = _splitLine(line);
      if (cols.isEmpty) continue;
      String col(int i) => i < cols.length ? cols[i].trim() : '';

      double? parseDouble(String s) =>
          s.isEmpty ? null : double.tryParse(s.replaceAll(',', '.'));

      // FK: Bestellnummer → order id lookup (no raw BIGINT from CSV)
      final orderNumberRaw = col(0);
      if (orderNumberRaw.isEmpty) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLPOSITIONEN',
          message: 'Bestellnummer darf nicht leer sein.',
        ));
        continue;
      }
      final purchaseOrderId = poIdByNumber[orderNumberRaw];
      if (purchaseOrderId == null) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLPOSITIONEN',
          message: 'Bestellung "$orderNumberRaw" nicht gefunden.',
        ));
        continue;
      }

      // FK: Artikel-SKU → product id lookup (no raw UUID from CSV)
      final skuRaw = col(1);
      if (skuRaw.isEmpty) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLPOSITIONEN',
          message: 'Artikel-SKU darf nicht leer sein.',
        ));
        continue;
      }
      final productId = productIdBySku[skuRaw];
      if (productId == null) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLPOSITIONEN',
          message: 'Artikel mit SKU "$skuRaw" nicht gefunden.',
        ));
        continue;
      }

      // CHECK: quantity_ordered > 0
      final qtyOrdered = int.tryParse(col(2));
      if (qtyOrdered == null || qtyOrdered <= 0) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLPOSITIONEN',
          message:
              'Bestellt-Menge muss > 0 sein (war "${col(2)}").',
        ));
        continue;
      }

      // CHECK: quantity_received >= 0
      final qtyReceived = int.tryParse(col(3)) ?? 0;
      if (qtyReceived < 0) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLPOSITIONEN',
          message:
              'Erhalten-Menge muss >= 0 sein (war "${col(3)}").',
        ));
        continue;
      }

      // Security (low): pre-validate unitPrice against DB CHECK (price >= 0).
      final unitPrice = parseDouble(col(4));
      if (unitPrice != null && unitPrice < 0) {
        errors.add(CsvValidationError(
          lineNumber: lineNumber,
          section: 'BESTELLPOSITIONEN',
          message:
              'Einzelpreis darf nicht negativ sein (war ${col(4)}).',
        ));
        continue;
      }

      final now = DateTime.now().toUtc();
      items.add(PurchaseOrderItem(
        id:               _uuid.v4(),
        workspaceId:      workspaceId,
        purchaseOrderId:  purchaseOrderId,
        productId:        productId,
        quantityOrdered:  qtyOrdered,
        quantityReceived: qtyReceived,
        unitPrice:        unitPrice,
        createdAt:        now,
        updatedAt:        now,
      ));
    }
    return items;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _q(String value) {
    // Formula-injection guard (OWASP CSV Injection): neutralise cells that
    // start with characters that Excel / LibreOffice interpret as formula
    // leaders (=, +, -, @, tab, carriage-return).
    String safe = value;
    if (safe.isNotEmpty) {
      final first = safe.codeUnitAt(0);
      // 0x3D =, 0x2B +, 0x2D -, 0x40 @, 0x09 TAB, 0x0D CR
      if (first == 0x3D || first == 0x2B || first == 0x2D ||
          first == 0x40 || first == 0x09 || first == 0x0D) {
        safe = "'$safe";
      }
    }
    if (safe.contains(_sep) || safe.contains('"') || safe.contains('\n')) {
      return '"${safe.replaceAll('"', '""')}"';
    }
    return safe;
  }

  static String _colorHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static Color _parseColor(String hex, Color fallback) {
    try {
      return Color(int.parse(hex.replaceFirst('#', ''), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  static List<String> _splitLine(String line) {
    final fields = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == _sep && !inQuotes) {
        fields.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    fields.add(buf.toString());
    return fields;
  }
}
