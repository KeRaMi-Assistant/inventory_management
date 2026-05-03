# Supabase-Setup für Sprint 1 (Masterprompt 3)

Diese Anleitung listet **konkret und in Reihenfolge** auf, was du im Supabase-
Dashboard erledigen musst, damit die Code-Änderungen aus Sprint 1 wirken.

URL deines Projekts (aus `lib/config/supabase_config.dart` ableitbar):
- Dashboard: <https://supabase.com/dashboard/project/__DEINE_PROJECT_REF__>

> Wenn du die `supabase` CLI mit `supabase link` verknüpft hast, kannst du
> stattdessen `supabase db push` aus dem Repo-Root ausführen — die Migrationen
> liegen unter `supabase/migrations/` und werden in alphabetischer Reihenfolge
> angewendet.

---

## 1. SQL-Migrationen ausführen (Pflicht)

Im Dashboard **SQL Editor** öffnen und die fünf neuen Dateien **in dieser
Reihenfolge** ausführen. Inhalt jeweils per Copy/Paste aus der Datei.

| Reihenfolge | Datei | Was sie tut |
|---|---|---|
| 1 | `supabase/migrations/20260503000000_audit_columns.sql` | `updated_at`, `updated_by`, `version` + Trigger für deals/buyers/shops/inventory_items |
| 2 | `supabase/migrations/20260503000100_soft_delete.sql` | `deleted_at`-Spalten + Partial-Indexe „nur aktive" |
| 3 | `supabase/migrations/20260503000200_check_constraints.sql` | CHECK gegen negative Mengen/Preise und Null-Bewegungen |
| 4 | `supabase/migrations/20260503000300_uniques.sql` | UNIQUE auf `(user_id, lower(name))` für Shops/Buyer und `(user_id, lower(sku))` für Items |
| 5 | `supabase/migrations/20260503000400_indexes.sql` | Zusätzliche Indexe für Status/Buyer/Ticket/Stock-Filter |

**Validierung nach jedem Schritt:** im Dashboard → **Database → Tables** prüfen,
ob die neuen Spalten erscheinen. Bei Fehler nicht mit dem nächsten Schritt
weitermachen.

> **Achtung — bestehende Daten:** Sollte `flutter analyze` lokal ok sein, aber
> die Migration `check_constraints.sql` fehlschlagen, hast du wahrscheinlich
> bereits eine Zeile mit negativem Preis o. ä. Such mit
> `SELECT * FROM deals WHERE quantity <= 0` und korrigiere sie vor der
> Migration.

---

## 2. Auth-Einstellungen (Pflicht)

**Dashboard → Authentication → Providers → Email**

- ✅ **Minimum password length: 8** (statt Default 6).
- ✅ **Require characters: Lower + Upper + Numbers + Symbols** aktivieren
  (matched die Client-Validierung in `Validators.validatePassword`).

**Dashboard → Authentication → Rate Limits** *(falls verfügbar in deinem Plan)*

- Login: 5 Versuche / 15 min ist Default — passt zur App-Fehlermeldung.

---

## 3. E-Mail-Verifikation (für Produktion)

**Dashboard → Authentication → Sign In / Up → Email**

- **Dev/Staging-Projekt:** „Confirm email" **AUS** lassen.
- **Produktions-Projekt:** „Confirm email" **EIN**.
  - In dem Fall **Sprint 2 / B.2** umsetzen (VerifyEmailScreen) — die
    AuthProvider-Hilfsmeldung wird sonst nicht weitergeleitet. Aktuell zeigt
    der Code bei aktivierter Pflichtbestätigung eine SnackBar, das ist OK als
    Übergangslösung.

---

## 4. URL-Konfiguration (für Passwort-Reset später)

**Dashboard → Authentication → URL Configuration**

- **Site URL:** `https://deine-domain.de` (oder `http://localhost:PORT` für Dev).
- **Redirect URLs (Allow list):** je eine Zeile für jede Plattform, z.B.
  - `http://localhost:5000/*`
  - `inventorymanagement://auth/reset` (für Mobile-Deep-Link in Sprint 2)

> Dies ist Vorarbeit für Sprint 2 (Password-Reset-Screen, B.1) — heute schon
> einrichten kostet nichts und verhindert spätere Fehler.

---

## 5. Validierung (Smoke-Test)

Nach den Migrationen einmal in der App durchklicken:

1. **App neu starten** → Login klappt unverändert.
2. **Neuen Deal anlegen** → speichern → in Dashboard `SELECT updated_at,
   version FROM deals ORDER BY id DESC LIMIT 1;` → `version = 1`.
3. **Deal bearbeiten** → `version` muss auf `2` steigen, `updated_at` sich
   aktualisieren, `updated_by` deine `user_id` enthalten.
4. **Deal löschen** → in Dashboard
   `SELECT id, deleted_at FROM deals WHERE id = <id>;` → Zeile existiert
   weiter, `deleted_at` ist gesetzt.
5. **App neu laden** → der gelöschte Deal taucht NICHT mehr auf.
6. **30 Min nichts klicken** → Idle-Timeout schmeißt dich raus.
7. **Registrierung mit „abc"** → Client-Fehler „Mindestens 8 Zeichen", Server-
   seitige Regel würde es ohnehin ablehnen.

---

## 6. Was kommt NICHT in Sprint 1

Bewusst ausgeklammert (kommen in späteren Sprints, siehe `masterprompt3.txt`):

- EAN/GTIN-Felder (C.1) — Sprint 2
- Lieferanten-Tabelle (D.2) — Sprint 2
- Charge/MHD/Seriennummer (C.3) — Sprint 2
- Steuersatz/Währung pro Deal (C.4) — Sprint 2
- Audit-Log (A.6), Auth-Events (A.7) — Sprint 3
- MFA / TOTP (A.8) — Sprint 4
- Companies/Mandanten (D.1, A.9) — Sprint 4

---

## 7. Rollback-Hinweis

Wenn etwas schief geht:

```sql
-- Audit-Spalten zurückrollen (analog für andere Tabellen)
ALTER TABLE public.deals
  DROP COLUMN IF EXISTS updated_at,
  DROP COLUMN IF EXISTS updated_by,
  DROP COLUMN IF EXISTS version;
DROP TRIGGER IF EXISTS trg_touch_deals ON public.deals;
DROP FUNCTION IF EXISTS public.touch_row();

-- Soft-Delete zurückrollen
ALTER TABLE public.deals DROP COLUMN IF EXISTS deleted_at;
DROP INDEX IF EXISTS public.deals_active_idx;

-- CHECK-Constraints
ALTER TABLE public.deals DROP CONSTRAINT IF EXISTS deals_qty_positive;
-- … usw.
```

Code-seitig würde das ohne Migration weiter funktionieren, weil
`deleted_at IS NULL` bei NULL-Spalten harmlos ist und die DELETE-Pfade sich
intern verhalten würden — du müsstest aber im Repository die `update`-Calls
zurück auf `delete` umbiegen.
