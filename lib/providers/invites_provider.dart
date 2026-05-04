import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/workspace.dart';
import '../services/workspace_service.dart';

/// Hält die für den aktuellen User offenen Workspace-Einladungen. Wird vom
/// Bell-Widget im Header beobachtet.
///
/// Lädt einmalig beim Login + bei manuellem `refresh()`. Optional pollend
/// in größerem Abstand, damit neue Invites ohne App-Restart sichtbar werden.
class InvitesProvider extends ChangeNotifier {
  InvitesProvider(this._service);

  final WorkspaceService _service;

  List<WorkspaceInvite> _invites = const [];
  bool _loading = false;
  Object? _lastError;
  Timer? _poll;

  List<WorkspaceInvite> get invites => List.unmodifiable(_invites);
  int get count => _invites.length;
  bool get loading => _loading;
  Object? get lastError => _lastError;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _invites = await _service.listMyPendingInvites();
      _lastError = null;
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('InvitesProvider.refresh failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Startet einen leichten Polling-Timer (jede 5 min), damit Einladungen
  /// auch ohne App-Reload erscheinen. Idempotent.
  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<String?> accept(String inviteId) async {
    try {
      final wsId = await _service.acceptInvite(inviteId);
      _invites = _invites.where((i) => i.id != inviteId).toList();
      notifyListeners();
      return wsId;
    } catch (e) {
      if (kDebugMode) debugPrint('accept invite failed: $e');
      rethrow;
    }
  }

  Future<void> decline(String inviteId) async {
    try {
      await _service.declineInvite(inviteId);
      _invites = _invites.where((i) => i.id != inviteId).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('decline invite failed: $e');
      rethrow;
    }
  }

  void clear() {
    _invites = const [];
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
