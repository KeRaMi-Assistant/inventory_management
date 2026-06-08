import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../models/pricing_plan.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/csv_service.dart';
import '../widgets/add_edit_deal_dialog.dart';
import '../widgets/app_nav_rail.dart';
import '../widgets/global_search_dialog.dart';
import '../widgets/invites_bell.dart';
import 'analytics_section_screen.dart';
import 'dashboard_screen.dart';
import 'help_screen.dart';
import 'inventory_screen.dart';
import 'pricing_screen.dart';
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
    final (path, err) = await CsvService.exportAll(
      List.from(provider.deals),
      List.from(provider.shops),
      List.from(provider.buyers),
      List.from(provider.inventoryItems),
      suppliers: List.from(provider.suppliers),
      categories: List.from(catalog.productCategories),
      products: List.from(catalog.products),
      warehouses: List.from(provider.warehouses),
      purchaseOrders: List.from(provider.purchaseOrders),
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
  void _selectSection(MainSection section) {
    if (sectionOf(_selectedIndex) == section) return;
    setState(() => _selectedIndex = defaultTabOf(section));
  }

  /// Baut die 5 Sektions-Destinations für die Phone-NavigationBar.
  /// Der Verkauf-Slot trägt den aggregierten Tracking-Badge.
  List<NavigationDestination> _bottomNavDestinations(
    AppLocalizations l10n,
    int trackingBadgeCount,
  ) {
    return [
      for (final section in MainSection.values)
        NavigationDestination(
          key: Key('main-tab-${section.name}'),
          icon: _bottomNavIcon(section, false, trackingBadgeCount),
          selectedIcon: _bottomNavIcon(section, true, trackingBadgeCount),
          label: _sectionLabel(l10n, section),
        ),
    ];
  }

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
        // T1.3b (Phase B): Shell-Switch-Schwellen aktiv geändert.
        // - narrow:   800 → 900 (Breakpoints.navRail).
        //   Verhalten: Viewports 800–899 px wechseln von Desktop-Sidebar auf
        //   Phone-Bottom-Nav. M3-Window-Size-Class "Expanded" beginnt bei 840;
        //   wir wählen 900 (vgl. Plan §5.1).
        // - extended: 1100 → 1200 (Breakpoints.railExtended).
        //   Verhalten: Viewports 1100–1199 px zeigen die Rail künftig kompakt
        //   (Icons only) statt expanded (Labels). Entspricht M3 Large-Beginn.
        final width = MediaQuery.of(context).size.width;
        final narrow = width < Breakpoints.navRail;
        final extended = width >= Breakpoints.railExtended;
        final visibility = _navVisibility(billing);
        final inboxEnabled = visibility[MainTab.inbox] != false;
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
        } else {
          fab = null;
        }

        final scaffold = narrow
            ? Scaffold(
                appBar: AppBar(
                  title: Text(sectionTitle),
                  actions: [
                    const InvitesBell(),
                    IconButton(
                      tooltip: l10n.actionSearch,
                      icon: const Icon(Icons.search),
                      onPressed: _openSearch,
                    ),
                    IconButton(
                      key: const Key('appBar-help-action'),
                      tooltip: l10n.actionHelp,
                      icon: const Icon(Icons.help_outlined),
                      onPressed: () =>
                          setState(() => _selectedIndex = MainTab.help),
                    ),
                    // T1.7 — CSV import/export on phone via overflow menu.
                    PopupMenuButton<_PhoneMenuAction>(
                      key: const Key('appBar-overflow-menu'),
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) {
                        switch (action) {
                          case _PhoneMenuAction.csvImport:
                            _import(context, provider);
                          case _PhoneMenuAction.csvExport:
                            _export(
                              context,
                              provider,
                              context.read<CatalogProvider>(),
                            );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _PhoneMenuAction.csvImport,
                          child: Row(
                            children: [
                              Icon(Icons.upload_file_outlined,
                                  size: 18,
                                  color: AppTheme.textMutedOf(context)),
                              const SizedBox(width: 12),
                              Text(l10n.appBarMenuCsvImport),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _PhoneMenuAction.csvExport,
                          child: Row(
                            children: [
                              Icon(Icons.download_outlined,
                                  size: 18,
                                  color: AppTheme.textMutedOf(context)),
                              const SizedBox(width: 12),
                              Text(l10n.appBarMenuCsvExport),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                floatingActionButton: fab,
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.endFloat,
                bottomNavigationBar: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    // Enforce single-line labels — 5 Sektions-Slots auf
                    // 360 dp dürfen nicht wrappen/überlaufen. fontSize 11
                    // + ellipsis + height:1 halten jedes Label einzeilig.
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => const TextStyle(
                        fontSize: 11,
                        overflow: TextOverflow.ellipsis,
                        height: 1,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    key: const Key('mainBottomNav'),
                    selectedIndex: sectionOf(_selectedIndex).index,
                    onDestinationSelected: (i) =>
                        _selectSection(MainSection.values[i]),
                    destinations:
                        _bottomNavDestinations(l10n, trackingBadgeCount),
                  ),
                ),
                body: body,
              )
            : Scaffold(
                floatingActionButton: fab,
                body: Row(
                  children: [
                    AppNavRail(
                      sections: MainSection.values,
                      selectedSection: currentSection,
                      onSelect: _selectSection,
                      extended: extended,
                      iconBuilder: (section, selected) {
                        final (outlined, filled) = _sectionIcons[section]!;
                        return Icon(selected ? filled : outlined);
                      },
                      labelBuilder: (section) =>
                          _sectionLabel(l10n, section),
                      badgeBuilder: (section) {
                        // Aggregierter Tracking-Badge auf der Verkauf-Sektion.
                        if (section != MainSection.verkauf ||
                            trackingBadgeCount <= 0) {
                          return null;
                        }
                        // Minimal Marker — wird von AppNavRail via
                        // Stack/Positioned über das Icon gelegt.
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
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
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ContentHeader(
                            title: sectionTitle,
                            subTabTitle: subTabTitle,
                            provider: provider,
                            onImport: () => _import(context, provider),
                            onExport: () => _export(
                              context,
                              provider,
                              context.read<CatalogProvider>(),
                            ),
                            onSearch: _openSearch,
                          ),
                          Expanded(child: body),
                        ],
                      ),
                    ),
                  ],
                ),
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

// ─── Desktop Content Header ────────────────────────────────────────────────────

class _ContentHeader extends StatelessWidget {
  final String title;

  /// Sub-Tab innerhalb der Sektion (Deals/Tickets, Statistik/Aktivität,
  /// Bestand/Lieferanten als Deep-Link). `null` ⇒ Sektion hat nur ein Ziel.
  final String? subTabTitle;
  final InventoryProvider provider;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onSearch;

  const _ContentHeader({
    required this.title,
    required this.subTabTitle,
    required this.provider,
    required this.onImport,
    required this.onExport,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // T1.6 — Breadcrumb row (thin, 28 dp): App › Sektion [› Sub-Tab]
        _BreadcrumbRow(title: title, subTabTitle: subTabTitle),
        // Main header row (56 dp)
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.bgSurfaceOf(context),
            border:
                Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              const Spacer(),
              _SearchHint(onTap: onSearch),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.headerImportCsv,
                icon: Icon(Icons.upload_file_outlined,
                    size: 18, color: AppTheme.textMutedOf(context)),
                onPressed: onImport,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.headerExportCsv,
                icon: Icon(Icons.download_outlined,
                    size: 18, color: AppTheme.textMutedOf(context)),
                onPressed: onExport,
              ),
              const SizedBox(width: 8),
              const InvitesBell(),
              const SizedBox(width: 4),
              const _AccountMenu(),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }
}

// T1.6 — Thin breadcrumb bar shown above the desktop content header.
// Shows `App › Sektion [› Sub-Tab]` so der User immer einen Pfad-Indikator
// hat — minimal, theme-token-only. Tier-2b: zeigt zusätzlich den Sub-Tab,
// wenn die aktive Sektion mehrere Sub-Ziele hat (Verkauf/Auswertung/
// Lager-Deep-Links).
class _BreadcrumbRow extends StatelessWidget {
  final String title;
  final String? subTabTitle;
  const _BreadcrumbRow({required this.title, required this.subTabTitle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget separator() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.chevron_right,
            size: 14,
            color: AppTheme.textMutedOf(context),
          ),
        );
    return Container(
      height: 28,
      color: AppTheme.bgSubtleOf(context),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Tooltip(
        message: l10n.breadcrumbSeparatorTooltip,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 12,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {}, // Root — no-op (could navigate to dashboard)
              child: Text(
                l10n.appTitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ),
            separator(),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    subTabTitle == null ? FontWeight.w600 : FontWeight.w400,
                color: subTabTitle == null
                    ? AppTheme.textSecondaryOf(context)
                    : AppTheme.textMutedOf(context),
              ),
            ),
            if (subTabTitle != null) ...[
              separator(),
              Flexible(
                child: Text(
                  subTabTitle!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMac = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.iOS;
    return Tooltip(
      message: l10n.actionSearch,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.bgSubtleOf(context),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 14, color: AppTheme.textMutedOf(context)),
              const SizedBox(width: 6),
              Text(
                l10n.actionSearch,
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurfaceOf(context),
                  border: Border.all(color: AppTheme.borderOf(context)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isMac ? '⌘K' : 'Ctrl+K',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Account Menu ──────────────────────────────────────────────────────────────

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final workspaces = context.watch<ActiveWorkspaceProvider>();
    final billing = context.watch<BillingProvider>();
    final email = auth.userEmail ?? l10n.commonUnknown;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final plan = billing.currentPlan;

    return PopupMenuButton<String>(
      tooltip: email,
      offset: const Offset(0, 40),
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: AppTheme.accent,
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.accountMenuSignedInAs,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textMutedOf(context))),
              const SizedBox(height: 2),
              Text(email,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'plan',
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 16, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan == BillingPlan.free
                          ? l10n.planMenuSelect
                          : l10n.planMenuManage,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.planMenuCurrent(plan.label),
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMutedOf(context)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: plan == BillingPlan.free
                      ? AppTheme.accent.withAlpha(30)
                      : Colors.green.withAlpha(40),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plan == BillingPlan.free
                      ? l10n.planMenuUpgradeBadge
                      : plan.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: plan == BillingPlan.free
                        ? AppTheme.accent
                        : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (workspaces.workspaces.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              l10n.accountMenuActiveWorkspace,
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedOf(context)),
            ),
          ),
          for (final ws in workspaces.workspaces)
            PopupMenuItem<String>(
              value: 'ws:${ws.id}',
              child: Row(
                children: [
                  Icon(
                    workspaces.active?.id == ws.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: workspaces.active?.id == ws.id
                        ? AppTheme.accent
                        : AppTheme.textMutedOf(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ws.displayLabel(auth.currentUser?.id),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: workspaces.active?.id == ws.id
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 16, color: AppTheme.danger),
              const SizedBox(width: 10),
              Text(l10n.accountMenuSignOut),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_forever_outlined,
                  size: 16, color: Color(0xFFC0392B)),
              const SizedBox(width: 10),
              Text(l10n.accountMenuDeleteAccount,
                  style: const TextStyle(color: Color(0xFFC0392B))),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        final auth = context.read<AuthProvider>();
        final activeWs = context.read<ActiveWorkspaceProvider>();
        final navigator = Navigator.of(context);
        final l10n = AppLocalizations.of(context);
        if (value == 'plan') {
          await navigator.push(
            MaterialPageRoute(builder: (_) => const PricingScreen()),
          );
          return;
        }
        if (value.startsWith('ws:')) {
          final id = value.substring(3);
          final ws =
              activeWs.workspaces.where((w) => w.id == id).firstOrNull;
          final uid = auth.currentUser?.id;
          if (ws != null && uid != null) {
            await activeWs.setActive(ws, uid);
          }
          return;
        }
        if (value == 'logout') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.logoutConfirmTitle),
              content: Text(l10n.logoutConfirmText),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.actionCancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.accountMenuSignOut),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await auth.signOut();
          }
        } else if (value == 'delete') {
          final confirmCtrl = TextEditingController();
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setS) => AlertDialog(
                title: Text(l10n.deleteAccountTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.deleteAccountText),
                    const SizedBox(height: 16),
                    Text(
                      l10n.deleteAccountConfirmInstruction,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmCtrl,
                      autofocus: true,
                      onChanged: (_) => setS(() {}),
                      decoration: InputDecoration(
                        hintText: l10n.deleteAccountConfirmKeyword,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.actionCancel),
                  ),
                  ElevatedButton(
                    onPressed: confirmCtrl.text.trim() ==
                            l10n.deleteAccountConfirmKeyword
                        ? () => Navigator.pop(ctx, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0392B)),
                    child: Text(l10n.accountMenuDeleteAccount),
                  ),
                ],
              ),
            ),
          );
          confirmCtrl.dispose();
          if (confirmed == true && context.mounted) {
            final error = await auth.deleteAccount();
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: const Color(0xFFC0392B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      },
    );
  }
}

/// T1.7 — Actions available in the phone AppBar overflow menu.
enum _PhoneMenuAction { csvImport, csvExport }
