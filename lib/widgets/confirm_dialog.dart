import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unicode-Bidi sanitizer
// ─────────────────────────────────────────────────────────────────────────────

/// Entfernt Unicode-Bidi-Override-Zeichen und Zero-Width-Chars aus [input].
///
/// Filtert heraus:
/// - Bidi-Override-Zeichen: U+202A–U+202E (LRM, RLM, LRE, RLE, PDF, LRO, RLO)
/// - Bidi-Isolate-Zeichen: U+2066–U+2069 (LRI, RLI, FSI, PDI)
/// - Zero-Width-Chars: U+200B (ZWSP), U+200C (ZWNJ), U+200D (ZWJ), U+FEFF (BOM)
///
/// Defense-in-Depth: verhindert visuelles Spoofing im [requireTypeName]-Mode,
/// bei dem der angezeigte String mit dem Nutzereingabe-String verglichen wird.
// Pre-built RegExp using String.fromCharCode escapes to avoid the
// text_direction_code_point_in_literal analyzer warning.
//
// Strips:
//   U+200B ZWSP · U+200C ZWNJ · U+200D ZWJ · U+200E LRM · U+200F RLM
//   U+202A LRE  · U+202B RLE  · U+202C PDF  · U+202D LRO · U+202E RLO
//   U+2066 LRI  · U+2067 RLI  · U+2068 FSI  · U+2069 PDI
//   U+FEFF BOM
final RegExp _bidiPattern = RegExp(
  '[${String.fromCharCode(0x200B)}'
  '${String.fromCharCode(0x200C)}'
  '${String.fromCharCode(0x200D)}'
  '${String.fromCharCode(0x200E)}'
  '${String.fromCharCode(0x200F)}'
  '${String.fromCharCode(0x202A)}'
  '${String.fromCharCode(0x202B)}'
  '${String.fromCharCode(0x202C)}'
  '${String.fromCharCode(0x202D)}'
  '${String.fromCharCode(0x202E)}'
  '${String.fromCharCode(0x2066)}'
  '${String.fromCharCode(0x2067)}'
  '${String.fromCharCode(0x2068)}'
  '${String.fromCharCode(0x2069)}'
  '${String.fromCharCode(0xFEFF)}'
  ']',
);

String _sanitizeBidi(String input) => input.replaceAll(_bidiPattern, '');

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Zeigt einen Confirm-Dialog und gibt `true` (bestätigt), `false` (abgebrochen)
/// oder `null` (Dialog geschlossen ohne Entscheidung) zurück.
///
/// **Phone vs. Desktop:**
/// - Phone (< [Breakpoints.phone]): `showModalBottomSheet` mit Keyboard-Inset
///   via `MediaQuery.viewInsetsOf`. Confirm/Cancel als breite Buttons.
/// - Desktop: zentrierter `AlertDialog`.
///
/// **[isDestructive]:**
/// Wenn `true`, erhält der Confirm-Button danger-Styling. `barrierDismissible`
/// ist dann `false`. `HapticFeedback.lightImpact()` wird beim Confirm ausgelöst.
///
/// **[requireTypeName]:**
/// Wenn gesetzt, muss der Nutzer den exakten String (Bidi-sanitized) tippen,
/// bevor der Confirm-Button aktiviert wird. Nützlich für irreversible Aktionen.
/// `PopScope` verhindert Back-Navigation bis der Name korrekt eingegeben ist
/// (oder der Nutzer Cancel wählt).
///
/// **A11y-Keys:**
/// - `Key('confirmDialog')` — Root-Widget
/// - `Key('confirmDialog-confirm')` — Confirm-Button
/// - `Key('confirmDialog-cancel')` — Cancel-Button
/// - `Key('confirmDialog-typeName-field')` — TextField im requireTypeName-Mode
///
/// Beispiel:
/// ```dart
/// final confirmed = await showConfirmDialog(
///   context: context,
///   title: l10n.dealDeleteTitle,
///   message: l10n.dealDeleteConfirm(product: name, id: id),
///   confirmLabel: l10n.actionDelete,
///   isDestructive: true,
/// );
/// if (confirmed == true) { /* delete */ }
/// ```
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  String? requireTypeName,
}) async {
  final isPhone = MediaQuery.sizeOf(context).width < Breakpoints.phone;

  if (isPhone) {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: !isDestructive,
      enableDrag: !isDestructive,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmDialogContent(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        requireTypeName: requireTypeName,
        isBottomSheet: true,
      ),
    );
    return result ?? false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !isDestructive,
    builder: (ctx) => _ConfirmDialogContent(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
      requireTypeName: requireTypeName,
      isBottomSheet: false,
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal StatefulWidget (shared between sheet and dialog)
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDialogContent extends StatefulWidget {
  const _ConfirmDialogContent({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDestructive,
    required this.isBottomSheet,
    this.cancelLabel,
    this.requireTypeName,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final bool isDestructive;
  final bool isBottomSheet;
  final String? requireTypeName;

  @override
  State<_ConfirmDialogContent> createState() => _ConfirmDialogContentState();
}

class _ConfirmDialogContentState extends State<_ConfirmDialogContent> {
  final TextEditingController _typeNameController = TextEditingController();
  bool _typeNameMatches = false;

  bool get _isTypeNameMode => widget.requireTypeName != null;

  /// Der sanitisierte Vergleichswert (Bidi-Chars entfernt).
  String get _sanitizedRequiredName =>
      widget.requireTypeName != null ? _sanitizeBidi(widget.requireTypeName!) : '';

  @override
  void initState() {
    super.initState();
    _typeNameController.addListener(_onTypeNameChanged);
  }

  @override
  void dispose() {
    _typeNameController.removeListener(_onTypeNameChanged);
    _typeNameController.dispose();
    super.dispose();
  }

  void _onTypeNameChanged() {
    final matches = _typeNameController.text == _sanitizedRequiredName;
    if (matches != _typeNameMatches) {
      setState(() => _typeNameMatches = matches);
    }
  }

  bool get _canConfirm => !_isTypeNameMode || _typeNameMatches;

  void _onConfirm() {
    if (!_canConfirm) return;
    if (widget.isDestructive) HapticFeedback.lightImpact();
    Navigator.of(context).pop(true);
  }

  void _onCancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    // PopScope muss INNERHALB des Dialog-Trees liegen (Plan §5.1 Bug-Hunter-Fix).
    // canPop = false wenn requireTypeName-Mode aktiv UND Name noch nicht korrekt.
    return PopScope(
      canPop: !_isTypeNameMode || _typeNameMatches,
      onPopInvokedWithResult: (didPop, _) {
        // Wenn Back-Button gedrückt und canPop=false: nichts tun.
        // User muss Cancel-Button nutzen.
      },
      child: widget.isBottomSheet ? _buildSheet(context) : _buildDialog(context),
    );
  }

  // ── Bottom-Sheet-Variante (Phone) ─────────────────────────────────────────

  Widget _buildSheet(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: const Key('confirmDialog'),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        // Keyboard-Inset + Safe-Area-Bottom + eigenes Padding
        keyboardInset.bottom + bottomPadding + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag-Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.borderStrongOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildTitle(context),
          const SizedBox(height: 12),
          _buildMessage(context),
          if (_isTypeNameMode) ...[
            const SizedBox(height: 16),
            _buildTypeNameField(context),
          ],
          const SizedBox(height: 24),
          // Breite Buttons — Touch-Targets ≥ 48 dp
          _buildConfirmButton(context, fullWidth: true),
          const SizedBox(height: 12),
          _buildCancelButton(context, fullWidth: true),
        ],
      ),
    );
  }

  // ── Dialog-Variante (Desktop) ─────────────────────────────────────────────

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      key: const Key('confirmDialog'),
      title: _buildTitle(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessage(context),
          if (_isTypeNameMode) ...[
            const SizedBox(height: 16),
            _buildTypeNameField(context),
          ],
        ],
      ),
      actions: [
        _buildCancelButton(context, fullWidth: false),
        _buildConfirmButton(context, fullWidth: false),
      ],
    );
  }

  // ── Shared Sub-Widgets ────────────────────────────────────────────────────

  Widget _buildTitle(BuildContext context) {
    return Text(
      widget.title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: widget.isDestructive
            ? AppTheme.dangerTextOf(context)
            : AppTheme.textPrimaryOf(context),
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Text(
      widget.message,
      style: TextStyle(
        fontSize: 14,
        color: AppTheme.textSecondaryOf(context),
      ),
    );
  }

  Widget _buildTypeNameField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Sanitize the display value (strip Bidi before showing).
    final displayName = _sanitizeBidi(widget.requireTypeName!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmTypeNamePrompt(displayName),
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textMutedOf(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('confirmDialog-typeName-field'),
          controller: _typeNameController,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimaryOf(context),
          ),
          decoration: InputDecoration(
            hintText: displayName,
            hintStyle: TextStyle(color: AppTheme.textDisabledOf(context)),
            suffixIcon: _typeNameMatches
                ? Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton(BuildContext context, {required bool fullWidth}) {
    final isEnabled = _canConfirm;
    final button = SizedBox(
      height: 48,
      width: fullWidth ? double.infinity : null,
      child: FilledButton(
        key: const Key('confirmDialog-confirm'),
        onPressed: isEnabled ? _onConfirm : null,
        style: FilledButton.styleFrom(
          backgroundColor: widget.isDestructive
              ? AppTheme.dangerTextOf(context)
              : null,
          foregroundColor: widget.isDestructive
              ? Theme.of(context).colorScheme.onError
              : null,
          disabledBackgroundColor: AppTheme.borderOf(context),
          disabledForegroundColor: AppTheme.textDisabledOf(context),
        ),
        child: Text(widget.confirmLabel),
      ),
    );
    return button;
  }

  Widget _buildCancelButton(BuildContext context, {required bool fullWidth}) {
    return SizedBox(
      height: 48,
      width: fullWidth ? double.infinity : null,
      child: TextButton(
        key: const Key('confirmDialog-cancel'),
        onPressed: _onCancel,
        child: Text(
          widget.cancelLabel ??
              AppLocalizations.of(context).commonCancel,
        ),
      ),
    );
  }
}
