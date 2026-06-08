import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/inventory_provider.dart';
import '../screens/main_section.dart';
import '../screens/pricing_screen.dart';
import '../utils/responsive.dart';
import 'app_nav_rail.dart';
import 'invites_bell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdaptiveNavScaffold (T3.2 + T3.3)
// ─────────────────────────────────────────────────────────────────────────────
//
// **Gewählte Widget-Grenze (Datei-Header-Dok, Plan §T3.2/T3.3):**
//
// Der Name `AppScreenScaffold` (T3.3) war bereits durch ein generisches
// Content-Scaffold belegt (`lib/widgets/app_screen_scaffold.dart`, 7 Nutzer +
// 11 Tests). Eine zweite Klasse gleichen Namens — oder ein Repurpose des
// bestehenden Widgets — hätte Kollisionen und Regressionen an völlig
// unbeteiligten Screens (categories/stocktake/help/…) riskiert. Daher folgt
// diese Extraktion dem im Plan ausdrücklich erlaubten Fallback:
//
//   „Wenn eine saubere Trennung AppScreenScaffold↔AdaptiveNavScaffold zu
//    künstlich wird, ist EIN Widget (AdaptiveNavScaffold) mit interner
//    Phone-AppBar-Bau-Methode akzeptabel."
//
// `AdaptiveNavScaffold` kapselt damit das **komplette Shell-Layout-Gerüst**:
//   1. den narrow/extended-Switch (intern via MediaQuery + Breakpoints,
//      identische Schwellen wie zuvor in main_screen.dart),
//   2. die Phone-Struktur: Scaffold(AppBar[InvitesBell, Search, Help,
//      CSV-Overflow] + NavigationBarTheme>NavigationBar + body),
//   3. die Desktop-Struktur: Scaffold(Row[AppNavRail, Column[ContentHeader,
//      body]]).
//
// Die **Phone-AppBar** (Action-Set: InvitesBell, Search, Help, CSV-Overflow)
// ist hier die Single-Source — sie wird in genau einer Methode gebaut
// (`_buildPhoneAppBar`), parametrisiert über Callbacks. Der **Desktop-Header**
// bleibt `_ContentHeader` (1:1 aus main_screen.dart hierher gezogen, inkl.
// `_BreadcrumbRow`/`_SearchHint`/`_AccountMenu`).
//
// **State + Logik bleiben in `main_screen.dart`:** _selectedIndex, Section-
// Mapping, _buildBody, Visibility, Downgrade-Redirect, Badge-Count, FAB-
// Konstruktion, Shortcuts. Dieses Widget ist rein layout-gebend und erhält
// alles Verhaltensrelevante via Config/Builder/Callbacks. Verhaltens-NEUTRAL,
// pixel-identisch.
//
// **A11y-Keys (1:1 erhalten):** `Key('mainBottomNav')`,
// `Key('main-tab-<section.name>')`, `Key('appBar-help-action')`,
// `Key('appBar-overflow-menu')`. Die Rail-Keys (`mainNavRail`,
// `navRailDestination-<section.name>`) liefert `AppNavRail` selbst.

/// Action-Set des Phone-AppBar-Overflow-Menüs (CSV import/export).
/// War zuvor `_PhoneMenuAction` in `main_screen.dart`.
enum _PhoneMenuAction { csvImport, csvExport }

/// Shell-Scaffold der App: schaltet zwischen Phone- (Bottom-Nav) und
/// Desktop-Layout (NavigationRail + Content-Header) um.
class AdaptiveNavScaffold extends StatelessWidget {
  /// Alle Sektionen in Anzeigereihenfolge (`MainSection.values`).
  final List<MainSection> sections;

  /// Aktuell aktive Sektion (für Bottom-Nav-Selection + Rail-Selection).
  final MainSection selectedSection;

  /// Callback bei Sektions-Wahl (Bottom-Nav-Tap oder Rail-Klick).
  final ValueChanged<MainSection> onSelectSection;

  /// Icon-Resolver für die Desktop-Rail (outline/filled je nach `selected`).
  final Widget Function(MainSection section, bool selected) sectionIconBuilder;

  /// Label-Resolver pro Sektion (l10n aus dem Caller).
  final String Function(MainSection section) sectionLabelBuilder;

  /// Optionaler Badge-Resolver für die Desktop-Rail (z.B. Tracking-Count auf
  /// der Verkauf-Sektion). `null` ⇒ kein Badge.
  final Widget? Function(MainSection section)? railBadgeBuilder;

  /// Icon-Resolver für die Phone-Bottom-Nav (inkl. evtl. Badge).
  final Widget Function(MainSection section, bool selected) bottomIconBuilder;

  /// Der Body des aktiven Tabs (von `main_screen._buildBody` geliefert).
  final Widget body;

  /// Optionaler FAB (von `main_screen` konstruiert).
  final Widget? floatingActionButton;

  /// Sektions-Titel (AppBar-Title auf Phone, Header-Titel auf Desktop).
  final String sectionTitle;

  /// Sub-Tab-Titel für die Desktop-Breadcrumb. `null` ⇒ Sektion hat nur ein
  /// Ziel.
  final String? subTabTitle;

  /// InventoryProvider — wird an den Desktop-Header (`_ContentHeader`)
  /// durchgereicht (identisch zur bisherigen Konstruktion).
  final InventoryProvider provider;

  /// Phone-AppBar + Desktop-Header Action-Callbacks.
  final VoidCallback onSearch;
  final VoidCallback onHelp;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const AdaptiveNavScaffold({
    super.key,
    required this.sections,
    required this.selectedSection,
    required this.onSelectSection,
    required this.sectionIconBuilder,
    required this.sectionLabelBuilder,
    required this.bottomIconBuilder,
    required this.body,
    required this.sectionTitle,
    required this.subTabTitle,
    required this.provider,
    required this.onSearch,
    required this.onHelp,
    required this.onImport,
    required this.onExport,
    this.railBadgeBuilder,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    // T1.3b (Phase B): Shell-Switch-Schwellen — identisch zur bisherigen
    // Berechnung in main_screen.dart.
    // - narrow:   width < Breakpoints.navRail (900).
    // - extended: width >= Breakpoints.railExtended (1200).
    final width = MediaQuery.of(context).size.width;
    final narrow = width < Breakpoints.navRail;
    final extended = width >= Breakpoints.railExtended;

    return narrow
        ? _buildPhoneScaffold(context)
        : _buildDesktopScaffold(context, extended);
  }

  // ── Phone (narrow) ──────────────────────────────────────────────────────

  Widget _buildPhoneScaffold(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: _buildPhoneAppBar(context, l10n),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
          selectedIndex: selectedSection.index,
          onDestinationSelected: (i) =>
              onSelectSection(MainSection.values[i]),
          destinations: [
            for (final section in MainSection.values)
              NavigationDestination(
                key: Key('main-tab-${section.name}'),
                icon: bottomIconBuilder(section, false),
                selectedIcon: bottomIconBuilder(section, true),
                label: sectionLabelBuilder(section),
              ),
          ],
        ),
      ),
      body: body,
    );
  }

  /// Single-Source der Phone-AppBar: Titel + Actions (InvitesBell, Search,
  /// Help[Key appBar-help-action], CSV-Overflow[Key appBar-overflow-menu]).
  PreferredSizeWidget _buildPhoneAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return AppBar(
      title: Text(sectionTitle),
      actions: [
        const InvitesBell(),
        IconButton(
          tooltip: l10n.actionSearch,
          icon: const Icon(Icons.search),
          onPressed: onSearch,
        ),
        IconButton(
          key: const Key('appBar-help-action'),
          tooltip: l10n.actionHelp,
          icon: const Icon(Icons.help_outlined),
          onPressed: onHelp,
        ),
        // T1.7 — CSV import/export on phone via overflow menu.
        PopupMenuButton<_PhoneMenuAction>(
          key: const Key('appBar-overflow-menu'),
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            switch (action) {
              case _PhoneMenuAction.csvImport:
                onImport();
              case _PhoneMenuAction.csvExport:
                onExport();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _PhoneMenuAction.csvImport,
              child: Row(
                children: [
                  Icon(Icons.upload_file_outlined,
                      size: 18, color: AppTheme.textMutedOf(context)),
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
                      size: 18, color: AppTheme.textMutedOf(context)),
                  const SizedBox(width: 12),
                  Text(l10n.appBarMenuCsvExport),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Desktop (extended/non-narrow) ────────────────────────────────────────

  Widget _buildDesktopScaffold(BuildContext context, bool extended) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          AppNavRail(
            sections: sections,
            selectedSection: selectedSection,
            onSelect: onSelectSection,
            extended: extended,
            iconBuilder: sectionIconBuilder,
            labelBuilder: sectionLabelBuilder,
            badgeBuilder: railBadgeBuilder,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ContentHeader(
                  title: sectionTitle,
                  subTabTitle: subTabTitle,
                  provider: provider,
                  onImport: onImport,
                  onExport: onExport,
                  onSearch: onSearch,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
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
