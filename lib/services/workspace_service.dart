import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_profile.dart';
import '../models/workspace.dart';

/// Dünner Wrapper um die `workspaces`/`workspace_members`/`workspace_invites`-
/// Tabellen. Trennt den Team-Modell-Pfad bewusst vom monolithischen
/// `SupabaseRepository` — das hier wird unabhängig vom Single-User-Daten-
/// Pfad eingeführt und kann später in eigene Provider/Screens wachsen.
class WorkspaceService {
  WorkspaceService(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('WorkspaceService requires an authenticated user.');
    }
    return id;
  }

  Future<List<Workspace>> listMine() async {
    final rows = await _client
        .from('workspaces')
        .select()
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Workspace.fromSupabase)
        .toList();
  }

  Future<List<WorkspaceMember>> listMembers(String workspaceId) async {
    final rows = await _client
        .from('workspace_members')
        .select()
        .eq('workspace_id', workspaceId)
        .order('joined_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WorkspaceMember.fromSupabase)
        .toList();
  }

  Future<List<WorkspaceInvite>> listInvites(String workspaceId) async {
    final rows = await _client
        .from('workspace_invites')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('accepted_at', 'is', null)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WorkspaceInvite.fromSupabase)
        .toList();
  }

  Future<WorkspaceInvite> createInvite({
    required String workspaceId,
    required String email,
    required WorkspaceRole role,
  }) async {
    if (role == WorkspaceRole.owner) {
      throw ArgumentError('Owner-Rolle kann nicht eingeladen werden.');
    }
    final row = await _client
        .from('workspace_invites')
        .insert({
          'workspace_id': workspaceId,
          'email': email.trim().toLowerCase(),
          'role': role.apiName,
          'invited_by': _userId,
        })
        .select()
        .single();
    return WorkspaceInvite.fromSupabase(row);
  }

  Future<void> revokeInvite(String inviteId) async {
    await _client.from('workspace_invites').delete().eq('id', inviteId);
  }

  /// Setzt einen Alias-Namen auf einem Workspace. RLS erlaubt das nur dem
  /// Owner — Admins/Member werfen mit `permission denied`. Leerstring oder
  /// "Personal" wird wie ein Reset behandelt (Display fällt dann wieder
  /// auf die Kurz-ID zurück, siehe [Workspace.displayLabel]).
  Future<Workspace> renameWorkspace({
    required String workspaceId,
    required String name,
  }) async {
    final clean = name.trim();
    final row = await _client
        .from('workspaces')
        .update({'name': clean.isEmpty ? 'Personal' : clean})
        .eq('id', workspaceId)
        .select()
        .single();
    return Workspace.fromSupabase(row);
  }

  Future<void> setMemberRole({
    required String workspaceId,
    required String userId,
    required WorkspaceRole role,
  }) async {
    await _client
        .from('workspace_members')
        .update({'role': role.apiName})
        .eq('workspace_id', workspaceId)
        .eq('user_id', userId);
  }

  Future<void> removeMember({
    required String workspaceId,
    required String userId,
  }) async {
    await _client
        .from('workspace_members')
        .delete()
        .eq('workspace_id', workspaceId)
        .eq('user_id', userId);
  }

  // ── Invitee-Pfad: Einladungen für mich (per Email) ────────────────────

  /// Liefert offene Einladungen, die an die Email des aktuell eingeloggten
  /// Users gehen. Geht über die RLS-Policy `invites_self_email_read`.
  Future<List<WorkspaceInvite>> listMyPendingInvites() async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) return const [];
    final rows = await _client
        .from('workspace_invites')
        .select()
        .eq('email', email.toLowerCase())
        .filter('accepted_at', 'is', null)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WorkspaceInvite.fromSupabase)
        .toList();
  }

  /// Nimmt die Einladung an. Liefert die `workspace_id` zurück, in die der
  /// User aufgenommen wurde. Wirft bei Token/Email-Mismatch oder Ablauf.
  Future<String> acceptInvite(String inviteId) async {
    final res = await _client.rpc(
      'accept_workspace_invite',
      params: {'_invite_id': inviteId},
    );
    return res.toString();
  }

  /// Lehnt die Einladung ab (löscht sie). Idempotent.
  Future<void> declineInvite(String inviteId) async {
    await _client.rpc(
      'decline_workspace_invite',
      params: {'_invite_id': inviteId},
    );
  }

  // ── Public Profile ────────────────────────────────────────────────────

  /// Setzt Handle + öffentliche Sichtbarkeit. RLS lässt nur Owner schreiben.
  /// Wirft, falls der Handle bereits vergeben ist.
  Future<Workspace> updatePublicProfile({
    required String workspaceId,
    String? handle,
    bool? publicProfileEnabled,
  }) async {
    final patch = <String, dynamic>{};
    if (handle != null) {
      final clean = handle.trim().toLowerCase();
      patch['handle'] = clean.isEmpty ? null : clean;
    }
    if (publicProfileEnabled != null) {
      patch['public_profile_enabled'] = publicProfileEnabled;
    }
    if (patch.isEmpty) {
      throw ArgumentError('updatePublicProfile: nichts zu aktualisieren.');
    }
    final row = await _client
        .from('workspaces')
        .update(patch)
        .eq('id', workspaceId)
        .select()
        .single();
    return Workspace.fromSupabase(row);
  }

  /// Liefert das öffentliche Profil zu einem Handle. NULL, wenn der Handle
  /// nicht existiert oder das Profil nicht öffentlich ist. Anonym aufrufbar
  /// (nutzt SECURITY-DEFINER-RPC `get_public_profile`).
  Future<PublicProfile?> fetchPublicProfile(String handle) async {
    final res = await _client.rpc(
      'get_public_profile',
      params: {'handle_in': handle},
    );
    if (res == null) return null;
    if (res is! Map) return null;
    return PublicProfile.fromRpc(res.cast<String, dynamic>());
  }
}
