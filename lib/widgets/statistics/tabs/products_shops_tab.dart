import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/statistics_service.dart';
import '../product_drilldown_sheet.dart';
import '../sortable_table.dart';
import '../stat_panel.dart';

class ProductsShopsTab extends StatelessWidget {
  final StatisticsService stats;
  const ProductsShopsTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatPanel(
          title: l10n.dealProduct,
          icon: Icons.star_outline,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SortableTable<ProductStat>(
            rows: stats.topProducts,
            defaultSortIndex: 2,
            defaultAscending: false,
            onTap: (p) => ProductDrilldownSheet.show(
              context,
              stats.drillDown(p.name),
            ),
            columns: [
              SortableColumn(
                label: l10n.dealProduct,
                builder: (p) => Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                valueOf: (p) => p.name.toLowerCase(),
              ),
              SortableColumn(
                label: l10n.statsDealsLabel,
                numeric: true,
                builder: (p) => Text('${p.count}'),
                valueOf: (p) => p.count,
              ),
              SortableColumn(
                label: l10n.statsLabelProfit,
                numeric: true,
                builder: (p) => Text(
                  money.format(p.profit),
                  style: TextStyle(
                    color: p.profit >= 0
                        ? AppTheme.success
                        : AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                valueOf: (p) => p.profit,
              ),
              SortableColumn(
                label: l10n.statsLabelRevenue,
                numeric: true,
                builder: (p) => Text(money.format(p.revenue)),
                valueOf: (p) => p.revenue,
              ),
              SortableColumn(
                label: l10n.statsLabelMargin,
                numeric: true,
                builder: (p) => Text('${p.marginPct.toStringAsFixed(1)}%'),
                valueOf: (p) => p.marginPct,
              ),
              SortableColumn(
                label: l10n.dealQuantityShort,
                numeric: true,
                builder: (p) => Text('${p.units}'),
                valueOf: (p) => p.units,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StatPanel(
          title: l10n.dealShop,
          icon: Icons.store_outlined,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SortableTable<ShopStat>(
            rows: stats.shopStats,
            defaultSortIndex: 2,
            defaultAscending: false,
            columns: [
              SortableColumn(
                label: l10n.dealShop,
                builder: (s) => Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                valueOf: (s) => s.name.toLowerCase(),
              ),
              SortableColumn(
                label: l10n.statsDealsLabel,
                numeric: true,
                builder: (s) => Text('${s.count}'),
                valueOf: (s) => s.count,
              ),
              SortableColumn(
                label: l10n.statsLabelRevenue,
                numeric: true,
                builder: (s) => Text(money.format(s.volume)),
                valueOf: (s) => s.volume,
              ),
              SortableColumn(
                label: l10n.statsLabelProfit,
                numeric: true,
                builder: (s) => Text(
                  money.format(s.profit),
                  style: TextStyle(
                    color: s.profit >= 0
                        ? AppTheme.success
                        : AppTheme.danger,
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
              SortableColumn(
                label: 'Ø',
                numeric: true,
                builder: (s) => Text(money.format(s.avgProfit)),
                valueOf: (s) => s.avgProfit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
