---
slug: amazon-tracking-coverage-70pct
priority: 0
plan: true
test_scenario: smoke-amazon-tracking-coverage
---

## User-Frust (3. Iteration)

> "Geht immer noch nicht. Es muss bei ALLEN Amazon-Bestellungen
> funktionieren. Erfolgsfaktor: 70% der Amazon-Bestellungen zeigen
> ein Tracking mit `DE…`."

PR #48 (CONTEXT_TRACKING_RE-Erweiterung) und PR #49 (STRONG-Pattern
`DE\d{8,14}` + In-App-Re-Parse-Trigger) waren beide Schritte vorwärts,
aber die Coverage über das echte User-Postfach ist immer noch zu
niedrig. Diese Task **muss** den Bug komplett lösen, mit harter
Coverage-Metrik.

## Vorgehen

### Phase A — Live-Diagnose (PFLICHT, ohne MCP/REST-API kein Fortschritt)

**Wichtig:** synthetische Fixtures sind verboten — User-Frust kommt
genau daher. ALLES was hier passiert, muss gegen echte
`parsed_messages`-Rows in Cloud-Dev (`uzpkrdymlrrydtuxnvhy`) laufen.

1. Browser-Tester via User-JWT mit `fetch` direkt auf Supabase REST-API:
   ```js
   const url = '/rest/v1/parsed_messages?select=id,subject,shop_key,'
     + 'parsed_payload,received_at&shop_key=eq.amazon'
     + '&order=received_at.desc&limit=200'
   const res = await fetch(SUPABASE_URL + url, {
     headers: { Authorization: 'Bearer ' + jwt, apikey: ANON_KEY }
   })
   ```
2. Filtere clientseitig: alle mit `subject ~ versand|shipped|expédié|enviado|spedito|dispatch|delivery|on its way`.
3. Pro Mail extrahiere:
   - `tracking` (aus parsed_payload.tracking)
   - `trackings` (Array)
   - hat `_raw_html`?
   - subject
4. Berechne Coverage:
   - **`#dpdAmazon-Versand-Mails`** = wie viele Versand-Mails hat der User?
   - **`#mit_tracking`** = wie viele haben tracking != null?
   - **`#mit_DE_tracking`** = wie viele haben tracking matching `^DE\d{8,14}$`?
   - **`#mit_falschem_tracking`** = tracking matching `^[0-9]{14,16}$` (orderingShipmentId-Format)?
   - Output: Coverage-Tabelle als Markdown.

### Phase B — Pattern-Forensik

Pro Versand-Mail OHNE DE-Tracking, die aber `_raw_html` hat:

1. Lade das HTML in den Browser-Tester (via `fetch` UND als Blob).
2. Suche im HTML manuell nach:
   - "tracking number is" / "Sendungsnummer" / "Sendung" / "Paketnummer"
   - DE-Pattern-Varianten: `DE\d+`, `DE-\d+`, `DE\s\d+`
   - Andere Carrier-Codes: TBA, JJD, 1Z, 22-stellig
3. Welche Pattern fehlen im aktuellen Adapter?
4. Listing der gefundenen Pattern in einem Forensik-Memo
   `docs/inbox-forensics/amazon-coverage-2026-05-09.md`.

### Phase C — Adapter-Härtung

Für jedes neu identifizierte Pattern:
1. Test in `inbox_adapters_test.ts` ergänzen.
2. STRONG_TRACKING_PATTERNS oder CONTEXT_TRACKING_RE erweitern.
3. Falls nötig: `findTrackingsInHtml` URL_PATTERNS um neue Carrier-URLs
   ergänzen.
4. Prüfe gegen Phase-A-Daten erneut: berechne erwartete Coverage.

Speziell zu prüfen:
- **Mail ohne `_raw_html`**: hat der Polling-Pfad das HTML mitgesichert?
  Falls nicht, dann Re-Parse hilft nicht — wir müssen IMAP erneut fetchen
  ODER `parsed_payload._raw_html` aus der parsed_payload-Backup-Spalte holen.
- **Mail mit `_raw_html` aber leerem text/plain**: möglicherweise wurde
  `text` in stripBody() bei der Initial-Parse nicht gespeichert. Adapter
  arbeitet trotzdem auf HTML, also OK.
- **Mail mit Subject "X has been dispatched" aber DE im Body in einem
  Bild-Alt-Tag oder JSON-LD**: Adapter muss alle Quellen scannen.

### Phase D — Re-Parse + Verify-Loop

1. Edge Functions (inbox-parse + inbox-poll) re-deployen.
2. Browser-Tester triggert Re-Parse via UI-Button.
3. Re-runs Phase A → neue Coverage-Tabelle.
4. **Wenn Coverage < 70%:** zurück zu Phase B mit den verbleibenden
   Mails ohne DE-Tracking. Iteriere bis Coverage ≥ 70%.
5. Browser-Screenshot der Inbox-Card mit Order-ID `404-5127739-1289903`:
   muss `DE…`-Tracking zeigen. Plus Screenshot der gesamten "Vorschläge"-
   Liste mit visuell sichtbaren DE-Trackings.

---

## ✅ ERFOLGSFAKTOREN (HARTE ABBRUCH-KRITERIEN)

Du brichst die Task **NICHT vorher ab**. Alle Punkte müssen erfüllt sein:

1. **Coverage ≥ 70%** — bei ≥ 5 Amazon-Versand-Mails im echten User-
   Workspace (`test@test.com` oder Account mit `keremo.business2025@gmail.com`-
   Mailbox) zeigen ≥ 70% ein Tracking matching `^DE\d{8,14}$`.
2. **Konkrete User-Mail-Card** mit Order `404-5127739-1289903` zeigt
   im Inbox-UI `DE5455279839` (oder die echte DE-Tracking-Nummer aus
   der Mail). Screenshot beweist's.
3. **Forensik-Memo** in `docs/inbox-forensics/amazon-coverage-2026-05-09.md`
   listet pro Mail-Typ:
   - Welches Pattern matchen wir?
   - Welche Pattern haben wir vorher NICHT gematcht (was geändert)?
   - Coverage-Tabelle vorher/nachher.
4. **`flutter analyze` clean, `flutter test` 117+ grün, `deno test` 29+ grün.**
5. **Live-Verify im Browser**: Re-Parse-Button klicken → SnackBar zeigt
   "X korrigiert" → Inbox-Refresh → DE-Trackings sichtbar.
6. **Edge Functions deployed** auf `uzpkrdymlrrydtuxnvhy`.

Wenn Coverage < 70%: nicht aufgeben. Mind. **5 alternative Pattern-
Versuche** (verschiedene Carrier-Codes, Subject-Heuristiken,
HTML-Tag-Parsing, Body-Sektion-Filter, …). Erst danach als Blocker enden.

## Hinweise

- **KEINE synthetischen Fixtures**. Fixtures sind nur OK wenn sie aus
  ECHTEN Live-Mails (PII-redacted) extrahiert wurden.
- Re-Parse-Trigger via UI-Button nutzen (User-JWT) — nicht via
  Service-Role-Key cURL.
- Falls eine Mail **gar kein** Tracking im HTML hat (manche Lieferungen
  nutzen Pickup/Locker ohne Tracking-Nr): die zählt nicht in den
  Coverage-Nenner.
- Coverage-Definition: `#mit_DE_tracking / #Versand_Mails_die_Tracking_haben_sollten`.
  "haben sollten" = Subject deutet auf Versand hin.
