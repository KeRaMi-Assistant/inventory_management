import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace.dart';
import '../services/workspace_service.dart';

/// Hält die aktuell aktive Workspace-ID + Rolle des angemeldeten Users.
/// - lädt nach Login alle Workspaces, die der User sehen darf
/// - persistiert die zuletzt gewählte Workspace-ID lokal
/// - validiert beim Wechseln, dass der User Mitglied ist
class ActiveWorkspaceProvider extends ChangeNotifier {
  ActiveWorkspaceProvider(this._service);

  final WorkspaceService _service;

  static const _kActiveWorkspace = 'active_workspace_id';

  List<Workspace> _workspaces = [];
  Workspace? _active;
  WorkspaceRole? _role;
  bool _loading = false;

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  Workspace? get active => _active;
  WorkspaceRole? get role => _role;
  bool get loading => _loading;

  /// Setzt eine spezifische Workspace-ID *bevor* die Workspaces geladen sind —
  /// genutzt vom Team-Login-Flow, damit nach erfolgreichem Login direkt der
  /// gewählte Team-Workspace aktiv ist.
  Future<void> presetActiveId(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveWorkspace, workspaceId);
  }

  Future<void> loadForCurrentUser(String currentUserId) async {
    _loading = true;
    notifyListeners();
    try {
      _workspaces = await _service.listMine();
      final prefs = await SharedPreferences.getInstance();
      final pinned = prefs.getString(_kActiveWorkspace);
      Workspace? candidate;
      if (pinned != null) {
        candidate = _workspaces.where((w) => w.id == pinned).firstOrNull;
      }
      candidate ??= _workspaces.firstOrNull;
      _active = candidate;

      if (candidate != null) {
        try {
          final members = await _service.listMembers(candidate.id);
          _role = members
              .where((m) => m.userId == currentUserId)
              .map((m) => m.role)
              .firstOrNull;
        } catch (_) {
          _role = null;
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setActive(Workspace ws, String currentUserId) async {
    _active = ws;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveWorkspace, ws.id);
    try {
      final members = await _service.listMembers(ws.id);
      _role = members
          .where((m) => m.userId == currentUserId)
          .map((m) => m.role)
          .firstOrNull;
    } catch (_) {
      _role = null;
    }
    notifyListeners();
  }

  /// Erstellt einen neuen Workspace via [WorkspaceService.createWorkspace],
  /// hängt ihn an die in-memory-Liste an und switched aktiv hin.
  ///
  /// Bewusst KEIN `loadForCurrentUser`-Roundtrip — der RPC liefert die Row
  /// bereits zurück, wir können sie direkt anhängen. Spart einen Round-Trip
  /// und vermeidet eine Race zwischen Insert und Snapshot-Reload.
  ///
  /// Wirft [WorkspaceLimitException] / [ArgumentError] aus dem Service durch.
  Future<Workspace> createAndSwitchTo({
    required String name,
    required String currentUserId,
  }) async {
    final ws = await _service.createWorkspace(name);
    _workspaces = [..._workspaces, ws];
    // setActive persistiert in SharedPrefs + ruft notifyListeners.
    await setActive(ws, currentUserId);
    return ws;
  }

  void clear() {
    _workspaces = [];
    _active = null;
    _role = null;
    notifyListeners();
  }

  /// Ersetzt einen Workspace in der Liste (z.B. nach `updatePublicProfile`).
  /// Wenn er gerade aktiv ist, wird auch `_active` aktualisiert.
  void applyUpdate(Workspace updated) {
    final idx = _workspaces.indexWhere((w) => w.id == updated.id);
    if (idx >= 0) {
      _workspaces[idx] = updated;
    } else {
      _workspaces = [..._workspaces, updated];
    }
    if (_active?.id == updated.id) {
      _active = updated;
    }
    notifyListeners();
  }
}
