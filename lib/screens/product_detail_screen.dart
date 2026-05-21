import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/inventory_item.dart';
import '../models/supplier.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/status_l10n.dart';
import '../widgets/inventory_batches_sheet.dart';

/// 360°-Detail-Sicht auf eine bestehende [InventoryItem]-Row.
///
/// Zeigt:
/// - Stammdaten (Name, SKU, EAN, Lagerort, Status, Lieferant, EK, Ankunft, Notiz)
/// - Aktueller Bestand (Menge, Mindestbestand, kritisch ja/nein)
/// - Bewegungshistorie (getypte [InventoryMovement]s mit Buchungsart-Badge)
/// - Chargen (via [InventoryBatchesSheet])
///
/// Navigation: gepusht per [Navigator.push] vom [InventoryScreen].
/// A11y-Keys: `productDetailScrollView`, `movementHistoryList`, `movementRow-<id>`.
class ProductDetailScreen extends StatelessWidget {
  final InventoryItem item;

  const ProductDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<InventoryProvider>(context);
    final wsProvider = Provider.of<ActiveWorkspaceProvider>(context);
    final canEdit = wsProvider.role?.canEdit ?? false;

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final dateFormatter = DateFormat.yMd(localeTag);

    // Item aus Provider-Liste holen, damit live-Updates ankommen.
    final liveItem = provider.inventoryItems
            .where((i) => i.id == item.id)
            .firstOrNull ??
        item;

    final supplier = liveItem.supplierId != null
        ? provider.suppliers
            .where((s) => s.id == liveItem.supplierId)
            .firstOrNull
        : null;

    final itemMovements = provider.movements
        .where((m) => m.itemId == liveItem.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productDetailTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('productDetailScrollView'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Viewer-Hinweis-Banner
              if (!canEdit)
                _ViewerHintBanner(l10n: l10n),

              // ── Stammdaten ──────────────────────────────────────────────
              _SectionCard(
                title: l10n.productDetailSectionStammdaten,
                icon: Icons.info_outline,
                child: _StammdatenSection(
                  item: liveItem,
                  supplier: supplier,
                  money: money,
                  dateFormatter: dateFormatter,
                  l10n: l10n,
                ),
              ),
              const SizedBox(height: 12),

              // ── Bestand ─────────────────────────────────────────────────
              _SectionCard(
                title: l10n.productDetailSectionStock,
                icon: Icons.inventory_2_outlined,
                child: _StockSection(item: liveItem, l10n: l10n),
              ),
              const SizedBox(height: 12),

              // ── Chargen ─────────────────────────────────────────────────
              _SectionCard(
                title: l10n.productDetailSectionBatches,
                icon: Icons.layers_outlined,
                child: _BatchesSection(
                  item: liveItem,
                  l10n: l10n,
                ),
              ),
              const SizedBox(height: 12),

              // ── Bewegungshistorie ────────────────────────────────────────
              _SectionCard(
                title: l10n.movementHistoryTitle,
                icon: Icons.history_outlined,
                child: _MovementHistorySection(
                  movements: itemMovements,
                  money: money,
                  l10n: l10n,
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
// Section wrapper card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.accentTextOf(context)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stammdaten
// ─────────────────────────────────────────────────────────────────────────────

class _StammdatenSection extends StatelessWidget {
  final InventoryItem item;
  final Supplier? supplier;
  final NumberFormat money;
  final DateFormat dateFormatter;
  final AppLocalizations l10n;

  const _StammdatenSection({
    required this.item,
    required this.supplier,
    required this.money,
    required this.dateFormatter,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LabelValue(
          label: item.name,
          value: null,
          isHeadline: true,
        ),
        const SizedBox(height: 8),
        if (item.sku != null)
          _LabelValue(label: l10n.productDetailLabelSku, value: item.sku!),
        if (item.ean != null)
          _LabelValue(label: l10n.productDetailLabelEan, value: item.ean!),
        _LabelValue(
          label: l10n.productDetailLabelLocation,
          value: item.location ?? l10n.productDetailNoLocation,
        ),
        _LabelValue(
          label: l10n.productDetailLabelStatus,
          value: localizeInventoryStatus(context, item.status),
        ),
        _LabelValue(
          label: l10n.productDetailLabelSupplier,
          value: supplier?.name ?? l10n.productDetailNoSupplier,
        ),
        if (item.costPrice != null)
          _LabelValue(
            label: l10n.productDetailLabelCostPrice,
            value: money.format(item.costPrice),
          ),
        if (item.arrivalDate != null)
          _LabelValue(
            label: l10n.productDetailLabelArrivalDate,
            value: dateFormatter.format(item.arrivalDate!),
          ),
        if (item.note != null && item.note!.isNotEmpty)
          _LabelValue(
            label: l10n.productDetailLabelNote,
            value: item.note!,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bestand
// ─────────────────────────────────────────────────────────────────────────────

class _StockSection extends StatelessWidget {
  final InventoryItem item;
  final AppLocalizations l10n;

  const _StockSection({required this.item, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final isCritical = item.isCritical;
    final stockColor = isCritical
        ? AppTheme.dangerTextOf(context)
        : item.quantity == item.minStock
            ? AppTheme.warningTextOf(context)
            : AppTheme.successTextOf(context);

    return Row(
      children: [
        Expanded(
          child: _KpiBox(
            label: l10n.productDetailLabelQuantity,
            value: '${item.quantity}',
            valueColor: stockColor,
            icon: Icons.inventory_2_outlined,
            iconColor: stockColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiBox(
            label: l10n.productDetailLabelMinStock,
            value: '${item.minStock}',
            valueColor: AppTheme.textPrimaryOf(context),
            icon: Icons.warning_amber_outlined,
            iconColor: AppTheme.textMutedOf(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiBox(
            label: l10n.productDetailLabelStatus,
            value: isCritical
                ? l10n.productDetailLabelCritical
                : l10n.productDetailLabelOk,
            valueColor: stockColor,
            icon: isCritical ? Icons.error_outline : Icons.check_circle_outline,
            iconColor: stockColor,
          ),
        ),
      ],
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;

  const _KpiBox({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMutedOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chargen-Sektion
// ─────────────────────────────────────────────────────────────────────────────

class _BatchesSection extends StatelessWidget {
  final InventoryItem item;
  final AppLocalizations l10n;

  const _BatchesSection({required this.item, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => InventoryBatchesSheet.show(context, item),
        icon: const Icon(Icons.layers_outlined, size: 18),
        label: Text(l10n.productDetailViewBatches),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bewegungshistorie
// ─────────────────────────────────────────────────────────────────────────────

class _MovementHistorySection extends StatelessWidget {
  final List<InventoryMovement> movements;
  final NumberFormat money;
  final AppLocalizations l10n;

  const _MovementHistorySection({
    required this.movements,
    required this.money,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return Column(
        children: [
          Icon(
            Icons.history_outlined,
            size: 40,
            color: AppTheme.textDisabledOf(context),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.productDetailEmpty,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.productDetailEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textDisabledOf(context),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      key: const Key('movementHistoryList'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: movements.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: AppTheme.borderOf(context),
      ),
      itemBuilder: (context, i) {
        final m = movements[i];
        return _MovementRow(
          key: Key('movementRow-${m.id}'),
          movement: m,
          money: money,
          l10n: l10n,
        );
      },
    );
  }
}

class _MovementRow extends StatelessWidget {
  final InventoryMovement movement;
  final NumberFormat money;
  final AppLocalizations l10n;

  const _MovementRow({
    super.key,
    required this.movement,
    required this.money,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter =
        DateFormat.yMd(Localizations.localeOf(context).toLanguageTag());
    final isPositive = movement.quantityChange > 0;

    final (badgeLabel, badgeBg, badgeFg) = _badgeStyle(context, movement.movementType);
    final qtyColor = isPositive
        ? AppTheme.successTextOf(context)
        : AppTheme.dangerTextOf(context);
    final qtySign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeFg.withAlpha(60)),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeFg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.reason.isNotEmpty ? movement.reason : badgeLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormatter.format(movement.date.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
                if (movement.unitCost != null)
                  Text(
                    money.format(movement.unitCost),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Menge
          Text(
            '$qtySign${movement.quantityChange}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: qtyColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Liefert (label, bgColor, fgColor) für den Buchungsart-Badge.
  (String, Color, Color) _badgeStyle(
      BuildContext context, InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.goodsIn:
        return (
          l10n.movementTypeGoodsIn,
          AppTheme.successBgOf(context),
          AppTheme.successTextOf(context),
        );
      case InventoryMovementType.goodsOut:
        return (
          l10n.movementTypeGoodsOut,
          AppTheme.warningBgOf(context),
          AppTheme.warningTextOf(context),
        );
      case InventoryMovementType.correction:
        return (
          l10n.movementTypeCorrection,
          AppTheme.infoBgOf(context),
          AppTheme.infoTextOf(context),
        );
      case InventoryMovementType.stocktake:
        return (
          l10n.movementTypeStocktake,
          AppTheme.bgSubtleOf(context),
          AppTheme.textSecondaryOf(context),
        );
      case InventoryMovementType.transfer:
        return (
          l10n.movementTypeTransfer,
          AppTheme.bgSubtleOf(context),
          AppTheme.textSecondaryOf(context),
        );
      case InventoryMovementType.sale:
        return (
          l10n.movementTypeSale,
          AppTheme.dangerBgOf(context),
          AppTheme.dangerTextOf(context),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viewer-Hinweis
// ─────────────────────────────────────────────────────────────────────────────

class _ViewerHintBanner extends StatelessWidget {
  final AppLocalizations l10n;
  const _ViewerHintBanner({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningBgOf(context),
        border: Border.all(color: AppTheme.warningBorderOf(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline,
              size: 16, color: AppTheme.warningTextOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.productDetailViewerHint,
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

// ─────────────────────────────────────────────────────────────────────────────
// Label-Value Zeile
// ─────────────────────────────────────────────────────────────────────────────

class _LabelValue extends StatelessWidget {
  final String label;
  final String? value;
  final bool isHeadline;

  const _LabelValue({
    required this.label,
    required this.value,
    this.isHeadline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHeadline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
