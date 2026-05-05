import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../providers/inventory_provider.dart';
import '../utils/status_l10n.dart';
import '../utils/url_helper.dart';
import '../utils/validators.dart';
import 'attachment_gallery.dart';
import 'deal_comments_section.dart';

class AddEditDealDialog extends StatefulWidget {
  final Deal? deal;
  final Deal? prefill;
  final String? initialTicketNumber;
  const AddEditDealDialog({
    super.key,
    this.deal,
    this.prefill,
    this.initialTicketNumber,
  });

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

  bool _isDropship = false;
  String? _shop;
  DateTime _orderDate = DateTime.now();
  DateTime? _arrivalDate;
  String _status = 'Bestellt';
  bool _hasReceipt = false;
  String? _buyer;
  String _priceType = 'Netto';
  String _currency = 'EUR';
  final _taxRateCtrl = TextEditingController(text: '19');
  List<String> _attachmentPaths = const [];

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
    // `widget.deal` = bestehender Deal zum Bearbeiten.
    // `widget.prefill` = neuer Deal mit vorausgefüllten Werten (z.B. aus
    // einem Inbox-Vorschlag). Save-Logik unten unterscheidet anhand `deal`.
    final d = widget.deal ?? widget.prefill;
    if (d != null) {
      _productCtrl.text = d.product;
      _quantityCtrl.text = d.quantity.toString();
      _isDropship = d.isDropship;
      _shop = d.shop;
      _orderDate = d.orderDate;
      _arrivalDate = d.arrivalDate;
      _status = d.status;
      _hasReceipt = d.hasReceipt;
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
      _attachmentPaths = List.of(d.attachmentPaths);
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

  /// Übernimmt Werte aus einem zuvor angelegten Deal als Vorlage. Wird beim
  /// Tippen auf einen Vorschlag im Produkt-Autocomplete aufgerufen — nur Felder
  /// die der User noch nicht überschrieben hat, werden befüllt.
  void _applyTemplate(Deal template) {
    setState(() {
      _productCtrl.text = template.product;
      _isDropship = template.isDropship;
      _shop = template.shop;
      _buyer = template.buyer;
      _currency = template.currency;
      if (template.taxRate != null) {
        final pct = template.taxRate! * 100;
        _taxRateCtrl.text =
            pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(2);
      }
      if (template.ekNetto != null) {
        _priceType = 'Netto';
        _priceCtrl.text = template.ekNetto!.toStringAsFixed(2);
      } else if (template.ekBrutto != null) {
        _priceType = 'Brutto';
        _priceCtrl.text = template.ekBrutto!.toStringAsFixed(2);
      }
      if (template.vk != null) {
        _vkCtrl.text = template.vk!.toStringAsFixed(2);
      }
    });
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
      isDropship: _isDropship,
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
      hasReceipt: _hasReceipt,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
      taxRate: taxRate,
      currency: _currency,
      attachmentPaths: _attachmentPaths,
    );

    Deal saved = deal;
    try {
      if (widget.deal != null) {
        await provider.updateDeal(deal);
      } else {
        saved = await provider.addDeal(deal);
      }
    } catch (_) {
      // Deal is already in memory; storage errors are non-fatal
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<InventoryProvider>();
    // Shop-Picker: Amazon-Block oben, Trennlinie, sonstige alphabetisch.
    final activeShops = provider.shops.where((s) => s.active).toList();
    final amazonShops = activeShops
        .where((s) => s.name.trim().toLowerCase().startsWith('amazon'))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final otherShops = activeShops
        .where((s) => !s.name.trim().toLowerCase().startsWith('amazon'))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    // Vorausgefüllter Shop ("Amazon" aus Inbox-Suggestion) matcht oft kein
    // exaktes Item ("Amazon-DE", "Amazon-COM", …). Wenn der Wert nicht in
    // der Liste ist, würde der DropdownButton mit "exactly one item"
    // assertionen — daher hier auf den ersten passenden umbiegen oder auf
    // null fallen.
    if (_shop != null && !activeShops.any((s) => s.name == _shop)) {
      final fallback = activeShops
          .where((s) =>
              s.name.toLowerCase().startsWith(_shop!.toLowerCase()) ||
              _shop!.toLowerCase().startsWith(s.name.toLowerCase()))
          .firstOrNull;
      _shop = fallback?.name;
    }
    final buyers = provider.buyers.where((b) => b.active).toList();
    final dateFmt = DateFormat.yMd(
        Localizations.localeOf(context).toLanguageTag());

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
                      widget.deal != null ? l10n.dealEdit : l10n.dealNew,
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
                        _sectionLabel(l10n.dealSectionProduct),
                        const SizedBox(height: 10),
                        _row(narrow, [
                          _ProductAutocomplete(
                            controller: _productCtrl,
                            pastDeals: provider.deals,
                            onPickPast: _applyTemplate,
                          ),
                          TextFormField(
                            controller: _quantityCtrl,
                            decoration: InputDecoration(
                                labelText: '${l10n.dealQuantity} *'),
                            keyboardType: TextInputType.number,
                            validator: Validators.validatePositiveInt,
                          ),
                        ], flex: [3, 1]),
                        const SizedBox(height: 12),
                        _row(narrow, [
                          DropdownButtonFormField<bool>(
                            initialValue: _isDropship,
                            decoration: InputDecoration(
                                labelText: '${l10n.dealShippingType} *'),
                            items: [
                              DropdownMenuItem(
                                  value: false, child: Text(l10n.dealReship)),
                              DropdownMenuItem(
                                  value: true,
                                  child: Text(l10n.dealDropship)),
                            ],
                            onChanged: (v) =>
                                setState(() => _isDropship = v ?? false),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _shop,
                            decoration:
                                InputDecoration(labelText: '${l10n.dealShop} *'),
                            items: [
                              for (final s in amazonShops)
                                DropdownMenuItem(
                                    value: s.name, child: Text(s.name)),
                              if (amazonShops.isNotEmpty &&
                                  otherShops.isNotEmpty)
                                const DropdownMenuItem<String>(
                                  enabled: false,
                                  child: Divider(height: 1),
                                ),
                              for (final s in otherShops)
                                DropdownMenuItem(
                                    value: s.name, child: Text(s.name)),
                            ],
                            onChanged: (v) => setState(() => _shop = v),
                            validator: (v) => v == null || v.isEmpty
                                ? l10n.commonRequired
                                : null,
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // ── Preise ──────────────────────────────────────
                        _sectionLabel(l10n.dealSectionPrices),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(l10n.dealEkPriceLabel,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569))),
                            const SizedBox(width: 12),
                            _radioOption('Netto', l10n.dealPriceTypeNet),
                            const SizedBox(width: 12),
                            _radioOption('Brutto', l10n.dealPriceTypeGross),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.dealEkAmount,
                                  prefixText: '€ ',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) => Validators.validateMoney(v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _vkCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.dealVkAmount,
                                  prefixText: '€ ',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) => Validators.validateMoney(v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _currency,
                                decoration: InputDecoration(
                                  labelText: l10n.dealCurrency,
                                  prefixIcon:
                                      const Icon(Icons.euro_symbol, size: 18),
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
                                decoration: InputDecoration(
                                  labelText: l10n.dealTaxRate,
                                  hintText: l10n.dealTaxRateHint,
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
                                  if (n == null) return l10n.dealTaxRateInvalid;
                                  if (n < 0 || n > 100) {
                                    return l10n.dealTaxRateRange;
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // ── Käufer & Status ─────────────────────────────
                        _sectionLabel(l10n.dealSectionBuyer),
                        const SizedBox(height: 10),
                        _row(narrow, [
                          DropdownButtonFormField<String>(
                            initialValue: _buyer,
                            decoration: InputDecoration(
                                labelText: l10n.dealBuyer),
                            items: [
                              DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(l10n.dealBuyerNone)),
                              ...buyers.map((b) => DropdownMenuItem(
                                  value: b.name, child: Text(b.name))),
                            ],
                            onChanged: (v) {
                              setState(() => _buyer = v);
                            },
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: InputDecoration(
                                labelText: l10n.dealStatus),
                            items: InventoryProvider.statusOptions
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                        localizeDealStatus(context, s))))
                                .toList(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                          DropdownButtonFormField<bool>(
                            initialValue: _hasReceipt,
                            decoration: InputDecoration(
                                labelText: l10n.dealReceipt),
                            items: [
                              DropdownMenuItem(
                                  value: false,
                                  child: Text(l10n.dealReceiptNo)),
                              DropdownMenuItem(
                                  value: true,
                                  child: Text(l10n.dealReceiptYes)),
                            ],
                            onChanged: (v) =>
                                setState(() => _hasReceipt = v ?? false),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // ── Datum & Tracking ────────────────────────────
                        _sectionLabel(l10n.dealSectionDateTracking),
                        const SizedBox(height: 10),
                        _row(narrow, [
                          _DatePickerField(
                            label: '${l10n.dealOrderDate} *',
                            date: _orderDate,
                            onTap: () => _pickDate(ctx, false),
                            dateFmt: dateFmt,
                          ),
                          _DatePickerField(
                            label: l10n.dealArrivalDate,
                            date: _arrivalDate,
                            onTap: () => _pickDate(ctx, true),
                            dateFmt: dateFmt,
                            placeholder: l10n.commonNotSet,
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _row(narrow, [
                          TextFormField(
                            controller: _ticketCtrl,
                            decoration: InputDecoration(
                                labelText: l10n.dealTicketNumber),
                            maxLength: Validators.maxTicket,
                            validator: (v) => Validators.validateTicket(v),
                            onChanged: _onTicketChanged,
                          ),
                          TextFormField(
                            controller: _trackingCtrl,
                            decoration: InputDecoration(
                                labelText: l10n.dealTracking),
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
                             decoration: InputDecoration(
                               labelText: l10n.dealTicketUrl,
                               hintText: l10n.dealTicketUrlHint,
                               prefixIcon: const Icon(Icons.link, size: 18),
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
                        _sectionLabel(l10n.dealSectionAttachments),
                        const SizedBox(height: 10),
                        AttachmentGallery(
                          paths: _attachmentPaths,
                          entityKind: 'deal',
                          entityId: widget.deal != null
                              ? widget.deal!.id.toString()
                              : '',
                          onChanged: (next) =>
                              setState(() => _attachmentPaths = next),
                        ),
                        const SizedBox(height: 20),
                        _sectionLabel(l10n.dealNote),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _noteCtrl,
                          decoration: InputDecoration(
                              labelText: l10n.dealNote),
                          maxLines: 2,
                          maxLength: Validators.maxNote,
                          validator: Validators.validateNote,
                        ),
                        if (widget.deal != null) ...[
                          const SizedBox(height: 20),
                          _sectionLabel(l10n.dealComments),
                          const SizedBox(height: 10),
                          DealCommentsSection(dealId: widget.deal!.id),
                        ],
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
                    child: Text(l10n.actionCancel),
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
                    label: Text(
                        _saving ? l10n.actionSaving : l10n.actionSave),
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
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
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
    final fmt = NumberFormat.currency(locale: localeTag, symbol: '€');

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
          const Icon(Icons.calculate_outlined,
              size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              profit == null
                  ? l10n.dealProfitPreviewMissing
                  : l10n.dealProfitPreviewLine(
                      fmt.format(profit), fmt.format(total)),
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
              final l10n = AppLocalizations.of(ctx);
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
                    ? l10n.dealDiscordTicketOpen
                    : l10n.dealDiscordServerOpen(i + 1)),
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
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).dealDiscordChannelHint,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
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

/// Produkt-Eingabefeld mit Vorschlägen aus vergangenen Deals.
///
/// Zeigt für jedes vorgeschlagene Produkt den jüngsten Deal mit den
/// häufigsten Begleitwerten (Shop, EK, Käufer) — Tippen übernimmt diesen Deal
/// als Vorlage via [onPickPast]. Bleibt der Text frei eingegeben, wird nur
/// das Produktfeld gesetzt.
class _ProductAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<Deal> pastDeals;
  final ValueChanged<Deal> onPickPast;

  const _ProductAutocomplete({
    required this.controller,
    required this.pastDeals,
    required this.onPickPast,
  });

  /// Pro eindeutigem Produktnamen den jüngsten Deal — sortiert nach Datum
  /// absteigend, damit die letzte Konfiguration als Vorschlag oben steht.
  List<Deal> _latestPerProduct() {
    final byName = <String, Deal>{};
    for (final d in pastDeals) {
      final key = d.product.trim().toLowerCase();
      if (key.isEmpty) continue;
      final existing = byName[key];
      if (existing == null || d.orderDate.isAfter(existing.orderDate)) {
        byName[key] = d;
      }
    }
    final list = byName.values.toList()
      ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestPerProduct();
    return Autocomplete<Deal>(
      displayStringForOption: (d) => d.product,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return latest.take(8);
        return latest
            .where((d) => d.product.toLowerCase().contains(q))
            .take(8);
      },
      onSelected: (deal) {
        controller.text = deal.product;
        onPickPast(deal);
      },
      fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
        // Halte den extern gepflegten Controller mit dem Autocomplete-Feld in
        // sync — wir wollen den Wert von außen lesen können (im _save-Flow).
        if (textCtrl.text != controller.text) {
          textCtrl.text = controller.text;
          textCtrl.selection =
              TextSelection.collapsed(offset: textCtrl.text.length);
        }
        textCtrl.addListener(() {
          if (controller.text != textCtrl.text) {
            controller.text = textCtrl.text;
          }
        });
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
              labelText: '${AppLocalizations.of(ctx).dealProduct} *'),
          maxLength: Validators.maxProductName,
          validator: Validators.validateProductName,
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        final list = options.toList();
        final localeTag = Localizations.localeOf(ctx).toLanguageTag();
        final money = NumberFormat.currency(locale: localeTag, symbol: '€');
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (_, i) {
                  final d = list[i];
                  final ek = d.ekBrutto ?? d.ekNetto;
                  final summary = [
                    d.shop,
                    if (ek != null) 'EK ${money.format(ek)}',
                    if (d.vk != null) 'VK ${money.format(d.vk)}',
                    if (d.buyer != null) d.buyer,
                  ].join(' · ');
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history,
                        size: 18, color: Color(0xFF64748B)),
                    title: Text(d.product,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      summary,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(d),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
