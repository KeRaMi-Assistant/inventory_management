import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/statistics_filter_provider.dart';
import '../../../services/statistics_service.dart';
import '../sortable_table.dart';
import '../stat_panel.dart';

class InventorySuppliersTab extends StatelessWidget {
  final StatisticsService stats;
  const InventorySuppliersTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final h = stats.inventoryHealth;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Lager-Gesundheit ───────────────────────────────────────────────
        StatPanel(
          title: l10n.statsHealthHeading,
          icon: Icons.health_and_safety_outlined,
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth < 480
                  ? 2
                  : c.maxWidth < 800
                      ? 3
                      : 4;
              const gap = 12.0;
              final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
              final cards = <Widget>[
                _HealthCard(
                  label: l10n.statsStockValueEk,
                  value: money.format(h.stockValueEk),
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF2563EB),
                ),
                _HealthCard(
                  label: l10n.statsLowStock,
                  value: '${h.lowStock}',
                  icon: Icons.warning_amber_outlined,
                  color: h.lowStock > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFF6B7280),
                  hint: '< ${stats.lowStockThreshold}',
                ),
                _HealthCard(
                  label: l10n.statsExpiringSoon,
                  value: '${h.expiringSoon}',
                  icon: Icons.schedule_outlined,
                  color: h.expiringSoon > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFF6B7280),
                  hint: l10n.statsExpiringSoonHint,
                ),
                _HealthCard(
                  label: l10n.statsExpired,
                  value: '${h.expired}',
                  icon: Icons.error_outline,
                  color: h.expired > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF6B7280),
                  pulsing: h.expired > 0,
                ),
                _HealthCard(
                  label: l10n.statsDeadStock,
                  value: '${h.deadStock}',
                  icon: Icons.do_not_disturb_alt,
                  color: h.deadStock > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF6B7280),
                  hint: l10n.statsDeadStockHint,
                ),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: cards
                    .map((w) => SizedBox(width: cardW, child: w))
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Bestandsbewertung ──────────────────────────────────────────────
        _StockValuationPanel(stats: stats, money: money),
        const SizedBox(height: 16),

        // ── Lagerumschlag ──────────────────────────────────────────────────
        _InventoryTurnoverPanel(stats: stats),
        const SizedBox(height: 16),

        // ── ABC-Analyse ────────────────────────────────────────────────────
        _AbcAnalysisPanel(stats: stats, money: money),
        const SizedBox(height: 16),

        // ── Lieferanten-Performance ────────────────────────────────────────
        StatPanel(
          title: l10n.statsSupplierPerformance,
          icon: Icons.local_shipping_outlined,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SortableTable<SupplierStat>(
            rows: stats.supplierStats,
            defaultSortIndex: 3,
            defaultAscending: false,
            onTap: (s) {
              context.read<StatisticsFilterProvider>().setSupplier(s.id);
            },
            columns: [
              SortableColumn(
                label: l10n.inventoryColSupplier,
                builder: (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.active
                            ? const Color(0xFF059669)
                            : const Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(s.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                valueOf: (s) => s.name.toLowerCase(),
              ),
              SortableColumn(
                label: l10n.statsItems,
                numeric: true,
                builder: (s) => Text('${s.itemCount}'),
                valueOf: (s) => s.itemCount,
              ),
              SortableColumn(
                label: l10n.statsStockValueShort,
                numeric: true,
                builder: (s) => Text(money.format(s.stockValue)),
                valueOf: (s) => s.stockValue,
              ),
              SortableColumn(
                label: l10n.statsAvgEk,
                numeric: true,
                builder: (s) => Text(money.format(s.avgEk)),
                valueOf: (s) => s.avgEk,
              ),
              SortableColumn(
                label: l10n.statsLabelProfit,
                numeric: true,
                builder: (s) => Text(
                  money.format(s.profit),
                  style: TextStyle(
                    color: s.profit >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                valueOf: (s) => s.profit,
              ),
              SortableColumn(
                label: l10n.statsLabelMargin,
                numeric: true,
                builder: (s) => Text('${s.marginPct.toStringAsFixed(1)}%'),
                valueOf: (s) => s.marginPct,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bestandsbewertung ──────────────────────────────────────────────────────

class _StockValuationPanel extends StatelessWidget {
  final StatisticsService stats;
  final NumberFormat money;
  const _StockValuationPanel({required this.stats, required this.money});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = stats.reportStockValuation;

    if (report.items.isEmpty) {
      return StatPanel(
        title: l10n.reportStockValuation,
        icon: Icons.account_balance_wallet_outlined,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              l10n.reportStockValuationEmpty,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textMutedOf(context)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return StatPanel(
      title: l10n.reportStockValuation,
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI-Zeile: Gesamtwert + Gesamtmenge
          LayoutBuilder(builder: (context, c) {
            final isWide = c.maxWidth >= 480;
            final totalValueCard = _ReportKpiCard(
              label: l10n.reportStockValuationTotal,
              value: money.format(report.totalValue),
              color: AppTheme.accentTextOf(context),
              icon: Icons.euro_outlined,
            );
            final totalUnitsCard = _ReportKpiCard(
              label: l10n.reportStockValuationUnits,
              value: '${report.totalUnits}',
              color: const Color(0xFF059669),
              icon: Icons.inventory_outlined,
            );
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: totalValueCard),
                  const SizedBox(width: 12),
                  Expanded(child: totalUnitsCard),
                ],
              );
            }
            return Column(
              children: [
                totalValueCard,
                const SizedBox(height: 8),
                totalUnitsCard,
              ],
            );
          }),
          const SizedBox(height: 16),
          // Artikel-Liste (Top 10)
          LayoutBuilder(builder: (context, c) {
            final isWide = c.maxWidth >= 800;
            final top = report.items.take(10).toList();
            if (isWide) {
              // Tabellen-Ansicht auf Tablet/Desktop
              return Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: AppTheme.borderOf(context))),
                    ),
                    children: [
                      _tableHeader(context, l10n.reportStockValuationItemName),
                      _tableHeader(context, l10n.reportStockValuationQuantity,
                          align: TextAlign.right),
                      _tableHeader(context, l10n.reportStockValuationCostPrice,
                          align: TextAlign.right),
                      _tableHeader(context, l10n.reportStockValuationValue,
                          align: TextAlign.right),
                    ],
                  ),
                  for (final item in top)
                    TableRow(
                      children: [
                        _tableCell(context, item.name,
                            sub: item.sku),
                        _tableCell(context, '${item.quantity}',
                            align: TextAlign.right),
                        _tableCell(context, money.format(item.costPrice),
                            align: TextAlign.right),
                        _tableCell(context, money.format(item.totalValue),
                            align: TextAlign.right,
                            bold: true),
                      ],
                    ),
                ],
              );
            }
            // Card-Ansicht auf Phone
            return Column(
              children: top.map((item) {
                return _ItemValuationCard(item: item, money: money);
              }).toList(),
            );
          }),
          if (report.items.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${report.items.length - 10} weitere',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textMutedOf(context)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(BuildContext context, String text,
      {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMutedOf(context),
        ),
      ),
    );
  }

  Widget _tableCell(BuildContext context, String text,
      {String? sub,
      TextAlign align = TextAlign.left,
      bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: AppTheme.textPrimaryOf(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (sub != null)
            Text(
              sub,
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedOf(context)),
            ),
        ],
      ),
    );
  }
}

class _ItemValuationCard extends StatelessWidget {
  final ItemValuation item;
  final NumberFormat money;
  const _ItemValuationCard({required this.item, required this.money});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.sku != null)
                  Text(
                    item.sku!,
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textMutedOf(context)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money.format(item.totalValue),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              Text(
                '${item.quantity} × ${money.format(item.costPrice)}',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textMutedOf(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lagerumschlag ───────────────────────────────────────────────────────────

class _InventoryTurnoverPanel extends StatelessWidget {
  final StatisticsService stats;
  const _InventoryTurnoverPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = stats.reportInventoryTurnover;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final numFmt = NumberFormat.decimalPattern(localeTag);

    return StatPanel(
      title: l10n.reportInventoryTurnover,
      icon: Icons.loop_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reportInventoryTurnoverSubtitle,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textMutedOf(context)),
          ),
          const SizedBox(height: 16),
          if (report.movementCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.reportInventoryTurnoverNoData,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textMutedOf(context)),
              ),
            )
          else
            LayoutBuilder(builder: (context, c) {
              final isWide = c.maxWidth >= 480;
              final rateCard = _ReportKpiCard(
                label: l10n.reportInventoryTurnoverRate,
                value: report.turnoverRate.toStringAsFixed(2),
                color: AppTheme.accentTextOf(context),
                icon: Icons.swap_horiz_outlined,
                hint: l10n.reportInventoryTurnoverHint,
              );
              final outflowCard = _ReportKpiCard(
                label: l10n.reportInventoryTurnoverOutflow,
                value: numFmt.format(report.totalOutflowUnits),
                color: const Color(0xFFDC2626),
                icon: Icons.arrow_downward_outlined,
              );
              final avgStockCard = _ReportKpiCard(
                label: l10n.reportInventoryTurnoverAvgStock,
                value: report.avgStockUnits.toStringAsFixed(1),
                color: const Color(0xFF059669),
                icon: Icons.inventory_2_outlined,
              );
              final movementsCard = _ReportKpiCard(
                label: l10n.reportInventoryTurnoverMovements,
                value: '${report.movementCount}',
                color: const Color(0xFF6B7280),
                icon: Icons.receipt_long_outlined,
              );
              if (isWide) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                        width: (c.maxWidth - 12) / 2 < 180
                            ? c.maxWidth
                            : (c.maxWidth - 36) / 2,
                        child: rateCard),
                    SizedBox(
                        width: (c.maxWidth - 12) / 2 < 180
                            ? c.maxWidth
                            : (c.maxWidth - 36) / 2,
                        child: outflowCard),
                    SizedBox(
                        width: (c.maxWidth - 12) / 2 < 180
                            ? c.maxWidth
                            : (c.maxWidth - 36) / 2,
                        child: avgStockCard),
                    SizedBox(
                        width: (c.maxWidth - 12) / 2 < 180
                            ? c.maxWidth
                            : (c.maxWidth - 36) / 2,
                        child: movementsCard),
                  ],
                );
              }
              return Column(
                children: [
                  rateCard,
                  const SizedBox(height: 8),
                  outflowCard,
                  const SizedBox(height: 8),
                  avgStockCard,
                  const SizedBox(height: 8),
                  movementsCard,
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ── ABC-Analyse ─────────────────────────────────────────────────────────────

class _AbcAnalysisPanel extends StatelessWidget {
  final StatisticsService stats;
  final NumberFormat money;
  const _AbcAnalysisPanel({required this.stats, required this.money});

  static const _colorA = Color(0xFF2563EB);
  static const _colorB = Color(0xFFD97706);
  static const _colorC = Color(0xFF6B7280);

  Color _classColor(AbcClass cls) {
    switch (cls) {
      case AbcClass.a:
        return _colorA;
      case AbcClass.b:
        return _colorB;
      case AbcClass.c:
        return _colorC;
    }
  }

  String _classLabel(AppLocalizations l10n, AbcClass cls) {
    switch (cls) {
      case AbcClass.a:
        return l10n.reportAbcClassA;
      case AbcClass.b:
        return l10n.reportAbcClassB;
      case AbcClass.c:
        return l10n.reportAbcClassC;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = stats.reportAbcAnalysis;

    if (report.totalCount == 0) {
      return StatPanel(
        title: l10n.reportAbcAnalysis,
        icon: Icons.bar_chart_outlined,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              l10n.reportAbcEmpty,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textMutedOf(context)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return StatPanel(
      title: l10n.reportAbcAnalysis,
      icon: Icons.bar_chart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reportAbcAnalysisSubtitle,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textMutedOf(context)),
          ),
          const SizedBox(height: 16),

          // Donut-Chart + Klassensummary
          LayoutBuilder(builder: (context, c) {
            final isWide = c.maxWidth >= 480;
            // Donut: Wert pro Klasse
            final donutData = <String, double>{};
            if (report.valueA > 0) donutData['A'] = report.valueA;
            if (report.valueB > 0) donutData['B'] = report.valueB;
            if (report.valueC > 0) donutData['C'] = report.valueC;
            final total = report.totalValue;

            final pie = SizedBox(
              height: 180,
              child: total > 0
                  ? _AbcDonut(
                      valueA: report.valueA,
                      valueB: report.valueB,
                      valueC: report.valueC,
                      total: total,
                      money: money,
                    )
                  : Center(
                      child: Text(l10n.reportAbcEmpty,
                          style: TextStyle(
                              color: AppTheme.textMutedOf(context))),
                    ),
            );

            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AbcClassRow(
                  label: 'A',
                  count: report.countA,
                  value: report.valueA,
                  total: total,
                  color: _colorA,
                  money: money,
                  l10n: l10n,
                ),
                const SizedBox(height: 8),
                _AbcClassRow(
                  label: 'B',
                  count: report.countB,
                  value: report.valueB,
                  total: total,
                  color: _colorB,
                  money: money,
                  l10n: l10n,
                ),
                const SizedBox(height: 8),
                _AbcClassRow(
                  label: 'C',
                  count: report.countC,
                  value: report.valueC,
                  total: total,
                  color: _colorC,
                  money: money,
                  l10n: l10n,
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  pie,
                  const SizedBox(width: 16),
                  Expanded(child: summary),
                ],
              );
            }
            return Column(
              children: [pie, const SizedBox(height: 12), summary],
            );
          }),

          const SizedBox(height: 16),

          // Artikel-Tabelle / Cards
          LayoutBuilder(builder: (context, c) {
            final isWide = c.maxWidth >= 800;
            final top = report.items.take(15).toList();

            if (isWide) {
              return Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FixedColumnWidth(56),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: AppTheme.borderOf(context))),
                    ),
                    children: [
                      _abcTh(context, l10n.reportAbcItemName),
                      _abcTh(context, l10n.reportAbcItemValue,
                          align: TextAlign.right),
                      _abcTh(context, l10n.reportAbcItemShare,
                          align: TextAlign.right),
                      _abcTh(context, l10n.reportAbcItemClass,
                          align: TextAlign.right),
                      const SizedBox.shrink(),
                    ],
                  ),
                  for (final item in top)
                    TableRow(children: [
                      _abcTd(context, item.name, sub: item.sku),
                      _abcTd(context, money.format(item.stockValue),
                          align: TextAlign.right),
                      _abcTd(
                          context,
                          '${item.cumulativeSharePct.toStringAsFixed(1)}%',
                          align: TextAlign.right),
                      _abcTd(
                          context,
                          item.abcClass.name.toUpperCase(),
                          align: TextAlign.right,
                          color: _classColor(item.abcClass)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          width: 6,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _classColor(item.abcClass),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ]),
                ],
              );
            }

            // Card-Ansicht auf Phone
            return Column(
              children: top.map((item) {
                return _AbcItemCard(
                  item: item,
                  money: money,
                  color: _classColor(item.abcClass),
                  classLabel: _classLabel(l10n, item.abcClass),
                );
              }).toList(),
            );
          }),

          if (report.items.length > 15)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${report.items.length - 15} weitere',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textMutedOf(context)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _abcTh(BuildContext context, String text,
      {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMutedOf(context),
        ),
      ),
    );
  }

  Widget _abcTd(BuildContext context, String text,
      {String? sub,
      TextAlign align = TextAlign.left,
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  color != null ? FontWeight.w700 : FontWeight.w400,
              color: color ?? AppTheme.textPrimaryOf(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (sub != null)
            Text(
              sub,
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedOf(context)),
            ),
        ],
      ),
    );
  }
}

class _AbcDonut extends StatefulWidget {
  final double valueA;
  final double valueB;
  final double valueC;
  final double total;
  final NumberFormat money;
  const _AbcDonut({
    required this.valueA,
    required this.valueB,
    required this.valueC,
    required this.total,
    required this.money,
  });

  @override
  State<_AbcDonut> createState() => _AbcDonutState();
}

class _AbcDonutState extends State<_AbcDonut> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = <PieChartSectionData>[
      if (widget.valueA > 0)
        PieChartSectionData(
          value: widget.valueA,
          color: const Color(0xFF2563EB),
          radius: _hovered == 0 ? 60 : 52,
          title: widget.total > 0
              ? '${((widget.valueA / widget.total) * 100).toStringAsFixed(0)}%'
              : '',
          titleStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      if (widget.valueB > 0)
        PieChartSectionData(
          value: widget.valueB,
          color: const Color(0xFFD97706),
          radius: _hovered == 1 ? 60 : 52,
          title: widget.total > 0
              ? '${((widget.valueB / widget.total) * 100).toStringAsFixed(0)}%'
              : '',
          titleStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      if (widget.valueC > 0)
        PieChartSectionData(
          value: widget.valueC,
          color: const Color(0xFF6B7280),
          radius: _hovered == 2 ? 60 : 52,
          title: widget.total > 0
              ? '${((widget.valueC / widget.total) * 100).toStringAsFixed(0)}%'
              : '',
          titleStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: sections,
            sectionsSpace: 2,
            centerSpaceRadius: 46,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.touchedSection == null) {
                    _hovered = null;
                    return;
                  }
                  _hovered =
                      response.touchedSection!.touchedSectionIndex;
                });
              },
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gesamt',
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppTheme.textMutedDark
                    : AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.money.format(widget.total),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.textPrimaryDark
                    : AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AbcClassRow extends StatelessWidget {
  final String label;
  final int count;
  final double value;
  final double total;
  final Color color;
  final NumberFormat money;
  final AppLocalizations l10n;
  const _AbcClassRow({
    required this.label,
    required this.count,
    required this.value,
    required this.total,
    required this.color,
    required this.money,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total) * 100 : 0.0;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.reportAbcCountItems(count),
            style: TextStyle(
                fontSize: 13, color: AppTheme.textPrimaryOf(context)),
          ),
        ),
        Text(
          money.format(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(
              fontSize: 11, color: AppTheme.textMutedOf(context)),
        ),
      ],
    );
  }
}

class _AbcItemCard extends StatelessWidget {
  final AbcItem item;
  final NumberFormat money;
  final Color color;
  final String classLabel;
  const _AbcItemCard({
    required this.item,
    required this.money,
    required this.color,
    required this.classLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.sku != null)
                  Text(
                    item.sku!,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedOf(context)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money.format(item.stockValue),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.abcClass.name.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gemeinsame Helfer-Widgets ────────────────────────────────────────────────

class _ReportKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? hint;
  const _ReportKpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textDisabledOf(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _HealthCard (bestehend) ──────────────────────────────────────────────────

class _HealthCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
  final bool pulsing;
  const _HealthCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
    this.pulsing = false,
  });

  @override
  State<_HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<_HealthCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final pulse = widget.pulsing
            ? Tween<double>(begin: 0.65, end: 1.0).evaluate(_ctrl)
            : 1.0;
        return Opacity(opacity: pulse, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgSurfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 16, color: widget.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMutedOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: widget.color,
              ),
            ),
            if (widget.hint != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.hint!,
                style: TextStyle(
                    fontSize: 10, color: AppTheme.textDisabledOf(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
