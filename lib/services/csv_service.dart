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
import '../models/shop.dart';

/// Result of a full CSV import containing all four tables.
class CsvImportResult {
  final List<Deal> deals;
  final List<Shop> shops;
  final List<Buyer> buyers;
  final List<InventoryItem> inventoryItems;
  const CsvImportResult({
    required this.deals,
    required this.shops,
    required this.buyers,
    required this.inventoryItems,
  });
}

class CsvService {
  static const _sep = ';';
  static final _dateFmt = DateFormat('dd.MM.yyyy');
  static const _uuid = Uuid();

  // ── Section markers ───────────────────────────────────────────────────────

  static const _secDeals     = '## DEALS';
  static const _secShops     = '## SHOPS';
  static const _secBuyers    = '## KÄUFER';
  static const _secInventory = '## LAGERBESTAND';

  // ── Column headers ────────────────────────────────────────────────────────

  static const _dealHeaders = [
    'ID', 'Produkt', 'Anzahl', 'Versandtyp', 'Shop', 'Bestelldatum',
    'EK Netto', 'EK Brutto', 'VK', 'Käufer', 'Ticketnummer', 'Ticket-URL',
    'Tracking', 'Ankunft', 'Status', 'Beleg', 'Notiz',
  ];

  static const _shopHeaders = [
    'Name', 'Region', 'Channel', 'URL', 'Aktiv',
  ];

  static const _buyerHeaders = [
    'Name', 'Discord-Server-IDs', 'Aktiv', 'Zahlungsstatus',
    'RowFillColor', 'BuyerCellColor', 'FontColor', 'SortOrder',
  ];

  static const _inventoryHeaders = [
    'ID', 'Name', 'SKU', 'Anzahl', 'Mindestbestand', 'Lagerort',
    'Einkaufspreis', 'Ankunft', 'Deal-ID', 'Ticketnummer', 'Ticket-URL',
    'Status', 'Notiz',
  ];

  // ── Export ────────────────────────────────────────────────────────────────

  /// Exports deals, shops, buyers and inventory as a single multi-section CSV.
  static Future<(String?, String?)> exportAll(
    List<Deal> deals,
    List<Shop> shops,
    List<Buyer> buyers,
    List<InventoryItem> inventoryItems,
  ) async {
    try {
      final csvContent = _buildAll(deals, shops, buyers, inventoryItems);
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final fileName = 'deals_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

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
    List<InventoryItem> inventoryItems,
  ) {
    final buf = StringBuffer();
    buf.write('\uFEFF'); // BOM for Excel UTF-8

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
        _q(d.beleg),
        _q(d.note ?? ''),
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
        _q(b.discordServerIds.join('|')), // multiple IDs separated by |
        b.active ? 'Ja' : 'Nein',
        _q(b.paymentStatus),
        _colorHex(b.rowFillColor),
        _colorHex(b.buyerCellColor),
        _colorHex(b.fontColor),
        b.sortOrder,
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
        item.quantity,
        item.minStock,
        _q(item.location ?? ''),
        item.costPrice != null ? item.costPrice!.toStringAsFixed(2) : '',
        item.arrivalDate != null ? _dateFmt.format(item.arrivalDate!) : '',
        item.dealId?.toString() ?? '',
        _q(item.ticketNumber ?? ''),
        _q(item.ticketUrl    ?? ''),
        _q(item.status),
        _q(item.note ?? ''),
      ].join(_sep));
    }

    return buf.toString();
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Picks a CSV file and returns all three tables (deals, shops, buyers).
  /// Legacy single-table CSVs (no section markers) are imported as deals only.
  static Future<(CsvImportResult?, String?)> importAll(int nextDealId) async {
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

      if (content.startsWith('\uFEFF')) content = content.substring(1);
      return (_parseAll(content, nextDealId), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static CsvImportResult _parseAll(String content, int startId) {
    final allLines = content.split(RegExp(r'\r?\n'));
    final sections = <String, List<String>>{};
    String? currentSection;

    for (final line in allLines) {
      final trimmed = line.trim();
      if (trimmed == _secDeals || trimmed == _secShops ||
          trimmed == _secBuyers || trimmed == _secInventory) {
        currentSection = trimmed;
        sections[currentSection] = [];
      } else if (currentSection != null && trimmed.isNotEmpty) {
        sections[currentSection]!.add(line);
      }
    }

    // Legacy: no section markers → treat all lines as deals
    final dealLines      = sections[_secDeals]     ?? allLines.where((l) => l.trim().isNotEmpty).toList();
    final shopLines      = sections[_secShops]     ?? [];
    final buyerLines     = sections[_secBuyers]    ?? [];
    final inventoryLines = sections[_secInventory] ?? [];

    return CsvImportResult(
      deals:          _parseDeals(dealLines, startId),
      shops:          _parseShops(shopLines),
      buyers:         _parseBuyers(buyerLines),
      inventoryItems: _parseInventory(inventoryLines),
    );
  }

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

      double? finalNetto  = ekNetto;
      double? finalBrutto = ekBrutto;
      if (finalNetto != null && finalBrutto == null) {
        finalBrutto = finalNetto * 1.19;
      } else if (finalBrutto != null && finalNetto == null) {
        finalNetto = finalBrutto / 1.19;
      }

      // Support old 16-col format (no Ticket-URL) and new 17-col format.
      final hasTicketUrlCol = cols.length >= 17;
      final ticketUrl  = hasTicketUrlCol ? col(11) : null;
      final tracking   = col(hasTicketUrlCol ? 12 : 11);
      final arrivalRaw = col(hasTicketUrlCol ? 13 : 12);
      final statusRaw  = col(hasTicketUrlCol ? 14 : 13);
      final belegRaw   = col(hasTicketUrlCol ? 15 : 14);
      final noteRaw    = col(hasTicketUrlCol ? 16 : 15);

      const validStatuses = [
        'Bestellt', 'Unterwegs', 'Angekommen', 'Rechnung gestellt', 'Done',
      ];
      final status = validStatuses.contains(statusRaw) ? statusRaw : 'Bestellt';
      final beleg  = belegRaw == 'Ja' ? 'Ja' : 'Nein';

      deals.add(Deal(
        id: currentId++,
        product:      col(1).isEmpty ? 'Unbekannt' : col(1),
        quantity:     int.tryParse(col(2)) ?? 1,
        shippingType: col(3).isEmpty ? 'Reship' : col(3),
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
        beleg:  beleg,
        note:   noteRaw.isEmpty ? null : noteRaw,
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

  static List<InventoryItem> _parseInventory(List<String> lines) {
    if (lines.isEmpty) return [];
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

      const validStatuses = ['Im Lager', 'Reserviert', 'Versandt', 'Verkauft'];
      final rawStatus = col(11);
      final status = validStatuses.contains(rawStatus) ? rawStatus : 'Im Lager';

      items.add(InventoryItem(
        id:           col(0).isEmpty ? _uuid.v4() : col(0),
        name:         col(1).isEmpty ? 'Unbekannt' : col(1),
        sku:          col(2).isEmpty ? null : col(2),
        quantity:     int.tryParse(col(3))  ?? 0,
        minStock:     int.tryParse(col(4))  ?? 0,
        location:     col(5).isEmpty ? null : col(5),
        costPrice:    double.tryParse(col(6).replaceAll(',', '.')),
        arrivalDate:  parseDate(col(7)),
        dealId:       int.tryParse(col(8)),
        ticketNumber: col(9).isEmpty  ? null : col(9),
        ticketUrl:    col(10).isEmpty ? null : col(10),
        status:       status,
        note:         col(12).isEmpty ? null : col(12),
      ));
    }
    return items;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _q(String value) {
    if (value.contains(_sep) || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
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
