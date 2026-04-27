import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/inventory_provider.dart';
import 'screens/main_screen.dart';
import 'utils/discord_oauth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final fragment = getDiscordOAuthFragment();

  // ── Popup return: Discord redirected back with access_token ──────────────
  if (isInOAuthPopup()) {
    // Save token to localStorage → fires storage event in the opener window
    sendTokenAndClosePopup(fragment);
    // Fallback UI shown if window.close() is blocked by the browser
    runApp(const _ClosingApp());
    return;
  }

  // ── Normal startup ────────────────────────────────────────────────────────
  final provider = InventoryProvider();
  await provider.loadData();

  // Same-tab fallback: if popup was blocked, Discord redirected in the same tab
  if (fragment.isNotEmpty) {
    await provider.handleDiscordOAuthCallback(fragment);
    clearDiscordOAuthFragment();
  }

  // Listen for token saved by the popup
  listenForDiscordOAuthSaved((frag) async {
    await provider.handleDiscordOAuthCallback(frag);
  });

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Management',
      theme: AppTheme.light,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Shown briefly in the popup window while it closes itself.
class _ClosingApp extends StatelessWidget {
  const _ClosingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF5865F2), size: 72),
              SizedBox(height: 20),
              Text(
                'Discord verbunden!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 8),
              Text(
                'Dieses Fenster schließt sich automatisch…',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
