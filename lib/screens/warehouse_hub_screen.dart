import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/section_hub_screen.dart';
import 'categories_screen.dart';
import 'product_catalog_screen.dart';
import 'purchase_orders_screen.dart';
import 'statistics_screen.dart';
import 'stocktake_screen.dart';
import 'warehouses_screen.dart';

/// Hub-Screen für die Warenwirtschaft (AF11).
///
/// Delegiert das gesamte Hub-Layout (Phone-Liste / Desktop-Master-Detail) an
/// [SectionHubScreen]. Verhalten und A11y-Keys (`hubTile<Name>`,
/// `detailPane`, `detailPaneEmpty`) sind identisch mit der früheren
/// baked-in Implementierung.
///
/// **T1.3 — Reporting-Doppelung entfernt:** Das ehemalige Reporting-Tile
/// (das `StatisticsScreen` in einem inline-Scaffold renderte) wurde durch
/// einen direkten `Navigator.push`-Aufruf auf `StatisticsScreen` ersetzt.
/// Das eliminiert die doppelte, leicht abweichende Statistics-Instanz.
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
        // ── Artikelstamm ─────────────────────────────────────────────
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

        // ── Lager (Epic D, Task D4) ───────────────────────────────────
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

        // ── Reporting — T1.3: direkter Push auf StatisticsScreen ──────
        // Das frühere inline Scaffold + StatisticsScreen-Embed ist entfernt.
        // onPushFullscreen navigiert zur echten StatisticsScreen-Instanz
        // (kein doppelter, abweichender Inline-Screen mehr).
        SectionHubTile(
          key: const Key('hubTileReporting'),
          icon: Icons.bar_chart_outlined,
          label: l10n.warehouseHubTileReporting,
          onPushFullscreen: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatisticsScreen()),
          ),
        ),
      ],
    );
  }
}
