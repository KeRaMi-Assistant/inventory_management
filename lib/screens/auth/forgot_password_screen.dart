import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.sendPasswordReset(_emailCtrl.text);
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
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passwort vergessen')),
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
                child: _sent ? _buildSuccess() : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() => Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wir senden dir einen Link zum Zurücksetzen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
              ),
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(_busy ? 'Sende…' : 'Reset-Link senden'),
            ),
          ],
        ),
      );

  Widget _buildSuccess() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read_outlined,
              size: 56, color: Color(0xFF059669)),
          const SizedBox(height: 16),
          const Text(
            'E-Mail gesendet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Falls ein Konto mit ${_emailCtrl.text.trim()} existiert, '
            'wurde ein Link zum Zurücksetzen gesendet. Bitte prüfe auch '
            'deinen Spam-Ordner.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zurück zum Login'),
          ),
        ],
      );
}
