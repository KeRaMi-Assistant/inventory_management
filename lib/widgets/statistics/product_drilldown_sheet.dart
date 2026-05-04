import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
        builder: (_, scroll) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            color: const Color(0xFFF8FAFC),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE0E6EF))),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_outlined, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.product,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${data.deals.length} · $totalUnits',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
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
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statsLabelProfit,
                      value: money.format(totalProfit),
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
                              style: const TextStyle(color: Color(0xFF9CA3AF))),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => const FlLine(
                                color: Color(0xFFEEF2F7),
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
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF9CA3AF)),
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
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9CA3AF)),
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
                                color: const Color(0xFF059669),
                                barWidth: 2.5,
                                isCurved: true,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF059669).withAlpha(25),
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
                                    style: const TextStyle(
                                        color: Color(0xFF9CA3AF), fontSize: 12))
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
                                    style: const TextStyle(
                                        color: Color(0xFF9CA3AF), fontSize: 12))
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
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
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
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827)),
                                  ),
                                  Text(
                                    '${dateFmt.format(deal.orderDate)} · ${deal.quantity}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280)),
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
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
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
