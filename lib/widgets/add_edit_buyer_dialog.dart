import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/buyer.dart';
import '../providers/inventory_provider.dart';
import '../utils/validators.dart';

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
  final List<TextEditingController> _serverIdCtrls = [];

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
      for (final id in b.discordServerIds) {
        _serverIdCtrls.add(TextEditingController(text: id));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _serverIdCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addServerId() {
    setState(() => _serverIdCtrls.add(TextEditingController()));
  }

  void _removeServerId(int index) {
    setState(() {
      _serverIdCtrls[index].dispose();
      _serverIdCtrls.removeAt(index);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();
    final p = _palette[_selectedPalette];
    final serverIds = _serverIdCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final buyer = Buyer(
      id: widget.buyer?.id ?? '',
      name: _nameCtrl.text.trim(),
      rowFillColor: p['row'] as Color,
      buyerCellColor: p['cell'] as Color,
      fontColor: p['font'] as Color,
      sortOrder: _sortOrder,
      active: _active,
      discordServerIds: serverIds,
    );

    if (widget.buyer != null) {
      provider.updateBuyer(buyer.copyWith(id: widget.buyer!.id));
    } else {
      provider.addBuyer(buyer);
    }
    Navigator.pop(context);
  }

  String _colorLabel(AppLocalizations l10n, String key) => switch (key) {
        'Blau' => l10n.buyerColorBlue,
        'Orange' => l10n.buyerColorOrange,
        'Grün' => l10n.buyerColorGreen,
        'Lila' => l10n.buyerColorPurple,
        'Gelb' => l10n.buyerColorYellow,
        'Rot' => l10n.buyerColorRed,
        'Teal' => l10n.buyerColorTeal,
        'Pink' => l10n.buyerColorPink,
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _palette[_selectedPalette];
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
          widget.buyer != null ? l10n.buyerEditTitle : l10n.buyerNewTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration:
                      InputDecoration(labelText: '${l10n.fieldName} *'),
                  maxLength: Validators.maxBuyerName,
                  onChanged: (_) => setState(() {}),
                  validator: Validators.validateBuyerName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _sortOrder.toString(),
                  decoration:
                      InputDecoration(labelText: l10n.buyerSortOrder),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      _sortOrder = int.tryParse(v) ?? _sortOrder,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text(l10n.buyerActive),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
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
                          _colorLabel(l10n, p['label'] as String),
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
                Text(l10n.buyerPreview,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
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
                              ? l10n.buyerPreview
                              : _nameCtrl.text,
                          style: TextStyle(
                            color: selected['font'] as Color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.buyerSampleProduct),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Discord Server IDs section
                Row(
                  children: [
                    const Icon(Icons.discord, size: 18),
                    const SizedBox(width: 6),
                    Text(l10n.buyerDiscordIds,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addServerId,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.buyerAddIdLabel),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_serverIdCtrls.isEmpty)
                  Text(
                    l10n.helpDiscordNoServerIds,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ...List.generate(_serverIdCtrls.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _serverIdCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Server ID ${i + 1}',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                Validators.validateDiscordSnowflake(v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: AppTheme.dangerTextOf(context),
                              size: 20),
                          onPressed: () => _removeServerId(i),
                          visualDensity: VisualDensity.compact,
                          tooltip: l10n.buyerRemoveTooltip,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
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
