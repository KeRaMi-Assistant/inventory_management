import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import 'categories_screen.dart';
import 'purchase_orders_screen.dart';
import 'statistics_screen.dart';

/// Hub-Screen für die Warenwirtschaft (AF11).
///
/// Zeigt Kacheln für alle Sub-Bereiche der Warenwirtschaft.
/// Sub-Routen werden per [Navigator.push] geöffnet — kein eigener
/// [MainTab] pro Bereich.
///
/// PLACEHOLDER-STATUS:
/// - Artikelstamm     → PLATZHALTER (kommt in Epic A-full)
/// - Bestellungen     → PLATZHALTER (kommt in Epic C, Task C5)
/// - Lager            → PLATZHALTER (kommt in Epic D, Task D3)
/// - Warengruppen     → PLATZHALTER (kommt in Epic B, Task B4)
/// - Inventur         → PLATZHALTER (kommt in Epic E, Task E3)
/// - Reporting        → zeigt bestehenden [StatisticsScreen]
class WarehouseHubScreen extends StatelessWidget {
  const WarehouseHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final tiles = _buildTiles(context, l10n);

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => tiles[index],
      ),
    );
  }

  List<Widget> _buildTiles(BuildContext context, AppLocalizations l10n) => [
        // ── Artikelstamm ─────────────────────────────────────────────
        // TODO(AF-full): ersetze onTap durch Navigator.push(ProductCatalogScreen)
        _HubTile(
          key: const Key('hubTileProductCatalog'),
          icon: Icons.inventory_2_outlined,
          title: l10n.warehouseHubTileProductCatalog,
          isPlaceholder: true, // Epic A-full
          onTap: () => _showComingSoon(context, l10n),
        ),

        // ── Bestellungen (Epic C) ─────────────────────────────────────
        _HubTile(
          key: const Key('hubTilePurchaseOrders'),
          icon: Icons.shopping_cart_outlined,
          title: l10n.warehouseHubTilePurchaseOrders,
          isPlaceholder: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PurchaseOrdersScreen(),
            ),
          ),
        ),

        // ── Lager (Epic D) ────────────────────────────────────────────
        // TODO(D3): ersetze onTap durch Navigator.push(WarehousesScreen)
        _HubTile(
          key: const Key('hubTileWarehouses'),
          icon: Icons.warehouse_outlined,
          title: l10n.warehouseHubTileWarehouses,
          isPlaceholder: true, // Epic D
          onTap: () => _showComingSoon(context, l10n),
        ),

        // ── Warengruppen / Kategorien (Epic B, Task B4) ───────────────
        _HubTile(
          key: const Key('hubTileCategories'),
          icon: Icons.category_outlined,
          title: l10n.warehouseHubTileCategories,
          isPlaceholder: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CategoriesScreen(),
            ),
          ),
        ),

        // ── Inventur (Epic E) ─────────────────────────────────────────
        // TODO(E3): ersetze onTap durch Navigator.push(StocktakeScreen)
        _HubTile(
          key: const Key('hubTileStocktake'),
          icon: Icons.fact_check_outlined,
          title: l10n.warehouseHubTileStocktake,
          isPlaceholder: true, // Epic E
          onTap: () => _showComingSoon(context, l10n),
        ),

        // ── Reporting ─────────────────────────────────────────────────
        // Zeigt den bestehenden StatisticsScreen (existiert bereits).
        _HubTile(
          key: const Key('hubTileReporting'),
          icon: Icons.bar_chart_outlined,
          title: l10n.warehouseHubTileReporting,
          isPlaceholder: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StatisticsScreen(),
            ),
          ),
        ),
      ];

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.warehouseHubComingSoon),
        content: Text(l10n.warehouseHubComingSoonHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
    );
  }
}

// ─── Hub Tile ──────────────────────────────────────────────────────────────────

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  /// When true, the tile renders a "bald verfügbar" badge.
  final bool isPlaceholder;
  final VoidCallback onTap;

  const _HubTile({
    super.key,
    required this.icon,
    required this.title,
    required this.isPlaceholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // Vertical padding ensures touch target ≥ 48 dp even with short text.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Icon container (48×48 dp touch-target compliant)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentLightOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: AppTheme.accentTextOf(context),
                ),
              ),
              const SizedBox(width: 16),
              // Title
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              // Coming-soon badge or chevron
              if (isPlaceholder)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSubtleOf(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.borderOf(context)),
                  ),
                  child: Text(
                    l10n.warehouseHubComingSoon,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppTheme.textMutedOf(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
