import 'dart:async';

import 'package:accessibility_tools/accessibility_tools.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'config/supabase_config.dart';
import 'l10n/app_localizations.dart';
import 'providers/active_workspace_provider.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/auth_provider.dart';
import 'models/pricing_plan.dart';
import 'providers/billing_provider.dart';
import 'providers/carrier_credentials_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/purchasing_provider.dart';
import 'providers/inbox_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/invites_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/statistics_filter_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/public_profile_screen.dart';
import 'services/attachment_service.dart';
import 'services/billing_service.dart';
import 'services/demo_data_service.dart';
import 'services/push_service.dart';
import 'services/session_manager.dart';
import 'services/supabase_repository.dart';
import 'services/workspace_service.dart';

/// Compile-Time-Flag: aktiviert Flutter-Semantics für Playwright-Tests.
/// Aktivierung: `flutter build web --dart-define=ENABLE_SEMANTICS=true`
/// Nur im Test-Build setzen — Semantics-Overlay hat messbaren Render-Overhead.
const bool kEnableSemanticsForTests = bool.fromEnvironment(
  'ENABLE_SEMANTICS',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Test-Build: Semantics aktivieren, damit <flt-semantics>-Elemente im
  // Web-DOM erscheinen und Playwright getByLabel() / getByRole() greifen kann.
  if (kEnableSemanticsForTests && kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }

  await initializeDateFormatting('de_DE');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Web-only: `/u/<handle>` öffnet das öffentliche Verkaufsprofil.
  // Funktioniert sowohl mit Hash- als auch Path-URL-Strategie.
  final publicHandle = kIsWeb ? publicProfileHandleFromUri(Uri.base) : null;

  final prefs = AppPreferencesProvider();
  await prefs.load();

  final pushService = PushService(Supabase.instance.client);
  // Best-effort: läuft auch ohne Firebase-Config still durch.
  await pushService.init();

  runApp(InventoryApp(
    preferences: prefs,
    pushService: pushService,
    publicProfileHandle: publicHandle,
  ));
}

/// Extrahiert einen Workspace-Handle aus `/u/<handle>` (Path-Strategie)
/// oder `/#/u/<handle>` (Hash-Strategie). Liefert null, wenn nichts passt.
@visibleForTesting
String? publicProfileHandleFromUri(Uri base) {
  final pattern = RegExp(r'^/?u/([a-z0-9][a-z0-9-]{1,30}[a-z0-9])/?$');
  // Path-Strategie: base.path enthält /u/<handle>
  final pathMatch = pattern.firstMatch(base.path);
  if (pathMatch != null) return pathMatch.group(1);
  // Hash-Strategie: base.fragment enthält /u/<handle>
  final frag = base.fragment;
  if (frag.isNotEmpty) {
    final fragMatch = pattern.firstMatch(frag);
    if (fragMatch != null) return fragMatch.group(1);
  }
  return null;
}

final GlobalKey<NavigatorState> _rootNavigator =
    GlobalKey<NavigatorState>();

class InventoryApp extends StatelessWidget {
  final AppPreferencesProvider preferences;
  final PushService pushService;
  final String? publicProfileHandle;
  const InventoryApp({
    super.key,
    required this.preferences,
    required this.pushService,
    this.publicProfileHandle,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    return MultiProvider(
      providers: [
        Provider<SupabaseRepository>(
          create: (_) => SupabaseRepository(supabase),
        ),
        Provider<AttachmentService>(
          create: (_) => AttachmentService(supabase),
        ),
        Provider<WorkspaceService>(
          create: (_) => WorkspaceService(supabase),
        ),
        Provider<BillingService>(
          create: (_) => BillingService(supabase),
        ),
        Provider<DemoDataService>(
          create: (_) => DemoDataService(supabase),
        ),
        Provider<PushService>.value(value: pushService),
        Provider<NotificationPreferencesService>(
          create: (_) => NotificationPreferencesService(supabase),
        ),
        ChangeNotifierProvider<AppPreferencesProvider>.value(value: preferences),
        ChangeNotifierProxyProvider<AppPreferencesProvider, AuthProvider>(
          create: (ctx) => AuthProvider(
            onBeforeSignOut: ctx.read<AppPreferencesProvider>().clearRecentSearches,
          ),
          update: (_, prefs, previous) =>
              previous ?? AuthProvider(onBeforeSignOut: prefs.clearRecentSearches),
        ),
        ChangeNotifierProvider<FilterProvider>(create: (_) => FilterProvider()),
        ChangeNotifierProvider<StatisticsFilterProvider>(
          create: (_) => StatisticsFilterProvider(),
        ),
        Provider<SessionManager>(
          lazy: false,
          create: (ctx) =>
              SessionManager(auth: ctx.read<AuthProvider>())..start(),
          dispose: (_, sm) => sm.dispose(),
        ),
        ChangeNotifierProxyProvider<SupabaseRepository, CatalogProvider>(
          create: (ctx) => CatalogProvider(
            repository: ctx.read<SupabaseRepository>(),
          ),
          update: (_, repository, previous) =>
              previous ?? CatalogProvider(repository: repository),
        ),
        // PurchasingProvider MUST be registered BEFORE InventoryProvider — the
        // latter depends on it via the ChangeNotifierProxyProvider3 below
        // (registration order = dependency order; Gotcha #5/#9).
        ChangeNotifierProxyProvider<SupabaseRepository, PurchasingProvider>(
          create: (ctx) => PurchasingProvider(
            repository: ctx.read<SupabaseRepository>(),
          ),
          update: (_, repository, previous) =>
              previous ?? PurchasingProvider(repository: repository),
        ),
        ChangeNotifierProxyProvider3<SupabaseRepository, CatalogProvider,
            PurchasingProvider, InventoryProvider>(
          create: (ctx) => InventoryProvider(
            repository: ctx.read<SupabaseRepository>(),
            catalogProvider: ctx.read<CatalogProvider>(),
            purchasingProvider: ctx.read<PurchasingProvider>(),
          ),
          update: (_, repository, catalog, purchasing, previous) {
            if (previous != null) {
              // Both upstream refs MUST be re-injected on every rebuild
              // (Gotcha #4) — otherwise importCsvAll/bookGoodsReceipt would
              // write against a stale/null reference and silently no-op.
              previous.updateCatalogProvider(catalog);
              previous.updatePurchasingProvider(purchasing);
              return previous;
            }
            return InventoryProvider(
              repository: repository,
              catalogProvider: catalog,
              purchasingProvider: purchasing,
            );
          },
        ),
        ChangeNotifierProxyProvider<SupabaseRepository, InboxProvider>(
          create: (ctx) => InboxProvider(
            repository: ctx.read<SupabaseRepository>(),
          ),
          update: (_, repository, previous) =>
              previous ?? InboxProvider(repository: repository),
        ),
        ChangeNotifierProxyProvider<SupabaseRepository,
            CarrierCredentialsProvider>(
          create: (ctx) => CarrierCredentialsProvider(
            repository: ctx.read<SupabaseRepository>(),
          ),
          update: (_, repository, previous) =>
              previous ?? CarrierCredentialsProvider(repository: repository),
        ),
        ChangeNotifierProxyProvider<WorkspaceService, ActiveWorkspaceProvider>(
          create: (ctx) =>
              ActiveWorkspaceProvider(ctx.read<WorkspaceService>()),
          update: (_, service, previous) =>
              previous ?? ActiveWorkspaceProvider(service),
        ),
        ChangeNotifierProxyProvider<WorkspaceService, InvitesProvider>(
          create: (ctx) => InvitesProvider(ctx.read<WorkspaceService>()),
          update: (_, service, previous) =>
              previous ?? InvitesProvider(service),
        ),
        ChangeNotifierProxyProvider<BillingService, BillingProvider>(
          create: (ctx) => BillingProvider(ctx.read<BillingService>()),
          update: (_, service, previous) =>
              previous ?? BillingProvider(service),
        ),
        ChangeNotifierProvider<OnboardingProvider>(
          create: (ctx) => OnboardingProvider(
            workspaceService: ctx.read<WorkspaceService>(),
            demoDataService: ctx.read<DemoDataService>(),
          ),
        ),
      ],
      child: Consumer<AppPreferencesProvider>(
        builder: (ctx, prefs, _) => MaterialApp(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
          theme: AppTheme.lightFor(prefs.colorPalette),
          darkTheme: AppTheme.darkFor(prefs.colorPalette),
          themeMode: prefs.themeMode,
          navigatorKey: _rootNavigator,
          locale: prefs.locale,
          supportedLocales: AppPreferencesProvider.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Debug-only: A11y-Checker — zero overhead in production.
          builder: kDebugMode
              ? (context, child) => AccessibilityTools(
                    checkSemanticLabels: true,
                    child: child,
                  )
              : null,
          home: publicProfileHandle != null
              ? PublicProfileScreen(handle: publicProfileHandle!)
              : const _ActivityListener(
                  child: _RecoveryListener(child: _AuthGate()),
                ),
          debugShowCheckedModeBanner: false,
        ),
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
  ActiveWorkspaceProvider? _wsListening;
  String? _lastWsId;
  BillingProvider? _billingListening;

  @override
  void dispose() {
    _wsListening?.removeListener(_onWorkspaceChanged);
    _billingListening?.removeListener(_onBillingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      // Drop any stale data from a previous session before showing login.
      if (_hydratedFor != null) {
        _hydratedFor = null;
        _detachWorkspaceListener();
        _detachBillingListener();
        final push = context.read<PushService>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<CatalogProvider>().clearLocalState();
          context.read<PurchasingProvider>().clearLocalState();
          context.read<InventoryProvider>().clearLocalState();
          context.read<InboxProvider>().clear();
          context.read<CarrierCredentialsProvider>().clear();
          context.read<ActiveWorkspaceProvider>().clear();
          context.read<BillingProvider>().clear();
          context.read<InvitesProvider>()
            ..stopPolling()
            ..clear();
          push.unregisterCurrentDevice();
        });
      }
      return const LoginScreen();
    }

    if (_hydratedFor != user.id) {
      if (!_hydrating) {
        _hydrating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate(user.id));
      }
      return const SplashScreen();
    }

    // First-Time-User-Routing: solange der Owner-Workspace `onboarded_at`
    // NULL hat und der eingeloggte User auch dessen Owner ist, zeigt die App
    // den Onboarding-Flow. Sobald `markOnboarded()` durchläuft, schaltet
    // ActiveWorkspaceProvider den Wert um → AuthGate rebuildet → MainScreen.
    final ws = context.watch<ActiveWorkspaceProvider>().active;
    final isOwner = ws != null && ws.ownerId == user.id;
    if (isOwner && ws.onboardedAt == null) {
      return const OnboardingScreen();
    }

    return const MainScreen();
  }

  Future<void> _hydrate(String userId) async {
    final inventory = context.read<InventoryProvider>();
    final catalog = context.read<CatalogProvider>();
    final purchasing = context.read<PurchasingProvider>();
    final push = context.read<PushService>();
    final workspaces = context.read<ActiveWorkspaceProvider>();
    final invites = context.read<InvitesProvider>();
    final billing = context.read<BillingProvider>();
    final inbox = context.read<InboxProvider>();

    // Workspaces zuerst laden, damit Inventory den aktiven Scope kennt.
    await workspaces.loadForCurrentUser(userId);
    final activeId = workspaces.active?.id;
    _lastWsId = activeId;
    // CatalogProvider, PurchasingProvider and InventoryProvider all need the
    // active workspace. Catalog + Purchasing load alongside Inventory so the
    // latter's cross-domain reads/writes see up-to-date products/suppliers/POs.
    await Future.wait([
      catalog.setActiveWorkspace(activeId),
      purchasing.setActiveWorkspace(activeId),
      inventory.setActiveWorkspace(activeId),
      invites.refresh(),
      billing.load(),
    ]);
    // Plan-Quotas auf Inbox anwenden, bevor das UI rendert.
    _applyBillingToInbox(billing, inbox);
    _attachWorkspaceListener(workspaces);
    _attachBillingListener(billing);
    invites.startPolling();
    // Fire-and-forget: Push-Registrierung darf den Login nicht blockieren.
    unawaited(push.registerCurrentDevice());
    if (!mounted) return;
    setState(() {
      _hydratedFor = userId;
      _hydrating = false;
    });
  }

  void _attachWorkspaceListener(ActiveWorkspaceProvider ws) {
    if (identical(_wsListening, ws)) return;
    _detachWorkspaceListener();
    ws.addListener(_onWorkspaceChanged);
    _wsListening = ws;
  }

  void _detachWorkspaceListener() {
    _wsListening?.removeListener(_onWorkspaceChanged);
    _wsListening = null;
  }

  void _onWorkspaceChanged() {
    final ws = _wsListening;
    if (ws == null || !mounted) return;
    final newId = ws.active?.id;
    if (newId == _lastWsId) return;
    _lastWsId = newId;
    // Reload Catalog + Purchasing + Inventory gegen neuen Workspace.
    context.read<CatalogProvider>().setActiveWorkspace(newId);
    context.read<PurchasingProvider>().setActiveWorkspace(newId);
    context.read<InventoryProvider>().setActiveWorkspace(newId);
    // Carrier-Keys sind workspace-scoped — neu laden statt Stale-Cache zeigen.
    context.read<CarrierCredentialsProvider>().refresh();
  }

  void _attachBillingListener(BillingProvider billing) {
    if (identical(_billingListening, billing)) return;
    _detachBillingListener();
    billing.addListener(_onBillingChanged);
    _billingListening = billing;
  }

  void _detachBillingListener() {
    _billingListening?.removeListener(_onBillingChanged);
    _billingListening = null;
  }

  void _onBillingChanged() {
    final billing = _billingListening;
    if (billing == null || !mounted) return;
    _applyBillingToInbox(billing, context.read<InboxProvider>());
  }

  /// Plan-Quotas auf den InboxProvider übertragen. Free hat 0 Postfächer
  /// und 0 Sichtbarkeitstage → Inbox-Tab und Postfach-Settings werden
  /// dadurch im UI ausgeblendet.
  void _applyBillingToInbox(BillingProvider billing, InboxProvider inbox) {
    final pricing = PricingPlan.forBillingPlan(billing.currentPlan);
    inbox.applyPlanQuota(
      mailboxLimit: pricing.mailboxLimit,
      visibilityDays: pricing.inboxVisibilityDays,
    );
  }
}

/// Hört auf `passwordRecovery`-Events des AuthProviders und pusht den
/// ResetPasswordScreen über den Root-Navigator. Liegt um den AuthGate herum,
/// damit auch unangemeldete Recovery-Sessions (Magic-Link) korrekt routen.
class _RecoveryListener extends StatefulWidget {
  final Widget child;
  const _RecoveryListener({required this.child});

  @override
  State<_RecoveryListener> createState() => _RecoveryListenerState();
}

class _RecoveryListenerState extends State<_RecoveryListener> {
  StreamSubscription<bool>? _sub;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _sub = auth.passwordRecoveryStream.listen((_) async {
      if (_isOpen) return;
      final navigator = _rootNavigator.currentState;
      if (navigator == null) return;
      _isOpen = true;
      await navigator.push(MaterialPageRoute(
        builder: (_) => const ResetPasswordScreen(),
      ));
      _isOpen = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wrapper, der jede Pointer-/Tastatur-Eingabe an den [SessionManager]
/// meldet, damit der Idle-Timer zurückgesetzt wird. Zeigt zusätzlich ein
/// dezentes Banner, wenn die Session in ≤ 5 Minuten abläuft.
class _ActivityListener extends StatefulWidget {
  final Widget child;
  const _ActivityListener({required this.child});

  @override
  State<_ActivityListener> createState() => _ActivityListenerState();
}

class _ActivityListenerState extends State<_ActivityListener> {
  bool _showExpiryBanner = false;
  StreamSubscription<bool>? _expirySub;

  @override
  void initState() {
    super.initState();
    final sm = context.read<SessionManager>();
    _expirySub = sm.expiryWarningStream.listen((show) {
      if (!mounted) return;
      setState(() => _showExpiryBanner = show);
    });
  }

  @override
  void dispose() {
    _expirySub?.cancel();
    super.dispose();
  }

  void _bump([_]) => context.read<SessionManager>().bumpActivity();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _bump,
      onPointerSignal: _bump,
      child: Stack(
        children: [
          widget.child,
          if (_showExpiryBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Material(
                  color: AppTheme.warningBgOf(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 18,
                            color: AppTheme.warningTextOf(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).sessionExpiringSoon,
                            style: TextStyle(
                                color: AppTheme.warningTextOf(context),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Builder(
                          builder: (btnCtx) => TextButton(
                            onPressed: () async {
                              final sm = btnCtx.read<SessionManager>();
                              final messenger =
                                  ScaffoldMessenger.of(btnCtx);
                              final l10n = AppLocalizations.of(btnCtx);
                              final ok = await sm.extendSession();
                              if (!ok) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(l10n.sessionExtendFailed),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Text(AppLocalizations.of(btnCtx)
                                .sessionExtend),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
