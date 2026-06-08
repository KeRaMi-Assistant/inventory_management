import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';

/// Descriptor for a single tile in a [SectionHubScreen].
///
/// Either [build] or [onPushFullscreen] must be provided — never both.
///
/// - **Embeddable tiles** provide [build]: a widget factory that returns the
///   sub-screen body (no `Scaffold`). On desktop (≥ [Breakpoints.master])
///   this widget is rendered in the detail pane; on phone it is pushed wrapped
///   in a `Scaffold`.
/// - **Non-embeddable tiles** provide [onPushFullscreen]: a callback that
///   handles navigation itself (e.g. `Navigator.push(StatisticsScreen())`).
///   These tiles never appear "selected" in the master column and always push
///   full-screen, even on desktop.
class SectionHubTile {
  /// Stable identity key — used by [SectionHubScreen] as the `ValueKey` on the
  /// list item AND as the selection discriminator. Must be unique per screen.
  final Key key;

  /// Icon shown in the tile's 48×48 dp icon box.
  final IconData icon;

  /// Primary label, already localised.
  final String label;

  /// Optional secondary line below [label].
  final String? subtitle;

  /// Factory for the embeddable sub-screen body.
  ///
  /// Exactly one of [build] and [onPushFullscreen] must be non-null.
  final Widget Function()? build;

  /// Called when the tile is tapped and the content is NOT embeddable (e.g.
  /// the destination has its own `Scaffold`/`AppBar`). Ignored on desktop when
  /// [build] is provided.
  ///
  /// Exactly one of [build] and [onPushFullscreen] must be non-null.
  final VoidCallback? onPushFullscreen;

  const SectionHubTile({
    required this.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.build,
    this.onPushFullscreen,
  }) : assert(
          (build != null) != (onPushFullscreen != null),
          'Exactly one of build or onPushFullscreen must be provided.',
        );
}

/// Generic hub screen that renders a list of [SectionHubTile]s.
///
/// **Phone / narrow container** (Container-Breite < [Breakpoints.master]):
/// Kachel-Liste; jeder Tap pusht den Sub-Screen als Vollbild-Route.
///
/// **Desktop / breiter Container** (≥ [Breakpoints.master] = 1200 px):
/// Master-Detail-Split — Hub-Kacheln links (320 dp), gewählter Sub-Bereich
/// rechts als embedded Widget (ohne eigenes `Scaffold`). Selections-State
/// lebt innerhalb dieses Widgets und überlebt Resize.
///
/// **A11y-Keys** (kompatibel mit bestehendem `WarehouseHubScreen`):
/// - Tile-Row: der [SectionHubTile.key] wird direkt am `_SectionHubTileCard`
///   gesetzt.
/// - Detail-Pane (leer): `Key('detailPaneEmpty')`
/// - Detail-Pane (mit Inhalt): `Key('detailPane')`
class SectionHubScreen extends StatefulWidget {
  const SectionHubScreen({
    super.key,
    required this.tiles,
  });

  final List<SectionHubTile> tiles;

  @override
  State<SectionHubScreen> createState() => _SectionHubScreenState();
}

class _SectionHubScreenState extends State<SectionHubScreen> {
  /// Currently selected tile in desktop master-detail mode.
  ///
  /// `null` → detail pane shows empty state. Unused on phone (taps push).
  SectionHubTile? _selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = isLarge(constraints.maxWidth);

          if (!wide) {
            return _TileList(
              tiles: widget.tiles,
              selected: null,
              isDesktop: false,
              onTileTap: (tile) {
                if (tile.build != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(tile.label)),
                        body: tile.build!(),
                      ),
                    ),
                  );
                } else {
                  tile.onPushFullscreen?.call();
                }
              },
            );
          }

          // Desktop: master-detail split
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Master column
              SizedBox(
                width: 320,
                child: _TileList(
                  tiles: widget.tiles,
                  selected: _selected,
                  isDesktop: true,
                  onTileTap: (tile) {
                    if (tile.build != null) {
                      setState(() => _selected = tile);
                    } else {
                      tile.onPushFullscreen?.call();
                    }
                  },
                ),
              ),

              // Divider
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppTheme.borderOf(context),
              ),

              // Detail column
              Expanded(
                child: _DetailPane(selected: _selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Tile list (Phone + Master column) ────────────────────────────────────────

class _TileList extends StatelessWidget {
  const _TileList({
    required this.tiles,
    required this.selected,
    required this.isDesktop,
    required this.onTileTap,
  });

  final List<SectionHubTile> tiles;
  final SectionHubTile? selected;
  final bool isDesktop;
  final void Function(SectionHubTile) onTileTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return _SectionHubTileCard(
          key: tile.key,
          tile: tile,
          selected: isDesktop && selected?.key == tile.key,
          onTap: () => onTileTap(tile),
        );
      },
    );
  }
}

// ─── Detail pane (Desktop right column) ───────────────────────────────────────

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.selected});

  final SectionHubTile? selected;

  @override
  Widget build(BuildContext context) {
    final tile = selected;
    if (tile == null || tile.build == null) {
      return _DetailPaneEmpty();
    }
    return Container(
      key: const Key('detailPane'),
      color: AppTheme.bgAppOf(context),
      child: tile.build!(),
    );
  }
}

class _DetailPaneEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('detailPaneEmpty'),
      color: AppTheme.bgAppOf(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 56,
                color: AppTheme.textMutedOf(context),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).warehouseHubDetailPaneEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tile card ─────────────────────────────────────────────────────────────────

class _SectionHubTileCard extends StatelessWidget {
  const _SectionHubTileCard({
    super.key,
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  final SectionHubTile tile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? AppTheme.accentLightOf(context) : null,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: AppTheme.accentTextOf(context),
                width: 1.5,
              ),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // Vertical padding ensures touch target ≥ 48 dp even with short text.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Icon container (48×48 dp touch-target compliant)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentLightOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  tile.icon,
                  size: 24,
                  color: AppTheme.accentTextOf(context),
                ),
              ),
              const SizedBox(width: 16),
              // Labels
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    if (tile.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tile.subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Chevron — non-embeddable tiles always push, show external icon
              Icon(
                tile.onPushFullscreen != null
                    ? Icons.open_in_new_outlined
                    : Icons.chevron_right,
                size: 20,
                color: AppTheme.textMutedOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
