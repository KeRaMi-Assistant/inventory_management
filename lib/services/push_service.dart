import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Verkapselt FCM-Bootstrap, Token-Registrierung gegen `fcm_tokens` und das
/// Foreground-Display von Push-Benachrichtigungen.
///
/// Tolerant gegenüber fehlendem Firebase-Setup: wenn die Konfig-Dateien
/// (google-services.json / GoogleService-Info.plist) noch nicht abgelegt
/// sind, läuft die App normal weiter und Push ist einfach inaktiv.
class PushService {
  PushService(this._client);

  final SupabaseClient _client;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _firebaseAvailable = false;
  String? _registeredToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  static const _androidChannel = AndroidNotificationChannel(
    'inventoryos_default',
    'InventoryOS Benachrichtigungen',
    description: 'MHD-Warnungen, Lieferungen und Zahlungserinnerungen',
    importance: Importance.high,
  );

  bool get isAvailable => _firebaseAvailable;

  /// Wird in [main] nach Supabase.initialize aufgerufen. Initialisiert Firebase
  /// best-effort. Wirft nicht — wenn Config fehlt, bleibt Push inaktiv.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) {
      // Web bräuchte VAPID-Key + service-worker-Setup — out of scope.
      return;
    }
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase init skipped: $e');
      }
      return;
    }

    await _setupLocalNotifications();
    await _requestPermission();
    _foregroundSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen(_persistToken);
  }

  Future<void> _setupLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _requestPermission() async {
    if (!_firebaseAvailable) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FCM permission request failed: $e');
    }
  }

  /// Wird vom AuthGate nach erfolgreichem Login getriggert. Holt einen FCM
  /// Token und legt ihn in `fcm_tokens` ab (upsert auf token).
  Future<void> registerCurrentDevice() async {
    if (!_firebaseAvailable) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _persistToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token fetch failed: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _registeredToken = token;
    final platform = _platformLabel();
    try {
      await _client.from('fcm_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('fcm_tokens upsert failed: $e');
    }
  }

  /// Wird beim Logout aufgerufen, damit ein zweiter Account auf demselben
  /// Gerät keinen Cross-Push bekommt.
  Future<void> unregisterCurrentDevice() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await _client.from('fcm_tokens').delete().eq('token', token);
    } catch (_) {
      // best-effort
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      if (Platform.isMacOS) return 'macos';
    } catch (_) {}
    return 'unknown';
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
  }
}

// ─── Notification preferences (kleine, unabhängige Hilfsklasse) ──────────────

class NotificationPreferences {
  final bool mhdWarningEnabled;
  final int mhdWarningDays;
  final bool deliveryEnabled;
  final bool paymentEnabled;
  final int paymentOverdueDays;

  const NotificationPreferences({
    this.mhdWarningEnabled = true,
    this.mhdWarningDays = 14,
    this.deliveryEnabled = true,
    this.paymentEnabled = true,
    this.paymentOverdueDays = 7,
  });

  Map<String, dynamic> toUpsert(String userId) => {
        'user_id': userId,
        'mhd_warning_enabled': mhdWarningEnabled,
        'mhd_warning_days': mhdWarningDays,
        'delivery_enabled': deliveryEnabled,
        'payment_enabled': paymentEnabled,
        'payment_overdue_days': paymentOverdueDays,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory NotificationPreferences.fromRow(Map<String, dynamic> row) =>
      NotificationPreferences(
        mhdWarningEnabled: row['mhd_warning_enabled'] as bool? ?? true,
        mhdWarningDays: (row['mhd_warning_days'] as num?)?.toInt() ?? 14,
        deliveryEnabled: row['delivery_enabled'] as bool? ?? true,
        paymentEnabled: row['payment_enabled'] as bool? ?? true,
        paymentOverdueDays:
            (row['payment_overdue_days'] as num?)?.toInt() ?? 7,
      );

  NotificationPreferences copyWith({
    bool? mhdWarningEnabled,
    int? mhdWarningDays,
    bool? deliveryEnabled,
    bool? paymentEnabled,
    int? paymentOverdueDays,
  }) =>
      NotificationPreferences(
        mhdWarningEnabled: mhdWarningEnabled ?? this.mhdWarningEnabled,
        mhdWarningDays: mhdWarningDays ?? this.mhdWarningDays,
        deliveryEnabled: deliveryEnabled ?? this.deliveryEnabled,
        paymentEnabled: paymentEnabled ?? this.paymentEnabled,
        paymentOverdueDays: paymentOverdueDays ?? this.paymentOverdueDays,
      );
}

class NotificationPreferencesService {
  NotificationPreferencesService(this._client);
  final SupabaseClient _client;

  Future<NotificationPreferences> load() async {
    final user = _client.auth.currentUser;
    if (user == null) return const NotificationPreferences();
    try {
      final row = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) return const NotificationPreferences();
      return NotificationPreferences.fromRow(row);
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> save(NotificationPreferences prefs) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('notification_preferences')
        .upsert(prefs.toUpsert(user.id), onConflict: 'user_id');
  }
}
