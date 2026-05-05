import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/shop.dart';
import '../providers/inventory_provider.dart';
import '../services/carrier_service.dart';
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
    // Wenn der Nutzer "Amazon" ins Name-Feld tippt, blenden wir den
    // EU-Country-Picker für Region ein. Listener triggert ein Rebuild.
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    _channelCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  bool get _isAmazonShop =>
      _nameCtrl.text.trim().toLowerCase().startsWith('amazon');

  /// Parst den Country-Suffix aus dem Shop-Namen (`Amazon-FR` → `'fr'`,
  /// `Amazon-CO.UK` → `'co.uk'`). Liefert `null`, wenn der Name kein
  /// Suffix nach einem `-` hat oder das Suffix kein bekanntes TLD ist.
  String? get _amazonSuffixCountry {
    final name = _nameCtrl.text.trim();
    final dashIdx = name.lastIndexOf('-');
    if (dashIdx <= 0 || dashIdx >= name.length - 1) return null;
    final suffix = name.substring(dashIdx + 1).trim().toLowerCase();
    return amazonCountryOptions.containsKey(suffix) ? suffix : null;
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

    // Bei Suffix-Amazon-Shops (`Amazon-FR`) leiten wir die Region aus dem
    // Namen ab — der User sieht das Feld nur als read-only Chip.
    final region = _amazonSuffixCountry ?? _regionCtrl.text.trim();

    final shop = Shop(
      id: widget.shop?.id ?? '',
      name: _nameCtrl.text.trim(),
      region: region,
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
              if (_isAmazonShop && _amazonSuffixCountry != null)
                _AmazonSuffixCountryChip(
                  country: _amazonSuffixCountry!,
                  label: '${l10n.shopRegion} *',
                )
              else if (_isAmazonShop)
                _AmazonCountryDropdown(
                  controller: _regionCtrl,
                  label: '${l10n.shopRegion} *',
                )
              else
                TextFormField(
                  controller: _regionCtrl,
                  decoration:
                      InputDecoration(labelText: '${l10n.shopRegion} *'),
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

/// Dropdown mit allen unterstützten Amazon-Country-TLDs. Schreibt den
/// gewählten Schlüssel (`'de'`, `'fr'`, …) zurück in den `controller` —
/// so bleibt das übergebene Region-Feld die Single Source of Truth, ohne
/// dass der Shop ein extra Feld bräuchte.
class _AmazonCountryDropdown extends StatelessWidget {
  const _AmazonCountryDropdown({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim().toLowerCase();
    final value = amazonCountryOptions.containsKey(current) ? current : null;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in amazonCountryOptions.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text('Amazon · ${entry.value}'),
          ),
      ],
      onChanged: (v) {
        if (v != null) controller.text = v;
      },
      validator: (v) => (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
    );
  }
}

/// Read-only Chip, der den aus dem Shop-Namen-Suffix abgeleiteten Country
/// anzeigt (z. B. `Amazon-FR` → "France"). Verhindert, dass der User das
/// Feld editiert, weil der Country bereits aus dem Namen feststeht.
class _AmazonSuffixCountryChip extends StatelessWidget {
  const _AmazonSuffixCountryChip({
    required this.country,
    required this.label,
  });

  final String country;
  final String label;

  @override
  Widget build(BuildContext context) {
    final name = amazonCountryOptions[country] ?? country;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Aus Shop-Namen abgeleitet',
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Text(
              '.$country',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD97706),
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }
}
