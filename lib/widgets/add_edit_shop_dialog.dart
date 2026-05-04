import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/shop.dart';
import '../providers/inventory_provider.dart';
import '../utils/validators.dart';

class AddEditShopDialog extends StatefulWidget {
  final Shop? shop;
  const AddEditShopDialog({super.key, this.shop});

  @override
  State<AddEditShopDialog> createState() => _AddEditShopDialogState();
}

class _AddEditShopDialogState extends State<AddEditShopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final s = widget.shop;
    if (s != null) {
      _nameCtrl.text = s.name;
      _regionCtrl.text = s.region;
      _channelCtrl.text = s.channel;
      _urlCtrl.text = s.url ?? '';
      _active = s.active;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    _channelCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();
    final rawUrl = _urlCtrl.text.trim();
    String? url = rawUrl.isEmpty ? null : rawUrl;
    // Auto-prepend https:// if missing
    if (url != null && !url.startsWith('http')) {
      url = 'https://$url';
    }

    final shop = Shop(
      id: widget.shop?.id ?? '',
      name: _nameCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      channel: _channelCtrl.text.trim(),
      active: _active,
      url: url,
    );

    if (widget.shop != null) {
      provider.updateShop(shop.copyWith(id: widget.shop!.id));
    } else {
      provider.addShop(shop);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.shop != null ? l10n.shopEditTitle : l10n.shopNewTitle),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: '${l10n.fieldName} *'),
                maxLength: Validators.maxShopName,
                validator: Validators.validateShopName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _regionCtrl,
                decoration: InputDecoration(labelText: '${l10n.shopRegion} *'),
                maxLength: 40,
                validator: (v) =>
                    Validators.validateRequired(v, label: l10n.shopRegion),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _channelCtrl,
                decoration: InputDecoration(labelText: l10n.shopChannel),
                maxLength: 50,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  labelText: l10n.supplierWebsite,
                  hintText: 'https://www.amazon.de',
                  prefixIcon: const Icon(Icons.link, size: 18),
                ),
                keyboardType: TextInputType.url,
                validator: (v) => Validators.validateUrl(v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(l10n.shopActive),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel)),
        ElevatedButton(
            onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
