import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Wraps Supabase Storage interactions for image attachments on deals/items.
/// Object key scheme: `<user_id>/<entity_kind>/<entity_id>/<uuid>.<ext>`.
/// The leading `<user_id>` segment is enforced by RLS on `storage.objects`.
class AttachmentService {
  AttachmentService(this._client);

  final SupabaseClient _client;
  final _uuid = const Uuid();
  static const String bucket = 'attachments';

  /// Max number of attachments per entity. Mirrors the SQL CHECK constraint.
  static const int maxPerEntity = 5;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('AttachmentService requires an authenticated user.');
    }
    return id;
  }

  /// Reads the picked image into memory, picks an extension based on MIME, and
  /// uploads it. Returns the storage path (relative to bucket) on success.
  Future<String> upload(
    XFile file, {
    required String entityKind,
    required String entityId,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = _extFor(file);
    final mime = _mimeFor(ext);
    final path = '$_userId/$entityKind/$entityId/${_uuid.v4()}.$ext';

    await _client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: mime,
            upsert: false,
          ),
        );
    return path;
  }

  /// Removes an object from storage. Silently ignores 404s so that callers can
  /// best-effort clean up after partial failures.
  Future<void> delete(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {
      // Storage already gone or RLS-blocked; the row's path list is the
      // source of truth, so we don't surface this to the user.
    }
  }

  Future<void> deleteMany(Iterable<String> paths) async {
    final list = paths.toList();
    if (list.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove(list);
    } catch (_) {
      // ignored — see [delete]
    }
  }

  /// Returns a 1-hour signed URL for displaying private images.
  Future<String> signedUrl(String path) {
    return _client.storage.from(bucket).createSignedUrl(path, 3600);
  }

  String _extFor(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    if (name.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _mimeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
}
