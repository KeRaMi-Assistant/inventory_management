import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/statistics_service.dart';
import '../charts/donut_chart.dart';
import '../charts/monthly_bar_chart.dart';
import '../charts/profit_line_chart.dart';
import '../kpi_card.dart';
import '../stat_panel.dart';

/// Übersichts-Tab: KPI-Karten, Profit-Verlauf, Marge-Trend, Donut-Charts.
class OverviewTab extends StatelessWidget {
  final StatisticsService stats;
  const OverviewTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final compare = stats.filter.compareToPrevious;

    final byBuyer = <String, double>{};
    for (final b in stats.buyerStats) {
      byBuyer[b.name] = b.profit;
    }
    final byShop = <String, double>{};
    for (final s in stats.shopStats) {
      byShop[s.name] = s.volume;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        KpiGrid(
          cards: [
            KpiCard(
              label: 'Umsatz',
              value: money.format(stats.revenue),
              icon: Icons.payments_outlined,
              accent: const Color(0xFF2563EB),
              deltaPct: compare
                  ? StatisticsService.deltaPct(stats.revenue, stats.prevRevenue)
                  : null,
              deltaLabel: compare ? 'vs. Vorperiode' : null,
            ),
            KpiCard(
              label: 'Profit',
              value: money.format(stats.profit),
              icon: Icons.trending_up,
              accent: const Color(0xFF059669),
              deltaPct: compare
                  ? StatisticsService.deltaPct(stats.profit, stats.prevProfit)
                  : null,
              deltaLabel: compare ? 'vs. Vorperiode' : null,
            ),
            KpiCard(
              label: 'Profit-Marge',
              value: '${stats.margin.toStringAsFixed(1)}%',
              icon: Icons.percent_outlined,
              accent: const Color(0xFF7C3AED),
              deltaPct: compare
                  ? StatisticsService.deltaPct(stats.margin, stats.prevMargin)
                  : null,
              deltaLabel: compare ? 'vs. Vorperiode' : null,
            ),
            KpiCard(
              label: 'ROI',
              value: '${stats.roi.toStringAsFixed(1)}%',
              icon: Icons.show_chart,
              accent: const Color(0xFFD97706),
              deltaPct: compare
                  ? StatisticsService.deltaPct(stats.roi, stats.prevRoi)
                  : null,
              deltaLabel: compare ? 'vs. Vorperiode' : null,
            ),
            KpiCard(
              label: 'Offene Forderungen',
              value: money.format(stats.openReceivables),
              icon: Icons.hourglass_empty,
              accent: const Color(0xFFDC2626),
              deltaPct: compare
                  ? StatisticsService.deltaPct(
                      stats.openReceivables, stats.prevOpenReceivables)
                  : null,
              deltaLabel: compare ? 'vs. Vorperiode' : null,
              deltaInverted: true,
            ),
            KpiCard(
              label: 'Anzahl Deals',
              value: '${stats.dealCount}',
              icon: Icons.inventory_2_outlined,
              accent: const Color(0xFF0891B2),
              deltaPct: compare
                  ? StatisticsService.deltaPct(
                      stats.dealCount.toDouble(),
                      stats.prevDealCount.toDouble(),
                    )
                  : null,
              deltaLabel: compare ? 'vs. Vorperiode' : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatPanel(
          title: 'Profit & Umsatz',
          icon: Icons.show_chart,
          trailing: const ProfitChartLegend(),
          child: ProfitLineChart(series: stats.timeSeries),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = StatPanel(
              title: 'Profit pro Bucket',
              icon: Icons.bar_chart_outlined,
              child: MonthlyBarChart(
                series: stats.timeSeries,
                comparison: compare ? stats.previousTimeSeries : null,
              ),
            );
            final right = StatPanel(
              title: 'Profit-Marge Trend',
              icon: Icons.timeline,
              child: MarginLineChart(series: stats.timeSeries),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 16),
                  Expanded(child: right),
                ],
              );
            }
            return Column(
              children: [left, const SizedBox(height: 16), right],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = StatPanel(
              title: 'Profit nach Käufer',
              icon: Icons.people_outline,
              child: DonutChart(
                data: byBuyer,
                centerLabel: 'GESAMT',
              ),
            );
            final right = StatPanel(
              title: 'Umsatz nach Shop',
              icon: Icons.store_outlined,
              child: DonutChart(
                data: byShop,
                centerLabel: 'GESAMT',
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 16),
                  Expanded(child: right),
                ],
              );
            }
            return Column(
              children: [left, const SizedBox(height: 16), right],
            );
          },
        ),
      ],
    );
  }
}
