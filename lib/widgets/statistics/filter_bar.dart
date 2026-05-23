import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/statistics_filter_provider.dart';
import '../../utils/responsive.dart';

/// Filter-Toolbar oben in der Statistik. Adaptiv: auf schmalen Bildschirmen
/// in zwei Reihen, auf breiten in einer.
class StatisticsFilterBar extends StatelessWidget {
  final VoidCallback? onExport;
  const StatisticsFilterBar({super.key, this.onExport});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final filter = context.watch<StatisticsFilterProvider>();
    final inv = context.watch<InventoryProvider>();
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
          final wide = c.maxWidth > Breakpoints.legacyStatsWide;
          final children = <Widget>[
            _PresetGroup(
              selected: filter.preset,
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
            ),
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
                DropdownMenuItem<String>(value: null, child: Text(l10n.commonAll)),
                ...inv.buyers.map((b) =>
                    DropdownMenuItem<String>(value: b.name, child: Text(b.name))),
              ],
              onChanged: filter.setBuyer,
            ),
            _FilterDropdown<String>(
              icon: Icons.store_outlined,
              hint: l10n.dealShop,
              value: filter.shop,
              items: [
                DropdownMenuItem<String>(value: null, child: Text(l10n.commonAll)),
                ...inv.shops.map((s) =>
                    DropdownMenuItem<String>(value: s.name, child: Text(s.name))),
              ],
              onChanged: filter.setShop,
            ),
            _FilterDropdown<String>(
              icon: Icons.local_shipping_outlined,
              hint: l10n.inventoryColSupplier,
              value: filter.supplierId,
              items: [
                DropdownMenuItem<String>(value: null, child: Text(l10n.commonAll)),
                ...inv.suppliers.map((s) =>
                    DropdownMenuItem<String>(value: s.id, child: Text(s.name))),
              ],
              onChanged: filter.setSupplier,
            ),
            SizedBox(
              width: 200,
              child: TextField(
                onChanged: filter.setProductSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.dealProduct,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Row(
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
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: children,
              ),
              if (wide)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: filters,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
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

class _PresetGroup extends StatelessWidget {
  final StatsPreset selected;
  final ValueChanged<StatsPreset> onSelect;
  const _PresetGroup({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: StatsPreset.values.map((p) {
        final isSelected = p == selected;
        return Material(
          color: isSelected
              ? AppTheme.accent
              : AppTheme.bgSubtleOf(context),
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
      }).toList(),
    );
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
  const _FilterDropdown({
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMutedOf(context)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(hint, style: const TextStyle(fontSize: 12)),
              items: items,
              onChanged: onChanged,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
