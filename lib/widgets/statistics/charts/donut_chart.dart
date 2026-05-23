import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../utils/responsive.dart';

/// Donut-Chart mit Legende rechts. Zeigt automatisch nur Top-N Slices,
/// der Rest wird zu "Sonstige" zusammengefasst.
class DonutChart extends StatefulWidget {
  final Map<String, double> data;
  final String centerLabel;
  final int topN;
  final double height;
  const DonutChart({
    super.key,
    required this.data,
    required this.centerLabel,
    this.topN = 5,
    this.height = 220,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _hovered;

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFF94A3B8),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('Keine Daten.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ),
      );
    }
    final entries = widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(widget.topN).toList();
    final restSum = entries.skip(widget.topN).fold<double>(0, (s, e) => s + e.value);
    final list = [
      ...top,
      if (restSum > 0) MapEntry('Sonstige', restSum),
    ];
    final total = list.fold<double>(0, (s, e) => s + e.value);
    final money = NumberFormat.compactCurrency(locale: 'de_DE', symbol: '€');

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final isHovered = i == _hovered;
      final pct = total == 0 ? 0 : (e.value / total) * 100;
      sections.add(PieChartSectionData(
        value: e.value.abs() < 0.001 ? 0.001 : e.value,
        color: _palette[i % _palette.length],
        radius: isHovered ? 64 : 56,
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ));
    }

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > Breakpoints.legacyDonutNarrow;
          final pie = SizedBox(
            width: widget.height,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _hovered = null;
                            return;
                          }
                          _hovered = response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.centerLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      money.format(total),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final legend = SingleChildScrollView(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            list[i].key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF374151)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          money.format(list[i].value),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );

          if (wide) {
            return Row(
              children: [
                pie,
                Expanded(child: legend),
              ],
            );
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [pie, const SizedBox(height: 8), legend],
          );
        },
      ),
    );
  }
}
