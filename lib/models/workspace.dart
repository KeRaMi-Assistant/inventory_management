/// Team-Workspace. Aktuell wird pro User automatisch ein "Personal"-Workspace
/// angelegt. Mit dem Team-Tier können Owner zusätzliche Mitglieder einladen.
class Workspace {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final String? handle;
  final bool publicProfileEnabled;
  final DateTime? onboardedAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.handle,
    this.publicProfileEnabled = false,
    this.onboardedAt,
  });

  factory Workspace.fromSupabase(Map<String, dynamic> row) => Workspace(
        id: row['id'] as String,
        name: row['name'] as String,
        ownerId: row['owner_id'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        handle: row['handle'] as String?,
        publicProfileEnabled:
            (row['public_profile_enabled'] as bool?) ?? false,
        onboardedAt: row['onboarded_at'] != null
            ? DateTime.parse(row['onboarded_at'] as String)
            : null,
      );

  /// Label, das im UI angezeigt werden soll. Wenn der aktuelle User Owner
  /// ist, zeigt die App den Roh-`name` (also z.B. "Personal" für den eigenen
  /// Personal-Workspace, oder den Alias für eigene Team-Workspaces).
  /// Beigetretene Workspaces zeigen den Alias, sofern er gesetzt wurde —
  /// sonst die Kurz-ID, damit es bei mehreren beigetretenen "Personal"-
  /// Workspaces nicht zu doppelten Einträgen im Switcher kommt.
  String displayLabel(String? currentUserId) {
    final n = name.trim();
    final isDefault = n.isEmpty || n.toLowerCase() == 'personal';
    if (currentUserId != null && ownerId == currentUserId) return n;
    if (!isDefault) return n;
    return 'Team ${id.substring(0, 8)}';
  }
}

enum WorkspaceRole {
  owner,
  admin,
  member,
  viewer;

  static WorkspaceRole fromString(String s) => switch (s.toLowerCase()) {
        'owner' => owner,
        'admin' => admin,
        'viewer' => viewer,
        _ => member,
      };

  String get apiName => name;

  String get label => switch (this) {
        owner => 'Owner',
        admin => 'Admin',
        member => 'Mitglied',
        viewer => 'Read-only',
      };

  bool get canManageMembers => this == owner || this == admin;
  bool get canEdit => this != viewer;
}

class WorkspaceMember {
  final String workspaceId;
  final String userId;
  final WorkspaceRole role;
  final DateTime joinedAt;
  final String? email;

  const WorkspaceMember({
    required this.workspaceId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.email,
  });

  factory WorkspaceMember.fromSupabase(Map<String, dynamic> row) =>
      WorkspaceMember(
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        role: WorkspaceRole.fromString(row['role'] as String),
        joinedAt: DateTime.parse(row['joined_at'] as String),
        email: row['email'] as String?,
      );
}

class WorkspaceInvite {
  final String id;
  final String workspaceId;
  final String email;
  final WorkspaceRole role;
  final String token;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  const WorkspaceInvite({
    required this.id,
    required this.workspaceId,
    required this.email,
    required this.role,
    required this.token,
    required this.expiresAt,
    required this.createdAt,
    this.acceptedAt,
  });

  bool get isPending =>
      acceptedAt == null && expiresAt.isAfter(DateTime.now().toUtc());

  factory WorkspaceInvite.fromSupabase(Map<String, dynamic> row) =>
      WorkspaceInvite(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        email: row['email'] as String,
        role: WorkspaceRole.fromString(row['role'] as String),
        token: row['token'] as String,
        expiresAt: DateTime.parse(row['expires_at'] as String),
        acceptedAt: row['accepted_at'] != null
            ? DateTime.parse(row['accepted_at'] as String)
            : null,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
