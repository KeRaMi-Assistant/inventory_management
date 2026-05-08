import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/active_workspace_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

enum _Provider { google, apple }

enum _LoginMode { personal, team }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _teamIdCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  _LoginMode _mode = _LoginMode.personal;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _teamIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthProvider>();
    final workspaces = context.read<ActiveWorkspaceProvider>();

    String? teamId;
    if (_mode == _LoginMode.team) {
      teamId = _teamIdCtrl.text.trim();
      // Pin the requested workspace before auth so the post-login hydrator
      // jumps straight into the right team context.
      await workspaces.presetActiveId(teamId);
    }

    final error = await auth.signIn(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _busy = false);
      _showSnack(error, isError: true);
      return;
    }

    if (teamId != null) {
      final ok = await auth.isMemberOfWorkspace(teamId);
      if (!mounted) return;
      if (!ok) {
        await auth.signOut();
        if (!mounted) return;
        setState(() => _busy = false);
        _showSnack(l10n.loginTeamNotMember, isError: true);
        return;
      }
    }

    setState(() => _busy = false);
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
            isError ? AppTheme.dangerTextOf(context) : AppTheme.successTextOf(context),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.borderOf(context)),
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
                              color: AppTheme.accentLightOf(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.inventory_2_rounded,
                              color: AppTheme.accentTextOf(context),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.appTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textMutedOf(context)),
                      ),
                      const SizedBox(height: 20),
                      // ── Mode toggle ────────────────────────────────────
                      SegmentedButton<_LoginMode>(
                        segments: [
                          ButtonSegment(
                            value: _LoginMode.personal,
                            label: Text(l10n.loginModePersonal),
                            icon: const Icon(Icons.person_outline, size: 16),
                          ),
                          ButtonSegment(
                            value: _LoginMode.team,
                            label: Text(l10n.loginModeTeam),
                            icon: const Icon(Icons.group_outlined, size: 16),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 16),
                      if (_mode == _LoginMode.team) ...[
                        TextFormField(
                          controller: _teamIdCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.loginTeamIdLabel,
                            helperText: l10n.loginTeamIdHelp,
                            prefixIcon:
                                const Icon(Icons.group_outlined, size: 18),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return l10n.loginTeamIdRequired;
                            // Workspace IDs sind UUIDs (36 Zeichen mit Bindestrichen).
                            final uuidPattern = RegExp(
                                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
                            if (!uuidPattern.hasMatch(t)) {
                              return l10n.loginTeamIdInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: l10n.fieldEmail,
                          prefixIcon:
                              const Icon(Icons.email_outlined, size: 18),
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
                          labelText: l10n.fieldPassword,
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
                            v == null || v.isEmpty ? l10n.passwordRequired : null,
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
                          child: Text(l10n.loginForgotPassword),
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
                        label: Text(_busy ? l10n.loginInProgress : l10n.loginSubmit),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: AppTheme.borderOf(context))),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              l10n.loginContinueWith,
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMutedOf(context)),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: AppTheme.borderOf(context))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _GoogleSignInButton(
                        busy: _busy,
                        label: l10n.loginWithGoogle,
                        onPressed: () => _socialSignIn(_Provider.google),
                      ),
                      if (context.read<AuthProvider>().appleSignInAvailable) ...[
                        const SizedBox(height: 8),
                        _AppleSignInButton(
                          busy: _busy,
                          label: l10n.loginWithApple,
                          onPressed: () => _socialSignIn(_Provider.apple),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.loginNoAccount,
                              style: TextStyle(color: AppTheme.textMutedOf(context))),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterScreen(),
                                      ),
                                    ),
                            child: Text(l10n.loginRegister),
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
  final String label;
  final VoidCallback onPressed;
  const _GoogleSignInButton({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

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
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600)),
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
  final String label;
  final VoidCallback onPressed;
  const _AppleSignInButton({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

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
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
