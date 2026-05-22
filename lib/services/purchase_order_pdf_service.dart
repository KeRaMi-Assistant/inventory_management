import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/supplier.dart';

/// Erzeugt Bestell-PDFs (Purchase Order / Lieferschein-Stil) für eine
/// [PurchaseOrder].
///
/// Pattern analog zu [StatisticsExportService]: Dokument aufbauen via
/// `pdf`/`widgets.dart`, teilen via `printing`-Package.
///
/// Keine Supabase-Calls — Service erhält alle Daten als Parameter.
class PurchaseOrderPdfService {
  static final _money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
  static final _date = DateFormat('dd.MM.yyyy', 'de_DE');

  // ── Öffentliche API ────────────────────────────────────────────────────────

  /// Baut das Bestell-PDF und gibt die rohen Bytes zurück.
  ///
  /// [order] — der Bestellkopf.
  /// [items] — alle Positionen der Bestellung (nicht-gelöschte).
  /// [supplier] — Lieferant; `null` wenn kein Lieferant verknüpft.
  /// [products] — Produkt-Stammsätze, aus denen Positionen aufgelöst werden.
  ///
  /// Strings für Spaltenköpfe und Labels sind als Parameter übergeben, damit
  /// der Aufrufer sie aus [AppLocalizations] befüllen kann (kein
  /// BuildContext-Zugriff im Service nötig).
  static Future<Uint8List> buildPdf({
    required PurchaseOrder order,
    required List<PurchaseOrderItem> items,
    required Supplier? supplier,
    required List<Product> products,
    required PdfLabels labels,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        header: (ctx) => _buildHeader(order: order, labels: labels),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _supplierBlock(supplier: supplier, labels: labels),
          pw.SizedBox(height: 16),
          _orderMetaBlock(order: order, labels: labels),
          pw.SizedBox(height: 20),
          pw.Header(
            level: 1,
            text: labels.sectionItems,
            textStyle: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          _itemsTable(
            items: items,
            products: products,
            labels: labels,
          ),
          pw.SizedBox(height: 12),
          if (order.totalNet != null) _totalRow(order: order, labels: labels),
          if (order.note != null && order.note!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _noteBlock(note: order.note!, labels: labels),
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// Öffnet den System-Teilen/Drucken-Dialog für das PDF.
  ///
  /// Auf Web: [Printing.sharePdf] (Download).
  /// Auf Mobile/Desktop: [Printing.layoutPdf] (nativer Druck-Dialog).
  static Future<void> sharePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    }
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: fileName,
    );
  }

  // ── Dokument-Bausteine ─────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required PurchaseOrder order,
    required PdfLabels labels,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              labels.documentTitle,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.Text(
              order.orderNumber,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey400, thickness: 0.8),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generiert ${_date.format(DateTime.now())} · InventoryOS',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
            pw.Text(
              '${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _supplierBlock({
    required Supplier? supplier,
    required PdfLabels labels,
  }) {
    if (supplier == null) return pw.SizedBox.shrink();

    final addressParts = <String>[];
    if (supplier.addressStreet != null && supplier.addressStreet!.isNotEmpty) {
      addressParts.add(supplier.addressStreet!);
    }
    final cityLine = [
      if (supplier.addressZip != null && supplier.addressZip!.isNotEmpty)
        supplier.addressZip!,
      if (supplier.addressCity != null && supplier.addressCity!.isNotEmpty)
        supplier.addressCity!,
    ].join(' ');
    if (cityLine.isNotEmpty) addressParts.add(cityLine);
    if (supplier.addressCountry != null &&
        supplier.addressCountry!.isNotEmpty &&
        supplier.addressCountry != 'DE') {
      addressParts.add(supplier.addressCountry!);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            labels.supplierLabel,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            supplier.name,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          if (addressParts.isNotEmpty)
            pw.Text(
              addressParts.join(', '),
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          if (supplier.vatId != null && supplier.vatId!.isNotEmpty)
            pw.Text(
              '${labels.vatIdLabel}: ${supplier.vatId!}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          if (supplier.email != null && supplier.email!.isNotEmpty)
            pw.Text(
              supplier.email!,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _orderMetaBlock({
    required PurchaseOrder order,
    required PdfLabels labels,
  }) {
    final rows = <_MetaRow>[
      if (order.orderDate != null)
        _MetaRow(labels.orderDateLabel, _date.format(order.orderDate!)),
      if (order.expectedDate != null)
        _MetaRow(labels.expectedDateLabel, _date.format(order.expectedDate!)),
      _MetaRow(labels.statusLabel, _statusLabel(order.status, labels)),
    ];

    if (rows.isEmpty) return pw.SizedBox.shrink();

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(140),
        1: pw.FlexColumnWidth(1),
      },
      children: rows
          .map(
            (r) => pw.TableRow(
              children: [
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: pw.Text(
                    r.label,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: pw.Text(
                    r.value,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _itemsTable({
    required List<PurchaseOrderItem> items,
    required List<Product> products,
    required PdfLabels labels,
  }) {
    // Baut eine Produkt-Map für schnellen Zugriff
    final productMap = {for (final p in products) p.id: p};

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: pw.FlexColumnWidth(3),   // Produkt-Name
        1: pw.FixedColumnWidth(70), // Bestellt
        2: pw.FixedColumnWidth(70), // Erhalten
        3: pw.FixedColumnWidth(80), // Einzelpreis
        4: pw.FixedColumnWidth(80), // Summe
      },
      children: [
        // Tabellenkopf
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell(labels.colProduct, isHeader: true),
            _cell(labels.colOrdered, isHeader: true, align: pw.Alignment.centerRight),
            _cell(labels.colReceived, isHeader: true, align: pw.Alignment.centerRight),
            _cell(labels.colUnitPrice, isHeader: true, align: pw.Alignment.centerRight),
            _cell(labels.colLineTotal, isHeader: true, align: pw.Alignment.centerRight),
          ],
        ),
        // Positionen
        ...items.asMap().entries.map((entry) {
          final item = entry.value;
          final product = productMap[item.productId];
          final productName = product?.name ?? item.productId ?? '—';
          final unitPrice = item.unitPrice;
          final lineTotal = unitPrice != null
              ? unitPrice * item.quantityOrdered
              : null;
          final isOdd = entry.key.isOdd;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isOdd ? PdfColors.grey50 : PdfColors.white,
            ),
            children: [
              _cell(productName),
              _cell(item.quantityOrdered.toString(), align: pw.Alignment.centerRight),
              _cell(item.quantityReceived.toString(), align: pw.Alignment.centerRight),
              _cell(
                unitPrice != null ? _money.format(unitPrice) : '—',
                align: pw.Alignment.centerRight,
              ),
              _cell(
                lineTotal != null ? _money.format(lineTotal) : '—',
                align: pw.Alignment.centerRight,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _totalRow({
    required PurchaseOrder order,
    required PdfLabels labels,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                '${labels.totalNetLabel}: ',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                _money.format(order.totalNet!),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _noteBlock({
    required String note,
    required PdfLabels labels,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          labels.noteLabel,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          note,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  // ── Hilfsmethoden ──────────────────────────────────────────────────────────

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey800 : PdfColors.grey700,
        ),
      ),
    );
  }

  static String _statusLabel(
    PurchaseOrderStatus status,
    PdfLabels labels,
  ) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return labels.statusDraft;
      case PurchaseOrderStatus.ordered:
        return labels.statusOrdered;
      case PurchaseOrderStatus.partiallyReceived:
        return labels.statusPartial;
      case PurchaseOrderStatus.received:
        return labels.statusReceived;
      case PurchaseOrderStatus.cancelled:
        return labels.statusCancelled;
    }
  }

  /// Datei-Name für das PDF, z. B. `bestellung_PO-2026-0001.pdf`.
  static String fileName(String orderNumber) {
    final safe = orderNumber.replaceAll(RegExp(r'[^\w\-]'), '_');
    return 'bestellung_$safe.pdf';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hilfstrukturen
// ─────────────────────────────────────────────────────────────────────────────

/// Alle lokalisierten Strings für das Bestell-PDF.
///
/// Wird vom Aufrufer aus [AppLocalizations] befüllt, damit der Service
/// keinen [BuildContext] benötigt.
class PdfLabels {
  const PdfLabels({
    required this.documentTitle,
    required this.supplierLabel,
    required this.vatIdLabel,
    required this.orderDateLabel,
    required this.expectedDateLabel,
    required this.statusLabel,
    required this.statusDraft,
    required this.statusOrdered,
    required this.statusPartial,
    required this.statusReceived,
    required this.statusCancelled,
    required this.sectionItems,
    required this.colProduct,
    required this.colOrdered,
    required this.colReceived,
    required this.colUnitPrice,
    required this.colLineTotal,
    required this.totalNetLabel,
    required this.noteLabel,
  });

  final String documentTitle;
  final String supplierLabel;
  final String vatIdLabel;
  final String orderDateLabel;
  final String expectedDateLabel;
  final String statusLabel;
  final String statusDraft;
  final String statusOrdered;
  final String statusPartial;
  final String statusReceived;
  final String statusCancelled;
  final String sectionItems;
  final String colProduct;
  final String colOrdered;
  final String colReceived;
  final String colUnitPrice;
  final String colLineTotal;
  final String totalNetLabel;
  final String noteLabel;
}

class _MetaRow {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;
}
