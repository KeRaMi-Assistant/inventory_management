# Setup: send-notifications (FCM Push-Cron)

> Einmalig nach dem Deploy der Function. Schritt 4 (Cron) erst aktivieren,
> wenn die Function vorhanden ist UND `FCM_SERVICE_ACCOUNT_JSON` gesetzt ist.

## 1. FCM Service-Account JSON setzen

```bash
# Lade die Datei aus Firebase → Project Settings → Service Accounts.
# Dann (Pfad anpassen):
supabase secrets set --project-ref <PROJECT_REF> \
  FCM_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)"
```

## 2. CRON_SECRET setzen

```bash
# Beliebige zufällige Bytes – wird gleich auch in pg_cron eingetragen.
SECRET=$(openssl rand -hex 32)
echo "Generated CRON_SECRET=$SECRET"

supabase secrets set --project-ref <PROJECT_REF> CRON_SECRET="$SECRET"
```

## 3. Function deployen

```bash
supabase functions deploy send-notifications --project-ref <PROJECT_REF>

# Manuell testen (User mit Token nötig — siehe Schritt 5):
supabase functions invoke send-notifications --project-ref <PROJECT_REF>
```

## 4. pg_cron aktivieren (Daily 09:00 Europe/Berlin = 07:00 UTC)

In der Supabase-SQL-Konsole **EINMAL** ausführen — `<SECRET>` und
`<PROJECT_REF>` ersetzen:

```sql
SELECT cron.schedule(
  'send-notifications-daily',
  '0 7 * * *',
  $$
    SELECT net.http_post(
      url := 'https://<PROJECT_REF>.functions.supabase.co/send-notifications',
      headers := jsonb_build_object(
        'Authorization', 'Bearer <SECRET>',
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $$
);
```

Status prüfen:
```sql
SELECT * FROM cron.job;
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
```

Job entfernen (z.B. zum Pausieren):
```sql
SELECT cron.unschedule('send-notifications-daily');
```

## 5. Geräte-Token registrieren

Beim Login schreibt die App den FCM-Token automatisch nach `fcm_tokens`
(siehe `lib/services/push_service.dart`). Erst dann liefert ein
`functions invoke` echte Pushes aus.

## 6. Notification-Toggles

User-Toggles liegen in `notification_preferences`. Die App füllt das
implizit beim ersten Settings-Aufruf; Defaults sind alle "an" mit
14 Tagen MHD-Vorwarnung und 7 Tagen Zahlungs-Mahn-Schwelle.
