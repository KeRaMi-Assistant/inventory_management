import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/section_hub_screen.dart';
import 'categories_screen.dart';
import 'inventory_screen.dart';
import 'product_catalog_screen.dart';
import 'purchase_orders_screen.dart';
import 'statistics_screen.dart';
import 'stocktake_screen.dart';
import 'suppliers_screen.dart';
import 'warehouses_screen.dart';

/// Hub-Screen für die Warenwirtschaft (AF11).
///
/// Delegiert das gesamte Hub-Layout (Phone-Liste / Desktop-Master-Detail) an
/// [SectionHubScreen]. Verhalten und A11y-Keys (`hubTile<Name>`,
/// `detailPane`, `detailPaneEmpty`) sind identisch mit der früheren
/// baked-in Implementierung.
///
/// **T3.1b — Reporting embeddable:** Das Reporting-Tile nutzt jetzt
/// `StatisticsScreen(embedded: true)` via `build:` statt `onPushFullscreen`.
/// Auf Phone wird es von [SectionHubScreen] in ein Scaffold gewrappt (mit
/// AppBar title = label), auf Desktop erscheint es in der Detail-Pane —
/// konsistent mit allen anderen Warenwirtschaft-Kacheln.
///
/// **T1.8b — Icon-Disambiguierung:** Artikelstamm-Kachel verwendet jetzt
/// `Icons.style_outlined` statt `Icons.inventory_2_outlined`, das mit dem
/// Bestand/Inventory-Icon kollidierte.
class WarehouseHubScreen extends StatelessWidget {
  const WarehouseHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SectionHubScreen(
      tiles: [
        // ── Bestand (Nav Tier-2a: neue Default-Kachel, erste Position) ─
        SectionHubTile(
          key: const Key('hubTileInventory'),
          icon: Icons.inventory_2_outlined,
          label: l10n.warehouseHubTileInventory,
          build: () => const InventoryScreen(embedded: true),
        ),

        // ── Artikelstamm ──────────────────────────────────────────────
        // T1.8b: Icons.style_outlined (war: Icons.inventory_2_outlined).
        SectionHubTile(
          key: const Key('hubTileProductCatalog'),
          icon: Icons.style_outlined,
          label: l10n.warehouseHubTileProductCatalog,
          build: () => const ProductCatalogScreen(embedded: true),
        ),

        // ── Bestellungen (Epic C) ─────────────────────────────────────
        SectionHubTile(
          key: const Key('hubTilePurchaseOrders'),
          icon: Icons.shopping_cart_outlined,
          label: l10n.warehouseHubTilePurchaseOrders,
          build: () => const PurchaseOrdersScreen(embedded: true),
        ),

        // ── Lieferanten (Nav Tier-2a) ─────────────────────────────────
        SectionHubTile(
          key: const Key('hubTileSuppliers'),
          icon: Icons.handshake_outlined,
          label: l10n.warehouseHubTileSuppliers,
          build: () => const SuppliersScreen(embedded: true),
        ),

        // ── Lager / Standorte (Epic D, Task D4) ──────────────────────
        SectionHubTile(
          key: const Key('hubTileWarehouses'),
          icon: Icons.warehouse_outlined,
          label: l10n.warehouseHubTileWarehouses,
          build: () => const WarehousesScreen(embedded: true),
        ),

        // ── Warengruppen / Kategorien (Epic B, Task B4) ───────────────
        SectionHubTile(
          key: const Key('hubTileCategories'),
          icon: Icons.category_outlined,
          label: l10n.warehouseHubTileCategories,
          build: () => const CategoriesScreen(embedded: true),
        ),

        // ── Inventur (Epic E, Task E3) ────────────────────────────────
        SectionHubTile(
          key: const Key('hubTileStocktake'),
          icon: Icons.fact_check_outlined,
          label: l10n.warehouseHubTileStocktake,
          build: () => const StocktakeScreen(embedded: true),
        ),

        // ── Reporting — T3.1b: embeddable Detail-Pane ────────────────
        // StatisticsScreen(embedded: true) liefert nur TabBar + TabBarView
        // ohne eigenen Scaffold/AppBar. SectionHubScreen wrappt das auf
        // Phone selbst in ein Scaffold(AppBar(title: label)), auf Desktop
        // landet es direkt in der Detail-Pane. Icon wird dadurch automatisch
        // chevron_right (konsistent mit allen anderen Kacheln).
        SectionHubTile(
          key: const Key('hubTileReporting'),
          icon: Icons.bar_chart_outlined,
          label: l10n.warehouseHubTileReporting,
          build: () => const StatisticsScreen(embedded: true),
        ),
      ],
    );
  }
}
