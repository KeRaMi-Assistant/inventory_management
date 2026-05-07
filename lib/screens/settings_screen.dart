import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../models/carrier_credential.dart';
import '../models/pricing_plan.dart';
import '../models/shop.dart';
import '../models/workspace.dart';
import '../models/mailbox_account.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/carrier_credentials_provider.dart';
import '../providers/inbox_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/push_service.dart';
import '../services/workspace_service.dart';
import '../widgets/add_edit_buyer_dialog.dart';
import '../widgets/add_edit_mailbox_dialog.dart';
import '../widgets/add_edit_shop_dialog.dart';
import 'billing_profile_screen.dart';
import 'pricing_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = DefaultTabController(
      length: 7,
      child: Column(
        children: [
          if (!embedded)
            AppBar(
              title: Text(l10n.settingsTitle),
              bottom: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(icon: const Icon(Icons.people_outline, size: 18), text: l10n.settingsTabBuyers),
                  Tab(icon: const Icon(Icons.store_outlined, size: 18), text: l10n.settingsTabShops),
                  Tab(icon: const Icon(Icons.group_outlined, size: 18), text: l10n.settingsTabTeam),
                  Tab(icon: const Icon(Icons.notifications_outlined, size: 18), text: l10n.settingsTabPush),
                  const Tab(icon: Icon(Icons.mail_outline, size: 18), text: 'Postfach'),
                  Tab(icon: const Icon(Icons.local_shipping_outlined, size: 18), text: l10n.settingsTabShipping),
                  Tab(icon: const Icon(Icons.tune, size: 18), text: l10n.settingsTabGeneral),
                ],
              ),
            )
          else
            Material(
              color: AppTheme.bgSurfaceOf(context),
              child: TabBar(
                isScrollable: true,
                indicatorColor: AppTheme.accentTextOf(context),
                labelColor: AppTheme.accentTextOf(context),
                unselectedLabelColor: AppTheme.textMutedOf(context),
                dividerColor: AppTheme.borderOf(context),
                tabs: [
                  Tab(icon: const Icon(Icons.people_outline, size: 18), text: l10n.settingsTabBuyers),
                  Tab(icon: const Icon(Icons.store_outlined, size: 18), text: l10n.settingsTabShops),
                  Tab(icon: const Icon(Icons.group_outlined, size: 18), text: l10n.settingsTabTeam),
                  Tab(icon: const Icon(Icons.notifications_outlined, size: 18), text: l10n.settingsTabPush),
                  const Tab(icon: Icon(Icons.mail_outline, size: 18), text: 'Postfach'),
                  Tab(icon: const Icon(Icons.local_shipping_outlined, size: 18), text: l10n.settingsTabShipping),
                  Tab(icon: const Icon(Icons.tune, size: 18), text: l10n.settingsTabGeneral),
                ],
              ),
            ),
          const Expanded(
            child: TabBarView(
              children: [
                _BuyersTab(),
                _ShopsTab(),
                _TeamTab(),
                _NotificationsTab(),
                _MailboxTab(),
                _ShippingTab(),
                _GeneralTab(),
              ],
            ),
          ),
        ],
      ),
    );

    if (embedded) return tabs;
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      body: tabs,
    );
  }
}

// ── Buyers Tab ─────────────────────────────────────────────────────────────────

class _BuyersTab extends StatelessWidget {
  const _BuyersTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final buyers = provider.buyers;
        return Scaffold(
          backgroundColor: AppTheme.bgAppOf(context),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addBuyer',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddEditBuyerDialog(),
            ),
            icon: const Icon(Icons.person_add_outlined),
            label: Text(l10n.buyersAdd),
          ),
          body: buyers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 52,
                          color: AppTheme.textDisabledOf(context)),
                      const SizedBox(height: 12),
                      Text(l10n.buyersEmpty,
                          style: TextStyle(
                              color: AppTheme.textMutedOf(context))),
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
                        side: BorderSide(color: AppTheme.borderOf(context)),
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.buyersDeleteTitle),
        content: Text(l10n.buyersDeleteConfirm(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
            onPressed: () {
              provider.deleteBuyer(id);
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.actionDelete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Shops Tab ──────────────────────────────────────────────────────────────────

class _ShopsTab extends StatelessWidget {
  const _ShopsTab();

  bool _isAmazon(Shop s) =>
      s.name.trim().toLowerCase().startsWith('amazon');

  Future<void> _seedAmazon(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await provider.seedAmazonShops();
      messenger.showSnackBar(SnackBar(
        content: Text(result.added == 0
            ? 'Amazon-Shops sind bereits vorhanden (${result.skipped} übersprungen).'
            : '${result.added} Amazon-Shops hinzugefügt'
                '${result.skipped > 0 ? ', ${result.skipped} bereits vorhanden' : ''}.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Fehler beim Hinzufügen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final shops = provider.shops;
        final amazonShops = shops.where(_isAmazon).toList()
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final otherShops = shops.where((s) => !_isAmazon(s)).toList()
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return Scaffold(
          backgroundColor: AppTheme.bgAppOf(context),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addShop',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddEditShopDialog(),
            ),
            icon: const Icon(Icons.add_business_outlined),
            label: Text(l10n.shopsAdd),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _seedAmazon(context, provider),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Text('Amazon-Shops hinzufügen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: shops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.store_outlined,
                                size: 52, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(l10n.shopsEmpty,
                                style:
                                    const TextStyle(color: Color(0xFF94A3B8))),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (amazonShops.isNotEmpty) ...[
                            _AmazonShopsGroup(
                              shops: amazonShops,
                              onEdit: (shop) => showDialog(
                                context: context,
                                builder: (_) => AddEditShopDialog(shop: shop),
                              ),
                              onDelete: (shop) => _confirmDeleteShop(
                                  context, provider, shop.id, shop.name),
                            ),
                            const SizedBox(height: 8),
                          ],
                          for (final shop in otherShops) ...[
                            _ShopTile(
                              shop: shop,
                              onEdit: () => showDialog(
                                context: context,
                                builder: (_) => AddEditShopDialog(shop: shop),
                              ),
                              onDelete: () => _confirmDeleteShop(
                                  context, provider, shop.id, shop.name),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteShop(BuildContext context, InventoryProvider provider,
      String id, String name) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.shopsDeleteTitle),
        content: Text(l10n.shopsDeleteConfirm(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
            onPressed: () {
              provider.deleteShop(id);
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.actionDelete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.shop,
    required this.onEdit,
    required this.onDelete,
  });

  final Shop shop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.accentLightOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.fromBorderSide(
                BorderSide(color: AppTheme.accentBorderOf(context))),
          ),
          child: Icon(Icons.store_outlined,
              color: AppTheme.accentTextOf(context), size: 22),
        ),
        title: Text(shop.name,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context))),
        subtitle: Text(
          '${shop.region}${shop.channel.isNotEmpty ? " · ${shop.channel}" : ""}',
          style: TextStyle(
              fontSize: 12, color: AppTheme.textMutedOf(context)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppTheme.textMutedOf(context),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppTheme.dangerTextOf(context),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmazonShopsGroup extends StatelessWidget {
  const _AmazonShopsGroup({
    required this.shops,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Shop> shops;
  final void Function(Shop) onEdit;
  final void Function(Shop) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.warningBgOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.fromBorderSide(
                BorderSide(color: AppTheme.warningBorderOf(context))),
          ),
          child: Icon(Icons.shopping_bag_outlined,
              color: AppTheme.warningTextOf(context), size: 22),
        ),
        title: Text('Amazon',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context))),
        subtitle: Text(
          '${shops.length} ${shops.length == 1 ? "Country-Account" : "Country-Accounts"}',
          style: TextStyle(
              fontSize: 12, color: AppTheme.textMutedOf(context)),
        ),
        children: [
          for (final shop in shops)
            ListTile(
              contentPadding: const EdgeInsets.only(
                  left: 56, right: 16, top: 0, bottom: 0),
              dense: true,
              title: Text(shop.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context))),
              subtitle: Text(
                '${shop.region}${shop.channel.isNotEmpty ? " · ${shop.channel}" : ""}',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textMutedOf(context)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppTheme.textMutedOf(context),
                    onPressed: () => onEdit(shop),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppTheme.dangerTextOf(context),
                    onPressed: () => onDelete(shop),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _PlanSection(),
            const SizedBox(height: 24),
            _SettingsCard(
              icon: Icons.percent_outlined,
              title: l10n.settingsTaxRateTitle,
              subtitle: l10n.settingsTaxRateSubtitle,
              trailing: const Text('19%'),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.sort_outlined,
              title: l10n.settingsSortTitle,
              subtitle: l10n.settingsSortSubtitle,
              trailing: Text(l10n.settingsSortValue),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.cloud_done_outlined,
              title: l10n.settingsCloudTitle,
              subtitle: l10n.settingsCloudSubtitle,
              trailing: const Text('Supabase'),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.storage_outlined,
              title: l10n.settingsDataTitle,
              subtitle: l10n.settingsDataSubtitle(
                provider.deals.length,
                provider.buyers.length,
                provider.shops.length,
                provider.inventoryItems.length,
              ),
              trailing: Text(l10n.commonItems(
                  provider.deals.length + provider.inventoryItems.length)),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: l10n.settingsThemeSection),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final prefs = context.watch<AppPreferencesProvider>();
                  return SegmentedButton<ThemeMode>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    expandedInsets: constraints.maxWidth < 600
                        ? EdgeInsets.zero
                        : null,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l10n.settingsThemeLight),
                        icon: const Icon(Icons.light_mode_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.settingsThemeDark),
                        icon: const Icon(Icons.dark_mode_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l10n.settingsThemeSystem),
                        icon: const Icon(Icons.brightness_auto_outlined, size: 16),
                      ),
                    ],
                    selected: {prefs.themeMode},
                    onSelectionChanged: (s) =>
                        context.read<AppPreferencesProvider>().setThemeMode(s.first),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: l10n.settingsLanguageSection),
            const SizedBox(height: 8),
            const _LanguageCard(),
            const SizedBox(height: 24),
            _SectionHeader(title: l10n.settingsStatsSection),
            const SizedBox(height: 8),
            const _MonthlyGoalCard(),
            const SizedBox(height: 12),
            const _LowStockThresholdCard(),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const _LogoutCard(),
            const SizedBox(height: 12),
            _DeleteAccountCard(),
          ],
        );
      },
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard();

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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.accountMenuSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = context.watch<AuthProvider>().userEmail ?? '—';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.logout, color: Color(0xFFD97706)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accountMenuSignOut,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${l10n.accountMenuSignedInAs} $email',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _confirmLogout(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFD97706)),
              ),
              child: Text(l10n.accountMenuSignOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _MonthlyGoalCard extends StatelessWidget {
  const _MonthlyGoalCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppPreferencesProvider>(
      builder: (context, prefs, _) {
        final localeTag =
            Localizations.localeOf(context).toLanguageTag();
        final money =
            NumberFormat.currency(locale: localeTag, symbol: '€');
        return _SettingsCard(
          icon: Icons.flag_outlined,
          title: l10n.settingsMonthlyGoalTitle,
          subtitle: l10n.settingsMonthlyGoalSubtitle,
          trailing: TextButton(
            onPressed: () async {
              final ctrl = TextEditingController(
                  text: prefs.monthlyProfitGoal.toStringAsFixed(0));
              final value = await showDialog<double>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.settingsMonthlyGoalDialogTitle),
                  content: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      suffixText: '€',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.actionCancel),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final v = double.tryParse(
                            ctrl.text.replaceAll(',', '.'));
                        if (v != null && v >= 0) Navigator.pop(ctx, v);
                      },
                      child: Text(l10n.actionSave),
                    ),
                  ],
                ),
              );
              ctrl.dispose();
              if (value != null) {
                await prefs.setMonthlyProfitGoal(value);
              }
            },
            child: Text(money.format(prefs.monthlyProfitGoal)),
          ),
        );
      },
    );
  }
}

class _LowStockThresholdCard extends StatelessWidget {
  const _LowStockThresholdCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppPreferencesProvider>(
      builder: (context, prefs, _) {
        return _SettingsCard(
          icon: Icons.warning_amber_outlined,
          title: l10n.settingsLowStockTitle,
          subtitle: l10n.settingsLowStockSubtitle,
          trailing: TextButton(
            onPressed: () async {
              final ctrl = TextEditingController(
                  text: '${prefs.lowStockThreshold}');
              final value = await showDialog<int>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.settingsLowStockDialogTitle),
                  content: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      suffixText: l10n.settingsLowStockUnit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.actionCancel),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final v = int.tryParse(ctrl.text);
                        if (v != null && v >= 0) Navigator.pop(ctx, v);
                      },
                      child: Text(l10n.actionSave),
                    ),
                  ],
                ),
              );
              ctrl.dispose();
              if (value != null) {
                await prefs.setLowStockThreshold(value);
              }
            },
            child: Text(l10n.settingsLowStockTrailing(prefs.lowStockThreshold)),
          ),
        );
      },
    );
  }
}

class _DeleteAccountCard extends StatefulWidget {
  @override
  State<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends State<_DeleteAccountCard> {
  bool _loading = false;

  Future<void> _confirmDelete() async {
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
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.deleteAccount();
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFC0392B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.delete_forever_outlined, color: Color(0xFFC0392B)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accountMenuDeleteAccount,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC0392B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.deleteAccountSubtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : OutlinedButton(
                    onPressed: _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC0392B),
                      side: const BorderSide(color: Color(0xFFC0392B)),
                    ),
                    child: Text(l10n.actionDelete),
                  ),
          ],
        ),
      ),
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

// ── Notifications Tab ─────────────────────────────────────────────────────────

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<NotificationPreferencesService>();
    final loaded = await svc.load();
    if (!mounted) return;
    setState(() {
      _prefs = loaded;
      _loading = false;
    });
  }

  Future<void> _persist(NotificationPreferences next) async {
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      await context.read<NotificationPreferencesService>().save(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pushSaveFailed('$e')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final push = context.watch<PushService>();
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: AppTheme.bgAppOf(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!push.isAvailable)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.warningBgOf(context),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.warningBorderOf(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warningTextOf(context), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.pushFirebaseMissing,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warningTextOf(context)),
                    ),
                  ),
                ],
              ),
            ),
          _Section(
            title: l10n.pushSectionTypes,
            children: [
              SwitchListTile(
                title: Text(l10n.pushMhdTitle),
                subtitle: Text(l10n.pushMhdSubtitle),
                value: _prefs.mhdWarningEnabled,
                onChanged: _saving
                    ? null
                    : (v) =>
                        _persist(_prefs.copyWith(mhdWarningEnabled: v)),
              ),
              ListTile(
                enabled: _prefs.mhdWarningEnabled && !_saving,
                title: Text(l10n.pushMhdLeadTitle),
                subtitle:
                    Text(l10n.pushMhdLeadSubtitle(_prefs.mhdWarningDays)),
                trailing: SizedBox(
                  width: 200,
                  child: Slider(
                    value: _prefs.mhdWarningDays.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    label:
                        l10n.pushMhdLeadSliderLabel(_prefs.mhdWarningDays),
                    onChanged: !_prefs.mhdWarningEnabled || _saving
                        ? null
                        : (v) {
                            setState(() => _prefs = _prefs.copyWith(
                                mhdWarningDays: v.round()));
                          },
                    onChangeEnd: !_prefs.mhdWarningEnabled || _saving
                        ? null
                        : (v) => _persist(_prefs.copyWith(
                            mhdWarningDays: v.round())),
                  ),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.pushDeliveryTitle),
                subtitle: Text(l10n.pushDeliverySubtitle),
                value: _prefs.deliveryEnabled,
                onChanged: _saving
                    ? null
                    : (v) =>
                        _persist(_prefs.copyWith(deliveryEnabled: v)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.pushPaymentTitle),
                subtitle:
                    Text(l10n.pushPaymentSubtitle(_prefs.paymentOverdueDays)),
                value: _prefs.paymentEnabled,
                onChanged: _saving
                    ? null
                    : (v) => _persist(_prefs.copyWith(paymentEnabled: v)),
              ),
              ListTile(
                enabled: _prefs.paymentEnabled && !_saving,
                title: Text(l10n.pushPaymentLeadTitle),
                subtitle: Text(
                    l10n.pushPaymentLeadSubtitle(_prefs.paymentOverdueDays)),
                trailing: SizedBox(
                  width: 200,
                  child: Slider(
                    value: _prefs.paymentOverdueDays.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    label: l10n
                        .pushMhdLeadSliderLabel(_prefs.paymentOverdueDays),
                    onChanged: !_prefs.paymentEnabled || _saving
                        ? null
                        : (v) {
                            setState(() => _prefs = _prefs.copyWith(
                                paymentOverdueDays: v.round()));
                          },
                    onChangeEnd: !_prefs.paymentEnabled || _saving
                        ? null
                        : (v) => _persist(_prefs.copyWith(
                            paymentOverdueDays: v.round())),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: l10n.pushSectionInfo,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule,
                    size: 20, color: Color(0xFF64748B)),
                title: Text(l10n.pushDailyCheckTitle),
                subtitle: Text(l10n.pushDailyCheckSubtitle),
              ),
              ListTile(
                leading: const Icon(Icons.fingerprint,
                    size: 20, color: Color(0xFF64748B)),
                title: Text(l10n.pushDedupTitle),
                subtitle: Text(l10n.pushDedupSubtitle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMutedOf(context),
                letterSpacing: 0.7,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}


// ── Team Tab ──────────────────────────────────────────────────────────────────

class _TeamTab extends StatefulWidget {
  const _TeamTab();

  @override
  State<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<_TeamTab> {
  Workspace? _workspace;
  List<WorkspaceMember> _members = [];
  List<WorkspaceInvite> _invites = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = context.read<WorkspaceService>();
      final activeId =
          context.read<ActiveWorkspaceProvider>().active?.id;
      final all = await svc.listMine();
      // Bevorzuge den aktuell aktiven Workspace; fällt zurück auf den ersten
      // Workspace, wenn nichts aktiv ist (z.B. direkt nach Login).
      final ws = activeId == null
          ? (all.isEmpty ? null : all.first)
          : all.where((w) => w.id == activeId).firstOrNull ??
              (all.isEmpty ? null : all.first);
      if (ws == null) {
        if (!mounted) return;
        setState(() {
          _workspace = null;
          _members = [];
          _invites = [];
          _loading = false;
        });
        return;
      }
      final members = await svc.listMembers(ws.id);
      List<WorkspaceInvite> invites = const [];
      try {
        invites = await svc.listInvites(ws.id);
      } catch (_) {
        // Mitglieder ohne Owner/Admin-Rolle dürfen Invites nicht lesen — OK.
      }
      if (!mounted) return;
      setState(() {
        _workspace = ws;
        _members = members;
        _invites = invites;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _renameWorkspace() async {
    final ws = _workspace;
    if (ws == null) return;
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: ws.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.teamRenameTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.teamRenameLabel,
            hintText: l10n.teamRenameHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.actionSave)),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final activeWs = context.read<ActiveWorkspaceProvider>();
    final uid = context.read<AuthProvider>().currentUser?.id;
    try {
      await context.read<WorkspaceService>().renameWorkspace(
            workspaceId: ws.id,
            name: newName,
          );
      if (uid != null) {
        await activeWs.loadForCurrentUser(uid);
      }
      if (!mounted) return;
      await _load();
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.teamRenameSuccess)));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.teamRenameFailed('$e'))));
    }
  }

  WorkspaceRole? get _myRole {
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return null;
    return _members.where((m) => m.userId == uid).firstOrNull?.role;
  }

  String _roleLabel(AppLocalizations l10n, WorkspaceRole role) =>
      switch (role) {
        WorkspaceRole.owner => l10n.teamRoleOwner,
        WorkspaceRole.admin => l10n.teamRoleAdmin,
        WorkspaceRole.member => l10n.teamRoleMember,
        WorkspaceRole.viewer => l10n.teamRoleViewer,
      };

  Future<void> _invite() async {
    final ws = _workspace;
    if (ws == null) return;
    final l10n = AppLocalizations.of(context);
    final emailCtrl = TextEditingController();
    WorkspaceRole role = WorkspaceRole.member;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.teamInviteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.teamInviteEmailLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WorkspaceRole>(
                initialValue: role,
                decoration: InputDecoration(
                  labelText: l10n.teamInviteRoleLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: WorkspaceRole.admin,
                      child: Text(l10n.teamRoleAdmin)),
                  DropdownMenuItem(
                      value: WorkspaceRole.member,
                      child: Text(l10n.teamRoleMember)),
                  DropdownMenuItem(
                      value: WorkspaceRole.viewer,
                      child: Text(l10n.teamRoleViewer)),
                ],
                onChanged: (v) =>
                    setS(() => role = v ?? WorkspaceRole.member),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.actionCancel)),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.teamInvite)),
          ],
        ),
      ),
    );
    final email = emailCtrl.text.trim();
    emailCtrl.dispose();
    if (ok != true || email.isEmpty || !mounted) return;
    try {
      await context.read<WorkspaceService>().createInvite(
            workspaceId: ws.id,
            email: email,
            role: role,
          );
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.teamInviteFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFmt =
        DateFormat.yMd(Localizations.localeOf(context).toLanguageTag());
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${l10n.teamLoadFailed(_error!)}\n\n${l10n.teamMigrationHint}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final ws = _workspace;
    if (ws == null) {
      return Center(child: Text(l10n.teamNoWorkspace));
    }
    final canManage = _myRole?.canManageMembers ?? false;
    final isOwner = _myRole == WorkspaceRole.owner;
    final myUid = context.read<AuthProvider>().currentUser?.id;
    return Container(
      color: AppTheme.bgAppOf(context),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsCard(
            icon: Icons.workspaces_outlined,
            title: ws.displayLabel(myUid),
            subtitle: l10n.teamWorkspaceSummary(
                ws.id.substring(0, 8), _members.length),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner)
                  IconButton(
                    tooltip: l10n.teamRename,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: _renameWorkspace,
                  ),
                IconButton(
                  tooltip: l10n.teamCopyId,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: ws.id));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.teamCopyIdSnack)),
                    );
                  },
                ),
                if (canManage) ...[
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _invite,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: Text(l10n.teamInvite),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: l10n.teamMembers),
          const SizedBox(height: 8),
          ..._members.map(
            (m) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.borderOf(context)),
              ),
              child: ListTile(
                leading: Icon(Icons.person_outline,
                    color: AppTheme.accentTextOf(context)),
                title: Text(m.email ?? m.userId.substring(0, 8),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context))),
                subtitle: Text(
                  l10n.teamMemberSince(_roleLabel(l10n, m.role),
                      dateFmt.format(m.joinedAt.toLocal())),
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedOf(context)),
                ),
                trailing: canManage && m.role != WorkspaceRole.owner
                    ? IconButton(
                        tooltip: l10n.teamMemberRemove,
                        icon: Icon(Icons.person_remove_outlined,
                            color: AppTheme.dangerTextOf(context),
                            size: 18),
                        onPressed: () async {
                          await context
                              .read<WorkspaceService>()
                              .removeMember(
                                workspaceId: ws.id,
                                userId: m.userId,
                              );
                          if (mounted) await _load();
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (_invites.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader(title: l10n.teamInvites),
            const SizedBox(height: 8),
            ..._invites.map(
              (inv) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.borderOf(context)),
                ),
                child: ListTile(
                  leading: Icon(Icons.mail_outline,
                      color: AppTheme.textMutedOf(context)),
                  title: Text(inv.email,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context))),
                  subtitle: Text(
                    l10n.teamInviteExpires(_roleLabel(l10n, inv.role),
                        dateFmt.format(inv.expiresAt.toLocal())),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context)),
                  ),
                  trailing: canManage
                      ? IconButton(
                          tooltip: l10n.teamInviteRevoke,
                          icon: Icon(Icons.cancel_outlined,
                              color: AppTheme.dangerTextOf(context),
                              size: 18),
                          onPressed: () async {
                            await context
                                .read<WorkspaceService>()
                                .revokeInvite(inv.id);
                            if (mounted) await _load();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppPreferencesProvider>(
      builder: (context, prefs, _) {
        final code = prefs.locale?.languageCode ?? 'system';
        return _SettingsCard(
          icon: Icons.language_outlined,
          title: l10n.settingsLanguageTitle,
          subtitle: l10n.settingsLanguageSubtitle,
          trailing: DropdownButton<String>(
            value: code,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                  value: 'system', child: Text(l10n.settingsLanguageSystem)),
              DropdownMenuItem(
                  value: 'de', child: Text(l10n.settingsLanguageDe)),
              DropdownMenuItem(
                  value: 'en', child: Text(l10n.settingsLanguageEn)),
            ],
            onChanged: (v) {
              if (v == null) return;
              prefs.setLocale(v == 'system' ? null : Locale(v));
            },
          ),
        );
      },
    );
  }
}

// ── Plan & Billing Section ────────────────────────────────────────────────────

class _PlanSection extends StatefulWidget {
  const _PlanSection();

  @override
  State<_PlanSection> createState() => _PlanSectionState();
}

class _PlanSectionState extends State<_PlanSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final billing = context.read<BillingProvider>();
      if (billing.profile == null && !billing.isLoading) {
        billing.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingProvider>();
    final profile = billing.profile;
    final plan = billing.currentPlan;
    final pricing = PricingPlan.forBillingPlan(plan);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final priceLabel = plan == BillingPlan.free
        ? 'kostenlos'
        : '${_fmtEur(pricing.monthlyPriceEur)} / Monat';

    final addressMissing =
        plan.isPaid && (profile == null || !profile.hasCompleteBillingAddress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Plan & Abrechnung'),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PricingScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.workspace_premium_outlined,
                        color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            if (pricing.mostPopular)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withAlpha(30),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Most Popular',
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          priceLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    plan == BillingPlan.free ? 'Upgrade' : 'Verwalten',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BillingProfileScreen(),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFF2563EB)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rechnungsdaten',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          _billingSubtitle(profile, plan, addressMissing),
                          style: TextStyle(
                            fontSize: 12,
                            color: addressMissing
                                ? Colors.red.shade600
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (addressMissing)
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _billingSubtitle(
      BillingProfile? p, BillingPlan plan, bool missing) {
    if (missing) {
      return 'Pflichtangaben unvollständig — bitte ergänzen';
    }
    if (p == null || (p.fullName ?? '').trim().isEmpty) {
      return plan.isPaid
          ? 'Adresse hinterlegen'
          : 'Optional — wird erst beim Upgrade benötigt';
    }
    final parts = <String>[
      p.fullName!.trim(),
      if ((p.city ?? '').trim().isNotEmpty) p.city!.trim(),
    ];
    return parts.join(' · ');
  }

  static String _fmtEur(double v) {
    if (v == v.roundToDouble()) return '${v.toStringAsFixed(0)} €';
    return '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
}

// ── Mailbox / Postfach Tab ─────────────────────────────────────────────────────

class _MailboxTab extends StatefulWidget {
  const _MailboxTab();

  @override
  State<_MailboxTab> createState() => _MailboxTabState();
}

class _MailboxTabState extends State<_MailboxTab> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<InboxProvider>().refresh();
      });
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InboxProvider provider,
    MailboxAccount account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Postfach entfernen'),
        content: Text(
            'Soll das IMAP-Konto "${account.label}" wirklich gelöscht werden? '
            'Bereits importierte Mails bleiben in der Inbox erhalten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.deleteAccount(account.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<InboxProvider, BillingProvider>(
      builder: (context, provider, billing, _) {
        final pricing = PricingPlan.forBillingPlan(billing.currentPlan);
        final mailboxLimit = pricing.mailboxLimit; // -1 = unlimited
        final hasInbox = pricing.hasInbox;
        final atLimit = mailboxLimit > 0 &&
            provider.accounts.length >= mailboxLimit;
        return Scaffold(
          backgroundColor: AppTheme.bgAppOf(context),
          floatingActionButton: hasInbox
              ? FloatingActionButton.extended(
                  heroTag: 'addMailbox',
                  onPressed: atLimit
                      ? () => _showMailboxLimitReached(
                          context, billing.currentPlan, mailboxLimit)
                      : () => showDialog(
                            context: context,
                            builder: (_) => const AddEditMailboxDialog(),
                          ),
                  backgroundColor: atLimit ? Colors.grey : null,
                  icon: Icon(atLimit ? Icons.lock_outline : Icons.add),
                  label: Text(atLimit
                      ? 'Limit erreicht ($mailboxLimit)'
                      : 'IMAP-Konto'),
                )
              : null,
          body: !hasInbox
              ? _MailboxFreePlanGate(plan: billing.currentPlan)
              : provider.isLoading && provider.accounts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.accounts.isEmpty
                      ? _MailboxEmptyState(
                          mailboxLimit: mailboxLimit,
                          plan: billing.currentPlan,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.accounts.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return _MailboxIntroCard(
                                plan: billing.currentPlan,
                                mailboxLimit: mailboxLimit,
                                used: provider.accounts.length,
                                visibilityDays: pricing.inboxVisibilityDays,
                              );
                            }
                            final account = provider.accounts[i - 1];
                            return _MailboxAccountTile(
                              account: account,
                              onEdit: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    AddEditMailboxDialog(existing: account),
                              ),
                              onDelete: () =>
                                  _confirmDelete(context, provider, account),
                            );
                          },
                        ),
        );
      },
    );
  }
}

void _showMailboxLimitReached(
    BuildContext context, BillingPlan plan, int limit) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Postfach-Limit erreicht'),
      content: Text(
        'Dein ${plan.label}-Plan erlaubt $limit '
        '${limit == 1 ? "Postfach" : "Postfächer"}. '
        'Upgrade auf einen höheren Plan, um weitere zu verbinden.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PricingScreen()),
            );
          },
          child: const Text('Plan upgraden'),
        ),
      ],
    ),
  );
}

class _MailboxIntroCard extends StatelessWidget {
  final BillingPlan plan;
  final int mailboxLimit;
  final int used;
  final int visibilityDays;
  const _MailboxIntroCard({
    required this.plan,
    required this.mailboxLimit,
    required this.used,
    required this.visibilityDays,
  });

  String _quotaLine() {
    final limitLabel = mailboxLimit < 0
        ? 'unbegrenzt'
        : '$used / $mailboxLimit';
    return '${plan.label}-Plan: $limitLabel '
        'Postf${(mailboxLimit == 1) ? "ach" : "ächer"} · '
        '$visibilityDays Tage Inbox-Verlauf';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.accentLightOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.accentBorderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppTheme.accentTextOf(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Postfach-Integration',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentTextOf(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hinterlege ein IMAP-Konto, um Bestell- und Versand-Mails '
                    'automatisch erkennen zu lassen. Polling läuft alle 5 min '
                    'serverseitig — Passwörter werden mit pgp_sym_encrypt '
                    'verschlüsselt gespeichert. Im Inbox-Tab kannst du '
                    'erkannte Deals annehmen.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _quotaLine(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentTextOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailboxAccountTile extends StatelessWidget {
  const _MailboxAccountTile({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  final MailboxAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _statusLabel() {
    if (!account.enabled) return 'Pausiert';
    if (account.lastError != null && account.lastError!.isNotEmpty) {
      return 'Fehler';
    }
    if (account.lastPolledAt == null) return 'Noch nicht gepollt';
    return 'Zuletzt gepollt: ${_relative(account.lastPolledAt!)}';
  }

  Color _statusColor(BuildContext context) {
    if (!account.enabled) return AppTheme.textMutedOf(context);
    if (account.lastError != null && account.lastError!.isNotEmpty) {
      return AppTheme.dangerTextOf(context);
    }
    return AppTheme.successTextOf(context);
  }

  static String _relative(DateTime ts) {
    final delta = DateTime.now().difference(ts);
    if (delta.inMinutes < 1) return 'gerade eben';
    if (delta.inMinutes < 60) return 'vor ${delta.inMinutes} min';
    if (delta.inHours < 24) return 'vor ${delta.inHours} h';
    return 'vor ${delta.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: account.enabled
                ? AppTheme.accentLightOf(context)
                : AppTheme.bgSubtleOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.mail_outline,
            color: account.enabled
                ? AppTheme.accentTextOf(context)
                : AppTheme.textMutedOf(context),
          ),
        ),
        title: Text(
          account.label,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${account.username} · ${account.imapHost}:${account.imapPort}',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textMutedOf(context)),
            ),
            const SizedBox(height: 2),
            Text(
              _statusLabel(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusColor(context),
              ),
            ),
            if (account.lastError != null && account.lastError!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  account.lastError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.dangerTextOf(context),
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppTheme.textMutedOf(context),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppTheme.dangerTextOf(context),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MailboxEmptyState extends StatelessWidget {
  final BillingPlan plan;
  final int mailboxLimit;
  const _MailboxEmptyState({
    required this.plan,
    required this.mailboxLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _MailboxIntroCard(
            plan: plan,
            mailboxLimit: mailboxLimit,
            used: 0,
            visibilityDays:
                PricingPlan.forBillingPlan(plan).inboxVisibilityDays,
          ),
          const SizedBox(height: 32),
          Icon(Icons.mail_outline,
              size: 52, color: AppTheme.textDisabledOf(context)),
          const SizedBox(height: 12),
          Text(
            'Noch kein Postfach hinterlegt.',
            style: TextStyle(color: AppTheme.textMutedOf(context)),
          ),
        ],
      ),
    );
  }
}

/// Free-User sehen keine IMAP-Einstellungen — stattdessen einen klaren
/// Upgrade-Pfad. Genauso bei Plänen, die das Postfach nicht enthalten
/// (mailboxLimit == 0).
class _MailboxFreePlanGate extends StatelessWidget {
  final BillingPlan plan;
  const _MailboxFreePlanGate({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_outline,
                            color: Color(0xFFB45309)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Postfach im Free-Plan nicht enthalten',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Dein aktueller Plan: ${plan.label}. '
                    'Die automatische Erkennung von Bestell- und Versand-'
                    'Mails ist ab dem Starter-Plan verfügbar — höhere '
                    'Pläne erlauben mehr Postfächer und längeren Inbox-'
                    'Verlauf.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _PlanComparisonRow(
                    label: 'Starter',
                    value: '1 Postfach · 7 Tage',
                  ),
                  const _PlanComparisonRow(
                    label: 'Pro',
                    value: '3 Postfächer · 14 Tage',
                  ),
                  const _PlanComparisonRow(
                    label: 'Business',
                    value: '10 Postfächer · 30 Tage',
                  ),
                  const _PlanComparisonRow(
                    label: 'Ultimate',
                    value: '15 Postfächer · 90 Tage',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PricingScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.upgrade),
                      label: const Text('Plan upgraden'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanComparisonRow extends StatelessWidget {
  final String label;
  final String value;
  const _PlanComparisonRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shipping Tab (Carrier API Keys) ─────────────────────────────────────────

class _ShippingTab extends StatefulWidget {
  const _ShippingTab();

  @override
  State<_ShippingTab> createState() => _ShippingTabState();
}

class _ShippingTabState extends State<_ShippingTab> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CarrierCredentialsProvider>().refresh();
      });
    }
  }

  Future<void> _showKeyDialog(
    BuildContext context, {
    required String carrierId,
    required CarrierCredential? existing,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shippingKeyDialogTitle(labelForCarrierId(carrierId))),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'API-Key',
                  hintText: existing?.masked,
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.length < 8) {
                    return l10n.shippingKeyTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                l10n.shippingKeyHelp,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMutedOf(context),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, true);
            },
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<CarrierCredentialsProvider>().setApiKey(
            carrierId: carrierId,
            apiKey: controller.text.trim(),
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.shippingKeySaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String carrierId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shippingDeleteKey),
        content: Text(
          '${labelForCarrierId(carrierId)}: API-Key wirklich entfernen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              l10n.shippingDeleteKey,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<CarrierCredentialsProvider>().deleteApiKey(carrierId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.shippingKeyDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<CarrierCredentialsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgAppOf(context),
          body: provider.isLoading && provider.credentials.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.lastError != null && provider.credentials.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          l10n.shippingNoAccess,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _ShippingIntroCard(),
                        const SizedBox(height: 12),
                        for (final id in supportedCarrierIds) ...[
                          _CarrierTile(
                            carrierId: id,
                            credential: provider.credentialFor(id),
                            onSet: () => _showKeyDialog(
                              context,
                              carrierId: id,
                              existing: provider.credentialFor(id),
                            ),
                            onDelete: () =>
                                _confirmDelete(context, carrierId: id),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
        );
      },
    );
  }
}

class _ShippingIntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      color: AppTheme.accentLightOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.accentBorderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.local_shipping_outlined,
                color: AppTheme.accentTextOf(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shippingIntroTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentTextOf(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.shippingIntroBody,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarrierTile extends StatelessWidget {
  const _CarrierTile({
    required this.carrierId,
    required this.credential,
    required this.onSet,
    required this.onDelete,
  });

  final String carrierId;
  final CarrierCredential? credential;
  final VoidCallback onSet;
  final VoidCallback onDelete;

  String _statusLine(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = credential;
    if (c == null) return l10n.shippingNotConfigured;
    if (c.lastError != null && c.lastError!.isNotEmpty) {
      return l10n.shippingLastError(c.lastError!);
    }
    if (c.lastPolledAt == null) return l10n.shippingLastNeverPolled;
    final fmt = DateFormat.yMd().add_Hm();
    return l10n.shippingLastChecked(fmt.format(c.lastPolledAt!.toLocal()));
  }

  Color _statusColor(BuildContext context) {
    final c = credential;
    if (c == null) return AppTheme.textMutedOf(context);
    if (c.lastError != null && c.lastError!.isNotEmpty) {
      return AppTheme.dangerTextOf(context);
    }
    return AppTheme.textSecondaryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = credential;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.bgSurfaceOf(context),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: AppTheme.accentTextOf(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelForCarrierId(carrierId),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c != null ? c.masked : l10n.shippingNotConfigured,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (c != null)
                  IconButton(
                    tooltip: l10n.shippingDeleteKey,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusLine(context),
              style: TextStyle(
                fontSize: 11,
                color: _statusColor(context),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onSet,
                icon: Icon(c == null ? Icons.add : Icons.edit_outlined),
                label: Text(
                  c == null ? l10n.shippingSetKey : l10n.shippingUpdateKey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
