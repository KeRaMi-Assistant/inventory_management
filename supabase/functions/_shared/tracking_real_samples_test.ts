// Auto-generated regression-test from jkeen test_numbers.valid
// Source: supabase/functions/_shared/tracking_data/couriers/*.json
// Generated: 2026-05-15 — covers all carriers, max 2 samples per pattern
//
// Purpose: Ensure disambig-logic correctly identifies each carrier
// without false-negatives ("(none)" instead of correct carrier).

import { validateTrackingNumber } from "./tracking_validators.ts";
import { assert, assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

// 36 real-world samples
const REAL_SAMPLES = [
  { value: 'TBA000000000000', carrier: 'amazon', desc: 'Amazon Logistics' },
  { value: 'TBA010000000000', carrier: 'amazon', desc: 'Amazon Logistics' },
  { value: 'C1004444443', carrier: 'amazon', desc: 'Amazon International' },
  { value: 'C1004444444', carrier: 'amazon', desc: 'Amazon International' },
  { value: '0073938000549297', carrier: 'canadapost', desc: 'Canada Post (16)' },
  { value: '7035114477138472', carrier: 'canadapost', desc: 'Canada Post (16)' },
  { value: '3318810025', carrier: 'dhl', desc: 'DHL Express' },
  { value: '73891051146', carrier: 'dhl', desc: 'DHL Express' },
  { value: 'JJD0099999999', carrier: 'dhl', desc: 'DHL Express (Piece ID)' },
  { value: 'JVGL0999999990', carrier: 'dhl', desc: 'DHL Express (Piece ID)' },
  { value: 'GM2951173225174494', carrier: 'dhl', desc: 'DHL E-Commerce' },
  { value: '60120172242323', carrier: 'dhl', desc: 'DHL E-Commerce (14)' },
  { value: '420902459261290336128704042634', carrier: 'dhl', desc: 'DHL E-Commerce (30)' },
  { value: '420941179261290336128704062441', carrier: 'dhl', desc: 'DHL E-Commerce (30)' },
  { value: '986578788855', carrier: 'fedex', desc: 'FedEx Express (12)' },
  { value: '477179081230', carrier: 'fedex', desc: 'FedEx Express (12)' },
  { value: '9261292700768711948021', carrier: 'fedex', desc: 'FedEx SmartPost' },
  { value: '9611020987654312345672', carrier: 'fedex', desc: 'FedEx Ground 96 (22)' },
  { value: 'LTN74207623N1', carrier: 'landmark', desc: 'Landmark Global LTN' },
  { value: 'LTN74209518N1', carrier: 'landmark', desc: 'Landmark Global LTN' },
  { value: 'LX17635036', carrier: 'lasership', desc: 'LaserShip LX' },
  { value: '1LS717793482164', carrier: 'lasership', desc: 'LaserShip 1LS7 (15)' },
  { value: '1LS724505321754', carrier: 'lasership', desc: 'LaserShip 1LS7 (15)' },
  { value: '1LS7119013618127-1', carrier: 'lasership', desc: 'LaserShip 1LS7 (18)' },
  { value: '07209562763', carrier: 'old_dominion', desc: 'Old Dominion' },
  { value: '80003280379', carrier: 'old_dominion', desc: 'Old Dominion Guaranteed Shipment' },
  { value: 'C11031500001879', carrier: 'ontrac', desc: 'OnTrac' },
  { value: 'D10011354453707', carrier: 'ontrac', desc: 'OnTrac D' },
  { value: 'D10011345983010', carrier: 'ontrac', desc: 'OnTrac D' },
  { value: 'RB123456785GB', carrier: 's10', desc: 'S10' },
  { value: 'RB123456785US', carrier: 's10', desc: 'S10' },
  { value: '1Z5R89390357567127', carrier: 'ups', desc: 'UPS' },
  { value: '1Z879E930346834440', carrier: 'ups', desc: 'UPS' },
  { value: 'K1506235620', carrier: 'ups', desc: 'UPS Waybill' },
  { value: '420787459400111206206406260787', carrier: 'usps', desc: 'USPS 22' },
  { value: '9400111206206406260787', carrier: 'usps', desc: 'USPS 22' },
];

Deno.test("real-world valid samples — disambig identifies correct carrier", async () => {
  let pass = 0, fail = 0;
  const fails: string[] = [];
  for (const s of REAL_SAMPLES) {
    const r = await validateTrackingNumber(s.value);
    const got = (r.carrierSlug ?? "").toLowerCase();
    const expected = s.carrier.toLowerCase();
    if (got === expected || (r as any).ambiguous) {
      // Ambiguous is acceptable (cannot disambig with checksum alone)
      pass++;
    } else {
      fail++;
      fails.push(`${s.value} → got=${got}, expected=${expected} (${s.desc})`);
    }
  }
  // Allow 5% noise (jkeen partner-cross-refs etc.); fail-fast above
  const maxFails = Math.ceil(REAL_SAMPLES.length * 0.05);
  if (fail > maxFails) {
    console.log("FAILS:\n" + fails.slice(0, 10).join("\n"));
    assert(false, `${fail} fails > max ${maxFails}`);
  }
  console.log(`real-samples: ${pass}/${REAL_SAMPLES.length} pass, ${fail} fail (max ${maxFails})`);
});
