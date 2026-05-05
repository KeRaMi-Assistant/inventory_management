# Setup: inbox-poll + inbox-parse (Postfach-Integration)

> Sprint 6. Liest IMAP-Postfächer, erkennt Bestellbestätigungen + Tracking-
> Updates, gleicht sie mit Deals ab. Setup einmalig nach Deploy.

## 1. Master-Key für IMAP-Passwörter setzen

Die Migration `20260507000000_inbox.sql` legt RPCs an, die IMAP-Passwörter
mit `pgp_sym_encrypt` verschlüsseln. Der Schlüssel kommt aus Supabase Vault.

In der SQL-Konsole:

```sql
-- 32 zufällige Bytes (hex) reichen aus.
SELECT vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'hex'),
  'mailbox_master_key',
  'Master-Schlüssel für IMAP-Passwörter (Sprint 6)'
);
```

Prüfen:
```sql
SELECT name, created_at FROM vault.secrets WHERE name = 'mailbox_master_key';
```

> **Self-hosted ohne Vault**: Alternativ `app.mailbox_master_key` per
> `ALTER DATABASE ... SET app.mailbox_master_key = '...'` setzen.

## 2. CRON_SECRET teilen

Wir nutzen denselben `CRON_SECRET` wie für `send-notifications`. Wer den
noch nicht gesetzt hat:

```bash
SECRET=$(openssl rand -hex 32)
supabase secrets set --project-ref <PROJECT_REF> CRON_SECRET="$SECRET"
```

## 3. Functions deployen

```bash
supabase functions deploy inbox-poll  --project-ref <PROJECT_REF>
supabase functions deploy inbox-parse --project-ref <PROJECT_REF>
```

## 4. pg_cron — Polling alle 5 min

In der SQL-Konsole **EINMAL** ausführen:

```sql
SELECT cron.schedule(
  'inbox-poll-5min',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://<PROJECT_REF>.functions.supabase.co/inbox-poll',
      headers := jsonb_build_object(
        'Authorization', 'Bearer <CRON_SECRET>',
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    );
  $$
);
```

Status prüfen:
```sql
SELECT * FROM cron.job WHERE jobname LIKE 'inbox%';
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
```

Pausieren:
```sql
SELECT cron.unschedule('inbox-poll-5min');
```

## 5. Erstes IMAP-Konto in der App anlegen

App → Einstellungen → **Postfach** → **IMAP-Konto hinzufügen**.

- Server / Port / SSL: provider-spezifisch (Gmail: `imap.gmail.com:993`,
  GMX: `imap.gmx.net:993`, web.de: `imap.web.de:993`).
- App-Passwort: Bei Gmail/Microsoft separates App-Passwort generieren —
  reguläre Account-Passwörter funktionieren mit IMAP nicht mehr.

Nach dem Speichern führt der nächste Cron-Tick automatisch den ersten
Poll durch. Erkannte Mails landen im Tab **Inbox**.

## 6. Manuell triggern (Debug)

```bash
supabase functions invoke inbox-poll  --project-ref <PROJECT_REF>
supabase functions invoke inbox-parse --project-ref <PROJECT_REF>
```

`inbox-poll` schreibt rohe Bodys nur sehr kurz ins Feld
`parsed_payload._raw`, damit `inbox-parse` daraus extrahieren kann. Nach
dem Parsen wird der Body durch das normalisierte Adapter-Ergebnis ersetzt
— der vollständige Mail-Body bleibt nicht persistent gespeichert. Die
Tabelle `parsed_messages` wird zusätzlich nach 30 Tagen auto-gelöscht
(siehe Cron-Job `cleanup_inbox_history_daily` in der Migration).
