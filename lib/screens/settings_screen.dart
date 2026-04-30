import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/add_edit_buyer_dialog.dart';
import '../widgets/add_edit_shop_dialog.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final tabs = DefaultTabController(
      length: 5,
      child: Column(
        children: [
          if (!embedded)
            AppBar(
              title: const Text('Einstellungen'),
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Käufer'),
                  Tab(icon: Icon(Icons.store_outlined, size: 18), text: 'Shops'),
                  Tab(icon: Icon(Icons.discord, size: 18), text: 'Discord'),
                  Tab(icon: Icon(Icons.import_export, size: 18), text: 'Export/Import'),
                  Tab(icon: Icon(Icons.tune, size: 18), text: 'Allgemein'),
                ],
              ),
            )
          else
            const Material(
              color: Colors.white,
              child: TabBar(
                indicatorColor: Color(0xFF2563EB),
                labelColor: Color(0xFF2563EB),
                unselectedLabelColor: Color(0xFF64748B),
                tabs: [
                  Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Käufer'),
                  Tab(icon: Icon(Icons.store_outlined, size: 18), text: 'Shops'),
                  Tab(icon: Icon(Icons.discord, size: 18), text: 'Discord'),
                  Tab(icon: Icon(Icons.import_export, size: 18), text: 'Export/Import'),
                  Tab(icon: Icon(Icons.tune, size: 18), text: 'Allgemein'),
                ],
              ),
            ),
          const Expanded(
            child: TabBarView(
              children: [
                _BuyersTab(),
                _ShopsTab(),
                _DiscordInfoTab(),
                _ExportImportTab(),
                _GeneralTab(),
              ],
            ),
          ),
        ],
      ),
    );

    if (embedded) return tabs;
    return Scaffold(
      body: tabs,
    );
  }
}

// ── Buyers Tab ─────────────────────────────────────────────────────────────────

class _BuyersTab extends StatelessWidget {
  const _BuyersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final buyers = provider.buyers;
        return Scaffold(
          backgroundColor: const Color(0xFFF1F4F8),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addBuyer',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddEditBuyerDialog(),
            ),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Käufer hinzufügen'),
          ),
          body: buyers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 52, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text('Noch keine Käufer angelegt.',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: buyers.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final buyer = buyers[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: buyer.buyerCellColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              buyer.name.isNotEmpty
                                  ? buyer.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color: buyer.fontColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                        title: Text(buyer.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: buyer.discordServerIds.isNotEmpty
                            ? Row(
                                children: [
                                  const Icon(Icons.discord,
                                      size: 12,
                                      color: Color(0xFF5865F2)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      buyer.discordServerIds.join(', '),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF5865F2)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.edit_outlined, size: 20),
                              color: const Color(0xFF64748B),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    AddEditBuyerDialog(buyer: buyer),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20),
                              color: Colors.red[400],
                              onPressed: () => _confirmDeleteBuyer(
                                  context, provider, buyer.id, buyer.name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _confirmDeleteBuyer(BuildContext context, InventoryProvider provider,
      String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Käufer löschen'),
        content: Text('Käufer "$name" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              provider.deleteBuyer(id);
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Shops Tab ──────────────────────────────────────────────────────────────────

class _ShopsTab extends StatelessWidget {
  const _ShopsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final shops = provider.shops;
        return Scaffold(
          backgroundColor: const Color(0xFFF1F4F8),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addShop',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddEditShopDialog(),
            ),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Shop hinzufügen'),
          ),
          body: shops.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined,
                          size: 52, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text('Noch keine Shops angelegt.',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: shops.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final shop = shops[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border.fromBorderSide(
                                BorderSide(color: Color(0xFFBFDBFE))),
                          ),
                          child: const Icon(Icons.store_outlined,
                              color: Color(0xFF2563EB), size: 22),
                        ),
                        title: Text(shop.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${shop.region}${shop.channel.isNotEmpty ? " · ${shop.channel}" : ""}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 20),
                              color: const Color(0xFF64748B),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    AddEditShopDialog(shop: shop),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20),
                              color: Colors.red[400],
                              onPressed: () => _confirmDeleteShop(
                                  context, provider, shop.id, shop.name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _confirmDeleteShop(BuildContext context, InventoryProvider provider,
      String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shop löschen'),
        content: Text('Shop "$name" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              provider.deleteShop(id);
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Discord Info Tab ───────────────────────────────────────────────────────────

class _DiscordInfoTab extends StatelessWidget {
  const _DiscordInfoTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2).withAlpha(12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF5865F2).withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5865F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.discord,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discord-Integration',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            'Beim Hinzufügen eines Deals kannst du die Ticketnummer eintragen. '
                            'Die App zeigt dann Buttons zum direkten Öffnen der konfigurierten Discord-Server. '
                            'Dort findest du den Kanal, kopierst den Link und trägst ihn in das Ticket-URL-Feld ein.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // How to find Server ID
              Text('Server-IDs einrichten',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _infoStep(
                context,
                '1',
                'Entwicklermodus aktivieren',
                'Discord → Einstellungen → Erweitert → Entwicklermodus einschalten.',
              ),
              const SizedBox(height: 8),
              _infoStep(
                context,
                '2',
                'Server-ID kopieren',
                'Rechtsklick auf den Servernamen → „Server-ID kopieren".',
              ),
              const SizedBox(height: 8),
              _infoStep(
                context,
                '3',
                'Server-ID beim Käufer hinterlegen',
                'Käufer-Tab → Käufer bearbeiten → Discord Server IDs → ID eintragen.',
              ),
              const SizedBox(height: 24),

              // Server IDs overview per buyer
              Text('Konfigurierte Server-IDs',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...provider.buyers.map((b) {
                final ids = b.discordServerIds;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: b.buyerCellColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          b.name.isNotEmpty
                              ? b.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: b.fontColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    title: Text(b.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      ids.isEmpty
                          ? 'Keine Server-IDs konfiguriert'
                          : ids.join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: ids.isEmpty
                            ? theme.colorScheme.outline
                            : const Color(0xFF5865F2),
                      ),
                    ),
                    trailing: Icon(Icons.discord,
                        color: ids.isEmpty
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF5865F2)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _infoStep(
      BuildContext context, String number, String title, String desc) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF5865F2).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Color(0xFF5865F2),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportImportTab extends StatelessWidget {
  const _ExportImportTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SettingsCard(
              icon: Icons.file_download_outlined,
              title: 'CSV-Export',
              subtitle: 'Deals als CSV exportieren kannst du weiterhin über die obere Toolbar.',
              trailing: const Icon(Icons.table_chart_outlined, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.backup_outlined,
              title: 'JSON-Backup',
              subtitle: 'Kompletter App-Export: Deals, Käufer, Shops, Lager und Bewegungen.',
              trailing: ElevatedButton.icon(
                onPressed: () => _exportJson(context, provider),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Exportieren'),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.restore_outlined,
              title: 'JSON-Restore',
              subtitle: 'Vollständige Wiederherstellung aus einem JSON-Backup.',
              trailing: ElevatedButton.icon(
                onPressed: () => _restoreJson(context, provider),
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Wiederherstellen'),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Amazon-Import',
              subtitle: 'Amazon-CSV-Import ist über die obere Toolbar verfügbar.',
              trailing: const Icon(Icons.north_east, color: Color(0xFF64748B)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportJson(BuildContext context, InventoryProvider provider) async {
    final json = provider.exportJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final fileName = 'lagerverwaltung_data_${DateTime.now().toIso8601String().substring(0, 10)}.json';
    await Clipboard.setData(ClipboardData(text: json));
    final path = await FilePicker.saveFile(
      dialogTitle: 'JSON-Backup speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path == null ? 'Backup in die Zwischenablage kopiert.' : 'Backup exportiert: $path')),
    );
  }

  Future<void> _restoreJson(BuildContext context, InventoryProvider provider) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'JSON-Backup auswählen',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic>) return;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Daten wiederherstellen'),
        content: const Text('Alle aktuellen Daten werden durch dieses Backup ersetzt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wiederherstellen')),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.restoreData(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup wiederhergestellt.')));
      }
    }
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SettingsCard(
              icon: Icons.percent_outlined,
              title: 'MwSt-Satz',
              subtitle: 'Standard: 19%. Neue Deals berechnen EK Brutto aktuell mit 1,19.',
              trailing: Text('19%'),
            ),
            const SizedBox(height: 12),
            const _SettingsCard(
              icon: Icons.sort_outlined,
              title: 'Standard-Sortierung',
              subtitle: 'Deals werden standardmäßig nach Bestelldatum absteigend angezeigt.',
              trailing: Text('Datum ↓'),
            ),
            const SizedBox(height: 12),
            const _SettingsCard(
              icon: Icons.cloud_done_outlined,
              title: 'Cloud-Speicher',
              subtitle:
                  'Daten werden in deinem Supabase-Konto gespeichert und über alle Geräte synchronisiert.',
              trailing: Text('Supabase'),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.storage_outlined,
              title: 'Datenbestand',
              subtitle:
                  '${provider.deals.length} Deals · ${provider.buyers.length} Käufer · ${provider.shops.length} Shops · ${provider.inventoryItems.length} Lagerartikel',
              trailing: Text('${provider.exportJson().length ~/ 1024} KB'),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
