import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/inventory_provider.dart';
import '../utils/status_l10n.dart';

class SummaryPanel extends StatelessWidget {
  const SummaryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final fmt = NumberFormat.currency(locale: localeTag, symbol: '€');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final deals = provider.deals;
        final buyers = provider.buyers.where((b) => b.active).toList();

        final buyerStats = {
          for (final b in buyers)
            b.name: _Stat(
              count: deals.where((d) => d.buyer == b.name).length,
              zuBekommen: deals
                  .where((d) => d.buyer == b.name)
                  .fold(0.0, (s, d) => s + (d.zuBekommen ?? 0)),
              profit: deals
                  .where((d) => d.buyer == b.name)
                  .fold(0.0, (s, d) => s + (d.totalProfit ?? 0)),
              color: b.buyerCellColor,
            ),
        };

        final statusColors = {
          'Bestellt': const Color(0xFF3B82F6),
          'Unterwegs': const Color(0xFFF59E0B),
          'Angekommen': const Color(0xFF0D9488),
          'Rechnung gestellt': const Color(0xFF8B5CF6),
          'Done': const Color(0xFF10B981),
        };

        final statusStats = {
          for (final s in InventoryProvider.statusOptions)
            s: _Stat(
              count: deals.where((d) => d.status == s).length,
              profit: deals
                  .where((d) => d.status == s)
                  .fold(0.0, (sum, d) => sum + (d.totalProfit ?? 0)),
              color: statusColors[s] ?? Colors.grey,
            ),
        };

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      l10n.summaryHeading,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionLabel(l10n.summaryByBuyer),
                const SizedBox(height: 6),
                if (buyerStats.isEmpty)
                  const Text('–', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                else
                  ...buyerStats.entries.map((e) => _BuyerRow(
                        name: e.key,
                        stat: e.value,
                        fmt: fmt,
                      )),
                const SizedBox(height: 12),
                _SectionLabel(l10n.summaryByStatus),
                const SizedBox(height: 6),
                ...statusStats.entries.map((e) => _StatusRow(
                      name: localizeDealStatus(context, e.key),
                      stat: e.value,
                      fmt: fmt,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _BuyerRow extends StatelessWidget {
  final String name;
  final _Stat stat;
  final NumberFormat fmt;
  const _BuyerRow({required this.name, required this.stat, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 20,
            child: Text(
              '${stat.count}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fmt.format(stat.profit),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF059669),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String name;
  final _Stat stat;
  final NumberFormat fmt;
  const _StatusRow({required this.name, required this.stat, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: stat.color.withAlpha(26),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: stat.color.withAlpha(90)),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 10,
                      color: stat.color,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 20,
                child: Text(
                  '${stat.count}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fmt.format(stat.profit),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final int count;
  final double zuBekommen;
  final double profit;
  final Color color;
  _Stat({required this.count, this.zuBekommen = 0, required this.profit, required this.color});
}
