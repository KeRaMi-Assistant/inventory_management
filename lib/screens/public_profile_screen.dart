import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/public_profile.dart';
import '../services/workspace_service.dart';

/// Öffentlich erreichbare Verkaufsseite eines Workspaces (`/u/<handle>`).
/// Lädt Daten via SECURITY-DEFINER-RPC; benötigt keinen Login.
class PublicProfileScreen extends StatefulWidget {
  final String handle;
  const PublicProfileScreen({super.key, required this.handle});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final WorkspaceService _service;
  late Future<PublicProfile?> _future;

  @override
  void initState() {
    super.initState();
    _service = WorkspaceService(Supabase.instance.client);
    _future = _service.fetchPublicProfile(widget.handle);
  }

  Future<void> _retry() async {
    setState(() {
      _future = _service.fetchPublicProfile(widget.handle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      body: FutureBuilder<PublicProfile?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return _NotFoundView(onRetry: _retry, l10n: l10n);
          }
          return _ProfileView(profile: snap.data!);
        },
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  final VoidCallback onRetry;
  final AppLocalizations l10n;
  const _NotFoundView({required this.onRetry, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off,
                    size: 56, color: AppTheme.textMutedOf(context)),
                const SizedBox(height: 16),
                Text(
                  l10n.publicProfileNotFoundTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.publicProfileNotFoundBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.actionRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final PublicProfile profile;
  const _ProfileView({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;
    final crossCount = width >= 1100
        ? 3
        : width >= 700
            ? 2
            : 1;

    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(profile: profile)),
              if (profile.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l10n.publicProfileEmptyItems,
                        style:
                            TextStyle(color: AppTheme.textMutedOf(context)),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    isPhone ? 100 : 32,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 360,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) =>
                          _ItemCard(item: profile.items[idx]),
                      childCount: profile.items.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _Footer(extraBottom: isPhone ? 80 : 0),
              ),
            ],
          ),
          if (isPhone)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _ContactButton(profile: profile),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final PublicProfile profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderOf(context)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Flex(
            direction: isPhone ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: isPhone
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.accentLightOf(context),
                    child: Text(
                      _initial(profile.workspaceName),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentTextOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.workspaceName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '/u/${profile.handle}',
                          style: TextStyle(
                            color: AppTheme.textMutedOf(context),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isPhone)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: SizedBox(
                    width: 220,
                    child: _ContactButton(profile: profile, dense: true),
                  ),
                ),
              if (isPhone) const SizedBox(height: 4),
              if (isPhone)
                Text(
                  l10n.publicProfileFooter,
                  style: TextStyle(
                    color: AppTheme.textMutedOf(context),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String s) {
    final t = s.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }
}

class _ItemCard extends StatelessWidget {
  final PublicProfileItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = item.price;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: _ItemImage(paths: item.attachmentPaths),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.description != null &&
                      item.description!.trim().isNotEmpty)
                    Text(
                      item.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textMutedOf(context),
                        fontSize: 13,
                      ),
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (price != null)
                        Text(
                          _formatPrice(price),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentTextOf(context),
                          ),
                        )
                      else
                        Text(
                          '—',
                          style: TextStyle(
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                      Text(
                        l10n.publicProfileItemQuantity(item.quantity),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPrice(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
}

class _ItemImage extends StatefulWidget {
  final List<String> paths;
  const _ItemImage({required this.paths});

  @override
  State<_ItemImage> createState() => _ItemImageState();
}

class _ItemImageState extends State<_ItemImage> {
  String? _signedUrl;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.paths.isNotEmpty) {
      _loadUrl();
    }
  }

  Future<void> _loadUrl() async {
    setState(() => _loading = true);
    try {
      final url = await Supabase.instance.client.storage
          .from('attachments')
          .createSignedUrl(widget.paths.first, 3600);
      if (!mounted) return;
      setState(() {
        _signedUrl = url;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bgSubtleOf(context);
    if (widget.paths.isEmpty || _failed) {
      return Container(
        color: bg,
        child: Icon(Icons.image_outlined,
            size: 40, color: AppTheme.textMutedOf(context)),
      );
    }
    if (_loading || _signedUrl == null) {
      return Container(color: bg);
    }
    return CachedNetworkImage(
      imageUrl: _signedUrl!,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: bg),
      errorWidget: (_, _, _) => Container(
        color: bg,
        child: Icon(Icons.broken_image_outlined,
            size: 40, color: AppTheme.textMutedOf(context)),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final PublicProfile profile;
  final bool dense;
  const _ContactButton({required this.profile, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accent,
        minimumSize: Size.fromHeight(dense ? 44 : 52),
      ),
      onPressed: () => _openMail(context),
      icon: const Icon(Icons.mail_outline),
      label: Text(l10n.publicProfileContact),
    );
  }

  Future<void> _openMail(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final subject =
        Uri.encodeComponent('${l10n.publicProfileContactSubject} (/u/${profile.handle})');
    // Kein Email-Adressen-Leak: wir kennen die Inhaber-Mail nicht. Statt
    // mailto:owner@... öffnen wir mailto: mit Betreff — der Nutzer setzt
    // die Empfänger-Adresse selbst ein. Future Iteration: kontaktbares
    // Public-Mail-Feld am Workspace.
    final uri = Uri.parse('mailto:?subject=$subject');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _Footer extends StatelessWidget {
  final double extraBottom;
  const _Footer({this.extraBottom = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + extraBottom),
      child: Center(
        child: Text(
          l10n.publicProfileFooter,
          style: TextStyle(
            color: AppTheme.textMutedOf(context),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
