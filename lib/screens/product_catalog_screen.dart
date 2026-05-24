import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/add_edit_product_dialog.dart';
import '../widgets/app_screen_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProductCatalogScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Artikelstamm-Übersicht (Epic A-full).
///
/// Zeigt alle [Product]-Einträge des aktiven Workspaces als vertikale Cards
/// mit Name, SKU, Kategorie-Name, Standard-EK/-VK und Aktiv-Status.
///
/// States: empty, loading, error (mit Retry), no-permission (Viewer →
/// kein FAB, kein Edit — schreibgeschützter Read-Only-Modus).
///
/// Sub-Route des Warenwirtschaft-Hubs — wird per [Navigator.push] geöffnet.
///
/// **Zwei Modi (additiv, rückwärtskompatibel):**
/// - `embedded == false` (Default): eigener [Scaffold] + [AppBar] für den
///   Vollbild-Push-Pfad (Phone-Hub-Verhalten).
/// - `embedded == true` (T3.4): kein [AppBar] — nur ein [Scaffold] mit FAB
///   und Body, damit der Screen in einer Master-Detail-Detail-Spalte
///   gerendert werden kann (Desktop-Warehouse-Hub).
///
/// A11y-Keys: `productNewFab`, `productCatalogCard-<id>`.
/// Mobile-First: 360×640 + 390×844, vertikale Cards, SafeArea,
/// Touch-Targets ≥ 48 dp, Theme-Tokens.
class ProductCatalogScreen extends StatelessWidget {
  /// Wenn `true`, wird kein [AppBar] gerendert — geeignet für
  /// Master-Detail-Embeds (T3.4 Warehouse-Hub-Desktop). Default `false`
  /// (rückwärtskompatibel mit allen bisherigen Aufrufern).
  final bool embedded;

  const ProductCatalogScreen({super.key, this.embedded = false});

  void _openDialog(BuildContext context, {Product? product}) {
    showDialog<void>(
      context: context,
      builder: (_) => AddEditProductDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer2<InventoryProvider, ActiveWorkspaceProvider>(
      builder: (context, provider, wsProvider, _) {
        final canEdit = wsProvider.role?.canEdit ?? false;
        final products = provider.products;

        final fab = canEdit
            ? FloatingActionButton.extended(
                key: const Key('productNewFab'),
                // D4: tooltip → explicit Semantics-Label for screen readers.
                tooltip: l10n.productNew,
                onPressed: () => _openDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.productNew),
              )
            : null;

        final bodyContent = provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.lastError != null
                ? _ErrorState(
                    message: l10n.productCatalogLoadError,
                    onRetry: () => provider.loadData(),
                  )
                : products.isEmpty
                    ? _EmptyState(canEdit: canEdit)
                    : _ProductList(
                        products: products,
                        provider: provider,
                        canEdit: canEdit,
                        onTap: (p) => _openDialog(context, product: p),
                      );

        if (embedded) {
          return Scaffold(
            floatingActionButton: fab,
            body: SafeArea(child: bodyContent),
          );
        }

        return AppScreenScaffold(
          appBar: AppBar(title: Text(l10n.productCatalogTitle)),
          floatingActionButton: fab,
          body: bodyContent,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product list
// ─────────────────────────────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  final List<Product> products;
  final InventoryProvider provider;
  final bool canEdit;
  final void Function(Product) onTap;

  const _ProductList({
    required this.products,
    required this.provider,
    required this.canEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final product = products[i];
        return _ProductCard(
          key: Key('productCatalogCard-${product.id}'),
          product: product,
          provider: provider,
          canEdit: canEdit,
          onTap: () => onTap(product),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final InventoryProvider provider;
  final bool canEdit;
  final VoidCallback onTap;

  const _ProductCard({
    super.key,
    required this.product,
    required this.provider,
    required this.canEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Resolve category name from provider (O(n) but list is small)
    final category = provider.productCategories
        .where((c) => c.id == product.categoryId)
        .firstOrNull;

    final hasCostPrice = product.defaultCostPrice != null;
    final hasSalePrice = product.defaultSalePrice != null;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: canEdit ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container (48×48 dp touch-target compliant)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: product.isActive
                      ? AppTheme.accentLightOf(context)
                      : AppTheme.bgSubtleOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 22,
                  color: product.isActive
                      ? AppTheme.accentTextOf(context)
                      : AppTheme.textMutedOf(context),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row + active badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActiveBadge(isActive: product.isActive),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // SKU + category
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        if (product.sku != null && product.sku!.isNotEmpty)
                          _MetaChip(
                            icon: Icons.tag,
                            label: product.sku!,
                          ),
                        if (category != null)
                          _MetaChip(
                            icon: Icons.folder_outlined,
                            label: category.name,
                          ),
                      ],
                    ),
                    // Prices
                    if (hasCostPrice || hasSalePrice) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (hasCostPrice)
                            _PriceLabel(
                              label: l10n.productDefaultCostPrice,
                              price: product.defaultCostPrice!,
                            ),
                          if (hasSalePrice)
                            _PriceLabel(
                              label: l10n.productDefaultSalePrice,
                              price: product.defaultSalePrice!,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Chevron only when editable
              if (canEdit) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppTheme.textMutedOf(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveBadge extends StatelessWidget {
  final bool isActive;

  const _ActiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.accentSelectedBgOf(context)
            : AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? AppTheme.accentBorderOf(context)
              : AppTheme.borderOf(context),
        ),
      ),
      child: Text(
        isActive ? l10n.productIsActive : l10n.commonNotSet,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive
              ? AppTheme.accentTextOf(context)
              : AppTheme.textMutedOf(context),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textMutedOf(context),
          ),
        ),
      ],
    );
  }
}

class _PriceLabel extends StatelessWidget {
  final String label;
  final double price;

  const _PriceLabel({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          TextSpan(
            text: '€ ${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool canEdit;

  const _EmptyState({required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.productCatalogEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canEdit
                  ? l10n.productCatalogEmptyHint
                  : l10n.productCatalogViewerHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.danger,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
