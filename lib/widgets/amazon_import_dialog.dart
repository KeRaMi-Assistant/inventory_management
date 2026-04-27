import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../services/amazon_csv_service.dart';

class AmazonImportDialog extends StatefulWidget {
  const AmazonImportDialog({super.key});

  @override
  State<AmazonImportDialog> createState() => _AmazonImportDialogState();
}

class _AmazonImportDialogState extends State<AmazonImportDialog> {
  // Phases: 'idle' | 'loading' | 'preview' | 'importing' | 'done' | 'error'
  String _phase = 'idle';
  String _errorMsg = '';
  AmazonImportResult? _result;
  String _selectedShop = 'Amazon-DE';
  int _importedCount = 0;

  final _dateFmt = DateFormat('dd.MM.yyyy');
  final _priceFmt = NumberFormat('#,##0.00', 'de_DE');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Flexible(child: _buildBody(context)),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                color: Color(0xFFEA580C), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amazon Bestellbericht importieren',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Amazon Business → Berichte → Bestellberichte → CSV exportieren',
                  style:
                      TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context) {
    return switch (_phase) {
      'idle' => _buildIdle(context),
      'loading' => _buildLoading(),
      'preview' => _buildPreview(context),
      'importing' => _buildLoading(label: 'Wird importiert…'),
      'done' => _buildDone(),
      'error' => _buildError(),
      _ => const SizedBox(),
    };
  }

  Widget _buildIdle(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final shops = provider.shops.where((s) => s.active).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // How-to card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text(
                      'So exportierst du den Bestellbericht',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0369A1)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _Step(n: '1', text: 'Öffne business.amazon.de'),
                _Step(n: '2', text: 'Gehe zu Berichte → Bestellberichte'),
                _Step(
                    n: '3',
                    text:
                        'Wähle den gewünschten Zeitraum und klicke auf „Bericht anfordern"'),
                _Step(
                    n: '4',
                    text:
                        'Lade die fertige CSV-Datei herunter und wähle sie hier aus'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Shop selection
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IMPORTIERTEN EINTRÄGEN ZUWEISEN',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.6),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Welchem Shop sollen die Amazon-Bestellungen zugeordnet werden?',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _selectedShop,
                  decoration: const InputDecoration(labelText: 'Shop'),
                  items: shops
                      .map((s) => DropdownMenuItem(
                          value: s.name, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedShop = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Duplicate info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bereits importierte Bestellungen werden anhand der Bestellnummer erkannt und automatisch übersprungen – keine Duplikate.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading({String label = 'Datei wird gelesen…'}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 20),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final result = _result!;
    final newItems = result.newItems;
    final skipped = result.skippedKeys;

    return Column(
      children: [
        // Summary strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              _statBadge('${newItems.length}', 'Neu', const Color(0xFF2563EB),
                  const Color(0xFFEFF6FF)),
              const SizedBox(width: 12),
              _statBadge('${skipped.length}', 'Doppelt (wird übersprungen)',
                  const Color(0xFF64748B), const Color(0xFFF1F5F9)),
              const SizedBox(width: 12),
              if (result.cancelledRows > 0) ...[
                _statBadge('${result.cancelledRows}', 'Storniert',
                    const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                const SizedBox(width: 12),
              ],
              _statBadge('${result.totalDataRows}', 'Gesamt',
                  const Color(0xFF475569), const Color(0xFFF1F5F9)),
            ],
          ),
        ),
        if (newItems.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: Color(0xFF16A34A)),
                  SizedBox(height: 12),
                  Text('Alle Einträge bereits vorhanden.',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF334155))),
                  SizedBox(height: 4),
                  Text(
                    'Keine neuen Bestellungen zum Importieren.',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'NEUE EINTRÄGE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6),
                ),
                const Spacer(),
                Text(
                  'Shop: $_selectedShop',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          // Preview table header
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: const Row(
              children: [
                SizedBox(
                    width: 160,
                    child: _TH('Bestellnummer')),
                SizedBox(width: 10),
                Expanded(child: _TH('Produkt')),
                SizedBox(width: 10),
                SizedBox(width: 44, child: _TH('Anz.')),
                SizedBox(width: 10),
                SizedBox(width: 90, child: _TH('EK Brutto')),
                SizedBox(width: 10),
                SizedBox(width: 88, child: _TH('Datum')),
              ],
            ),
          ),
          // Preview rows
          Expanded(
            child: ListView.builder(
              itemCount: newItems.length,
              itemBuilder: (context, i) {
                final item = newItems[i];
                final isEven = i.isEven;
                return Container(
                  color: isEven ? Colors.white : const Color(0xFFFAFBFD),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text(
                          item.orderNumber,
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.asin != null)
                              Text(
                                'ASIN: ${item.asin}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${item.quantity}×',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF475569)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: Text(
                          item.ekBrutto != null
                              ? '€ ${_priceFmt.format(item.ekBrutto)}'
                              : '–',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 88,
                        child: Text(
                          _dateFmt.format(item.orderDate),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 40, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 20),
            Text(
              '$_importedCount Einträge importiert',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Die Einträge sind jetzt in der Tabelle sichtbar.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fehler beim Lesen der Datei',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C))),
                      const SizedBox(height: 6),
                      Text(_errorMsg,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF7F1D1D))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    final provider = context.read<InventoryProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: switch (_phase) {
          'idle' => [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _pickFile(context),
                icon: const Icon(Icons.folder_open_outlined, size: 16),
                label: const Text('Datei auswählen'),
              ),
            ],
          'preview' => [
              TextButton(
                onPressed: () => setState(() => _phase = 'idle'),
                child: const Text('← Zurück'),
              ),
              const SizedBox(width: 10),
              if (_result!.newItems.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _doImport(provider),
                  icon: const Icon(Icons.download_done_outlined, size: 16),
                  label:
                      Text('${_result!.newItems.length} Einträge importieren'),
                ),
              if (_result!.newItems.isEmpty)
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Schließen'),
                ),
            ],
          'done' => [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fertig'),
              ),
            ],
          'error' => [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _pickFile(context),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Erneut versuchen'),
              ),
            ],
          _ => [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
            ],
        },
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickFile(BuildContext context) async {
    final provider = context.read<InventoryProvider>();
    setState(() => _phase = 'loading');

    final existingIds = provider.existingAmazonOrderIds;
    final startId = provider.nextDealId;

    final (result, err) = await AmazonCsvService.pickAndParse(
      existingIds,
      startId,
    );

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _phase = 'error';
        _errorMsg = err;
      });
    } else if (result == null) {
      setState(() => _phase = 'idle'); // user cancelled
    } else {
      setState(() {
        _result = result;
        _phase = 'preview';
      });
    }
  }

  Future<void> _doImport(InventoryProvider provider) async {
    if (_result == null) return;
    setState(() => _phase = 'importing');

    int id = provider.nextDealId;
    final deals = _result!.newItems
        .map((item) => item.toDeal(id: id++, shopName: _selectedShop))
        .toList();

    await provider.importDeals(deals);
    if (!mounted) return;

    setState(() {
      _importedCount = deals.length;
      _phase = 'done';
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _statBadge(String value, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: fg)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, color: fg.withAlpha(180))),
        ],
      ),
    );
  }
}

// ── Small helper widgets ─────────────────────────────────────────────────────

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(n,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String label;
  const _TH(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      );
}
