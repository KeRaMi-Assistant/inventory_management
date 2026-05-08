/// Read-only Sicht eines öffentlich freigegebenen Workspaces (`/u/<handle>`).
/// Wird per RPC `get_public_profile(handle)` geladen — der Server entscheidet,
/// welche Felder anonym lesbar sind.
class PublicProfile {
  final String handle;
  final String workspaceName;
  final List<PublicProfileItem> items;

  const PublicProfile({
    required this.handle,
    required this.workspaceName,
    required this.items,
  });

  factory PublicProfile.fromRpc(Map<String, dynamic> row) {
    final ws = (row['workspace'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawItems = (row['items'] as List?) ?? const [];
    return PublicProfile(
      handle: ws['handle'] as String? ?? '',
      workspaceName: ws['name'] as String? ?? '',
      items: rawItems
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => PublicProfileItem.fromRpc(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class PublicProfileItem {
  final String id;
  final String name;
  final String? description;
  final double? price;
  final int quantity;
  final List<String> attachmentPaths;

  const PublicProfileItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.description,
    this.price,
    this.attachmentPaths = const [],
  });

  factory PublicProfileItem.fromRpc(Map<String, dynamic> row) {
    final raw = row['attachment_paths'];
    final paths = raw is List
        ? raw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return PublicProfileItem(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      description: row['public_description'] as String?,
      price: (row['public_price'] as num?)?.toDouble(),
      quantity: (row['quantity'] as num?)?.toInt() ?? 0,
      attachmentPaths: paths,
    );
  }
}
