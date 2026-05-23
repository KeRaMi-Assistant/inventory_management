import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import 'purchase_order_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PurchaseOrdersScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Bestellliste (Epic C, Task C5).
///
/// Sub-Route des Warenwirtschaft-Hubs — kein eigener [MainTab].
/// Navigiert per [Navigator.push] zu [PurchaseOrderDetailScreen].
///
/// **Zwei Modi (additiv, rückwärtskompatibel):**
/// - `embedded == false` (Default): eigener [Scaffold] + [AppBar] für den
///   Vollbild-Push-Pfad (Phone-Hub-Verhalten).
/// - `embedded == true` (T3.4): kein [AppBar] — nur ein [Scaffold] mit FAB
///   und Body, damit der Screen in einer Master-Detail-Detail-Spalte
///   gerendert werden kann (Desktop-Warehouse-Hub).
///
/// A11y-Keys: `poNewFab`, `poCard-<id>`.
class PurchaseOrdersScreen extends StatelessWidget {
  /// Wenn `true`, wird kein [AppBar] gerendert — geeignet für
  /// Master-Detail-Embeds (T3.4 Warehouse-Hub-Desktop). Default `false`
  /// (rückwärtskompatibel mit allen bisherigen Aufrufern).
  final bool embedded;

  const PurchaseOrdersScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer2<InventoryProvider, ActiveWorkspaceProvider>(
      builder: (context, provider, wsProvider, _) {
        final canEdit = wsProvider.role?.canEdit ?? false;
        final orders = provider.purchaseOrders
            .where((o) => o.deletedAt == null)
            .toList();

        return Scaffold(
          appBar: embedded
              ? null
              : AppBar(
                  title: Text(l10n.purchaseOrdersTitle),
                ),
          floatingActionButton: canEdit
              ? FloatingActionButton.extended(
                  key: const Key('poNewFab'),
                  onPressed: () => _openNewOrderDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.purchaseOrderNew),
                )
              : null,
          body: SafeArea(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.lastError != null
                    ? _ErrorState(
                        message: l10n.purchaseOrdersLoadError,
                        onRetry: provider.loadData,
                      )
                    : orders.isEmpty
                        ? _EmptyState(canEdit: canEdit)
                        : _OrderList(
                            orders: orders,
                            suppliers: provider.suppliers,
                          ),
          ),
        );
      },
    );
  }

  void _openNewOrderDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _AddEditOrderDialog(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order list
// ─────────────────────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  final List<PurchaseOrder> orders;
  final List<Supplier> suppliers;

  const _OrderList({required this.orders, required this.suppliers});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _OrderCard(
        order: orders[i],
        suppliers: suppliers,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order card
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final PurchaseOrder order;
  final List<Supplier> suppliers;

  const _OrderCard({required this.order, required this.suppliers});

  @override
  Widget build(BuildContext context) {
    final supplier =
        suppliers.where((s) => s.id == order.supplierId).firstOrNull;

    return Card(
      key: Key('poCard-${order.id}'),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PurchaseOrderDetailScreen(order: order),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: order.status),
                ],
              ),
              if (supplier != null) ...[
                const SizedBox(height: 6),
                Text(
                  supplier.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  if (order.orderDate != null) ...[
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppTheme.textMutedOf(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(order.orderDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (order.totalNet != null)
                    Text(
                      '${order.totalNet!.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge (shared with detail screen via export below)
// ─────────────────────────────────────────────────────────────────────────────

/// Farbiger Status-Badge für eine Bestellung.
class PurchaseOrderStatusBadge extends StatelessWidget {
  final PurchaseOrderStatus status;

  const PurchaseOrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, bg, fg) = _resolve(context, status, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  static (String, Color, Color) _resolve(
    BuildContext context,
    PurchaseOrderStatus s,
    AppLocalizations l10n,
  ) {
    switch (s) {
      case PurchaseOrderStatus.draft:
        return (
          l10n.purchaseOrderStatusDraft,
          AppTheme.bgSubtleOf(context),
          AppTheme.textMutedOf(context),
        );
      case PurchaseOrderStatus.ordered:
        return (
          l10n.purchaseOrderStatusOrdered,
          AppTheme.infoBgOf(context),
          AppTheme.infoTextOf(context),
        );
      case PurchaseOrderStatus.partiallyReceived:
        return (
          l10n.purchaseOrderStatusPartial,
          AppTheme.warningBgOf(context),
          AppTheme.warningTextOf(context),
        );
      case PurchaseOrderStatus.received:
        return (
          l10n.purchaseOrderStatusReceived,
          AppTheme.successBgOf(context),
          AppTheme.successTextOf(context),
        );
      case PurchaseOrderStatus.cancelled:
        return (
          l10n.purchaseOrderStatusCancelled,
          AppTheme.dangerBgOf(context),
          AppTheme.dangerTextOf(context),
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final PurchaseOrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) =>
      PurchaseOrderStatusBadge(status: status);
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool canEdit;

  const _EmptyState({required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.purchaseOrdersEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              Text(
                l10n.purchaseOrdersEmptyHint,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMutedOf(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.dangerTextOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddEditOrderDialog
// ─────────────────────────────────────────────────────────────────────────────

/// Dialog zum Anlegen einer neuen Bestellung.
///
/// Mobile-First: [SingleChildScrollView] + [SafeArea] +
/// [MediaQuery.viewInsetsOf] — kein Feld wird von der Tastatur verdeckt.
class _AddEditOrderDialog extends StatefulWidget {
  const _AddEditOrderDialog();

  @override
  State<_AddEditOrderDialog> createState() => _AddEditOrderDialogState();
}

class _AddEditOrderDialogState extends State<_AddEditOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _supplierId;
  DateTime? _orderDate;
  DateTime? _expectedDate;
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  final List<_ItemDraft> _items = [];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_supplierId == null) {
      setState(() => _error = l10n.purchaseOrderNoSupplierError);
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = l10n.purchaseOrderNoItemsError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      final wsProvider =
          Provider.of<ActiveWorkspaceProvider>(context, listen: false);
      // workspaceId + userId werden vom Repository injiziert (wie in categories_screen).
      // order_number wird ebenfalls vom Repository per Retry-Logik vergeben.
      final wsId = wsProvider.active?.id ?? '';
      final now = DateTime.now();

      // Platzhalter-Werte — repository überschreibt workspace_id/user_id/order_number.
      final newOrder = PurchaseOrder(
        workspaceId: '',
        userId: '',
        supplierId: _supplierId,
        orderNumber: '',
        orderDate: _orderDate,
        expectedDate: _expectedDate,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      final saved = await provider.addPurchaseOrder(newOrder);

      const uuid = Uuid();
      for (final draft in _items) {
        final item = PurchaseOrderItem(
          id: uuid.v4(),
          workspaceId: wsId,
          purchaseOrderId: saved.id,
          productId: draft.productId,
          quantityOrdered: draft.qty > 0 ? draft.qty : 1,
          unitPrice: draft.unitPrice,
          createdAt: now,
          updatedAt: now,
        );
        await provider.addPurchaseOrderItem(item);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDate({required bool isOrder}) async {
    final initial = (isOrder ? _orderDate : _expectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isOrder) {
          _orderDate = picked;
        } else {
          _expectedDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final suppliers = provider.activeSuppliers;
    final products =
        provider.products.where((p) => p.isActive && p.deletedAt == null).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.purchaseOrderNew,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Supplier
                  DropdownButtonFormField<String>(
                    initialValue: _supplierId,
                    decoration: InputDecoration(
                      labelText: l10n.purchaseOrderFieldSupplier,
                      hintText: l10n.purchaseOrderFieldSupplierHint,
                    ),
                    items: suppliers
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _supplierId = v),
                    validator: (v) =>
                        v == null ? l10n.purchaseOrderNoSupplierError : null,
                  ),
                  const SizedBox(height: 8),

                  // Order date row
                  _DatePickerRow(
                    label: l10n.purchaseOrderFieldOrderDate,
                    date: _orderDate,
                    onTap: () => _pickDate(isOrder: true),
                    optional: l10n.commonOptional,
                  ),
                  // Expected date row
                  _DatePickerRow(
                    label: l10n.purchaseOrderFieldExpectedDate,
                    date: _expectedDate,
                    onTap: () => _pickDate(isOrder: false),
                    optional: l10n.commonOptional,
                  ),

                  TextFormField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.purchaseOrderFieldNote,
                      hintText: l10n.purchaseOrderFieldNoteHint,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Items header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.purchaseOrderSectionItems,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: products.isEmpty
                            ? null
                            : () => setState(
                                  () => _items.add(_ItemDraft()),
                                ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l10n.purchaseOrderItemAdd),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.purchaseOrderItemsEmpty,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ),
                  // Item draft list
                  ..._items.asMap().entries.map(
                        (e) => _ItemDraftTile(
                          key: ValueKey(e.key),
                          draft: e.value,
                          products: products,
                          onDelete: () =>
                              setState(() => _items.removeAt(e.key)),
                        ),
                      ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.dangerTextOf(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        child: Text(l10n.actionCancel),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text(l10n.actionSave),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date picker row helper
// ─────────────────────────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String optional;

  const _DatePickerRow({
    required this.label,
    required this.date,
    required this.onTap,
    required this.optional,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryOf(context),
        ),
      ),
      trailing: TextButton(
        onPressed: onTap,
        child: Text(
          date != null
              ? '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}'
              : optional,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item draft (mutable state for a single PO position during dialog)
// ─────────────────────────────────────────────────────────────────────────────

class _ItemDraft {
  String? productId;
  int qty = 1;
  double? unitPrice;

  _ItemDraft();
}

class _ItemDraftTile extends StatefulWidget {
  final _ItemDraft draft;
  final List<Product> products;
  final VoidCallback onDelete;

  const _ItemDraftTile({
    super.key,
    required this.draft,
    required this.products,
    required this.onDelete,
  });

  @override
  State<_ItemDraftTile> createState() => _ItemDraftTileState();
}

class _ItemDraftTileState extends State<_ItemDraftTile> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl =
        TextEditingController(text: widget.draft.qty.toString());
    _priceCtrl = TextEditingController(
        text: widget.draft.unitPrice?.toStringAsFixed(2) ?? '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.draft.productId,
                    decoration: InputDecoration(
                      labelText: l10n.purchaseOrderItemFieldProduct,
                      hintText: l10n.purchaseOrderItemFieldProductHint,
                      isDense: true,
                    ),
                    items: widget.products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => widget.draft.productId = v),
                  ),
                ),
                // 48dp touch target for delete
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppTheme.dangerTextOf(context),
                      size: 20,
                    ),
                    tooltip: l10n.purchaseOrderItemDelete,
                    onPressed: widget.onDelete,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.purchaseOrderItemFieldQtyOrdered,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        widget.draft.qty = parsed;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.purchaseOrderItemFieldUnitPrice,
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (v) =>
                        widget.draft.unitPrice = double.tryParse(v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
