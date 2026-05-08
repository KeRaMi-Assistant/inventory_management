import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/statistics_service.dart';
import 'stat_panel.dart';

/// Bottom-Sheet für tiefen Drilldown auf ein einzelnes Produkt.
class ProductDrilldownSheet extends StatelessWidget {
  final ProductDrilldown data;
  const ProductDrilldownSheet({super.key, required this.data});

  static Future<void> show(BuildContext context, ProductDrilldown data) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scroll) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            color: AppTheme.bgAppOf(ctx),
            child: ProductDrilldownSheet(data: data),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final dateFmt = DateFormat.yMd(localeTag);
    final monthFmt = DateFormat.yMMM(localeTag);

    final totalRevenue =
        data.deals.fold<double>(0, (s, d) => s + (d.zuBekommen ?? 0));
    final totalProfit =
        data.deals.fold<double>(0, (s, d) => s + (d.totalProfit ?? 0));
    final totalUnits = data.deals.fold<int>(0, (s, d) => s + d.quantity);
    final marginPct =
        totalRevenue == 0 ? 0.0 : (totalProfit / totalRevenue) * 100;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppTheme.bgSurfaceOf(context),
            border: Border(
                bottom: BorderSide(color: AppTheme.borderOf(context))),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_outlined,
                  color: AppTheme.accentTextOf(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.product,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${data.deals.length} · $totalUnits',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedOf(context)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statsLabelRevenue,
                      value: money.format(totalRevenue),
                      color: AppTheme.accentTextOf(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statsLabelProfit,
                      value: money.format(totalProfit),
                      color: AppTheme.successTextOf(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    // Purple margin accent — chart-series semantic constant.
                    child: _MiniStat(
                      label: l10n.statsLabelMargin,
                      value: '${marginPct.toStringAsFixed(1)}%',
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatPanel(
                title: l10n.statsProfitPerMonth,
                icon: Icons.show_chart,
                child: SizedBox(
                  height: 180,
                  child: data.monthSeries.isEmpty
                      ? Center(
                          child: Text(l10n.dealCommentEmpty,
                              style: TextStyle(
                                  color:
                                      AppTheme.textDisabledOf(context))),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => FlLine(
                                color: AppTheme.borderOf(context),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  getTitlesWidget: (v, _) => Text(
                                    NumberFormat.compactCurrency(
                                            locale: localeTag, symbol: '€')
                                        .format(v),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            AppTheme.textMutedOf(context)),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 26,
                                  interval:
                                      (data.monthSeries.length / 5).ceilToDouble().clamp(1, double.infinity),
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= data.monthSeries.length) {
                                      return const SizedBox();
                                    }
                                    return Text(
                                      monthFmt.format(data.monthSeries[i].date),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textMutedOf(
                                              context)),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0;
                                      i < data.monthSeries.length;
                                      i++)
                                    FlSpot(i.toDouble(),
                                        data.monthSeries[i].profit),
                                ],
                                color: AppTheme.successTextOf(context),
                                barWidth: 2.5,
                                isCurved: true,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.successTextOf(context)
                                      .withAlpha(25),
                                ),
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatPanel(
                      title: '${l10n.dealBuyer} · Top',
                      icon: Icons.people_outline,
                      child: Column(
                        children: data.topBuyers.isEmpty
                            ? [
                                Text(l10n.dealCommentEmpty,
                                    style: TextStyle(
                                        color: AppTheme.textDisabledOf(
                                            context),
                                        fontSize: 12))
                              ]
                            : data.topBuyers
                                .map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              child: Text(e.key,
                                                  style: const TextStyle(
                                                      fontSize: 13))),
                                          Text(money.format(e.value),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatPanel(
                      title: '${l10n.dealShop} · Top',
                      icon: Icons.store_outlined,
                      child: Column(
                        children: data.topShops.isEmpty
                            ? [
                                Text(l10n.dealCommentEmpty,
                                    style: TextStyle(
                                        color: AppTheme.textDisabledOf(
                                            context),
                                        fontSize: 12))
                              ]
                            : data.topShops
                                .map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              child: Text(e.key,
                                                  style: const TextStyle(
                                                      fontSize: 13))),
                                          Text(money.format(e.value),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatPanel(
                title: l10n.statsAllDeals,
                icon: Icons.list_alt_outlined,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final deal in data.deals)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: deal.status == 'Done'
                                    ? AppTheme.successTextOf(context)
                                    : AppTheme.warningTextOf(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${deal.id} · ${deal.shop} → ${deal.buyer ?? '–'}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            AppTheme.textPrimaryOf(context)),
                                  ),
                                  Text(
                                    '${dateFmt.format(deal.orderDate)} · ${deal.quantity}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            AppTheme.textMutedOf(context)),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              money.format(deal.totalProfit ?? 0),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: (deal.totalProfit ?? 0) >= 0
                                    ? AppTheme.successTextOf(context)
                                    : AppTheme.dangerTextOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedOf(context))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}
