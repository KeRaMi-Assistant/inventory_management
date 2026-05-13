import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/attachment_service.dart';

/// Inline-Gallery für Foto-Anhänge an Items/Deals. Hält die `paths`-Liste
/// als Local-State (Source-of-Truth liegt beim Caller / Form-State) und
/// meldet Mutationen über [onChanged] zurück.
///
/// Tap auf Bild → Lightbox. Long-Press auf Bild → Löschen-Dialog.
class AttachmentGallery extends StatefulWidget {
  const AttachmentGallery({
    super.key,
    required this.paths,
    required this.onChanged,
    required this.entityKind,
    required this.entityId,
    this.compact = false,
  });

  /// Aktuelle Liste der Storage-Pfade (mutable im Form-State des Parents).
  final List<String> paths;

  /// Wird mit der neuen Liste aufgerufen, wenn ein Bild dazugekommen oder
  /// gelöscht ist. Parent persistiert dann beim Speichern.
  final ValueChanged<List<String>> onChanged;

  /// 'deal' oder 'item' – nur als Storage-Subordner relevant.
  final String entityKind;

  /// Wenn die Entität noch nicht gespeichert ist, kann der Parent eine
  /// vorab generierte UUID übergeben (für Items) oder einen temporären
  /// Schlüssel. Bilder werden dann beim Speichern später migriert
  /// (out of scope für diesen Sprint — wir blockieren Upload bei leerer ID).
  final String entityId;

  final bool compact;

  @override
  State<AttachmentGallery> createState() => _AttachmentGalleryState();
}

class _AttachmentGalleryState extends State<AttachmentGallery> {
  final _picker = ImagePicker();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final canAdd =
        widget.paths.length < AttachmentService.maxPerEntity && !_busy;
    final tileSize = widget.compact ? 56.0 : 72.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library_outlined,
                size: 16, color: AppTheme.textMutedOf(context)),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).attachmentTitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMutedOf(context),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.paths.length}/${AttachmentService.maxPerEntity}',
              style: TextStyle(fontSize: 11, color: AppTheme.textDisabledOf(context)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: tileSize,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < widget.paths.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Thumbnail(
                    path: widget.paths[i],
                    size: tileSize,
                    onTap: () => _openLightbox(i),
                    onDelete: () => _confirmDelete(i),
                  ),
                ),
              if (canAdd) _AddTile(size: tileSize, onTap: _addImages),
              if (widget.paths.isEmpty && !canAdd)
                Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context).dealCommentEmpty,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addImages() async {
    if (widget.entityId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).actionSave),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final remaining =
        AttachmentService.maxPerEntity - widget.paths.length;
    if (remaining <= 0) return;

    final source = await _pickSource();
    if (source == null || !mounted) return;

    setState(() => _busy = true);
    final svc = context.read<AttachmentService>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      final List<XFile> picked = source == ImageSource.camera
          ? [
              await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1600,
                    maxHeight: 1600,
                    imageQuality: 85,
                  ) ??
                  XFile(''),
            ].where((f) => f.path.isNotEmpty).toList()
          : await _picker.pickMultiImage(
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 85,
              limit: remaining,
            );

      if (picked.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final toUpload = picked.take(remaining).toList();

      final uploaded = <String>[];
      for (final file in toUpload) {
        final path = await svc.upload(
          file,
          entityKind: widget.entityKind,
          entityId: widget.entityId,
        );
        uploaded.add(path);
      }
      widget.onChanged([...widget.paths, ...uploaded]);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.errorPrefix('$e')),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ImageSource?> _pickSource() async {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.attachmentTakePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.attachmentPickGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.dealCommentDeleteTitle),
        content: Text(l10n.dealCommentDeleteText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final path = widget.paths[index];
    final svc = context.read<AttachmentService>();
    await svc.delete(path);
    final next = [...widget.paths]..removeAt(index);
    widget.onChanged(next);
  }

  Future<void> _openLightbox(int index) async {
    final svc = context.read<AttachmentService>();
    showDialog<void>(
      context: context,
      builder: (_) => _LightboxDialog(
        paths: widget.paths,
        startIndex: index,
        service: svc,
      ),
    );
  }
}

// ─── Tiles & Lightbox ────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final String path;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _Thumbnail({
    required this.path,
    required this.size,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final svc = context.read<AttachmentService>();
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: size,
              height: size,
              color: AppTheme.bgSubtleOf(context),
              child: FutureBuilder<String>(
                future: svc.signedUrl(path),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return CachedNetworkImage(
                    imageUrl: snap.data!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    placeholder: (_, _) =>
                        ColoredBox(color: AppTheme.bgSubtleOf(context)),
                    errorWidget: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.textDisabledOf(context),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  const _AddTile({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.accent.withAlpha(120),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Icon(Icons.add_a_photo_outlined,
            color: AppTheme.accent, size: 20),
      ),
    );
  }
}

class _LightboxDialog extends StatefulWidget {
  final List<String> paths;
  final int startIndex;
  final AttachmentService service;
  const _LightboxDialog({
    required this.paths,
    required this.startIndex,
    required this.service,
  });

  @override
  State<_LightboxDialog> createState() => _LightboxDialogState();
}

class _LightboxDialogState extends State<_LightboxDialog> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _ctrl = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Center(
              child: FutureBuilder<String>(
                future: widget.service.signedUrl(widget.paths[i]),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const CircularProgressIndicator(
                        color: Colors.white);
                  }
                  return InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: snap.data!,
                      fit: BoxFit.contain,
                      placeholder: (_, _) =>
                          const CircularProgressIndicator(color: Colors.white),
                      errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image, color: Colors.white, size: 48),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.paths.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.paths.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
