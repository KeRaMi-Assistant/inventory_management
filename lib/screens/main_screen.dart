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
import '../providers/inventory_provider.dart';
import '../services/csv_service.dart';
import '../widgets/add_edit_deal_dialog.dart';
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
import 'tickets_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _selectedTicket;

  static const _navIcons = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded),
    (Icons.list_alt_outlined, Icons.list_alt_rounded),
    (Icons.confirmation_number_outlined, Icons.confirmation_number_rounded),
    (Icons.mail_outline, Icons.mail_rounded),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    (Icons.local_shipping_outlined, Icons.local_shipping),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    (Icons.history_outlined, Icons.history_rounded),
    (Icons.help_outline_rounded, Icons.help_rounded),
    (Icons.settings_outlined, Icons.settings_rounded),
  ];

  List<String> _navLabels(AppLocalizations l10n) => [
        l10n.navDashboard,
        l10n.navDeals,
        l10n.navTickets,
        'Inbox',
        l10n.navInventory,
        l10n.navSuppliers,
        l10n.navStatistics,
        l10n.navActivity,
        l10n.navHelp,
        l10n.navSettings,
      ];

  Future<void> _export(BuildContext context, InventoryProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final (path, err) = await CsvService.exportAll(
      List.from(provider.deals),
      List.from(provider.shops),
      List.from(provider.buyers),
      List.from(provider.inventoryItems),
      suppliers: List.from(provider.suppliers),
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
    final (result, err) = await CsvService.importAll(provider.nextDealId);
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

  /// Index 3 (Inbox) ist nur ab `hasInbox` (Starter+) sichtbar. Reihenfolge
  /// im sonstigen Nav bleibt stabil, damit andere Screens (GlobalSearch,
  /// _openTicket, _openSearch) ihre Indizes nicht neu lernen müssen.
  static const int _inboxNavIndex = 3;

  List<bool> _navVisibility(BillingProvider billing) {
    final hasInbox =
        PricingPlan.forBillingPlan(billing.currentPlan).hasInbox;
    return [
      true, // 0 dashboard
      true, // 1 deals
      true, // 2 tickets
      hasInbox, // 3 inbox
      true, // 4 inventory
      true, // 5 suppliers
      true, // 6 statistics
      true, // 7 activity
      true, // 8 help
      true, // 9 settings
    ];
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
    Navigator.maybePop(context);
  }

  void _openTicket(String ticket) {
    setState(() {
      _selectedTicket = ticket;
      _selectedIndex = 2;
    });
  }

  void _openSearch() {
    GlobalSearchDialog.show(
      context,
      selectTab: (i) => setState(() => _selectedIndex = i),
      openTicket: _openTicket,
    );
  }

  Widget _buildBody() {
    return switch (_selectedIndex) {
      0 => const DashboardScreen(),
      1 => DealsScreen(onOpenTicket: _openTicket),
      2 => TicketsScreen(initialTicket: _selectedTicket),
      3 => InboxScreen(onOpenTicket: _openTicket),
      4 => const InventoryScreen(),
      5 => const SuppliersScreen(),
      6 => const StatisticsScreen(),
      7 => const ActivityScreen(),
      8 => const HelpScreen(embedded: true),
      _ => const SettingsScreen(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = _navLabels(l10n);
    return Consumer2<InventoryProvider, BillingProvider>(
      builder: (context, provider, billing, _) {
        final width = MediaQuery.of(context).size.width;
        final narrow = width < 800;
        final extended = width >= 1100;
        final visibility = _navVisibility(billing);
        // Wenn der User auf einen Plan ohne Postfach downgradet, während
        // er den Inbox-Tab offen hat, automatisch zurück aufs Dashboard.
        if (_selectedIndex == _inboxNavIndex && !visibility[_inboxNavIndex]) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = 0);
          });
        }
        final body = _buildBody();

        final fab = _selectedIndex == 1 || _selectedIndex == 2
            ? FloatingActionButton.extended(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AddEditDealDialog(
                    initialTicketNumber:
                        _selectedIndex == 2 ? _selectedTicket : null,
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.dealNew),
              )
            : null;

        final scaffold = narrow
            ? Scaffold(
                appBar: AppBar(
                  title: Text(labels[_selectedIndex]),
                  actions: [
                    const InvitesBell(),
                    IconButton(
                      tooltip: l10n.actionSearch,
                      icon: const Icon(Icons.search),
                      onPressed: _openSearch,
                    ),
                  ],
                ),
                drawer: Drawer(
                  backgroundColor: AppTheme.navBg,
                  child: SafeArea(
                    child: _MobileNavList(
                      selectedIndex: _selectedIndex,
                      icons: _navIcons,
                      labels: labels,
                      visibility: visibility,
                      onSelect: _select,
                    ),
                  ),
                ),
                floatingActionButton: fab,
                body: body,
              )
            : Scaffold(
                floatingActionButton: fab,
                body: Row(
                  children: [
                    _Sidebar(
                      selectedIndex: _selectedIndex,
                      icons: _navIcons,
                      labels: labels,
                      visibility: visibility,
                      extended: extended,
                      onSelect: _select,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ContentHeader(
                            title: labels[_selectedIndex],
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

// ─── Custom Sidebar ────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<(IconData, IconData)> icons;
  final List<String> labels;
  /// Pro Index: true = sichtbar, false = ausblenden (z.B. Inbox auf Free).
  final List<bool> visibility;
  final bool extended;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.icons,
    required this.labels,
    required this.visibility,
    required this.extended,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = extended ? 220.0 : 64.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      color: AppTheme.navBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Header
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded,
                      color: Colors.white, size: 18),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    Text(
                      l10n.appTitle,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(height: 1, color: Colors.white.withAlpha(20)),
          const SizedBox(height: 8),
          // Nav items — versteckte Indizes (z.B. Inbox auf Free)
          // werden hier rausgefiltert, der Index-Schlüssel bleibt aber
          // gleich wie im _buildBody-Switch.
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (int i = 0; i < icons.length; i++)
                  if (i >= visibility.length || visibility[i])
                    _NavItem(
                      icon: icons[i].$1,
                      activeIcon: icons[i].$2,
                      label: labels[i],
                      isSelected: selectedIndex == i,
                      extended: extended,
                      onTap: () => onSelect(i),
                    ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withAlpha(20)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool extended;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.extended,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isSelected ? Colors.white : AppTheme.navIcon;
    final labelColor = widget.isSelected ? Colors.white : AppTheme.navLabel;
    final bgColor = widget.isSelected
        ? Colors.white.withAlpha(20)
        : _hovered
            ? Colors.white.withAlpha(13)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.extended ? '' : widget.label,
        preferBelow: false,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                left: BorderSide(
                  color:
                      widget.isSelected ? AppTheme.accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: widget.isSelected ? 61 : 64,
                  child: Center(
                    child: Icon(
                      widget.isSelected ? widget.activeIcon : widget.icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
                if (widget.extended)
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 13,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          _SearchHint(onTap: onSearch),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.headerImportCsv,
            icon: const Icon(Icons.upload_file_outlined,
                size: 18, color: AppTheme.textMuted),
            onPressed: onImport,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.headerExportCsv,
            icon: const Icon(Icons.download_outlined,
                size: 18, color: AppTheme.textMuted),
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
            color: AppTheme.bgSubtle,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                l10n.actionSearch,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isMac ? '⌘K' : 'Ctrl+K',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
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
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 2),
              Text(email,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'plan',
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_outlined,
                  size: 16, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan == BillingPlan.free
                          ? 'Plan auswählen'
                          : 'Plan verwalten',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aktuell: ${plan.label}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
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
                  plan == BillingPlan.free ? 'Upgrade' : plan.label,
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
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textMuted),
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
                        : AppTheme.textMuted,
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

// ─── Mobile Nav List ───────────────────────────────────────────────────────────

class _MobileNavList extends StatelessWidget {
  final int selectedIndex;
  final List<(IconData, IconData)> icons;
  final List<String> labels;
  final List<bool> visibility;
  final ValueChanged<int> onSelect;

  const _MobileNavList({
    required this.selectedIndex,
    required this.icons,
    required this.labels,
    required this.visibility,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final email = auth.userEmail ?? l10n.commonUnknown;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                l10n.appTitle,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: Colors.white.withAlpha(20)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (int i = 0; i < icons.length; i++)
                if (i >= visibility.length || visibility[i])
                  _NavItem(
                    icon: icons[i].$1,
                    activeIcon: icons[i].$2,
                    label: labels[i],
                    isSelected: selectedIndex == i,
                    extended: true,
                    onTap: () => onSelect(i),
                  ),
            ],
          ),
        ),
        // ── Account-Footer ────────────────────────────────────────────
        Container(height: 1, color: Colors.white.withAlpha(20)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              CircleAvatar(
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.accountMenuSignedInAs,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _DrawerActionTile(
          icon: Icons.logout,
          label: l10n.accountMenuSignOut,
          onTap: () => _confirmLogout(context),
        ),
        _DrawerActionTile(
          icon: Icons.delete_forever_outlined,
          label: l10n.accountMenuDeleteAccount,
          danger: true,
          onTap: () => _confirmDelete(context),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.accountMenuSignOut),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
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
      final error = await context.read<AuthProvider>().deleteAccount();
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
}

class _DrawerActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _DrawerActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : Colors.white70;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
