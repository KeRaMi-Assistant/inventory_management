import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/deal.dart';
import '../providers/inventory_provider.dart';

class AddEditDealDialog extends StatefulWidget {
  final Deal? deal;
  const AddEditDealDialog({super.key, this.deal});

  @override
  State<AddEditDealDialog> createState() => _AddEditDealDialogState();
}

class _AddEditDealDialogState extends State<AddEditDealDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _vkCtrl = TextEditingController();
  final _ticketCtrl = TextEditingController();
  final _ticketUrlCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _shippingType = 'Reship';
  String? _shop;
  DateTime _orderDate = DateTime.now();
  DateTime? _arrivalDate;
  String _status = 'Bestellt';
  String _beleg = 'Nein';
  String? _buyer;
  String _priceType = 'Netto';

  @override
  void initState() {
    super.initState();
    final d = widget.deal;
    if (d != null) {
      _productCtrl.text = d.product;
      _quantityCtrl.text = d.quantity.toString();
      _shippingType = d.shippingType;
      _shop = d.shop;
      _orderDate = d.orderDate;
      _arrivalDate = d.arrivalDate;
      _status = d.status;
      _beleg = d.beleg;
      _buyer = d.buyer;
      _vkCtrl.text = d.vk?.toString() ?? '';
      _ticketCtrl.text = d.ticketNumber ?? '';
      _ticketUrlCtrl.text = d.ticketUrl ?? '';
      _trackingCtrl.text = d.tracking ?? '';
      _noteCtrl.text = d.note ?? '';
      if (d.ekNetto != null) {
        _priceType = 'Netto';
        _priceCtrl.text = d.ekNetto!.toStringAsFixed(2);
      } else if (d.ekBrutto != null) {
        _priceType = 'Brutto';
        _priceCtrl.text = d.ekBrutto!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _vkCtrl.dispose();
    _ticketCtrl.dispose();
    _ticketUrlCtrl.dispose();
    _trackingCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, bool isArrival) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isArrival ? (_arrivalDate ?? DateTime.now()) : _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isArrival) {
          _arrivalDate = picked;
        } else {
          _orderDate = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();

    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    double? ekNetto;
    double? ekBrutto;
    if (price != null) {
      if (_priceType == 'Netto') {
        ekNetto = price;
        ekBrutto = price * 1.19;
      } else {
        ekBrutto = price;
        ekNetto = price / 1.19;
      }
    }

    final deal = Deal(
      id: widget.deal?.id ?? provider.nextDealId,
      product: _productCtrl.text.trim(),
      quantity: int.parse(_quantityCtrl.text),
      shippingType: _shippingType,
      shop: _shop!,
      orderDate: _orderDate,
      ekNetto: ekNetto,
      ekBrutto: ekBrutto,
      vk: double.tryParse(_vkCtrl.text.replaceAll(',', '.')),
      buyer: _buyer?.isEmpty ?? true ? null : _buyer,
      ticketNumber:
          _ticketCtrl.text.isEmpty ? null : _ticketCtrl.text.trim(),
      ticketUrl: () {
        if (_ticketCtrl.text.isEmpty) return null;
        final raw = _ticketUrlCtrl.text.trim();
        if (raw.isEmpty) return null;
        return raw.startsWith('http') ? raw : 'https://$raw';
      }(),
      tracking:
          _trackingCtrl.text.isEmpty ? null : _trackingCtrl.text.trim(),
      arrivalDate: _arrivalDate,
      status: _status,
      beleg: _beleg,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (widget.deal != null) {
      provider.updateDeal(deal);
    } else {
      provider.addDeal(deal);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final shops = provider.shops.where((s) => s.active).toList();
    final buyers = provider.buyers.where((b) => b.active).toList();
    final dateFmt = DateFormat('dd.MM.yyyy');

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.deal != null
                          ? Icons.edit_outlined
                          : Icons.add_circle_outline,
                      color: const Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.deal != null
                          ? 'Deal bearbeiten'
                          : 'Neuer Deal',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18,
                        color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // ── Form ─────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Builder(builder: (ctx) {
                    final narrow = MediaQuery.of(ctx).size.width < 560;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Produkt & Versand ───────────────────────────
                        _sectionLabel('Produkt & Versand'),
                        const SizedBox(height: 10),
                        _row(narrow, [
                          TextFormField(
                            controller: _productCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Produkt *'),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Pflichtfeld'
                                : null,
                          ),
                          TextFormField(
                            controller: _quantityCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Anzahl *'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Pflichtfeld';
                              final n = int.tryParse(v);
                              if (n == null || n <= 0) return 'Muss > 0 sein';
                              return null;
                            },
                          ),
                        ], flex: [3, 1]),
                        const SizedBox(height: 12),
                        _row(narrow, [
                          DropdownButtonFormField<String>(
                            initialValue: _shippingType,
                            decoration: const InputDecoration(
                                labelText: 'Versandtyp *'),
                            items: InventoryProvider.shippingTypes
                                .map((t) => DropdownMenuItem(
                                    value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _shippingType = v!),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _shop,
                            decoration:
                                const InputDecoration(labelText: 'Shop *'),
                            items: shops
                                .map((s) => DropdownMenuItem(
                                    value: s.name, child: Text(s.name)))
                                .toList(),
                            onChanged: (v) => setState(() => _shop = v),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Pflichtfeld' : null,
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // ── Preise ──────────────────────────────────────
                        _sectionLabel('Preise'),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('EK Preis',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569))),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      _radioOption('Netto', 'Netto'),
                                      const SizedBox(width: 12),
                                      _radioOption('Brutto', 'Brutto'),
                                    ]),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _priceCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Betrag (€)',
                                        prefixText: '€ ',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return null;
                                        if (double.tryParse(
                                                v.replaceAll(',', '.')) ==
                                            null) { return 'Ungültige Zahl'; }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('VK (Verkaufspreis)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _vkCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Betrag (€)',
                                        prefixText: '€ ',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return null;
                                        if (double.tryParse(
                                                v.replaceAll(',', '.')) ==
                                            null) { return 'Ungültige Zahl'; }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // ── Käufer & Status ─────────────────────────────
                        _sectionLabel('Käufer & Status'),
                        const SizedBox(height: 10),
                        _row(narrow, [
                          DropdownButtonFormField<String>(
                            initialValue: _buyer,
                            decoration:
                                const InputDecoration(labelText: 'Käufer'),
                            items: [
                              const DropdownMenuItem<String>(
                                  value: null, child: Text('— Kein —')),
                              ...buyers.map((b) => DropdownMenuItem(
                                  value: b.name, child: Text(b.name))),
                            ],
                            onChanged: (v) => setState(() => _buyer = v),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: InventoryProvider.statusOptions
                                .map((s) => DropdownMenuItem(
                                    value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _beleg,
                            decoration:
                                const InputDecoration(labelText: 'Beleg'),
                            items: InventoryProvider.belegOptions
                                .map((s) => DropdownMenuItem(
                                    value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => _beleg = v!),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // ── Datum & Tracking ────────────────────────────
                        _sectionLabel('Datum & Tracking'),
                        const SizedBox(height: 10),
                        _row(narrow, [
                          _DatePickerField(
                            label: 'Bestelldatum *',
                            date: _orderDate,
                            onTap: () => _pickDate(ctx, false),
                            dateFmt: dateFmt,
                          ),
                          _DatePickerField(
                            label: 'Ankunftsdatum',
                            date: _arrivalDate,
                            onTap: () => _pickDate(ctx, true),
                            dateFmt: dateFmt,
                            placeholder: 'Nicht gesetzt',
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _row(narrow, [
                          TextFormField(
                            controller: _ticketCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Ticketnummer'),
                            onChanged: (_) => setState(() {}),
                          ),
                          TextFormField(
                            controller: _trackingCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Tracking'),
                          ),
                        ]),
                        if (_ticketCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ticketUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ticket-URL (optional)',
                              hintText: 'https://...',
                              prefixIcon: Icon(Icons.link, size: 18),
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ],
                        const SizedBox(height: 20),
                        // ── Notiz ───────────────────────────────────────
                        _sectionLabel('Notiz'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _noteCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Notiz'),
                          maxLines: 2,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            // ── Actions ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a 2-column Row on wide screens or a stacked Column on narrow screens.
  Widget _row(bool narrow, List<Widget> children, {List<int>? flex}) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(flex: flex != null ? flex[i] : 1, child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }

  Widget _radioOption(String value, String label) {
    return GestureDetector(
      onTap: () => setState(() => _priceType = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Radio<String>(
              // ignore: deprecated_member_use
              value: value,
              // ignore: deprecated_member_use
              groupValue: _priceType,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _priceType = v!),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF334155))),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final DateFormat dateFmt;
  final String? placeholder;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.dateFmt,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16,
              color: Color(0xFF64748B)),
        ),
        child: Text(
          date != null ? dateFmt.format(date!) : (placeholder ?? ''),
          style: TextStyle(
            fontSize: 14,
            color: date != null
                ? const Color(0xFF0F172A)
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
