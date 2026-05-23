import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/product_category.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/validators.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CategoriesScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Warengruppen-Verwaltung (Epic B, Task B4).
///
/// Zeigt alle [ProductCategory]-Einträge des aktiven Workspaces.
/// Unterkategorien werden eingerückt unter ihrer Elternkategorie angezeigt
/// (max. 2 Ebenen, App-seitig validiert).
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
/// A11y-Keys: `categoryNewFab`, `categoryRow-<id>`.
class CategoriesScreen extends StatelessWidget {
  /// Wenn `true`, wird kein [AppBar] gerendert — geeignet für
  /// Master-Detail-Embeds (T3.4 Warehouse-Hub-Desktop). Default `false`
  /// (rückwärtskompatibel mit allen bisherigen Aufrufern).
  final bool embedded;

  const CategoriesScreen({super.key, this.embedded = false});

  Future<void> _confirmDelete(
    BuildContext context,
    InventoryProvider provider,
    ProductCategory category,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.categoryDelete),
        content: Text(l10n.categoryDeletePrompt(category.name)),
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
      await provider.deleteProductCategory(category.id);
    }
  }

  void _openAddDialog(BuildContext context, {ProductCategory? category}) {
    showDialog<void>(
      context: context,
      builder: (_) => AddEditCategoryDialog(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer2<InventoryProvider, ActiveWorkspaceProvider>(
      builder: (context, provider, wsProvider, _) {
        final canEdit = wsProvider.role?.canEdit ?? false;
        final categories = provider.productCategories;

        // Sort: top-level first by sortOrder, then children under their parent.
        final sorted = _buildSortedList(categories);

        return Scaffold(
          appBar: embedded
              ? null
              : AppBar(
                  title: Text(l10n.categoriesTitle),
                ),
          floatingActionButton: canEdit
              ? FloatingActionButton.extended(
                  key: const Key('categoryNewFab'),
                  onPressed: () => _openAddDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.categoryNew),
                )
              : null,
          body: SafeArea(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.lastError != null
                    ? _ErrorState(
                        message: l10n.categoriesLoadError,
                        onRetry: () => provider.loadData(),
                      )
                    : sorted.isEmpty
                        ? _EmptyState(canEdit: canEdit)
                        : _CategoryList(
                            items: sorted,
                            canEdit: canEdit,
                            onEdit: (c) => _openAddDialog(context, category: c),
                            onDelete: (c) =>
                                _confirmDelete(context, provider, c),
                          ),
          ),
        );
      },
    );
  }

  /// Returns categories in display order: top-level items sorted by sortOrder,
  /// with children inserted immediately after their parent, also sorted.
  static List<_CategoryRow> _buildSortedList(
    List<ProductCategory> categories,
  ) {
    final topLevel = categories
        .where((c) => c.parentId == null && c.deletedAt == null)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final result = <_CategoryRow>[];
    for (final parent in topLevel) {
      result.add(_CategoryRow(category: parent, depth: 0));
      final children = categories
          .where((c) => c.parentId == parent.id && c.deletedAt == null)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final child in children) {
        result.add(_CategoryRow(category: child, depth: 1));
      }
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class used only for display ordering
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryRow {
  final ProductCategory category;

  /// 0 = top-level, 1 = child
  final int depth;

  const _CategoryRow({required this.category, required this.depth});
}

// ─────────────────────────────────────────────────────────────────────────────
// Category list
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  final List<_CategoryRow> items;
  final bool canEdit;
  final void Function(ProductCategory) onEdit;
  final void Function(ProductCategory) onDelete;

  const _CategoryList({
    required this.items,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final row = items[i];
        final cat = row.category;
        final isChild = row.depth == 1;

        return Padding(
          padding: EdgeInsets.only(left: isChild ? 24.0 : 0.0),
          child: Card(
            key: Key('categoryRow-${cat.id}'),
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: canEdit ? () => onEdit(cat) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Depth indicator
                    if (isChild)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    // Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.accentLightOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: AppTheme.accentTextOf(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + sort order
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          if (cat.sortOrder != 0)
                            Text(
                              '#${cat.sortOrder}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMutedOf(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Actions
                    if (canEdit) ...[
                      // Minimum 48×48 touch targets via SizedBox
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
                          onPressed: () => onEdit(cat),
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
                          onPressed: () => onDelete(cat),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
              Icons.category_outlined,
              size: 56,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.categoriesEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.categoriesEmptyHint,
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
// AddEditCategoryDialog
// ─────────────────────────────────────────────────────────────────────────────

/// Add/Edit-Dialog für [ProductCategory].
///
/// Felder: name (Pflicht, 1–100), parentId (Dropdown, nur Top-Level wählbar),
/// sortOrder.
///
/// A11y-Keys: `categoryParentDropdown`.
/// Mobile-Checkliste: [SingleChildScrollView] + [SafeArea] +
/// [MediaQuery.viewInsetsOf].
class AddEditCategoryDialog extends StatefulWidget {
  final ProductCategory? category;

  const AddEditCategoryDialog({super.key, this.category});

  @override
  State<AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();

  String? _parentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameCtrl.text = c.name;
      _sortCtrl.text = c.sortOrder == 0 ? '' : '${c.sortOrder}';
      _parentId = c.parentId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
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
    final sortOrder = int.tryParse(_sortCtrl.text.trim()) ?? 0;

    // workspaceId + userId are injected by the repository (_userId / _wsId),
    // so we can use empty strings here — they are overridden on insert.
    final category = ProductCategory(
      id: widget.category?.id ?? const Uuid().v4(),
      workspaceId: '',
      userId: '',
      name: Validators.sanitize(_nameCtrl.text),
      parentId: _parentId,
      sortOrder: sortOrder,
      createdAt: widget.category?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (widget.category != null) {
        await provider.updateProductCategory(category);
      } else {
        await provider.addProductCategory(category);
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
    final provider = context.watch<InventoryProvider>();
    final categories = provider.productCategories;

    // Only top-level categories are selectable as parent (max 2 levels).
    final topLevelCategories = categories
        .where((c) =>
            c.parentId == null &&
            c.deletedAt == null &&
            c.id != widget.category?.id)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Validate current _parentId — if we are editing a category that has
    // a parent which is itself a child (would create depth > 2), reset.
    // Also guard against editing a top-level category whose parent was set.
    final isEditingChild = widget.category?.parentId != null;

    // If currently selected parent is itself a child, reset (guard).
    if (_parentId != null) {
      final parentCat =
          categories.where((c) => c.id == _parentId).firstOrNull;
      if (parentCat != null && parentCat.parentId != null) {
        // Clear silently — the validator will show message if user picks again.
        _parentId = null;
      }
    }

    final title = widget.category != null ? l10n.categoryEdit : l10n.categoryNew;

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
                // Title bar
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
                // Form body — scrollable for small phones
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name field
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: '${l10n.categoryFieldName} *',
                            ),
                            validator: (v) => Validators.validateRequired(
                                v,
                                label: l10n.categoryFieldName),
                          ),
                          const SizedBox(height: 12),
                          // Parent dropdown — use initialValue + ValueKey
                          // to support controlled pattern in Flutter 3.33+.
                          DropdownButtonFormField<String?>(
                            key: ValueKey('categoryParentDropdown-$_parentId'),
                            initialValue: _parentId,
                            decoration: InputDecoration(
                              labelText: l10n.categoryParent,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  l10n.categoryParentNone,
                                  style: TextStyle(
                                    color: AppTheme.textMutedOf(context),
                                  ),
                                ),
                              ),
                              ...topLevelCategories.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _parentId = v),
                            validator: (v) {
                              // If a parent is selected, ensure that parent
                              // is truly top-level (depth check).
                              if (v != null) {
                                final parentCat = categories
                                    .where((c) => c.id == v)
                                    .firstOrNull;
                                if (parentCat != null &&
                                    parentCat.parentId != null) {
                                  return l10n.categoryMaxDepthError;
                                }
                              }
                              return null;
                            },
                          ),
                          if (!isEditingChild && topLevelCategories.isEmpty && _parentId == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMutedOf(context),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Sort order field
                          TextFormField(
                            controller: _sortCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.categoryFieldSortOrder,
                              hintText: l10n.categorySortOrderHint,
                            ),
                            onFieldSubmitted: (_) => _save(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                // Action buttons
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
