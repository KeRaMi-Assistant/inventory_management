/// IMAP-Konto eines Workspaces. Das Passwort liegt nie im Modell —
/// gesetzt wird es separat per RPC `set_mailbox_password`.
class MailboxAccount {
  final String id;
  final String workspaceId;
  final String label;
  final String imapHost;
  final int imapPort;
  final bool useSsl;
  final String username;
  final String folder;
  final bool enabled;
  final int? lastUid;
  final DateTime? lastPolledAt;
  final String? lastError;

  const MailboxAccount({
    required this.id,
    required this.workspaceId,
    required this.label,
    required this.imapHost,
    required this.imapPort,
    required this.useSsl,
    required this.username,
    required this.folder,
    required this.enabled,
    this.lastUid,
    this.lastPolledAt,
    this.lastError,
  });

  factory MailboxAccount.fromSupabase(Map<String, dynamic> row) =>
      MailboxAccount(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        label: row['label'] as String,
        imapHost: row['imap_host'] as String,
        imapPort: (row['imap_port'] as num).toInt(),
        useSsl: row['use_ssl'] as bool? ?? true,
        username: row['username'] as String,
        folder: row['folder'] as String? ?? 'INBOX',
        enabled: row['enabled'] as bool? ?? true,
        lastUid: (row['last_uid'] as num?)?.toInt(),
        lastPolledAt: row['last_polled_at'] != null
            ? DateTime.parse(row['last_polled_at'] as String)
            : null,
        lastError: row['last_error'] as String?,
      );

  Map<String, dynamic> toSupabaseInsert() => {
        'label': label,
        'imap_host': imapHost,
        'imap_port': imapPort,
        'use_ssl': useSsl,
        'username': username,
        'folder': folder,
        'enabled': enabled,
      };

  MailboxAccount copyWith({
    String? label,
    String? imapHost,
    int? imapPort,
    bool? useSsl,
    String? username,
    String? folder,
    bool? enabled,
    int? lastUid,
    DateTime? lastPolledAt,
    String? lastError,
  }) =>
      MailboxAccount(
        id: id,
        workspaceId: workspaceId,
        label: label ?? this.label,
        imapHost: imapHost ?? this.imapHost,
        imapPort: imapPort ?? this.imapPort,
        useSsl: useSsl ?? this.useSsl,
        username: username ?? this.username,
        folder: folder ?? this.folder,
        enabled: enabled ?? this.enabled,
        lastUid: lastUid ?? this.lastUid,
        lastPolledAt: lastPolledAt ?? this.lastPolledAt,
        lastError: lastError ?? this.lastError,
      );
}
