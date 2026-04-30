import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/kpi_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _kpi(Icons.shopping_cart_outlined, 'Offene Bestellungen', '${provider.openOrdersCount}', const Color(0xFF2563EB)),
                    _kpi(Icons.local_shipping_outlined, 'Unterwegs', '${provider.openDeliveriesCount}', const Color(0xFFD97706)),
                    _kpi(Icons.today_outlined, 'Heute angekommen', '${provider.arrivedTodayCount}', const Color(0xFF0D9488)),
                    _kpi(Icons.trending_up_rounded, 'Gesamtprofit', fmt.format(provider.totalProfit), const Color(0xFF059669)),
                    _kpi(Icons.account_balance_wallet_outlined, 'Offener Betrag', fmt.format(provider.openAmount), const Color(0xFFD97706)),
                    _kpi(Icons.warning_amber_rounded, 'Lager kritisch', '${provider.criticalStockCount}', const Color(0xFFDC2626)),
                    _kpi(Icons.receipt_long_outlined, 'Ausstehende Rechnungen', '${provider.missingInvoiceCount}', const Color(0xFF8B5CF6)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 960;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _BuyerOverview(fmt: fmt)),
                        const SizedBox(width: 16),
                        const Expanded(child: _ActivityFeed()),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _BuyerOverview(fmt: fmt),
                      const SizedBox(height: 16),
                      const _ActivityFeed(),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kpi(IconData icon, String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 220,
        child: KpiCard(icon: icon, title: title, value: value, color: color),
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM. HH:mm');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final activities = provider.activities.take(10).toList();
        return _Panel(
          title: 'Aktivitäts-Feed',
          icon: Icons.bolt_outlined,
          child: activities.isEmpty
              ? const _MutedText('Noch keine Aktionen vorhanden.')
              : Column(
                  children: activities
                      .map(
                        (a) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.circle, size: 8, color: Color(0xFF2563EB)),
                          title: Text(a.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(fmt.format(a.date), style: const TextStyle(fontSize: 11)),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}

class _BuyerOverview extends StatelessWidget {
  final NumberFormat fmt;
  const _BuyerOverview({required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final rows = provider.buyers.map((buyer) {
          final deals = provider.deals.where((d) => d.buyer == buyer.name).toList();
          deals.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          final open = deals.where((d) => d.status != 'Done').fold(0.0, (sum, d) => sum + (d.zuBekommen ?? 0));
          return (buyer: buyer, count: deals.length, open: open, last: deals.firstOrNull);
        }).toList();

        return _Panel(
          title: 'Käufer-Schnellübersicht',
          icon: Icons.people_outline,
          child: rows.isEmpty
              ? const _MutedText('Käufer in den Einstellungen anlegen.')
              : Column(
                  children: rows
                      .map(
                        (row) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: row.buyer.buyerCellColor, shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(row.buyer.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                              SizedBox(width: 70, child: Text('${row.count} Deals', textAlign: TextAlign.right)),
                              SizedBox(width: 120, child: Text(fmt.format(row.open), textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700))),
                              SizedBox(width: 150, child: Text(row.last?.product ?? '-', overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Panel({required this.title, required this.icon, required this.child});

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
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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

class _MutedText extends StatelessWidget {
  final String text;
  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Color(0xFF94A3B8)));
  }
}
