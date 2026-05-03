import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

enum _Provider { google, apple }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.signIn(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _showSnack(error, isError: true);
    }
    // On success: AuthGate listens to authState and swaps to MainScreen.
  }

  Future<void> _socialSignIn(_Provider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final error = provider == _Provider.google
        ? await auth.signInWithGoogle()
        : await auth.signInWithApple();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) _showSnack(error, isError: true);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFC0392B) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Color(0xFF2563EB),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Lagerverwaltung',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mit deinem Konto anmelden',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          prefixIcon:
                              const Icon(Icons.lock_outline, size: 18),
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
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Passwort erforderlich' : null,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  ),
                          child: const Text('Passwort vergessen?'),
                        ),
                      ),
                      const SizedBox(height: 4),
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
                            : const Icon(Icons.login, size: 18),
                        label: Text(_busy ? 'Anmelden…' : 'Anmelden'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(
                              child: Divider(color: Color(0xFFE2E8F0))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'oder weiter mit',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: Color(0xFFE2E8F0))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _GoogleSignInButton(
                        busy: _busy,
                        onPressed: () => _socialSignIn(_Provider.google),
                      ),
                      if (context.read<AuthProvider>().appleSignInAvailable) ...[
                        const SizedBox(height: 8),
                        _AppleSignInButton(
                          busy: _busy,
                          onPressed: () => _socialSignIn(_Provider.apple),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Noch kein Konto?',
                              style: TextStyle(color: Color(0xFF64748B))),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterScreen(),
                                      ),
                                    ),
                            child: const Text('Registrieren'),
                          ),
                        ],
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

class _GoogleSignInButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const _GoogleLogo(),
      label: const Text('Mit Google anmelden',
          style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

class _AppleSignInButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _AppleSignInButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.apple, size: 20),
      label: const Text('Mit Apple anmelden',
          style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
