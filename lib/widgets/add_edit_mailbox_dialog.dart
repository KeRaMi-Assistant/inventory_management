import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/mailbox_account.dart';
import '../providers/inbox_provider.dart';

/// Dialog zum Anlegen/Bearbeiten eines IMAP-Postfachs. Das Passwort wird
/// nur lokal im State gehalten und sofort über `set_mailbox_password`
/// verschlüsselt persistiert.
class AddEditMailboxDialog extends StatefulWidget {
  final MailboxAccount? existing;
  const AddEditMailboxDialog({super.key, this.existing});

  @override
  State<AddEditMailboxDialog> createState() => _AddEditMailboxDialogState();
}

class _AddEditMailboxDialogState extends State<AddEditMailboxDialog> {
  late final TextEditingController _label;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _folder;
  late bool _ssl;
  late bool _enabled;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _host = TextEditingController(text: e?.imapHost ?? 'imap.gmail.com');
    _port = TextEditingController(text: '${e?.imapPort ?? 993}');
    _username = TextEditingController(text: e?.username ?? '');
    _password = TextEditingController();
    _folder = TextEditingController(text: e?.folder ?? 'INBOX');
    _ssl = e?.useSsl ?? true;
    _enabled = e?.enabled ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final label = _label.text.trim();
    final host = _host.text.trim();
    final username = _username.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 993;
    final folder = _folder.text.trim().isEmpty ? 'INBOX' : _folder.text.trim();
    final password = _password.text;

    if (label.isEmpty || host.isEmpty || username.isEmpty) {
      setState(() => _error = 'Label, Server und Benutzer sind Pflichtfelder.');
      return;
    }
    if (!_isEdit && password.isEmpty) {
      setState(() => _error = 'Passwort ist beim Anlegen Pflicht.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
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
        setState(() {
          _saving = false;
          _error = 'Speichern fehlgeschlagen: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit
          ? AppLocalizations.of(context).mailboxDialogEditTitle
          : AppLocalizations.of(context).mailboxDialogAddTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'z. B. "Gmail Reseller"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      decoration: const InputDecoration(
                        labelText: 'IMAP-Server',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Benutzername / Mail-Adresse',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEdit
                      ? AppLocalizations.of(context)
                          .mailboxDialogPasswordEditLabel
                      : 'App-Passwort',
                  helperText: _isEdit
                      ? null
                      : 'Bei Gmail/Outlook: separates App-Passwort generieren.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _folder,
                decoration: const InputDecoration(
                  labelText: 'Ordner',
                  hintText: 'INBOX',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('SSL/TLS verwenden'),
                value: _ssl,
                onChanged: (v) => setState(() => _ssl = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Polling aktiv'),
                subtitle: const Text(
                    'Wird alle 5 Minuten von der Edge Function abgefragt.'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).actionSave),
        ),
      ],
    );
  }
}
