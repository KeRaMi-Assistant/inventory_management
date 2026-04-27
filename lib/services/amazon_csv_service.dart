import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/deal.dart';

// ─── Result model ─────────────────────────────────────────────────────────────

class AmazonImportResult {
  final List<AmazonDealPreview> newItems;
  final List<String> skippedKeys;
  final int totalDataRows;
  final int cancelledRows;

  const AmazonImportResult({
    required this.newItems,
    required this.skippedKeys,
    required this.totalDataRows,
    required this.cancelledRows,
  });
}

class AmazonDealPreview {
  /// Human-readable order number (e.g. 306-5580998-3956325)
  final String orderNumber;

  /// Composite dedup key stored as ticketNumber: "orderId:ASIN"
  final String dedupKey;

  final String product;
  final String? asin;
  final int quantity;
  final double? ekNetto;   // Kauf-PPU per unit (net)
  final double? ekBrutto;  // Kauf-PPU × (1 + vatRate) per unit
  final DateTime orderDate;
  final String? category;

  const AmazonDealPreview({
    required this.orderNumber,
    required this.dedupKey,
    required this.product,
    this.asin,
    required this.quantity,
    this.ekNetto,
    this.ekBrutto,
    required this.orderDate,
    this.category,
  });

  Deal toDeal({required int id, required String shopName}) => Deal(
        id: id,
        product: product,
        quantity: quantity,
        shippingType: 'Reship',
        shop: shopName,
        orderDate: orderDate,
        ekNetto: ekNetto,
        ekBrutto: ekBrutto,
        ticketNumber: dedupKey,
        status: 'Bestellt',
        beleg: 'Nein',
        note: [
          'Bestellnr.: $orderNumber',
          if (asin != null && asin!.isNotEmpty) 'ASIN: $asin',
        ].join(' | '),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AmazonCsvService {
  // ── Exact column names from Amazon Business Bestellbericht ────────────────
  // (lowercase, trimmed — matched with contains() for robustness)
  static const _orderIdKey = 'bestellnummer';
  static const _statusKey = 'bestellstatus';
  static const _dateKey = 'bestelldatum';
  static const _titleKey = 'titel';
  static const _asinKey = 'asin';
  static const _qtyKey = 'artikelmenge';
  static const _unitPriceKey = 'kauf-ppu';
  static const _vatRateKey = 'umsatzsteuersatz';
  static const _categoryKey = 'amazon-interne produktkategorie';

  // ── Pick file & parse ──────────────────────────────────────────────────────

  static Future<(AmazonImportResult?, String?)> pickAndParse(
    Set<String> existingDedupKeys,
    int startId,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Amazon Bestellbericht (CSV) auswählen',
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
        final bytes = result.files.first.bytes;
        final path = result.files.first.path;
        if (bytes != null) {
          content = utf8.decode(bytes, allowMalformed: true);
        } else if (path != null) {
          try {
            content = await File(path).readAsString(encoding: utf8);
          } catch (_) {
            content = await File(path).readAsString(encoding: latin1);
          }
        } else {
          return (null, 'Datei konnte nicht gelesen werden.');
        }
      }

      // Strip UTF-8 BOM
      if (content.startsWith('\uFEFF')) content = content.substring(1);

      final parsed = _parse(content, existingDedupKeys);
      return (parsed, null);
    } on AmazonCsvException catch (e) {
      return (null, e.message);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // ── Parser ────────────────────────────────────────────────────────────────

  static AmazonImportResult _parse(
    String content,
    Set<String> existingDedupKeys,
  ) {
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length < 2) {
      throw AmazonCsvException('Die Datei enthält keine Daten.');
    }

    // Amazon Bestellbericht uses comma as separator
    final sep = lines[0].contains(';') ? ';' : ',';

    final rawHeaders = _splitLine(lines[0], sep);
    final headers = rawHeaders.map((h) => h.trim().toLowerCase()).toList();

    int findCol(String key) {
      // exact match first, then partial
      final exact = headers.indexOf(key);
      if (exact != -1) return exact;
      return headers.indexWhere((h) => h.contains(key));
    }

    final orderIdCol = findCol(_orderIdKey);
    final statusCol = findCol(_statusKey);
    final dateCol = findCol(_dateKey);
    final titleCol = findCol(_titleKey);
    final asinCol = findCol(_asinKey);
    final qtyCol = findCol(_qtyKey);
    final unitPriceCol = findCol(_unitPriceKey);
    final vatRateCol = findCol(_vatRateKey);
    final categoryCol = findCol(_categoryKey);

    if (orderIdCol == -1 || titleCol == -1) {
      throw AmazonCsvException(
        'Keine Amazon-Bestellbericht-Spalten gefunden.\n\n'
        'Erkannte Spalten: ${rawHeaders.take(6).join(', ')}…\n\n'
        'Bitte einen Amazon Business Bestellbericht exportieren:\n'
        'Business.Amazon.de → Berichte → Bestellberichte → CSV herunterladen.',
      );
    }

    // ── Group rows by (Bestellnummer, ASIN) ─────────────────────────────────
    // Amazon lists one row per payment event; same product in same order
    // appears multiple times. We take the first row per (order, ASIN) group.
    final seen = <String>{};
    final grouped = <_Row>[];
    int totalRows = 0;
    int cancelledRows = 0;

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final cols = _splitLine(line, sep);
      if (cols.length < 2) continue;

      String get(int i) =>
          i >= 0 && i < cols.length ? _clean(cols[i]) : '';

      // Skip cancelled orders
      final status = statusCol >= 0 ? get(statusCol) : '';
      if (status.toLowerCase() == 'storniert') {
        cancelledRows++;
        continue;
      }

      final orderId = get(orderIdCol);
      if (orderId.isEmpty) continue;
      totalRows++;

      final asin = asinCol >= 0 ? get(asinCol) : '';
      final dedupKey = _buildKey(orderId, asin);

      // Skip rows we've already seen (same product, same order)
      if (seen.contains(dedupKey)) continue;
      seen.add(dedupKey);

      grouped.add(_Row(
        orderId: orderId,
        asin: asin.isEmpty || asin == 'N/A' ? null : asin,
        dedupKey: dedupKey,
        title: titleCol >= 0 ? get(titleCol) : '',
        qty: qtyCol >= 0 ? (int.tryParse(get(qtyCol)) ?? 1) : 1,
        unitPrice: unitPriceCol >= 0 ? _parsePrice(get(unitPriceCol)) : null,
        vatRate: vatRateCol >= 0 ? _parseVatRate(get(vatRateCol)) : null,
        date: dateCol >= 0 ? (_parseDate(get(dateCol)) ?? DateTime.now()) : DateTime.now(),
        category: categoryCol >= 0 ? get(categoryCol).nullIfEmpty : null,
      ));
    }

    // ── Separate into new vs existing ────────────────────────────────────────
    final newItems = <AmazonDealPreview>[];
    final skippedKeys = <String>[];

    for (final row in grouped) {
      if (existingDedupKeys.contains(row.dedupKey)) {
        skippedKeys.add(row.dedupKey);
        continue;
      }

      double? ekNetto = row.unitPrice;
      double? ekBrutto;
      if (ekNetto != null) {
        final vat = row.vatRate ?? 0.19;
        ekBrutto = ekNetto * (1 + vat);
      }

      newItems.add(AmazonDealPreview(
        orderNumber: row.orderId,
        dedupKey: row.dedupKey,
        product: row.title.isEmpty ? 'Unbekannt' : row.title,
        asin: row.asin,
        quantity: row.qty,
        ekNetto: ekNetto,
        ekBrutto: ekBrutto,
        orderDate: row.date,
        category: row.category,
      ));
    }

    return AmazonImportResult(
      newItems: newItems,
      skippedKeys: skippedKeys,
      totalDataRows: totalRows,
      cancelledRows: cancelledRows,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _buildKey(String orderId, String asin) {
    if (asin.isEmpty || asin == 'N/A') return orderId;
    return '$orderId:$asin';
  }

  /// Strips surrounding quotes, leading `=` (Excel formula prefix), and trims.
  static String _clean(String s) {
    s = s.trim();
    if (s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).replaceAll('""', '"');
    }
    if (s.startsWith('=')) s = s.substring(1);
    return s.trim();
  }

  static double? _parsePrice(String s) {
    if (s.isEmpty || s == 'N/A') return null;
    // Strip currency symbols
    s = s.replaceAll(RegExp(r'[€\$£\s\u00a0]'), '');
    // European format: 1.234,56 → strip dots (thousands), replace comma with dot
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(s);
  }

  /// Parse "19%" → 0.19, "0%" → 0.0
  static double? _parseVatRate(String s) {
    if (s.isEmpty) return null;
    s = s.replaceAll('%', '').trim();
    final v = double.tryParse(s);
    return v != null ? v / 100.0 : null;
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    final formats = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('dd.MM.yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
    ];
    for (final fmt in formats) {
      try {
        return fmt.parse(s);
      } catch (_) {}
    }
    try {
      return DateTime.parse(s);
    } catch (_) {}
    return null;
  }

  static List<String> _splitLine(String line, String sep) {
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
      } else if (!inQuotes && line.startsWith(sep, i)) {
        fields.add(buf.toString());
        buf.clear();
        i += sep.length - 1;
      } else {
        buf.write(ch);
      }
    }
    fields.add(buf.toString());
    return fields;
  }
}

// ── Internal row struct ────────────────────────────────────────────────────────

class _Row {
  final String orderId;
  final String? asin;
  final String dedupKey;
  final String title;
  final int qty;
  final double? unitPrice;
  final double? vatRate;
  final DateTime date;
  final String? category;

  const _Row({
    required this.orderId,
    required this.asin,
    required this.dedupKey,
    required this.title,
    required this.qty,
    required this.unitPrice,
    required this.vatRate,
    required this.date,
    required this.category,
  });
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

class AmazonCsvException implements Exception {
  final String message;
  const AmazonCsvException(this.message);
}
