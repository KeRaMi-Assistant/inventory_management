import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/billing_provider.dart';

/// Formular für die Rechnungsdaten. Aufrufbar entweder direkt aus den
/// Settings (zum Verwalten/Aktualisieren) oder vom Pricing-Screen vor
/// einem kostenpflichtigen Upgrade. Im Upgrade-Fall ([requireCompleteForPaidPlan]
/// = true) markieren wir die Pflichtfelder visuell und erlauben das
/// Speichern nur, wenn alle Pflichtangaben gesetzt sind.
class BillingProfileScreen extends StatefulWidget {
  final bool requireCompleteForPaidPlan;
  const BillingProfileScreen({
    super.key,
    this.requireCompleteForPaidPlan = false,
  });

  @override
  State<BillingProfileScreen> createState() => _BillingProfileScreenState();
}

class _BillingProfileScreenState extends State<BillingProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullName;
  late TextEditingController _company;
  late TextEditingController _vatId;
  late TextEditingController _phone;
  late TextEditingController _addr1;
  late TextEditingController _addr2;
  late TextEditingController _postal;
  late TextEditingController _city;
  late TextEditingController _region;
  late TextEditingController _country;
  bool _saving = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _company = TextEditingController();
    _vatId = TextEditingController();
    _phone = TextEditingController();
    _addr1 = TextEditingController();
    _addr2 = TextEditingController();
    _postal = TextEditingController();
    _city = TextEditingController();
    _region = TextEditingController();
    _country = TextEditingController(text: 'DE');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final billing = context.read<BillingProvider>();
      if (billing.profile == null && !billing.isLoading) {
        await billing.load();
      }
      if (!mounted) return;
      _hydrate(billing.profile);
    });
  }

  void _hydrate(BillingProfile? p) {
    if (p == null || _initialised) return;
    _fullName.text = p.fullName ?? '';
    _company.text = p.company ?? '';
    _vatId.text = p.vatId ?? '';
    _phone.text = p.phone ?? '';
    _addr1.text = p.addressLine1 ?? '';
    _addr2.text = p.addressLine2 ?? '';
    _postal.text = p.postalCode ?? '';
    _city.text = p.city ?? '';
    _region.text = p.region ?? '';
    _country.text = p.country;
    _initialised = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    _vatId.dispose();
    _phone.dispose();
    _addr1.dispose();
    _addr2.dispose();
    _postal.dispose();
    _city.dispose();
    _region.dispose();
    _country.dispose();
    super.dispose();
  }

  bool get _isPaidContext {
    if (widget.requireCompleteForPaidPlan) return true;
    final p = context.read<BillingProvider>().profile;
    return p?.plan.isPaid ?? false;
  }

  String? _requiredValidator(String? v) {
    if (!_isPaidContext) return null;
    if ((v ?? '').trim().isEmpty) {
      return AppLocalizations.of(context).billingProfileRequiredForPaid;
    }
    return null;
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    if (!form.validate()) return;

    setState(() => _saving = true);
    try {
      final billing = context.read<BillingProvider>();
      final uid = context.read<AuthProvider>().currentUser?.id;
      final base = billing.profile ??
          BillingProfile.defaultFor(uid ?? '');
      final updated = base.copyWith(
        fullName: _fullName.text,
        company: _company.text,
        vatId: _vatId.text,
        phone: _phone.text,
        addressLine1: _addr1.text,
        addressLine2: _addr2.text,
        postalCode: _postal.text,
        city: _city.text,
        region: _region.text,
        country: _country.text.trim().toUpperCase(),
        updatedAt: DateTime.now().toUtc(),
      );
      await billing.save(updated);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.billingProfileSaved)),
      );
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.billingProfileSaveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final billing = context.watch<BillingProvider>();
    if (!_initialised && billing.profile != null) {
      _hydrate(billing.profile);
    }
    final paidContext = _isPaidContext;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billingProfileTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.actionSave),
          ),
        ],
      ),
      body: billing.isLoading && billing.profile == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (paidContext) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFE082),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(l10n.billingProfileIntroBody),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _SectionHeader('Kontaktperson'),
                    const SizedBox(height: 8),
                    _Field(
                      controller: _fullName,
                      label: l10n.billingProfileFullName,
                      required: paidContext,
                      validator: _requiredValidator,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _company,
                      label: 'Firma (optional)',
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _vatId,
                      label: 'USt-IdNr. (optional)',
                      hint: 'DE123456789',
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _phone,
                      label: 'Telefon',
                      required: paidContext,
                      validator: _requiredValidator,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9 +\-/()]'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader('Rechnungsadresse'),
                    const SizedBox(height: 8),
                    _Field(
                      controller: _addr1,
                      label: l10n.billingProfileStreet,
                      required: paidContext,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _addr2,
                      label: 'Adresszusatz (optional)',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: _Field(
                            controller: _postal,
                            label: 'PLZ',
                            required: paidContext,
                            validator: _requiredValidator,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9A-Za-z\- ]'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _city,
                            label: 'Ort',
                            required: paidContext,
                            validator: _requiredValidator,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _region,
                            label: 'Bundesland (optional)',
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: _Field(
                            controller: _country,
                            label: 'Land',
                            required: true,
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.length != 2) {
                                return 'ISO 2-Buchstaben';
                              }
                              return null;
                            },
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(2),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z]'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_saving
                            ? l10n.billingProfileSavingDots
                            : l10n.actionSave),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.billingProfilePrivacyHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
