import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../services/discord_service.dart';
import '../utils/discord_oauth.dart';
import '../utils/url_helper.dart';
import '../widgets/add_edit_buyer_dialog.dart';
import '../widgets/add_edit_shop_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Einstellungen'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Käufer'),
              Tab(icon: Icon(Icons.store_outlined, size: 18), text: 'Shops'),
              Tab(icon: Icon(Icons.discord, size: 18), text: 'Discord'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_BuyersTab(), _ShopsTab(), _DiscordTab()],
        ),
      ),
    );
  }
}

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
                      Icon(Icons.people_outline, size: 52, color: Color(0xFFCBD5E1)),
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
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          buyer.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: buyer.rowFillColor,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: buyer.buyerCellColor.withAlpha(100)),
                              ),
                            ),
                            Text(
                              buyer.active ? 'Aktiv' : 'Inaktiv',
                              style: TextStyle(
                                fontSize: 12,
                                color: buyer.active
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: const Color(0xFF64748B),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AddEditBuyerDialog(buyer: buyer),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red[400],
                              onPressed: () =>
                                  _confirmDelete(context, provider, buyer.id, buyer.name),
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

  void _confirmDelete(BuildContext context, InventoryProvider provider,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

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
                      Icon(Icons.store_outlined, size: 52, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text('Noch keine Shops angelegt.',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: shops.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
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
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${shop.region}${shop.channel.isNotEmpty ? " · ${shop.channel}" : ""}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: const Color(0xFF64748B),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AddEditShopDialog(shop: shop),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red[400],
                              onPressed: () => _confirmDelete(
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

  void _confirmDelete(BuildContext context, InventoryProvider provider,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Discord Tab ────────────────────────────────────────────────────────────────
class _DiscordTab extends StatefulWidget {
  const _DiscordTab();

  @override
  State<_DiscordTab> createState() => _DiscordTabState();
}

class _DiscordTabState extends State<_DiscordTab> {
  final _clientIdCtrl = TextEditingController();
  bool _saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<InventoryProvider>().discordClientId;
    if (_clientIdCtrl.text.isEmpty && id.isNotEmpty) {
      _clientIdCtrl.text = id;
    }
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveClientId() async {
    await context
        .read<InventoryProvider>()
        .updateDiscordClientId(_clientIdCtrl.text.trim());
    setState(() => _saved = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  void _connectDiscord() {
    final provider = context.read<InventoryProvider>();
    final clientId = provider.discordClientId;
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bitte zuerst die Client-ID eintragen und speichern.')),
      );
      return;
    }
    final redirectUri = getAppBaseUrl();
    final url = DiscordService.buildOAuthUrl(
      clientId: clientId,
      redirectUri: redirectUri,
    );
    navigateToDiscordOAuth(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final connected = provider.isDiscordConnected;
        final username = provider.discordUsername;
        final redirectUrl = getAppBaseUrl();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status card ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF5865F2).withAlpha(15)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: connected
                        ? const Color(0xFF5865F2).withAlpha(80)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: connected
                            ? const Color(0xFF5865F2)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.discord,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connected
                                ? 'Verbunden als $username'
                                : 'Nicht verbunden',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: connected
                                  ? const Color(0xFF5865F2)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            connected
                                ? 'Ticketnummern werden automatisch in Discord-Links umgewandelt.'
                                : 'Mit Discord anmelden, um Ticketnummern automatisch aufzulösen.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    if (connected)
                      TextButton.icon(
                        onPressed: () =>
                            context.read<InventoryProvider>().disconnectDiscord(),
                        icon: const Icon(Icons.logout, size: 16,
                            color: Color(0xFF64748B)),
                        label: const Text('Trennen',
                            style: TextStyle(color: Color(0xFF64748B))),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Setup steps ─────────────────────────────────────────
              if (!connected) ...[
                _SetupStep(
                  number: '1',
                  title: 'Discord Developer Portal öffnen',
                  description:
                      'Gehe zu discord.com/developers/applications → "New Application" → Name eingeben → Erstellen.',
                  action: TextButton.icon(
                    onPressed: () => openUrl(
                        'https://discord.com/developers/applications'),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Developer Portal öffnen'),
                  ),
                ),
                const SizedBox(height: 12),
                _SetupStep(
                  number: '2',
                  title: 'Redirect-URL registrieren',
                  description:
                      'Links auf "OAuth2" → unter "Redirects" auf "+ Add" klicken → folgende URL einfügen → Speichern:',
                  extra: _CopyableUrl(url: redirectUrl),
                ),
                const SizedBox(height: 12),
                _SetupStep(
                  number: '3',
                  title: 'Client-ID kopieren und eintragen',
                  description:
                      'Oben auf der OAuth2-Seite steht die "Client ID" — die ist öffentlich und kein Geheimnis. '
                      'Hier eintragen und speichern:',
                  extra: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _clientIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Client ID',
                            hintText: '1234567890123456789',
                            isDense: true,
                            prefixIcon: Icon(Icons.tag, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveClientId,
                        style: _saved
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Colors.green)
                            : null,
                        child: Text(_saved ? '✓' : 'Speichern'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SetupStep(
                  number: '4',
                  title: 'Mit Discord anmelden',
                  description:
                      'Klicke auf den Button — du wirst zu Discord weitergeleitet. '
                      'Nach der Anmeldung kehrst du automatisch zurück.',
                  action: ElevatedButton.icon(
                    onPressed: _connectDiscord,
                    icon: const Icon(Icons.discord, size: 18),
                    label: const Text('Mit Discord verbinden'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5865F2),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SetupStep(
                  number: '5',
                  title: 'Server-IDs pro Käufer hinterlegen',
                  description:
                      'Einstellungen → Käufer-Tab → Käufer bearbeiten → Discord Server IDs eintragen.\n'
                      'Server-ID findest du in Discord Desktop: '
                      'Entwicklermodus aktivieren (Einstellungen → Erweitert), '
                      'dann Rechtsklick auf den Servername → "Server-ID kopieren".',
                ),
                const SizedBox(height: 24),
              ],

              // ── Connected: Server-IDs overview ───────────────────────
              Text('Server-IDs pro Käufer',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Käufer-Tab → Käufer bearbeiten → Discord Server IDs hinzufügen.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
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
                          b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
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
                      ids.isEmpty ? 'Keine Server-IDs' : ids.join(', '),
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
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SetupStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final Widget? action;
  final Widget? extra;

  const _SetupStep({
    required this.number,
    required this.title,
    required this.description,
    this.action,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF5865F2).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                    color: Color(0xFF5865F2),
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                if (extra != null) ...[const SizedBox(height: 10), extra!],
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableUrl extends StatefulWidget {
  final String url;
  const _CopyableUrl({required this.url});

  @override
  State<_CopyableUrl> createState() => _CopyableUrlState();
}

class _CopyableUrlState extends State<_CopyableUrl> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.url,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              await _copyToClipboard(widget.url);
              setState(() => _copied = true);
              await Future<void>.delayed(const Duration(seconds: 2));
              if (mounted) setState(() => _copied = false);
            },
            icon: Icon(
                _copied ? Icons.check : Icons.copy,
                size: 14),
            label: Text(_copied ? 'Kopiert' : 'Kopieren'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    // Use Flutter's clipboard
    await _clipboardSetData(text);
  }
}


Future<void> _clipboardSetData(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
