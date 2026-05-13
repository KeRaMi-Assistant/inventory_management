import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/activity_entry.dart';
import '../providers/inventory_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final Set<String> _activeTypes = {};
  String _query = '';

  static final _typeMeta = <String, ({IconData icon, Color color})>{
    'deal':     (icon: Icons.list_alt_rounded,         color: AppTheme.accent),
    'status':   (icon: Icons.flag_rounded,             color: AppTheme.info),
    'stock':    (icon: Icons.inventory_2_rounded,      color: AppTheme.success),
    'supplier': (icon: Icons.local_shipping_rounded,   color: AppTheme.warning),
    'batch':    (icon: Icons.layers_rounded,           color: AppTheme.warning),
    'bulk':     (icon: Icons.dynamic_feed_rounded,     color: AppTheme.accentDark),
    'import':   (icon: Icons.upload_file_rounded,      color: AppTheme.accentDark),
    'comment':  (icon: Icons.chat_bubble_outline,      color: AppTheme.info),
    'info':     (icon: Icons.info_outline_rounded,     color: AppTheme.textMuted),
  };

  String _typeLabel(AppLocalizations l10n, String type) => switch (type) {
        'deal' => l10n.activityTypeDeal,
        'status' => l10n.activityTypeStatus,
        'stock' => l10n.activityTypeStock,
        'supplier' => l10n.activityTypeSupplier,
        'batch' => l10n.activityTypeBatch,
        'bulk' => l10n.activityTypeBulk,
        'import' => l10n.activityTypeImport,
        'comment' => l10n.activityTypeComment,
        _ => l10n.activityTypeInfo,
      };

  ({IconData icon, Color color, String label}) _metaFor(
      AppLocalizations l10n, String type) {
    final meta = _typeMeta[type] ?? _typeMeta['info']!;
    return (icon: meta.icon, color: meta.color, label: _typeLabel(l10n, type));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    metaFor(String type) => _metaFor(l10n, type);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final all = provider.activities;
        final filtered = _filter(all);

        return Column(
          children: [
            _Header(
              total: all.length,
              filtered: filtered.length,
            ),
            _FilterBar(
              query: _query,
              activeTypes: _activeTypes,
              availableTypes: all.map((a) => a.type).toSet(),
              metaFor: metaFor,
              onQueryChanged: (v) => setState(() => _query = v),
              onTypeToggled: (t) => setState(() {
                if (!_activeTypes.add(t)) _activeTypes.remove(t);
              }),
              onClearTypes: _activeTypes.isEmpty
                  ? null
                  : () => setState(_activeTypes.clear),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _Empty(hasActivities: all.isNotEmpty)
                  : _ActivityList(
                      entries: filtered,
                      metaFor: metaFor,
                    ),
            ),
          ],
        );
      },
    );
  }

  List<ActivityEntry> _filter(List<ActivityEntry> all) {
    final q = _query.trim().toLowerCase();
    return all.where((entry) {
      if (_activeTypes.isNotEmpty && !_activeTypes.contains(entry.type)) {
        return false;
      }
      if (q.isNotEmpty && !entry.message.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int total;
  final int filtered;
  const _Header({required this.total, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showFiltered = total != filtered;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.history_rounded,
                color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activityHeading,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showFiltered
                      ? l10n.activityCountFiltered(filtered, total)
                      : l10n.activityCountTotal(total),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String query;
  final Set<String> activeTypes;
  final Set<String> availableTypes;
  final ({IconData icon, Color color, String label}) Function(String) metaFor;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onTypeToggled;
  final VoidCallback? onClearTypes;

  const _FilterBar({
    required this.query,
    required this.activeTypes,
    required this.availableTypes,
    required this.metaFor,
    required this.onQueryChanged,
    required this.onTypeToggled,
    required this.onClearTypes,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordered = [
      'deal', 'status', 'stock', 'supplier', 'batch', 'bulk', 'import',
      'comment', 'info',
    ].where(availableTypes.contains).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: l10n.activitySearchHint,
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final type in ordered) ...[
                  _TypeChip(
                    label: metaFor(type).label,
                    icon: metaFor(type).icon,
                    color: metaFor(type).color,
                    selected: activeTypes.contains(type),
                    onTap: () => onTypeToggled(type),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onClearTypes != null)
                  TextButton.icon(
                    onPressed: onClearTypes,
                    icon: const Icon(Icons.close, size: 14),
                    label: Text(l10n.activityFilterReset),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textMutedOf(context),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(28) : AppTheme.bgSubtleOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppTheme.borderOf(context),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : AppTheme.textMutedOf(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── List ────────────────────────────────────────────────────────────────────

class _ActivityList extends StatelessWidget {
  final List<ActivityEntry> entries;
  final ({IconData icon, Color color, String label}) Function(String) metaFor;

  const _ActivityList({required this.entries, required this.metaFor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final groups = _groupByDay(
      entries,
      todayLabel: l10n.activityToday,
      yesterdayLabel: l10n.activityYesterday,
      localeTag: localeTag,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                group.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMutedOf(context),
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final entry in group.entries)
              _ActivityTile(entry: entry, meta: metaFor(entry.type)),
          ],
        );
      },
    );
  }

  List<({String label, List<ActivityEntry> entries})> _groupByDay(
      List<ActivityEntry> all,
      {required String todayLabel,
      required String yesterdayLabel,
      required String localeTag}) {
    final byDay = <String, List<ActivityEntry>>{};
    final order = <String>[];
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayKey =
        DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));
    final fmt = DateFormat.yMMMMEEEEd(localeTag);

    for (final entry in all) {
      final key = DateFormat('yyyy-MM-dd').format(entry.date);
      if (!byDay.containsKey(key)) {
        order.add(key);
        byDay[key] = [];
      }
      byDay[key]!.add(entry);
    }

    return [
      for (final key in order)
        (
          label: switch (key) {
            _ when key == todayKey => todayLabel,
            _ when key == yesterdayKey => yesterdayLabel,
            _ => fmt.format(byDay[key]!.first.date).toUpperCase(),
          },
          entries: byDay[key]!,
        ),
    ];
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityEntry entry;
  final ({IconData icon, Color color, String label}) meta;

  const _ActivityTile({required this.entry, required this.meta});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(entry.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: meta.color.withAlpha(28),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(meta.icon, color: meta.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimaryOf(context),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      meta.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: meta.color,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppTheme.textDisabledOf(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final bool hasActivities;
  const _Empty({required this.hasActivities});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasActivities
                ? Icons.filter_alt_off_rounded
                : Icons.history_toggle_off_rounded,
            size: 48,
            color: AppTheme.textDisabledOf(context),
          ),
          const SizedBox(height: 12),
          Text(
            hasActivities
                ? l10n.activityNoMatches
                : l10n.activityNoActivitiesYet,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasActivities
                ? l10n.activityAdjustFilters
                : l10n.activityAutoAppears,
            style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
          ),
        ],
      ),
    );
  }
}
