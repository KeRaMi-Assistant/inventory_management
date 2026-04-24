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

    return AlertDialog(
      title: Text(widget.deal != null ? 'Deal bearbeiten' : 'Neuer Deal'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _productCtrl,
                  decoration: const InputDecoration(labelText: 'Produkt *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quantityCtrl,
                  decoration: const InputDecoration(labelText: 'Anzahl *'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Pflichtfeld';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Muss > 0 sein';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _shippingType,
                  decoration: const InputDecoration(labelText: 'Versandtyp *'),
                  items: InventoryProvider.shippingTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _shippingType = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _shop,
                  decoration: const InputDecoration(labelText: 'Shop *'),
                  items: shops
                      .map((s) =>
                          DropdownMenuItem(value: s.name, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _shop = v),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Bestelldatum: ${dateFmt.format(_orderDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(context, false),
                ),
                const SizedBox(height: 8),
                const Text('EK Preis',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Radio<String>(
                      // ignore: deprecated_member_use
                      value: 'Netto',
                      // ignore: deprecated_member_use
                      groupValue: _priceType,
                      // ignore: deprecated_member_use
                      onChanged: (v) => setState(() => _priceType = v!),
                    ),
                    const Text('Netto'),
                    Radio<String>(
                      // ignore: deprecated_member_use
                      value: 'Brutto',
                      // ignore: deprecated_member_use
                      groupValue: _priceType,
                      // ignore: deprecated_member_use
                      onChanged: (v) => setState(() => _priceType = v!),
                    ),
                    const Text('Brutto'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Betrag (€)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          if (double.tryParse(v.replaceAll(',', '.')) ==
                              null) {
                            return 'Ungültige Zahl';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vkCtrl,
                  decoration:
                      const InputDecoration(labelText: 'VK (Verkaufspreis)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'Ungültige Zahl';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _buyer,
                  decoration: const InputDecoration(labelText: 'Käufer'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('— Kein —')),
                    ...buyers.map((b) =>
                        DropdownMenuItem(value: b.name, child: Text(b.name))),
                  ],
                  onChanged: (v) => setState(() => _buyer = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ticketCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Ticketnummer'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _trackingCtrl,
                  decoration: const InputDecoration(labelText: 'Tracking'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_arrivalDate != null
                      ? 'Ankunft: ${dateFmt.format(_arrivalDate!)}'
                      : 'Ankunftsdatum wählen'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(context, true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: InventoryProvider.statusOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _beleg,
                  decoration: const InputDecoration(labelText: 'Beleg'),
                  items: InventoryProvider.belegOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _beleg = v!),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(labelText: 'Notiz'),
                  maxLines: 3,
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
