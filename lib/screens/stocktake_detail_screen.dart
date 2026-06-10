import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../models/stocktake.dart';
import '../models/stocktake_item.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/stock_provider.dart';
import '../widgets/app_feedback.dart';
import '../widgets/barcode_scanner_sheet.dart';
import '../widgets/confirm_dialog.dart';
import 'stocktake_screen.dart' show StocktakeStatusBadge;

// ─────────────────────────────────────────────────────────────────────────────
// StocktakeDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Zähl-Workflow für eine Inventur-Session (Epic E, Task E3).
///
/// Lädt Positionen lazy via [InventoryProvider.loadStocktakeItems].
/// Inkrementelles Speichern pro Zähl-Eingabe (kein Batch-Submit).
/// Barcode-Scan-Einsprung via [BarcodeScannerSheet].
/// Differenz-Report als vertikale Cards nach Abschluss.
///
/// A11y-Keys: `stocktakeCountField-<id>`, `stocktakeFilterUncounted`,
/// `stocktakeCloseButton`.
class StocktakeDetailScreen extends StatefulWidget {
  final Stocktake stocktake;

  const StocktakeDetailScreen({super.key, required this.stocktake});

  @override
  State<StocktakeDetailScreen> createState() => _StocktakeDetailScreenState();
}

class _StocktakeDetailScreenState extends State<StocktakeDetailScreen> {
  late Stocktake _stocktake;
  List<StocktakeItem>? _items;
  bool _loadingItems = true;
  String? _itemsError;

  /// Lokal gepufferte gezählte Mengen (item.id → qty). Wird bei Netzwerkfehler
  /// gehalten, damit eingegebene Werte nicht verloren gehen.
  final Map<String, int> _localCounted = {};

  /// Ausstehende Saves (item.id → true). Zeigt Spinning-Indicator in der Zeile.
  final Map<String, bool> _saving = {};

  /// Letzte Fehler pro Item (item.id → Fehlermeldung). Wird nach erfolgreichem
  /// Save gelöscht.
  final Map<String, String> _saveErrors = {};

  /// Nur ungezählte Positionen anzeigen.
  bool _filterUncounted = false;

  /// Differenz-Report sichtbar (nach Abschluss).
  bool _showDiffReport = false;

  /// Scroll-Controller für Barcode-Einsprung (Scroll zur entsprechenden Zeile).
  final ScrollController _scrollController = ScrollController();

  /// Map item.id → GlobalKey für die entsprechende Zähl-Zeile (Scroll-Target).
  final Map<String, GlobalKey> _rowKeys = {};

  @override
  void initState() {
    super.initState();
    _stocktake = widget.stocktake;
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadItems() async {
    final stocktakeId = _stocktake.id;
    if (stocktakeId == null) {
      setState(() {
        _items = const [];
        _loadingItems = false;
      });
      return;
    }
    setState(() {
      _loadingItems = true;
      _itemsError = null;
    });
    try {
      final provider = Provider.of<StockProvider>(context, listen: false);
      final items = await provider.loadStocktakeItems(stocktakeId);
      if (mounted) {
        setState(() {
          _items = items;
          _loadingItems = false;
          // Initialisiere lokale Puffer aus DB-Werten.
          for (final item in _items!) {
            _localCounted[item.id] = item.countedQty ?? item.expectedQty;
            _rowKeys[item.id] = GlobalKey();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingItems = false;
          // _itemsError wird nur als null-Check verwendet (zeigt
          // l10n.stocktakeLoadError). Kein roher String in der UI.
          _itemsError = e.toString();
        });
      }
    }
  }

  // ── Inkrementelles Speichern ───────────────────────────────────────────────

  /// Setzt [countedQty] für [item] und persistiert sofort.
  /// Bei Netzwerkfehler: lokaler Wert wird behalten, dezenter Fehlerhinweis.
  Future<void> _saveCounted(StocktakeItem item, int countedQty) async {
    if (_saving[item.id] == true) return;
    setState(() {
      _localCounted[item.id] = countedQty;
      _saving[item.id] = true;
      _saveErrors.remove(item.id);
    });

    try {
      final provider = Provider.of<StockProvider>(context, listen: false);
      final saved = await provider.countStocktakeItem(item, countedQty);
      if (mounted) {
        setState(() {
          final idx = _items!.indexWhere((i) => i.id == saved.id);
          if (idx != -1) _items![idx] = saved;
          _saving.remove(item.id);
        });
      }
    } catch (e) {
      debugPrint('countStocktakeItem failed: $e');
      if (mounted) {
        setState(() {
          _saving.remove(item.id);
          _saveErrors[item.id] =
              AppLocalizations.of(context).stocktakeSaveError;
        });
      }
    }
  }

  // ── Barcode-Einsprung ──────────────────────────────────────────────────────

  Future<void> _scanBarcode(BuildContext ctx) async {
    // Capture context-dependent objects before any async gap.
    final l10n = AppLocalizations.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);
    // Produkte aus dem CatalogProvider für EAN/SKU-Match — vor dem await lesen.
    final products = Provider.of<CatalogProvider>(ctx, listen: false).products;

    final code = await BarcodeScannerSheet.show(
      ctx,
      title: l10n.stocktakeScanBarcode,
    );
    if (code == null || !mounted) return;

    final items = _items;
    if (items == null) return;
    Product? matched;
    for (final p in products) {
      if ((p.ean != null && p.ean == code) ||
          (p.sku != null && p.sku == code)) {
        matched = p;
        break;
      }
    }

    if (matched == null) {
      AppFeedback.infoOn(
        messenger,
        l10n.stocktakeScanNoMatch,
        rootContext: context,
      );
      return;
    }

    // Finde passende Inventur-Position.
    final mp = matched;
    final matchedItem =
        items.where((i) => i.productId == mp.id).firstOrNull;
    if (matchedItem == null) {
      AppFeedback.infoOn(
        messenger,
        l10n.stocktakeScanNoMatch,
        rootContext: context,
      );
      return;
    }

    // Falls Filter aktiv und das Item gezählt ist, kurz deaktivieren.
    if (_filterUncounted && matchedItem.isCounted) {
      setState(() => _filterUncounted = false);
    }

    // Zur Zeile scrollen.
    final rowKey = _rowKeys[matchedItem.id];
    if (rowKey != null && rowKey.currentContext != null) {
      await Scrollable.ensureVisible(
        rowKey.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
    if (!mounted) return;

    // Menge um 1 erhöhen (Scan = ein weiteres Stück gezählt).
    final current = _localCounted[matchedItem.id] ?? 0;
    _saveCounted(matchedItem, current + 1);

    AppFeedback.successOn(
      messenger,
      l10n.stocktakeScanIncrement(mp.name),
      rootContext: context,
    );
  }

  // ── Inventur abschließen ───────────────────────────────────────────────────

  Future<void> _closeStocktake() async {
    final l10n = AppLocalizations.of(context);
    // Capture messenger before async gap (Dialog-Context-Pattern).
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<StockProvider>(context, listen: false);
    final items = _items;
    if (items == null) return;

    final ok = await showConfirmDialog(
      context: context,
      title: l10n.stocktakeCloseConfirm,
      message: l10n.stocktakeCloseConfirmHint,
      confirmLabel: l10n.stocktakeCloseAction,
      isDestructive: false,
    );
    if (!ok || !mounted) return;

    try {
      // Aktualisierte Items mit lokal gepufferten Werten übergeben.
      final updatedItems = items.map((item) {
        final local = _localCounted[item.id];
        if (local != null && local != item.countedQty) {
          return item.copyWith(countedQty: local);
        }
        return item;
      }).toList();

      final closed = await provider.closeStocktake(_stocktake, updatedItems);
      if (mounted) {
        setState(() {
          _stocktake = closed;
          _showDiffReport = true;
        });
        AppFeedback.successOn(
          messenger,
          l10n.stocktakeCloseSuccess,
          rootContext: context,
        );
      }
    } catch (e) {
      debugPrint('closeStocktake failed: $e');
      if (mounted) {
        AppFeedback.errorOn(
          messenger,
          l10n.stocktakeCloseError,
          rootContext: context,
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canEdit = context
            .watch<ActiveWorkspaceProvider>()
            .role
            ?.canEdit ??
        false;
    final isClosed = _stocktake.status == StocktakeStatus.closed ||
        _stocktake.status == StocktakeStatus.cancelled;
    final isReadOnly = !canEdit || isClosed;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _stocktake.title ?? l10n.stocktakeTitle,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Barcode-Scan (nur wenn Zählung läuft)
          if (!isReadOnly && _items != null && _items!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: l10n.stocktakeScanBarcode,
              onPressed: () => _scanBarcode(context),
            ),
        ],
      ),
      body: SafeArea(
        child: _loadingItems
            ? const Center(child: CircularProgressIndicator())
            : _itemsError != null
                ? _ErrorBody(
                    message: l10n.stocktakeLoadError,
                    onRetry: _loadItems,
                  )
                : _buildBody(context, l10n, isReadOnly, isClosed),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    bool isReadOnly,
    bool isClosed,
  ) {
    final items = _items ?? const <StocktakeItem>[];
    final displayItems = _filterUncounted
        ? items.where((i) {
            final local = _localCounted[i.id];
            final counted = local ?? i.countedQty;
            return counted == null;
          }).toList()
        : items;

    final countedCount = items.where((i) {
      final local = _localCounted[i.id];
      return local != null || i.isCounted;
    }).length;
    final total = items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        _ProgressHeader(
          stocktake: _stocktake,
          counted: countedCount,
          total: total,
          filterUncounted: _filterUncounted,
          onFilterChanged: (val) => setState(() => _filterUncounted = val),
        ),

        // ── Differenz-Report (nach Abschluss) ─────────────────────────────
        if (_showDiffReport || isClosed) ...[
          _DiffReportSection(
            items: items,
            localCounted: _localCounted,
            products: context.read<CatalogProvider>().products,
          ),
          const Divider(height: 1),
        ],

        // ── Positions-Liste ───────────────────────────────────────────────
        Expanded(
          child: displayItems.isEmpty
              ? Center(
                  child: Text(
                    _filterUncounted
                        ? l10n.stocktakeAllCounted
                        : l10n.stocktakeNoItems,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: displayItems.length,
                  itemBuilder: (context, i) {
                    final item = displayItems[i];
                    final product = context
                        .read<CatalogProvider>()
                        .products
                        .where((p) => p.id == item.productId)
                        .firstOrNull;
                    return _CountRow(
                      key: _rowKeys[item.id],
                      item: item,
                      product: product,
                      localCounted: _localCounted[item.id],
                      isSaving: _saving[item.id] ?? false,
                      saveError: _saveErrors[item.id],
                      isReadOnly: isReadOnly,
                      onChanged: isReadOnly
                          ? null
                          : (qty) => _saveCounted(item, qty),
                    );
                  },
                ),
        ),

        // ── Abschließen-Button ────────────────────────────────────────────
        if (!isReadOnly && !isClosed)
          _CloseButton(
            onPressed: _closeStocktake,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress header
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final Stocktake stocktake;
  final int counted;
  final int total;
  final bool filterUncounted;
  final ValueChanged<bool> onFilterChanged;

  const _ProgressHeader({
    required this.stocktake,
    required this.counted,
    required this.total,
    required this.filterUncounted,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = total > 0 ? counted / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderOf(context), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status-Badge
              StocktakeStatusBadge(status: stocktake.status),
              const SizedBox(width: 12),
              // Fortschritts-Text
              Expanded(
                child: Text(
                  l10n.stocktakeProgress(counted, total),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              // Filter-Toggle
              FilterChip(
                key: const Key('stocktakeFilterUncounted'),
                label: Text(l10n.stocktakeFilterUncounted),
                selected: filterUncounted,
                onSelected: onFilterChanged,
                labelStyle: const TextStyle(fontSize: 12),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fortschritts-Balken
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.bgSubtleOf(context),
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Count row (Zähl-Zeile)
// ─────────────────────────────────────────────────────────────────────────────

class _CountRow extends StatefulWidget {
  final StocktakeItem item;
  final Product? product;
  final int? localCounted;
  final bool isSaving;
  final String? saveError;
  final bool isReadOnly;
  final ValueChanged<int>? onChanged;

  const _CountRow({
    super.key,
    required this.item,
    required this.product,
    required this.localCounted,
    required this.isSaving,
    required this.saveError,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<_CountRow> createState() => _CountRowState();
}

class _CountRowState extends State<_CountRow> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    final value = widget.localCounted ?? widget.item.countedQty ?? widget.item.expectedQty;
    _controller = TextEditingController(text: value.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
      if (!_focusNode.hasFocus) {
        _submit();
      }
    });
  }

  @override
  void didUpdateWidget(_CountRow old) {
    super.didUpdateWidget(old);
    if (!_hasFocus) {
      final newVal = widget.localCounted ?? widget.item.countedQty ?? widget.item.expectedQty;
      _controller.text = newVal.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_controller.text.trim());
    if (qty != null && qty >= 0) {
      widget.onChanged?.call(qty);
    }
  }

  void _decrement() {
    final current = int.tryParse(_controller.text.trim()) ?? 0;
    if (current > 0) {
      final next = current - 1;
      _controller.text = next.toString();
      widget.onChanged?.call(next);
    }
  }

  void _increment() {
    final current = int.tryParse(_controller.text.trim()) ?? 0;
    final next = current + 1;
    _controller.text = next.toString();
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final productName = widget.product?.name ??
        widget.item.productId.substring(0, 8);
    final hasError = widget.saveError != null;

    return Container(
      key: widget.key,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderOf(context), width: 1),
        ),
        color: hasError
            ? AppTheme.dangerBgOf(context)
            : AppTheme.bgSurfaceOf(context),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Produkt-Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.stocktakeExpected}: ${widget.item.expectedQty}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.saveError!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.dangerTextOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Touch-Stepper + Eingabefeld
            if (widget.isReadOnly)
              _ReadOnlyCount(
                item: widget.item,
                localCounted: widget.localCounted,
              )
            else
              _TouchStepper(
                itemId: widget.item.id,
                controller: _controller,
                focusNode: _focusNode,
                isSaving: widget.isSaving,
                onDecrement: _decrement,
                onIncrement: _increment,
                onSubmit: _submit,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyCount extends StatelessWidget {
  final StocktakeItem item;
  final int? localCounted;

  const _ReadOnlyCount({required this.item, required this.localCounted});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counted = localCounted ?? item.countedQty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${l10n.stocktakeCounted}: ${counted ?? "-"}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        if (counted != null) ...[
          const SizedBox(height: 2),
          _DiffLabel(difference: counted - item.expectedQty),
        ],
      ],
    );
  }
}

class _TouchStepper extends StatelessWidget {
  final String itemId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSaving;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onSubmit;

  const _TouchStepper({
    required this.itemId,
    required this.controller,
    required this.focusNode,
    required this.isSaving,
    required this.onDecrement,
    required this.onIncrement,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus-Button (48×48)
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.remove, size: 20),
            onPressed: onDecrement,
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.textPrimaryOf(context),
              backgroundColor: AppTheme.bgSubtleOf(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // Textfeld (48 dp breit)
        SizedBox(
          width: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TextFormField(
                key: Key('stocktakeCountField-$itemId'),
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                ),
                onFieldSubmitted: (_) => onSubmit(),
              ),
              if (isSaving)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgSubtleOf(context).withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(
                      width: 60,
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Plus-Button (48×48)
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: onIncrement,
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Differenz-Report
// ─────────────────────────────────────────────────────────────────────────────

class _DiffReportSection extends StatelessWidget {
  final List<StocktakeItem> items;
  final Map<String, int> localCounted;
  final List<Product> products;

  const _DiffReportSection({
    required this.items,
    required this.localCounted,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diffItems = items.where((item) {
      final counted = localCounted[item.id] ?? item.countedQty;
      if (counted == null) return false;
      return counted != item.expectedQty;
    }).toList();

    return Container(
      color: AppTheme.bgSubtleOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.stocktakeDiffReportTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          if (diffItems.isEmpty)
            Text(
              l10n.stocktakeDiffReportNoDiff,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMutedOf(context),
              ),
            )
          else
            ...diffItems.map((item) {
              final product =
                  products.where((p) => p.id == item.productId).firstOrNull;
              final counted = localCounted[item.id] ?? item.countedQty ?? 0;
              final diff = counted - item.expectedQty;
              return _DiffCard(
                productName: product?.name ??
                    item.productId.substring(0, 8),
                expected: item.expectedQty,
                counted: counted,
                difference: diff,
              );
            }),
        ],
      ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  final String productName;
  final int expected;
  final int counted;
  final int difference;

  const _DiffCard({
    required this.productName,
    required this.expected,
    required this.counted,
    required this.difference,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _KvChip(
                  label: l10n.stocktakeExpected,
                  value: expected.toString(),
                  context: context,
                ),
                const SizedBox(width: 8),
                _KvChip(
                  label: l10n.stocktakeCounted,
                  value: counted.toString(),
                  context: context,
                ),
                const SizedBox(width: 8),
                _DiffLabel(difference: difference),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KvChip extends StatelessWidget {
  final String label;
  final String value;
  final BuildContext context;

  const _KvChip({
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textMutedOf(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _DiffLabel extends StatelessWidget {
  final int difference;

  const _DiffLabel({required this.difference});

  @override
  Widget build(BuildContext context) {
    final isPositive = difference > 0;
    final isNeutral = difference == 0;
    final color = isNeutral
        ? AppTheme.textMutedOf(context)
        : isPositive
            ? AppTheme.successTextOf(context)
            : AppTheme.dangerTextOf(context);
    final sign = difference > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isNeutral
            ? AppTheme.bgSubtleOf(context)
            : isPositive
                ? AppTheme.successBgOf(context)
                : AppTheme.dangerBgOf(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$sign$difference',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Close button (sticky bottom)
// ─────────────────────────────────────────────────────────────────────────────

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        border: Border(
          top: BorderSide(color: AppTheme.borderOf(context), width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          key: const Key('stocktakeCloseButton'),
          onPressed: onPressed,
          icon: const Icon(Icons.check_circle_outlined, size: 20),
          label: Text(
            l10n.stocktakeCloseAction,
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error body
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outlined,
              size: 48,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
