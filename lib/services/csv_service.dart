import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/deal.dart';

class CsvService {
  static const _separator = ';';
  static final _dateFmt = DateFormat('dd.MM.yyyy');

  static const List<String> _headers = [
    'ID',
    'Produkt',
    'Anzahl',
    'Versandtyp',
    'Shop',
    'Bestelldatum',
    'EK Netto',
    'EK Brutto',
    'VK',
    'Käufer',
    'Ticketnummer',
    'Tracking',
    'Ankunft',
    'Status',
    'Beleg',
    'Notiz',
  ];

  // ── Export ────────────────────────────────────────────────────────────────

  /// Returns (filePath, errorMessage). filePath is null on cancel/error.
  static Future<(String?, String?)> exportDeals(List<Deal> deals) async {
    try {
      final csvContent = _buildCsv(deals);
      final bytes = Uint8List.fromList(utf8.encode(csvContent));

      final fileName =
          'deals_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

      if (kIsWeb) {
        // On web, saveFile triggers a browser download and always returns null.
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

      if (outputPath == null) return (null, null); // user cancelled

      await File(outputPath)
          .writeAsString(csvContent, encoding: utf8, flush: true);
      return (outputPath, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static String _buildCsv(List<Deal> deals) {
    final buf = StringBuffer();
    // BOM for Excel UTF-8 recognition
    buf.write('\uFEFF');
    buf.writeln(_headers.map(_quote).join(_separator));
    for (final d in deals) {
      buf.writeln([
        d.id,
        _quote(d.product),
        d.quantity,
        _quote(d.shippingType),
        _quote(d.shop),
        _dateFmt.format(d.orderDate),
        d.ekNetto != null ? d.ekNetto!.toStringAsFixed(2) : '',
        d.ekBrutto != null ? d.ekBrutto!.toStringAsFixed(2) : '',
        d.vk != null ? d.vk!.toStringAsFixed(2) : '',
        _quote(d.buyer ?? ''),
        _quote(d.ticketNumber ?? ''),
        _quote(d.tracking ?? ''),
        d.arrivalDate != null ? _dateFmt.format(d.arrivalDate!) : '',
        _quote(d.status),
        _quote(d.beleg),
        _quote(d.note ?? ''),
      ].join(_separator));
    }
    return buf.toString();
  }

  static String _quote(String value) {
    if (value.contains(_separator) ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Returns (deals, errorMessage). deals is null on cancel/error.
  static Future<(List<Deal>?, String?)> importDeals(int nextId) async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'CSV importieren',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true, // Required on web; harmless on desktop
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
          // Fallback to bytes if path is unavailable (e.g. some desktop scenarios)
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

      // Strip BOM if present
      if (content.startsWith('\uFEFF')) content = content.substring(1);

      final deals = _parseCsv(content, nextId);
      return (deals, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static List<Deal> _parseCsv(String content, int startId) {
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return [];

    // Skip header row
    final dataLines = lines.skip(1).where((l) => l.trim().isNotEmpty);
    final deals = <Deal>[];
    int currentId = startId;

    for (final line in dataLines) {
      final cols = _splitLine(line);
      if (cols.length < 2) continue;

      String col(int i) => i < cols.length ? cols[i].trim() : '';

      DateTime? parseDate(String s) {
        if (s.isEmpty) return null;
        try {
          return _dateFmt.parse(s);
        } catch (_) {
          try {
            return DateTime.parse(s);
          } catch (_) {
            return null;
          }
        }
      }

      double? parseDouble(String s) =>
          s.isEmpty ? null : double.tryParse(s.replaceAll(',', '.'));

      final orderDate = parseDate(col(5)) ?? DateTime.now();
      final ekNetto = parseDouble(col(6));
      final ekBrutto = parseDouble(col(7));

      // If only one price is present, derive the other
      double? finalNetto = ekNetto;
      double? finalBrutto = ekBrutto;
      if (finalNetto != null && finalBrutto == null) {
        finalBrutto = finalNetto * 1.19;
      } else if (finalBrutto != null && finalNetto == null) {
        finalNetto = finalBrutto / 1.19;
      }

      final validStatuses = [
        'Bestellt',
        'Unterwegs',
        'Angekommen',
        'Rechnung gestellt',
        'Done',
      ];
      final status = validStatuses.contains(col(13)) ? col(13) : 'Bestellt';
      final beleg = col(14) == 'Ja' ? 'Ja' : 'Nein';

      deals.add(Deal(
        id: currentId++,
        product: col(1).isEmpty ? 'Unbekannt' : col(1),
        quantity: int.tryParse(col(2)) ?? 1,
        shippingType: col(3).isEmpty ? 'Reship' : col(3),
        shop: col(4).isEmpty ? 'Unbekannt' : col(4),
        orderDate: orderDate,
        ekNetto: finalNetto,
        ekBrutto: finalBrutto,
        vk: parseDouble(col(8)),
        buyer: col(9).isEmpty ? null : col(9),
        ticketNumber: col(10).isEmpty ? null : col(10),
        tracking: col(11).isEmpty ? null : col(11),
        arrivalDate: parseDate(col(12)),
        status: status,
        beleg: beleg,
        note: col(15).isEmpty ? null : col(15),
      ));
    }

    return deals;
  }

  /// Splits a CSV line respecting quoted fields.
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
      } else if (ch == _separator && !inQuotes) {
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
