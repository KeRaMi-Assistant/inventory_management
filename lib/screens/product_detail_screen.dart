import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
import '../models/product_stock.dart';
import '../models/supplier.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/status_l10n.dart';
import '../widgets/inventory_batches_sheet.dart';

/// 360°-Detail-Sicht auf eine bestehende [InventoryItem]-Row.
///
/// **Zwei Modi (additiv, rückwärtskompatibel):**
///
/// 1. `item.productId != null` → **Produkt-Aggregations-Modus**
///    - Zeigt zusätzlich Produkt-Stammdaten aus dem `products`-Katalog
///    - Zeigt aggregierten Gesamtbestand des Produkts über ALLE Bestands-Rows
///      via `product_stock`-View (aufgeschlüsselt nach Lager wenn mehrere)
///    - Bewegungshistorie umfasst Movements aller Items die dem Produkt gehören
///      (via `movement.productId`) + clientseitige Pagination (50 Einträge)
///
/// 2. `item.productId == null` → **Single-Row-Modus (bisheriges Verhalten)**
///    - Stammdaten der Bestands-Row, Bestand der Row, Movements der Row
///    - Keine Aggregation, keine Produkt-Sektion
///
/// Navigation:
/// - **Standalone** (`embedded == false`, Default): per [Navigator.push] vom
///   [InventoryScreen] — eigener [Scaffold] + [AppBar].
/// - **Embedded** (`embedded == true`, T3.3a): renderbar als Detail-Pane in
///   einem Master-Detail-Split (kein eigener [Scaffold]/[AppBar]) — Body
///   wird direkt zurückgegeben. Pattern analog `SettingsScreen(embedded: true)`.
///
/// A11y-Keys: `productDetailScrollView`, `movementHistoryList`, `movementRow-<id>`.

// ─────────────────────────────────────────────────────────────────────────────
// Pagination constant
// ─────────────────────────────────────────────────────────────────────────────

const int _kMovementPageSize = 50;

// ─────────────────────────────────────────────────────────────────────────────
// Screen (StatefulWidget for pagination state)
// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailScreen extends StatefulWidget {
  final InventoryItem item;

  /// Wenn `true`, rendert das Widget keinen eigenen [Scaffold]/[AppBar],
  /// sondern nur den Body-Inhalt — geeignet für Master-Detail-Embeds.
  ///
  /// Default `false` (rückwärtskompatibel mit allen bisherigen Aufrufern).
  /// Vorbereitung für T3.3b (Inventory-Master-Detail-Split). Siehe
  /// `plans/2026-05-22_ui-ux-responsive-overhaul.md` §T3.3a.
  final bool embedded;

  /// Hero-Tag für die Phone-Navigation-Animation (F4).
  ///
  /// Wird vom [InventoryScreen] gesetzt wenn `isPhoneViewport && !isMasterDetail`.
  /// Muss mit dem Tag auf der Quell-Card in der Item-Liste übereinstimmen:
  /// `'product-hero-${item.id}'`.
  ///
  /// `null` bedeutet keine Hero-Animation (Desktop oder embedded).
  final String? heroTag;

  const ProductDetailScreen({
    super.key,
    required this.item,
    this.embedded = false,
    this.heroTag,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  /// How many movements are currently visible.
  int _visibleMovements = _kMovementPageSize;

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
            .where((i) => i.id == widget.item.id)
            .firstOrNull ??
        widget.item;

    final supplier = liveItem.supplierId != null
        ? provider.suppliers
            .where((s) => s.id == liveItem.supplierId)
            .firstOrNull
        : null;

    // ── Produkt-Aggregations-Modus ───────────────────────────────────────────
    final productId = liveItem.productId;
    final Product? product = productId != null
        ? provider.products.where((p) => p.id == productId).firstOrNull
        : null;

    // Aggregierter Bestand aus product_stock-View.
    // Falls noch nicht geladen: leere Liste (View lädt async in loadData).
    final List<ProductStock> productStockRows = productId != null
        ? provider.productStock
            .where((s) => s.productId == productId)
            .toList()
        : [];

    // Movements: bei verknüpftem Produkt ALLE Movements mit diesem productId
    // (katalogweite Sicht), fallback auf item-basierte Movements.
    final List<InventoryMovement> allMovements = productId != null
        ? provider.movements
            .where((m) => m.productId == productId)
            .toList()
        : provider.movements
            .where((m) => m.itemId == liveItem.id)
            .toList();

    // Provider-Movements sind bereits absteigend nach Datum sortiert.
    // Clientseitige Pagination: nur die ersten _visibleMovements zeigen.
    final visibleCount =
        _visibleMovements.clamp(0, allMovements.length);
    final pagedMovements = allMovements.take(visibleCount).toList();
    final hasMore = allMovements.length > visibleCount;
    final remainingCount = allMovements.length - visibleCount;

    final scrollView = SingleChildScrollView(
      key: const Key('productDetailScrollView'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Viewer-Hinweis-Banner
          if (!canEdit)
            _ViewerHintBanner(l10n: l10n),

          // ── Produkt-Stammdaten (nur im Produkt-Aggregations-Modus) ──────
          if (product != null) ...[
            _SectionCard(
              title: l10n.productDetailSectionProduct,
              icon: Icons.category_outlined,
              child: _ProductMasterSection(
                product: product,
                money: money,
                l10n: l10n,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Stammdaten der Bestands-Row ─────────────────────────────────
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

          // ── Bestand ─────────────────────────────────────────────────────
          // Im Produkt-Modus: aggregierter Gesamtbestand über alle Lager.
          // Im Single-Row-Modus: Bestand der einzelnen Row.
          if (productId != null && productStockRows.isNotEmpty)
            _SectionCard(
              title: l10n.productDetailSectionAggregatedStock,
              icon: Icons.inventory_2_outlined,
              child: _AggregatedStockSection(
                stockRows: productStockRows,
                product: product,
                l10n: l10n,
              ),
            )
          else
            _SectionCard(
              title: l10n.productDetailSectionStock,
              icon: Icons.inventory_2_outlined,
              child: _StockSection(item: liveItem, l10n: l10n),
            ),
          const SizedBox(height: 12),

          // ── Chargen ─────────────────────────────────────────────────────
          _SectionCard(
            title: l10n.productDetailSectionBatches,
            icon: Icons.layers_outlined,
            child: _BatchesSection(
              item: liveItem,
              l10n: l10n,
            ),
          ),
          const SizedBox(height: 12),

          // ── Bewegungshistorie (paginiert) ────────────────────────────────
          _SectionCard(
            title: l10n.movementHistoryTitle,
            icon: Icons.history_outlined,
            child: _MovementHistorySection(
              movements: pagedMovements,
              hasMore: hasMore,
              remainingCount: remainingCount,
              isProductScope: productId != null,
              money: money,
              l10n: l10n,
              onLoadMore: () {
                setState(() {
                  _visibleMovements += _kMovementPageSize;
                });
              },
            ),
          ),
        ],
      ),
    );

    // Embedded-Modus: nur Body zurückgeben (kein Scaffold/AppBar).
    // Vorbereitung für Master-Detail-Split (T3.3b).
    if (widget.embedded) {
      return scrollView;
    }

    // F4: Hero-Animation für AppBar-Titel (nur im Standalone-Modus mit Tag).
    // Der Hero matched den Card-Container in inventory_screen.dart.
    // Embedded-Modus ist immer Desktop → kein Hero dort.
    final titleWidget = widget.heroTag != null
        ? Hero(
            tag: widget.heroTag!,
            // FlutterLogo-Workaround: Hero über Text braucht DefaultTextStyle-
            // Wrapper damit Material-Übergang korrekt rendert.
            flightShuttleBuilder: (_, animation, _, fromCtx, toCtx) {
              return AnimatedBuilder(
                animation: animation,
                builder: (_, _) => DefaultTextStyle(
                  style: DefaultTextStyle.of(toCtx).style,
                  child: toCtx.widget,
                ),
              );
            },
            child: Text(l10n.productDetailTitle),
          )
        : Text(l10n.productDetailTitle);

    return Scaffold(
      appBar: AppBar(
        title: titleWidget,
      ),
      body: SafeArea(child: scrollView),
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
// Produkt-Stammdaten (Epic A-full — nur wenn productId != null)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductMasterSection extends StatelessWidget {
  final Product product;
  final NumberFormat money;
  final AppLocalizations l10n;

  const _ProductMasterSection({
    required this.product,
    required this.money,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LabelValue(
          label: product.name,
          value: null,
          isHeadline: true,
        ),
        const SizedBox(height: 8),
        if (product.sku != null)
          _LabelValue(
            label: l10n.productDetailLabelSku,
            value: product.sku!,
          ),
        if (product.ean != null)
          _LabelValue(
            label: l10n.productDetailLabelEan,
            value: product.ean!,
          ),
        _LabelValue(
          label: l10n.productDetailLabelProductUnit,
          value: product.unit,
        ),
        if (product.defaultCostPrice != null)
          _LabelValue(
            label: l10n.productDetailLabelDefaultCostPrice,
            value: money.format(product.defaultCostPrice),
          ),
        if (product.defaultSalePrice != null)
          _LabelValue(
            label: l10n.productDetailLabelDefaultSalePrice,
            value: money.format(product.defaultSalePrice),
          ),
        if (product.minStock > 0)
          _LabelValue(
            label: l10n.productDetailLabelMinStockProduct,
            value: '${product.minStock}',
          ),
        if (product.taxRate != null)
          _LabelValue(
            label: l10n.productDetailLabelTaxRate,
            value: '${product.taxRate!.toStringAsFixed(1)} %',
          ),
        if (product.note != null && product.note!.isNotEmpty)
          _LabelValue(
            label: l10n.productDetailLabelNote,
            value: product.note!,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aggregierter Bestand (Produkt-Modus)
// ─────────────────────────────────────────────────────────────────────────────

class _AggregatedStockSection extends StatelessWidget {
  final List<ProductStock> stockRows;
  final Product? product;
  final AppLocalizations l10n;

  const _AggregatedStockSection({
    required this.stockRows,
    required this.product,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final totalQty =
        stockRows.fold(0, (sum, s) => sum + s.qtyInWarehouse);
    final minStock = product?.minStock ?? 0;
    final isCritical = minStock > 0 && totalQty < minStock;
    final atMin = minStock > 0 && totalQty == minStock;

    final stockColor = isCritical
        ? AppTheme.dangerTextOf(context)
        : atMin
            ? AppTheme.warningTextOf(context)
            : AppTheme.successTextOf(context);

    // KPI-Boxen-Zeile: Gesamtbestand + Mindestbestand + Status.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiBox(
                label: l10n.productDetailLabelTotalQty,
                value: '$totalQty',
                valueColor: stockColor,
                icon: Icons.inventory_2_outlined,
                iconColor: stockColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiBox(
                label: l10n.productDetailLabelMinStock,
                value: '$minStock',
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
                icon: isCritical
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                iconColor: stockColor,
              ),
            ),
          ],
        ),

        // Aufschlüsselung nach Lager (nur wenn mehrere Lager vorhanden).
        if (stockRows.length > 1) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.borderOf(context)),
          const SizedBox(height: 10),
          ...stockRows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.warehouse_outlined,
                    size: 14,
                    color: AppTheme.textMutedOf(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      row.warehouseId != null
                          ? l10n.productDetailLabelWarehouseQty(
                              row.warehouseId!)
                          : l10n.productDetailLabelNoWarehouse,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  Text(
                    '${row.qtyInWarehouse}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stammdaten (Bestands-Row)
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
// Bestand (Single-Row-Modus)
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
// Bewegungshistorie (paginiert)
// ─────────────────────────────────────────────────────────────────────────────

class _MovementHistorySection extends StatelessWidget {
  final List<InventoryMovement> movements;
  final bool hasMore;
  final int remainingCount;
  final bool isProductScope;
  final NumberFormat money;
  final AppLocalizations l10n;
  final VoidCallback onLoadMore;

  const _MovementHistorySection({
    required this.movements,
    required this.hasMore,
    required this.remainingCount,
    required this.isProductScope,
    required this.money,
    required this.l10n,
    required this.onLoadMore,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scope-Hinweis: wenn Produkt-Modus, zeige kleinen Hinweis
        if (isProductScope) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.infoBgOf(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.infoBorderOf(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppTheme.infoTextOf(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.productDetailMovementsAllProduct,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.infoTextOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Bewegungs-Liste
        ListView.separated(
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
        ),

        // Pagination-Footer
        if (hasMore) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(
                l10n.productDetailLoadMoreMovements(
                  remainingCount.clamp(1, remainingCount),
                ),
              ),
            ),
          ),
        ] else if (movements.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.productDetailAllMovementsShown,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textDisabledOf(context),
              ),
            ),
          ),
        ],
      ],
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

    final (badgeLabel, badgeBg, badgeFg) =
        _badgeStyle(context, movement.movementType);
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
