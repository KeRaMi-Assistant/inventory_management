import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _busy = false;

  Future<void> _resend() async {
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.resendConfirmation(widget.email);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Bestätigungsmail wurde erneut gesendet.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error != null ? const Color(0xFFC0392B) : null,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_unread_outlined,
                        size: 56, color: Color(0xFF2563EB)),
                    const SizedBox(height: 16),
                    const Text(
                      'Bitte bestätige deine E-Mail',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wir haben einen Bestätigungslink an\n${widget.email}\ngesendet. Klicke auf den Link in der Mail, um dein Konto zu aktivieren.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _resend,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(
                          _busy ? 'Sende…' : 'Bestätigungsmail erneut senden'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Zurück zum Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
