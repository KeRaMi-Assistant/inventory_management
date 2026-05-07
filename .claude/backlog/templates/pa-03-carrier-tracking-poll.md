---
slug: carrier-tracking-poll
priority: 3
plan: true
---

## Ziel
Edge Function `tracking-poll` die alle 4h die Carrier-APIs (DHL, DPD,
UPS, mind. diese 3) für offene `deals` mit `tracking_number IS NOT NULL
AND status='Unterwegs' AND arrival_date IS NULL` pollt.

Bei "delivered"-Status:
- `deals.arrival_date` = api-reported delivery date
- `deals.status` = `Angekommen`
- Activity-Log-Eintrag
- Optional: Push-Notification

## Was zu tun ist

1. Migration `supabase/migrations/<ts>_workspace_carrier_credentials.sql`:
   - Tabelle `workspace_carrier_credentials` (`workspace_id`, `carrier_id`,
     `api_key_encrypted`, `created_at`)
   - RLS: nur Owner/Admin sehen + ändern
   - Verschlüsselung via `pgp_sym_encrypt` analog zu `inbox_credentials`

2. Settings-Tab "Versand": API-Key-Eingabe pro Carrier (Read-only-Anzeige
   `••••••••••••<last4>` nach Save)

3. Edge Function `supabase/functions/tracking-poll/index.ts`:
   - Cron-Trigger alle 4h via `pg_cron`
   - Pro Workspace: lade aktive Tracking-Nummern + decrypted credentials
   - Carrier-Adapter-Pattern (analog zu Inbox-Adaptern):
     - `dhl_adapter.ts`: DHL Sendungsverfolgung-API
     - `dpd_adapter.ts`: DPD Tracking-API
     - `ups_adapter.ts`: UPS Tracking-API
   - Bei Status-Change: Update Deal + Activity-Log

4. Carrier-Detection bleibt aus existierendem `carrier_service.dart`.

## Tests

- Pro Adapter: Mock-API-Response → ParsedTracking-Object (status,
  delivered_at, last_event)
- Edge Fn: invoke mit fixed Workspace + Mock-Adapter, prüfe Deal-Update.

## Akzeptanz

- `flutter analyze` clean
- `flutter test` 70+ grün
- Edge Fn lokal via `supabase functions serve` testbar
- Settings-UI funktional
- DOCS in PR: User-Action: nach Merge `supabase functions deploy
  tracking-poll --project-ref <dev>`, dann Cron-Job in Supabase Studio
  setzen (4h interval).

## Hinweis

Edge Function lokal entwickeln + testen. Cloud-Deployment macht User
selbst. Keine Carrier-API-Keys hardcoden.
