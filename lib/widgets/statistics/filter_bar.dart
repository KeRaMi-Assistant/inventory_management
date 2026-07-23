import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/deals_provider.dart';
import '../../providers/purchasing_provider.dart';
import '../../providers/statistics_filter_provider.dart';
import '../../utils/responsive.dart';

/// Filter-Toolbar oben in der Statistik. Adaptiv in drei Stufen:
///
/// - **Compact (< 600 px, Phone):** nur Zeitraum-Chips (horizontal scrollbar,
///   eine Zeile) + „Filter"-Button mit Aktiv-Badge. Die Detail-Filter
///   (Käufer/Shop/Lieferant/Produktsuche/Vergleich) leben in einem
///   Bottom-Sheet — vorher fraß das volle Panel ~½ Phone-Viewport und
///   stauchte die Charts (UX-Audit 2026-07-22, Finding #9).
/// - **Medium:** Presets + Compare als Wrap, Detail-Filter als zweites Wrap.
/// - **Wide (> 900 px):** wie Medium, großzügigere Abstände.
class StatisticsFilterBar extends StatelessWidget {
  final VoidCallback? onExport;
  const StatisticsFilterBar({super.key, this.onExport});

  /// Anzahl aktiver Detail-Filter (ohne Zeitraum-Preset) — Badge am
  /// „Filter"-Button im kompakten Layout.
  static int _activeDetailFilterCount(StatisticsFilterProvider f) =>
      (f.buyer != null ? 1 : 0) +
      (f.shop != null ? 1 : 0) +
      (f.supplierId != null ? 1 : 0) +
      (f.productSearch.isNotEmpty ? 1 : 0);

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final filter = context.watch<StatisticsFilterProvider>();
    final inv = context.watch<DealsProvider>();
    // Suppliers now live in PurchasingProvider; buyers/shops stay on Inventory.
    final purchasing = context.watch<PurchasingProvider>();
    final dateFmt = DateFormat.yMd(localeTag);
    final r = filter.currentRange;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = isCompact(c.maxWidth);
          final wide = c.maxWidth > Breakpoints.legacyStatsWide;

          final headerRow = Row(
            children: [
              Icon(Icons.filter_alt_outlined,
                  size: 16, color: AppTheme.textMutedOf(context)),
              const SizedBox(width: 6),
              Text(
                '${dateFmt.format(r.from)} – ${dateFmt.format(r.to)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const Spacer(),
              if (onExport != null)
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(l10n.statsExportReport),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.borderOf(context)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          );

          final presetGroup = _PresetGroup(
            selected: filter.preset,
            scrollable: compact,
            onSelect: (p) async {
              if (p == StatsPreset.custom) {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  initialDateRange: DateTimeRange(
                    start: filter.customFrom ??
                        DateTime.now().subtract(const Duration(days: 29)),
                    end: filter.customTo ?? DateTime.now(),
                  ),
                );
                if (picked != null) {
                  filter.setCustomRange(picked.start, picked.end);
                }
              } else {
                filter.setPreset(p);
              }
            },
          );

          // ── Compact (Phone): Presets 1-zeilig + Filter-Button ────────────
          if (compact) {
            final activeCount = _activeDetailFilterCount(filter);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerRow,
                const SizedBox(height: 10),
                presetGroup,
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openFilterSheet(context),
                      icon: Badge(
                        isLabelVisible: activeCount > 0,
                        label: Text('$activeCount'),
                        child: const Icon(Icons.tune, size: 16),
                      ),
                      label: Text(l10n.statsFilterButton),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: activeCount > 0
                                ? AppTheme.accentTextOf(context)
                                : AppTheme.borderOf(context)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const Spacer(),
                    if (filter.hasAnyFilter ||
                        filter.preset != StatsPreset.last30)
                      TextButton.icon(
                        onPressed: filter.reset,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(l10n.actionReset),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textMutedOf(context)),
                      ),
                  ],
                ),
              ],
            );
          }

          // ── Medium/Wide: bisheriges Layout ────────────────────────────────
          final children = <Widget>[
            presetGroup,
            const SizedBox(width: 16, height: 8),
            _CompareToggle(
              value: filter.compareToPrevious,
              onChanged: (v) => filter.toggleCompare(v),
            ),
          ];

          final filters = <Widget>[
            _FilterDropdown<String>(
              icon: Icons.person_outline,
              hint: l10n.dealBuyer,
              value: filter.buyer,
              items: [
                DropdownMenuItem<String>(
                    value: null, child: Text(l10n.commonAll)),
                ...inv.buyers.map((b) => DropdownMenuItem<String>(
                    value: b.name, child: Text(b.name))),
              ],
              onChanged: filter.setBuyer,
            ),
            _FilterDropdown<String>(
              icon: Icons.store_outlined,
              hint: l10n.dealShop,
              value: filter.shop,
              items: [
                DropdownMenuItem<String>(
                    value: null, child: Text(l10n.commonAll)),
                ...inv.shops.map((s) => DropdownMenuItem<String>(
                    value: s.name, child: Text(s.name))),
              ],
              onChanged: filter.setShop,
            ),
            _FilterDropdown<String>(
              icon: Icons.local_shipping_outlined,
              hint: l10n.inventoryColSupplier,
              value: filter.supplierId,
              items: [
                DropdownMenuItem<String>(
                    value: null, child: Text(l10n.commonAll)),
                ...purchasing.suppliers.map((s) => DropdownMenuItem<String>(
                    value: s.id, child: Text(s.name))),
              ],
              onChanged: filter.setSupplier,
            ),
            SizedBox(
              width: 200,
              child: TextFormField(
                initialValue: filter.productSearch,
                onChanged: filter.setProductSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.dealProduct,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ),
            if (filter.hasAnyFilter || filter.preset != StatsPreset.last30)
              TextButton.icon(
                onPressed: filter.reset,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.actionReset),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMutedOf(context)),
              ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerRow,
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: children,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: wide ? 12 : 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: filters,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bottom-Sheet mit den Detail-Filtern (Phone). Beobachtet die Provider
/// selbst, damit Auswahl-Änderungen sofort im Sheet reflektiert werden.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filter = context.watch<StatisticsFilterProvider>();
    final inv = context.watch<DealsProvider>();
    final purchasing = context.watch<PurchasingProvider>();

    return SafeArea(
      child: Padding(
        // Keyboard-safe: Produktsuche darf nicht von der Tastatur verdeckt
        // werden (CLAUDE.md Mobile-First).
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.statsFilterSheetTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close,
                          size: 20, color: AppTheme.textMutedOf(context)),
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _CompareToggle(
                value: filter.compareToPrevious,
                onChanged: (v) => filter.toggleCompare(v),
              ),
              const SizedBox(height: 12),
              _FilterDropdown<String>(
                icon: Icons.person_outline,
                hint: l10n.dealBuyer,
                value: filter.buyer,
                expanded: true,
                items: [
                  DropdownMenuItem<String>(
                      value: null, child: Text(l10n.commonAll)),
                  ...inv.buyers.map((b) => DropdownMenuItem<String>(
                      value: b.name, child: Text(b.name))),
                ],
                onChanged: filter.setBuyer,
              ),
              const SizedBox(height: 10),
              _FilterDropdown<String>(
                icon: Icons.store_outlined,
                hint: l10n.dealShop,
                value: filter.shop,
                expanded: true,
                items: [
                  DropdownMenuItem<String>(
                      value: null, child: Text(l10n.commonAll)),
                  ...inv.shops.map((s) => DropdownMenuItem<String>(
                      value: s.name, child: Text(s.name))),
                ],
                onChanged: filter.setShop,
              ),
              const SizedBox(height: 10),
              _FilterDropdown<String>(
                icon: Icons.local_shipping_outlined,
                hint: l10n.inventoryColSupplier,
                value: filter.supplierId,
                expanded: true,
                items: [
                  DropdownMenuItem<String>(
                      value: null, child: Text(l10n.commonAll)),
                  ...purchasing.suppliers.map((s) => DropdownMenuItem<String>(
                      value: s.id, child: Text(s.name))),
                ],
                onChanged: filter.setSupplier,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: filter.productSearch,
                onChanged: filter.setProductSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.dealProduct,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: filter.reset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(l10n.actionReset),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textMutedOf(context)),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.actionApply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetGroup extends StatelessWidget {
  final StatsPreset selected;
  final ValueChanged<StatsPreset> onSelect;

  /// `true` (Phone): eine Zeile, horizontal scrollbar — statt 2-zeiligem
  /// Wrap, der den halben Viewport frisst.
  final bool scrollable;

  const _PresetGroup({
    required this.selected,
    required this.onSelect,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = StatsPreset.values.map((p) {
      final isSelected = p == selected;
      return Material(
        color: isSelected ? AppTheme.accent : AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelect(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              p.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
        ),
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              chips[i],
            ],
          ],
        ),
      );
    }

    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

class _CompareToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CompareToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? AppTheme.accentLightOf(context)
          : AppTheme.bgSubtleOf(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 14,
                color: value
                    ? AppTheme.accentTextOf(context)
                    : AppTheme.textMutedOf(context),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).statsCompareToPrevious,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: value
                      ? AppTheme.accentTextOf(context)
                      : AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  /// `true` im Bottom-Sheet: volle Breite + 44-dp-Höhe (Touch-Target).
  final bool expanded;

  const _FilterDropdown({
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: const TextStyle(fontSize: 12)),
        items: items,
        onChanged: onChanged,
        isExpanded: expanded,
        style:
            TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 10, vertical: expanded ? 8 : 0),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMutedOf(context)),
          const SizedBox(width: 6),
          expanded ? Expanded(child: dropdown) : dropdown,
        ],
      ),
    );
  }
}
