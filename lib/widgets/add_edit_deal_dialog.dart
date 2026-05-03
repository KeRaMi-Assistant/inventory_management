import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../providers/inventory_provider.dart';
import '../utils/url_helper.dart';
import '../utils/validators.dart';

class AddEditDealDialog extends StatefulWidget {
  final Deal? deal;
  final String? initialTicketNumber;
  const AddEditDealDialog({super.key, this.deal, this.initialTicketNumber});

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
  String _currency = 'EUR';
  final _taxRateCtrl = TextEditingController(text: '19');

  bool _saving = false;

  static const List<String> _currencyOptions = [
    'EUR',
    'USD',
    'GBP',
    'CHF',
  ];

  @override
  void initState() {
    super.initState();
    _quantityCtrl.addListener(_refreshPreview);
    _priceCtrl.addListener(_refreshPreview);
    _vkCtrl.addListener(_refreshPreview);
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
      _currency = d.currency;
      if (d.taxRate != null) {
        _taxRateCtrl.text = (d.taxRate! * 100).toStringAsFixed(
            d.taxRate! * 100 % 1 == 0 ? 0 : 2);
      }
    } else if (widget.initialTicketNumber != null) {
      _ticketCtrl.text = widget.initialTicketNumber!;
    }
  }

  @override
  void dispose() {
    _quantityCtrl.removeListener(_refreshPreview);
    _priceCtrl.removeListener(_refreshPreview);
    _vkCtrl.removeListener(_refreshPreview);
    _productCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _taxRateCtrl.dispose();
    _vkCtrl.dispose();
    _ticketCtrl.dispose();
    _ticketUrlCtrl.dispose();
    _trackingCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  void _onTicketChanged(String value) {
    setState(() {
      if (value.trim().isEmpty) _ticketUrlCtrl.text = '';
    });
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    if (!mounted) return;
    final provider = context.read<InventoryProvider>();

    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    final taxPct =
        double.tryParse(_taxRateCtrl.text.trim().replaceAll(',', '.'));
    final taxRate =
        (taxPct != null && taxPct >= 0 && taxPct <= 100) ? taxPct / 100 : null;
    final factor = 1 + (taxRate ?? 0.19);
    double? ekNetto;
    double? ekBrutto;
    if (price != null) {
      if (_priceType == 'Netto') {
        ekNetto = price;
        ekBrutto = price * factor;
      } else {
        ekBrutto = price;
        ekNetto = price / factor;
      }
    }

    final shop = _shop;
    if (shop == null) {
      setState(() => _saving = false);
      return;
    }

    final ticket = _ticketCtrl.text.trim();
    final deal = Deal(
      id: widget.deal?.id ?? provider.nextDealId,
      product: _productCtrl.text.trim(),
      quantity: int.parse(_quantityCtrl.text),
      shippingType: _shippingType,
      shop: shop,
      orderDate: _orderDate,
      ekNetto: ekNetto,
      ekBrutto: ekBrutto,
      vk: double.tryParse(_vkCtrl.text.replaceAll(',', '.')),
      buyer: _buyer?.isEmpty ?? true ? null : _buyer,
      ticketNumber: ticket.isEmpty ? null : ticket,
      ticketUrl: () {
        if (ticket.isEmpty) return null;
        final raw = _ticketUrlCtrl.text.trim();
        if (raw.isEmpty) return null;
        if (raw.contains('discord.com/channels/')) return raw;
        // Bare Discord snowflake ID → build proper URL using buyer's first server
        if (RegExp(r'^\d{15,21}$').hasMatch(raw)) {
          final buyerObj = provider.buyers.where((b) => b.name == _buyer).firstOrNull;
          final serverId = buyerObj?.discordServerIds.firstOrNull;
          if (serverId != null) return 'https://discord.com/channels/$serverId/$raw';
        }
        return raw.startsWith('http') ? raw : 'https://$raw';
      }(),
      tracking:
          _trackingCtrl.text.isEmpty ? null : _trackingCtrl.text.trim(),
      arrivalDate: _arrivalDate,
      status: _status,
      beleg: _beleg,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
      taxRate: taxRate,
      currency: _currency,
    );

    try {
      if (widget.deal != null) {
        await provider.updateDeal(deal);
      } else {
        await provider.addDeal(deal);
      }
    } catch (_) {
      // Deal is already in memory; storage errors are non-fatal
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.pop(context);
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
                  child: LayoutBuilder(builder: (ctx, formConstraints) {
                    final narrow = formConstraints.maxWidth < 480;
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
                            maxLength: Validators.maxProductName,
                            validator: Validators.validateProductName,
                          ),
                          TextFormField(
                            controller: _quantityCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Anzahl *'),
                            keyboardType: TextInputType.number,
                            validator: Validators.validatePositiveInt,
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
                                      validator: (v) =>
                                          Validators.validateMoney(v),
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
                                      validator: (v) =>
                                          Validators.validateMoney(v),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _currency,
                                decoration: const InputDecoration(
                                  labelText: 'Währung',
                                  prefixIcon:
                                      Icon(Icons.euro_symbol, size: 18),
                                ),
                                items: _currencyOptions
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _currency = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _taxRateCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'MwSt-Satz %',
                                  hintText: 'z.B. 19',
                                  suffixText: '%',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => _refreshPreview(),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return null;
                                  final n =
                                      double.tryParse(s.replaceAll(',', '.'));
                                  if (n == null) return 'Ungültige Zahl';
                                  if (n < 0 || n > 100) {
                                    return '0 – 100';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
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
                            onChanged: (v) {
                              setState(() => _buyer = v);
                            },
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
                            maxLength: Validators.maxTicket,
                            validator: (v) => Validators.validateTicket(v),
                            onChanged: _onTicketChanged,
                          ),
                          TextFormField(
                            controller: _trackingCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Tracking'),
                            maxLength: 100,
                          ),
                        ]),
                        // Discord status hint
                        if (_ticketCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _DiscordServerButtons(
                            buyer: _buyer,
                            buyers: buyers,
                            ticketUrl: _ticketUrlCtrl.text.trim(),
                          ),
                        ],
                        if (_ticketCtrl.text.isNotEmpty) ...[
                           const SizedBox(height: 8),
                           TextFormField(
                             controller: _ticketUrlCtrl,
                             decoration: const InputDecoration(
                               labelText: 'Ticket-URL (optional)',
                               hintText: 'Link aus Discord einfügen…',
                               prefixIcon: Icon(Icons.link, size: 18),
                             ),
                             keyboardType: TextInputType.url,
                           ),
                         ],
                        const SizedBox(height: 20),
                        // ── Notiz ───────────────────────────────────────
                        if (_priceCtrl.text.isNotEmpty || _vkCtrl.text.isNotEmpty) ...[
                          _ProfitPreview(
                            priceText: _priceCtrl.text,
                            vkText: _vkCtrl.text,
                            quantityText: _quantityCtrl.text,
                            priceType: _priceType,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _sectionLabel('Notiz'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _noteCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Notiz'),
                          maxLines: 2,
                          maxLength: Validators.maxNote,
                          validator: Validators.validateNote,
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
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: Text(_saving ? 'Speichert…' : 'Speichern'),
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

class _ProfitPreview extends StatelessWidget {
  final String priceText;
  final String vkText;
  final String quantityText;
  final String priceType;

  const _ProfitPreview({
    required this.priceText,
    required this.vkText,
    required this.quantityText,
    required this.priceType,
  });

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(priceText.replaceAll(',', '.'));
    final vk = double.tryParse(vkText.replaceAll(',', '.'));
    final quantity = int.tryParse(quantityText) ?? 1;
    final ekBrutto = price == null
        ? null
        : priceType == 'Netto'
            ? price * 1.19
            : price;
    final profit = vk != null && ekBrutto != null ? vk - ekBrutto : null;
    final total = profit != null ? profit * quantity : null;
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              profit == null
                  ? 'Profit-Vorschau: EK und VK eintragen'
                  : 'Profit/Stück ${fmt.format(profit)} · Gesamt ${fmt.format(total)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: profit == null
                    ? const Color(0xFF64748B)
                    : profit >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscordServerButtons extends StatelessWidget {
  final String? buyer;
  final List<Buyer> buyers;
  final String ticketUrl;

  const _DiscordServerButtons({
    required this.buyer,
    required this.buyers,
    required this.ticketUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (buyer == null) return const SizedBox.shrink();
    final b = buyers.where((x) => x.name == buyer).firstOrNull;
    final serverIds = b?.discordServerIds ?? [];
    if (serverIds.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (int i = 0; i < serverIds.length; i++)
          Builder(
            builder: (ctx) {
              final serverId = serverIds[i];
              final resolved = resolveDiscordUrl(ticketUrl, serverIds: [serverId]);
              final hasChannel = resolved.contains('discord.com/channels/');
              final url = hasChannel ? resolved : 'https://discord.com/channels/$serverId';
              return OutlinedButton.icon(
                onPressed: () => openUrlWithFallback(ctx, url),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFF5865F2)),
                  foregroundColor: const Color(0xFF5865F2),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.discord, size: 14),
                label: Text(hasChannel
                    ? 'Ticket in Discord öffnen'
                    : 'Server ${i + 1} in Discord öffnen'),
              );
            },
          ),
        if (ticketUrl.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 12, color: Color(0xFF0369A1)),
                const SizedBox(width: 5),
                const Flexible(
                  child: Text(
                    'Kanal finden → Rechtsklick → „Link kopieren" → hier einfügen',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
