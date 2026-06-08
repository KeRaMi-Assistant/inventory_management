import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/pricing_plan.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/purchasing_provider.dart';
import '../services/csv_service.dart';
import '../widgets/adaptive_nav_scaffold.dart';
import '../widgets/add_edit_deal_dialog.dart';
import '../widgets/global_search_dialog.dart';
import 'analytics_section_screen.dart';
import 'dashboard_screen.dart';
import 'help_screen.dart';
import 'inventory_screen.dart';
import 'sales_section_screen.dart';
import 'settings_screen.dart';
import 'suppliers_screen.dart';
import 'main_section.dart';
import 'main_tab.dart';
import 'warehouse_hub_screen.dart';
import '../utils/responsive.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  MainTab _selectedIndex = MainTab.dashboard;
  String? _selectedTicket;

  // T3.6 — Sektions-Default-Memory: letzter aktiver Sub-Tab je Sektion.
  // Wird OHNE setState aktualisiert (reines Bookkeeping, kein Rebuild-Trigger).
  final Map<MainSection, MainTab> _lastTabPerSection = {};

  // ── Sektions-Ebene (Tier-2b) ───────────────────────────────────────────
  // Die 5 Sektionen liegen ÜBER dem stabilen MainTab-Enum. Icons/Labels
  // werden pro Sektion aufgelöst — der State-Schlüssel bleibt _selectedIndex
  // (MainTab), siehe main_section.dart.

  /// (outline, filled)-Icon-Paar pro Sektion.
  static const Map<MainSection, (IconData, IconData)> _sectionIcons = {
    MainSection.dashboard: (Icons.dashboard_outlined, Icons.dashboard_rounded),
    MainSection.verkauf: (Icons.point_of_sale_outlined, Icons.point_of_sale),
    MainSection.lager: (Icons.warehouse_outlined, Icons.warehouse),
    MainSection.auswertung: (Icons.insights_outlined, Icons.insights),
    MainSection.konto: (Icons.account_circle_outlined, Icons.account_circle),
  };

  String _sectionLabel(AppLocalizations l10n, MainSection section) =>
      switch (section) {
        MainSection.dashboard => l10n.navDashboard,
        MainSection.verkauf => l10n.navSectionSales,
        MainSection.lager => l10n.navSectionWarehouse,
        MainSection.auswertung => l10n.navSectionInsights,
        MainSection.konto => l10n.navSectionAccount,
      };

  /// Sub-Tab-Label für die Breadcrumb (Desktop): das konkrete Ziel
  /// innerhalb einer Sektion (Deals/Tickets/Inbox, Statistik/Aktivität,
  /// Bestand/Lieferanten als Deep-Link). `null`, wenn die Sektion nur ein
  /// einziges Ziel hat (Dashboard).
  String? _subTabLabel(AppLocalizations l10n, MainTab tab) => switch (tab) {
        MainTab.deals => l10n.navDeals,
        MainTab.tickets => l10n.navTickets,
        MainTab.inbox => l10n.navInbox,
        MainTab.inventory => l10n.navInventory,
        MainTab.suppliers => l10n.navSuppliers,
        MainTab.stats => l10n.navStatistics,
        MainTab.activity => l10n.navActivity,
        MainTab.settings => l10n.navSettings,
        MainTab.help => l10n.navHelp,
        // dashboard + warehouse-Hub sind selbst das Sektions-Ziel.
        MainTab.dashboard || MainTab.warehouse => null,
      };

  Future<void> _export(
    BuildContext context,
    InventoryProvider provider,
    CatalogProvider catalog,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Suppliers + purchase orders now live in PurchasingProvider; deals, shops,
    // buyers, inventory items and warehouses stay on InventoryProvider.
    final purchasing = context.read<PurchasingProvider>();
    final (path, err) = await CsvService.exportAll(
      List.from(provider.deals),
      List.from(provider.shops),
      List.from(provider.buyers),
      List.from(provider.inventoryItems),
      suppliers: List.from(purchasing.suppliers),
      categories: List.from(catalog.productCategories),
      products: List.from(catalog.products),
      warehouses: List.from(provider.warehouses),
      purchaseOrders: List.from(purchasing.purchaseOrders),
      // PO items are not held in the global cache (lazy-loaded per detail
      // screen), so we export an empty list for now. A future task can wire
      // up a global PO-items cache when the use case warrants it.
      purchaseOrderItems: const [],
    );
    if (!context.mounted) return;
    if (err != null) {
      _showSnack(context, l10n.errorPrefix(err), isError: true);
    } else if (path != null) {
      _showSnack(context, l10n.csvExportSuccess(path));
    }
  }

  Future<void> _import(BuildContext context, InventoryProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.csvImportConfirmTitle),
        content: Text(l10n.csvImportConfirmText),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.csvImportPickFile)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // workspaceId and userId are required by the new section parsers so that
    // imported entities carry the correct context (not taken from the CSV).
    final workspaceId =
        context.read<ActiveWorkspaceProvider>().active?.id ?? '';
    final userId =
        context.read<AuthProvider>().currentUser?.id ?? '';

    final (result, err) = await CsvService.importAll(
      provider.nextDealId,
      workspaceId: workspaceId,
      userId: userId,
    );
    if (!context.mounted) return;
    if (err != null) {
      _showSnack(context, l10n.errorPrefix(err), isError: true);
    } else if (result != null) {
      final (deals, shops, buyers, suppliers, items) =
          await provider.importCsvAll(result);
      if (context.mounted) {
        _showSnack(
            context,
            l10n.csvImportSummary(deals, shops, buyers, suppliers, items));
      }
    }
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Inbox-Tab ist nur ab `hasInbox` (Starter+) sichtbar. Reihenfolge
  /// im sonstigen Nav bleibt stabil, damit andere Screens (GlobalSearch,
  /// _openTicket, _openSearch) ihre Indizes nicht neu lernen müssen.
  Map<MainTab, bool> _navVisibility(BillingProvider billing) {
    final hasInbox =
        PricingPlan.forBillingPlan(billing.currentPlan).hasInbox;
    return {
      MainTab.dashboard: true,
      MainTab.deals: true,
      MainTab.tickets: true,
      MainTab.inbox: hasInbox,
      MainTab.inventory: true,
      MainTab.suppliers: true,
      MainTab.stats: true,
      MainTab.activity: true,
      MainTab.settings: true,
      MainTab.help: true,
      MainTab.warehouse: true, // AF11
    };
  }

  void _openTicket(String ticket) {
    setState(() {
      _selectedTicket = ticket;
      _selectedIndex = MainTab.tickets;
    });
  }

  void _openSearch() {
    final inventoryProvider = context.read<InventoryProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    final prefs = context.read<AppPreferencesProvider>();
    GlobalSearchDialog.show(
      context,
      selectTab: (tab) => setState(() => _selectedIndex = tab),
      openTicket: _openTicket,
      onImport: () => _import(context, inventoryProvider),
      onExport: () => _export(context, inventoryProvider, catalogProvider),
      onNewDeal: () => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AddEditDealDialog(
          initialTicketNumber:
              _selectedIndex == MainTab.tickets ? _selectedTicket : null,
        ),
      ),
      onToggleTheme: () {
        final current = prefs.themeMode;
        final next = current == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
        prefs.setThemeMode(next);
      },
    );
  }

  void _goToDealsReview() {
    context.read<FilterProvider>().setOnlyNeedsReview(true);
    setState(() => _selectedIndex = MainTab.deals);
  }

  // T3.7 — Quick-Actions-BottomSheet für den Lager-Hub (MainTab.warehouse).
  // rootContext ist der Context des Consumer2-Builders — bleibt nach
  // Navigator.pop(sheetContext) noch mounted.
  void _showLagerQuickActions(
      BuildContext rootContext, InventoryProvider provider) {
    final l10n = AppLocalizations.of(rootContext);
    showModalBottomSheet<void>(
      context: rootContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: AppTheme.bgSurfaceOf(rootContext),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag-Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderOf(rootContext),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Sheet-Titel
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.quickActionsTitle,
                    style: TextStyle(
                      color: AppTheme.textPrimaryOf(rootContext),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // 1. Neuer Artikel
              ListTile(
                key: const Key('quickAction-newItem'),
                leading:
                    Icon(Icons.inventory_2_outlined,
                        color: AppTheme.textSecondaryOf(rootContext)),
                title: Text(
                  l10n.inventoryAddItem,
                  style: TextStyle(color: AppTheme.textPrimaryOf(rootContext)),
                ),
                minVerticalPadding: 12,
                onTap: () {
                  Navigator.pop(sheetContext);
                  InventoryScreen.showAddDialog(rootContext);
                },
              ),
              // 2. Neuer Deal
              ListTile(
                key: const Key('quickAction-newDeal'),
                leading: Icon(Icons.add_shopping_cart_outlined,
                    color: AppTheme.textSecondaryOf(rootContext)),
                title: Text(
                  l10n.dealNew,
                  style: TextStyle(color: AppTheme.textPrimaryOf(rootContext)),
                ),
                minVerticalPadding: 12,
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDialog(
                    context: rootContext,
                    barrierDismissible: false,
                    builder: (_) => const AddEditDealDialog(),
                  );
                },
              ),
              // 3. CSV importieren
              ListTile(
                key: const Key('quickAction-csvImport'),
                leading: Icon(Icons.upload_file_outlined,
                    color: AppTheme.textSecondaryOf(rootContext)),
                title: Text(
                  l10n.appBarMenuCsvImport,
                  style: TextStyle(color: AppTheme.textPrimaryOf(rootContext)),
                ),
                minVerticalPadding: 12,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _import(rootContext, provider);
                },
              ),
              // 4. CSV exportieren
              ListTile(
                key: const Key('quickAction-csvExport'),
                leading: Icon(Icons.download_outlined,
                    color: AppTheme.textSecondaryOf(rootContext)),
                title: Text(
                  l10n.appBarMenuCsvExport,
                  style: TextStyle(color: AppTheme.textPrimaryOf(rootContext)),
                ),
                minVerticalPadding: 12,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _export(
                    rootContext,
                    provider,
                    rootContext.read<CatalogProvider>(),
                  );
                },
              ),
              // Sicherheitsabstand zum Home-Indicator (SafeArea übernimmt
              // nochmal, aber explizites Padding hält das Sheet luftig)
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// T1.2 — kontextuelles „Neu" für den aktuellen Tab (Shortcut: n).
  /// Öffnet den jeweils passenden Erstellungsdialog/-flow, sofern vorhanden.
  void _contextualNew() {
    switch (_selectedIndex) {
      case MainTab.deals:
      case MainTab.tickets:
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AddEditDealDialog(
            initialTicketNumber:
                _selectedIndex == MainTab.tickets ? _selectedTicket : null,
          ),
        );
      case MainTab.inventory:
        InventoryScreen.showAddDialog(context);
      default:
        // Kein kontextuelles Neu für diesen Tab — kein-op.
        break;
    }
  }

  // ── Bottom-Nav (Phone) — 5 Sektions-Slots, kein „Mehr" mehr ──────────────

  /// Wechselt IN eine Sektion (Bottom-Nav-Tap oder Rail-Klick). No-op, wenn
  /// die Sektion bereits aktiv ist (verhindert Sub-Tab-Reset).
  /// T3.6: Stellt den zuletzt aktiven Sub-Tab der Ziel-Sektion wieder her.
  void _selectSection(MainSection section) {
    if (sectionOf(_selectedIndex) == section) return;
    setState(() {
      final restored = _lastTabPerSection[section];
      if (restored == null) {
        _selectedIndex = defaultTabOf(section);
      } else {
        // Edge-Case (a): Inbox-Tab im Memory, aber Plan ohne Postfach →
        // Fallback auf defaultTabOf (wird im build-Körper ggf. noch einmal
        // durch den Downgrade-Guard korrigiert).
        _selectedIndex = restored;
      }
    });
  }

  /// Baut das Bottom-Nav-Icon einer Sektion inkl. aggregiertem Tracking-Badge
  /// auf dem Verkauf-Slot. Wird von [AdaptiveNavScaffold] über den
  /// `bottomIconBuilder` aufgerufen.
  Widget _bottomNavIcon(
      MainSection section, bool selected, int trackingBadgeCount) {
    final (outlined, filled) = _sectionIcons[section]!;
    final icon = Icon(selected ? filled : outlined);
    // Aggregierter Tracking-Badge sitzt auf dem Verkauf-Slot.
    final badgeCount =
        section == MainSection.verkauf ? trackingBadgeCount : 0;
    if (badgeCount <= 0) return icon;
    return Badge(
      label: Text(
        '$badgeCount',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
      backgroundColor: AppTheme.warning,
      child: icon,
    );
  }

  /// Dispatcht den aktiven [MainTab] auf den passenden Body. Sektions-
  /// Wrapper (Verkauf/Auswertung) bündeln ihre Sub-Tabs intern; die
  /// Deep-Link-Ziele inventory/suppliers/help bleiben direkt erreichbar.
  Widget _buildBody(bool inboxEnabled, int trackingBadgeCount) {
    return switch (_selectedIndex) {
      MainTab.dashboard => const DashboardScreen(),
      MainTab.deals || MainTab.tickets || MainTab.inbox => SalesSectionScreen(
          activeTab: _selectedIndex,
          inboxEnabled: inboxEnabled,
          badgeCount: trackingBadgeCount,
          onSelectSubTab: (t) => setState(() => _selectedIndex = t),
          onOpenTicket: _openTicket,
          selectedTicket: _selectedTicket,
          onGoToDealsReview: _goToDealsReview,
        ),
      // Deep-Link-Ziele (global_search / dashboard) — eigene Vollbild-Bodies.
      MainTab.inventory => const InventoryScreen(),
      MainTab.suppliers => const SuppliersScreen(),
      MainTab.warehouse => const WarehouseHubScreen(),
      MainTab.stats || MainTab.activity => AnalyticsSectionScreen(
          activeTab: _selectedIndex,
          onSelectSubTab: (t) => setState(() => _selectedIndex = t),
        ),
      MainTab.settings => const SettingsScreen(embedded: true),
      MainTab.help => const HelpScreen(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer2<InventoryProvider, BillingProvider>(
      builder: (context, provider, billing, _) {
        // T3.2/T3.3: Der Shell-Switch (narrow/extended via Breakpoints) +
        // das Layout-Gerüst (Phone-Scaffold mit AppBar+BottomNav,
        // Desktop-Row[Rail, Column[Header, Body]]) leben jetzt in
        // [AdaptiveNavScaffold]. main_screen liest nur Provider, berechnet
        // die narrow-unabhängigen Werte (Visibility/Badge/Body/Titel/FAB)
        // und füttert die Shell mit Buildern/Callbacks. `narrow` braucht
        // main_screen nur noch für die Inventory-FAB-Bedingung unten.
        final width = MediaQuery.of(context).size.width;
        final narrow = width < Breakpoints.navRail;
        final visibility = _navVisibility(billing);
        final inboxEnabled = visibility[MainTab.inbox] != false;

        // T3.6 — Sektions-Memory aufzeichnen: idempotent, KEIN setState,
        // kein Rebuild-Trigger. Fängt alle Pfade ab, über die _selectedIndex
        // gesetzt wird (Bottom-Nav, Rail, Deep-Link, _openTicket, Help-Icon,
        // GlobalSearch selectTab).
        // ignore: invalid_use_of_protected_member
        _lastTabPerSection[sectionOf(_selectedIndex)] = _selectedIndex;

        // T3.6 Edge-Case (a): Inbox-Tab im Memory, aber Plan ohne Postfach
        // → beim nächsten Betreten der Sektion schlägt der Memory keinen
        //   disabled Tab vor.
        if (!inboxEnabled) {
          _lastTabPerSection.remove(MainSection.verkauf);
        }

        // Wenn der User auf einen Plan ohne Postfach downgradet, während
        // er den Inbox-Tab offen hat, automatisch zurück aufs Dashboard.
        if (_selectedIndex == MainTab.inbox && !inboxEnabled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = MainTab.dashboard);
          });
        }

        // Aggregierter Tracking-Needs-Review-Count: sitzt auf dem Verkauf-
        // Slot (Bottom-Nav + Rail) sowie auf dem Inbox-Segment der
        // Verkauf-Sektion.
        final trackingBadgeCount = provider.trackingNeedsReviewCount;

        final body = _buildBody(inboxEnabled, trackingBadgeCount);

        // Sektions-Label für AppBar/Header; Sub-Tab-Label für Breadcrumb.
        final currentSection = sectionOf(_selectedIndex);
        final sectionTitle = _sectionLabel(l10n, currentSection);
        final subTabTitle = _subTabLabel(l10n, _selectedIndex);

        // G2: FAB covers deals, tickets AND inventory (phone-reachability).
        // Suppliers has its own FAB in suppliers_screen.dart.
        final Widget? fab;
        if (_selectedIndex == MainTab.deals ||
            _selectedIndex == MainTab.tickets) {
          fab = FloatingActionButton.extended(
            // D4: tooltip → explicit Semantics-Label for screen readers
            // and desktop long-press. NavigationBar items do NOT need
            // additional Semantics wrapping — M3 NavigationBar already
            // emits Semantics(role: tab, selected: …) per destination
            // (Flutter SDK navigation_bar.dart lines 304-306).
            tooltip: l10n.dealNew,
            onPressed: () => showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AddEditDealDialog(
                initialTicketNumber:
                    _selectedIndex == MainTab.tickets ? _selectedTicket : null,
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.dealNew),
          );
        } else if (narrow && _selectedIndex == MainTab.inventory) {
          // G2: On phone only — inventory header button scrolls out of view.
          // Desktop keeps the ElevatedButton in the header row.
          fab = FloatingActionButton.extended(
            tooltip: l10n.inventoryAddItem,
            onPressed: () => InventoryScreen.showAddDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.inventoryAddItem),
          );
        } else if (_selectedIndex == MainTab.warehouse) {
          // T3.7: Lager-Hub — Quick-Actions-Sheet-FAB.
          fab = FloatingActionButton(
            key: const Key('lagerQuickActionsFab'),
            tooltip: l10n.quickActionsTooltip,
            onPressed: () => _showLagerQuickActions(context, provider),
            child: const Icon(Icons.add),
          );
        } else {
          fab = null;
        }

        // Shell-Layout-Gerüst (Phone-Scaffold mit AppBar+BottomNav,
        // Desktop-Row[Rail, Column[Header, Body]]) ist in [AdaptiveNavScaffold]
        // gekapselt. Hier nur Config + Builder/Callbacks — die Icon-/Badge-/
        // Section-Logik bleibt in main_screen.
        final scaffold = AdaptiveNavScaffold(
          sections: MainSection.values,
          selectedSection: currentSection,
          onSelectSection: _selectSection,
          sectionLabelBuilder: (section) => _sectionLabel(l10n, section),
          sectionIconBuilder: (section, selected) {
            final (outlined, filled) = _sectionIcons[section]!;
            return Icon(selected ? filled : outlined);
          },
          bottomIconBuilder: (section, selected) =>
              _bottomNavIcon(section, selected, trackingBadgeCount),
          railBadgeBuilder: (section) {
            // Aggregierter Tracking-Badge auf der Verkauf-Sektion.
            if (section != MainSection.verkauf || trackingBadgeCount <= 0) {
              return null;
            }
            // Minimal Marker — wird von AppNavRail via Stack/Positioned über
            // das Icon gelegt.
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.warning,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$trackingBadgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
          sectionTitle: sectionTitle,
          subTabTitle: subTabTitle,
          provider: provider,
          body: body,
          floatingActionButton: fab,
          onSearch: _openSearch,
          onHelp: () => setState(() => _selectedIndex = MainTab.help),
          onImport: () => _import(context, provider),
          onExport: () =>
              _export(context, provider, context.read<CatalogProvider>()),
        );

        // T1.2 — Keyboard shortcuts (Desktop/Web only, additiv).
        // Cmd/Ctrl+1..5 → Sektionen (reorder-robust via MainSection +
        // defaultTabOf). Slash → Suche/Palette öffnen.
        // n → kontextuelles „Neu" (FAB-Aktion des aktiven Tabs).
        void goSection(MainSection s) => _selectSection(s);
        final tabShortcuts = <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
              () => goSection(MainSection.dashboard),
          const SingleActivator(LogicalKeyboardKey.digit1, control: true):
              () => goSection(MainSection.dashboard),
          const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
              () => goSection(MainSection.verkauf),
          const SingleActivator(LogicalKeyboardKey.digit2, control: true):
              () => goSection(MainSection.verkauf),
          const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
              () => goSection(MainSection.lager),
          const SingleActivator(LogicalKeyboardKey.digit3, control: true):
              () => goSection(MainSection.lager),
          const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
              () => goSection(MainSection.auswertung),
          const SingleActivator(LogicalKeyboardKey.digit4, control: true):
              () => goSection(MainSection.auswertung),
          const SingleActivator(LogicalKeyboardKey.digit5, meta: true):
              () => goSection(MainSection.konto),
          const SingleActivator(LogicalKeyboardKey.digit5, control: true):
              () => goSection(MainSection.konto),
          const SingleActivator(LogicalKeyboardKey.slash): _openSearch,
          const SingleActivator(LogicalKeyboardKey.keyN): _contextualNew,
        };
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _openSearch,
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _openSearch,
            ...tabShortcuts,
          },
          child: Focus(autofocus: true, child: scaffold),
        );
      },
    );
  }
}
