import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/supplier.dart';
import '../providers/inventory_provider.dart';
import '../utils/validators.dart';
import 'unsaved_changes_guard.dart';

/// Snapshot der Initialwerte für die Dirty-Detection im Lieferanten-Dialog.
class _SupplierFormSnapshot {
  const _SupplierFormSnapshot({
    required this.name,
    required this.contact,
    required this.email,
    required this.phone,
    required this.website,
    required this.note,
    required this.active,
    required this.street,
    required this.zip,
    required this.city,
    required this.country,
    required this.vatId,
    required this.customerNumber,
    required this.paymentTerms,
    required this.leadTime,
    required this.minOrderValue,
  });

  final String name;
  final String contact;
  final String email;
  final String phone;
  final String website;
  final String note;
  final bool active;
  final String street;
  final String zip;
  final String city;
  final String country;
  final String vatId;
  final String customerNumber;
  final String paymentTerms;
  final String leadTime;
  final String minOrderValue;
}

/// Dialog zum Anlegen und Bearbeiten eines Lieferanten.
///
/// **UnsavedChangesGuard:** `barrierDismissible: false` ist beim showDialog-Aufrufer
/// Pflicht (z.B. in `suppliers_screen.dart`), damit der Guard greifen kann.
class AddEditSupplierDialog extends StatefulWidget {
  final Supplier? supplier;
  const AddEditSupplierDialog({super.key, this.supplier});

  @override
  State<AddEditSupplierDialog> createState() => _AddEditSupplierDialogState();
}

class _AddEditSupplierDialogState extends State<AddEditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();

  // Basic fields
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _active = true;

  // Advanced / extended kreditor fields
  final _streetCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _vatIdCtrl = TextEditingController();
  final _customerNumberCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  final _leadTimeCtrl = TextEditingController();
  final _minOrderValueCtrl = TextEditingController();

  bool _advancedExpanded = false;

  // ── Dirty-Detection ───────────────────────────────────────────────────────
  late _SupplierFormSnapshot _initialSnapshot;
  bool _wasDirty = false;

  /// Alle TextController — zum komfortablen Listener-Management.
  List<TextEditingController> get _allCtrls => [
        _nameCtrl,
        _contactCtrl,
        _emailCtrl,
        _phoneCtrl,
        _websiteCtrl,
        _noteCtrl,
        _streetCtrl,
        _zipCtrl,
        _cityCtrl,
        _countryCtrl,
        _vatIdCtrl,
        _customerNumberCtrl,
        _paymentTermsCtrl,
        _leadTimeCtrl,
        _minOrderValueCtrl,
      ];

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    if (s != null) {
      _nameCtrl.text = s.name;
      _contactCtrl.text = s.contactName ?? '';
      _emailCtrl.text = s.email ?? '';
      _phoneCtrl.text = s.phone ?? '';
      _websiteCtrl.text = s.website ?? '';
      _noteCtrl.text = s.note ?? '';
      _active = s.active;
      // Advanced
      _streetCtrl.text = s.addressStreet ?? '';
      _zipCtrl.text = s.addressZip ?? '';
      _cityCtrl.text = s.addressCity ?? '';
      _countryCtrl.text = s.addressCountry ?? '';
      _vatIdCtrl.text = s.vatId ?? '';
      _customerNumberCtrl.text = s.customerNumber ?? '';
      _paymentTermsCtrl.text =
          s.paymentTermsDays != null ? '${s.paymentTermsDays}' : '';
      _leadTimeCtrl.text = s.leadTimeDays != null ? '${s.leadTimeDays}' : '';
      _minOrderValueCtrl.text =
          s.minOrderValue != null ? '${s.minOrderValue}' : '';

      // Auto-expand if any advanced field is already filled.
      if (_streetCtrl.text.isNotEmpty ||
          _zipCtrl.text.isNotEmpty ||
          _cityCtrl.text.isNotEmpty ||
          _vatIdCtrl.text.isNotEmpty ||
          _customerNumberCtrl.text.isNotEmpty ||
          _paymentTermsCtrl.text.isNotEmpty ||
          _leadTimeCtrl.text.isNotEmpty ||
          _minOrderValueCtrl.text.isNotEmpty) {
        _advancedExpanded = true;
      }
    }

    // Snapshot direkt nach dem Befüllen festhalten.
    _initialSnapshot = _captureSnapshot();

    // Dirty-Listener: setState nur wenn sich _isDirty ändert.
    for (final ctrl in _allCtrls) {
      ctrl.addListener(_checkDirtyChanged);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _allCtrls) {
      ctrl.removeListener(_checkDirtyChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Dirty-Detection Helpers ───────────────────────────────────────────────

  _SupplierFormSnapshot _captureSnapshot() => _SupplierFormSnapshot(
        name: _nameCtrl.text,
        contact: _contactCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        website: _websiteCtrl.text,
        note: _noteCtrl.text,
        active: _active,
        street: _streetCtrl.text,
        zip: _zipCtrl.text,
        city: _cityCtrl.text,
        country: _countryCtrl.text,
        vatId: _vatIdCtrl.text,
        customerNumber: _customerNumberCtrl.text,
        paymentTerms: _paymentTermsCtrl.text,
        leadTime: _leadTimeCtrl.text,
        minOrderValue: _minOrderValueCtrl.text,
      );

  bool get _isDirty {
    final s = _initialSnapshot;
    return _nameCtrl.text != s.name ||
        _contactCtrl.text != s.contact ||
        _emailCtrl.text != s.email ||
        _phoneCtrl.text != s.phone ||
        _websiteCtrl.text != s.website ||
        _noteCtrl.text != s.note ||
        _active != s.active ||
        _streetCtrl.text != s.street ||
        _zipCtrl.text != s.zip ||
        _cityCtrl.text != s.city ||
        _countryCtrl.text != s.country ||
        _vatIdCtrl.text != s.vatId ||
        _customerNumberCtrl.text != s.customerNumber ||
        _paymentTermsCtrl.text != s.paymentTerms ||
        _leadTimeCtrl.text != s.leadTime ||
        _minOrderValueCtrl.text != s.minOrderValue;
  }

  /// setState nur bei Dirty-Status-Wechsel — nicht bei jedem Tastendruck.
  void _checkDirtyChanged() {
    if (!mounted) return;
    final nowDirty = _isDirty;
    if (nowDirty != _wasDirty) {
      setState(() => _wasDirty = nowDirty);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);

    String? website = Validators.sanitizeOrNull(_websiteCtrl.text);
    if (website != null && !website.startsWith('http')) {
      website = 'https://$website';
    }

    final supplier = Supplier(
      id: widget.supplier?.id ?? '',
      name: Validators.sanitize(_nameCtrl.text),
      contactName: Validators.sanitizeOrNull(_contactCtrl.text),
      email: Validators.sanitizeOrNull(_emailCtrl.text),
      phone: Validators.sanitizeOrNull(_phoneCtrl.text),
      website: website,
      note: Validators.sanitizeOrNull(_noteCtrl.text),
      active: _active,
      // Advanced
      addressStreet: Validators.sanitizeOrNull(_streetCtrl.text),
      addressZip: Validators.sanitizeOrNull(_zipCtrl.text),
      addressCity: Validators.sanitizeOrNull(_cityCtrl.text),
      addressCountry: Validators.sanitizeOrNull(_countryCtrl.text),
      vatId: Validators.sanitizeOrNull(_vatIdCtrl.text),
      customerNumber: Validators.sanitizeOrNull(_customerNumberCtrl.text),
      paymentTermsDays: int.tryParse(_paymentTermsCtrl.text.trim()),
      leadTimeDays: int.tryParse(_leadTimeCtrl.text.trim()),
      minOrderValue: double.tryParse(
          _minOrderValueCtrl.text.trim().replaceAll(',', '.')),
    );

    try {
      if (widget.supplier != null) {
        await provider.updateSupplier(
            supplier.copyWith(id: widget.supplier!.id));
      } else {
        await provider.addSupplier(supplier);
      }
      if (context.mounted) navigator.pop();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.pushSaveFailed('$e')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.supplier != null
                              ? l10n.supplierEditTitle
                              : l10n.supplierAddTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        // maybePop damit UnsavedChangesGuard greifen kann
                        onPressed: () => Navigator.maybePop(context),
                        tooltip: l10n.actionClose,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Scrollable form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Basic fields ────────────────────────────────
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: '${l10n.fieldName} *',
                            ),
                            validator: (v) => Validators.validateRequired(
                                v,
                                label: l10n.fieldName),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _contactCtrl,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: l10n.supplierContactName,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emailCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: l10n.fieldEmail,
                              prefixIcon:
                                  const Icon(Icons.email_outlined, size: 18),
                            ),
                            validator: (v) {
                              final s = Validators.sanitize(v);
                              if (s.isEmpty) return null;
                              return Validators.validateEmail(s);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _phoneCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.phone,
                            maxLength: 40,
                            decoration: InputDecoration(
                              labelText: l10n.supplierPhone,
                              prefixIcon:
                                  const Icon(Icons.phone_outlined, size: 18),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _websiteCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              labelText: l10n.supplierWebsite,
                              prefixIcon: const Icon(Icons.link, size: 18),
                            ),
                            validator: (v) => Validators.validateUrl(v),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _noteCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.dealNote,
                            ),
                            maxLength: Validators.maxNote,
                            maxLines: 3,
                            validator: Validators.validateNote,
                          ),
                          SwitchListTile(
                            value: _active,
                            onChanged: (v) {
                              setState(() => _active = v);
                              _checkDirtyChanged();
                            },
                            title: Text(l10n.supplierActive),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 4),

                          // ── Advanced section (collapsible) ──────────────
                          _AdvancedSection(
                            expanded: _advancedExpanded,
                            onToggle: () => setState(
                                () => _advancedExpanded = !_advancedExpanded),
                            children: [
                              // Address sub-group
                              _SectionLabel(
                                icon: Icons.location_on_outlined,
                                label: l10n.supplierAddress,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _streetCtrl,
                                textInputAction: TextInputAction.next,
                                maxLength: 200,
                                decoration: InputDecoration(
                                  labelText: l10n.supplierAddressStreet,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: _zipCtrl,
                                      textInputAction: TextInputAction.next,
                                      keyboardType: TextInputType.number,
                                      maxLength: 10,
                                      decoration: InputDecoration(
                                        labelText: l10n.supplierAddressZip,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cityCtrl,
                                      textInputAction: TextInputAction.next,
                                      maxLength: 100,
                                      decoration: InputDecoration(
                                        labelText: l10n.supplierAddressCity,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _countryCtrl,
                                textInputAction: TextInputAction.next,
                                maxLength: 60,
                                decoration: InputDecoration(
                                  labelText: l10n.supplierAddressCountry,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Fiscal / commercial sub-group
                              _SectionLabel(
                                icon: Icons.receipt_outlined,
                                label: l10n.supplierVatId,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _vatIdCtrl,
                                textInputAction: TextInputAction.next,
                                maxLength: 30,
                                decoration: InputDecoration(
                                  labelText: l10n.supplierVatId,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _customerNumberCtrl,
                                textInputAction: TextInputAction.next,
                                maxLength: 50,
                                decoration: InputDecoration(
                                  labelText: l10n.supplierCustomerNumber,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Order terms sub-group
                              _SectionLabel(
                                icon: Icons.assignment_outlined,
                                label: l10n.supplierAdvancedSection,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _paymentTermsCtrl,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: l10n.supplierPaymentTerms,
                                  suffixText: l10n.commonDaysUnit,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return null;
                                  }
                                  final n = int.tryParse(v.trim());
                                  if (n == null || n < 0 || n > 9999) {
                                    return '0–9999';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _leadTimeCtrl,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: l10n.supplierLeadTime,
                                  suffixText: l10n.commonDaysUnit,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return null;
                                  }
                                  final n = int.tryParse(v.trim());
                                  if (n == null || n < 0 || n > 9999) {
                                    return '0–9999';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _minOrderValueCtrl,
                                textInputAction: TextInputAction.done,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText: l10n.supplierMinOrderValue,
                                  prefixText: '€ ',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return null;
                                  }
                                  final d = double.tryParse(
                                      v.trim().replaceAll(',', '.'));
                                  if (d == null || d < 0) {
                                    return '≥ 0';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        // maybePop damit UnsavedChangesGuard greifen kann
                        onPressed: () => Navigator.maybePop(context),
                        child: Text(l10n.actionCancel),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _save, child: Text(l10n.actionSave)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ), // ConstrainedBox
    ), // Dialog
    ); // UnsavedChangesGuard
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advanced collapsible section widget
// ─────────────────────────────────────────────────────────────────────────────

class _AdvancedSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _AdvancedSection({
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle row — full-width tap target ≥ 48 dp
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgSubtleOf(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.expand_more,
                  size: 20,
                  color: AppTheme.textMutedOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.supplierAdvancedSection,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Collapsible body
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small label with icon for sub-sections
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMutedOf(context),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
