import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/supplier.dart';
import '../providers/inventory_provider.dart';
import '../widgets/add_edit_supplier_dialog.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    InventoryProvider provider,
    Supplier supplier,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.suppliersDeleteTitle),
        content: Text(l10n.suppliersDeletePrompt(supplier.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.deleteSupplier(supplier.id);
    }
  }

  Future<void> _seedCarriers(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await provider.seedCarrierSuppliers();
      messenger.showSnackBar(SnackBar(
        content: Text(result.added == 0
            ? 'Versanddienste sind bereits vorhanden (${result.skipped} übersprungen).'
            : '${result.added} Versanddienste hinzugefügt'
                '${result.skipped > 0 ? ', ${result.skipped} bereits vorhanden' : ''}.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Fehler beim Hinzufügen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
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
                child: suppliers.isEmpty
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
                        side:
                            BorderSide(color: AppTheme.borderOf(context)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: s.active
                              ? AppTheme.infoBgOf(context)
                              : AppTheme.bgSubtleOf(context),
                          child: Icon(
                            Icons.local_shipping_outlined,
                            color: s.active
                                ? AppTheme.infoTextOf(context)
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
                                builder: (_) =>
                                    AddEditSupplierDialog(supplier: s),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppTheme.dangerTextOf(context)),
                              tooltip: l10n.actionDelete,
                              onPressed: () =>
                                  _confirmDelete(context, provider, s),
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
            style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
