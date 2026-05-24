import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../models/pricing_plan.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/csv_service.dart';
import '../widgets/add_edit_deal_dialog.dart';
import '../widgets/app_nav_rail.dart';
import '../widgets/global_search_dialog.dart';
import '../widgets/invites_bell.dart';
import 'activity_screen.dart';
import 'dashboard_screen.dart';
import 'deals_screen.dart';
import 'help_screen.dart';
import 'inbox_screen.dart';
import 'inventory_screen.dart';
import 'pricing_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'suppliers_screen.dart';
import 'main_tab.dart';
import 'tickets_screen.dart';
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

  static const _navIcons = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded),
    (Icons.list_alt_outlined, Icons.list_alt_rounded),
    (Icons.confirmation_number_outlined, Icons.confirmation_number_rounded),
    (Icons.mail_outlined, Icons.mail_rounded),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    (Icons.local_shipping_outlined, Icons.local_shipping),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    (Icons.history_outlined, Icons.history_rounded),
    (Icons.settings_outlined, Icons.settings_rounded),  // MainTab.settings (8)
    (Icons.help_outline_rounded, Icons.help_rounded),   // MainTab.help (9)
    (Icons.storefront_outlined, Icons.storefront),       // MainTab.warehouse (10) — AF11
  ];

  List<String> _navLabels(AppLocalizations l10n) => [
        l10n.navDashboard,
        l10n.navDeals,
        l10n.navTickets,
        l10n.navInbox,
        l10n.navInventory,
        l10n.navSuppliers,
        l10n.navStatistics,
        l10n.navActivity,
        l10n.navSettings,   // MainTab.settings (8)
        l10n.navHelp,       // MainTab.help (9)
        l10n.navWarehouse,  // MainTab.warehouse (10) — AF11
      ];

  Future<void> _export(BuildContext context, InventoryProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final (path, err) = await CsvService.exportAll(
      List.from(provider.deals),
      List.from(provider.shops),
      List.from(provider.buyers),
      List.from(provider.inventoryItems),
      suppliers: List.from(provider.suppliers),
      categories: List.from(provider.productCategories),
      products: List.from(provider.products),
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

  void _select(MainTab tab) {
    setState(() => _selectedIndex = tab);
    Navigator.maybePop(context);
  }

  void _openTicket(String ticket) {
    setState(() {
      _selectedTicket = ticket;
      _selectedIndex = MainTab.tickets;
    });
  }

  void _openSearch() {
    GlobalSearchDialog.show(
      context,
      selectTab: (tab) => setState(() => _selectedIndex = tab),
      openTicket: _openTicket,
    );
  }

  void _goToDealsReview() {
    context.read<FilterProvider>().setOnlyNeedsReview(true);
    setState(() => _selectedIndex = MainTab.deals);
  }

  // ── Bottom-Nav helpers (Phone only, width < 800) ─────────────────────────

  /// The 5 (or 4 if Inbox-hidden) tabs shown in the NavigationBar.
  List<MainTab> _bottomNavTabs(Map<MainTab, bool> visibility) {
    const baseOrder = [
      MainTab.dashboard,
      MainTab.deals,
      MainTab.tickets,
      MainTab.inbox,
      MainTab.inventory,
    ];
    return baseOrder.where((t) => visibility[t] != false).toList();
  }

  /// Index inside the NavigationBar for the currently selected tab.
  /// Returns the "Mehr"-slot index when the active tab is not in the bar.
  int _bottomNavSelectedIndex(Map<MainTab, bool> visibility) {
    final tabs = _bottomNavTabs(visibility);
    final i = tabs.indexOf(_selectedIndex);
    return i >= 0 ? i : tabs.length; // "Mehr"-slot is the last entry
  }

  void _bottomNavOnTap(
      int i, Map<MainTab, bool> visibility, BuildContext context) {
    final tabs = _bottomNavTabs(visibility);
    if (i < tabs.length) {
      setState(() => _selectedIndex = tabs[i]);
    } else {
      _openMoreSheet(context, visibility);
    }
  }

  List<NavigationDestination> _bottomNavDestinations(
    AppLocalizations l10n,
    List<String> labels,
    Map<MainTab, bool> visibility,
    Map<MainTab, int> navBadgeCounts,
  ) {
    final tabs = _bottomNavTabs(visibility);
    return [
      for (final tab in tabs)
        NavigationDestination(
          key: Key('main-tab-${tab.name}'),
          icon: Badge(
            isLabelVisible: (navBadgeCounts[tab] ?? 0) > 0,
            label: Text(
              '${navBadgeCounts[tab] ?? 0}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppTheme.warning,
            child: Icon(_navIcons[tab.index].$1),
          ),
          selectedIcon: Badge(
            isLabelVisible: (navBadgeCounts[tab] ?? 0) > 0,
            label: Text(
              '${navBadgeCounts[tab] ?? 0}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppTheme.warning,
            child: Icon(_navIcons[tab.index].$2),
          ),
          label: labels[tab.index],
        ),
      NavigationDestination(
        key: const Key('main-tab-more'),
        icon: const Icon(Icons.more_horiz),
        label: l10n.navMore,
      ),
    ];
  }

  Future<void> _openMoreSheet(
      BuildContext context, Map<MainTab, bool> visibility) async {
    final l10n = AppLocalizations.of(context);
    final labels = _navLabels(l10n);
    // Tabs already in the bottom-nav — exclude them from the sheet.
    final bottomTabs = _bottomNavTabs(visibility);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.navBg,
      isScrollControlled: true,
      builder: (sheetCtx) => _MoreNavSheet(
        key: const Key('moreNavSheet'),
        icons: _navIcons,
        labels: labels,
        visibility: visibility,
        excludeTabs: bottomTabs,
        onSelect: (tab) {
          Navigator.pop(sheetCtx);
          setState(() => _selectedIndex = tab);
        },
        onSearch: () {
          Navigator.pop(sheetCtx);
          _openSearch();
        },
        badgeCounts: const {},
        sheetTitle: l10n.navMoreSheetTitle,
      ),
    );
  }

  Widget _buildBody() {
    return switch (_selectedIndex) {
      MainTab.dashboard => const DashboardScreen(),
      MainTab.deals => DealsScreen(onOpenTicket: _openTicket),
      MainTab.tickets => TicketsScreen(initialTicket: _selectedTicket),
      MainTab.inbox => InboxScreen(
          onOpenTicket: _openTicket,
          onGoToDealsReview: _goToDealsReview,
        ),
      MainTab.inventory => const InventoryScreen(),
      MainTab.suppliers => const SuppliersScreen(),
      MainTab.stats => const StatisticsScreen(),
      MainTab.activity => const ActivityScreen(),
      MainTab.settings => const SettingsScreen(embedded: true),
      MainTab.help => const HelpScreen(embedded: true),
      MainTab.warehouse => const WarehouseHubScreen(), // AF11
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = _navLabels(l10n);
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
        // Wenn der User auf einen Plan ohne Postfach downgradet, während
        // er den Inbox-Tab offen hat, automatisch zurück aufs Dashboard.
        if (_selectedIndex == MainTab.inbox &&
            visibility[MainTab.inbox] == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = MainTab.dashboard);
          });
        }
        final body = _buildBody();

        // Counter badge on the Inbox tab: show tracking needs-review count.
        final trackingBadgeCount = provider.trackingNeedsReviewCount;
        final navBadgeCounts = trackingBadgeCount > 0
            ? {MainTab.inbox: trackingBadgeCount}
            : const <MainTab, int>{};

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
                  title: Text(labels[_selectedIndex.index]),
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
                  ],
                ),
                floatingActionButton: fab,
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.endFloat,
                bottomNavigationBar: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    // Enforce single-line labels — prevents "Dashboar/d"
                    // wrap on narrow Phone viewports (360-390 dp wide).
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => const TextStyle(
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis,
                        // height: 1 clamps the line-height so Flutter
                        // does not allocate a second line even when the
                        // label barely fits.
                        height: 1,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    key: const Key('mainBottomNav'),
                    selectedIndex:
                        _bottomNavSelectedIndex(visibility),
                    onDestinationSelected: (i) =>
                        _bottomNavOnTap(i, visibility, context),
                    destinations: _bottomNavDestinations(
                        l10n, labels, visibility, navBadgeCounts),
                  ),
                ),
                body: body,
              )
            : Scaffold(
                floatingActionButton: fab,
                body: Row(
                  children: [
                    AppNavRail(
                      tabs: MainTab.values,
                      visibility: visibility,
                      selectedTab: _selectedIndex,
                      onSelect: _select,
                      extended: extended,
                      iconBuilder: (tab, selected) {
                        final (outlined, filled) = _navIcons[tab.index];
                        return Icon(selected ? filled : outlined);
                      },
                      labelBuilder: (tab) => labels[tab.index],
                      badgeBuilder: (tab) {
                        final count = navBadgeCounts[tab] ?? 0;
                        if (count <= 0) return null;
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
                            '$count',
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
                            title: labels[_selectedIndex.index],
                            provider: provider,
                            onImport: () => _import(context, provider),
                            onExport: () => _export(context, provider),
                            onSearch: _openSearch,
                          ),
                          Expanded(child: body),
                        ],
                      ),
                    ),
                  ],
                ),
              );

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _openSearch,
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _openSearch,
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
  final InventoryProvider provider;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onSearch;

  const _ContentHeader({
    required this.title,
    required this.provider,
    required this.onImport,
    required this.onExport,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
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

// ─── More-Nav Bottom Sheet ─────────────────────────────────────────────────────
// Shown when the user taps the "Mehr" slot in the Phone NavigationBar.
// Renders every tab that is NOT already shown in the bottom-nav
// (Suppliers, Stats, Activity, Settings, Help by default).
//
// G1 polish (2026-05-24):
//  • Drag-handle (4×40 dp) for sheet affordance.
//  • Quick-search TextField filters items by label substring.
//  • Section headers group tabs thematically.
//  • Chevron trailing on each item.
//  • SafeArea + MediaQuery.viewInsetsOf for keyboard awareness.

// Section assignment — determines which header a tab falls under.
_MoreNavSection _tabSection(MainTab tab) => switch (tab) {
      MainTab.inventory ||
      MainTab.suppliers ||
      MainTab.warehouse =>
        _MoreNavSection.manage,
      MainTab.stats || MainTab.activity => _MoreNavSection.tools,
      MainTab.settings || MainTab.help => _MoreNavSection.account,
      // dashboard/deals/tickets/inbox are typically pinned in bottom-nav
      // and won't show here, but fall back gracefully.
      _ => _MoreNavSection.manage,
    };

enum _MoreNavSection { manage, tools, account }

class _MoreNavSheet extends StatefulWidget {
  final List<(IconData, IconData)> icons;
  final List<String> labels;
  final Map<MainTab, bool> visibility;

  /// Tabs already present in the bottom-nav — excluded from this sheet.
  final List<MainTab> excludeTabs;
  final ValueChanged<MainTab> onSelect;

  /// Called when the user taps the search tile — sheet pops then global
  /// search opens (handled by the caller so context is correct).
  final VoidCallback onSearch;
  final Map<MainTab, int> badgeCounts;
  final String sheetTitle;

  const _MoreNavSheet({
    super.key,
    required this.icons,
    required this.labels,
    required this.visibility,
    required this.excludeTabs,
    required this.onSelect,
    required this.onSearch,
    required this.sheetTitle,
    this.badgeCounts = const {},
  });

  @override
  State<_MoreNavSheet> createState() => _MoreNavSheetState();
}

class _MoreNavSheetState extends State<_MoreNavSheet> {
  String _query = '';

  List<MainTab> get _allSheetTabs => MainTab.values
      .where((t) =>
          widget.visibility[t] != false &&
          !widget.excludeTabs.contains(t))
      .toList();

  List<MainTab> _filtered(List<MainTab> tabs) {
    if (_query.isEmpty) return tabs;
    final q = _query.toLowerCase();
    return tabs
        .where((t) => widget.labels[t.index].toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allTabs = _allSheetTabs;
    final filtered = _filtered(allTabs);

    // Group filtered tabs by section — only render a section header if
    // at least one tab in that section survived the filter.
    final Map<_MoreNavSection, List<MainTab>> sections = {};
    for (final tab in filtered) {
      sections.putIfAbsent(_tabSection(tab), () => []).add(tab);
    }

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  // navBg is always dark — white/60 is appropriate here.
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Sheet title ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Text(
                widget.sheetTitle,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // ── Quick search field ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('moreNavSheet-searchField'),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: l10n.navMoreSearchHint,
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(100),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withAlpha(140),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(18),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withAlpha(80)),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Container(height: 1, color: Colors.white.withAlpha(20)),
            // ── Sectioned nav items ────────────────────────────────────
            if (filtered.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Text(
                  l10n.navMoreSearchNoResults,
                  style: TextStyle(
                    color: Colors.white.withAlpha(100),
                    fontSize: 14,
                  ),
                ),
              )
            else
              for (final section in _MoreNavSection.values)
                if (sections[section] != null) ...[
                  _MoreNavSectionHeader(
                    label: switch (section) {
                      _MoreNavSection.manage => l10n.navMoreSectionManage,
                      _MoreNavSection.tools => l10n.navMoreSectionTools,
                      _MoreNavSection.account => l10n.navMoreSectionAccount,
                    },
                  ),
                  for (final tab in sections[section]!)
                    _MoreNavSheetItem(
                      key: Key('moreNavSheet-${tab.name}'),
                      icon: widget.icons[tab.index].$1,
                      label: widget.labels[tab.index],
                      badgeCount: widget.badgeCounts[tab] ?? 0,
                      onTap: () => widget.onSelect(tab),
                    ),
                ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MoreNavSectionHeader extends StatelessWidget {
  final String label;
  const _MoreNavSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withAlpha(100),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MoreNavSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _MoreNavSheetItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        // min 48 dp touch target: 14+20 = 34 inner height → icon 20 dp →
        // vertical padding 14 dp each side = 48 dp total.
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(
                '$badgeCount',
                style:
                    const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppTheme.warning,
              child: Icon(icon, size: 20, color: AppTheme.navIcon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_outlined,
              size: 18,
              color: Colors.white.withAlpha(80),
            ),
          ],
        ),
      ),
    );
  }
}
