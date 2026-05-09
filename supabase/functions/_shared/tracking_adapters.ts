// Carrier-Tracking-Adapter für die Edge Function `tracking-poll`.
//
// Jeder Adapter implementiert dasselbe Interface:
//   * `id`    – stabiler Schlüssel (`'dhl' | 'dpd' | 'ups'`); muss zur
//               carrier_id-Spalte in workspace_carrier_credentials passen.
//   * `parseResponse(json)` – nimmt die rohe API-Response, gibt `ParsedTracking`
//                             oder `null` (= unbekannt/nicht parsbar). Reine
//                             Funktion, kein I/O — leicht testbar.
//   * `fetchStatus(tracking, apiKey)` – führt den HTTP-Call aus; intern erst
//                                       `_doFetch`, dann `parseResponse`. Kann
//                                       in Tests via `_doFetch`-Override gegen
//                                       Mocks gestellt werden.
//
// Alle Adapter arbeiten OFFLINE-fähig: wenn der Tracking-Number im Response
// kein Status zugeordnet werden kann, geben sie `null` zurück. Die Edge
// Function darf null wertelos behandeln (= kein Update).

export type TrackingDeliveryStatus =
  | 'in_transit'
  | 'delivered'
  | 'exception'
  | 'unknown'

export interface ParsedTracking {
  /// Carrier-übergreifend normalisierter Status. `delivered` ist der einzige
  /// Wert, der das Deal-Status-Update auslöst.
  status: TrackingDeliveryStatus
  /// ISO-8601-Zeitpunkt der Zustellung. Nur gefüllt, wenn `status='delivered'`.
  deliveredAt?: string
  /// Zuletzt bekannte Aktivität (z.B. "Zugestellt", "In Zustellung"). Wird in
  /// activity_log mitgegeben und im Deal-Detail angezeigt.
  lastEvent?: string
  /// Originaler Carrier-Statuscode für Debug-Zwecke (Logs).
  rawStatusCode?: string
}

export interface TrackingAdapter {
  id: 'dhl' | 'dpd' | 'ups'
  label: string
  fetchStatus(tracking: string, apiKey: string): Promise<ParsedTracking | null>
  parseResponse(payload: unknown): ParsedTracking | null
}

// Hilfen, die mehrere Adapter teilen.
const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v)

const pickString = (
  obj: Record<string, unknown> | null | undefined,
  ...keys: string[]
): string | undefined => {
  if (!obj) return undefined
  for (const k of keys) {
    const v = obj[k]
    if (typeof v === 'string' && v.length > 0) return v
  }
  return undefined
}

const toIso = (raw: string | undefined): string | undefined => {
  if (!raw) return undefined
  const d = new Date(raw)
  if (isNaN(d.getTime())) return undefined
  return d.toISOString()
}

// ── DHL ──────────────────────────────────────────────────────────────────
// Endpoint: `https://api-eu.dhl.com/track/shipments?trackingNumber=...`
// Auth   : `DHL-API-Key: <apiKey>` Header. Liefert JSON mit `shipments[]`,
//          jedes Shipment hat `status.statusCode` (z.B. `delivered`,
//          `transit`, `unknown`) und `status.timestamp`.
export const dhlAdapter: TrackingAdapter = {
  id: 'dhl',
  label: 'DHL',

  async fetchStatus(tracking, apiKey) {
    const url = new URL('https://api-eu.dhl.com/track/shipments')
    url.searchParams.set('trackingNumber', tracking)
    const res = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        'DHL-API-Key': apiKey,
        'Accept': 'application/json',
      },
    })
    if (!res.ok) return null
    const json = await res.json().catch(() => null)
    return this.parseResponse(json)
  },

  parseResponse(payload) {
    if (!isObject(payload)) return null
    const shipments = payload.shipments
    if (!Array.isArray(shipments) || shipments.length === 0) return null
    const shipment = shipments[0]
    if (!isObject(shipment)) return null
    const status = isObject(shipment.status) ? shipment.status : null
    const code = pickString(status, 'statusCode', 'status')?.toLowerCase()
    // `status`-Feld zuerst: bei DHL ist das das kurze, kuratierte Label
    // ("Zugestellt", "In Zustellung"). `description` ist der ausgeschriebene
    // Satz mit kleingeschriebenem Verb — weniger nützlich als Last-Event.
    const description =
      pickString(status, 'status', 'description') ?? undefined
    const timestamp = pickString(status, 'timestamp')

    let normalized: TrackingDeliveryStatus = 'unknown'
    if (code === 'delivered') normalized = 'delivered'
    else if (code === 'transit' || code === 'pre-transit' || code === 'out-for-delivery') {
      normalized = 'in_transit'
    } else if (code === 'failure' || code === 'exception') {
      normalized = 'exception'
    }

    return {
      status: normalized,
      deliveredAt: normalized === 'delivered' ? toIso(timestamp) : undefined,
      lastEvent: description,
      rawStatusCode: code,
    }
  },
}

// ── DPD ──────────────────────────────────────────────────────────────────
// Endpoint: `https://api.dpd.com/v1/track?parcelLabelNumber=...`
// Auth   : `Authorization: Bearer <apiKey>`. Response: `{ parcelLifeCycleData
//          : { statusInfo: [{ status: 'DELIVERED'|'IN_TRANSIT'|..., date,
//          description }] } }`. Wir interessieren uns nur für den
//          letzten Eintrag.
export const dpdAdapter: TrackingAdapter = {
  id: 'dpd',
  label: 'DPD',

  async fetchStatus(tracking, apiKey) {
    const url = new URL('https://api.dpd.com/v1/track')
    url.searchParams.set('parcelLabelNumber', tracking)
    const res = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Accept': 'application/json',
      },
    })
    if (!res.ok) return null
    const json = await res.json().catch(() => null)
    return this.parseResponse(json)
  },

  parseResponse(payload) {
    if (!isObject(payload)) return null
    const lifecycle = isObject(payload.parcelLifeCycleData)
      ? payload.parcelLifeCycleData
      : null
    const statusInfo = lifecycle?.statusInfo
    if (!Array.isArray(statusInfo) || statusInfo.length === 0) return null
    // Letzter Eintrag = aktueller Status.
    const latest = statusInfo[statusInfo.length - 1]
    if (!isObject(latest)) return null
    const code = pickString(latest, 'status', 'statusCode')?.toUpperCase()
    const description = pickString(latest, 'description', 'label')
    const date = pickString(latest, 'date', 'timestamp')

    let normalized: TrackingDeliveryStatus = 'unknown'
    if (code === 'DELIVERED') normalized = 'delivered'
    else if (code === 'IN_TRANSIT' || code === 'OUT_FOR_DELIVERY' || code === 'ACCEPTED') {
      normalized = 'in_transit'
    } else if (code === 'EXCEPTION' || code === 'RETURNED') {
      normalized = 'exception'
    }

    return {
      status: normalized,
      deliveredAt: normalized === 'delivered' ? toIso(date) : undefined,
      lastEvent: description,
      rawStatusCode: code?.toLowerCase(),
    }
  },
}

// ── UPS ──────────────────────────────────────────────────────────────────
// Endpoint: `https://onlinetools.ups.com/api/track/v1/details/<tracking>`
// Auth   : `Authorization: Bearer <apiKey>` (OAuth-Bearer). Response:
//          `{ trackResponse: { shipment: [{ package: [{ currentStatus:
//          { code, description }, deliveryDate: [{ date }] }] }] } }`.
export const upsAdapter: TrackingAdapter = {
  id: 'ups',
  label: 'UPS',

  async fetchStatus(tracking, apiKey) {
    const url = `https://onlinetools.ups.com/api/track/v1/details/${encodeURIComponent(tracking)}`
    const res = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Accept': 'application/json',
        'transId': crypto.randomUUID(),
        'transactionSrc': 'inventory_management',
      },
    })
    if (!res.ok) return null
    const json = await res.json().catch(() => null)
    return this.parseResponse(json)
  },

  parseResponse(payload) {
    if (!isObject(payload)) return null
    const trackResponse = isObject(payload.trackResponse)
      ? payload.trackResponse
      : null
    const shipments = trackResponse?.shipment
    if (!Array.isArray(shipments) || shipments.length === 0) return null
    const shipment = shipments[0]
    if (!isObject(shipment)) return null
    const packages = shipment.package
    if (!Array.isArray(packages) || packages.length === 0) return null
    const pkg = packages[0]
    if (!isObject(pkg)) return null
    const currentStatus = isObject(pkg.currentStatus) ? pkg.currentStatus : null
    const code = pickString(currentStatus, 'code', 'type')?.toUpperCase()
    const description = pickString(currentStatus, 'description', 'simpleDescription')

    let normalized: TrackingDeliveryStatus = 'unknown'
    // UPS-Statuscodes: D=Delivered, I=In-Transit, M=Order Processed,
    // O=Out for Delivery, X=Exception, P=Pickup, RS=Returned to Shipper.
    if (code === 'D' || code === 'DELIVERED') normalized = 'delivered'
    else if (
      code === 'I' || code === 'IN_TRANSIT' || code === 'M' ||
      code === 'O' || code === 'P' || code === 'OUT_FOR_DELIVERY'
    ) {
      normalized = 'in_transit'
    } else if (code === 'X' || code === 'RS' || code === 'EXCEPTION') {
      normalized = 'exception'
    }

    let deliveredAt: string | undefined
    if (normalized === 'delivered') {
      const deliveryDate = Array.isArray(pkg.deliveryDate)
        ? pkg.deliveryDate
        : null
      const first = deliveryDate && deliveryDate.length > 0 && isObject(deliveryDate[0])
        ? deliveryDate[0]
        : null
      const dateStr = pickString(first, 'date')
      // UPS-Format `YYYYMMDD` ohne Trennzeichen → in ISO-Date wandeln.
      if (dateStr && /^\d{8}$/.test(dateStr)) {
        deliveredAt = `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}T00:00:00.000Z`
      } else {
        deliveredAt = toIso(dateStr)
      }
    }

    return {
      status: normalized,
      deliveredAt,
      lastEvent: description,
      rawStatusCode: code?.toLowerCase(),
    }
  },
}

// ── Registry ─────────────────────────────────────────────────────────────
export const ADAPTERS: Record<TrackingAdapter['id'], TrackingAdapter> = {
  dhl: dhlAdapter,
  dpd: dpdAdapter,
  ups: upsAdapter,
}

/// Carrier-Detection: aus einer Tracking-Nummer den passenden Adapter ableiten.
/// Bewusst konservativ — bei Mehrdeutigkeit (z.B. 14-stellige Ziffern) wird
/// DHL bevorzugt (analog zu lib/services/carrier_service.dart).
export function detectAdapter(tracking: string): TrackingAdapter | null {
  const v = tracking.trim().replace(/\s+/g, '').toUpperCase()
  if (!v) return null
  if (/^1Z[0-9A-Z]{16}$/.test(v)) return upsAdapter
  // DPD-Pattern: 14-stellige Zahl, die mit 0500 oder 0599 (Carrier-Prefix)
  // anfängt — sehr eng, falsch-positive Treffer auf DHL sollen vermieden
  // werden. Bei reinem 14-stellig ohne Prefix bleiben wir auf DHL.
  if (/^05\d{12}$/.test(v)) return dpdAdapter
  // DHL: JJD-Prefix, DE-Prefix, 20-stellig, 12-stellig.
  if (/^JJD\d{10,18}$/.test(v)) return dhlAdapter
  if (/^[A-Z]{2}\d{8,14}$/.test(v) && v.startsWith('DE')) return dhlAdapter
  if (/^\d{20,22}$/.test(v)) return dhlAdapter
  if (/^\d{12,14}$/.test(v)) return dhlAdapter
  return null
}
