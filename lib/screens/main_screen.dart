import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/csv_service.dart';
import '../widgets/add_edit_deal_dialog.dart';
import 'dashboard_screen.dart';
import 'deals_screen.dart';
import 'inventory_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
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
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Statistiken'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Einstellungen'),
  ];

  Future<void> _export(BuildContext context, InventoryProvider provider) async {
    final (path, err) = await CsvService.exportAll(
      List.from(provider.deals),
      List.from(provider.shops),
      List.from(provider.buyers),
      List.from(provider.inventoryItems),
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
      final (deals, shops, buyers, items) = await provider.importCsvAll(result);
      if (context.mounted) {
        _showSnack(context, '$deals Deals, $shops Shops, $buyers Käufer, $items Lagerartikel importiert.');
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

  Widget _buildBody() {
    return switch (_selectedIndex) {
      0 => const DashboardScreen(),
      1 => DealsScreen(onOpenTicket: _openTicket),
      2 => TicketsScreen(initialTicket: _selectedTicket),
      3 => const InventoryScreen(),
      4 => const StatisticsScreen(),
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

        if (narrow) {
          // Mobile: klassische AppBar + Drawer
          return Scaffold(
            appBar: AppBar(
              title: Text(_navItems[_selectedIndex].$3),
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
          );
        }

        // Desktop: Sidebar + Content-Header
        return Scaffold(
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
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
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

  const _ContentHeader({
    required this.title,
    required this.provider,
    required this.onImport,
    required this.onExport,
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
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          await context.read<AuthProvider>().signOut();
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

