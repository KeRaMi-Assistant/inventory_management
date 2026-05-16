# DHL-Tracking-Aktivierung via API-Key

**Status:** Draft → Implementation
**Owner:** keramo
**Datum:** 2026-05-16

## Problem

In den Settings unter „Versand" wirft das Speichern eines DHL-API-Keys
`PostgrestException(message: carrier_master_key fehlt: Vault-Secret oder
app.carrier_master_key setzen., code: P0001)`. Damit ist der gesamte
DHL-API-Tracking-Pfad blockiert, obwohl die Architektur seit Sprint 7
(Migration `20260508000000`) End-to-End existiert (DB → RPCs → Edge-Fn →
Adapter → Flutter-UI).

Ursache: Das Vault-Secret `carrier_master_key` wurde im laufenden
Supabase-Projekt nie manuell angelegt — der dokumentierte SETUP-Schritt
in `supabase/functions/tracking-poll/SETUP.md` ist nie gelaufen.

## Ziel

End-to-End funktionierender DHL-API-Tracking-Pfad **ohne** manuelle
Vault-Schritte, mit klarer UX-Trennung „DHL aktiv / DPD+UPS bald
verfügbar".

## Scope

- DHL: vollständig aktiv (Set, Delete, List, Retrack).
- DPD/UPS: Tile bleibt sichtbar, ist aber **disabled** mit „Bald
  verfügbar"-Badge. Backend bleibt vollständig vorhanden (CHECK-Constraint,
  Adapter, Edge-Fn-Logik) — Reaktivierung ist Einzeiler-Konstanten-Change.
- Migration: idempotenter Vault-Secret-Bootstrap, läuft sowohl lokal
  (`supabase db reset`) als auch in Prod (`supabase db push`).
- Fehler-UX: P0001 wird in eine lokalisierte SnackBar mit Help-Link
  übersetzt.

Out-of-Scope:
- DPD/UPS-Aktivierung (separates Backlog-Item, wenn Bedarf entsteht).
- Migration der CHECK-Constraints von `('dhl','dpd','ups')` → `('dhl')`
  (bewusst nicht — Backend bleibt multi-carrier-fähig).
- OAuth-Flow für UPS (war noch nie produktiv; UPS-Adapter erwartet
  vorgefertigten Bearer-Token).
- Re-Build des Settings-Dialogs oder neuen Help-Screens (nur Ergänzungen).

## Future / Nicht-Ziele (separate Backlog-Items)

- **Master-Key-Rotation**: Wenn der Vault-Secret `carrier_master_key`
  rotiert wird, sind alle bestehenden `api_key_encrypted`-Bytea-Blobs
  in `workspace_carrier_credentials` mit dem alten Key verschlüsselt.
  Eine Rotation braucht einen Re-Encrypt-Loop: alten Key noch verfügbar
  halten (Vault-Secret „carrier_master_key_legacy"), alle Rows
  decrypt-with-old + encrypt-with-new, dann legacy-Secret löschen.
  Heute pre-launch + 0 Keys → out-of-scope; aber dokumentiert, damit
  in 12 Monaten kein Lock-out.
- **Eigener SQLSTATE für `_carrier_master_key()`**: `RAISE EXCEPTION
  ... USING ERRCODE = 'KM001'` statt generisches P0001. Macht den
  Flutter-Catch trennscharf (kein Substring-Match mehr).
- **DPD/UPS-Aktivierung**: Wenn DHL stabil läuft + User-Bedarf
  konkret ist. DPD-API-Zugang ist business-partnership-gated, UPS
  braucht OAuth-Bearer-Refresh-Mechanik.

## Architektur-Entscheidungen

### D1: Vault-Secret idempotent in Migration anlegen

Neue Migration `20260516000000_carrier_master_key_bootstrap.sql` führt
einen `DO $$ ... $$`-Block aus:

1. Prüft via Count-Query auf die Supabase-Vault-Secret-Tabelle (Schema
   `vault`, von Supabase managed, [EXT]) mit `name = 'carrier_master_key'`,
   ob bereits ein Eintrag existiert.
2. Wenn `count > 0` → `RAISE NOTICE` und Skip. (Caveat: `vault.secrets.name`
   ist **nicht** unique-constrained — Duplikate sind theoretisch möglich.
   Bei `count > 1` zusätzliche WARNING ausgeben, manuelle Bereinigung
   nötig, aber Migration bleibt grün.)
3. Wenn `count = 0` → `vault.create_secret(encode(
   extensions.gen_random_bytes(32), 'hex'), 'carrier_master_key',
   'Auto-bootstrapped by migration 20260516000000')`.
4. Exception-Handling:
   - **Verschachtelte `BEGIN ... EXCEPTION WHEN ... END;`-Blöcke**
     (kein top-level `DO`-EXCEPTION — propagiert).
   - Spezifische Klauseln: `WHEN undefined_schema THEN`
     (vault-Schema fehlt, Self-Hosting ohne Vault) →
     `RAISE NOTICE 'Vault-Schema fehlt, setze app.carrier_master_key
     manuell via ALTER DATABASE'`; `WHEN undefined_table THEN`
     (vault.secrets fehlt) → analog; `WHEN insufficient_privilege
     THEN` → analog. **Kein `WHEN OTHERS`** — sonst werden echte
     Fehler verschluckt.

Begründung:
- Idempotent (mehrfaches `db reset` / `db push` bleibt safe).
- Klartext-Schlüssel wird zur Migrations-Zeit zufällig generiert und liegt
  ausschließlich in `vault.secrets` (verschlüsselt durch Supabase-Vault).
- Kein Schlüssel im Repo, kein Schlüssel in Migration-History.
- Self-hosting-fähig (Fallback auf GUC ist dokumentiert).

### D2: DHL-Only-UI durch separate `enabledCarrierIds`-Konstante

Im Flutter-Layer trennen wir:
- `supportedCarrierIds` (unverändert: `{'dhl','dpd','ups'}` — Backend-
  Kompatibilität, gibt an, was die DB akzeptiert).
- `enabledCarrierIds` (neu: `{'dhl'}` — gibt an, welche Carrier der User
  aktiv konfigurieren kann).
- **Drift-Schutz:** Assert in einem (neuen) `test/carrier_credential_test.dart`,
  dass `enabledCarrierIds.every(supportedCarrierIds.contains) == true`.

Die UI iteriert weiterhin über `supportedCarrierIds`. `_CarrierTile`
bekommt einen neuen **required Parameter `bool enabled`**:
- `enabled == true`  → `onSet` + `onDelete` werden aufgerufen, Button-Label
  wie bisher.
- `enabled == false` → `onSet` + `onDelete` werden in der Tile auf `null`
  gesetzt (Buttons sind dadurch nicht-tap-bar, **nicht** nur per Tooltip
  geschützt); Tile-Label wechselt auf `l10n.shippingCarrierComingSoon` [NEW],
  visuell mit Badge + Opacity reduziert.

Begründung:
- Reversibilität: DPD/UPS-Aktivierung ist Einzeiler in
  `carrier_credential.dart`.
- Backend-Stabilität: CHECK-Constraint bleibt, alle RPCs akzeptieren
  weiterhin alle drei Carrier — keine Migrations-Churn.
- Discovery: User sieht die Roadmap.
- Tap-Schutz ist Code-strukturell, nicht UX-cosmetic — kein Risiko, dass
  ein versehentlicher Tap doch den Save-Dialog öffnet.

### D3: P0001-Fehler-UX mit gezieltem Catch

Im Settings-Dialog (`_ShippingTabState._showKeyDialog`) wird der
`setApiKey`-Try-Catch wie folgt erweitert:

- **Primär**: `PostgrestException.code == 'P0001'` (SQLSTATE, statisch im
  Postgres-Code-String, nicht locale-abhängig).
- **Sekundär** (Defense-in-Depth gegen Code-Drift): Substring-Match auf
  `'carrier_master_key'` in der Message.
- Wenn beides matched → SnackBar mit `l10n.shippingSetupError` [NEW] und
  Action-Button `l10n.shippingSetupHelpAction` [NEW] → öffnet Help-Section
  „Versand".
- **Sonst** → bestehende generische Fehler-Anzeige (`SnackBar('$e')`).
  Catch-All-Fallback ist Pflicht — kein silent miss.

Nachzieh-Task (out-of-scope für dieses PR, separates Backlog-Item):
Sprint-7-Migration anpassen, `_carrier_master_key()` wirft eigenen
SQLSTATE (z.B. `RAISE EXCEPTION ... USING ERRCODE = 'KM001'`) — damit
substring-match obsolet wird. Vorerst reicht P0001 + Substring.

Begründung:
- Sicherheitsnetz, falls Migration in einer Umgebung (Self-Hosting ohne
  Vault, fehlgeschlagener db push) nicht greift.
- Klare User-Action statt opakem Stack-Trace.
- Help-Section übernimmt die Erklärung (kein Duplikat in der
  SnackBar selbst).

### D4: Help-Inhalt für „Versand: API-Key einrichten"

Neue Hilfe-Sektion (oder Erweiterung bestehender Sektion „Versand"):
1. „Wozu der API-Key?" — kurze Erklärung Live-Tracking-Status.
2. „DHL-Key besorgen" — Link auf `developer.dhl.com/api-reference/shipment-tracking`.
3. „Wo eintragen" — Settings → Versand → DHL-Tile → API-Key.
4. „DPD/UPS" — Hinweis „Bald verfügbar".
5. „Fehler ‚carrier_master_key fehlt‘" — Erklärung + Hinweis auf SETUP.md
   für Self-Hoster.

Pflege via `/update-help --apply` (delegiert an `help-curator`).

## Touches

### Neue Files
- `supabase/migrations/20260516000000_carrier_master_key_bootstrap.sql`

### Geänderte Files
- `lib/models/carrier_credential.dart` (neue `enabledCarrierIds`-Konstante)
- `lib/screens/settings_screen.dart` (Disabled-Variante des `_CarrierTile`,
  P0001-Catch im `_showKeyDialog`)
- `lib/l10n/app_de.arb` + `lib/l10n/app_en.arb` (neue Strings:
  `shippingCarrierComingSoon` [NEW], `shippingSetupError`, `shippingSetupHelpAction`)
- `lib/screens/help_screen.dart` + ARB-Sektion „Versand"
- `supabase/functions/tracking-poll/SETUP.md` (Markdown-Hinweis: Migration
  übernimmt Bootstrap automatisch, manuell nur Backup-Pfad)

### Möglicherweise berührt
- `docs/handbook/07-edge-functions.md` (Edge-Fn-Doku-Sync via doc-updater)
- `docs/handbook/06-database.md` (Migration-Übersicht)

## Risiken

- **R1: Vault-Extension fehlt in Self-Hosting.** Migration darf nicht
  failen — DO-Block fängt Exception und schreibt NOTICE. Verifiziert via
  `supabase db reset` lokal (lokaler Stack hat Vault).
- **R2: Migration läuft in Prod, aber Edge-Fn cached alten Key.** Edge-Fn
  liest den Schlüssel pro Call frisch via `get_carrier_api_key`-RPC —
  kein Cache, kein Restart nötig.
- **R3: User hat schon manuell ein Vault-Secret gleichen Namens.**
  Migration prüft Existenz in der Supabase-Vault-Tabelle (`vault.secrets`,
  Supabase-managed) vor `create_secret` — überschreibt nichts.
- **R4: Disabled-Tile irritiert User.** Tooltip + Badge müssen klar sein.
  Browser-Smoke prüft Phone-Viewport + a11y-Labels.

## Tests

### Pflicht-Tests

- **SQL-Integration-Test** (verpflichtend): Nach `supabase db reset`
  muss Aufruf der existierenden Function `_carrier_master_key()` (aus Sprint-7-Migration `20260508000000`, [EXT]) einen non-empty TEXT
  liefern, **kein** `RAISE EXCEPTION`. Aufruf als
  `service_role`-Kontext via `psql` o.ä. — kann in
  `.claude/scripts/verify/` landen als
  `carrier-master-key-bootstrap.sh`, sodass der Verify-Suite-Lauf
  ihn mitnimmt.
- **Dart-Unit-Test** (verpflichtend, neu): `test/carrier_credential_test.dart`
  prüft `enabledCarrierIds.every(supportedCarrierIds.contains)` — verhindert
  Tippfehler-Drift in den Konstanten.

### Optional
- Widget-Test, der prüft, dass `_CarrierTile` mit `enabled=false` keinen
  Save-Dialog öffnet (Buttons sind null → kein Tap-Handler).

### Manuell (lokal)
1. `supabase db reset` → Migration läuft → `SELECT name FROM
   vault.secrets WHERE name = 'carrier_master_key'` (Supabase-managed,
   [EXT]) liefert 1 Row.
2. Flutter-Web starten → Settings → Versand → DHL-Tile sichtbar +
   tap-bar; DPD/UPS-Tiles sichtbar + disabled (kein Save-Dialog beim Tap).
3. DHL-Key eintragen (8+ Zeichen Dummy) → SnackBar „API-Key gespeichert".
4. `list_carrier_credentials(<workspace>)` → DHL-Row mit `last4`.
5. Optional: echten DHL-Key eintragen, ein Deal mit echter Tracking-Nr
   → Retrack-Button → Status aktualisiert.

### Browser-Smoke (Pre-Ship-Pflicht, UI-Änderung)
- `smoke-full-app-audit` — Theme, Mobile-Overflow, Console-Errors.

## Rollout

1. Migration deployen: `supabase db push --project-ref <PROD>`.
2. **Post-Push-Smoke** gegen Prod-DB: Aufruf der existierenden Function
   `_carrier_master_key()` ([EXT]) muss ein non-empty `TEXT` liefern,
   ohne `EXCEPTION`. Manuell via
   Supabase-SQL-Konsole oder `psql`. Stop-and-investigate, falls die
   Migration in der DO-EXCEPTION-Klausel gelandet ist (Self-Hosting-
   Fallback → User muss `app.carrier_master_key` per ALTER DATABASE
   setzen).
3. App-Build: `flutter build web` (oder regulärer CI-Pfad via `/ship`).
4. Verifikation via Settings → Versand → DHL-Tile saved-Test.
5. Keine Edge-Fn-Redeploy nötig — `get_carrier_api_key` wird pro Call
   ausgeführt, Vault-Lookup live; **kein** PostgREST-Schema-Cache betroffen,
   da Migration nur Vault-Daten anlegt, keine Function-Signaturen ändert.

## Verifikation nach Merge

- [ ] `supabase db reset` lokal grün.
- [ ] `flutter analyze` clean.
- [ ] `flutter test` grün.
- [ ] `smoke-full-app-audit` grün.
- [ ] Manual: DHL-Key in dev-DB speichern funktioniert.
- [ ] Manual: Retrack auf einem Deal mit DHL-Tracking-Nr funktioniert
  (oder bleibt Stand der DHL-API ohne registrierten Account).
