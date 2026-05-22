import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/inventory_batch.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/statistics_filter_provider.dart';
import '../services/statistics_export_service.dart';
import '../services/statistics_service.dart';
import '../widgets/statistics/filter_bar.dart';
import '../widgets/statistics/tabs/buyers_tab.dart';
import '../widgets/statistics/tabs/finance_tab.dart';
import '../widgets/statistics/tabs/inventory_suppliers_tab.dart';
import '../widgets/statistics/tabs/overview_tab.dart';
import '../widgets/statistics/tabs/products_shops_tab.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);
  Future<List<InventoryBatch>>? _batchFuture;

  @override
  void initState() {
    super.initState();
    final inv = context.read<InventoryProvider>();
    _batchFuture = inv.loadAllBatches().catchError((Object e) {
      if (kDebugMode) debugPrint('loadAllBatches: $e');
      return <InventoryBatch>[];
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _onExport(StatisticsService stats) async {
    final l10n = AppLocalizations.of(context);
    final svc = StatisticsExportService(stats);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: Color(0xFFDC2626)),
              title: Text(l10n.statsExportPdfTitle),
              subtitle: Text(l10n.statsExportPdfDesc),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined,
                  color: Color(0xFF059669)),
              title: Text(l10n.statsExportXlsxTitle),
              subtitle: Text(l10n.statsExportXlsxDesc),
              onTap: () => Navigator.pop(context, 'xlsx'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined,
                  color: Color(0xFF2563EB)),
              title: Text(l10n.statsExportCsvTitle),
              subtitle: Text(l10n.statsExportCsvDesc),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.print_outlined, color: Color(0xFF6B7280)),
              title: Text(l10n.statsExportPrintTitle),
              onTap: () => Navigator.pop(context, 'print'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (choice) {
        case 'pdf':
          final bytes = await svc.buildOverviewPdf();
          await svc.savePdf(bytes);
          break;
        case 'xlsx':
          await svc.saveExcel();
          break;
        case 'csv':
          await svc.saveDealsCsv();
          break;
        case 'print':
          final bytes = await svc.buildOverviewPdf();
          await Printing.layoutPdf(onLayout: (_) async => bytes);
          break;
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.statsReportExported)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.statsExportFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InventoryBatch>>(
      future: _batchFuture,
      builder: (context, snap) {
        return Consumer3<InventoryProvider, StatisticsFilterProvider,
            AppPreferencesProvider>(
          builder: (context, inv, filter, prefs, _) {
            if (inv.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final batches = snap.data ?? const <InventoryBatch>[];
            final stats = StatisticsService(
              allDeals: inv.deals,
              allItems: inv.inventoryItems,
              suppliers: inv.suppliers,
              batches: batches,
              allMovements: inv.movements,
              filter: filter,
              monthlyProfitGoal: prefs.monthlyProfitGoal,
              lowStockThreshold: prefs.lowStockThreshold,
            );

            return Container(
              color: AppTheme.bgAppOf(context),
              child: Column(
                children: [
                  StatisticsFilterBar(onExport: () => _onExport(stats)),
                  Material(
                    color: AppTheme.bgSurfaceOf(context),
                    elevation: 0,
                    child: TabBar(
                      controller: _tab,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: AppTheme.accentTextOf(context),
                      indicatorWeight: 2,
                      labelColor: AppTheme.accentTextOf(context),
                      unselectedLabelColor: AppTheme.textMutedOf(context),
                      dividerColor: AppTheme.borderOf(context),
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: [
                        Tab(icon: const Icon(Icons.dashboard_outlined, size: 16), text: AppLocalizations.of(context).statsTabOverview),
                        Tab(icon: const Icon(Icons.people_outline, size: 16), text: AppLocalizations.of(context).statsTabBuyers),
                        Tab(icon: const Icon(Icons.shopping_bag_outlined, size: 16), text: AppLocalizations.of(context).statsTabProductsShops),
                        Tab(icon: const Icon(Icons.inventory_2_outlined, size: 16), text: AppLocalizations.of(context).statsTabInventorySuppliers),
                        Tab(icon: const Icon(Icons.account_balance_outlined, size: 16), text: AppLocalizations.of(context).statsTabFinance),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        OverviewTab(stats: stats),
                        BuyersTab(stats: stats),
                        ProductsShopsTab(stats: stats),
                        InventorySuppliersTab(stats: stats),
                        FinanceTab(
                          stats: stats,
                          onExportTax: () async {
                            final svc = StatisticsExportService(stats);
                            final l10n = AppLocalizations.of(context);
                            try {
                              await svc.saveTaxCsv();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(l10n.statsTaxExportSaved)),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.errorPrefix('$e'))),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
