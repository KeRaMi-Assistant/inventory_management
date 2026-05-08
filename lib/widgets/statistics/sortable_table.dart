import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Spaltendefinition für [SortableTable]. [valueOf] liefert den Sortier-Wert.
class SortableColumn<T> {
  final String label;
  final Widget Function(T row) builder;
  final Comparable<Object?> Function(T row)? valueOf;
  final bool numeric;

  SortableColumn({
    required this.label,
    required this.builder,
    this.valueOf,
    this.numeric = false,
  });
}

/// Generische Tabelle mit klickbaren Spaltenheadern, Zebra-Streifen und
/// optionalen Row-Tap-Handlern.
class SortableTable<T> extends StatefulWidget {
  final List<T> rows;
  final List<SortableColumn<T>> columns;
  final Color? Function(T row)? rowColor;
  final void Function(T row)? onTap;
  final int defaultSortIndex;
  final bool defaultAscending;

  const SortableTable({
    super.key,
    required this.rows,
    required this.columns,
    this.rowColor,
    this.onTap,
    this.defaultSortIndex = 0,
    this.defaultAscending = false,
  });

  @override
  State<SortableTable<T>> createState() => _SortableTableState<T>();
}

class _SortableTableState<T> extends State<SortableTable<T>> {
  late int _sortIdx;
  late bool _asc;

  @override
  void initState() {
    super.initState();
    _sortIdx = widget.defaultSortIndex;
    _asc = widget.defaultAscending;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(AppLocalizations.of(context).statsNoDataAvailable,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      );
    }

    final col = widget.columns[_sortIdx];
    final sorted = [...widget.rows];
    if (col.valueOf != null) {
      sorted.sort((a, b) {
        final va = col.valueOf!(a);
        final vb = col.valueOf!(b);
        final cmp = Comparable.compare(va, vb);
        return _asc ? cmp : -cmp;
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.7),
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 16,
            headingRowHeight: 38,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            headingTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
            dataTextStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
            sortColumnIndex: _sortIdx,
            sortAscending: _asc,
            headingRowColor:
                WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              for (var i = 0; i < widget.columns.length; i++)
                DataColumn(
                  label: Text(widget.columns[i].label.toUpperCase()),
                  numeric: widget.columns[i].numeric,
                  onSort: widget.columns[i].valueOf == null
                      ? null
                      : (idx, asc) {
                          setState(() {
                            _sortIdx = idx;
                            _asc = asc;
                          });
                        },
                ),
            ],
            rows: [
              for (final r in sorted)
                DataRow(
                  color: widget.rowColor != null
                      ? WidgetStateProperty.resolveWith(
                          (_) => widget.rowColor!(r))
                      : null,
                  onSelectChanged: widget.onTap == null
                      ? null
                      : (_) => widget.onTap!(r),
                  cells: [
                    for (final c in widget.columns)
                      DataCell(c.builder(r)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
