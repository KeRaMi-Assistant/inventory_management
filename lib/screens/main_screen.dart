import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  static const _titles = [
    'Dashboard',
    'Deals',
    'Tickets',
    'Lager',
    'Statistiken',
    'Einstellungen',
  ];

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

  Future<void> _import(BuildContext context, InventoryProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CSV importieren'),
        content: const Text(
          'Importierte Einträge werden zu den bestehenden Daten hinzugefügt.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Datei auswählen')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final (deals, err) = await CsvService.importDeals(provider.nextDealId);
    if (!context.mounted) return;
    if (err != null) {
      _showSnack(context, 'Fehler: $err', isError: true);
    } else if (deals != null) {
      await provider.importDeals(deals);
      if (context.mounted) _showSnack(context, '${deals.length} Einträge importiert.');
    }
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFC0392B) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final body = _buildBody();
        final narrow = MediaQuery.of(context).size.width < 800;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, size: 20),
                const SizedBox(width: 10),
                Text(_titles[_selectedIndex]),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'CSV importieren',
                icon: const Icon(Icons.upload_file_outlined),
                onPressed: () => _import(context, provider),
              ),
              IconButton(
                tooltip: 'CSV exportieren',
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _export(context, provider),
              ),
              const SizedBox(width: 4),
              const _AccountMenu(),
              const SizedBox(width: 8),
            ],
          ),
          drawer: narrow ? Drawer(child: SafeArea(child: _NavList(selectedIndex: _selectedIndex, onSelect: _select))) : null,
          floatingActionButton: _selectedIndex == 1 || _selectedIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AddEditDealDialog(
                      initialTicketNumber: _selectedIndex == 2 ? _selectedTicket : null,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Neuer Deal'),
                )
              : null,
          body: Row(
            children: [
              if (!narrow)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _select,
                  extended: MediaQuery.of(context).size.width >= 1100,
                  backgroundColor: const Color(0xFF0F2744),
                  selectedIconTheme: const IconThemeData(color: Colors.white),
                  unselectedIconTheme: const IconThemeData(color: Colors.white60),
                  selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: Text('Deals')),
                    NavigationRailDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: Text('Tickets')),
                    NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Lager')),
                    NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Statistiken')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Einstellungen')),
                  ],
                ),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
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
}

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
        backgroundColor: Colors.white,
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF0F2744),
            fontWeight: FontWeight.w800,
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
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(email,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Color(0xFFDC2626)),
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

class _NavList extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _NavList({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dashboard_outlined, 'Dashboard'),
      (Icons.list_alt_outlined, 'Deals'),
      (Icons.confirmation_number_outlined, 'Tickets'),
      (Icons.inventory_2_outlined, 'Lager'),
      (Icons.bar_chart_outlined, 'Statistiken'),
      (Icons.settings_outlined, 'Einstellungen'),
    ];
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Lagerverwaltung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        for (int i = 0; i < items.length; i++)
          ListTile(
            selected: selectedIndex == i,
            leading: Icon(items[i].$1),
            title: Text(items[i].$2),
            onTap: () => onSelect(i),
          ),
      ],
    );
  }
}
