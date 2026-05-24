import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/product.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/purchase_order_pdf_service.dart';
import '../widgets/app_feedback.dart';
import '../widgets/barcode_scanner_sheet.dart';
import '../widgets/confirm_dialog.dart';
import 'purchase_orders_screen.dart' show PurchaseOrderStatusBadge;

// ─────────────────────────────────────────────────────────────────────────────
// PurchaseOrderDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Detail-Screen für eine einzelne Bestellung (Epic C, Task C5).
///
/// Zeigt Bestellkopf + Positionen (lazy geladen).
/// Ermöglicht Wareneingang buchen (Touch-Stepper pro Position),
/// Status-Wechsel (draft ↔ ordered, → cancelled), Barcode-Einsprung.
///
/// A11y-Keys: `goodsReceiptBookButton`, `poItemReceivedStepper-<id>`,
/// `poPdfExportButton`.
class PurchaseOrderDetailScreen extends StatefulWidget {
  final PurchaseOrder order;

  const PurchaseOrderDetailScreen({super.key, required this.order});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState
    extends State<PurchaseOrderDetailScreen> {
  late PurchaseOrder _order;
  List<PurchaseOrderItem>? _items;
  bool _loadingItems = true;
  String? _itemsError;

  // Menge-Eingaben pro Item-Id (Wareneingang)
  final Map<String, int> _receivedQty = {};

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (_order.id == null) {
      setState(() {
        _items = const [];
        _loadingItems = false;
      });
      return;
    }
    setState(() {
      _loadingItems = true;
      _itemsError = null;
    });
    try {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      final items = await provider.loadPurchaseOrderItems(_order.id!);
      if (mounted) {
        setState(() {
          _items = items.where((i) => i.deletedAt == null).toList();
          _loadingItems = false;
          // Initialisiere Eingabe-Menge mit 0 pro Position
          for (final item in _items!) {
            _receivedQty.putIfAbsent(item.id, () => 0);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingItems = false;
          _itemsError = e.toString();
        });
      }
    }
  }

  // ── Wareneingang buchen ───────────────────────────────────────────────────

  Future<void> _bookGoodsReceipt() async {
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final items = _items;
    if (items == null || items.isEmpty) return;

    // Sammle alle Positionen mit qty > 0
    final toBook = <PurchaseOrderItem, int>{};
    for (final item in items) {
      final qty = _receivedQty[item.id] ?? 0;
      if (qty > 0) toBook[item] = qty;
    }

    if (toBook.isEmpty) {
      AppFeedback.info(context, l10n.purchaseOrderItemsEmpty);
      return;
    }

    // Prüfe Produkt-Verknüpfung für alle zu buchenden Positionen
    for (final item in toBook.keys) {
      if (item.productId == null) {
        AppFeedback.error(context, l10n.goodsReceiptNoProduct);
        return;
      }
    }

    try {
      final results = <PurchaseOrderItem>[];
      for (final entry in toBook.entries) {
        final updated = await provider.bookGoodsReceipt(
          item: entry.key,
          receivedQty: entry.value,
        );
        results.add(updated);
      }

      // Positionen lokal aktualisieren
      if (mounted) {
        setState(() {
          final updatedMap = {for (final r in results) r.id: r};
          _items = _items!.map((i) => updatedMap[i.id] ?? i).toList();
          // Eingaben zurücksetzen
          for (final id in toBook.keys.map((i) => i.id)) {
            _receivedQty[id] = 0;
          }
        });

        AppFeedback.success(context, l10n.goodsReceiptSuccess);

        // Reload order to get updated status
        final refreshed =
            provider.purchaseOrders.where((o) => o.id == _order.id).firstOrNull;
        if (refreshed != null) {
          setState(() => _order = refreshed);
        }
      }
    } catch (e) {
      // Rohe Exception nicht im UI rendern (Information-Disclosure) —
      // generische lokalisierte Meldung, Detail nur ins Debug-Log.
      debugPrint('bookGoodsReceipt failed: $e');
      if (mounted) AppFeedback.error(context, l10n.goodsReceiptError);
    }
  }

  // ── Barcode-Einsprung ──────────────────────────────────────────────────────

  Future<void> _scanBarcode() async {
    // Use State's own context — safe because all async gaps check `mounted`.
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    final code = await BarcodeScannerSheet.show(
      context,
      title: l10n.purchaseOrderScanBarcode,
    );
    if (code == null || !mounted) return;

    final items = _items;
    if (items == null) return;

    // Produkte aus dem Provider für Barcode-Match (EAN oder SKU)
    final products = provider.products;
    Product? matchedProduct;
    for (final p in products) {
      if ((p.ean != null && p.ean == code) ||
          (p.sku != null && p.sku == code)) {
        matchedProduct = p;
        break;
      }
    }

    if (matchedProduct == null) {
      AppFeedback.info(context, l10n.purchaseOrderScanNoMatch);
      return;
    }

    // Finde passende Position und erhöhe qty um 1 (Stepper)
    final mp = matchedProduct;
    final matchedItem =
        items.where((i) => i.productId == mp.id).firstOrNull;
    if (matchedItem != null) {
      setState(() {
        final current = _receivedQty[matchedItem.id] ?? 0;
        _receivedQty[matchedItem.id] = current + 1;
      });
      AppFeedback.info(context, l10n.purchaseOrderScanItemAdded(mp.name));
    }
  }

  // ── Status-Wechsel ─────────────────────────────────────────────────────────

  Future<void> _setStatus(PurchaseOrderStatus newStatus) async {
    final l10n = AppLocalizations.of(context);
    // Capture messenger before dialog opens (dialog-context pattern).
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    final ok = await showConfirmDialog(
      context: context,
      title: l10n.purchaseOrderStatusChangeConfirm,
      message: l10n.purchaseOrderStatusChangeBody,
      confirmLabel: l10n.actionConfirm,
      cancelLabel: l10n.actionCancel,
    );
    if (ok != true || !mounted) return;

    try {
      final updated = _order.copyWith(status: newStatus);
      await provider.updatePurchaseOrder(updated);
      if (mounted) {
        setState(() => _order = updated);
      }
    } catch (e) {
      // Rohe Exception nicht im UI rendern — generische Meldung.
      debugPrint('setStatus failed: $e');
      if (mounted) {
        AppFeedback.errorOn(
          messenger,
          l10n.purchaseOrderStatusChangeError,
          rootContext: context,
        );
      }
    }
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    final supplier = _order.supplierId != null
        ? provider.suppliers
            .where((s) => s.id == _order.supplierId)
            .firstOrNull
        : null;

    final items = _items ?? const <PurchaseOrderItem>[];

    try {
      final labels = PdfLabels(
        documentTitle: l10n.poPdfDocumentTitle,
        supplierLabel: l10n.poPdfSupplierLabel,
        vatIdLabel: l10n.poPdfVatIdLabel,
        orderDateLabel: l10n.poPdfOrderDateLabel,
        expectedDateLabel: l10n.poPdfExpectedDateLabel,
        statusLabel: l10n.poPdfStatusLabel,
        statusDraft: l10n.purchaseOrderStatusDraft,
        statusOrdered: l10n.purchaseOrderStatusOrdered,
        statusPartial: l10n.purchaseOrderStatusPartial,
        statusReceived: l10n.purchaseOrderStatusReceived,
        statusCancelled: l10n.purchaseOrderStatusCancelled,
        sectionItems: l10n.poPdfSectionItems,
        colProduct: l10n.poPdfColProduct,
        colOrdered: l10n.poPdfColOrdered,
        colReceived: l10n.poPdfColReceived,
        colUnitPrice: l10n.poPdfColUnitPrice,
        colLineTotal: l10n.poPdfColLineTotal,
        totalNetLabel: l10n.poPdfTotalNetLabel,
        noteLabel: l10n.poPdfNoteLabel,
      );

      final bytes = await PurchaseOrderPdfService.buildPdf(
        order: _order,
        items: items,
        supplier: supplier,
        products: provider.products,
        labels: labels,
      );

      if (!mounted) return;

      await PurchaseOrderPdfService.sharePdf(
        bytes: bytes,
        fileName: PurchaseOrderPdfService.fileName(_order.orderNumber),
      );
    } catch (e) {
      // Rohe Exception nicht im UI rendern — generische Meldung.
      debugPrint('exportPdf failed: $e');
      if (mounted) {
        AppFeedback.error(context, l10n.purchaseOrderPdfExportError);
      }
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    final ok = await showConfirmDialog(
      context: context,
      title: l10n.purchaseOrderDelete,
      message: l10n.purchaseOrderDeletePrompt(_order.orderNumber),
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;

    if (_order.id != null) {
      await provider.deletePurchaseOrder(_order.id!);
    }
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wsProvider =
        Provider.of<ActiveWorkspaceProvider>(context, listen: false);
    final canEdit = wsProvider.role?.canEdit ?? false;

    final isDraft = _order.status == PurchaseOrderStatus.draft;
    final isOrdered = _order.status == PurchaseOrderStatus.ordered;
    final isCancellable =
        isDraft || isOrdered || _order.status == PurchaseOrderStatus.partiallyReceived;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchaseOrderDetailTitle),
        actions: [
          // PDF export button (C6)
          IconButton(
            key: const Key('poPdfExportButton'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.purchaseOrderPdfExport,
            onPressed: _loadingItems ? null : _exportPdf,
          ),
          if (canEdit)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'to_ordered':
                    _setStatus(PurchaseOrderStatus.ordered);
                  case 'to_cancelled':
                    _setStatus(PurchaseOrderStatus.cancelled);
                  case 'delete':
                    _delete(context);
                }
              },
              itemBuilder: (_) => [
                if (isDraft)
                  PopupMenuItem(
                    value: 'to_ordered',
                    child: Text(l10n.purchaseOrderStatusToOrdered),
                  ),
                if (isCancellable)
                  PopupMenuItem(
                    value: 'to_cancelled',
                    child: Text(l10n.purchaseOrderStatusToCancelled),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    l10n.purchaseOrderDelete,
                    style: TextStyle(color: AppTheme.dangerTextOf(context)),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── no-permission banner
              if (!canEdit)
                _ViewerBanner(message: l10n.purchaseOrderViewerHint),

              // ── Bestellkopf
              _SectionHeader(label: l10n.purchaseOrderDetailSectionHead),
              const SizedBox(height: 8),
              _HeadCard(order: _order),
              const SizedBox(height: 20),

              // ── Positionen
              Row(
                children: [
                  Expanded(
                    child: _SectionHeader(
                        label: l10n.purchaseOrderDetailSectionItems),
                  ),
                  // Barcode scan button (48dp target)
                  if (canEdit)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        tooltip: l10n.purchaseOrderScanBarcode,
                        onPressed: _scanBarcode,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_loadingItems)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_itemsError != null)
                _ItemsErrorState(
                  message: l10n.purchaseOrderItemsLoadError,
                  onRetry: _loadItems,
                )
              else if (_items == null || _items!.isEmpty)
                _ItemsEmptyState()
              else
                _ItemsList(
                  items: _items!,
                  products: Provider.of<InventoryProvider>(context,
                          listen: false)
                      .products,
                  receivedQty: _receivedQty,
                  canEdit: canEdit,
                  onQtyChanged: (id, qty) =>
                      setState(() => _receivedQty[id] = qty),
                ),

              const SizedBox(height: 24),

              // ── Wareneingang buchen button
              if (canEdit &&
                  _order.status != PurchaseOrderStatus.received &&
                  _order.status != PurchaseOrderStatus.cancelled)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('goodsReceiptBookButton'),
                    onPressed: _loadingItems ? null : _bookGoodsReceipt,
                    icon: const Icon(Icons.input_outlined, size: 18),
                    label: Text(l10n.goodsReceiptBook),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header card
// ─────────────────────────────────────────────────────────────────────────────

class _HeadCard extends StatelessWidget {
  final PurchaseOrder order;

  const _HeadCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final supplier =
        provider.suppliers.where((s) => s.id == order.supplierId).firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              label: l10n.purchaseOrderLabelNumber,
              value: order.orderNumber,
            ),
            _InfoRow(
              label: l10n.purchaseOrderLabelSupplier,
              value: supplier?.name ?? order.supplierId ?? '—',
            ),
            _InfoRow(
              label: l10n.purchaseOrderLabelStatus,
              valueWidget: PurchaseOrderStatusBadge(status: order.status),
            ),
            if (order.orderDate != null)
              _InfoRow(
                label: l10n.purchaseOrderLabelOrderDate,
                value: _fmtDate(order.orderDate!),
              ),
            if (order.expectedDate != null)
              _InfoRow(
                label: l10n.purchaseOrderLabelExpectedDate,
                value: _fmtDate(order.expectedDate!),
              ),
            if (order.totalNet != null)
              _InfoRow(
                label: l10n.purchaseOrderLabelTotalNet,
                value: '${order.totalNet!.toStringAsFixed(2)} €',
              ),
            if (order.note != null && order.note!.isNotEmpty)
              _InfoRow(
                label: l10n.purchaseOrderLabelNote,
                value: order.note!,
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueWidget,
  }) : assert(
          value != null || valueWidget != null,
          'Either value or valueWidget must be provided',
        );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Items list
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsList extends StatelessWidget {
  final List<PurchaseOrderItem> items;
  final List<Product> products;
  final Map<String, int> receivedQty;
  final bool canEdit;
  final void Function(String id, int qty) onQtyChanged;

  const _ItemsList({
    required this.items,
    required this.products,
    required this.receivedQty,
    required this.canEdit,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => _PoItemCard(
              key: Key('poItemCard-${item.id}'),
              item: item,
              products: products,
              receivedQtyInput: receivedQty[item.id] ?? 0,
              canEdit: canEdit,
              onQtyChanged: (qty) => onQtyChanged(item.id, qty),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single PO item card with touch stepper
// ─────────────────────────────────────────────────────────────────────────────

class _PoItemCard extends StatelessWidget {
  final PurchaseOrderItem item;
  final List<Product> products;
  final int receivedQtyInput;
  final bool canEdit;
  final void Function(int qty) onQtyChanged;

  const _PoItemCard({
    super.key,
    required this.item,
    required this.products,
    required this.receivedQtyInput,
    required this.canEdit,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product =
        products.where((p) => p.id == item.productId).firstOrNull;
    final productName = product?.name ?? item.productId ?? '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              productName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),

            // Soll / Ist row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.quantityOrdered,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                      Text(
                        item.quantityOrdered.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.quantityReceived,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                      Text(
                        item.quantityReceived.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: item.quantityReceived >= item.quantityOrdered
                              ? AppTheme.successTextOf(context)
                              : AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.unitPrice != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.purchaseOrderItemFieldUnitPrice,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                        Text(
                          '${item.unitPrice!.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Touch stepper (Wareneingang-Eingabe) — nur wenn canEdit und nicht vollständig
            if (canEdit && item.quantityReceived < item.quantityOrdered) ...[
              const SizedBox(height: 12),
              _TouchStepper(
                key: Key('poItemReceivedStepper-${item.id}'),
                value: receivedQtyInput,
                min: 0,
                max: item.quantityOrdered - item.quantityReceived,
                onChanged: onQtyChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Touch stepper — +/- mit 48dp-Targets
// ─────────────────────────────────────────────────────────────────────────────

class _TouchStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  const _TouchStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus button — 48×48dp
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            tooltip: '−1',
          ),
        ),
        // Value display
        Container(
          constraints: const BoxConstraints(minWidth: 48),
          alignment: Alignment.center,
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
        ),
        // Plus button — 48×48dp
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            tooltip: '+1',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimaryOf(context),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ViewerBanner extends StatelessWidget {
  final String message;

  const _ViewerBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningBgOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningBorderOf(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: AppTheme.warningTextOf(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.warningTextOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsEmptyState extends StatelessWidget {
  const _ItemsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          l10n.purchaseOrderItemsEmpty,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textMutedOf(context),
          ),
        ),
      ),
    );
  }
}

class _ItemsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ItemsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.dangerTextOf(context),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l10n.actionRetry),
          ),
        ],
      ),
    );
  }
}
