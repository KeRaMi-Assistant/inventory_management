import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/buyer.dart';
import '../providers/inventory_provider.dart';

class AddEditBuyerDialog extends StatefulWidget {
  final Buyer? buyer;
  const AddEditBuyerDialog({super.key, this.buyer});

  @override
  State<AddEditBuyerDialog> createState() => _AddEditBuyerDialogState();
}

class _AddEditBuyerDialogState extends State<AddEditBuyerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  int _sortOrder = 0;
  int _selectedPalette = 0;
  bool _active = true;

  static const List<Map<String, dynamic>> _palette = [
    {
      'label': 'Blau',
      'row': Color(0xFFE3F0FF),
      'cell': Color(0xFF1565C0),
      'font': Colors.white,
    },
    {
      'label': 'Orange',
      'row': Color(0xFFFFF3E0),
      'cell': Color(0xFFE65100),
      'font': Colors.white,
    },
    {
      'label': 'Grün',
      'row': Color(0xFFE8F5E9),
      'cell': Color(0xFF2E7D32),
      'font': Colors.white,
    },
    {
      'label': 'Lila',
      'row': Color(0xFFF3E5F5),
      'cell': Color(0xFF6A1B9A),
      'font': Colors.white,
    },
    {
      'label': 'Gelb',
      'row': Color(0xFFFFFDE7),
      'cell': Color(0xFFF9A825),
      'font': Colors.black,
    },
    {
      'label': 'Rot',
      'row': Color(0xFFFFEBEE),
      'cell': Color(0xFFC62828),
      'font': Colors.white,
    },
    {
      'label': 'Teal',
      'row': Color(0xFFE0F2F1),
      'cell': Color(0xFF00695C),
      'font': Colors.white,
    },
    {
      'label': 'Pink',
      'row': Color(0xFFFCE4EC),
      'cell': Color(0xFFAD1457),
      'font': Colors.white,
    },
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.buyer;
    if (b != null) {
      _nameCtrl.text = b.name;
      _sortOrder = b.sortOrder;
      _active = b.active;
      for (int i = 0; i < _palette.length; i++) {
        if ((_palette[i]['cell'] as Color).toARGB32() ==
            b.buyerCellColor.toARGB32()) {
          _selectedPalette = i;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();
    final p = _palette[_selectedPalette];

    final buyer = Buyer(
      id: widget.buyer?.id ?? '',
      name: _nameCtrl.text.trim(),
      rowFillColor: p['row'] as Color,
      buyerCellColor: p['cell'] as Color,
      fontColor: p['font'] as Color,
      sortOrder: _sortOrder,
      active: _active,
    );

    if (widget.buyer != null) {
      provider.updateBuyer(buyer.copyWith(id: widget.buyer!.id));
    } else {
      provider.addBuyer(buyer);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _palette[_selectedPalette];
    return AlertDialog(
      title: Text(
          widget.buyer != null ? 'Käufer bearbeiten' : 'Neuer Käufer'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _sortOrder.toString(),
                  decoration:
                      const InputDecoration(labelText: 'Sortierreihenfolge'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      _sortOrder = int.tryParse(v) ?? _sortOrder,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Aktiv'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                const Text('Farbe wählen:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_palette.length, (i) {
                    final p = _palette[i];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPalette = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: p['row'] as Color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedPalette == i
                                ? (p['cell'] as Color)
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Text(
                          p['label'] as String,
                          style: TextStyle(
                            color: p['cell'] as Color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('Vorschau:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected['row'] as Color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected['cell'] as Color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _nameCtrl.text.isEmpty
                              ? 'Vorschau'
                              : _nameCtrl.text,
                          style: TextStyle(
                            color: selected['font'] as Color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Beispiel Produkt'),
                    ],
                  ),
                ),
              ],
            ),
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
