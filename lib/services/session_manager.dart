import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../providers/auth_provider.dart';

/// Verwaltet Session-Lifecycle:
///  - Idle-Timeout: Nutzer wird nach [idleTimeout] ohne Interaktion abgemeldet.
///  - Ablauf-Warnung: Banner wird gezeigt, wenn das Token in ≤ [warnBefore]
///    abläuft (siehe [expiryWarningStream]).
///  - Auto-Refresh: bei App-Resume und kurz vor Ablauf.
///
/// Aufruf: einmalig in [InventoryApp] anstoßen, jede Benutzerinteraktion
/// in einem Listener aktualisiert den Idle-Timer via [bumpActivity].
class SessionManager with WidgetsBindingObserver {
  SessionManager({
    required AuthProvider auth,
    this.idleTimeout = const Duration(minutes: 30),
    this.warnBefore = const Duration(minutes: 5),
  }) : _auth = auth;

  final AuthProvider _auth;
  final Duration idleTimeout;
  final Duration warnBefore;

  Timer? _idleTimer;
  Timer? _expiryTimer;

  final _expiryCtrl = StreamController<bool>.broadcast();

  /// `true` = Session läuft in ≤ [warnBefore] ab, `false` = wieder sicher.
  Stream<bool> get expiryWarningStream => _expiryCtrl.stream;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    bumpActivity();
    _scheduleExpiryCheck();
    _auth.addListener(_onAuthChanged);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _expiryTimer?.cancel();
    _auth.removeListener(_onAuthChanged);
    _expiryCtrl.close();
  }

  /// Setzt den Idle-Timer zurück. Aus jedem onTap/onChange aufrufen.
  void bumpActivity() {
    if (!_auth.isLoggedIn) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _onIdleTimeout);
  }

  Future<void> _onIdleTimeout() async {
    if (!_auth.isLoggedIn) return;
    if (kDebugMode) debugPrint('SessionManager: idle timeout → signOut');
    await _auth.signOut();
  }

  void _onAuthChanged() {
    if (_auth.isLoggedIn) {
      bumpActivity();
      _scheduleExpiryCheck();
    } else {
      _idleTimer?.cancel();
      _expiryTimer?.cancel();
      _expiryCtrl.add(false);
    }
  }

  void _scheduleExpiryCheck() {
    _expiryTimer?.cancel();
    final session = _auth.currentSession;
    if (session == null) return;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return;
    final expiryTime =
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);
    final now = DateTime.now().toUtc();
    final untilWarning = expiryTime.subtract(warnBefore).difference(now);
    if (untilWarning.isNegative) {
      _emitWarning();
    } else {
      _expiryTimer = Timer(untilWarning, _emitWarning);
    }
  }

  Future<void> _emitWarning() async {
    if (!_auth.isLoggedIn) return;
    _expiryCtrl.add(true);
  }

  /// Wird vom Banner-Button "Sitzung verlängern" aufgerufen.
  Future<bool> extendSession() async {
    final ok = await _auth.refreshSession();
    if (ok) {
      _expiryCtrl.add(false);
      _scheduleExpiryCheck();
    }
    return ok;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _auth.isLoggedIn) {
      // Nach Hintergrund: Token könnte abgelaufen sein.
      _auth.refreshSession().then((ok) {
        if (!ok) return;
        bumpActivity();
        _scheduleExpiryCheck();
      });
    }
  }
}
