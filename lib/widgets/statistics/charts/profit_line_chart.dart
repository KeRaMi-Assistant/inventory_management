import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_theme.dart';
import '../../../services/statistics_service.dart';

/// Linien-Chart mit zwei Linien: Umsatz (blau) und Profit (grün).
class ProfitLineChart extends StatelessWidget {
  final List<TimeBucket> series;
  final double height;
  const ProfitLineChart({
    super.key,
    required this.series,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Keine Daten im Zeitraum.',
              style: TextStyle(
                  color: AppTheme.textDisabledOf(context), fontSize: 13)),
        ),
      );
    }

    final money = NumberFormat.compactCurrency(locale: 'de_DE', symbol: '€');
    final dateFmt = _dateFormatFor(series.first.granularity);

    final revenueSpots = <FlSpot>[];
    final profitSpots = <FlSpot>[];
    double maxY = 0;
    double minY = 0;
    for (var i = 0; i < series.length; i++) {
      final b = series[i];
      revenueSpots.add(FlSpot(i.toDouble(), b.revenue));
      profitSpots.add(FlSpot(i.toDouble(), b.profit));
      if (b.revenue > maxY) maxY = b.revenue;
      if (b.profit > maxY) maxY = b.profit;
      if (b.profit < minY) minY = b.profit;
    }
    if (maxY == 0) maxY = 100;
    final yPadding = (maxY - minY) * 0.1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - yPadding,
          maxY: maxY + yPadding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ((maxY - minY) / 4).abs().clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppTheme.borderOf(context),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    money.format(v),
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMutedOf(context)),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (series.length / 6).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      dateFmt.format(series[i].date),
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMutedOf(context)),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              // Tooltip stays dark in both themes.
              getTooltipColor: (_) => AppTheme.navBg,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItems: (spots) {
                final i = spots.first.x.toInt();
                if (i < 0 || i >= series.length) return [];
                final b = series[i];
                final dateStr = dateFmt.format(b.date);
                return spots.map((s) {
                  final isProfit = s.barIndex == 1;
                  return LineTooltipItem(
                    '${isProfit ? 'Profit' : 'Umsatz'}\n${money.format(s.y)}\n$dateStr',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: revenueSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: AppTheme.accentTextOf(context),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.accentTextOf(context).withAlpha(25),
              ),
            ),
            LineChartBarData(
              spots: profitSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: AppTheme.successTextOf(context),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.successTextOf(context).withAlpha(25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateFormat _dateFormatFor(Granularity g) {
    switch (g) {
      case Granularity.day:
        return DateFormat('dd.MM', 'de_DE');
      case Granularity.week:
        return DateFormat('dd.MM', 'de_DE');
      case Granularity.month:
        return DateFormat('MMM yy', 'de_DE');
    }
  }
}

class ProfitChartLegend extends StatelessWidget {
  const ProfitChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _LegendDot(color: AppTheme.accentTextOf(context), label: 'Umsatz'),
        const SizedBox(width: 14),
        _LegendDot(color: AppTheme.successTextOf(context), label: 'Profit'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppTheme.textMutedOf(context))),
      ],
    );
  }
}
