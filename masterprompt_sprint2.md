# Masterprompt Sprint 2 — Inventory Management App

## Kontext & Ausgangslage

Flutter-Inventarverwaltungs-App mit Supabase-Backend.

**Tech-Stack:**
- Flutter 3.x / Dart SDK ^3.11.5
- Supabase Flutter ^2.8.0 (Projekt-Ref: `uzpkrdymlrrydtuxnvhy`)
- Provider ^6.1.2 für State Management
- Sprache der UI: Deutsch

**Was Sprint 1 bereits lieferte (nicht nochmal implementieren):**
- Validators-Framework (`lib/utils/validators.dart`) mit allen Validierungen
- PasswordStrengthIndicator Widget
- SessionManager mit Idle-Timeout (30 min) und Token-Expiry-Warning
- Soft-Delete auf allen Tabellen (`deleted_at`-Spalte)
- 5 SQL-Migrations in `supabase/migrations/` (20260503000000–400)
- Audit-Spalten: `updated_at`, `updated_by`, `version` + DB-Trigger
- Fehlerübersetzungen in `auth_provider.dart` (Deutsch)
- Logout-Bestätigungsdialog

**Supabase CLI ist verknüpft** (`supabase link --project-ref uzpkrdymlrrydtuxnvhy`).
Das bedeutet: Alle DB-Änderungen als SQL-Migrations unter `supabase/migrations/` ablegen und am Ende `supabase db push` ausführen.

---

## Sprint 2 — Vollständige Aufgabenliste

### A. Social Login (Google + Apple)

#### A.1 Supabase-Konfiguration (via Management API / Dashboard-Hinweis)

Erstelle `supabase/config_hints/social_login_setup.md` mit exakten Schritt-für-Schritt-Anweisungen:
- Google: Wo man die Client-ID und Secret im Supabase Dashboard einträgt
  (Dashboard → Authentication → Providers → Google)
- Apple: Wo man Service ID, Key ID, Team ID und Private Key einträgt
  (Dashboard → Authentication → Providers → Apple)
- Welche Redirect-URL in Google Cloud Console / Apple Developer Portal eingetragen werden muss:
  `https://uzpkrdymlrrydtuxnvhy.supabase.co/auth/v1/callback`
- Deep-Link-Schema: `inventorymanagement://auth/callback` (für Mobile)

#### A.2 pubspec.yaml — neue Dependencies

Füge hinzu (lass bestehende unverändert):
```yaml
  google_sign_in: ^6.2.1
  sign_in_with_apple: ^6.1.2
```

Führe danach `flutter pub get` aus.

#### A.3 Android-Konfiguration

Datei `android/app/src/main/AndroidManifest.xml`:
- Intent-Filter für den Deep-Link `inventorymanagement://auth/callback` hinzufügen:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="inventorymanagement" android:host="auth" />
</intent-filter>
```

#### A.4 iOS-Konfiguration

Datei `ios/Runner/Info.plist`:
- URL-Scheme eintragen:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>inventorymanagement</string></array>
  </dict>
</array>
```
- Für Apple Sign In: `com.apple.developer.applesignin` in `ios/Runner/Runner.entitlements` (Capability) eintragen.

#### A.5 AuthProvider erweitern (`lib/providers/auth_provider.dart`)

Füge zwei neue Methoden hinzu:

```dart
Future<void> signInWithGoogle() async { ... }
Future<void> signInWithApple() async { ... }
```

Beide Methoden:
- Setzen `_isLoading = true` / `notifyListeners()`
- Rufen `Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google/apple, ...)`
- Nutzen `redirectTo: 'inventorymanagement://auth/callback'`
- Übersetzen Fehler via `_humanizeAuthError()` (bereits vorhanden)
- Setzen `_isLoading = false` / `notifyListeners()` im finally-Block

#### A.6 Login-Screen anpassen (`lib/screens/auth/login_screen.dart`)

Unterhalb der E-Mail/Passwort-Felder, aber über dem "Registrieren"-Link:
- Trennlinie mit Text "oder weiter mit"
- Google-Button: weißer Hintergrund, Google-Logo (Material-Icon oder Text "G"), Text "Mit Google anmelden"
- Apple-Button: schwarzer Hintergrund, Apple-Icon (Icons.apple), Text "Mit Apple anmelden", nur anzeigen wenn `Platform.isIOS || Platform.isMacOS`
- Beide Buttons rufen Provider-Methoden auf und zeigen Fehler via SnackBar

---

### B. Password-Reset-Flow (B.1)

#### B.1 ForgotPasswordScreen verbessern (`lib/screens/auth/forgot_password_screen.dart`)

Bereits vorhanden, aber erweitern:
- Nach erfolgreichem Request: Zeige Bestätigungsseite (kein Pop, sondern State-Wechsel) mit Text "Wir haben dir eine E-Mail gesendet. Klicke auf den Link um dein Passwort zurückzusetzen." und "Zurück zum Login"-Button.

#### B.2 ResetPasswordScreen ERSTELLEN (`lib/screens/auth/reset_password_screen.dart`)

Neuer Screen für den Deep-Link-Empfang nach E-Mail-Klick:
- Erkennt automatisch via `Supabase.instance.client.auth.onAuthStateChange` den `AuthChangeEvent.passwordRecovery`
- Zeigt zwei Felder: "Neues Passwort" + "Passwort bestätigen"
- Nutzt `Validators.validatePassword` und den `PasswordStrengthIndicator` (beide aus Sprint 1)
- Bei Submit: `Supabase.instance.client.auth.updateUser(UserAttributes(password: ...))`
- Bei Erfolg: Pop zu Login mit SnackBar "Passwort erfolgreich geändert"
- Fehlerübersetzung via `_humanizeAuthError()` aus AuthProvider

#### B.3 AuthProvider: Deep-Link-Handling

In `AuthProvider._init()` (oder separater Methode):
- Lauscht auf `onAuthStateChange`
- Bei `AuthChangeEvent.passwordRecovery` → navigiert zu `/reset-password`

#### B.4 Router anpassen (`lib/main.dart` oder Router-Datei)

Route `/reset-password` → `ResetPasswordScreen` registrieren.

---

### C. E-Mail-Verifikations-Screen (B.2)

#### C.1 VerifyEmailScreen ERSTELLEN (`lib/screens/auth/verify_email_screen.dart`)

- Wird nach Registrierung angezeigt (wenn E-Mail-Confirm in Supabase aktiviert ist)
- Zeigt: "Bitte bestätige deine E-Mail. Wir haben eine Bestätigungsmail an {email} gesendet."
- Button: "E-Mail erneut senden" → `Supabase.instance.client.auth.resend(type: OtpType.signup, email: email)`
- Button: "Zurück zum Login"
- AuthProvider: Nach Registrierung wenn `session == null && emailConfirmationRequired` → navigiert zu `/verify-email`

---

### D. EAN/GTIN-Felder für InventoryItem (C.1)

#### D.1 Model erweitern (`lib/models/inventory_item.dart`)

Füge hinzu:
```dart
final String? ean; // EAN-13 oder GTIN-14
```
- In Konstruktor, `toJson()`, `fromJson()`, `toSupabaseInsert()`, `fromSupabase()` einbauen
- `copyWith()` erweitern

#### D.2 Migration

Datei: `supabase/migrations/20260503000500_inventory_ean.sql`
```sql
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS ean TEXT;

-- CHECK: entweder NULL oder 8/12/13/14-stellige Ziffer
ALTER TABLE public.inventory_items
  ADD CONSTRAINT inventory_items_ean_format
  CHECK (ean IS NULL OR ean ~ '^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$');

CREATE INDEX IF NOT EXISTS inventory_items_ean_idx
  ON public.inventory_items (user_id, ean)
  WHERE ean IS NOT NULL AND deleted_at IS NULL;
```

#### D.3 Inventory-Screen anpassen (`lib/screens/inventory_screen.dart`)

Im Add/Edit-Formular nach dem SKU-Feld:
- Neues Feld "EAN/GTIN (optional)"
- `keyboardType: TextInputType.number`, `maxLength: 14`
- Validator: `Validators.validateEan(v)` (Modulo-10-Prüfung existiert bereits in validators.dart)

---

### E. Lieferanten-Tabelle (D.2)

#### E.1 Model ERSTELLEN (`lib/models/supplier.dart`)

```dart
class Supplier {
  final String id;      // UUID
  final String name;    // max 100
  final String? contactName;
  final String? email;
  final String? phone;
  final String? website;
  final String? note;
  final bool active;
  final DateTime? deletedAt;
}
```
Mit `toJson()`, `fromJson()`, `toSupabaseInsert()`, `fromSupabase()`, `copyWith()`.

#### E.2 Migration

Datei: `supabase/migrations/20260503000600_suppliers.sql`
```sql
CREATE TABLE IF NOT EXISTS public.suppliers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  contact_name TEXT,
  email       TEXT CHECK (email IS NULL OR email ~ '^[^@]+@[^@]+\.[^@]+$'),
  phone       TEXT,
  website     TEXT,
  note        TEXT CHECK (note IS NULL OR char_length(note) <= 2000),
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by  UUID REFERENCES auth.users(id),
  version     INT NOT NULL DEFAULT 1,
  deleted_at  TIMESTAMPTZ
);

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own suppliers"
  ON public.suppliers FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE UNIQUE INDEX IF NOT EXISTS suppliers_user_name_uidx
  ON public.suppliers (user_id, lower(name))
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS suppliers_active_idx
  ON public.suppliers (user_id)
  WHERE deleted_at IS NULL;

CREATE TRIGGER trg_touch_suppliers
  BEFORE UPDATE ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();
```

Außerdem `supplier_id` (UUID, FK) zu `inventory_items` hinzufügen:
```sql
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;
```

#### E.3 InventoryProvider erweitern (`lib/providers/inventory_provider.dart`)

Analog zu Buyers/Shops:
- `List<Supplier> _suppliers`
- `addSupplier()`, `updateSupplier()`, `deleteSupplier()`
- In `loadAll()` / `CloudSnapshot` einbinden

#### E.4 SupabaseRepository erweitern (`lib/services/supabase_repository.dart`)

CRUD-Methoden für Supplier, analog zu Buyer.
`CloudSnapshot` um `suppliers: List<Supplier>` erweitern.

#### E.5 UI: Lieferanten-Screen

Neuer Screen `lib/screens/suppliers_screen.dart`:
- Liste aller aktiven Lieferanten (DataTable oder ListView)
- FAB: Neuer Lieferant → `AddEditSupplierDialog`
- Jede Zeile: Name, Kontakt-Name, E-Mail, Edit/Delete-Aktionen
- Soft-Delete mit Bestätigungsdialog

Neues Dialog-Widget `lib/widgets/add_edit_supplier_dialog.dart`:
- Felder: Name*, Kontakt-Name, E-Mail, Telefon, Website-URL, Notiz, Aktiv-Toggle
- Nutzt vorhandene Validators (validateRequired, validateEmail, validateUrl, validateNote)
- maxLength überall gesetzt

#### E.6 Navigation

Im Hauptmenü (`lib/screens/main_screen.dart`) einen neuen Tab oder NavigationRail-Eintrag "Lieferanten" (Icons.local_shipping) hinzufügen.

#### E.7 Inventory-Formular: Lieferanten-Dropdown

Im Inventory-Add/Edit-Formular (nach EAN-Feld): Dropdown "Lieferant (optional)" mit allen aktiven Lieferanten + "Kein Lieferant" als Null-Option.

---

### F. Charge/Batch & MHD-Tracking (C.3)

#### F.1 Migration

Datei: `supabase/migrations/20260503000700_batches.sql`
```sql
CREATE TABLE IF NOT EXISTS public.inventory_batches (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id       UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  batch_number  TEXT NOT NULL CHECK (char_length(batch_number) BETWEEN 1 AND 100),
  serial_number TEXT CHECK (serial_number IS NULL OR char_length(serial_number) <= 100),
  mhd           DATE,   -- Mindesthaltbarkeitsdatum
  quantity      INT NOT NULL CHECK (quantity > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);

ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own batches"
  ON public.inventory_batches FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS batches_item_idx
  ON public.inventory_batches (item_id, mhd)
  WHERE deleted_at IS NULL;
```

#### F.2 Model ERSTELLEN (`lib/models/inventory_batch.dart`)

```dart
class InventoryBatch {
  final String id;
  final String itemId;
  final String batchNumber;
  final String? serialNumber;
  final DateTime? mhd;
  final int quantity;
  final DateTime createdAt;
}
```
Mit vollständigem Serialisierungs-Code.

#### F.3 Repository: CRUD für Batches

In `SupabaseRepository`: `insertBatch()`, `updateBatch()`, `deleteBatch()`, `loadBatchesForItem(String itemId)`.

#### F.4 UI: Batch-Liste

Im Inventory-Detail (oder als eigenes Sheet, das sich beim Klick auf ein Item öffnet):
- Zeige alle Chargen für dieses Item
- Spalten: Chargennummer, Seriennummer, MHD (rot wenn < 30 Tage), Menge
- FAB: Charge hinzufügen → einfaches Dialog-Formular

---

### G. Steuersatz & Währung pro Deal (C.4)

#### G.1 Model erweitern (`lib/models/deal.dart`)

Neue Felder:
```dart
final double? taxRate;     // z.B. 0.19 für 19%
final String currency;     // ISO 4217, z.B. "EUR"
```
- Default: `currency = 'EUR'`, `taxRate = null` (= kein MwSt-Tracking)
- Berechnungs-Getter erweitern: `double? get ekNettoPlusMwst => ekNetto != null && taxRate != null ? ekNetto! * (1 + taxRate!) : ekBrutto`
- In alle Serialisierungsmethoden einbauen

#### G.2 Migration

Datei: `supabase/migrations/20260503000800_deal_tax_currency.sql`
```sql
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS tax_rate NUMERIC(5,4) CHECK (tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 1)),
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR'
    CHECK (char_length(currency) = 3);
```

#### G.3 Deal-Dialog anpassen (`lib/widgets/add_edit_deal_dialog.dart`)

- Neues Dropdown "Währung": EUR, USD, GBP, CHF (erweiterbar)
- Neues NumberField "MwSt-Satz %": optional, 0-100, wird als Dezimal gespeichert (19 → 0.19)
- Falls `taxRate` gesetzt: Zeige berechneten Brutto-Preis als `helperText` im EK-Netto-Feld

---

## Technische Rahmenbedingungen für alle Implementierungen

### Allgemein
- **Kein Breaking Change** an bestehenden Modellen ohne Migration
- **Validators.dart** für alle neuen Felder nutzen (validateRequired, validateEmail, validateUrl, validateNote, validateMoney, validatePositiveInt)
- **Soft-Delete** auf allen neuen Tabellen (deleted_at + Partial-Index)
- **RLS** für alle neuen Tabellen aktivieren (Policy: `user_id = auth.uid()`)
- **Audit-Trigger** `touch_row()` auf alle neuen Tabellen (außer inventory_batches — deren update_at ist weniger kritisch)
- **flutter analyze** muss am Ende ohne Fehler und Warnings durchlaufen

### Code-Stil
- Dart: immutable Models, `copyWith()` auf allen Models, `const` wo möglich
- Keine try/catch ohne sinnvolle Fehlerbehandlung (SnackBar oder Provider-Error-State)
- Keine direkten Supabase-Calls in Widgets — alles über InventoryProvider / AuthProvider
- Deutsche UI-Texte überall

### Migrations-Reihenfolge (für `supabase db push`)
1. `20260503000500_inventory_ean.sql`
2. `20260503000600_suppliers.sql`
3. `20260503000700_batches.sql`
4. `20260503000800_deal_tax_currency.sql`

### Ablauf für die KI
1. Alle Migrations-Dateien erstellen
2. `supabase db push` ausführen (Supabase CLI ist verknüpft mit Projekt `uzpkrdymlrrydtuxnvhy`)
3. Prüfen ob Push erfolgreich war (`supabase db diff` oder Ausgabe)
4. pubspec.yaml anpassen und `flutter pub get` ausführen
5. Models erweitern/erstellen
6. Repository erweitern
7. Provider erweitern
8. UI-Screens und Widgets erstellen/anpassen
9. Navigation anpassen
10. `flutter analyze` ausführen und alle Fehler beheben

### Was noch NICHT in Sprint 2 kommt
- Audit-Log-Screen (Sprint 3)
- MFA/TOTP (Sprint 4)
- Multi-Mandanten / Companies (Sprint 4)
- Push-Notifications
- Barcode-Scanner (kommt in Sprint 3 als C.2)

---

## Supabase-Konfiguration die der User manuell machen muss

Nach Abschluss der Code-Änderungen dem User klar sagen:

1. **Google-Provider aktivieren:**
   Dashboard → Authentication → Providers → Google
   - Google-Client-ID (aus Google Cloud Console)
   - Google-Client-Secret
   - Authorized Redirect URI in Google Cloud Console: `https://uzpkrdymlrrydtuxnvhy.supabase.co/auth/v1/callback`

2. **Apple-Provider aktivieren:**
   Dashboard → Authentication → Providers → Apple
   - Service ID (aus Apple Developer Portal)
   - App ID (Bundle ID: `com.yourcompany.inventorymanagement`)
   - Key ID + Team ID + Private Key (.p8)

3. **Redirect-URLs:**
   Dashboard → Authentication → URL Configuration → Redirect URLs:
   - `inventorymanagement://auth/callback`
   - `inventorymanagement://auth/reset`

---

## Ablieferung

Sprint 2 gilt als abgeschlossen wenn:
- [ ] `supabase db push` erfolgreich alle 4 neuen Migrations angewendet hat
- [ ] `flutter analyze` = 0 Fehler, 0 Warnings
- [ ] Google Sign-In Button auf Login-Screen sichtbar
- [ ] Apple Sign-In Button auf iOS/macOS sichtbar
- [ ] Reset-Password-Flow (Screen + Deep-Link-Handler) implementiert
- [ ] EAN-Feld in Inventory-Items vorhanden
- [ ] Lieferanten-Screen mit CRUD vollständig
- [ ] Batch/Charge-Tabelle und grundlegendes CRUD vorhanden
- [ ] Steuersatz + Währung im Deal-Dialog verfügbar
- [ ] Alle neuen DB-Tabellen haben RLS + Soft-Delete + Audit-Trigger

Nach Abschluss dem User einen Smoke-Test-Plan ausgeben analog zu SUPABASE_SETUP.md.
