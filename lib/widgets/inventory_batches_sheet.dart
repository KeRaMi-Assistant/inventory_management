import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/inventory_batch.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';

/// BottomSheet zur Verwaltung von Chargen (Batches/MHD/Seriennummer)
/// für einen einzelnen [InventoryItem].
class InventoryBatchesSheet extends StatefulWidget {
  final InventoryItem item;
  const InventoryBatchesSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, InventoryItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InventoryBatchesSheet(item: item),
    );
  }

  @override
  State<InventoryBatchesSheet> createState() => _InventoryBatchesSheetState();
}

class _InventoryBatchesSheetState extends State<InventoryBatchesSheet> {
  late Future<List<InventoryBatch>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final provider = context.read<InventoryProvider>();
    _future = provider.loadBatchesForItem(widget.item.id);
  }

  Future<void> _addBatch() async {
    final result = await showDialog<InventoryBatch>(
      context: context,
      builder: (_) => _BatchFormDialog(itemId: widget.item.id),
    );
    if (result != null && mounted) {
      final provider = context.read<InventoryProvider>();
      await provider.addBatch(result);
      if (!mounted) return;
      setState(_reload);
    }
  }

  Future<void> _deleteBatch(InventoryBatch b) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.actionDelete),
        content: Text(b.batchNumber),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0392B)),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<InventoryProvider>().deleteBatch(b.id);
      if (!mounted) return;
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMd(localeTag);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.batchesAdd,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(widget.item.name,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addBatch,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.batchesAdd),
                  ),
                ],
              ),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: FutureBuilder<List<InventoryBatch>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final batches = snap.data ?? const [];
                    if (batches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Center(child: Text(l10n.dealCommentEmpty)),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: batches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final b = batches[i];
                        final mhdColor = b.isExpired
                            ? const Color(0xFFC0392B)
                            : b.isExpiringSoon()
                                ? const Color(0xFFD97706)
                                : const Color(0xFF334155);
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(b.batchNumber,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (b.serialNumber != null)
                                Text(l10n.inventoryBatchSnPrefix(b.serialNumber!),
                                    style: const TextStyle(fontSize: 12)),
                              Row(
                                children: [
                                  Text(
                                    b.mhd != null
                                        ? 'MHD ${dateFmt.format(b.mhd!)}'
                                        : l10n.batchesNoMhd,
                                    style: TextStyle(
                                        fontSize: 12, color: mhdColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('${b.quantity}',
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Color(0xFFC0392B)),
                            onPressed: () => _deleteBatch(b),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchFormDialog extends StatefulWidget {
  final String itemId;
  const _BatchFormDialog({required this.itemId});

  @override
  State<_BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends State<_BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  DateTime? _mhd;

  @override
  void dispose() {
    _batchCtrl.dispose();
    _serialCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMhd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _mhd ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _mhd = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final batch = InventoryBatch(
      id: '',
      itemId: widget.itemId,
      batchNumber: _batchCtrl.text.trim(),
      serialNumber: _serialCtrl.text.trim().isEmpty
          ? null
          : _serialCtrl.text.trim(),
      mhd: _mhd,
      quantity: int.tryParse(_qtyCtrl.text) ?? 1,
      createdAt: DateTime.now(),
    );
    Navigator.pop(context, batch);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMd(localeTag);
    return AlertDialog(
      title: Text(l10n.batchesNew),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _batchCtrl,
                decoration: InputDecoration(
                    labelText: '${l10n.batchesNew} *'),
                maxLength: 100,
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.commonRequired
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _serialCtrl,
                decoration: InputDecoration(labelText: l10n.inventoryBatchSnLabel),
                maxLength: 100,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      decoration: InputDecoration(
                          labelText: '${l10n.inventoryQuantity} *'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 1) return '≥ 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickMhd,
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: l10n.inventoryBatchExpiryLabel),
                        child: Text(_mhd != null
                            ? dateFmt.format(_mhd!)
                            : l10n.commonNotSet),
                      ),
                    ),
                  ),
                ],
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
        ElevatedButton(onPressed: _submit, child: Text(l10n.actionSave)),
      ],
    );
  }
}
