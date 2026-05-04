import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/supplier.dart';
import '../providers/inventory_provider.dart';
import '../utils/validators.dart';

class AddEditSupplierDialog extends StatefulWidget {
  final Supplier? supplier;
  const AddEditSupplierDialog({super.key, this.supplier});

  @override
  State<AddEditSupplierDialog> createState() => _AddEditSupplierDialogState();
}

class _AddEditSupplierDialogState extends State<AddEditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    if (s != null) {
      _nameCtrl.text = s.name;
      _contactCtrl.text = s.contactName ?? '';
      _emailCtrl.text = s.email ?? '';
      _phoneCtrl.text = s.phone ?? '';
      _websiteCtrl.text = s.website ?? '';
      _noteCtrl.text = s.note ?? '';
      _active = s.active;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    String? website = Validators.sanitizeOrNull(_websiteCtrl.text);
    if (website != null && !website.startsWith('http')) {
      website = 'https://$website';
    }

    final supplier = Supplier(
      id: widget.supplier?.id ?? '',
      name: Validators.sanitize(_nameCtrl.text),
      contactName: Validators.sanitizeOrNull(_contactCtrl.text),
      email: Validators.sanitizeOrNull(_emailCtrl.text),
      phone: Validators.sanitizeOrNull(_phoneCtrl.text),
      website: website,
      note: Validators.sanitizeOrNull(_noteCtrl.text),
      active: _active,
    );

    final l10n = AppLocalizations.of(context);
    try {
      if (widget.supplier != null) {
        await provider.updateSupplier(supplier.copyWith(id: widget.supplier!.id));
      } else {
        await provider.addSupplier(supplier);
      }
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.pushSaveFailed('$e')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.supplier != null
          ? l10n.supplierEditTitle
          : l10n.supplierAddTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration:
                      InputDecoration(labelText: '${l10n.fieldName} *'),
                  maxLength: 100,
                  validator: (v) =>
                      Validators.validateRequired(v, label: l10n.fieldName),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contactCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.supplierContactName),
                  maxLength: 100,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.fieldEmail,
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                  ),
                  validator: (v) {
                    final s = Validators.sanitize(v);
                    if (s.isEmpty) return null;
                    return Validators.validateEmail(s);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.supplierPhone,
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                  ),
                  maxLength: 40,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _websiteCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.supplierWebsite,
                    prefixIcon: const Icon(Icons.link, size: 18),
                  ),
                  validator: (v) => Validators.validateUrl(v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.dealNote),
                  maxLength: Validators.maxNote,
                  maxLines: 3,
                  validator: Validators.validateNote,
                ),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text(l10n.supplierActive),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        ElevatedButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
