import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/supplier.dart';
import '../providers/inventory_provider.dart';
import '../widgets/add_edit_supplier_dialog.dart';
import '../widgets/app_feedback.dart';
import '../widgets/confirm_dialog.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    InventoryProvider provider,
    Supplier supplier,
  ) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.suppliersDeleteTitle,
      message: l10n.suppliersDeletePrompt(supplier.name),
      confirmLabel: l10n.actionDelete,
      isDestructive: true,
    );

    if (confirmed) {
      try {
        await provider.deleteSupplier(supplier.id);
        if (!context.mounted) return;
        AppFeedback.success(context, l10n.suppliersDeleted);
      } catch (_) {
        if (!context.mounted) return;
        AppFeedback.error(context, l10n.suppliersDeleteFailed);
      }
    }
  }

  Future<void> _seedCarriers(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await provider.seedCarrierSuppliers();
      if (!context.mounted) return;
      if (result.added == 0) {
        AppFeedback.info(context, l10n.suppliersSeedAlreadyPresent(result.skipped));
      } else {
        AppFeedback.success(context, l10n.suppliersSeedSuccess(result.added));
      }
    } catch (_) {
      if (!context.mounted) return;
      AppFeedback.error(context, l10n.suppliersAddCarriersFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final suppliers = provider.suppliers;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            // D4: tooltip → explicit Semantics-Label for screen readers.
            tooltip: l10n.suppliersNew,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddEditSupplierDialog(),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.suppliersNew),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _seedCarriers(context, provider),
                      icon: const Icon(Icons.local_shipping_outlined,
                          size: 16),
                      label: Text(AppLocalizations.of(context).suppliersAddCarriers),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.isLoading && suppliers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : suppliers.isEmpty
                        ? const _EmptyState()
                        : _buildList(context, provider, suppliers, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    InventoryProvider provider,
    List<Supplier> suppliers,
    AppLocalizations l10n,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = suppliers[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderOf(context)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: s.active
                  ? AppTheme.accentLightOf(context)
                  : AppTheme.bgSubtleOf(context),
              child: Icon(
                Icons.local_shipping_outlined,
                color: s.active
                    ? AppTheme.accentTextOf(context)
                    : AppTheme.textDisabledOf(context),
              ),
            ),
            title: Text(
              s.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.contactName != null)
                  Text(s.contactName!,
                      style: const TextStyle(fontSize: 12)),
                if (s.email != null)
                  Text(s.email!,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedOf(context))),
                if (!s.active)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.suppliersInactive,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.dangerTextOf(context),
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: l10n.actionEdit,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AddEditSupplierDialog(supplier: s),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppTheme.dangerTextOf(context),
                  ),
                  tooltip: l10n.actionDelete,
                  onPressed: () => _confirmDelete(context, provider, s),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 48, color: AppTheme.textDisabledOf(context)),
          const SizedBox(height: 12),
          Text(
            l10n.suppliersEmpty,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.suppliersEmptyHint,
            style: TextStyle(
                color: AppTheme.textMutedOf(context), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
