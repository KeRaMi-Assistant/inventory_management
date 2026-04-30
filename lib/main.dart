import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/main_screen.dart';
import 'services/supabase_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    return MultiProvider(
      providers: [
        Provider<SupabaseRepository>(
          create: (_) => SupabaseRepository(supabase),
        ),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<FilterProvider>(create: (_) => FilterProvider()),
        ChangeNotifierProxyProvider<SupabaseRepository, InventoryProvider>(
          create: (ctx) => InventoryProvider(
            repository: ctx.read<SupabaseRepository>(),
          ),
          update: (_, repository, previous) =>
              previous ?? InventoryProvider(repository: repository),
        ),
      ],
      child: MaterialApp(
        title: 'Lagerverwaltung',
        theme: AppTheme.light,
        home: const _AuthGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Top-level redirect: shows the splash → login → main flow based on the
/// current Supabase session. We track the user id so a sign-out (or a switch
/// between accounts) reliably triggers a reload of [InventoryProvider].
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _hydratedFor;
  bool _hydrating = false;
  bool _migrationOffered = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      // Drop any stale data from a previous session before showing login.
      if (_hydratedFor != null) {
        _hydratedFor = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<InventoryProvider>().clearLocalState();
        });
      }
      return const LoginScreen();
    }

    if (_hydratedFor != user.id) {
      if (!_hydrating) {
        _hydrating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate(user.id));
      }
      return const SplashScreen(message: 'Synchronisiere mit Cloud…');
    }

    return const MainScreen();
  }

  Future<void> _hydrate(String userId) async {
    final inventory = context.read<InventoryProvider>();
    await inventory.loadData();
    if (!mounted) return;
    setState(() {
      _hydratedFor = userId;
      _hydrating = false;
    });
    // Offer legacy migration once per session if the cloud account is empty
    // but local shared_preferences still hold deals from the pre-cloud build.
    if (!_migrationOffered &&
        inventory.deals.isEmpty &&
        inventory.buyers.isEmpty &&
        inventory.shops.isEmpty &&
        inventory.inventoryItems.isEmpty) {
      _migrationOffered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferMigration());
    }
  }

  Future<void> _maybeOfferMigration() async {
    if (!mounted) return;
    final inventory = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final accept = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lokale Daten gefunden'),
        content: const Text(
          'Es scheinen Daten aus der lokalen Version zu existieren. '
          'Möchtest du sie jetzt in dein Cloud-Konto importieren? '
          'Die lokale Kopie wird danach gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text('Später'),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
    if (accept != true || !mounted) return;
    try {
      final imported = await inventory.migrateLegacyLocalData();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(imported == null
              ? 'Keine lokalen Daten zum Importieren.'
              : '$imported Deals importiert.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Import fehlgeschlagen: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }
}
