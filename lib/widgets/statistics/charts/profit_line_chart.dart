import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
        child: const Center(
          child: Text('Keine Daten im Zeitraum.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
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
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFEEF2F7),
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
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
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
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF111827),
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
              color: const Color(0xFF2563EB),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF2563EB).withAlpha(25),
              ),
            ),
            LineChartBarData(
              spots: profitSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: const Color(0xFF059669),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF059669).withAlpha(25),
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
      children: const [
        _LegendDot(color: Color(0xFF2563EB), label: 'Umsatz'),
        SizedBox(width: 14),
        _LegendDot(color: Color(0xFF059669), label: 'Profit'),
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
            style:
                const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      ],
    );
  }
}
