import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/carrier_service.dart';
import '../utils/url_helper.dart';

/// Kompaktes Chip mit Carrier-Pille + Tracking-Nummer. Tap baut die URL erst
/// im Moment des Klicks und öffnet sie — kein Pre-Computing pro Render.
/// Long-Press öffnet ein Override-Menü, falls die Auto-Erkennung daneben lag
/// (typisch bei 14-stelligen Nummern, die DHL/DPD/Hermes teilen).
///
/// Das Chip nimmt sich in `compact`-Variante die volle Breite des Eltern-
/// Containers; die Tracking-Nummer wird per Ellipsis gekürzt, falls der
/// Platz nicht reicht. Die Wrap-Variante (Karten-Detail) misst sich am
/// Inhalt.
class TrackingChip extends StatelessWidget {
  const TrackingChip({
    super.key,
    required this.tracking,
    this.compact = false,
    this.shopAmazonCountry,
  });

  final String tracking;

  /// `true` rendert die Variante für Tabellenzellen (kein eigener Hintergrund,
  /// dichte Anordnung, füllt die Eltern-Breite). `false` rendert die
  /// Karten-Variante mit Pillen-Hintergrund und Inhalt-Größe.
  final bool compact;

  /// Wenn der Deal einem Amazon-Shop mit eindeutigem Country zugeordnet ist
  /// (z. B. Shop „Amazon" mit Region `'fr'`), liefert der Caller hier das
  /// TLD-Fragment. Der Tap öffnet dann direkt die Bestellliste dieses
  /// Country-Accounts — der Long-Press-Country-Picker wird übersprungen.
  final String? shopAmazonCountry;

  @override
  Widget build(BuildContext context) {
    // Shop-Override: Wenn der Deal einem Amazon-Country-Shop zugeordnet ist
    // (`Amazon-FR`, `Amazon-DE`, …), routen wir IMMER über Amazon — egal
    // wie das Tracking-Format aussieht. Marketplace-IDs wie `DE5435294918`
    // sind zwar DHL-Codes, aber der User will sie aus der Amazon-FR-
    // Bestellhistorie öffnen, nicht aus dem DHL-Tracker. Long-Press
    // erlaubt weiterhin den manuellen Override auf einen anderen Carrier.
    final detected = shopAmazonCountry != null
        ? Carrier.amazon
        : CarrierService.detect(tracking);
    return _ChipBody(
      tracking: tracking,
      detected: detected,
      compact: compact,
      shopAmazonCountry: shopAmazonCountry,
    );
  }
}

class _ChipBody extends StatelessWidget {
  const _ChipBody({
    required this.tracking,
    required this.detected,
    required this.compact,
    required this.shopAmazonCountry,
  });

  final String tracking;
  final Carrier detected;
  final bool compact;
  final String? shopAmazonCountry;

  Future<void> _openWith(
    BuildContext context,
    Carrier carrier, {
    String? amazonCountry,
  }) async {
    final url = CarrierService.urlFor(
      carrier,
      tracking,
      amazonCountry: amazonCountry,
    );
    await openUrlWithFallback(context, url);
  }

  Future<void> _showOverride(BuildContext context, Offset globalPos) async {
    final pos = _menuPosition(context, globalPos);
    if (pos == null) return;
    final picked = await showMenu<_PickAction>(
      context: context,
      position: pos,
      items: [
        PopupMenuItem<_PickAction>(
          enabled: false,
          height: 32,
          child: Text(
            AppLocalizations.of(context).trackingCarrierPickTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMutedOf(context),
            ),
          ),
        ),
        for (final c in Carrier.pickable.where((c) => c != Carrier.amazon))
          PopupMenuItem<_PickAction>(
            value: _CarrierPick(c),
            height: 36,
            child: Row(
              children: [
                _CarrierPill(carrier: c, dense: true),
                const SizedBox(width: 8),
                Text(c.label, style: const TextStyle(fontSize: 13)),
                if (c == detected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check,
                      size: 14, color: AppTheme.textMutedOf(context)),
                ],
              ],
            ),
          ),
        const PopupMenuDivider(),
        // Eintrag, der das Country-Submenü aufklappt. Per Anforderung
        // erscheint hier nur "Amazon" — das Country-Picking passiert erst
        // im zweiten Schritt.
        PopupMenuItem<_PickAction>(
          value: const _AmazonExpand(),
          height: 36,
          child: Row(
            children: [
              const _CarrierPill(carrier: Carrier.amazon, dense: true),
              const SizedBox(width: 8),
              const Text('Amazon', style: TextStyle(fontSize: 13)),
              if (detected == Carrier.amazon) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 14, color: AppTheme.textMutedOf(context)),
              ],
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: 16, color: AppTheme.textMutedOf(context)),
            ],
          ),
        ),
      ],
    );
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case _CarrierPick(:final carrier):
        await _openWith(context, carrier);
      case _AmazonExpand():
        if (!context.mounted) return;
        final country = await _showAmazonCountryPicker(context, globalPos);
        if (country != null && context.mounted) {
          await _openWith(context, Carrier.amazon, amazonCountry: country);
        }
    }
  }

  Future<String?> _showAmazonCountryPicker(
      BuildContext context, Offset globalPos) async {
    final pos = _menuPosition(context, globalPos);
    if (pos == null) return null;
    return showMenu<String>(
      context: context,
      position: pos,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            AppLocalizations.of(context).trackingAmazonCountryTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMutedOf(context),
            ),
          ),
        ),
        for (final entry in amazonCountryOptions.entries)
          PopupMenuItem<String>(
            value: entry.key,
            height: 36,
            child: Row(
              children: [
                const _CarrierPill(carrier: Carrier.amazon, dense: true),
                const SizedBox(width: 8),
                Text(entry.value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  RelativeRect? _menuPosition(BuildContext context, Offset globalPos) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return null;
    return RelativeRect.fromLTRB(
      globalPos.dx,
      globalPos.dy,
      overlay.size.width - globalPos.dx,
      overlay.size.height - globalPos.dy,
    );
  }

  /// Wenn die Tracking-Eingabe selbst eine URL ist, zeigen wir nur den
  /// Hostname + den letzten Pfadabschnitt — die volle URL würde das Chip
  /// sprengen. Sonst die Tracking-ID 1:1.
  String get _displayLabel {
    final raw = tracking.trim();
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      return tracking;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return tracking;
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return host;
    final tail = segs.last;
    return '$host/.../$tail';
  }

  /// Optionales kleines Country-Suffix neben der Pille (z. B. `fr`), wenn
  /// das Tracking eine Amazon-Country-URL ist und der Country bekannt ist.
  String? get _urlCountrySuffix => amazonCountryFromTracking(tracking);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tooltip = detected == Carrier.unknown
        ? l10n.trackingTooltipUnknown
        : l10n.trackingTooltipKnown(detected.label);

    final number = Text(
      _displayLabel,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.accent,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      softWrap: false,
    );

    final urlCountry = _urlCountrySuffix;

    // Wir verzichten bewusst auf LayoutBuilder: DataTable misst seine Cells
    // via Intrinsic-Width, und LayoutBuilder unterstützt das nicht
    // (RenderBox-Layout-Ausnahme). Statt dessen begrenzen wir die
    // Tracking-Nummer in compact-Mode hart auf 160px — der Chip wird so
    // breit wie sein Inhalt und passt in DataCells, deal_table-SizedBox-
    // Wrappern und freie Karten gleichermaßen.
    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CarrierPill(carrier: detected),
        if (urlCountry != null) ...[
          const SizedBox(width: 4),
          _CountrySuffix(country: urlCountry),
        ],
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 160 : 220),
          child: number,
        ),
        const SizedBox(width: 4),
        Icon(Icons.open_in_new,
            size: 11, color: AppTheme.accent.withAlpha(180)),
      ],
    );

    final box = compact
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: inner,
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.warning.withAlpha(60)),
            ),
            child: inner,
          );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onLongPressStart: (d) => _showOverride(context, d.globalPosition),
        onSecondaryTapDown: (d) => _showOverride(context, d.globalPosition),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          // Bei Amazon + Shop-Country direkt zum richtigen Account-Land
          // springen (kein Picker). Sonst Standard-Verhalten via urlFor.
          onTap: () => _openWith(
            context,
            detected,
            amazonCountry:
                detected == Carrier.amazon ? shopAmazonCountry : null,
          ),
          child: box,
        ),
      ),
    );
  }
}

/// Menü-Action für den Long-Press-Override. `_CarrierPick` schaltet auf
/// einen anderen Carrier um. `_AmazonExpand` schließt das aktuelle Menü
/// und öffnet anschließend das Amazon-Country-Submenü — so erfüllt die
/// Liste den UX-Wunsch: erst nur "Amazon", auf Klick die Länder.
sealed class _PickAction {
  const _PickAction();
}

class _CarrierPick extends _PickAction {
  const _CarrierPick(this.carrier);
  final Carrier carrier;
}

class _AmazonExpand extends _PickAction {
  const _AmazonExpand();
}

class _CarrierPill extends StatelessWidget {
  const _CarrierPill({required this.carrier, this.dense = false});

  final Carrier carrier;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = _readableForeground(carrier.color);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 4 : 5, vertical: dense ? 1 : 2),
      decoration: BoxDecoration(
        color: carrier.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        carrier.short,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Schwarz/weiß je nach Helligkeit der Marken­farbe — DHL-Gelb braucht
  /// schwarze Schrift, UPS-Braun und DPD-Lila weiße.
  Color _readableForeground(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.55 ? const Color(0xFF1F2937) : Colors.white;
  }
}

/// Kleines Country-TLD-Pill neben der Carrier-Pille, wenn das Tracking eine
/// Amazon-Country-URL ist (z. B. `fr` für `amazon.fr/...`). Rein visueller
/// Hinweis — das Tap-Verhalten passiert über die Original-URL.
class _CountrySuffix extends StatelessWidget {
  const _CountrySuffix({required this.country});

  final String country;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        country,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Color(0xFFD97706),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
