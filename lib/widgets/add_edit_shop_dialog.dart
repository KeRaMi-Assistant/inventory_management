import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shop.dart';
import '../providers/inventory_provider.dart';

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
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final s = widget.shop;
    if (s != null) {
      _nameCtrl.text = s.name;
      _regionCtrl.text = s.region;
      _channelCtrl.text = s.channel;
      _active = s.active;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();

    final shop = Shop(
      id: widget.shop?.id ?? '',
      name: _nameCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      channel: _channelCtrl.text.trim(),
      active: _active,
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
    return AlertDialog(
      title: Text(widget.shop != null ? 'Shop bearbeiten' : 'Neuer Shop'),
      content: SizedBox(
        width: 350,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _regionCtrl,
                decoration: const InputDecoration(labelText: 'Region *'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _channelCtrl,
                decoration: const InputDecoration(labelText: 'Kanal'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Aktiv'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        ElevatedButton(
            onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
