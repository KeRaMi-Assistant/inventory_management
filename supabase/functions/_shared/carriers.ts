// Kanonische Carrier-Registry (Paket 2, Audit-Fix "Carrier 3-fach
// inkonsistent modelliert").
//
// EINE Quelle der Wahrheit darüber, welche Carrier es im System gibt und
// was sie können. Konsumenten:
//   * tracking_detection.ts  — CarrierId-Werte müssen hier existieren.
//   * tracking_adapters.ts   — ADAPTERS-Keys müssen pollAdapter=true tragen.
//   * tracking-poll/index.ts — DETECTION_ONLY_CARRIERS wird hieraus abgeleitet.
//   * lib/models/carrier_credential.dart + lib/utils/carrier_links.dart —
//     Dart-Spiegel; Konsistenz wird per deno-Test (carriers_test.ts) gegen
//     die Dart-Quelltexte geprüft (CI läuft mit --allow-read).
//   * Migration 20260610150000: deals.carrier-CHECK = Obermenge dieser Ids.

export interface CarrierInfo {
  id: string
  label: string
  /// Wird von der Mail-Detection erkannt (tracking_detection.ts).
  detection: boolean
  /// Hat einen Live-Status-Poll-Adapter (tracking_adapters.ts ADAPTERS).
  pollAdapter: boolean
  /// Poll-Adapter braucht einen Workspace-API-Key (Settings → Versand).
  requiresApiKey: boolean
  /// In der Credentials-UI freigeschaltet (Dart: enabledCarrierIds).
  uiEnabled: boolean
  /// Öffentliche Tracking-Seite (Deep-Link)? Spiegel von carrier_links.dart.
  publicTrackingPage: boolean
  /// Warum kein Poll / Besonderheiten — für Entwickler:innen.
  note: string
}

export const CARRIERS: ReadonlyArray<CarrierInfo> = [
  {
    id: 'dhl',
    label: 'DHL',
    detection: true,
    pollAdapter: true,
    requiresApiKey: true,
    uiEnabled: true,
    publicTrackingPage: true,
    note: 'Parcel-DE-Tracking-API, 1.000 Queries/Tag (Cap 900), 3 req/s.',
  },
  {
    id: 'dpd',
    label: 'DPD',
    detection: true,
    pollAdapter: true,
    requiresApiKey: true,
    uiEnabled: false,
    publicTrackingPage: true,
    note:
      'COMING FEATURE (2026-06-11): öffentliche Endpoints blocken Server-' +
      'Requests auf TLS-Ebene → Pull unmöglich; der offizielle Tracking ' +
      'Push Service braucht ein DPD-Geschäftskonto (Stakeholder hat keins). ' +
      'Webhook supabase/functions/dpd-push liegt fertig + fail-closed ' +
      'deployt bereit. Bis dahin: Detection + Deep-Link, UI „Bald verfügbar".',
  },
  {
    id: 'ups',
    label: 'UPS',
    detection: true,
    pollAdapter: true,
    requiresApiKey: true,
    uiEnabled: false,
    publicTrackingPage: true,
    note:
      'Detection seit 2026-06-11 (1Z-Format ist weltweit eindeutig, ' +
      'Anchor-gated). Poll-Adapter vorhanden, aber UI gesperrt bis ein ' +
      'OAuth-Key-Flow existiert — bis dahin Deep-Link via Chip.',
  },
  {
    id: 'amazon',
    label: 'Amazon Logistics',
    detection: true,
    pollAdapter: false,
    requiresApiKey: false,
    uiEnabled: false,
    publicTrackingPage: false,
    note: 'Detection-only — keine öffentliche Status-API, kein Deep-Link.',
  },
  {
    id: 'hermes',
    label: 'Hermes',
    detection: true,
    pollAdapter: false,
    requiresApiKey: false,
    uiEnabled: false,
    publicTrackingPage: true,
    note:
      'Detection-only seit 2026-06-11: 14-stellige Nummern NUR mit ' +
      'explizitem Hermes-Kontext (Doppel-Gate wie dpd-14, kollidiert ' +
      'sonst mit DHL/DPD) + myhermes-href. Kein öffentlicher Poll-Kanal; ' +
      'Deep-Link via carrier_links.dart.',
  },
  {
    id: 'gls',
    label: 'GLS',
    detection: true,
    pollAdapter: false,
    requiresApiKey: false,
    uiEnabled: false,
    publicTrackingPage: true,
    note:
      'Detection-only — offener rstt001-Endpoint wurde 2026 hinter ' +
      'API-Registrierung gelegt (verifiziert 2026-06-10). Deep-Link auf ' +
      'gls-group.eu Paketverfolgung; Status bleibt mail-getrieben.',
  },
]

/// Carrier, die NIE gepollt werden (tracking-poll Short-Circuit).
export const DETECTION_ONLY_CARRIERS: ReadonlySet<string> = new Set(
  CARRIERS.filter((c) => c.detection && !c.pollAdapter).map((c) => c.id),
)

export function carrierById(id: string | null | undefined): CarrierInfo | null {
  if (!id) return null
  return CARRIERS.find((c) => c.id === id.toLowerCase()) ?? null
}
