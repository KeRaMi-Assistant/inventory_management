# Setup: tracking-poll (Carrier-Sendungsverfolgung)

> Sprint 7. Pollt alle 4h die Carrier-APIs (DHL, DPD, UPS) für offene Deals
> und setzt Status auf `Angekommen`, sobald die Sendung zugestellt ist.

## 1. Master-Key für Carrier-API-Keys setzen

Die Migration `20260508000000_workspace_carrier_credentials.sql` legt RPCs an,
die API-Keys mit `pgp_sym_encrypt` verschlüsseln. Der Schlüssel kommt aus
Supabase Vault.

In der SQL-Konsole:

```sql
SELECT vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'hex'),
  'carrier_master_key',
  'Master-Schlüssel für Carrier-API-Keys (Sprint 7)'
);
```

Prüfen:

```sql
SELECT name, created_at FROM vault.secrets WHERE name = 'carrier_master_key';
```

> **Self-hosted ohne Vault**: Alternativ `app.carrier_master_key` per
> `ALTER DATABASE … SET app.carrier_master_key = '…'` setzen.

## 2. CRON_SECRET wiederverwenden

`tracking-poll` nutzt denselben `CRON_SECRET` wie `inbox-poll` /
`send-notifications`. Falls noch nicht gesetzt:

```bash
SECRET=$(openssl rand -hex 32)
supabase secrets set --project-ref <PROJECT_REF> CRON_SECRET="$SECRET"
```

## 3. Function deployen

```bash
supabase functions deploy tracking-poll --project-ref <PROJECT_REF>
```

## 4. pg_cron — Polling alle 4h

In der SQL-Konsole **EINMAL** ausführen (Zeitfenster ist absichtlich
versetzt zum 5-min-Inbox-Tick, damit beide nicht gleichzeitig laufen):

```sql
SELECT cron.schedule(
  'tracking-poll-4h',
  '7 */4 * * *',
  $$
    SELECT net.http_post(
      url := 'https://<PROJECT_REF>.functions.supabase.co/tracking-poll',
      headers := jsonb_build_object(
        'Authorization', 'Bearer <CRON_SECRET>',
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 90000
    );
  $$
);
```

Status prüfen:

```sql
SELECT * FROM cron.job WHERE jobname = 'tracking-poll-4h';
SELECT * FROM cron.job_run_details
 WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'tracking-poll-4h')
 ORDER BY start_time DESC LIMIT 5;
```

Pausieren:

```sql
SELECT cron.unschedule('tracking-poll-4h');
```

## 5. Carrier-API-Keys in der App eintragen

App → Einstellungen → **Versand** → API-Key pro Carrier eingeben. Der Key
wird sofort verschlüsselt gespeichert; angezeigt wird ab dem nächsten Reload
nur noch `••••<letzte 4 Zeichen>`.

API-Keys bekommt man hier:

- DHL  → <https://developer.dhl.com/api-reference/shipment-tracking>
- DPD  → DPD-Vertriebspartner / DPD Geopost API-Portal
- UPS  → <https://developer.ups.com/> (OAuth-Bearer-Token)

## 6. Manuell triggern (Debug)

```bash
# Alle Workspaces:
supabase functions invoke tracking-poll --project-ref <PROJECT_REF>

# Nur einen Workspace (z.B. zum Testen):
supabase functions invoke tracking-poll \
  --project-ref <PROJECT_REF> \
  --body '{"workspace_id": "<UUID>"}'
```

## 7. Erwartetes Verhalten

- **Vor Poll**: Deal `status='Unterwegs'`, `tracking='1Z…'`, `arrival_date=NULL`.
- **Nach Poll** (Sendung zugestellt): `status='Angekommen'`,
  `arrival_date=<api timestamp>`. Activity-Log enthält Eintrag
  `tracking_delivered`.
- **Nach Poll** (noch unterwegs): keine Änderung.
- **API-Fehler**: `workspace_carrier_credentials.last_error` wird befüllt;
  der Eintrag bleibt `enabled=true`. Im Settings-UI sieht der User die
  Fehlermeldung.
