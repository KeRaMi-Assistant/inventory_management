import 'dart:convert';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'statistics_service.dart';

/// Erzeugt Reports (PDF, CSV, Excel) aus einem [StatisticsService].
class StatisticsExportService {
  StatisticsExportService(this.stats);

  final StatisticsService stats;

  static final _money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
  static final _date = DateFormat('dd.MM.yyyy', 'de_DE');

  // ── PDF: Übersichts-Report ────────────────────────────────────────────────

  Future<Uint8List> buildOverviewPdf() async {
    final pdf = pw.Document();
    final r = stats.range;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            'Statistik-Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Zeitraum: ${_date.format(r.from)} – ${_date.format(r.to)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),

          // KPI-Block
          pw.Header(level: 1, text: 'Kennzahlen'),
          _kpiTable(),
          pw.SizedBox(height: 12),

          // Top-Produkte
          pw.Header(level: 1, text: 'Top-Produkte (max. 10)'),
          _productsTable(),
          pw.SizedBox(height: 12),

          // Käufer
          pw.Header(level: 1, text: 'Käufer (max. 10)'),
          _buyersTable(),
          pw.SizedBox(height: 12),

          // Shops
          pw.Header(level: 1, text: 'Shops (max. 10)'),
          _shopsTable(),
          pw.SizedBox(height: 12),

          // Cashflow
          pw.Header(level: 1, text: 'Cashflow'),
          _cashflowTable(),

          pw.SizedBox(height: 24),
          pw.Text(
            'Generiert ${_date.format(DateTime.now())} · CanLogistics',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _kpiTable() {
    final rows = [
      ['Umsatz', _money.format(stats.revenue)],
      ['Profit', _money.format(stats.profit)],
      ['Profit-Marge', '${stats.margin.toStringAsFixed(1)}%'],
      ['ROI', '${stats.roi.toStringAsFixed(1)}%'],
      ['Offene Forderungen', _money.format(stats.openReceivables)],
      ['Anzahl Deals', '${stats.dealCount}'],
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
      },
      children: rows.map((r) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(r[0],
                  style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(r[1],
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        );
      }).toList(),
    );
  }

  pw.Widget _productsTable() {
    final rows = stats.topProducts.take(10).toList();
    return _genericTable(
      headers: ['Produkt', 'Deals', 'Umsatz', 'Profit', 'Marge'],
      rows: rows
          .map((p) => [
                p.name,
                '${p.count}',
                _money.format(p.revenue),
                _money.format(p.profit),
                '${p.marginPct.toStringAsFixed(1)}%',
              ])
          .toList(),
    );
  }

  pw.Widget _buyersTable() {
    final rows = stats.buyerStats.take(10).toList();
    return _genericTable(
      headers: ['Käufer', 'Deals', 'Umsatz', 'Profit', 'Offen'],
      rows: rows
          .map((b) => [
                b.name,
                '${b.count}',
                _money.format(b.revenue),
                _money.format(b.profit),
                _money.format(b.openAmount),
              ])
          .toList(),
    );
  }

  pw.Widget _shopsTable() {
    final rows = stats.shopStats.take(10).toList();
    return _genericTable(
      headers: ['Shop', 'Deals', 'Volumen', 'Profit', 'Marge'],
      rows: rows
          .map((s) => [
                s.name,
                '${s.count}',
                _money.format(s.volume),
                _money.format(s.profit),
                '${s.marginPct.toStringAsFixed(1)}%',
              ])
          .toList(),
    );
  }

  pw.Widget _cashflowTable() {
    final cf = stats.cashflow;
    return _genericTable(
      headers: ['Posten', 'Wert'],
      rows: [
        ['Eingegangen', _money.format(cf.received)],
        ['Offen 0–7 Tage', _money.format(cf.bucket0_7)],
        ['Offen 8–30 Tage', _money.format(cf.bucket8_30)],
        ['Offen 31–60 Tage', _money.format(cf.bucket31_60)],
        ['Offen > 60 Tage', _money.format(cf.bucket60p)],
        ['Ø Zahlungsdauer', '${cf.avgPaymentDays.toStringAsFixed(1)} T.'],
      ],
    );
  }

  pw.Widget _genericTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        ),
        ...rows.map((r) => pw.TableRow(
              children: r
                  .map((c) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(c,
                            style: const pw.TextStyle(fontSize: 9)),
                      ))
                  .toList(),
            )),
      ],
    );
  }

  Future<void> savePdf(Uint8List bytes) async {
    final fileName =
        'statistik_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    }
    final path = await FilePicker.saveFile(
      dialogTitle: 'Report speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    if (path == null) {
      // Fallback auf Drucken-Dialog
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  // ── CSV: Roh-Daten Deals ──────────────────────────────────────────────────

  String buildDealsCsv() {
    final buf = StringBuffer();
    buf.writeln(
        'ID;Datum;Produkt;Menge;Shop;Käufer;EK Netto;EK Brutto;VK;Profit;Status;Währung');
    for (final d in stats.filteredDeals) {
      buf.writeln([
        d.id,
        _date.format(d.orderDate),
        _csv(d.product),
        d.quantity,
        _csv(d.shop),
        _csv(d.buyer ?? ''),
        d.ekNetto?.toStringAsFixed(2) ?? '',
        d.ekBrutto?.toStringAsFixed(2) ?? '',
        d.vk?.toStringAsFixed(2) ?? '',
        d.totalProfit?.toStringAsFixed(2) ?? '',
        d.status,
        d.currency,
      ].join(';'));
    }
    return buf.toString();
  }

  Future<void> saveDealsCsv() async {
    final csv = buildDealsCsv();
    await _saveText(
      csv,
      'deals_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

  // ── CSV: Steuerberater-Export ─────────────────────────────────────────────

  String buildTaxCsv() {
    final buf = StringBuffer();
    buf.writeln('Datum;Netto;MwSt-Satz;MwSt-Betrag;Brutto;Währung;Produkt');
    for (final d in stats.filteredDeals) {
      final netto = d.ekGesamtNetto ?? 0;
      final brutto = d.ekGesamtBrutto ?? 0;
      final tax = brutto - netto;
      final taxRate = d.taxRate ?? (netto == 0 ? 0 : tax / netto);
      buf.writeln([
        _date.format(d.orderDate),
        netto.toStringAsFixed(2),
        '${(taxRate * 100).toStringAsFixed(1)}%',
        tax.toStringAsFixed(2),
        brutto.toStringAsFixed(2),
        d.currency,
        _csv(d.product),
      ].join(';'));
    }
    return buf.toString();
  }

  Future<void> saveTaxCsv() async {
    final csv = buildTaxCsv();
    await _saveText(
      csv,
      'mwst_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

  // ── Excel ─────────────────────────────────────────────────────────────────

  Future<void> saveExcel() async {
    final book = xls.Excel.createExcel();
    final sheet = book['Deals'];
    sheet.appendRow([
      xls.TextCellValue('ID'),
      xls.TextCellValue('Datum'),
      xls.TextCellValue('Produkt'),
      xls.TextCellValue('Menge'),
      xls.TextCellValue('Shop'),
      xls.TextCellValue('Käufer'),
      xls.TextCellValue('EK Netto'),
      xls.TextCellValue('EK Brutto'),
      xls.TextCellValue('VK'),
      xls.TextCellValue('Profit'),
      xls.TextCellValue('Status'),
      xls.TextCellValue('Währung'),
    ]);
    for (final d in stats.filteredDeals) {
      sheet.appendRow([
        xls.IntCellValue(d.id),
        xls.TextCellValue(_date.format(d.orderDate)),
        xls.TextCellValue(d.product),
        xls.IntCellValue(d.quantity),
        xls.TextCellValue(d.shop),
        xls.TextCellValue(d.buyer ?? ''),
        xls.DoubleCellValue(d.ekNetto ?? 0),
        xls.DoubleCellValue(d.ekBrutto ?? 0),
        xls.DoubleCellValue(d.vk ?? 0),
        xls.DoubleCellValue(d.totalProfit ?? 0),
        xls.TextCellValue(d.status),
        xls.TextCellValue(d.currency),
      ]);
    }
    book.delete('Sheet1');
    final bytes = book.save();
    if (bytes == null) return;
    final fileName =
        'deals_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: 'Excel-Export: $fileName'));
      return;
    }
    await FilePicker.saveFile(
      dialogTitle: 'Excel-Datei speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(bytes),
    );
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  String _csv(String s) {
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<void> _saveText(String content, String fileName) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: content));
      return;
    }
    await FilePicker.saveFile(
      dialogTitle: 'Datei speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [fileName.split('.').last],
      bytes: bytes,
    );
  }
}
