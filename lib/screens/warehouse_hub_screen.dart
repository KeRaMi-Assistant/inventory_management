import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';
import 'categories_screen.dart';
import 'product_catalog_screen.dart';
import 'purchase_orders_screen.dart';
import 'statistics_screen.dart';
import 'stocktake_screen.dart';
import 'warehouses_screen.dart';

/// Identifier für die im Hub auswählbare Sub-Bereiche (Desktop-Master-Detail).
///
/// Wird nur im Desktop-Modus genutzt (T3.4): die Master-Spalte (Kacheln)
/// hält über `_selectedTile` fest, welche Detail-Spalte gerendert wird.
/// Auf Phone hat dies keine Bedeutung — dort pusht jede Kachel weiterhin
/// Vollbild.
///
/// **Reporting-Ausnahme:** Es gibt absichtlich KEINEN Enum-Wert für das
/// Reporting-Tile — auch im Desktop-Modus pusht Reporting weiterhin
/// Vollbild (dokumentierter Trade-off, siehe Plan §T3.4).
enum WarehouseTile {
  productCatalog,
  purchaseOrders,
  warehouses,
  categories,
  stocktake,
}

/// Hub-Screen für die Warenwirtschaft (AF11).
///
/// Zeigt Kacheln für alle Sub-Bereiche der Warenwirtschaft.
///
/// **Layout (T3.4):**
/// - **Phone / schmaler Container** (`!isExpanded(maxWidth)`):
///   Hub-Liste, Kachel-Tap pusht Vollbild-Sub-Screen (Verhalten unverändert).
/// - **Desktop / breiter Container** (`isExpanded` oder breiter, ≥ 900 px):
///   Master-Detail-Split — Hub-Kacheln links (280–360 px), gewählter
///   Sub-Bereich rechts als embedded Sub-Screen. Tap setzt `_selectedTile`,
///   kein Navigator-Push für die 5 embedbaren Tiles.
///
/// **Reporting-Tile-Ausnahme:** Das Reporting-Tile pusht IMMER Vollbild,
/// auch auf Desktop. Grund: `StatisticsScreen` ist heute nicht embeddable
/// (das Hub-Reporting-Tile wickelt es in ein inline `Scaffold` mit eigener
/// `AppBar` — siehe Plan §T3.4). Der embeddable-Umbau ist eine eigene,
/// größere Refaktor-Aufgabe und bewusst out-of-scope.
///
/// A11y-Keys: `hubTile<Name>`, `detailPane`, `detailPaneEmpty`.
class WarehouseHubScreen extends StatefulWidget {
  const WarehouseHubScreen({super.key});

  @override
  State<WarehouseHubScreen> createState() => _WarehouseHubScreenState();
}

class _WarehouseHubScreenState extends State<WarehouseHubScreen> {
  /// Aktuell ausgewählte Kachel im Desktop-Master-Detail-Modus.
  ///
  /// `null` = Detail-Pane zeigt den Empty-State-Placeholder.
  /// Wird nur im Desktop-Layout (`isExpanded`/`isLarge`) verwendet. Auf
  /// Phone bleibt der State unbenutzt (Tap pusht Vollbild).
  WarehouseTile? _selectedTile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = isExpanded(constraints.maxWidth) ||
              isLarge(constraints.maxWidth);

          if (!wide) {
            // ── Phone / schmal: bestehendes Verhalten unverändert ───────
            return _HubTileList(
              tiles: _buildTiles(
                context,
                l10n,
                isDesktop: false,
              ),
            );
          }

          // ── Desktop / breit: Master-Detail-Split ────────────────────
          return _DesktopMasterDetail(
            l10n: l10n,
            selectedTile: _selectedTile,
            tiles: _buildTiles(
              context,
              l10n,
              isDesktop: true,
            ),
          );
        },
      ),
    );
  }

  // ── Tile-Builder ──────────────────────────────────────────────────────

  List<Widget> _buildTiles(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isDesktop,
  }) {
    void selectOrPush(WarehouseTile tile, Widget Function() pageBuilder) {
      if (isDesktop) {
        setState(() => _selectedTile = tile);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => pageBuilder()),
        );
      }
    }

    return [
      // ── Artikelstamm ─────────────────────────────────────────────
      _HubTile(
        key: const Key('hubTileProductCatalog'),
        icon: Icons.inventory_2_outlined,
        title: l10n.warehouseHubTileProductCatalog,
        isPlaceholder: false,
        selected: isDesktop && _selectedTile == WarehouseTile.productCatalog,
        onTap: () => selectOrPush(
          WarehouseTile.productCatalog,
          () => const ProductCatalogScreen(),
        ),
      ),

      // ── Bestellungen (Epic C) ─────────────────────────────────────
      _HubTile(
        key: const Key('hubTilePurchaseOrders'),
        icon: Icons.shopping_cart_outlined,
        title: l10n.warehouseHubTilePurchaseOrders,
        isPlaceholder: false,
        selected: isDesktop && _selectedTile == WarehouseTile.purchaseOrders,
        onTap: () => selectOrPush(
          WarehouseTile.purchaseOrders,
          () => const PurchaseOrdersScreen(),
        ),
      ),

      // ── Lager (Epic D, Task D4) ───────────────────────────────────
      _HubTile(
        key: const Key('hubTileWarehouses'),
        icon: Icons.warehouse_outlined,
        title: l10n.warehouseHubTileWarehouses,
        isPlaceholder: false,
        selected: isDesktop && _selectedTile == WarehouseTile.warehouses,
        onTap: () => selectOrPush(
          WarehouseTile.warehouses,
          () => const WarehousesScreen(),
        ),
      ),

      // ── Warengruppen / Kategorien (Epic B, Task B4) ───────────────
      _HubTile(
        key: const Key('hubTileCategories'),
        icon: Icons.category_outlined,
        title: l10n.warehouseHubTileCategories,
        isPlaceholder: false,
        selected: isDesktop && _selectedTile == WarehouseTile.categories,
        onTap: () => selectOrPush(
          WarehouseTile.categories,
          () => const CategoriesScreen(),
        ),
      ),

      // ── Inventur (Epic E, Task E3) ────────────────────────────────
      _HubTile(
        key: const Key('hubTileStocktake'),
        icon: Icons.fact_check_outlined,
        title: l10n.warehouseHubTileStocktake,
        isPlaceholder: false,
        selected: isDesktop && _selectedTile == WarehouseTile.stocktake,
        onTap: () => selectOrPush(
          WarehouseTile.stocktake,
          () => const StocktakeScreen(),
        ),
      ),

      // ── Reporting (Sonderfall — IMMER Vollbild-Push) ──────────────
      // Auch auf Desktop pusht Reporting Vollbild, weil StatisticsScreen
      // heute nicht embeddable ist (inline Scaffold + AppBar). Siehe
      // Plan §T3.4 — bewusster, dokumentierter Trade-off.
      _HubTile(
        key: const Key('hubTileReporting'),
        icon: Icons.bar_chart_outlined,
        title: l10n.warehouseHubTileReporting,
        isPlaceholder: false,
        // Reporting kann nicht selected sein (kein Enum-Wert).
        selected: false,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(l10n.warehouseHubTileReporting)),
              body: const StatisticsScreen(),
            ),
          ),
        ),
      ),
    ];
  }
}

// ─── Hub Tile List (Phone) ─────────────────────────────────────────────────

class _HubTileList extends StatelessWidget {
  final List<Widget> tiles;

  const _HubTileList({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => tiles[index],
    );
  }
}

// ─── Desktop-Master-Detail ─────────────────────────────────────────────────

class _DesktopMasterDetail extends StatelessWidget {
  final AppLocalizations l10n;
  final WarehouseTile? selectedTile;
  final List<Widget> tiles;

  const _DesktopMasterDetail({
    required this.l10n,
    required this.selectedTile,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Master-Spalte: Hub-Kacheln ──────────────────────────────
        SizedBox(
          width: 320,
          child: _HubTileList(tiles: tiles),
        ),

        // ── Trennlinie ─────────────────────────────────────────────
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppTheme.borderOf(context),
        ),

        // ── Detail-Spalte ──────────────────────────────────────────
        Expanded(
          child: _DetailPane(
            selectedTile: selectedTile,
            l10n: l10n,
          ),
        ),
      ],
    );
  }
}

class _DetailPane extends StatelessWidget {
  final WarehouseTile? selectedTile;
  final AppLocalizations l10n;

  const _DetailPane({
    required this.selectedTile,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final tile = selectedTile;
    if (tile == null) {
      return _DetailPaneEmpty(l10n: l10n);
    }
    return _DetailPaneContent(tile: tile);
  }
}

class _DetailPaneEmpty extends StatelessWidget {
  final AppLocalizations l10n;

  const _DetailPaneEmpty({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('detailPaneEmpty'),
      color: AppTheme.bgAppOf(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 56,
                color: AppTheme.textMutedOf(context),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.warehouseHubDetailPaneEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPaneContent extends StatelessWidget {
  final WarehouseTile tile;

  const _DetailPaneContent({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('detailPane'),
      color: AppTheme.bgAppOf(context),
      child: _buildEmbeddedSubScreen(tile),
    );
  }

  Widget _buildEmbeddedSubScreen(WarehouseTile tile) {
    switch (tile) {
      case WarehouseTile.productCatalog:
        return const ProductCatalogScreen(embedded: true);
      case WarehouseTile.purchaseOrders:
        return const PurchaseOrdersScreen(embedded: true);
      case WarehouseTile.warehouses:
        return const WarehousesScreen(embedded: true);
      case WarehouseTile.categories:
        return const CategoriesScreen(embedded: true);
      case WarehouseTile.stocktake:
        return const StocktakeScreen(embedded: true);
    }
  }
}

// ─── Hub Tile ──────────────────────────────────────────────────────────────────

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;

  /// When true, the tile renders a "bald verfügbar" badge.
  final bool isPlaceholder;

  /// True wenn diese Kachel im Desktop-Master-Detail-Modus aktuell ausgewählt
  /// ist — rendert einen sichtbaren Selektions-Indikator. Auf Phone immer
  /// `false`.
  final bool selected;

  final VoidCallback onTap;

  const _HubTile({
    super.key,
    required this.icon,
    required this.title,
    required this.isPlaceholder,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? AppTheme.accentLightOf(context) : null,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: AppTheme.accentTextOf(context),
                width: 1.5,
              ),
            )
          : null,
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
