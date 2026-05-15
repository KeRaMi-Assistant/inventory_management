// tracking-comparison.ts — Side-by-Side jkeen-DB (lokal) vs AfterShip-API.
//
// Zweck: Real-World-Vergleich der Eigenbau-Pipeline mit AfterShip's Detect-API.
// Aufruf:
//   1. .env.test: AFTERSHIP_API_KEY=asat_xxx... (User-Action, Free-Tier)
//   2. deno run --allow-net --allow-read --allow-env \
//        .claude/scripts/tracking-comparison.ts [--sample <path>]
//
// Default-Sample: 20 Test-Cases (5 Demo-Fixtures + 5 jkeen real + 5 edge-cases
// + 5 user-provided via samples-file falls --sample gegeben).
//
// Output:
//   - Markdown-Tabelle Pipeline-Output vs AfterShip
//   - JSON-Stats in .claude/test-runs/tracking-comparison-<ts>.json
//   - Empfehlung am Ende: behalten / hybrid / migrate

import { validateTrackingNumber } from "../../supabase/functions/_shared/tracking_validators.ts";
import { findAllTrackings, gateTracking } from "../../supabase/functions/_shared/inbox_adapters.ts";
import { dhlAdapter, upsAdapter, dpdAdapter } from "../../supabase/functions/_shared/tracking_adapters.ts";

// API-Keys aus .env.test — alle optional; Script vergleicht nur was es hat.
const AFTERSHIP_API_KEY = Deno.env.get("AFTERSHIP_API_KEY") ?? "";
const DHL_API_KEY = Deno.env.get("DHL_API_KEY") ?? "";
const UPS_API_KEY = Deno.env.get("UPS_API_KEY") ?? "";  // OAuth Bearer-Token
const DPD_API_KEY = Deno.env.get("DPD_API_KEY") ?? "";

const HAS_ANY_API = AFTERSHIP_API_KEY || DHL_API_KEY || UPS_API_KEY;
if (!HAS_ANY_API) {
  console.error("ERROR: Keine API-Keys gesetzt. Mindestens einer wird benötigt:");
  console.error("  DHL_API_KEY        - https://developer.dhl.com (250 calls/day free)");
  console.error("  UPS_API_KEY        - https://developer.ups.com (OAuth Bearer-Token)");
  console.error("  DPD_API_KEY        - https://www.dpd.com/business/integration-partners");
  console.error("  AFTERSHIP_API_KEY  - https://accounts.aftership.com/sign-up (50/Mo free)");
  console.error("");
  console.error("Setup-Beispiel:");
  console.error("  echo 'DHL_API_KEY=<key>' >> .env.test");
  console.error("  source .env.test");
  console.error("  deno run --allow-net --allow-read --allow-env .claude/scripts/tracking-comparison.ts");
  Deno.exit(1);
}

interface TestCase {
  id: string;
  // entweder body (mail-text/html) für full-pipeline-test
  body?: string;
  // ODER nackte tracking-number für validator-only-test
  tracking?: string;
  expected_carrier?: string;
  source: string;
}

// 15 Default-Test-Cases (5+5+5)
const DEFAULT_SAMPLES: TestCase[] = [
  // 5 Demo-Fixtures (seed-demo-workspace plain-text Amazon-Mails)
  { id: "demo-1", body: "Your tracking number is: DE5455279839", expected_carrier: "Amazon Logistics", source: "demo-1 Amazon-DE" },
  { id: "demo-2", body: "Your tracking number is: DE6701142233", expected_carrier: "Amazon Logistics", source: "demo-2 Amazon-DE" },
  { id: "demo-3", body: "Your tracking number is: DE8821445566", expected_carrier: "Amazon Logistics", source: "demo-3 Amazon-IT" },
  { id: "demo-4", body: "Your tracking number is: DE7732998877", expected_carrier: "Amazon Logistics", source: "demo-4 Amazon-ES" },
  { id: "demo-5", body: "Your tracking number is: DE9988776655", expected_carrier: "Amazon Logistics", source: "demo-5 Amazon-FR" },

  // 5 jkeen real test-numbers (carrier-Standards)
  { id: "ups-1z", tracking: "1Z999AA10123456784", expected_carrier: "UPS", source: "jkeen UPS-1Z" },
  { id: "usps-22", tracking: "9400111206206406260787", expected_carrier: "USPS", source: "jkeen USPS-22" },
  { id: "fedex-12", tracking: "961207671018669605", expected_carrier: "FedEx", source: "jkeen FedEx-12" },
  { id: "s10-de", tracking: "RR123456785DE", expected_carrier: "DHL", source: "jkeen S10 international (DE-suffix)" },
  { id: "tba", tracking: "TBA123456789012", expected_carrier: "Amazon Logistics", source: "Amazon TBA" },

  // 5 Edge-Cases (regression-territory)
  { id: "iban-de", body: "Bezahlt auf DE89370400440532013000 via SEPA", expected_carrier: "(none)", source: "edge IBAN" },
  { id: "amazon-order-id", body: "Your order 302-1234567-1234567 has been processed", expected_carrier: "(none)", source: "edge Order-ID" },
  { id: "random-20", body: "Reference 12345678901234567890 placed", expected_carrier: "(none)", source: "edge random 20-digit no-anchor" },
  { id: "shipment-id-url", body: 'Track at "shiptrack?orderingShipmentId=109727463192302"', expected_carrier: "(none)", source: "edge orderingShipmentId-only" },
  { id: "ups-spaces", body: "Your tracking: 1Z 999 AA1 0123456784", expected_carrier: "UPS", source: "edge UPS-with-whitespace (must normalize)" },
];

interface AfterShipResult {
  carrier?: string;
  detected: boolean;
  raw?: unknown;
  error?: string;
}

async function callAfterShipDetect(trackingNr: string): Promise<AfterShipResult> {
  try {
    const r = await fetch("https://api.aftership.com/v4/couriers/detect", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "aftership-api-key": AFTERSHIP_API_KEY,
      },
      body: JSON.stringify({ tracking: { tracking_number: trackingNr } }),
    });
    if (!r.ok) {
      const t = await r.text();
      return { detected: false, error: `HTTP ${r.status}: ${t.slice(0, 100)}` };
    }
    const data = await r.json() as { data?: { couriers?: Array<{ name?: string; slug?: string }> } };
    const couriers = data.data?.couriers ?? [];
    if (couriers.length === 0) return { detected: false, raw: data };
    return { detected: true, carrier: couriers[0].name ?? couriers[0].slug, raw: data };
  } catch (e) {
    return { detected: false, error: String(e).slice(0, 100) };
  }
}

// Direct-API-Calls für DHL/UPS/DPD — nutzt die existierenden Adapter
async function callDirectCarrier(
  trackingNr: string,
  carrierHint: string,
): Promise<{ carrier?: string; status?: string; detected: boolean; error?: string }> {
  const lowerHint = carrierHint.toLowerCase();

  try {
    if ((lowerHint.includes("dhl") || lowerHint.includes("amazon log")) && DHL_API_KEY) {
      const r = await dhlAdapter.fetchStatus(trackingNr, DHL_API_KEY);
      if (r === null) return { detected: false, error: "DHL: no result" };
      return { detected: true, carrier: "DHL", status: r.status };
    }
    if (lowerHint.includes("ups") && UPS_API_KEY) {
      const r = await upsAdapter.fetchStatus(trackingNr, UPS_API_KEY);
      if (r === null) return { detected: false, error: "UPS: no result" };
      return { detected: true, carrier: "UPS", status: r.status };
    }
    if (lowerHint.includes("dpd") && DPD_API_KEY) {
      const r = await dpdAdapter.fetchStatus(trackingNr, DPD_API_KEY);
      if (r === null) return { detected: false, error: "DPD: no result" };
      return { detected: true, carrier: "DPD", status: r.status };
    }
    return { detected: false, error: "no-matching-carrier-key" };
  } catch (e) {
    return { detected: false, error: String(e).slice(0, 100) };
  }
}

interface RowResult {
  test: TestCase;
  ourPrimary: string | null;
  ourCarrier: string | null;
  ourConfidence: string;
  aftershipCarrier: string | null;
  aftershipDetected: boolean;
  directCarrier: string | null;
  directStatus: string | null;
  directOk: boolean;
  match_pipeline: "✓" | "✗" | "—";
  match_aftership: "✓" | "✗" | "—";
  match_direct: "✓" | "✗" | "—";
}

async function runOne(t: TestCase): Promise<RowResult> {
  // Our pipeline
  let primary: string | null = null;
  let carrier: string | null = null;
  let confidence = "none";
  let trackingForAfterShip: string | null = null;

  if (t.body) {
    const candidates = findAllTrackings(t.body);
    const gate = gateTracking(candidates, { minConfidence: "strong" });
    primary = gate.primary?.value ?? null;
    carrier = gate.primary?.carrier ?? null;
    confidence = gate.primary?.confidence ?? "none";
    trackingForAfterShip = primary;
  } else if (t.tracking) {
    const r = await validateTrackingNumber(t.tracking);
    primary = t.tracking;
    carrier = r.carrier ?? null;
    confidence = r.isValid ? "strong" : "none";
    trackingForAfterShip = t.tracking;
  }

  // AfterShip detect — nur wenn wir eine tracking-nr UND einen Key haben
  let afterShip: AfterShipResult = { detected: false };
  if (trackingForAfterShip && AFTERSHIP_API_KEY) {
    afterShip = await callAfterShipDetect(trackingForAfterShip);
    await new Promise((res) => setTimeout(res, 200));
  }

  // Direct-API: DHL / UPS / DPD direkt (nur wenn Carrier-Hint passt + Key gesetzt)
  let direct: { carrier?: string; status?: string; detected: boolean; error?: string } = { detected: false };
  if (trackingForAfterShip && carrier) {
    direct = await callDirectCarrier(trackingForAfterShip, carrier);
    await new Promise((res) => setTimeout(res, 200));
  }

  const expected = (t.expected_carrier ?? "(none)").toLowerCase();
  const ourCarrierLow = (carrier ?? "(none)").toLowerCase();
  const asCarrierLow = (afterShip.carrier ?? "(none)").toLowerCase();
  const directCarrierLow = (direct.carrier ?? "(none)").toLowerCase();

  const matchOurs = expected === "(none)"
    ? (primary === null ? "✓" : "✗")
    : (ourCarrierLow.includes(expected.split(" ")[0]) ? "✓" : "✗");
  const matchAS = !AFTERSHIP_API_KEY ? "—"
    : afterShip.error ? "—"
    : expected === "(none)"
      ? (afterShip.detected ? "✗" : "✓")
      : (asCarrierLow.includes(expected.split(" ")[0]) ? "✓" : "✗");
  const matchDirect = direct.error?.startsWith("no-matching-carrier-key") ? "—"
    : direct.error ? "✗"
    : expected === "(none)"
      ? (direct.detected ? "✗" : "✓")
      : (direct.detected ? "✓" : "✗");

  return {
    test: t,
    ourPrimary: primary,
    ourCarrier: carrier,
    ourConfidence: confidence,
    aftershipCarrier: afterShip.carrier ?? null,
    aftershipDetected: afterShip.detected,
    directCarrier: direct.carrier ?? null,
    directStatus: direct.status ?? null,
    directOk: direct.detected,
    match_pipeline: matchOurs,
    match_aftership: matchAS,
    match_direct: matchDirect,
  };
}

console.log("# Tracking Side-by-Side: Pipeline (jkeen) vs Direct-Carrier-API vs AfterShip\n");
console.log(`Test-Cases: ${DEFAULT_SAMPLES.length}`);
console.log(`Generated: ${new Date().toISOString()}`);
console.log(`Available APIs: DHL=${DHL_API_KEY ? "✓" : "✗"} UPS=${UPS_API_KEY ? "✓" : "✗"} DPD=${DPD_API_KEY ? "✓" : "✗"} AfterShip=${AFTERSHIP_API_KEY ? "✓" : "✗"}\n`);
console.log("| # | Case | Expected | Pipeline | Conf | Direct-API | AfterShip | P/D/A |");
console.log("|---|------|----------|----------|------|------------|-----------|-------|");

const results: RowResult[] = [];
for (const t of DEFAULT_SAMPLES) {
  const r = await runOne(t);
  results.push(r);
  const expShort = (t.expected_carrier ?? "(none)").slice(0, 16);
  const ourShort = (r.ourCarrier ?? r.ourPrimary ?? "(none)").toString().slice(0, 16);
  const directShort = (r.directCarrier ?? r.directStatus ?? (r.match_direct === "—" ? "(no-key)" : "(none)")).toString().slice(0, 14);
  const asShort = (r.aftershipCarrier ?? (r.match_aftership === "—" ? "(no-key)" : "(none)")).toString().slice(0, 14);
  console.log(`| ${t.id} | ${t.source.slice(0, 24)} | ${expShort} | ${ourShort} | ${r.ourConfidence} | ${directShort} | ${asShort} | ${r.match_pipeline}/${r.match_direct}/${r.match_aftership} |`);
}

const passPipeline = results.filter((r) => r.match_pipeline === "✓").length;
const passDirect = results.filter((r) => r.match_direct === "✓").length;
const naDirect = results.filter((r) => r.match_direct === "—").length;
const passAfterShip = results.filter((r) => r.match_aftership === "✓").length;
const naAfterShip = results.filter((r) => r.match_aftership === "—").length;

console.log(`\n## Summary`);
console.log(`- **Pipeline (jkeen, lokal, €0)**: ${passPipeline}/${results.length} correct`);
console.log(`- **Direct-Carrier-API (DHL/UPS/DPD free-tier, €0)**: ${passDirect}/${results.length - naDirect} correct (${naDirect} N/A — kein passender Key)`);
if (AFTERSHIP_API_KEY) {
  console.log(`- **AfterShip (€100/Mo Pro)**: ${passAfterShip}/${results.length - naAfterShip} correct (${naAfterShip} N/A)`);
}
console.log();

// Empfehlung-Logik: Direct-API > AfterShip-Cost-Benefit?
const directCoverage = naDirect < results.length / 2;  // > 50% Cases von Direct-API abgedeckt
if (directCoverage && passDirect >= passAfterShip - 1) {
  console.log(`### Empfehlung: **Direct-Carrier-APIs (€0/Mo)** — gleichwertig oder besser als AfterShip bei null Cost`);
  console.log(`Eine Investition in DHL/UPS-Developer-Keys (kostenlos, ~30min Setup) deckt dein Volumen ab.`);
  console.log(`AfterShip-Subscription wäre Verschwendung.`);
} else if (!directCoverage) {
  console.log(`### Empfehlung: **Setup mehr Direct-Keys** — viele Cases sind 'no-matching-key'`);
  console.log(`DHL_API_KEY, UPS_API_KEY, DPD_API_KEY in .env.test setzen und Test erneut laufen.`);
} else if (passAfterShip - passDirect >= 3) {
  console.log(`### Empfehlung: **Hybrid** — AfterShip schlägt Direct-APIs um ≥3 Cases`);
  console.log(`Pipeline + Direct als First-Pass, AfterShip als Fallback bei null-result.`);
} else {
  console.log(`### Empfehlung: **Manuelle Bewertung** — Diff Direct vs AfterShip = ${passAfterShip - passDirect} Cases`);
}

// Persist JSON
const outPath = `.claude/test-runs/tracking-comparison-${new Date().toISOString().replace(/[:.]/g, "-")}.json`;
try {
  await Deno.mkdir(".claude/test-runs", { recursive: true });
  await Deno.writeTextFile(outPath, JSON.stringify({
    generated: new Date().toISOString(),
    samples: DEFAULT_SAMPLES.length,
    available_apis: {
      dhl: !!DHL_API_KEY,
      ups: !!UPS_API_KEY,
      dpd: !!DPD_API_KEY,
      aftership: !!AFTERSHIP_API_KEY,
    },
    pipeline_pass: passPipeline,
    direct_api_pass: passDirect,
    direct_api_na: naDirect,
    aftership_pass: passAfterShip,
    aftership_na: naAfterShip,
    rows: results,
  }, null, 2));
  console.log(`\nJSON-Stats: ${outPath}`);
} catch (e) {
  console.error(`Failed to write stats: ${e}`);
}
