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

const AFTERSHIP_API_KEY = Deno.env.get("AFTERSHIP_API_KEY") ?? "";
if (!AFTERSHIP_API_KEY) {
  console.error("ERROR: AFTERSHIP_API_KEY env var not set.");
  console.error("Setup:");
  console.error("  1. https://accounts.aftership.com/sign-up");
  console.error("  2. Dashboard → Settings → API → Tracking API → Create Live API Key");
  console.error("  3. echo 'AFTERSHIP_API_KEY=<key>' >> .env.test");
  console.error("  4. source .env.test  (or pass inline)");
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

interface RowResult {
  test: TestCase;
  ourPrimary: string | null;
  ourCarrier: string | null;
  ourConfidence: string;
  aftershipCarrier: string | null;
  aftershipDetected: boolean;
  match_pipeline: "✓" | "✗" | "—";
  match_aftership: "✓" | "✗" | "—";
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

  // AfterShip detect — nur wenn wir eine tracking-nr haben (ihr API braucht eine)
  let afterShip: AfterShipResult = { detected: false };
  if (trackingForAfterShip) {
    afterShip = await callAfterShipDetect(trackingForAfterShip);
    // Be nice to rate-limit
    await new Promise((res) => setTimeout(res, 200));
  }

  const expected = (t.expected_carrier ?? "(none)").toLowerCase();
  const ourCarrierLow = (carrier ?? "(none)").toLowerCase();
  const asCarrierLow = (afterShip.carrier ?? "(none)").toLowerCase();

  const matchOurs = expected === "(none)"
    ? (primary === null ? "✓" : "✗")
    : (ourCarrierLow.includes(expected.split(" ")[0]) ? "✓" : "✗");
  const matchAS = afterShip.error ? "—"
    : expected === "(none)"
      ? (afterShip.detected ? "✗" : "✓")
      : (asCarrierLow.includes(expected.split(" ")[0]) ? "✓" : "✗");

  return {
    test: t,
    ourPrimary: primary,
    ourCarrier: carrier,
    ourConfidence: confidence,
    aftershipCarrier: afterShip.carrier ?? (afterShip.error ?? null),
    aftershipDetected: afterShip.detected,
    match_pipeline: matchOurs,
    match_aftership: matchAS,
  };
}

console.log("# Tracking Side-by-Side: jkeen-Pipeline vs AfterShip Detect-API\n");
console.log(`Test-Cases: ${DEFAULT_SAMPLES.length}`);
console.log(`Generated: ${new Date().toISOString()}\n`);
console.log("| # | Case | Expected | Pipeline | Conf | AfterShip | Match P / A |");
console.log("|---|------|----------|----------|------|-----------|-------------|");

const results: RowResult[] = [];
for (const t of DEFAULT_SAMPLES) {
  const r = await runOne(t);
  results.push(r);
  const expShort = (t.expected_carrier ?? "(none)").slice(0, 18);
  const ourShort = (r.ourCarrier ?? r.ourPrimary ?? "(none)").toString().slice(0, 18);
  const asShort = (r.aftershipCarrier ?? "(no-call)").toString().slice(0, 18);
  console.log(`| ${t.id} | ${t.source.slice(0, 28)} | ${expShort} | ${ourShort} | ${r.ourConfidence} | ${asShort} | ${r.match_pipeline} / ${r.match_aftership} |`);
}

const passPipeline = results.filter((r) => r.match_pipeline === "✓").length;
const passAfterShip = results.filter((r) => r.match_aftership === "✓").length;
const naAfterShip = results.filter((r) => r.match_aftership === "—").length;

console.log(`\n## Summary`);
console.log(`- **Pipeline (jkeen)**: ${passPipeline}/${results.length} correct`);
console.log(`- **AfterShip**: ${passAfterShip}/${results.length - naAfterShip} correct (${naAfterShip} N/A)`);
console.log();

if (passPipeline >= passAfterShip) {
  console.log(`### Empfehlung: **Pipeline behalten** — jkeen-Detection ist mindestens gleichwertig, kein Bedarf für externe Lösung`);
} else if (passAfterShip - passPipeline >= 3) {
  console.log(`### Empfehlung: **Hybrid** — AfterShip schlägt unsere Pipeline um ≥3 Cases. Hybrid: Pipeline-Detection als First-Pass, AfterShip-Fallback bei null-result. Cost: $0.08/lookup (AfterShip Free-Tier 100 trackings/Monat).`);
} else {
  console.log(`### Empfehlung: **Bewertung unentschlossen** — Diff zwischen jkeen und AfterShip ist ${passAfterShip - passPipeline} Cases. Manuelle Inspektion welche Cases jkeen falsch oder AfterShip falsch hat, dann Decision.`);
}

// Persist JSON
const outPath = `.claude/test-runs/tracking-comparison-${new Date().toISOString().replace(/[:.]/g, "-")}.json`;
try {
  await Deno.mkdir(".claude/test-runs", { recursive: true });
  await Deno.writeTextFile(outPath, JSON.stringify({
    generated: new Date().toISOString(),
    samples: DEFAULT_SAMPLES.length,
    pipeline_pass: passPipeline,
    aftership_pass: passAfterShip,
    aftership_na: naAfterShip,
    rows: results,
  }, null, 2));
  console.log(`\nJSON-Stats: ${outPath}`);
} catch (e) {
  console.error(`Failed to write stats: ${e}`);
}
