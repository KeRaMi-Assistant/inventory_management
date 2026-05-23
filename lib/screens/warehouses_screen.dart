import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/warehouse.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_screen_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WarehousesScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Lager-Verwaltung (Epic D, Task D4).
///
/// Zeigt alle [Warehouse]-Einträge des aktiven Workspaces als vertikale Cards.
/// Sub-Route des Warenwirtschaft-Hubs — wird per [Navigator.push] geöffnet.
///
/// **Zwei Modi (additiv, rückwärtskompatibel):**
/// - `embedded == false` (Default): eigener [Scaffold] + [AppBar] für den
///   Vollbild-Push-Pfad (Phone-Hub-Verhalten).
/// - `embedded == true` (T3.4): kein [AppBar] — nur ein [Scaffold] mit FAB
///   und Body, damit der Screen in einer Master-Detail-Detail-Spalte
///   gerendert werden kann (Desktop-Warehouse-Hub).
///
/// States: empty, loading, error (mit Retry), no-permission (Viewer → kein FAB/Edit/Delete).
///
/// A11y-Keys: `warehouseNewFab`, `warehouseRow-<id>`.
class WarehousesScreen extends StatelessWidget {
  /// Wenn `true`, wird kein [AppBar] gerendert — geeignet für
  /// Master-Detail-Embeds (T3.4 Warehouse-Hub-Desktop). Default `false`
  /// (rückwärtskompatibel mit allen bisherigen Aufrufern).
  final bool embedded;

  const WarehousesScreen({super.key, this.embedded = false});

  Future<void> _confirmDelete(
    BuildContext context,
    InventoryProvider provider,
    Warehouse warehouse,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.warehousesTitle),
        content: Text(l10n.warehouseDeletePrompt(warehouse.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white, // justified: white on danger-red
            ),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await provider.deleteWarehouse(warehouse.id);
    }
  }

  void _openDialog(BuildContext context, {Warehouse? warehouse}) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddEditWarehouseDialog(warehouse: warehouse),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer2<InventoryProvider, ActiveWorkspaceProvider>(
      builder: (context, provider, wsProvider, _) {
        final canEdit = wsProvider.role?.canEdit ?? false;
        final warehouses = provider.warehouses;

        final fab = canEdit
            ? FloatingActionButton.extended(
                key: const Key('warehouseNewFab'),
                onPressed: () => _openDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.warehouseNew),
              )
            : null;

        final bodyContent = provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.lastError != null
                ? _ErrorState(
                    message: l10n.warehousesLoadError,
                    onRetry: () => provider.loadData(),
                  )
                : warehouses.isEmpty
                    ? _EmptyState(canEdit: canEdit)
                    : _WarehouseList(
                        warehouses: warehouses,
                        canEdit: canEdit,
                        onEdit: (w) => _openDialog(context, warehouse: w),
                        onDelete: (w) => _confirmDelete(context, provider, w),
                      );

        if (embedded) {
          return Scaffold(
            floatingActionButton: fab,
            body: SafeArea(child: bodyContent),
          );
        }

        return AppScreenScaffold(
          appBar: AppBar(title: Text(l10n.warehousesTitle)),
          floatingActionButton: fab,
          body: bodyContent,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Warehouse list
// ─────────────────────────────────────────────────────────────────────────────

class _WarehouseList extends StatelessWidget {
  final List<Warehouse> warehouses;
  final bool canEdit;
  final void Function(Warehouse) onEdit;
  final void Function(Warehouse) onDelete;

  const _WarehouseList({
    required this.warehouses,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: warehouses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final w = warehouses[i];
        return _WarehouseCard(
          key: Key('warehouseRow-${w.id}'),
          warehouse: w,
          l10n: l10n,
          canEdit: canEdit,
          onEdit: () => onEdit(w),
          onDelete: () => onDelete(w),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Warehouse card
// ─────────────────────────────────────────────────────────────────────────────

class _WarehouseCard extends StatelessWidget {
  final Warehouse warehouse;
  final AppLocalizations l10n;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WarehouseCard({
    super.key,
    required this.warehouse,
    required this.l10n,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final w = warehouse;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: canEdit ? onEdit : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon container — 48×48 touch-target compliant
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: w.isActive
                      ? AppTheme.accentLightOf(context)
                      : AppTheme.bgSubtleOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warehouse_outlined,
                  size: 22,
                  color: w.isActive
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            w.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (w.isDefault) ...[
                          const SizedBox(width: 8),
                          _DefaultBadge(l10n: l10n),
                        ],
                        if (!w.isActive) ...[
                          const SizedBox(width: 6),
                          _InactiveBadge(),
                        ],
                      ],
                    ),
                    if (w.address != null && w.address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        w.address!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMutedOf(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Actions — only if canEdit
              if (canEdit) ...[
                SizedBox(
                  width: 40,
                  height: 48,
                  child: IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppTheme.textMutedOf(context),
                    ),
                    tooltip: l10n.actionEdit,
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 48,
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.danger,
                    ),
                    tooltip: l10n.actionDelete,
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  final AppLocalizations l10n;

  const _DefaultBadge({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentLightOf(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accentTextOf(context).withValues(alpha: 0.3)),
      ),
      child: Text(
        l10n.warehouseDefault,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.accentTextOf(context),
        ),
      ),
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Text(
        l10n.warehouseInactiveBadge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.textMutedOf(context),
        ),
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
              Icons.warehouse_outlined,
              size: 56,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.warehousesEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.warehousesEmptyHint,
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

// ─────────────────────────────────────────────────────────────────────────────
// AddEditWarehouseDialog
// ─────────────────────────────────────────────────────────────────────────────

/// Add/Edit-Dialog für [Warehouse].
///
/// Felder: name (Pflicht, 1–100), address (optional), is_default (Switch),
/// is_active (Switch).
///
/// Default-Konflikt-Strategie: Wird ein Lager mit `is_default: true`
/// gespeichert, setzt der Provider das bisherige Default-Lager zuerst auf
/// `is_default: false` (zwei sequentielle Schreibvorgänge). Damit wird die
/// Partial-UNIQUE-Constraint `UNIQUE (workspace_id) WHERE is_default AND
/// deleted_at IS NULL` auf der DB nie verletzt.
///
/// Mobile-Checkliste: [SingleChildScrollView] + [SafeArea] +
/// [MediaQuery.viewInsetsOf].
class _AddEditWarehouseDialog extends StatefulWidget {
  final Warehouse? warehouse;

  const _AddEditWarehouseDialog({this.warehouse});

  @override
  State<_AddEditWarehouseDialog> createState() =>
      _AddEditWarehouseDialogState();
}

class _AddEditWarehouseDialogState extends State<_AddEditWarehouseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isDefault = false;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    if (w != null) {
      _nameCtrl.text = w.name;
      _addressCtrl.text = w.address ?? '';
      _isDefault = w.isDefault;
      _isActive = w.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final provider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);

    final now = DateTime.now().toUtc();

    final warehouse = Warehouse(
      id: widget.warehouse?.id ?? const Uuid().v4(),
      workspaceId: '', // injected by repository
      userId: '', // injected by repository
      name: Validators.sanitize(_nameCtrl.text),
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      isDefault: _isDefault,
      isActive: _isActive,
      createdAt: widget.warehouse?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      // ── Default-Konflikt-Strategie ────────────────────────────────────────
      // Wenn dieses Lager als Standard gesetzt wird, zuerst das bisherige
      // Default-Lager zurücksetzen. So wird die DB-Constraint
      // UNIQUE (workspace_id) WHERE is_default AND deleted_at IS NULL
      // nie verletzt.
      if (_isDefault) {
        final currentDefault = provider.defaultWarehouse;
        if (currentDefault != null && currentDefault.id != warehouse.id) {
          await provider.updateWarehouse(
            currentDefault.copyWith(isDefault: false),
          );
        }
      }

      if (widget.warehouse != null) {
        await provider.updateWarehouse(warehouse);
      } else {
        await provider.addWarehouse(warehouse);
      }
      if (context.mounted) navigator.pop();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.pushSaveFailed('$e')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.warehouse != null;
    final title = isEditing ? l10n.warehouseEdit : l10n.warehouseNew;

    return Dialog(
      // Constrain width on desktop, full-width on phone.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Title bar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        tooltip: l10n.actionClose,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ── Form body — scrollable for small phones ──────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name field (required)
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: '${l10n.warehouseNameLabel} *',
                              prefixIcon: const Icon(
                                Icons.warehouse_outlined,
                                size: 18,
                              ),
                            ),
                            validator: (v) => Validators.validateRequired(
                              v,
                              label: l10n.warehouseNameLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Address field (optional)
                          TextFormField(
                            controller: _addressCtrl,
                            textInputAction: TextInputAction.done,
                            maxLength: 300,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: l10n.warehouseAddressLabel,
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                              ),
                            ),
                            onFieldSubmitted: (_) => _save(),
                          ),
                          const SizedBox(height: 4),
                          // is_default toggle
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.warehouseIsDefaultLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            value: _isDefault,
                            onChanged: (v) => setState(() => _isDefault = v),
                          ),
                          // is_active toggle
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.warehouseIsActiveLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Action buttons ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.actionCancel),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.actionSave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
