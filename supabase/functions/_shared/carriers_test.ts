// Konsistenz-Tests für die kanonische Carrier-Registry (Paket 2).
//
// Prüft, dass die drei vormals driftenden Carrier-Mengen (Detection,
// Poll-Adapter, Dart-UI) gegen carriers.ts konsistent bleiben. Die
// Dart-Seite wird per Quelltext-Read geprüft (CI: deno test --allow-read).

import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { CARRIERS, carrierById, DETECTION_ONLY_CARRIERS } from './carriers.ts'
import { ADAPTERS } from './tracking_adapters.ts'

Deno.test('registry: detection-only = amazon + gls', () => {
  assertEquals([...DETECTION_ONLY_CARRIERS].sort(), ['amazon', 'gls'])
})

Deno.test('registry: jeder ADAPTERS-Key ist als pollAdapter registriert', () => {
  for (const id of Object.keys(ADAPTERS)) {
    const info = carrierById(id)
    assert(info, `ADAPTERS['${id}'] fehlt in carriers.ts`)
    assert(info!.pollAdapter, `carriers.ts: '${id}' muss pollAdapter=true sein`)
  }
})

Deno.test('registry: pollAdapter=true ⇒ Adapter existiert wirklich', () => {
  for (const c of CARRIERS.filter((c) => c.pollAdapter)) {
    assert(
      Object.keys(ADAPTERS).includes(c.id),
      `carriers.ts behauptet pollAdapter für '${c.id}', ADAPTERS kennt ihn nicht`,
    )
  }
})

Deno.test('registry: Detection-CarrierId-Union deckt detection=true ab', async () => {
  const src = await Deno.readTextFile(
    new URL('./tracking_detection.ts', import.meta.url),
  )
  const m = src.match(/export type CarrierId = ([^\n]+)/)
  assert(m, 'CarrierId-Union nicht gefunden')
  const unionIds = [...m![1].matchAll(/'([a-z]+)'/g)].map((x) => x[1]).sort()
  const detectionIds = CARRIERS.filter((c) => c.detection).map((c) => c.id).sort()
  assertEquals(unionIds, detectionIds)
})

Deno.test('registry: Dart enabledCarrierIds spiegelt uiEnabled', async () => {
  const src = await Deno.readTextFile(
    new URL('../../../lib/models/carrier_credential.dart', import.meta.url),
  )
  const m = src.match(/const enabledCarrierIds = <String>\{([^}]*)\}/)
  assert(m, 'enabledCarrierIds nicht gefunden')
  const dartIds = [...m![1].matchAll(/'([a-z]+)'/g)].map((x) => x[1]).sort()
  const registryIds = CARRIERS.filter((c) => c.uiEnabled).map((c) => c.id).sort()
  assertEquals(dartIds, registryIds)
})

Deno.test('registry: Dart carrier_links deckt alle publicTrackingPage-Carrier', async () => {
  const src = await Deno.readTextFile(
    new URL('../../../lib/utils/carrier_links.dart', import.meta.url),
  )
  for (const c of CARRIERS.filter((c) => c.publicTrackingPage)) {
    assert(
      src.includes(`'${c.id}' =>`),
      `carrier_links.dart fehlt URL-Case für '${c.id}'`,
    )
  }
  // amazon ist explizit linklos — der Case muss auf null mappen.
  assert(/'amazon' => null/.test(src), 'amazon muss in carrier_links.dart null sein')
})

Deno.test('registry: deals.carrier-CHECK (Migration) ist Obermenge der Registry', async () => {
  const src = await Deno.readTextFile(
    new URL(
      '../../migrations/20260610150000_deals_carrier_gls.sql',
      import.meta.url,
    ),
  )
  const m = src.match(/carrier IN \(([^)]+)\)/)
  assert(m, 'CHECK-Liste nicht gefunden')
  const checkIds = new Set([...m![1].matchAll(/'([a-z]+)'/g)].map((x) => x[1]))
  for (const c of CARRIERS) {
    assert(checkIds.has(c.id), `deals_carrier_check fehlt '${c.id}'`)
  }
})
