import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/stocktake.dart';
import '../models/warehouse.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_screen_scaffold.dart';
import 'stocktake_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StocktakeScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Inventur-Liste (Epic E, Task E3).
///
/// Sub-Route des Warenwirtschaft-Hubs — kein eigener [MainTab].
/// Navigiert per [Navigator.push] zu [StocktakeDetailScreen].
///
/// **Zwei Modi (additiv, rückwärtskompatibel):**
/// - `embedded == false` (Default): eigener [Scaffold] + [AppBar] für den
///   Vollbild-Push-Pfad (Phone-Hub-Verhalten).
/// - `embedded == true` (T3.4): kein [AppBar] — nur ein [Scaffold] mit FAB
///   und Body, damit der Screen in einer Master-Detail-Detail-Spalte
///   gerendert werden kann (Desktop-Warehouse-Hub).
///
/// A11y-Keys: `stocktakeNewFab`, `stocktakeRow-<id>`.
class StocktakeScreen extends StatelessWidget {
  /// Wenn `true`, wird kein [AppBar] gerendert — geeignet für
  /// Master-Detail-Embeds (T3.4 Warehouse-Hub-Desktop). Default `false`
  /// (rückwärtskompatibel mit allen bisherigen Aufrufern).
  final bool embedded;

  const StocktakeScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer2<InventoryProvider, ActiveWorkspaceProvider>(
      builder: (context, provider, wsProvider, _) {
        final canEdit = wsProvider.role?.canEdit ?? false;
        final stocktakes = provider.stocktakes
            .where((s) => s.deletedAt == null)
            .toList();

        final fab = canEdit
            ? FloatingActionButton.extended(
                key: const Key('stocktakeNewFab'),
                // D4: tooltip → explicit Semantics-Label for screen readers.
                tooltip: l10n.stocktakeNew,
                onPressed: () => _openNewDialog(context, provider),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.stocktakeNew),
              )
            : null;

        final bodyContent = provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.lastError != null
                ? _ErrorState(
                    message: l10n.stocktakeLoadError,
                    onRetry: provider.loadData,
                  )
                : stocktakes.isEmpty
                    ? _EmptyState(canEdit: canEdit)
                    : _StocktakeList(
                        stocktakes: stocktakes,
                        warehouses: provider.warehouses,
                      );

        if (embedded) {
          return Scaffold(
            floatingActionButton: fab,
            body: SafeArea(child: bodyContent),
          );
        }

        return AppScreenScaffold(
          appBar: AppBar(title: Text(l10n.stocktakeTitle)),
          floatingActionButton: fab,
          body: bodyContent,
        );
      },
    );
  }

  Future<void> _openNewDialog(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final result = await showDialog<_NewStocktakeResult>(
      context: context,
      builder: (_) => _NewStocktakeDialog(warehouses: provider.warehouses),
    );
    if (result == null || !context.mounted) return;

    try {
      final created = await provider.startInventory(
        warehouseId: result.warehouseId,
        title: result.title.isNotEmpty ? result.title : null,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StocktakeDetailScreen(stocktake: created),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      AppFeedback.error(context, l10n.stocktakeStartError);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stocktake list
// ─────────────────────────────────────────────────────────────────────────────

class _StocktakeList extends StatelessWidget {
  final List<Stocktake> stocktakes;
  final List<Warehouse> warehouses;

  const _StocktakeList({
    required this.stocktakes,
    required this.warehouses,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stocktakes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _StocktakeCard(
        stocktake: stocktakes[i],
        warehouses: warehouses,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stocktake card
// ─────────────────────────────────────────────────────────────────────────────

class _StocktakeCard extends StatelessWidget {
  final Stocktake stocktake;
  final List<Warehouse> warehouses;

  const _StocktakeCard({
    required this.stocktake,
    required this.warehouses,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warehouse = warehouses
        .where((w) => w.id == stocktake.warehouseId)
        .firstOrNull;

    return Card(
      key: Key('stocktakeRow-${stocktake.id}'),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StocktakeDetailScreen(stocktake: stocktake),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stocktake.title ?? l10n.stocktakeNew,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StocktakeStatusBadge(status: stocktake.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppTheme.textMutedOf(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(stocktake.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                  if (warehouse != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.warehouse_outlined,
                      size: 13,
                      color: AppTheme.textMutedOf(context),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        warehouse.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedOf(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge (exported for use in detail screen)
// ─────────────────────────────────────────────────────────────────────────────

/// Farbiger Status-Badge für eine Inventur.
class StocktakeStatusBadge extends StatelessWidget {
  final StocktakeStatus status;

  const StocktakeStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, bg, fg) = _resolve(context, status, l10n);
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  static (String, Color, Color) _resolve(
    BuildContext context,
    StocktakeStatus s,
    AppLocalizations l10n,
  ) {
    switch (s) {
      case StocktakeStatus.open:
        return (
          l10n.stocktakeStatusOpen,
          AppTheme.bgSubtleOf(context),
          AppTheme.textMutedOf(context),
        );
      case StocktakeStatus.counting:
        return (
          l10n.stocktakeStatusCounting,
          AppTheme.infoBgOf(context),
          AppTheme.infoTextOf(context),
        );
      case StocktakeStatus.closed:
        return (
          l10n.stocktakeStatusClosed,
          AppTheme.successBgOf(context),
          AppTheme.successTextOf(context),
        );
      case StocktakeStatus.cancelled:
        return (
          l10n.stocktakeStatusCancelled,
          AppTheme.dangerBgOf(context),
          AppTheme.dangerTextOf(context),
        );
    }
  }
}

class _StocktakeStatusBadge extends StatelessWidget {
  final StocktakeStatus status;
  const _StocktakeStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) =>
      StocktakeStatusBadge(status: status);
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
              Icons.fact_check_outlined,
              size: 56,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.stocktakeEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              Text(
                l10n.stocktakeEmptyHint,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMutedOf(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
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

// ─────────────────────────────────────────────────────────────────────────────
// New stocktake dialog
// ─────────────────────────────────────────────────────────────────────────────

class _NewStocktakeResult {
  final String title;
  final String? warehouseId;
  const _NewStocktakeResult({required this.title, this.warehouseId});
}

class _NewStocktakeDialog extends StatefulWidget {
  final List<Warehouse> warehouses;

  const _NewStocktakeDialog({required this.warehouses});

  @override
  State<_NewStocktakeDialog> createState() => _NewStocktakeDialogState();
}

class _NewStocktakeDialogState extends State<_NewStocktakeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _selectedWarehouseId;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeWarehouses =
        widget.warehouses.where((w) => w.isActive).toList();

    return AlertDialog(
      title: Text(l10n.stocktakeNew),
      content: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.stocktakeTitleLabel,
                  hintText: l10n.stocktakeTitleHint,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
              ),
              const SizedBox(height: 12),
              if (activeWarehouses.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _selectedWarehouseId,
                  decoration: InputDecoration(
                    labelText: l10n.stocktakeSelectWarehouse,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.stocktakeAllWarehouses),
                    ),
                    ...activeWarehouses.map(
                      (w) => DropdownMenuItem<String?>(
                        value: w.id,
                        child: Text(w.name),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedWarehouseId = val),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(
                context,
                _NewStocktakeResult(
                  title: _titleController.text.trim(),
                  warehouseId: _selectedWarehouseId,
                ),
              );
            }
          },
          child: Text(l10n.stocktakeStartAction),
        ),
      ],
    );
  }
}
