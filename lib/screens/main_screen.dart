import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../services/csv_service.dart';
import '../widgets/amazon_import_dialog.dart';
import '../widgets/buyer_legend.dart';
import '../widgets/deal_table.dart';
import '../widgets/kpi_card.dart';
import '../widgets/summary_panel.dart';
import '../widgets/add_edit_deal_dialog.dart';
import 'settings_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  // ── CSV Export ────────────────────────────────────────────────────────────
  Future<void> _export(BuildContext context, InventoryProvider provider) async {
    final deals = provider.deals;
    if (deals.isEmpty) {
      _showSnack(context, 'Keine Einträge zum Exportieren.', isError: true);
      return;
    }
    final (path, err) = await CsvService.exportDeals(List.from(deals));
    if (!context.mounted) return;
    if (err != null) {
      _showSnack(context, 'Fehler: $err', isError: true);
    } else if (path != null) {
      _showSnack(context, 'Exportiert: $path');
    }
  }

  // ── CSV Import ────────────────────────────────────────────────────────────
  Future<void> _import(BuildContext context, InventoryProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CSV importieren'),
        content: const Text(
          'Importierte Einträge werden zu den bestehenden Daten hinzugefügt.\n\n'
          'Erwartet wird das gleiche Format wie beim Export (Semikolon-getrennt).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Datei auswählen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final (deals, err) = await CsvService.importDeals(provider.nextDealId);
    if (!context.mounted) return;
    if (err != null) {
      _showSnack(context, 'Fehler: $err', isError: true);
    } else if (deals != null) {
      if (deals.isEmpty) {
        _showSnack(context, 'Keine gültigen Einträge gefunden.', isError: true);
        return;
      }
      await provider.importDeals(deals);
      if (!context.mounted) return;
      _showSnack(context, '${deals.length} Einträge importiert.');
    }
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFC0392B) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final isWide = MediaQuery.of(context).size.width >= 700;
        return isWide
            ? _buildWide(context, provider)
            : _buildNarrow(context, provider);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Desktop layout (≥ 700 px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWide(BuildContext context, InventoryProvider provider) {
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2744), Color(0xFF1A3F70)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            title: const Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 20, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Bestell- & Verkaufs-Tracker',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            actions: [
              _AppBarButton(
                icon: Icons.shopping_bag_outlined,
                label: 'Amazon Import',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const AmazonImportDialog(),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                  width: 1,
                  height: 20,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 2)),
              const SizedBox(width: 6),
              _AppBarButton(
                icon: Icons.upload_file_outlined,
                label: 'Importieren',
                onTap: () => _import(context, provider),
              ),
              const SizedBox(width: 6),
              _AppBarButton(
                icon: Icons.download_outlined,
                label: 'Exportieren',
                onTap: () => _export(context, provider),
              ),
              const SizedBox(width: 6),
              Container(
                  width: 1,
                  height: 20,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 4)),
              _AppBarButton(
                icon: Icons.settings_outlined,
                label: 'Einstellungen',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const AddEditDealDialog(),
        ),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Neuer Eintrag'),
        elevation: 3,
      ),
      body: Column(
        children: [
          // ── KPI strip ───────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2744), Color(0xFF1A3F70)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A4A7F), width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                      width: 210,
                      child: KpiCard(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Offene Bestellungen',
                        value: '${provider.openOrdersCount}',
                        color: const Color(0xFF2563EB),
                      )),
                  const SizedBox(width: 12),
                  SizedBox(
                      width: 210,
                      child: KpiCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Gesamtprofit',
                        value: fmt.format(provider.totalProfit),
                        color: const Color(0xFF059669),
                      )),
                  const SizedBox(width: 12),
                  SizedBox(
                      width: 210,
                      child: KpiCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Offener Betrag',
                        value: fmt.format(provider.openAmount),
                        color: const Color(0xFFD97706),
                      )),
                  const SizedBox(width: 12),
                  SizedBox(
                      width: 210,
                      child: KpiCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'Offene Lieferungen',
                        value: '${provider.openDeliveriesCount}',
                        color: const Color(0xFF7C3AED),
                      )),
                ],
              ),
            ),
          ),
          // ── Table + sidebar ─────────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: DealTable()),
                Container(
                  width: 292,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(
                      left: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: const SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(14, 14, 14, 100),
                    child: Column(
                      children: [
                        BuyerLegend(),
                        SizedBox(height: 12),
                        SummaryPanel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mobile layout (< 700 px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNarrow(BuildContext context, InventoryProvider provider) {
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2744), Color(0xFF1A3F70)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              title: const Row(
                children: [
                  Icon(Icons.inventory_2_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Tracker',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined,
                      color: Colors.white70, size: 20),
                  tooltip: 'Amazon Import',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AmazonImportDialog(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file_outlined,
                      color: Colors.white70, size: 20),
                  tooltip: 'Importieren',
                  onPressed: () => _import(context, provider),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: Colors.white70, size: 20),
                  tooltip: 'Exportieren',
                  onPressed: () => _export(context, provider),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white70, size: 20),
                  tooltip: 'Einstellungen',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const AddEditDealDialog(),
          ),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Neuer Eintrag'),
        ),
        body: Column(
          children: [
            // KPI 2 × 2 grid
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F2744), Color(0xFF1A3F70)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A4A7F), width: 1),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: KpiCard(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Offene Bestellungen',
                        value: '${provider.openOrdersCount}',
                        color: const Color(0xFF2563EB),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Gesamtprofit',
                        value: fmt.format(provider.totalProfit),
                        color: const Color(0xFF059669),
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: KpiCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Offener Betrag',
                        value: fmt.format(provider.openAmount),
                        color: const Color(0xFFD97706),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'Offene Lieferungen',
                        value: '${provider.openDeliveriesCount}',
                        color: const Color(0xFF7C3AED),
                      )),
                    ],
                  ),
                ],
              ),
            ),
            // Tab bar
            Container(
              color: Colors.white,
              child: const TabBar(
                indicatorColor: Color(0xFF2563EB),
                indicatorWeight: 2.5,
                labelColor: Color(0xFF2563EB),
                unselectedLabelColor: Color(0xFF94A3B8),
                labelStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(
                      icon: Icon(Icons.list_alt_rounded, size: 18),
                      text: 'Einträge'),
                  Tab(
                      icon: Icon(Icons.bar_chart_rounded, size: 18),
                      text: 'Übersicht'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  DealTable(),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 80),
                    child: Column(
                      children: [
                        BuyerLegend(),
                        SizedBox(height: 12),
                        SummaryPanel(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AppBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AppBarButton> createState() => _AppBarButtonState();
}

class _AppBarButtonState extends State<_AppBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hovered ? Colors.white38 : Colors.white24,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 15, color: Colors.white.withAlpha(210)),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


