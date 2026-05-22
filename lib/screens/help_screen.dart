import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/inventory_provider.dart';

/// Hilfe-/Onboarding-Seite. Zeigt eine durchsuchbare Sammlung an
/// Sektionen (Quick-Start, Postfach, Deals, Inventory, FAQ, Troubleshooting,
/// …), die ein neuer Nutzer ohne Support-Kontakt durcharbeiten kann.
///
/// Pflege: bei Code-Änderungen prüft der `help-curator`-Subagent
/// (siehe `.claude/agents/help-curator.md`), ob die Hilfeseite noch aktuell
/// ist, und ergänzt fehlende Inhalte inkrementell.
class HelpScreen extends StatefulWidget {
  final bool embedded;
  const HelpScreen({super.key, this.embedded = false});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
  }

  void _clear() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = _buildSections(context, l10n);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? sections
        : sections.where((s) => s.matches(q)).toList(growable: false);

    final body = SafeArea(
      top: !widget.embedded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _HelpSearchField(
              controller: _searchCtrl,
              hintText: l10n.helpSearchHint,
              onChanged: _onChanged,
              onClear: _clear,
            ),
          ),
          if (q.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.helpResultsLabel(filtered.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? _HelpEmptyState(
                    title: l10n.helpSearchEmptyTitle,
                    body: l10n.helpSearchEmptyDesc,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return _HelpSectionCard(
                        section: s,
                        forceExpanded: q.isNotEmpty,
                        defaultExpanded: i == 0,
                        query: q,
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Container(color: AppTheme.bgAppOf(context), child: body);
    }
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: body,
    );
  }

  List<_HelpSection> _buildSections(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return [
      _HelpSection(
        id: 'quickstart',
        title: l10n.helpQuickStart,
        icon: Icons.flag_outlined,
        items: [
          _HelpItem.step('1', l10n.helpStepLoginTitle, l10n.helpStepLoginDesc),
          _HelpItem.step(
            '2',
            l10n.helpStepWorkspaceTitle,
            l10n.helpStepWorkspaceDesc,
          ),
          _HelpItem.step(
            '3',
            l10n.helpStepShopsBuyersTitle,
            l10n.helpStepShopsBuyersDesc,
          ),
          _HelpItem.step(
            '4',
            l10n.helpStepInboxTitle,
            l10n.helpStepInboxDesc,
          ),
          _HelpItem.step(
            '5',
            l10n.helpStepFirstDealTitle,
            l10n.helpStepFirstDealDesc,
          ),
          _HelpItem.step(
            '6',
            l10n.helpStepInventoryTitle,
            l10n.helpStepInventoryDesc,
          ),
          _HelpItem.step(
            '7',
            l10n.helpStepStatsTitle,
            l10n.helpStepStatsDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'inbox',
        title: l10n.helpInboxSection,
        icon: Icons.inbox_outlined,
        items: [
          _HelpItem.text(null, l10n.helpInboxIntro),
          _HelpItem.text(l10n.helpInboxGmailTitle, l10n.helpInboxGmailDesc),
          _HelpItem.text(
            l10n.helpInboxOutlookTitle,
            l10n.helpInboxOutlookDesc,
          ),
          _HelpItem.text(l10n.helpInboxIonosTitle, l10n.helpInboxIonosDesc),
          _HelpItem.text(l10n.helpInboxTabsTitle, l10n.helpInboxTabsDesc),
          _HelpItem.bullet(null, [
            l10n.helpInboxTabSuggestions,
            l10n.helpInboxTabUpdated,
            l10n.helpInboxTabUnclassified,
          ]),
          _HelpItem.text(
            l10n.helpInboxWhitelistTitle,
            l10n.helpInboxWhitelistDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'deals',
        title: l10n.helpDealsSection,
        icon: Icons.receipt_long_outlined,
        items: [
          _HelpItem.text(null, l10n.helpDealsStatusFlow),
          _HelpItem.bullet(null, [
            l10n.helpDealsStatusOrdered,
            l10n.helpDealsStatusInTransit,
            l10n.helpDealsStatusArrived,
            l10n.helpDealsStatusSold,
            l10n.helpDealsStatusDelivered,
          ]),
          _HelpItem.text(
            l10n.helpDealsTrackingTitle,
            l10n.helpDealsTrackingDesc,
          ),
          _HelpItem.text(
            l10n.helpDealsDropShipTitle,
            l10n.helpDealsDropShipDesc,
          ),
          _HelpItem.text(
            l10n.helpDealsRetrackTitle,
            l10n.helpDealsRetrackDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'shipping',
        title: l10n.helpShippingSection,
        icon: Icons.local_shipping_outlined,
        items: [
          _HelpItem.text(
            l10n.helpShippingIntroTitle,
            l10n.helpShippingIntroDesc,
          ),
          _HelpItem.text(
            l10n.helpShippingDhlTitle,
            l10n.helpShippingDhlDesc,
          ),
          _HelpItem.text(
            l10n.helpShippingApiOnlyTitle,
            l10n.helpShippingApiOnlyDesc,
          ),
          _HelpItem.text(
            l10n.helpShippingComingSoonTitle,
            l10n.helpShippingComingSoonDesc,
          ),
          _HelpItem.text(
            l10n.helpShippingKeySafetyTitle,
            l10n.helpShippingKeySafetyDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'inventory',
        title: l10n.helpInventorySection,
        icon: Icons.inventory_2_outlined,
        items: [
          _HelpItem.text(
            l10n.helpInventoryAddTitle,
            l10n.helpInventoryAddDesc,
          ),
          _HelpItem.text(
            l10n.helpInventoryStockTitle,
            l10n.helpInventoryStockDesc,
          ),
          _HelpItem.text(
            l10n.helpInventoryMinStockTitle,
            l10n.helpInventoryMinStockDesc,
          ),
          _HelpItem.text(
            l10n.helpInventorySoldTabTitle,
            l10n.helpInventorySoldTabDesc,
          ),
          _HelpItem.text(
            l10n.helpInventoryStockValueTitle,
            l10n.helpInventoryStockValueDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'entities',
        title: l10n.helpEntitiesSection,
        icon: Icons.people_alt_outlined,
        items: [
          _HelpItem.text(
            l10n.helpEntitiesBuyersTitle,
            l10n.helpEntitiesBuyersDesc,
          ),
          _HelpItem.text(
            l10n.helpEntitiesShopsTitle,
            l10n.helpEntitiesShopsDesc,
          ),
          _HelpItem.text(
            l10n.helpEntitiesSuppliersTitle,
            l10n.helpEntitiesSuppliersDesc,
          ),
          _HelpItem.text(
            l10n.helpEntitiesBuyerColorTitle,
            l10n.helpEntitiesBuyerColorDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'tickets',
        title: l10n.helpTicketsSection,
        icon: Icons.confirmation_number_outlined,
        items: [
          _HelpItem.text(
            l10n.helpTicketsWhatTitle,
            l10n.helpTicketsWhatDesc,
          ),
          _HelpItem.text(
            l10n.helpTicketsArchiveTitle,
            l10n.helpTicketsArchiveDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'stats',
        title: l10n.helpStatsSection,
        icon: Icons.bar_chart_outlined,
        items: [
          _HelpItem.text(l10n.helpStatsKpiTitle, l10n.helpStatsKpiDesc),
          _HelpItem.text(
            l10n.helpStatsChartsTitle,
            l10n.helpStatsChartsDesc,
          ),
          _HelpItem.text(
            l10n.helpStatsFiltersTitle,
            l10n.helpStatsFiltersDesc,
          ),
          _HelpItem.text(l10n.helpStatsTaxTitle, l10n.helpStatsTaxDesc),
        ],
      ),
      _HelpSection(
        id: 'workspace',
        title: l10n.helpWorkspaceSection,
        icon: Icons.workspaces_outlined,
        items: [
          _HelpItem.text(
            l10n.helpWorkspaceWhatTitle,
            l10n.helpWorkspaceWhatDesc,
          ),
          _HelpItem.text(
            l10n.helpWorkspaceInviteTitle,
            l10n.helpWorkspaceInviteDesc,
          ),
          _HelpItem.bullet(l10n.helpWorkspaceRolesTitle, [
            l10n.helpWorkspaceRoleOwner,
            l10n.helpWorkspaceRoleAdmin,
            l10n.helpWorkspaceRoleMember,
          ]),
          _HelpItem.text(
            l10n.helpWorkspacePricingTitle,
            l10n.helpWorkspacePricingDesc,
          ),
          _HelpItem.text(
            l10n.helpWorkspacesHowManyTitle,
            l10n.helpWorkspacesHowManyBody,
          ),
          _HelpItem.text(
            l10n.helpInviteHowTitle,
            l10n.helpInviteHowBody,
          ),
          _HelpItem.text(
            l10n.helpRolesEditorObserverTitle,
            l10n.helpRolesEditorObserverBody,
          ),
        ],
      ),
      _HelpSection(
        id: 'push',
        title: l10n.helpPushSection,
        icon: Icons.notifications_outlined,
        items: [
          _HelpItem.text(l10n.helpPushIosTitle, l10n.helpPushIosDesc),
          _HelpItem.text(l10n.helpPushAndroidTitle, l10n.helpPushAndroidDesc),
          _HelpItem.text(l10n.helpPushWhenTitle, l10n.helpPushWhenDesc),
        ],
      ),
      _HelpSection(
        id: 'faq',
        title: l10n.helpFaqSection,
        icon: Icons.help_outline,
        items: [
          _HelpItem.text(l10n.helpFaqQ1, l10n.helpFaqA1),
          _HelpItem.text(l10n.helpFaqQ2, l10n.helpFaqA2),
          _HelpItem.text(l10n.helpFaqQ3, l10n.helpFaqA3),
          _HelpItem.text(l10n.helpFaqQ4, l10n.helpFaqA4),
          _HelpItem.text(l10n.helpFaqQ5, l10n.helpFaqA5),
          _HelpItem.text(l10n.helpFaqQ6, l10n.helpFaqA6),
          _HelpItem.text(l10n.helpFaqQ7, l10n.helpFaqA7),
          _HelpItem.text(l10n.helpFaqQ8, l10n.helpFaqA8),
          _HelpItem.text(l10n.helpFaqQ9, l10n.helpFaqA9),
          _HelpItem.text(l10n.helpFaqQ10, l10n.helpFaqA10),
          _HelpItem.text(l10n.helpFaqQ11, l10n.helpFaqA11),
          _HelpItem.text(l10n.helpFaqQ12, l10n.helpFaqA12),
          _HelpItem.text(l10n.helpFaqQ13, l10n.helpFaqA13),
          _HelpItem.text(l10n.helpFaqQ14, l10n.helpFaqA14),
          _HelpItem.text(l10n.helpFaqQ15, l10n.helpFaqA15),
          _HelpItem.text(l10n.helpFaqQ16, l10n.helpFaqA16),
          _HelpItem.text(l10n.helpFaqQ17, l10n.helpFaqA17),
          _HelpItem.text(l10n.helpFaqQ18, l10n.helpFaqA18),
          _HelpItem.text(l10n.helpFaqQ19, l10n.helpFaqA19),
          _HelpItem.text(l10n.helpFaqQ20, l10n.helpFaqA20),
          _HelpItem.text(l10n.helpFaqQ21, l10n.helpFaqA21),
          _HelpItem.text(l10n.helpFaqQ22, l10n.helpFaqA22),
          _HelpItem.text(l10n.helpFaqQ23, l10n.helpFaqA23),
          _HelpItem.text(l10n.helpFaqQ24, l10n.helpFaqA24),
        ],
      ),
      _HelpSection(
        id: 'troubleshooting',
        title: l10n.helpTroubleSection,
        icon: Icons.report_problem_outlined,
        items: [
          _HelpItem.text(
            l10n.helpTroubleConnectionTitle,
            l10n.helpTroubleConnectionDesc,
          ),
          _HelpItem.text(
            l10n.helpTroubleImapAuthTitle,
            l10n.helpTroubleImapAuthDesc,
          ),
          _HelpItem.text(
            l10n.helpTroubleSyncStuckTitle,
            l10n.helpTroubleSyncStuckDesc,
          ),
          _HelpItem.text(
            l10n.helpTroubleNotifMissingTitle,
            l10n.helpTroubleNotifMissingDesc,
          ),
          _HelpItem.text(
            l10n.helpTroubleStatsEmptyTitle,
            l10n.helpTroubleStatsEmptyDesc,
          ),
          _HelpItem.text(
            l10n.helpTroubleLoginFailedTitle,
            l10n.helpTroubleLoginFailedDesc,
          ),
          _HelpItem.text(
            l10n.helpTroubleUploadFailedTitle,
            l10n.helpTroubleUploadFailedDesc,
          ),
          _HelpItem.text(l10n.helpTroubleSlowTitle, l10n.helpTroubleSlowDesc),
          _HelpItem.text(
            l10n.helpTroubleLowStockPushTitle,
            l10n.helpTroubleLowStockPushDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'warenwirtschaft',
        title: l10n.helpWarenwirtschaftSection,
        icon: Icons.warehouse_outlined,
        items: [
          _HelpItem.text(
            l10n.helpWarenwirtschaftIntroTitle,
            l10n.helpWarenwirtschaftIntroDesc,
          ),
          _HelpItem.text(
            l10n.helpWarenwirtschaftSubroutesTitle,
            l10n.helpWarenwirtschaftSubroutesDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'product-catalog',
        title: l10n.helpProductCatalogSection,
        icon: Icons.inventory_outlined,
        items: [
          _HelpItem.text(
            l10n.helpProductCatalogWhatTitle,
            l10n.helpProductCatalogWhatDesc,
          ),
          _HelpItem.text(
            l10n.helpProductCatalogNewTitle,
            l10n.helpProductCatalogNewDesc,
          ),
          _HelpItem.text(
            l10n.helpProductCatalogCategoryTitle,
            l10n.helpProductCatalogCategoryDesc,
          ),
          _HelpItem.text(
            l10n.helpProductCatalogDetailTitle,
            l10n.helpProductCatalogDetailDesc,
          ),
          _HelpItem.text(
            l10n.helpProductCatalogMovementsTitle,
            l10n.helpProductCatalogMovementsDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'purchase-orders',
        title: l10n.helpPurchaseOrdersSection,
        icon: Icons.shopping_cart_outlined,
        items: [
          _HelpItem.text(
            l10n.helpPurchaseOrdersWhatTitle,
            l10n.helpPurchaseOrdersWhatDesc,
          ),
          _HelpItem.text(
            l10n.helpPurchaseOrdersNewTitle,
            l10n.helpPurchaseOrdersNewDesc,
          ),
          _HelpItem.text(
            l10n.helpPurchaseOrdersStatusTitle,
            l10n.helpPurchaseOrdersStatusDesc,
          ),
          _HelpItem.text(
            l10n.helpPurchaseOrdersReceiveTitle,
            l10n.helpPurchaseOrdersReceiveDesc,
          ),
          _HelpItem.text(
            l10n.helpPurchaseOrdersPdfTitle,
            l10n.helpPurchaseOrdersPdfDesc,
          ),
          _HelpItem.text(
            l10n.helpPurchaseOrdersReorderTitle,
            l10n.helpPurchaseOrdersReorderDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'warehouses',
        title: l10n.helpWarehousesSection,
        icon: Icons.store_outlined,
        items: [
          _HelpItem.text(
            l10n.helpWarehousesWhatTitle,
            l10n.helpWarehousesWhatDesc,
          ),
          _HelpItem.text(
            l10n.helpWarehousesNewTitle,
            l10n.helpWarehousesNewDesc,
          ),
          _HelpItem.text(
            l10n.helpWarehousesDefaultTitle,
            l10n.helpWarehousesDefaultDesc,
          ),
          _HelpItem.text(
            l10n.helpWarehousesStockTitle,
            l10n.helpWarehousesStockDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'stocktake',
        title: l10n.helpStocktakeSection,
        icon: Icons.checklist_outlined,
        items: [
          _HelpItem.text(
            l10n.helpStocktakeWhatTitle,
            l10n.helpStocktakeWhatDesc,
          ),
          _HelpItem.text(
            l10n.helpStocktakeStartTitle,
            l10n.helpStocktakeStartDesc,
          ),
          _HelpItem.text(
            l10n.helpStocktakeCountTitle,
            l10n.helpStocktakeCountDesc,
          ),
          _HelpItem.text(
            l10n.helpStocktakeCloseTitle,
            l10n.helpStocktakeCloseDesc,
          ),
          _HelpItem.text(
            l10n.helpStocktakeDiffTitle,
            l10n.helpStocktakeDiffDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'ww-reporting',
        title: l10n.helpWwReportingSection,
        icon: Icons.bar_chart_outlined,
        items: [
          _HelpItem.text(
            l10n.helpWwReportingWhatTitle,
            l10n.helpWwReportingWhatDesc,
          ),
          _HelpItem.text(
            l10n.helpWwReportingValuationTitle,
            l10n.helpWwReportingValuationDesc,
          ),
          _HelpItem.text(
            l10n.helpWwReportingTurnoverTitle,
            l10n.helpWwReportingTurnoverDesc,
          ),
          _HelpItem.text(
            l10n.helpWwReportingAbcTitle,
            l10n.helpWwReportingAbcDesc,
          ),
        ],
      ),
      _HelpSection(
        id: 'discord',
        title: l10n.helpDiscordSection,
        icon: Icons.discord,
        custom: const _DiscordSectionContent(),
        items: [
          _HelpItem.text(
            l10n.helpDiscordHowTitle,
            l10n.helpDiscordHowDesc,
          ),
          _HelpItem.text(
            l10n.helpDiscordStep1Title,
            l10n.helpDiscordStep1Desc,
          ),
          _HelpItem.text(
            l10n.helpDiscordStep2Title,
            l10n.helpDiscordStep2Desc,
          ),
          _HelpItem.text(
            l10n.helpDiscordStep3Title,
            l10n.helpDiscordStep3Desc,
          ),
        ],
      ),
      _HelpSection(
        id: 'privacy',
        title: l10n.helpPrivacySection,
        icon: Icons.shield_outlined,
        items: [
          _HelpItem.text(
            l10n.helpPrivacyDataTitle,
            l10n.helpPrivacyDataDesc,
          ),
          _HelpItem.text(
            l10n.helpPrivacySupportTitle,
            l10n.helpPrivacySupportDesc,
          ),
          _HelpItem.text(
            l10n.helpPrivacyNoteTitle,
            l10n.helpPrivacyNoteDesc,
          ),
          _HelpItem.text(
            l10n.helpContactReportTitle,
            l10n.helpContactReportDesc,
          ),
        ],
      ),
    ];
  }
}

/// Suchfeld der Hilfeseite. Mobile-tauglich (volle Breite, klares
/// Clear-Icon), Theme-konform.
class _HelpSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _HelpSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          Icons.search,
          color: AppTheme.textMutedOf(context),
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: Icon(
                  Icons.close,
                  color: AppTheme.textMutedOf(context),
                ),
                onPressed: onClear,
                tooltip: AppLocalizations.of(context).actionClear,
              )
            : null,
        filled: true,
        fillColor: AppTheme.bgSurfaceOf(context),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.accent,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Empty-State, wenn die Suche nichts liefert.
class _HelpEmptyState extends StatelessWidget {
  final String title;
  final String body;
  const _HelpEmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Karte je Hilfe-Sektion mit ExpansionTile.
class _HelpSectionCard extends StatelessWidget {
  final _HelpSection section;
  final bool forceExpanded;
  final bool defaultExpanded;
  final String query;

  const _HelpSectionCard({
    required this.section,
    required this.forceExpanded,
    required this.defaultExpanded,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('help-section-${section.id}'),
          initiallyExpanded: forceExpanded || defaultExpanded,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentLightOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              section.icon,
              color: AppTheme.accentTextOf(context),
              size: 20,
            ),
          ),
          title: _HighlightedText(
            text: section.title,
            query: query,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          subtitle: Text(
            _subtitleFor(section, AppLocalizations.of(context)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMutedOf(context),
            ),
          ),
          children: [
            const SizedBox(height: 4),
            if (section.custom != null) ...[
              section.custom!,
              const SizedBox(height: 12),
            ],
            ...List<Widget>.generate(section.items.length, (i) {
              final item = section.items[i];
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: _HelpItemTile(item: item, query: query),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(_HelpSection s, AppLocalizations l10n) {
    final n = s.items.length;
    if (n == 1) return '1 ${l10n.helpEntryWord}';
    return '$n ${l10n.helpEntriesWord}';
  }
}

/// Eine einzelne Item-Karte innerhalb einer Sektion. Kann Text, einen
/// nummerierten Step oder eine Bullet-Liste rendern.
class _HelpItemTile extends StatelessWidget {
  final _HelpItem item;
  final String query;
  const _HelpItemTile({required this.item, required this.query});

  @override
  Widget build(BuildContext context) {
    switch (item.kind) {
      case _HelpItemKind.step:
        return _StepTile(
          number: item.number ?? '',
          title: item.title ?? '',
          body: item.body ?? '',
          query: query,
        );
      case _HelpItemKind.bullet:
        return _BulletTile(
          title: item.title,
          bullets: item.bullets ?? const [],
          query: query,
        );
      case _HelpItemKind.text:
        return _TextTile(
          title: item.title,
          body: item.body ?? '',
          query: query,
        );
    }
  }
}

/// Item-Variante: nummerierter Step (Quick-Start).
class _StepTile extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final String query;
  const _StepTile({
    required this.number,
    required this.title,
    required this.body,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgAppOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.accentLightOf(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppTheme.accentTextOf(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HighlightedText(
                  text: title,
                  query: query,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                _HighlightedText(
                  text: body,
                  query: query,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Item-Variante: Titel + Fließtext (FAQ, Troubleshooting, generische
/// Sektionen). Erkennt Zeilenumbrüche und „•"-Marker im Body und
/// rendert sie als Bullet-Liste.
class _TextTile extends StatelessWidget {
  final String? title;
  final String body;
  final String query;
  const _TextTile({
    required this.title,
    required this.body,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBulletMarker = body.contains('\n•') || body.startsWith('•');
    final lines = body
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgAppOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            _HighlightedText(
              text: title!,
              query: query,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (hasBulletMarker)
            ..._renderMixed(context, theme, lines)
          else
            _HighlightedText(
              text: body,
              query: query,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _renderMixed(
    BuildContext context,
    ThemeData theme,
    List<String> lines,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final isBullet = raw.startsWith('•');
      final text = isBullet ? raw.substring(1).trimLeft() : raw;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBullet)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: AppTheme.accentTextOf(context),
                  ),
                ),
              Expanded(
                child: _HighlightedText(
                  text: text,
                  query: query,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

/// Item-Variante: optional Titel + Bullet-Liste.
class _BulletTile extends StatelessWidget {
  final String? title;
  final List<String> bullets;
  final String query;
  const _BulletTile({
    required this.title,
    required this.bullets,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgAppOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            _HighlightedText(
              text: title!,
              query: query,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...List<Widget>.generate(bullets.length, (i) {
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.accentTextOf(context),
                    ),
                  ),
                  Expanded(
                    child: _HighlightedText(
                      text: bullets[i],
                      query: query,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Hebt Suchtreffer im Text farbig hervor (gelber Marker + Text-Color
/// passend zum Theme). Bei leerem Query wird normaler Text gerendert.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return Text(text, style: style);
    }
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQ = q.toLowerCase();
    var idx = 0;
    while (idx < text.length) {
      final hit = lowerText.indexOf(lowerQ, idx);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(idx)));
        break;
      }
      if (hit > idx) {
        spans.add(TextSpan(text: text.substring(idx, hit)));
      }
      final end = hit + q.length;
      spans.add(
        TextSpan(
          text: text.substring(hit, end),
          style: TextStyle(
            backgroundColor: AppTheme.accentLightOf(context),
            color: AppTheme.accentTextOf(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      idx = end;
    }
    return RichText(
      text: TextSpan(style: style, children: spans),
    );
  }
}

/// Discord-Inhalt — historischer Sonderfall mit dynamischer Buyer-Liste.
/// Verwendet als `custom`-Inhalt der Discord-Sektion.
class _DiscordSectionContent extends StatelessWidget {
  const _DiscordSectionContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final buyers = context.watch<InventoryProvider>().buyers;
    final dark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF5865F2).withAlpha(dark ? 35 : 12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF5865F2).withAlpha(60),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.discord,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.helpDiscordHowTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.helpDiscordHowDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.helpDiscordConfiguredIds,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        if (buyers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgAppOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.accentTextOf(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.helpDiscordNoBuyers,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.helpDiscordNoBuyersDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...buyers.map((b) {
            final ids = b.discordServerIds;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgAppOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderOf(context)),
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  b.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                subtitle: Text(
                  ids.isEmpty
                      ? l10n.helpDiscordNoServerIds
                      : ids.join(', '),
                  style: TextStyle(
                    fontSize: 12,
                    color: ids.isEmpty
                        ? AppTheme.textMutedOf(context)
                        : const Color(0xFF5865F2),
                  ),
                ),
                trailing: Icon(
                  Icons.discord,
                  color: ids.isEmpty
                      ? AppTheme.textDisabledOf(context)
                      : const Color(0xFF5865F2),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Datenmodell — eine Sektion bündelt Items und kann optional einen
// custom-Widget-Block (z. B. Discord-Buyer-Liste) mitbringen.
// ────────────────────────────────────────────────────────────────────────────

enum _HelpItemKind { text, step, bullet }

class _HelpItem {
  final _HelpItemKind kind;
  final String? number;
  final String? title;
  final String? body;
  final List<String>? bullets;

  const _HelpItem._({
    required this.kind,
    this.number,
    this.title,
    this.body,
    this.bullets,
  });

  factory _HelpItem.text(String? title, String body) =>
      _HelpItem._(kind: _HelpItemKind.text, title: title, body: body);

  factory _HelpItem.step(String number, String title, String body) =>
      _HelpItem._(
        kind: _HelpItemKind.step,
        number: number,
        title: title,
        body: body,
      );

  factory _HelpItem.bullet(String? title, List<String> bullets) =>
      _HelpItem._(
        kind: _HelpItemKind.bullet,
        title: title,
        bullets: bullets,
      );

  bool matches(String q) {
    if (title != null && title!.toLowerCase().contains(q)) return true;
    if (body != null && body!.toLowerCase().contains(q)) return true;
    if (bullets != null) {
      for (final b in bullets!) {
        if (b.toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }
}

class _HelpSection {
  final String id;
  final String title;
  final IconData icon;
  final List<_HelpItem> items;
  final Widget? custom;

  const _HelpSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
    this.custom,
  });

  bool matches(String q) {
    if (title.toLowerCase().contains(q)) return true;
    return items.any((i) => i.matches(q));
  }
}
