import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/password_strength_indicator.dart';

/// Wird angezeigt, wenn Supabase einen `passwordRecovery`-Auth-Event sendet
/// (Klick auf den Reset-Link in der E-Mail). Setzt das neue Passwort über
/// `AuthProvider.updatePassword`.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.updatePassword(_passwordCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFC0392B),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passwort erfolgreich geändert.'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Passwort')),
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Lege ein neues Passwort fest.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Neues Passwort',
                          prefixIcon:
                              const Icon(Icons.lock_outline, size: 18),
                          helperText:
                              '8+ Zeichen, Groß/Klein, Zahl, Sonderzeichen',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: Validators.validatePassword,
                      ),
                      PasswordStrengthIndicator(password: _passwordCtrl.text),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Passwort bestätigen',
                          prefixIcon: Icon(Icons.lock_outline, size: 18),
                        ),
                        validator: (v) {
                          if (v != _passwordCtrl.text) {
                            return 'Passwörter stimmen nicht überein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                            _busy ? 'Speichere…' : 'Passwort speichern'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
