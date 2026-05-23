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

/// HTTP-Klassifikation eines Probe-Calls. Nutzt der Validation-Wrapper,
/// um zwischen "Tracking-Nr unbekannt" (4xx ausser 401/403/429), "Auth-
/// Problem" (401/403), "Rate-Limit" (429), "Server-Fehler" (5xx) und
/// Netzwerk-Fehler zu unterscheiden.
export type ProbeOutcome =
  | { kind: 'hit'; parsed: ParsedTracking }
  | { kind: 'miss' }            // 4xx (404, 400, 422 etc.) → invalid
  | { kind: 'auth_error' }      // 401/403 → Key/Permission-Problem, unknown
  | { kind: 'rate_limited' }    // 429 → unknown, kurze TTL
  | { kind: 'server_error' }    // 5xx → unknown, kurze TTL
  | { kind: 'network_error'; message: string }

export interface TrackingAdapter {
  id: 'dhl' | 'dpd' | 'ups'
  label: string
  fetchStatus(tracking: string, apiKey: string): Promise<ParsedTracking | null>
  /// Erweiterter Probe-Call mit HTTP-Klassifikation. Default-Impl wrappt
  /// `fetchStatus` (rueckwaertskompat), DHL-Adapter ueberschreibt mit
  /// echter Status-Differenzierung.
  probeStatus?(tracking: string, apiKey: string): Promise<ProbeOutcome>
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
// Endpoint: `https://api-eu.dhl.com/parcel/de/tracking/v0/shipments?trackingNumber=...`
// Auth    : `DHL-API-Key: <apiKey>` Header.
//
// Hintergrund 2026-05-22: Die "Shipment Tracking – Unified" API
// (`/track/shipments`) wurde für unsere App-Registrierung revoked. Stattdessen
// hat die App die "Parcel DE Tracking (Post & Parcel Germany)" API
// freigeschaltet (10 000 000 calls/day vs. 250/day bei Unified). Wir migrieren
// deshalb auf `/parcel/de/tracking/v0/shipments`.
//
// Die Parcel-DE-Tracking-API spricht XML als Standard, kann aber via
// `Accept: application/json` JSON zurückgeben. Field-Namen bleiben hyphenated
// (`piece-code`, `status-timestamp`, `delivery-event-flag`, `pieceshipment`).
// Wir parsen defensiv beide Schemas:
//   * Variante A (Unified-style, falls die JSON-Variante darauf gemappt wird):
//     `{ shipments: [{ status: { statusCode, status, description, timestamp } }] }`.
//   * Variante B (Parcel-DE-XML-to-JSON):
//     `{ pieceshipmentlist: { pieceshipment: [{ piece-code, status,
//       status-timestamp, delivery-event-flag, pieceeventlist:{ pieceevent:[...] } }] } }`.
// Beide Pfade werden in `parseResponse` probiert. Bestehende Unified-Tests
// bleiben dadurch grün; neue Parcel-DE-Samples werden ebenfalls erkannt.
export const dhlAdapter: TrackingAdapter = {
  id: 'dhl',
  label: 'DHL',

  async fetchStatus(tracking, apiKey) {
    const outcome = await this.probeStatus!(tracking, apiKey)
    return outcome.kind === 'hit' ? outcome.parsed : null
  },

  /// Probe mit HTTP-Status-Differenzierung. Macht den Unterschied zwischen
  /// "DHL kennt die Nummer nicht" (404 → invalid, 30d Cache) und "DHL
  /// akzeptiert den Key nicht" (401/403 → auth_error, kurze TTL +
  /// last_error auf workspace_carrier_credentials).
  ///
  /// Strategie 2026-05-23: **Parcel-DE-Endpoint only**. Die "Shipment
  /// Tracking - Unified" API ist für unsere App-Registrierung revoked
  /// (siehe DHL-Developer-Portal-Screenshot vom 2026-05-22 — App-Status
  /// "mixed", Unified ist "deaktiviert", Parcel-DE ist "aktiviert" mit
  /// 10M/Tag). Ein Unified-Fallback bei 401/403 würde nur 5s-SPIKE-Arrest-
  /// Wartezeit verschwenden ohne Aussicht auf Erfolg. Falls Parcel-DE
  /// 401 zurückgibt, ist entweder der API-Key falsch (Stakeholder muss
  /// im Portal nachschauen) oder die App-Subscription nicht durch — wir
  /// loggen `body_snippet` damit das im Edge-Function-Log sichtbar ist.
  async probeStatus(tracking, apiKey): Promise<ProbeOutcome> {
    return await _probeDhlEndpoint(
      'https://api-eu.dhl.com/parcel/de/tracking/v0/shipments',
      tracking,
      apiKey,
      'parcel-de',
    )
  },

  parseResponse(payload) {
    // String → XML-Pfad (Parcel-DE-Public-Query liefert XML).
    if (typeof payload === 'string') {
      return parseDhlAnyResponse(payload)
    }
    if (!isObject(payload)) return null

    // Variante A — Unified-style JSON: `{ shipments: [{ status: {...} }] }`.
    const unified = parseDhlUnified(payload)
    if (unified) return unified

    // Variante B — Parcel-DE-style JSON (XML-to-JSON):
    //   `{ pieceshipmentlist: { pieceshipment: [...] } }`.
    const parcelDe = parseDhlParcelDe(payload)
    if (parcelDe) return parcelDe

    return null
  },
}

/// Innerer Helper: Parcel-DE-Tracking-Endpoint mit XML-Public-Query
/// probieren. Logs den HTTP-Status + Body-Snippet bei Fehlern (Edge-
/// Function-Logs), damit der Stakeholder bei „Polling klappt nicht"-
/// Reports direkt im Supabase-Log nachschauen kann.
///
/// **Auth-Setup laut DHL-Doku (2026-05-23):**
/// Die Parcel-DE-Tracking-API erwartet:
///   1. `DHL-API-Key`-Header mit dem App-Consumer-Key (App-Gateway-Auth).
///   2. Einen **XML-Payload als Query-String** unter dem Parameter `xml=`.
///      Wir nutzen die **Public Query** (`request="get-status-for-public-user"`),
///      die KEIN DHL-Geschäftskunden-Login (appname/password) erfordert —
///      gleiche Daten wie das öffentliche Tracking auf dhl.de.
async function _probeDhlEndpoint(
  baseUrl: string,
  tracking: string,
  apiKey: string,
  variant: 'parcel-de' | 'unified',
): Promise<ProbeOutcome> {
  const url = new URL(baseUrl)
  if (variant === 'parcel-de') {
    // XML-Public-Query als ?xml=... — DHL erwartet das so für die
    // Parcel-DE-Tracking-API. `appname=""` + `password=""` reichen,
    // weil `request="get-status-for-public-user"` keine Business-
    // Credentials braucht.
    const xmlPayload =
      `<?xml version="1.0" encoding="UTF-8"?>` +
      `<data appname="" password="" ` +
      `request="get-status-for-public-user" ` +
      `language-code="de" ` +
      `piece-code="${escapeXml(tracking)}"/>`
    url.searchParams.set('xml', xmlPayload)
  } else {
    // Unified/Legacy-Pfad: einfacher trackingNumber-Query (JSON-Response).
    url.searchParams.set('trackingNumber', tracking)
  }

  let res: Response
  try {
    res = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        'DHL-API-Key': apiKey,
        // Parcel-DE liefert XML, Unified liefert JSON. Beides akzeptieren.
        'Accept': 'application/json, application/xml;q=0.9, text/xml;q=0.9',
      },
    })
  } catch (e) {
    const msg = (e as Error).message ?? 'fetch failed'
    // deno-lint-ignore no-console
    console.warn(JSON.stringify({
      event: 'dhl_probe_network_error',
      variant,
      tracking_redacted: redactTracking(tracking),
      message: msg.slice(0, 200),
    }))
    return { kind: 'network_error', message: msg }
  }

  if (res.status === 200) {
    const text = await res.text().catch(() => '')
    // Erst JSON probieren, dann XML.
    const parsed = parseDhlAnyResponse(text)
    if (parsed) return { kind: 'hit', parsed }
    // 200 OK aber Body unparsbar / leer → DHL hat Nummer akzeptiert
    // aber kein Shipment-Objekt geliefert. Klassifizieren als miss.
    return { kind: 'miss' }
  }

  // Bei Fehler-Status: kompakten Body-Snippet ins Log schreiben, damit
  // wir beim Debug sehen, was die API moniert (z.B. „App not subscribed",
  // „API key revoked", „Invalid tracking format").
  let bodySnippet: string | null = null
  try {
    const text = await res.text()
    bodySnippet = text.slice(0, 300)
  } catch {
    bodySnippet = null
  }
  // deno-lint-ignore no-console
  console.warn(JSON.stringify({
    event: 'dhl_probe_error',
    variant,
    status: res.status,
    tracking_redacted: redactTracking(tracking),
    body_snippet: bodySnippet,
  }))

  if (res.status === 401 || res.status === 403) return { kind: 'auth_error' }
  if (res.status === 429) return { kind: 'rate_limited' }
  if (res.status >= 500) return { kind: 'server_error' }
  // 4xx (404, 400, 422, ...): Tracking-Nr ist DHL nicht bekannt.
  return { kind: 'miss' }
}

/// XML-Escape für Tracking-Nummern (defensiv — Trackings sind eigentlich
/// `[A-Z0-9]+`, aber `<>&"'` werden trotzdem escapt um XML-Injection
/// vorzubeugen).
function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

/// Versucht JSON, dann XML. Gibt ParsedTracking zurück oder null.
function parseDhlAnyResponse(text: string): ParsedTracking | null {
  if (!text || text.length === 0) return null
  // 1) JSON probieren.
  try {
    const json = JSON.parse(text)
    const fromJson = parseDhlResponseUnion(json)
    if (fromJson) return fromJson
  } catch {
    // not JSON — try XML next.
  }
  // 2) XML — Parcel-DE-Format heuristisch parsen (kein xml-dom Import).
  return parseDhlParcelDeXml(text)
}

/// Aus DHL-Tracking-Nr letzte 4 Zeichen behalten, Rest mit `*` maskieren.
/// Verhindert PII-Log-Leak (Tracking-Nummern dürfen nicht im Klartext im
/// Log liegen — siehe CLAUDE.md §Sicherheit).
function redactTracking(value: string): string {
  if (value.length <= 4) return '*'.repeat(value.length)
  return '*'.repeat(value.length - 4) + value.slice(-4)
}

/// Vereinigt parseDhlUnified + parseDhlParcelDe. Wird vom inneren Probe
/// und vom externen `dhlAdapter.parseResponse` benutzt.
function parseDhlResponseUnion(payload: unknown): ParsedTracking | null {
  if (!isObject(payload)) return null
  const unified = parseDhlUnified(payload)
  if (unified) return unified
  const parcelDe = parseDhlParcelDe(payload)
  if (parcelDe) return parcelDe
  return null
}

/// Parser für die XML-Response der Parcel-DE-Tracking-API.
///
/// Erwartetes Format (Public Query):
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <data name="pieceshipmentlist" request-id="..." code="0">
///   <data name="pieceshipment" error-status="0" piece-id="..."
///         piece-code="00340..." delivery-event-flag="1"
///         status="Zugestellt" status-timestamp="2026-05-22T10:30:00">
///     <data name="pieceeventlist" piece-id="...">
///       <data name="pieceevent" event-timestamp="2026-05-22T10:30:00"
///             event-status="Zugestellt" event-text="Zugestellt"
///             standard-event-code="ZU"/>
///       <!-- ... mehr Events ... -->
///     </data>
///   </data>
/// </data>
/// ```
///
/// Wir parsen heuristisch über Regex — robuster als XML-DOM weil DHL
/// die Attribute teils einzeilig, teils mehrzeilig schickt. Keine
/// External-DOM-Library nötig.
function parseDhlParcelDeXml(xml: string): ParsedTracking | null {
  // Schnelle Sanity-Checks: enthält das Response überhaupt
  // pieceshipment/pieceevent? Wenn nicht, return null.
  if (!xml.includes('pieceshipment') && !xml.includes('pieceevent')) {
    return null
  }

  // Top-Level pieceshipment-Tag: nimm das ERSTE Vorkommen.
  // Pattern: <data name="pieceshipment" ...attr="value"... > oder <... />
  const shipmentMatch = xml.match(
    /<data\s+name="pieceshipment"\s+([^>]*?)\/?>/i,
  )
  const shipmentAttrs = shipmentMatch ? parseXmlAttrs(shipmentMatch[1]) : {}

  // Alle pieceevent-Tags collecten (kann mehrere geben).
  const eventTags = xml.match(/<data\s+name="pieceevent"\s+[^>]*?\/?>/gi) ?? []
  const events: Record<string, string>[] = []
  for (const tag of eventTags) {
    const attrMatch = tag.match(/<data\s+name="pieceevent"\s+([^>]*?)\/?>/i)
    if (attrMatch) events.push(parseXmlAttrs(attrMatch[1]))
  }

  // Jüngstes Event per `event-timestamp` ermitteln. Wenn alle Timestamps
  // fehlen, nimm das letzte (DHL liefert üblicherweise chronologisch).
  let latestEvent: Record<string, string> | null = null
  let latestTs = -Infinity
  for (const ev of events) {
    const ts = ev['event-timestamp']
    const t = ts ? Date.parse(ts) : NaN
    if (!Number.isNaN(t) && t > latestTs) {
      latestTs = t
      latestEvent = ev
    }
  }
  if (!latestEvent && events.length > 0) latestEvent = events[events.length - 1]

  // Status-Inference: Priorität wie im JSON-Parcel-DE-Parser
  //   1. `delivery-event-flag="1"` → delivered (sicherstes Signal)
  //   2. `standard-event-code` (ZU/AZ = delivered, IZ/ES/AB/BA = transit,
  //      RT/ZF = exception)
  //   3. Text-Fallback in `event-text`/`status`
  const deliveryFlag = shipmentAttrs['delivery-event-flag']
  const eventCode = (
    latestEvent?.['standard-event-code'] ?? latestEvent?.['event-status']
  )?.toLowerCase()
  const eventText =
    latestEvent?.['event-text'] ??
    latestEvent?.['event-status'] ??
    shipmentAttrs['status']
  const eventTs =
    latestEvent?.['event-timestamp'] ?? shipmentAttrs['status-timestamp']

  let normalized: TrackingDeliveryStatus = 'unknown'
  if (deliveryFlag === '1') {
    normalized = 'delivered'
  } else if (eventCode) {
    if (eventCode === 'zu' || eventCode === 'az') normalized = 'delivered'
    else if (
      eventCode === 'iz' || eventCode === 'es' || eventCode === 'ab' ||
      eventCode === 'ba' || eventCode === 'transit' ||
      eventCode === 'pre-transit' || eventCode === 'out-for-delivery'
    ) {
      normalized = 'in_transit'
    } else if (
      eventCode === 'rt' || eventCode === 'zf' ||
      eventCode === 'failure' || eventCode === 'exception'
    ) {
      normalized = 'exception'
    } else {
      const txt = (eventText ?? '').toLowerCase()
      if (txt.includes('zugestellt') || txt.includes('delivered')) {
        normalized = 'delivered'
      }
    }
  } else if (eventText) {
    const txt = eventText.toLowerCase()
    if (txt.includes('zugestellt') || txt.includes('delivered')) {
      normalized = 'delivered'
    } else if (txt.includes('zustellung') || txt.includes('transit')) {
      normalized = 'in_transit'
    }
  }

  // Wenn weder Shipment noch Events erkannt wurden → kein Match.
  if (
    Object.keys(shipmentAttrs).length === 0 &&
    events.length === 0
  ) {
    return null
  }

  return {
    status: normalized,
    deliveredAt: normalized === 'delivered' ? toIso(eventTs) : undefined,
    lastEvent: eventText,
    rawStatusCode: eventCode,
  }
}

/// Mini-XML-Attribut-Parser: aus `attr1="value" attr2="value"` ein
/// Record<string, string>. Robust gegen multiple Whitespaces und
/// Tab/Newline; entitäten (`&amp;`, `&lt;` etc.) werden dekodiert.
function parseXmlAttrs(s: string): Record<string, string> {
  const out: Record<string, string> = {}
  const re = /([a-zA-Z_:-][a-zA-Z0-9_.:-]*)\s*=\s*"([^"]*)"/g
  let m: RegExpExecArray | null
  while ((m = re.exec(s)) !== null) {
    out[m[1]] = decodeXmlEntities(m[2])
  }
  return out
}

function decodeXmlEntities(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
}

/// Parser für das Unified-/Shipment-Tracking-Schema:
///   `{ shipments: [{ status: { statusCode, status, description, timestamp } }] }`
function parseDhlUnified(
  payload: Record<string, unknown>,
): ParsedTracking | null {
  const shipments = payload.shipments
  if (!Array.isArray(shipments) || shipments.length === 0) return null
  const shipment = shipments[0]
  if (!isObject(shipment)) return null
  const status = isObject(shipment.status) ? shipment.status : null
  if (!status) return null
  const code = pickString(status, 'statusCode', 'status')?.toLowerCase()
  // `status`-Feld zuerst: bei DHL ist das das kurze, kuratierte Label
  // ("Zugestellt", "In Zustellung"). `description` ist der ausgeschriebene
  // Satz mit kleingeschriebenem Verb — weniger nützlich als Last-Event.
  const description =
    pickString(status, 'status', 'description') ?? undefined
  const timestamp = pickString(status, 'timestamp')

  const normalized = normalizeDhlStatusCode(code)
  return {
    status: normalized,
    deliveredAt: normalized === 'delivered' ? toIso(timestamp) : undefined,
    lastEvent: description,
    rawStatusCode: code,
  }
}

/// Parser für das Parcel-DE-Tracking-Schema (XML-to-JSON):
///   `{ pieceshipmentlist: { pieceshipment: <obj|array>, ... } }`
/// Felder pro Shipment: `piece-code`, `status`, `status-timestamp`,
/// `delivery-event-flag` ("1"=delivered, "0"=pending),
/// `pieceeventlist.pieceevent[]` mit `event-timestamp`, `event-status`,
/// `event-text`, `standard-event-code`.
function parseDhlParcelDe(
  payload: Record<string, unknown>,
): ParsedTracking | null {
  const list = isObject(payload.pieceshipmentlist)
    ? payload.pieceshipmentlist
    : null
  if (!list) return null
  // `pieceshipment` kann ein Objekt (1 Treffer) oder ein Array sein (mehrere).
  const rawShipment = list.pieceshipment
  const shipment: Record<string, unknown> | null = Array.isArray(rawShipment)
    ? (isObject(rawShipment[0]) ? (rawShipment[0] as Record<string, unknown>) : null)
    : (isObject(rawShipment) ? rawShipment as Record<string, unknown> : null)
  if (!shipment) return null

  // Letztes Event: `pieceeventlist.pieceevent` (kann ebenfalls Obj oder Array sein).
  const eventList = isObject(shipment.pieceeventlist)
    ? shipment.pieceeventlist
    : null
  const rawEvents = eventList?.pieceevent
  const events: Record<string, unknown>[] = Array.isArray(rawEvents)
    ? rawEvents.filter(isObject) as Record<string, unknown>[]
    : (isObject(rawEvents) ? [rawEvents as Record<string, unknown>] : [])

  // Event mit jüngstem Timestamp gewinnt — DHL liefert in der Praxis
  // chronologisch sortiert, aber wir vertrauen darauf nicht.
  let latestEvent: Record<string, unknown> | null = null
  let latestTs = -Infinity
  for (const ev of events) {
    const ts = pickString(ev, 'event-timestamp')
    const t = ts ? Date.parse(ts) : NaN
    if (!Number.isNaN(t) && t > latestTs) {
      latestTs = t
      latestEvent = ev
    }
  }
  if (!latestEvent && events.length > 0) latestEvent = events[events.length - 1]

  // Status-Quellen, in dieser Priorität:
  //  1. `delivery-event-flag` ("1" → delivered, sicherstes Signal).
  //  2. `standard-event-code` (z.B. "ZU"=Zugestellt) oder `event-status`-Code
  //     am letzten Event.
  //  3. Top-Level `status` als Text-Fallback.
  const deliveryFlag = pickString(shipment, 'delivery-event-flag')
  const eventCode =
    pickString(latestEvent, 'standard-event-code', 'event-status')?.toLowerCase()
  const eventText =
    pickString(latestEvent, 'event-text', 'event-status') ??
    pickString(shipment, 'status') ?? undefined
  const eventTs =
    pickString(latestEvent, 'event-timestamp') ??
    pickString(shipment, 'status-timestamp')

  let normalized: TrackingDeliveryStatus = 'unknown'
  if (deliveryFlag === '1') {
    normalized = 'delivered'
  } else if (eventCode) {
    // DHL-DE-Standard-Event-Codes (kuratierte Mappings):
    //   ZU  = Zugestellt           → delivered
    //   AZ  = Ausgeliefert         → delivered (synonym)
    //   IZ  = In Zustellung        → in_transit
    //   ES  = Empfangen            → in_transit
    //   AB  = Abgeholt             → in_transit
    //   BA  = Bearbeitung          → in_transit
    //   RT  = Rücktransport        → exception
    //   ZF  = Zustellfehler        → exception
    if (eventCode === 'zu' || eventCode === 'az') normalized = 'delivered'
    else if (
      eventCode === 'iz' || eventCode === 'es' || eventCode === 'ab' ||
      eventCode === 'ba' || eventCode === 'transit' ||
      eventCode === 'pre-transit' || eventCode === 'out-for-delivery'
    ) {
      normalized = 'in_transit'
    } else if (
      eventCode === 'rt' || eventCode === 'zf' ||
      eventCode === 'failure' || eventCode === 'exception'
    ) {
      normalized = 'exception'
    } else {
      // Unbekannter Code → versuch's noch über den Text.
      const txt = (eventText ?? '').toLowerCase()
      if (txt.includes('zugestellt') || txt.includes('delivered')) {
        normalized = 'delivered'
      }
    }
  } else if (eventText) {
    const txt = eventText.toLowerCase()
    if (txt.includes('zugestellt') || txt.includes('delivered')) {
      normalized = 'delivered'
    } else if (txt.includes('zustellung') || txt.includes('transit')) {
      normalized = 'in_transit'
    }
  }

  return {
    status: normalized,
    deliveredAt: normalized === 'delivered' ? toIso(eventTs) : undefined,
    lastEvent: eventText,
    rawStatusCode: eventCode,
  }
}

/// Mapping für Unified-style statusCode → unsere normalisierte Enum-Variante.
function normalizeDhlStatusCode(
  code: string | undefined,
): TrackingDeliveryStatus {
  if (code === 'delivered') return 'delivered'
  if (
    code === 'transit' || code === 'pre-transit' ||
    code === 'out-for-delivery'
  ) {
    return 'in_transit'
  }
  if (code === 'failure' || code === 'exception') return 'exception'
  return 'unknown'
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
