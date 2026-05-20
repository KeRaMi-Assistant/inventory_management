import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/deal_comment.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';

/// Notiz-/Kommentar-Thread, der unter einem persistierten Deal angezeigt wird.
/// Lädt beim ersten Build alle Kommentare zum Deal und erlaubt das Hinzufügen
/// neuer Einträge sowie das Löschen eigener Einträge.
class DealCommentsSection extends StatefulWidget {
  final int dealId;
  const DealCommentsSection({super.key, required this.dealId});

  @override
  State<DealCommentsSection> createState() => _DealCommentsSectionState();
}

class _DealCommentsSectionState extends State<DealCommentsSection> {
  final _ctrl = TextEditingController();
  List<DealComment>? _comments;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await context
          .read<InventoryProvider>()
          .loadCommentsForDeal(widget.dealId);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _add() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _saving) return;
    final author = context.read<AuthProvider>().userEmail ?? '—';
    setState(() => _saving = true);
    try {
      final saved = await context.read<InventoryProvider>().addComment(
            dealId: widget.dealId,
            author: author,
            body: body,
          );
      if (!mounted) return;
      setState(() {
        _comments = [saved, ...(_comments ?? const [])];
        _ctrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context).dealCommentSaveFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(DealComment c) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.dealCommentDeleteTitle),
        content: Text(l10n.dealCommentDeleteText),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<InventoryProvider>().deleteComment(c.id);
      if (!mounted) return;
      setState(() {
        _comments = (_comments ?? []).where((x) => x.id != c.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dealCommentDeleteFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMd(localeTag).add_Hm();
    final list = _comments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: l10n.dealCommentPlaceholder,
                  isDense: true,
                ),
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saving ? null : _add,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined, size: 16),
              label: Text(l10n.dealCommentSend),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.dealCommentLoadFailed(_error!),
              style: TextStyle(fontSize: 12, color: AppTheme.dangerTextOf(context)),
            ),
          ),
        if (list == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.dealCommentEmpty,
              style: TextStyle(fontSize: 12, color: AppTheme.textDisabledOf(context)),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final c = list[i];
                return Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSubtleOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.author,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                          Text(
                            dateFmt.format(c.createdAt.toLocal()),
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textDisabledOf(context)),
                          ),
                          IconButton(
                            tooltip: l10n.actionDelete,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.delete_outline,
                                size: 16, color: AppTheme.textDisabledOf(context)),
                            onPressed: () => _delete(c),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.body,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
