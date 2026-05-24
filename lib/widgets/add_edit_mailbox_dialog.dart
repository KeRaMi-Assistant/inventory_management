import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/mailbox_account.dart';
import '../providers/inbox_provider.dart';
import 'unsaved_changes_guard.dart';

/// Snapshot der Initialwerte für die Dirty-Detection im Mailbox-Dialog.
class _MailboxFormSnapshot {
  const _MailboxFormSnapshot({
    required this.label,
    required this.host,
    required this.port,
    required this.username,
    required this.folder,
    required this.ssl,
    required this.enabled,
  });

  final String label;
  final String host;
  final String port;
  final String username;
  final String folder;
  final bool ssl;
  final bool enabled;
}

/// Dialog zum Anlegen/Bearbeiten eines IMAP-Postfachs. Das Passwort wird
/// nur lokal im State gehalten und sofort über `set_mailbox_password`
/// verschlüsselt persistiert.
///
/// **UnsavedChangesGuard:** Der Aufrufer muss `barrierDismissible: false`
/// setzen (z. B. in `settings_screen.dart`), damit der Guard greifen kann.
class AddEditMailboxDialog extends StatefulWidget {
  final MailboxAccount? existing;
  const AddEditMailboxDialog({super.key, this.existing});

  @override
  State<AddEditMailboxDialog> createState() => _AddEditMailboxDialogState();
}

class _AddEditMailboxDialogState extends State<AddEditMailboxDialog> {
  final _formKey = GlobalKey<FormState>();

  final _labelCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _folderCtrl = TextEditingController();

  late bool _ssl;
  late bool _enabled;

  bool _saving = false;
  bool _obscurePassword = true;

  bool get _isEdit => widget.existing != null;

  // ── Dirty-Detection ───────────────────────────────────────────────────────
  late _MailboxFormSnapshot _initialSnapshot;
  bool _wasDirty = false;

  /// Alle TextControllers zum komfortablen Listener-Management.
  /// Passwort-Controller ist bewusst NICHT enthalten — ein leeres Passwort-
  /// Feld beim Bearbeiten bedeutet "unverändert lassen", nicht "dirty".
  List<TextEditingController> get _allCtrls => [
        _labelCtrl,
        _hostCtrl,
        _portCtrl,
        _usernameCtrl,
        _folderCtrl,
      ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl.text = e?.label ?? '';
    _hostCtrl.text = e?.imapHost ?? 'imap.gmail.com';
    _portCtrl.text = '${e?.imapPort ?? 993}';
    _usernameCtrl.text = e?.username ?? '';
    _folderCtrl.text = e?.folder ?? 'INBOX';
    _ssl = e?.useSsl ?? true;
    _enabled = e?.enabled ?? true;
    // Passwort-Feld bleibt beim Bearbeiten leer (= unverändert).

    // Snapshot direkt nach dem Befüllen festhalten.
    _initialSnapshot = _captureSnapshot();

    // Dirty-Listener: setState nur wenn sich _isDirty ändert.
    for (final ctrl in _allCtrls) {
      ctrl.addListener(_checkDirtyChanged);
    }
    // Passwort-Feld: beim Anlegen ist jede Eingabe dirty-relevant.
    if (!_isEdit) {
      _passwordCtrl.addListener(_checkDirtyChanged);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _allCtrls) {
      ctrl.removeListener(_checkDirtyChanged);
      ctrl.dispose();
    }
    if (!_isEdit) {
      _passwordCtrl.removeListener(_checkDirtyChanged);
    }
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Dirty-Detection Helpers ───────────────────────────────────────────────

  _MailboxFormSnapshot _captureSnapshot() => _MailboxFormSnapshot(
        label: _labelCtrl.text,
        host: _hostCtrl.text,
        port: _portCtrl.text,
        username: _usernameCtrl.text,
        folder: _folderCtrl.text,
        ssl: _ssl,
        enabled: _enabled,
      );

  bool get _isDirty {
    final s = _initialSnapshot;
    final textDirty = _labelCtrl.text != s.label ||
        _hostCtrl.text != s.host ||
        _portCtrl.text != s.port ||
        _usernameCtrl.text != s.username ||
        _folderCtrl.text != s.folder ||
        _ssl != s.ssl ||
        _enabled != s.enabled;
    // Beim Anlegen: Passwort-Feld miteinbeziehen.
    final passwordDirty = !_isEdit && _passwordCtrl.text.isNotEmpty;
    return textDirty || passwordDirty;
  }

  /// setState nur bei Dirty-Status-Wechsel — nicht bei jedem Tastendruck.
  void _checkDirtyChanged() {
    if (!mounted) return;
    final nowDirty = _isDirty;
    if (nowDirty != _wasDirty) {
      setState(() => _wasDirty = nowDirty);
    }
  }

  // ── Validators ────────────────────────────────────────────────────────────

  static final RegExp _emailRegex =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateEmail(String? value, AppLocalizations l10n) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l10n.commonRequired;
    if (!_emailRegex.hasMatch(v)) return l10n.validationInvalidEmail;
    return null;
  }

  String? _validatePort(String? value, AppLocalizations l10n) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l10n.commonRequired;
    final n = int.tryParse(v);
    if (n == null || n < 1 || n > 65535) return l10n.validationInvalidPort;
    return null;
  }

  String? _validateRequired(String? value, AppLocalizations l10n) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l10n.commonRequired;
    return null;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final label = _labelCtrl.text.trim();
    final host = _hostCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 993;
    final folder =
        _folderCtrl.text.trim().isEmpty ? 'INBOX' : _folderCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      final inbox = context.read<InboxProvider>();
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          label: label,
          imapHost: host,
          imapPort: port,
          useSsl: _ssl,
          username: username,
          folder: folder,
          enabled: _enabled,
        );
        await inbox.updateAccount(
          updated,
          newPassword: password.isEmpty ? null : password,
        );
      } else {
        final draft = MailboxAccount(
          id: '',
          workspaceId: '',
          label: label,
          imapHost: host,
          imapPort: port,
          useSsl: _ssl,
          username: username,
          folder: folder,
          enabled: _enabled,
        );
        await inbox.addAccount(draft, password: password);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(l10n.mailboxDialogSaveFailed('$e')),
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
          constraints: const BoxConstraints(maxWidth: 480),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title bar ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isEdit
                                ? l10n.mailboxDialogEditTitle
                                : l10n.mailboxDialogAddTitle,
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
                  // ── Scrollable Form ───────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Label
                            TextFormField(
                              controller: _labelCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText:
                                    '${l10n.mailboxDialogLabelLabel} *',
                                hintText: l10n.mailboxDialogLabelHint,
                              ),
                              validator: (v) => _validateRequired(v, l10n),
                            ),
                            const SizedBox(height: 12),
                            // Host + Port in einer Zeile
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _hostCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.url,
                                    decoration: InputDecoration(
                                      labelText:
                                          '${l10n.mailboxDialogHostLabel} *',
                                    ),
                                    validator: (v) =>
                                        _validateRequired(v, l10n),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _portCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText:
                                          '${l10n.mailboxDialogPortLabel} *',
                                    ),
                                    validator: (v) =>
                                        _validatePort(v, l10n),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Username / Email
                            TextFormField(
                              controller: _usernameCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText:
                                    '${l10n.mailboxDialogUsernameLabel} *',
                                prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    size: 18),
                              ),
                              validator: (v) => _validateEmail(v, l10n),
                            ),
                            const SizedBox(height: 12),
                            // Password
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: _isEdit
                                    ? l10n.mailboxDialogPasswordEditLabel
                                    : l10n.mailboxDialogPasswordNewLabel,
                                helperText: _isEdit
                                    ? null
                                    : l10n.mailboxDialogPasswordHelper,
                                prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword =
                                          !_obscurePassword),
                                  tooltip: _obscurePassword
                                      ? l10n.actionOpen
                                      : l10n.actionClose,
                                ),
                              ),
                              validator: (v) {
                                // Beim Anlegen ist Passwort Pflicht.
                                if (!_isEdit &&
                                    (v == null || v.isEmpty)) {
                                  return l10n.mailboxDialogPasswordRequiredError;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // IMAP Folder
                            TextFormField(
                              controller: _folderCtrl,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: l10n.mailboxDialogFolderLabel,
                                hintText: 'INBOX',
                                prefixIcon: const Icon(
                                    Icons.folder_outlined,
                                    size: 18),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // SSL/TLS Switch
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.mailboxDialogSslLabel),
                              value: _ssl,
                              onChanged: (v) {
                                setState(() => _ssl = v);
                                _checkDirtyChanged();
                              },
                            ),
                            // Polling Switch
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.mailboxDialogPollingLabel),
                              subtitle:
                                  Text(l10n.mailboxDialogPollingSubtitle),
                              value: _enabled,
                              onChanged: (v) {
                                setState(() => _enabled = v);
                                _checkDirtyChanged();
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Actions ───────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          // maybePop damit UnsavedChangesGuard greifen kann
                          onPressed: _saving
                              ? null
                              : () => Navigator.maybePop(context),
                          child: Text(l10n.actionCancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.bgSurfaceOf(context),
                                  ),
                                )
                              : Text(l10n.actionSave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ), // Dialog
      ),
    ); // UnsavedChangesGuard
  }
}
