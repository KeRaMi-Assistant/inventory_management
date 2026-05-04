import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/csv_service.dart';
import '../widgets/add_edit_deal_dialog.dart';
import '../widgets/global_search_dialog.dart';
import 'activity_screen.dart';
import 'dashboard_screen.dart';
import 'deals_screen.dart';
import 'inventory_screen.dart';
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

  static const _navItems = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
    (Icons.list_alt_outlined, Icons.list_alt_rounded, 'Deals'),
    (Icons.confirmation_number_outlined, Icons.confirmation_number_rounded, 'Tickets'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Lager'),
    (Icons.local_shipping_outlined, Icons.local_shipping, 'Lieferanten'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Statistiken'),
    (Icons.history_outlined, Icons.history_rounded, 'Aktivität'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Einstellungen'),
  ];

  Future<void> _export(BuildContext context, InventoryProvider provider) async {
    final (path, err) = await CsvService.exportAll(
      List.from(provider.deals),
      List.from(provider.shops),
      List.from(provider.buyers),
      List.from(provider.inventoryItems),
      suppliers: List.from(provider.suppliers),
    );
    if (!context.mounted) return;
    if (err != null) {
      _showSnack(context, 'Fehler: $err', isError: true);
    } else if (path != null) {
      _showSnack(context, 'Exportiert: $path');
    }
  }

  Future<void> _import(BuildContext context, InventoryProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CSV importieren'),
        content: const Text(
          'Deals werden hinzugefügt. Shops, Käufer und Lagerbestand werden nur '
          'importiert, wenn noch kein Eintrag mit demselben Namen existiert.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Datei auswählen')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final (result, err) = await CsvService.importAll(provider.nextDealId);
    if (!context.mounted) return;
    if (err != null) {
      _showSnack(context, 'Fehler: $err', isError: true);
    } else if (result != null) {
      final (deals, shops, buyers, suppliers, items) =
          await provider.importCsvAll(result);
      if (context.mounted) {
        _showSnack(context,
            '$deals Deals, $shops Shops, $buyers Käufer, $suppliers Lieferanten, $items Lagerartikel importiert.');
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
      3 => const InventoryScreen(),
      4 => const SuppliersScreen(),
      5 => const StatisticsScreen(),
      6 => const ActivityScreen(),
      _ => const SettingsScreen(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final width = MediaQuery.of(context).size.width;
        final narrow = width < 800;
        final extended = width >= 1100;
        final body = _buildBody();

        final fab = _selectedIndex == 1 || _selectedIndex == 2
            ? FloatingActionButton.extended(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AddEditDealDialog(
                    initialTicketNumber: _selectedIndex == 2 ? _selectedTicket : null,
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Neuer Deal'),
              )
            : null;

        final scaffold = narrow
            ? Scaffold(
                appBar: AppBar(
                  title: Text(_navItems[_selectedIndex].$3),
                  actions: [
                    IconButton(
                      tooltip: 'Suchen',
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
                      items: _navItems,
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
                      items: _navItems,
                      extended: extended,
                      onSelect: _select,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ContentHeader(
                            title: _navItems[_selectedIndex].$3,
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
  final List<(IconData, IconData, String)> items;
  final bool extended;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.items,
    required this.extended,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
                  const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    Text(
                      'InventoryOS',
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
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, i) => _NavItem(
                icon: items[i].$1,
                activeIcon: items[i].$2,
                label: items[i].$3,
                isSelected: selectedIndex == i,
                extended: extended,
                onTap: () => onSelect(i),
              ),
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
                  color: widget.isSelected ? AppTheme.accent : Colors.transparent,
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
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
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
            tooltip: 'CSV importieren',
            icon: const Icon(Icons.upload_file_outlined, size: 18, color: AppTheme.textMuted),
            onPressed: onImport,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'CSV exportieren',
            icon: const Icon(Icons.download_outlined, size: 18, color: AppTheme.textMuted),
            onPressed: onExport,
          ),
          const SizedBox(width: 8),
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
    final isMac = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.iOS;
    return Tooltip(
      message: 'Globale Suche',
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
              const Text(
                'Suchen',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
    final auth = context.watch<AuthProvider>();
    final email = auth.userEmail ?? 'Unbekannt';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      tooltip: 'Konto',
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
              const Text('Angemeldet als',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 2),
              Text(email,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 16, color: AppTheme.danger),
              SizedBox(width: 10),
              Text('Abmelden'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever_outlined, size: 16, color: Color(0xFFC0392B)),
              SizedBox(width: 10),
              Text('Konto löschen',
                  style: TextStyle(color: Color(0xFFC0392B))),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        final auth = context.read<AuthProvider>();
        if (value == 'logout') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Wirklich abmelden?'),
              content: const Text(
                  'Du wirst zurück zum Login geleitet. Nicht synchronisierte Eingaben gehen verloren.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abmelden'),
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
                title: const Text('Konto endgültig löschen?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dein Konto und alle deine Daten werden unwiderruflich gelöscht. '
                      'Diese Aktion kann nicht rückgängig gemacht werden.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tippe LÖSCHEN zur Bestätigung:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmCtrl,
                      autofocus: true,
                      onChanged: (_) => setS(() {}),
                      decoration: const InputDecoration(
                        hintText: 'LÖSCHEN',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Abbrechen'),
                  ),
                  ElevatedButton(
                    onPressed: confirmCtrl.text.trim() == 'LÖSCHEN'
                        ? () => Navigator.pop(ctx, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0392B)),
                    child: const Text('Konto löschen'),
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
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onSelect;

  const _MobileNavList({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'InventoryOS',
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
        for (int i = 0; i < items.length; i++)
          _NavItem(
            icon: items[i].$1,
            activeIcon: items[i].$2,
            label: items[i].$3,
            isSelected: selectedIndex == i,
            extended: true,
            onTap: () => onSelect(i),
          ),
      ],
    );
  }
}

