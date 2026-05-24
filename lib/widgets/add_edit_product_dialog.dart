import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/validators.dart';

/// Dialog zum Anlegen und Bearbeiten eines Produkt-Stammsatzes ([Product]).
///
/// Mobile-First: `SingleChildScrollView` + `SafeArea` + `MediaQuery.viewInsetsOf`
/// garantieren, dass kein Feld auf 360×640 abgeschnitten oder von der Tastatur
/// verdeckt wird.
///
/// A11y-Keys: `Key('productCategoryDropdown')`, `Key('productSaveButton')`.
class AddEditProductDialog extends StatefulWidget {
  final Product? product;

  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _eanCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'Stk');
  final _defaultCostPriceCtrl = TextEditingController();
  final _defaultSalePriceCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController(text: '0');
  final _taxRateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // ── Dropdown state ────────────────────────────────────────────────────────
  String? _categoryId;
  String? _defaultSupplierId;
  bool _isActive = true;
  bool _advancedExpanded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      _skuCtrl.text = p.sku ?? '';
      _eanCtrl.text = p.ean ?? '';
      _unitCtrl.text = p.unit;
      _defaultCostPriceCtrl.text =
          p.defaultCostPrice?.toStringAsFixed(2) ?? '';
      _defaultSalePriceCtrl.text =
          p.defaultSalePrice?.toStringAsFixed(2) ?? '';
      _minStockCtrl.text = '${p.minStock}';
      _taxRateCtrl.text =
          p.taxRate?.toStringAsFixed(2) ?? '';
      _noteCtrl.text = p.note ?? '';
      _categoryId = p.categoryId;
      _defaultSupplierId = p.defaultSupplierId;
      _isActive = p.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _eanCtrl.dispose();
    _unitCtrl.dispose();
    _defaultCostPriceCtrl.dispose();
    _defaultSalePriceCtrl.dispose();
    _minStockCtrl.dispose();
    _taxRateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final product = Product(
      id: widget.product?.id ?? '',
      workspaceId: widget.product?.workspaceId ?? '',
      userId: widget.product?.userId ?? '',
      name: Validators.sanitize(_nameCtrl.text),
      sku: Validators.sanitizeOrNull(_skuCtrl.text),
      ean: Validators.sanitizeOrNull(_eanCtrl.text),
      categoryId: _categoryId,
      defaultSupplierId: _defaultSupplierId,
      unit: Validators.sanitize(_unitCtrl.text).isEmpty
          ? 'Stk'
          : Validators.sanitize(_unitCtrl.text),
      defaultCostPrice: _parseDouble(_defaultCostPriceCtrl.text),
      defaultSalePrice: _parseDouble(_defaultSalePriceCtrl.text),
      minStock: int.tryParse(_minStockCtrl.text.trim()) ?? 0,
      taxRate: _parseDouble(_taxRateCtrl.text),
      note: Validators.sanitizeOrNull(_noteCtrl.text),
      isActive: _isActive,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final l10n = AppLocalizations.of(context);
    try {
      if (widget.product != null) {
        await provider.updateProduct(product);
      } else {
        await provider.addProduct(product);
      }
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.pushSaveFailed('$e')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static double? _parseDouble(String text) {
    final v = text.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<InventoryProvider>();
    final wsProvider = context.watch<ActiveWorkspaceProvider>();
    final canEdit = wsProvider.role?.canEdit ?? false;

    // Bottom padding so keyboard doesn't obscure fields (Formular-Mobile-Checkliste)
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────────
              _buildHeader(context, l10n),
              // ── Form (scrollable) ──────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8 + keyboardInset),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Pflichtfelder ──────────────────────────────
                        _sectionLabel(context, l10n.productDetailSectionStammdaten),
                        const SizedBox(height: 12),

                        // Name (Pflicht)
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: '${l10n.productNameLabel} *',
                          ),
                          maxLength: Validators.maxProductName,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (v) => Validators.validateProductName(v),
                        ),
                        const SizedBox(height: 8),

                        // SKU + EAN nebeneinander
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _skuCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.productSkuLabel,
                                ),
                                maxLength: Validators.maxSku,
                                validator: (v) => Validators.validateSku(v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _eanCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.productEanLabel,
                                  prefixIcon:
                                      const Icon(Icons.qr_code_2, size: 18),
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 14,
                                validator: (v) => Validators.validateGtin(v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Warengruppe
                        DropdownButtonFormField<String?>(
                          key: const Key('productCategoryDropdown'),
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.productCategory,
                            prefixIcon: const Icon(
                                Icons.folder_outlined,
                                size: 18),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n.commonNone),
                            ),
                            ...provider.productCategories.map(
                              (c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: canEdit
                              ? (v) => setState(() => _categoryId = v)
                              : null,
                        ),
                        const SizedBox(height: 8),

                        // Standard-Lieferant
                        DropdownButtonFormField<String?>(
                          initialValue: _defaultSupplierId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.productDefaultSupplier,
                            prefixIcon: const Icon(
                                Icons.local_shipping_outlined,
                                size: 18),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n.commonNone),
                            ),
                            ...provider.activeSuppliers.map(
                              (s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: canEdit
                              ? (v) =>
                                  setState(() => _defaultSupplierId = v)
                              : null,
                        ),
                        const SizedBox(height: 8),

                        // Mindestbestand + Einheit
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minStockCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.productMinStock,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    Validators.validateNonNegativeInt(v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _defaultCostPriceCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.productDefaultCostPrice,
                                  prefixText: '€ ',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) =>
                                    Validators.validateMoney(v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Aktiv-Switch
                        SwitchListTile(
                          value: _isActive,
                          onChanged: canEdit
                              ? (v) => setState(() => _isActive = v)
                              : null,
                          title: Text(l10n.productIsActive),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 4),

                        // ── Erweitert (zusammenklappbar) ───────────────
                        _buildAdvancedSection(context, l10n, canEdit),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Actions ────────────────────────────────────────────────
              _buildActions(context, l10n, canEdit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderOf(context)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentLightOf(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.accentTextOf(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.product != null
                  ? l10n.productEditTitle
                  : l10n.productAddTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
          // Close button — touch target ≥ 48 dp via padding
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.close,
                size: 20,
                color: AppTheme.textMutedOf(context),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection(
      BuildContext context, AppLocalizations l10n, bool canEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Clickable header — touch target ≥ 48 dp
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              setState(() => _advancedExpanded = !_advancedExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  l10n.productAdvancedSection.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMutedOf(context),
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    height: 1,
                    color: AppTheme.borderOf(context),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _advancedExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                  color: AppTheme.textMutedOf(context),
                ),
              ],
            ),
          ),
        ),
        if (_advancedExpanded) ...[
          // Einheit + Standard-VK
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _unitCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.productUnit),
                  maxLength: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _defaultSalePriceCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.productDefaultSalePrice,
                    prefixText: '€ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.validateMoney(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // MwSt.-Satz
          TextFormField(
            controller: _taxRateCtrl,
            decoration:
                InputDecoration(labelText: l10n.productTaxRate),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final s = (v ?? '').trim().replaceAll(',', '.');
              if (s.isEmpty) return null;
              final n = double.tryParse(s);
              if (n == null) return l10n.productInvalidNumber;
              if (n < 0 || n > 100) return '0–100 %';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Notiz
          TextFormField(
            controller: _noteCtrl,
            decoration:
                InputDecoration(labelText: l10n.productNoteLabel),
            maxLength: Validators.maxNote,
            maxLines: 3,
            validator: Validators.validateNote,
          ),
        ],
      ],
    );
  }

  Widget _buildActions(
      BuildContext context, AppLocalizations l10n, bool canEdit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.borderOf(context)),
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
          if (canEdit)
            ElevatedButton(
              key: const Key('productSaveButton'),
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
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMutedOf(context),
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(height: 1, color: AppTheme.borderOf(context)),
        ),
      ],
    );
  }
}
