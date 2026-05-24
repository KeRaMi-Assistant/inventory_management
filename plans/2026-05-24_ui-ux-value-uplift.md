# UI/UX Value-Uplift — „premium feel" über Funktion hinaus

**[Committee-Approved 2026-05-24]**

Datum: 2026-05-24
Slug: `ui-ux-value-uplift`
Autor: planner (Opus)
Stakeholder-Wunsch (Original): _„plane weiter, so dass es eine sehr wertvolle software wird, jetzt nur UI/UX"_
Vorgänger-Plan: [`plans/2026-05-22_ui-ux-responsive-overhaul.md`](2026-05-22_ui-ux-responsive-overhaul.md) (Committee-Approved, gemerged via PR #104).

---

## 0. IST-Analyse (Codebase-Fakten, Stand `feature/brand-canlogistics`)

Alle Befunde belegt durch `grep`/`Read` über `lib/`. Pre-Launch-Modus —
aggressives Refactoring OK, Phone darf nicht regredieren.

### 0.1 Was heute schon gut ist

- **Theme-Tokens stabil.** `lib/app_theme.dart` hat Light/Dark-Paritäten +
  `*Of(context)`-Helpers, 5 Paletten. Keine Theme-Überarbeitung nötig.
- **Responsive-Foundation gelegt** (PR #104). `lib/utils/responsive.dart`
  hat Zwei-Achsen-API (`Breakpoints` + `WidthClass` + `ScreenSize`), klare
  Migration Phase A → B.
- **Shared-Widgets existieren.** `lib/widgets/app_screen_scaffold.dart`
  (maxWidth-Wrapper) und `lib/widgets/empty_state.dart` (CTA-Slot,
  card-/centered-Modus, `keySlug`-A11y-Key) sind sauber gebaut und in
  18 Files schon eingesetzt.
- **Skeleton-Loader für Dashboard** existiert (`skeletonizer`-Package
  bereits im `pubspec.yaml`, in `dashboard_screen.dart` mit
  `Key('skeletonLoader')` integriert).
- **Master-Detail-Pattern** funktioniert auf `/inventory` und
  `/warehouse` (PR #104).

### 0.2 Schwachstellen — priorisiert nach „Wert pro Aufwand"

#### P0 — SnackBar-Wildwuchs, fast keine Undo-Aktionen

- **217 `SnackBar(...)`-Konstruktionen über 33 Files**
  (`grep "SnackBar(" lib`). Jeder Call-Site baut sein eigenes
  `SnackBar` mit `content: Text('Foo')` — kein zentraler Builder.
- **Nur 4 `SnackBarAction`-Nutzungen über 3 Files** (`url_helper.dart`,
  `settings_screen.dart`, `inbox_screen.dart`). Heißt: bei
  Delete/Archive/Discard-Aktionen gibt es **keine Undo**. Killer für
  „premium feel" — jeder ernsthafte SaaS-Konkurrent hat Undo.
- Beispiele für stille destruktive Aktionen (Inbox-Mail verwerfen,
  Stocktake schließen, Buyer löschen, Mailbox-Account löschen): nur
  Text-Bestätigung in SnackBar, kein Undo, keine konsistente
  Erfolgs-/Fehler-Farbgebung.

#### P0 — Confirm-Dialog-Fragmentierung

- **28 Files mit `AlertDialog` / `showCupertinoDialog`** —
  `member_remove_confirm_dialog.dart` existiert bereits als
  wiederverwendbare Confirm-Komponente (Council-Output PR-Vorgänger),
  wird aber nur in einem Pfad genutzt. In `settings_screen.dart`,
  `inventory_screen.dart`, `tickets_screen.dart`, … wird der
  destruktive `AlertDialog` jeweils inline neu gebaut, mit
  hardcoded `Colors.red`-Buttons und freier Sprache („Wirklich
  löschen?" vs. „Soll … entfernt werden?").
- **`settings_screen.dart:2271`** hardcoded `'Postfach entfernen'`
  (kein l10n), Body-Text als roher String mit String-Interpolation.
- Inkonsistente Buttons: mal `TextButton` + `ElevatedButton(red)`,
  mal `Cancel` rechts/links, keine destruktive Aktion durch
  Schreiben des Object-Namens bestätigen-Pattern.

#### P0 — Loading-States meist nackt

- **49 `CircularProgressIndicator`-Nutzungen über 32 Files** (`grep`).
- **Nur 1 File nutzt `Skeletonizer`** (`dashboard_screen.dart`).
- Listen-Screens (`deals_screen`, `tickets_screen`, `inbox_screen`,
  `inventory_screen`, `suppliers_screen`, `categories_screen`,
  `warehouses_screen`, `purchase_orders_screen`, `stocktake_screen`,
  `activity_screen`, `product_catalog_screen`) zeigen alle einen
  Standard-Spinner während des ersten Loads. Wahrgenommen als
  „träge". `skeletonizer`-Package ist bereits in `pubspec.yaml`,
  keine neue Dependency nötig.

#### P0 — l10n-Drift in `inbox_screen.dart` + `settings_screen.dart`

`grep "Text\('[A-ZÄÖÜ]…" lib/screens/inbox_screen.dart` findet
mindestens 16 hardcoded deutsche UI-Strings:

- Z. 278: `'Tracking-Daten neu auslesen'` (ListTile-Title in Menü)
- Z. 367: `'Alle Shops'` (Filter-Header)
- Z. 405: `'Alle Status'` (Filter-Header)
- Z. 551: `'Verworfen-Filter geleert.'` (SnackBar)
- Z. 556: `'Zurücksetzen fehlgeschlagen: $e'`
- Z. 606: `'Pollt das Postfach…'`
- Z. 633: `'Polling fehlgeschlagen: ${provider.lastError}'`
- Z. 647: `'Liest Tracking-Daten neu aus…'`
- Z. 724: `'Mail verwerfen?'` (Dialog-Title)
- Z. 737: `'Verwerfen'` (Dialog-Button)
- Z. 747: `'Mail verworfen.'` (SnackBar)
- Z. 752: `'Verwerfen fehlgeschlagen: $e'`
- Z. 884/897/937: `'Konnte Vorschlag nicht abschließen: $e'`,
  `'Ablehnen fehlgeschlagen: $e'`
- Z. 1016/1021/1070/1075: Tracking/Deal-Verknüpfungs-SnackBars
- Z. 1139: `'Details & Tracking anzeigen'` (Tooltip)

`settings_screen.dart`:
- Z. 312: `'Fehler beim Hinzufügen: $e'`
- Z. 540: `'Amazon'` (statisch — vertretbar, Brand-Name)
- Z. 617: `'Supabase'` (Trailing-Label im Mailbox-Tab)
- Z. 2186: `'Rechnungsdaten'`
- Z. 2217: `'Pflichtangaben unvollständig — bitte ergänzen'`
- Z. 2271: `'Postfach entfernen'`
- Z. 2273ff.: kompletter Confirm-Dialog-Body als String
- Z. 2298: `'Löschen fehlgeschlagen: $e'`
- Z. 2389: `'Postfach-Limit erreicht'`
- Z. 2407: `'Plan upgraden'`
- Z. 2741: `'Plan upgraden'` (Duplikat)

Final-Audit aus dem Vorgänger-Plan hat das markiert; Item ist offen.

#### P0 — Hardcoded Colors in `settings_screen.dart`

`settings_screen.dart:2180` `Color(0xFF2563EB)`,
`settings_screen.dart:2194` `Colors.red.shade600`,
`settings_screen.dart:2195` `Color(0xFF64748B)`,
`settings_screen.dart:2202` `Colors.orange`,
`settings_screen.dart:2284` `backgroundColor: Colors.red`. Verstößt
gegen CLAUDE.md (§Dart: „Ausschließlich Farben/Tokens aus
`lib/app_theme.dart`"). Bricht Dark-Mode-Konsistenz.

#### P1 — A11y praktisch nicht vorhanden

`grep "Semantics(" lib` findet **4 Files** (`tracking_status_block.dart`,
`main.dart`, `tracking_banner_improved_detection.dart`,
`inbox_screen.dart`). Bei einer Flutter-Web-App mit
Tablet-/Desktop-Anspruch ist das zu wenig. Buttons, Charts und KPI-
Karten haben keine semantischen Labels. Screen-Reader scheitert auf
Mobile + Web.

Aus dem Vorgänger-Plan: **Epic 2 (NavigationRail)** wurde bewusst
nicht implementiert (Architekt-Verdict: „löst kein Kernproblem"),
aber liefert M3-Keyboard-Navigation und Focus-/Hover-Indikatoren —
direkt verbunden mit dem A11y-Hebel.

#### P1 — Animationen praktisch nicht eingesetzt

`grep "AnimatedSwitcher|AnimatedContainer|TweenAnimation|Hero("`
findet nur 9 Treffer über 6 Files. Tab-Wechsel,
SnackBar-Erscheinung, Empty→Filled-Übergang, FAB-Reveal sind alle
hart. Mikro-Animationen sind günstig (eine Zeile `AnimatedSwitcher`)
und sehr „premium feel"-wirksam.

#### P1 — Form-UX schwach: stille Saves, keine Inline-Validation

- Add/Edit-Dialogs (`add_edit_deal_dialog`, `add_edit_product_dialog`,
  `add_edit_supplier_dialog`, …) validieren beim Submit. Inline-
  Validierung beim Verlassen eines Felds gibt es nicht.
- Keine „unsaved changes"-Warnung beim Schließen eines Dialogs mit
  geänderten Feldern.
- Speichern-Buttons zeigen meist keinen Loading-State (kein
  `disabled` während pending Request → User klickt doppelt).

#### P1 — `_MoreNavSheet` ist heute grenzwertig voll

`main_screen.dart:1067` `_MoreNavSheet`. 6 Einträge auf
360×640-Phone passt knapp, jedes neue Top-Level-Tab kippt es.
Sheet-Title ist heute generisch „Mehr"; Items haben Badge-Support
aber keine Sektionierung (z.B. „Verwalten" vs. „Hilfe").

#### P1 — Reachability auf Phone

AppBar (`52 dp` Höhe, Z. 294 in `app_theme.dart`) hält Actions wie
Help-Icon, Search-Icon, Invites-Bell oben. Auf einem 6,7"-Phone
schlecht mit Daumen erreichbar. Im Vorgänger-Plan als out-of-scope
markiert — heute via Bottom-Sheet-Quick-Actions (FAB-Long-Press
oder eine neue „Aktions"-Bottom-Sheet) lösbar. Eigener kleiner
Epic.

#### P2 — Settings-Architektur: 8 Tabs, viele Toggle-Listen

`settings_screen.dart` hat 8 Tabs (`Buyers`, `Shops`, `Team`,
`Push`, `Postfach`, `Shipping`, `Public profile`, `General`).
Auf Phone als horizontal scrollende TabBar — Findbarkeit leidet.
Mögliche Verbesserung: Settings-Hub-Pattern wie Warehouse-Hub
(Card-Liste mit Sub-Routen), aber: das ist ein größerer Eingriff
mit Risiko von Regressionen. Wird in diesem Plan nur als P2-Epic
mit klarer Abgrenzung aufgenommen.

#### P2 — IA-Doppelung Inventory ↔ Warehouse

11 `MainTab`-Werte, `Inventory` (Lagerbestand) und `Warehouse`
(Warenwirtschaft mit Hub zu PO/Stocktake/Categories/…). Nutzer
fragen sich „warum zwei?" — der Wert eines IA-Redesigns ist hoch,
das Risiko aber ebenso. Aus dem Vorgänger-Plan bewusst auf
späteren IA-Folge-Plan verschoben. Bleibt in diesem Plan
**out-of-scope**, weil es kein reines UI/UX-Item ist (verschiebt
Datenfluss + Navigationspfade).

#### P2 — Notification-Center / Activity-Bell

Aktuell: Activity ist eigener MainTab, Push-Notifications laufen
in Firebase Messaging. Kein dediziertes In-App-Notification-
Center mit Read/Unread-State + Bell-Icon in der AppBar.
Aus „premium feel"-Sicht wertvoll, aber **benötigt Backend**
(Tabelle `notifications` mit `read_at`, RLS, Edge-Function-
Hooks). Wird **explizit als out-of-scope** markiert und für einen
Folge-Plan vorgeschlagen.

---

## 1. Ziel

Die App soll sich **wie ein fertiges, durchdachtes Produkt anfühlen** —
nicht wie eine funktionale Demo. Sechs Hebel mit hohem „Wert pro
Aufwand"-Verhältnis:

1. **Konsistente Mikro-Feedback-Schicht** (zentraler SnackBar-Helper
   mit Undo-Support, Confirm-Dialog-Helper, optimistische Saves).
2. **Loading-Polish** (Skeleton-Loader durchgängig statt nackter
   Spinner).
3. **l10n + Color-Hygiene** in den zwei lautesten Drift-Hotspots
   (Inbox + Settings).
4. **A11y-Basis** (Semantics-Labels für Buttons/KPI-Karten/Charts,
   M3-NavigationRail mit Keyboard-Focus aus dem alten Epic 2).
5. **Form-UX** (Inline-Validation, Loading-State auf Save-Button,
   Unsaved-Changes-Guard).
6. **Visual-Polish + Onboarding-Politur** (Spacing-/Radius-Tokens,
   Animationen für State-Wechsel, Onboarding-Step-Polishing).

Erfolgs-Indikator: `smoke-full-app-audit` zeigt keine neuen
Overflow-/Console-Errors; `flutter test` grün; ein manueller
Real-World-Smoke (5 destruktive Aktionen mit Undo) bestätigt das
Premium-Feel.

---

## 2. Scope

### In Scope

- Zentraler SnackBar-Helper (`lib/widgets/app_feedback.dart` — NEU)
  mit Success/Error/Info-Varianten, Undo-Action-Support, semantischen
  Farben aus `AppTheme`.
- Zentraler Confirm-Dialog-Helper (`lib/widgets/confirm_dialog.dart`
  — NEU, generalisiert aus existierendem
  `lib/widgets/member_remove_confirm_dialog.dart`) für destruktive
  Aktionen. Ablöse für inline-`AlertDialog`-Wildwuchs in 28 Files
  (inkrementell pro Screen, nicht Big-Bang).
- Skeleton-Loader-Migration: `dashboard_screen` ist die Vorlage,
  Migration für 5 weitere Listen-Screens (`inventory`, `deals`,
  `tickets`, `inbox`, `suppliers`).
- l10n-Migration: Alle 16+ hardcoded Strings in `inbox_screen.dart`
  und alle hardcoded Strings in `settings_screen.dart` in
  `app_de.arb` + `app_en.arb`.
- Hardcoded-Color-Cleanup in `settings_screen.dart` (5+ Stellen) —
  Scope ist **55+ Treffer** über alle Modul-Cluster (siehe C5-Split).
- A11y-Pass-1: Semantics-Labels für KPI-Karten (Dashboard),
  Status-Badges (Deals/Tickets/POs), FABs, Bottom-Nav-Items.
- M3-NavigationRail (alter Epic 2): Replace
  `main_screen.dart` Custom-Sidebar durch `NavigationRail` mit
  Hover-/Focus-Indikatoren, Keyboard-Navigation. Phone-Pfad
  unverändert. Branding-Header + `_navVisibility`-Filter bleiben
  erhalten.
- Form-UX-Pass: Save-Button-Loading-State + Unsaved-Changes-Guard
  für die 6 zentralen Add/Edit-Dialogs.
- Visual-Tokens: `AppTheme.spacing*` (NEU) + `AppTheme.radius*`
  (NEU) als zentrale Doubles. Erste Migration der wichtigsten
  Magic-Number-Stellen.
- Mikro-Animationen: `Hero` für Item-Card → Detail-Push (nur Phone).
  `AnimatedSwitcher`-Pattern ist in B1 (Skeleton) built-in, kein
  separater F3-Task.
- Onboarding-Politur: visuelle Hierarchie, Progress-Indikator,
  konsistente CTAs.
- `_MoreNavSheet`-Politur: Sektions-Header, Polish-Style,
  Quick-Search-Eingang im Sheet (kein Vollbild-Override).

### Out of Scope (explizit)

- **Keine neuen Tabellen, keine neuen Edge Functions, keine RLS-
  Änderungen.** Das ist ein UI/UX-Plan.
- **Notification-Center mit Read/Unread-State** — benötigt
  `notifications`-Tabelle + RLS + Edge-Function. **Folge-Plan
  empfohlen.**
- **Settings-Architektur-Refactor zu Hub-Pattern** — zu
  risikoreich für diesen Plan. Wird im IA-Folge-Plan adressiert.
- **IA-Konsolidierung Inventory ↔ Warehouse** — eigener IA-Folge-
  Plan, schreibt Datenflüsse um. **Direkter Nachfolger dieses
  Plans** (siehe §10).
- **Bottom-Sheet-Action-Center für Reachability** — als P2-Hebel
  identifiziert, aber außerhalb der ersten Iteration. Wird in
  Epic G als optionaler Stretch-Task geführt.
- **`StatisticsScreen` embeddable machen** — bewusst aus dem
  Vorgänger-Plan offen gelassen, kein UX-Wert ohne Master-Detail-
  Push. Bleibt offen.

---

## 3. Datenmodell + RLS

**Keine.** Reiner UI/UX-Plan. Keine Migration in
`supabase/migrations/`, keine Tabellen-Änderung, keine Spalte
hinzu/entfernt.

Falls Epic D (Form-UX) wirklich einen `dismissed_changes`-Marker
braucht, wird das ausschließlich lokal in einem Provider gehalten
(SharedPreferences ist akzeptabel) — kein Supabase-Roundtrip.

---

## 4. API / Edge Functions

**Keine.** Kein Endpoint geändert, kein neuer Endpoint angelegt.

---

## 5. UI + l10n-Keys

### 5.1 Neue Widgets / Helpers

| Datei | Zweck | Public-API |
|---|---|---|
| `lib/widgets/app_feedback.dart` (NEU) | Zentrale SnackBar-Factory | `AppFeedback.success(context, message, {undo})`, `AppFeedback.error(context, message)`, `AppFeedback.info(context, message)`, `AppFeedback.loading(context, message)` |
| `lib/widgets/confirm_dialog.dart` (NEU, generalisiert aus `member_remove_confirm_dialog.dart`) | Destruktiver Confirm | `showConfirmDialog({title, message, confirmLabel, isDestructive, requireTypeName, confirmTypeNameValue})` |
| `lib/widgets/skeletons/list_skeleton.dart` (NEU) | Listen-Skeleton-Loader | `ListSkeleton({itemCount, itemHeight})` |
| `lib/widgets/skeletons/card_skeleton.dart` (NEU) | KPI/Deal-Card-Skeleton | `CardSkeleton({width, height})` |
| `lib/widgets/unsaved_changes_guard.dart` (NEU) | `PopScope`-Wrapper (Flutter 3.27+ ersetzt `WillPopScope`) | `UnsavedChangesGuard({isDirty, child})` |
| `lib/app_theme.dart` (ERWEITERT) | Spacing-/Radius-Tokens | `AppTheme.space2, space4, space8, space12, space16, space24`, `radiusSm, radiusMd, radiusLg` |

**Bug-Hunter-Fix (PopScope-Pattern):**
`PopScope` muss INNERHALB des Dialog-Trees liegen, nicht um den
`showDialog`-Call. Pattern:

```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => PopScope(
    canPop: !isDirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop) {
        final discard = await showConfirmDiscardDialog(ctx);
        if (discard == true && ctx.mounted) Navigator.of(ctx).pop();
      }
    },
    child: AlertDialog(/* ... */),
  ),
);
```

**Confirm-Dialog Phone-Variante (UX/Mobile-Fix):**
Auf Phone (`MediaQuery.sizeOf(context).width < Breakpoints.phone`)
wird der Confirm-Dialog als `showModalBottomSheet(isScrollControlled: true)`
gerendert mit `Padding(MediaQuery.viewInsetsOf(context))` für die
Keyboard-Awareness des optionalen `requireTypeName`-TextFields. Auf
Desktop bleibt `Dialog`. Touch-Targets ≥ 48 dp Pflicht
(Confirm- + Cancel-Button + Close-Icon).

**AppFeedback-Spec (Bug-Hunter-Fix):**

- **SnackBar-Margin** muss Phone-Bottom-Nav respektieren:
  ```dart
  margin: EdgeInsets.only(
    left: 16, right: 16,
    bottom: MediaQuery.paddingOf(context).bottom
      + (isPhoneViewport(context) ? kBottomNavHeight + 8 : 16),
  )
  ```
  `behavior: SnackBarBehavior.floating` ist zwingend (sonst greift
  `margin` nicht).
- **Dialog-Context-Pattern:** Wenn AppFeedback aus einem
  Dialog-Confirm gerufen wird, muss der `ScaffoldMessenger` vom
  Root-Scaffold capturiert werden **vor** `showDialog`:
  ```dart
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showConfirmDialog(/* ... */);
  if (confirmed == true) {
    // ... action
    AppFeedback.success(messenger, l10n.feedbackSuccessDefault);
  }
  ```
  Alternative: `AppFeedback.*` akzeptiert `ScaffoldMessengerState`
  zusätzlich zu `BuildContext` (Overload).

### 5.1.1 A11y-Key-Inventar (Browser-Tester + Smoke-Selektoren)

Pflicht-Keys für die neuen Widgets — landen in `_page-registry.md`
als Selektor-Anker:

```
Key('appFeedbackSuccess')
Key('appFeedbackError')
Key('appFeedbackInfo')
Key('appFeedbackUndoAction')

Key('confirmDialog')
Key('confirmDialog-confirm')
Key('confirmDialog-cancel')
Key('confirmDialog-typeName-field')   // nur wenn requireTypeName

Key('skeletonLoader')                  // Konvention aus dashboard_screen

Key('unsavedChangesGuard-dialog')
Key('unsavedChangesGuard-discard')

Key('mainNavRail')
Key('navRailDestination-<tab>')        // pro MainTab.value (snake-case)
```

### 5.2 Geänderte Screens (inkrementell)

| Screen | Änderung |
|---|---|
| `lib/main.dart` | `AccessibilityTools`-Builder via `kDebugMode` einklinken (DevDep, siehe Epic D). |
| `lib/screens/main_screen.dart` | Custom-Sidebar → `NavigationRail` (Branding-Header + `_navVisibility`-Filter behalten). `_MoreNavSheet` mit Section-Header + Quick-Search-Tile. |
| `lib/screens/dashboard_screen.dart` | KPI-Karten `Semantics`-Labels. Skeleton schon vorhanden. |
| `lib/screens/inbox_screen.dart` | 16 hardcoded Strings → l10n. SnackBars → `AppFeedback`. Confirm-Dialog → `showConfirmDialog`. Skeleton-Loader statt Spinner. |
| `lib/screens/settings_screen.dart` | Hardcoded Strings + Colors aufräumen. Confirm-Dialog für „Postfach entfernen" → `showConfirmDialog`. |
| `lib/screens/deals_screen.dart` | Skeleton statt Spinner. Status-Badges `Semantics`. SnackBars → `AppFeedback`. |
| `lib/screens/tickets_screen.dart` | Skeleton, Confirm-Dialog, SnackBars zentralisiert. |
| `lib/screens/inventory_screen.dart` | Skeleton, AppFeedback, Confirm-Dialog für Delete. |
| `lib/screens/suppliers_screen.dart` | Skeleton, AppFeedback, Confirm-Dialog. |
| `lib/screens/onboarding_screen.dart` | Progress-Indikator polish, AnimatedSwitcher für Step-Transitions, AppFeedback statt rohe SnackBars. |
| `lib/widgets/add_edit_deal_dialog.dart` | Save-Button-Loading-State, UnsavedChangesGuard. |
| `lib/widgets/add_edit_product_dialog.dart` | dito |
| `lib/widgets/add_edit_supplier_dialog.dart` | dito |
| `lib/widgets/add_edit_buyer_dialog.dart` | dito |
| `lib/widgets/add_edit_shop_dialog.dart` | dito |
| `lib/widgets/add_edit_mailbox_dialog.dart` | dito |

**Bug-Hunter-Fix (D1 NavigationRail-API):**

- `extended: true` (Container ≥ 1200 dp) → `labelType: null` (sonst
  Flutter-Assertion). `extended: false` (900–1199 dp) →
  `labelType: NavigationRailLabelType.all`.
- Bei 11 `MainTab.values`: `NavigationRail.scrollable: true`
  (Flutter 3.27+) oder Tab-Subset (Top-N), nicht alle 11 als
  Destinations rendern.
- **Branding-Header bleibt 1:1:**
  `leading: SizedBox(height: 56, child: BrandMark + optional BrandWordmark)`,
  identisch zur heutigen `_Sidebar`.
- **`_navVisibility`-Filter erhalten:** `NavigationRail.destinations`
  wird aus der gefilterten `MainTab`-Liste gebaut (Free-Plan-Gating
  + Feature-Flags bleiben aktiv). Akzeptanzkriterium: Free-User
  sieht keine Premium-Tabs im Rail.
- **Index-Mapping-Schicht:** Der dichte `int` aus
  `NavigationRail.selectedIndex` ist NICHT `MainTab.index` (Tabs
  können ausgeblendet sein). Helper-Funktion
  `visibleTabAtRailIndex(int) → MainTab` Pflicht.

### 5.3 Neue ARB-Keys

Die Liste ist nicht final; sie wird beim Implementieren von
Epic C (l10n-Cleanup) konkretisiert. Pflicht-Vokabular:

**Feedback (Epic A):**
- `feedbackSuccessDefault` — DE: „Gespeichert" / EN: „Saved"
- `feedbackErrorDefault` — DE: „Etwas ist schiefgelaufen" / EN:
  „Something went wrong"
- `feedbackUndo` — DE: „Rückgängig" / EN: „Undo"
- `feedbackDismiss` — DE: „Schließen" / EN: „Dismiss"
- `feedbackLoading` — DE: „Wird verarbeitet…" / EN: „Working…"

**Confirm (Epic A):**
- `confirmDestructiveTitle` — DE: „Wirklich löschen?" / EN: „Really delete?"
- `confirmDestructiveBody` — DE: „Diese Aktion kann nicht rückgängig gemacht werden." / EN: „This action cannot be undone."
- `confirmTypeNamePrompt` — DE: „Gib „{name}" ein, um zu bestätigen." / EN: „Type \"{name}\" to confirm." (Platzhalter `{name}`; **EN verwendet ASCII-Quotes, DE deutsche Anführungszeichen**)

**Form (Epic D):**
- `formUnsavedTitle` — DE: „Ungespeicherte Änderungen" / EN: „Unsaved changes"
- `formUnsavedBody` — DE: „Du hast Änderungen, die noch nicht gespeichert sind." / EN: „You have unsaved changes."
- `formDiscardChanges` — DE: „Verwerfen" / EN: „Discard"
- `formSaving` — DE: „Speichern…" / EN: „Saving…"

**Inbox-Cleanup (Epic C):** (16+ Keys; finale Namen vom
`l10n-checker`-Agent geprüft)
- `inboxRetrackTrackings`, `inboxFilterAllShops`,
  `inboxFilterAllStatus`, `inboxDiscardFilterCleared`,
  `inboxResetFailed`, `inboxPolling`, `inboxPollingFailed`,
  `inboxRetracking`, `inboxDiscardMailTitle`,
  `inboxDiscardMail`, `inboxMailDiscarded`,
  `inboxDiscardFailed`, `inboxSuggestionCompleteFailed`,
  `inboxSuggestionRejectFailed`, `inboxTrackingAdopted` (mit
  Platzhalter `{dealId}`), `inboxTrackingAdoptionFailed`,
  `inboxSuggestionLinked` (`{dealId}`), `inboxLinkFailed`,
  `inboxDetailsAndTracking` (Tooltip)

**Settings-Cleanup (Epic C):**
- `settingsBillingDataTitle` — „Rechnungsdaten" / „Billing details"
- `settingsBillingIncomplete` — „Pflichtangaben unvollständig — bitte ergänzen" / „Required info missing — please complete"
- `settingsMailboxRemoveTitle` — „Postfach entfernen" / „Remove mailbox"
- `settingsMailboxRemoveBody` (Platzhalter `{label}`)
- `settingsMailboxDeleteFailed` — „Löschen fehlgeschlagen: {error}"
- `settingsMailboxLimitReached` — „Postfach-Limit erreicht"
- `settingsPlanUpgrade` — „Plan upgraden" / „Upgrade plan"
- `settingsAddFailed` (Platzhalter `{error}`)

**Onboarding (Epic F):**
- `onboardingStepLabel` — „Schritt {current} von {total}" /
  „Step {current} of {total}"

### 5.4 Visual-Tokens

`lib/app_theme.dart` bekommt neue statische Doubles:

```dart
// Spacing-Skala (4-px-Basis, an Material 3 angelehnt)
static const double space2 = 2;
static const double space4 = 4;
static const double space8 = 8;
static const double space12 = 12;
static const double space16 = 16;
static const double space24 = 24;
static const double space32 = 32;

// Border-Radii (an bestehende Theme-Werte angepasst)
static const double radiusSm = 6;   // Chips
static const double radiusMd = 8;   // Cards (heute Default)
static const double radiusLg = 12;  // Dialogs, FAB
static const double radiusXl = 16;
```

Migration verhaltensneutral: nur Magic-Number-Indirektion (Phase A
analog zum Responsive-Overhaul-Pattern). Keine Werte ändern in
dieser Iteration.

### 5.5 A11y-Pass-1 — Semantics-Labels

Pflicht-Wrapper:
- **KPI-Karten** (`dashboard_screen`, `statistics_screen`):
  `Semantics(label: 'KPI: $title, Wert $value, $trend')`.
- **Status-Badges** (`deal_card`, `deal_table`, `tickets_screen`,
  `purchase_order_detail`): `Semantics(label: 'Status: $statusName')`.
- **Bottom-Nav-Items**: `Semantics(label: tabName, selected: …)`.
- **FABs**: `Semantics(button: true, label: …)`.
- **Charts** (`statistics_screen`): `Semantics(label: chartSummary)`
  als textuelle Zusammenfassung.

---

## 6. Tests

### 6.1 Widget-Tests (`test/widgets/`)

| Test-File | Coverage |
|---|---|
| `test/widgets/app_feedback_test.dart` (NEU) | success/error/info-Konfiguration, Undo-Callback wird gerufen, semantische Farben pro Variante. |
| `test/widgets/confirm_dialog_test.dart` (NEU) | Confirm gibt `true` bei Bestätigung, `false`/`null` bei Cancel, `requireTypeName` blockt Submit bis Name korrekt eingegeben. Unicode-Bidi-Sanitize testen (RTL-Override-Char darf nicht durch). |
| `test/widgets/skeletons/list_skeleton_test.dart` (NEU) | rendert `itemCount` Skeleton-Items. |
| `test/widgets/unsaved_changes_guard_test.dart` (NEU) | bei `isDirty=true` zeigt Discard-Confirm beim Pop, bei `isDirty=false` poppt direkt. |

### 6.2 Smoke-Tests (`browser-tester`)

Bevor `/ship` getriggert wird, läuft Pflicht-`smoke-full-app-audit`
(siehe CLAUDE.md §Browser-Smoke-Tests). Zusätzlich neue
Smoke-Szenarien:

- `smoke-feedback-undo` — Inbox-Mail verwerfen → Undo-Action im
  SnackBar tippen → Mail kommt zurück.
- `smoke-confirm-dialog` — Mailbox-Account löschen → Confirm-
  Dialog erscheint → Cancel poppt nichts.
- `smoke-skeleton` — Dashboard, Inventory, Inbox: First-Load zeigt
  Skeleton statt Spinner. Keine Race-Condition (Skeleton aktiv
  nur wenn `isLoading && data.isEmpty`).
- `smoke-a11y-labels` — Light + Dark, Phone + Desktop: KPI-Karten
  haben Semantics-Label, Bottom-Nav-Items haben `selected`-State.
- `smoke-keyboard-nav` (Desktop) — Tab durch alle NavigationRail-
  Items, Focus-Ring sichtbar, Enter aktiviert.
- `smoke-form-unsaved` — Add-Deal-Dialog: Feld ändern, schließen-X
  → UnsavedChangesGuard zeigt Discard-Confirm.
- `smoke-form-keyboard-phone` — Add-Edit-Dialogs auf Phone-Viewport:
  Tastatur öffnet sich, TextField wird NICHT verdeckt
  (`MediaQuery.viewInsetsOf` greift). Confirm-Dialog mit
  `requireTypeName` testet dasselbe in der BottomSheet-Variante.
- `smoke-nav-feature-gating` — Free-User-Login: `NavigationRail`
  zeigt KEINE Premium-Tabs. Switch zu Premium-Account → Tabs
  erscheinen. `_navVisibility`-Filter-Regression-Test.
- `smoke-hero-no-desktop-regression` — Desktop-Viewport: Hero-
  Animation in Inventory → Detail darf NICHT triggern (Master-
  Detail bleibt ohne Push). Phone-Viewport: Hero animiert.

### 6.3 Manuelle Real-World-Smokes (Pre-Ship)

Vor jedem `/ship`-Call eines Epics:
- 5 destruktive Aktionen mit Undo (Mail verwerfen, Deal löschen,
  Supplier löschen, Mailbox entfernen, Discard-Filter leeren) —
  alle zeigen Undo, alle stellen tatsächlich wieder her wenn
  möglich.
- Dark-Mode-Audit der geänderten Screens (Kontrast, Border-
  Sichtbarkeit, keine hardcoded Colors mehr).

---

## 7. Risiken

1. **Big-Bang-Migration explodiert.** SnackBar-Migration über 33
   Files / Confirm-Dialog über 28 Files / Color-Cleanup mit 55+
   Treffern. Mitigation: **inkrementell pro Screen / pro Cluster**,
   jeder Task atomar, keine Pflicht zur Voll-Migration in einem PR.
   C5 ist in C5a/C5b/C5c gesplittet, A4 in A4a/b/c, A6 in 16
   Sub-Tasks.
2. **Skeleton-Loader führt zu Layout-Flickern.** `Skeletonizer`
   benötigt korrektes `enabled`-Flag (siehe Dashboard:
   `isLoading && data.isEmpty`). Race-Condition-Test in jedem
   Skeleton-Task Pflicht. Provider muss `bool get isLoading` UND
   `_initialLoadAttempted`-Flag exponieren (B0 liefert die
   Vereinheitlichung).
3. **NavigationRail bricht Maus-Hover-Verhalten + Brand-Optik.**
   Heutige Custom-Sidebar hat eigene Hover/Selected-Logik UND
   trägt die Brand. M3-NavigationRail tauscht die Optik leicht aus.
   Mitigation: Branding-Header (Logo + Wordmark) wird 1:1
   übernommen (D1-Spec). Vor Merge: visueller Vorher/Nachher-
   Vergleich im PR-Body Pflicht.
4. **Hardcoded-Color-Cleanup bricht Dark-Mode oder Brand-Look.**
   Mitigation: `grep "Colors\."` und `grep "Color(0x"` pro Cluster
   nach jedem Sub-Task; jeder Hit im Diff manuell prüfen.
   **Brand-Color-Whitelist** (bleibt hardcoded):
   - Discord-Brand `Color(0xFF5865F2)` (in `inbox_screen.dart` für
     Discord-Suggestion-Card)
   - Amazon-Brand `Color(0xFFD97706)` (Amazon-Adapter-Icon)
   - Weitere Carrier-/Shop-Brand-Farben nach derselben Regel: Brand
     ist Identität, kein Theme-Token.
5. **A11y-Labels können bestehende Browser-Tests-Selektoren
   stören.** `Key('...')`-Selektoren bleiben unberührt, aber
   `find.byTooltip` o.ä. kann brechen. Mitigation: `Semantics`
   immer als Wrapper (Outer-Layer), nie als Replacement von
   bestehenden Widgets.
6. **`UnsavedChangesGuard` blockiert legitimes Schließen** wenn
   Dirty-Detection einen False-Positive hat (z.B. initialer
   Wert ≠ Cursor-Wert). Mitigation: Dirty-Flag muss
   `originalValue != currentValue` exakt prüfen, nicht „User
   hat ins Feld geklickt".
7. **`l10n-checker`-Auto-Fix produziert sterile EN-Übersetzungen**
   für die Inbox-/Settings-Strings. Mitigation: Übersetzungen
   manuell idiomatisch im Task selbst, nicht via Auto-Fix.
8. **`_MoreNavSheet`-Quick-Search-Tile kollidiert mit Cmd+K-
   Global-Search.** Mitigation: Tile öffnet dasselbe
   `global_search_dialog`, kein neuer Pfad.
9. **Pre-Launch-Vorteil verbrannt.** Wenn Plan zu groß wird,
   verschiebt sich Launch. Mitigation: Epics A–C als Minimum-
   Viable-Polish; Epics D–G als Stretch.
10. **Phone-Regression.** Master-Detail-Layout aus PR #104 darf
    durch keine A11y-Wrapper, kein FAB-Animations-Tweak und kein
    Confirm-Dialog-Refactor brechen. Mitigation: Phone-First-
    Tests in jedem PR (`browser-tester` mit `mobile-overflow`
    Pflicht).
11. **`accessibility_tools`-Builder feuert False-Positives** auf
    Charts (`statistics_screen`-Subtree), wo `Semantics` als
    textuelle Summary genügt und die einzelnen Chart-Slices nicht
    labeln muss. Mitigation:
    `AccessibilityTools(checkSemanticLabels: false)` für diesen
    Subtree, alternativ `ExcludeSemantics`-Wrapper um den
    Chart-Builder.
12. **Optimistic-Undo ist RLS-blockiert.** Nicht jeder Soft-Delete
    erlaubt UPDATE durch denselben User (z.B. workspace-shared
    Resources mit `deleted_by != auth.uid()`). A7-Pre-Audit
    klärt das pro Pfad, bevor A3/A5 Undo umsetzen.
13. **NavigationRail-Index-Mapping-Bug.** Bei ausgeblendeten Tabs
    (Free-Plan) ist `selectedIndex` ≠ `MainTab.index`. Ohne
    Helper-Funktion zeigt der Rail die falsche Selection.
    Mitigation: `visibleTabAtRailIndex`-Helper + Unit-Test.

---

## 8. Tasks

Format: jeder Task atomar (1 PR-fähig), mit `agent`-, `model`- und
`depends`-Tag. Reihenfolge ist Empfehlung, parallele Bearbeitung
möglich wo `depends` leer.

### Epic A — Mikro-Feedback-Schicht (P0)

- [ ] **A1** Implementiere `lib/widgets/app_feedback.dart` mit
  Success/Error/Info/Loading-Varianten, Undo-Action-Slot,
  semantische Farben aus `AppTheme`, Phone-Bottom-Margin-Berechnung
  (siehe §5.1 AppFeedback-Spec), Dialog-Context-Pattern als
  Doc-Comment + Overload für `ScaffoldMessengerState`. ARB-Keys
  für Default-Messages anlegen. Keys: `appFeedbackSuccess`,
  `appFeedbackError`, `appFeedbackInfo`, `appFeedbackUndoAction`.
  Unit-Tests in `test/widgets/app_feedback_test.dart`.
  `agent: ui-builder` · `model: sonnet` · `depends: []`

- [ ] **A2** Generalisiere existierendes
  `lib/widgets/member_remove_confirm_dialog.dart` (53 Z., A11y/l10n
  ready) zu neuem `lib/widgets/confirm_dialog.dart`. Parametrische
  Public-API: `title`, `message`, `confirmLabel`, `isDestructive`,
  `requireTypeName?`, `confirmTypeNameValue?`. Phone-Variante als
  `showModalBottomSheet` mit `viewInsetsOf` (siehe §5.1).
  PopScope-Pattern korrekt im Dialog-Tree. Unicode-Bidi-Sanitize
  bei `requireTypeName` (RTL-Override-Chars rausfiltern).
  `MemberRemoveConfirmDialog.show()` wird Thin-Wrapper auf
  `showConfirmDialog`. Keys: `confirmDialog`, `confirmDialog-confirm`,
  `confirmDialog-cancel`, `confirmDialog-typeName-field`.
  Unit-Tests, `HapticFeedback.lightImpact()` bei destruktivem
  Confirm.
  `agent: ui-builder` · `model: sonnet` · `depends: []`

- [x] **A3** Migriere `inbox_screen.dart` SnackBars (~15 Stellen)
  auf `AppFeedback.*`. Migriere „Mail verwerfen"-Dialog (Z. 720ff.)
  auf `showConfirmDialog`. Undo-Action bei „Mail verwerfen" +
  „Discard-Filter geleert" (Optimistic-Restore aus A7-Audit).
  Rohe Exception-Strings (`'$e'`) sanitisieren — nur generic
  `l10n.feedbackErrorDefault` ODER bekannte Error-Codes mappen.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2, A7, C1]`

- [ ] **A4a** Migriere SnackBars im Mailbox-Tab von
  `settings_screen.dart` (~Z. 280–620, 18+ Stellen) auf
  `AppFeedback.*`. Confirm-Dialog für „Postfach entfernen"
  (Z. 2266ff.) auf `showConfirmDialog` mit `requireTypeName`
  (Account-Label als `confirmTypeNameValue`). Exception-Strings
  sanitisieren.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2, C2]`

- [ ] **A4b** Migriere SnackBars im Team-/Buyer-/Shop-Tab von
  `settings_screen.dart` (~22 Stellen) auf `AppFeedback.*`.
  Inline-Confirm-Dialogs auf `showConfirmDialog`.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2, C2]`

- [ ] **A4c** Migriere SnackBars im Subscription-/Plan-Bereich von
  `settings_screen.dart` (~16 Stellen) auf `AppFeedback.*`.
  Plan-Upgrade-Hinweise als `AppFeedback.info`.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2, C2]`

- [x] **A5** Migriere `deals_screen.dart` + `deal_table.dart`
  SnackBars auf `AppFeedback`. Confirm-Dialog für „Deal
  löschen" auf `showConfirmDialog(isDestructive: true)`.
  Undo-Support für Delete (Optimistic-Restore aus A7-Audit;
  falls A7 ergibt „nicht möglich" → kein Undo, nur Confirm).
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2, A7]`

- [x] **A6a** `tickets_screen.dart` SnackBars + Confirm-Dialogs auf
  zentrale Helpers.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6b** `inventory_screen.dart` SnackBars + Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6c** `suppliers_screen.dart` SnackBars + Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6d** `warehouses_screen.dart` SnackBars + Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6e** `categories_screen.dart` SnackBars + Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6f** `stocktake_screen.dart` SnackBars + Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6g** `purchase_orders_screen.dart` SnackBars +
  Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6h** `purchase_order_detail_screen.dart` SnackBars +
  Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6i** `stocktake_detail_screen.dart` SnackBars +
  Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [x] **A6j** `dashboard_screen.dart` SnackBars (CTA-Errors,
  Refresh-Failures).
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6k** `onboarding_screen.dart` SnackBars (vor F5).
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6l** `statistics_screen.dart` SnackBars.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6m** `invite_member_dialog.dart` SnackBars.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6n** `invites_bell.dart` SnackBars.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6o** `create_workspace_dialog.dart` SnackBars.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [ ] **A6p** `inbox_message_details_screen.dart` SnackBars +
  Confirm-Dialogs.
  `agent: flutter-coder` · `model: sonnet` · `depends: [A1, A2]`

- [x] **A7** **Undo-Audit (Pre-Flight, blockierend für A3/A5).** Pro
  Delete-Pfad (Inbox-Mail verwerfen, Deal löschen, Supplier
  löschen, Mailbox entfernen, Buyer/Shop entfernen, Ticket
  schließen) prüfen: ist Optimistic-Local-Restore machbar
  (Provider-Cache-Marker + Delayed-Commit, kein DB-Touch bis
  SnackBar-Dismiss)? RLS-Check ob Soft-Delete-Rows UPDATE-bar
  sind durch denselben User (z.B. `deleted_at = null`-Update).
  Output: Markdown-Report unter
  `plans/2026-05-24_undo-audit.md` mit Tabelle „Pfad |
  Optimistic-Möglich | RLS-OK | Empfohlene Pattern". A3 und A5
  hängen daran.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **A8** `_page-registry.md` aktualisieren: ConfirmDialog als
  Sub-Route hinzufügen, NavigationRail-Notiz im `/main`-Eintrag
  ergänzen, Skeleton-Loader-Konvention (`Key('skeletonLoader')`)
  dokumentieren, AppFeedback als Modal-Layer-Note.
  `agent: doc-updater` · `model: sonnet` · `depends: [A1, A2, B1, D1]`

### Epic B — Loading-Polish (P0)

- [x] **B0** **Provider-API-Harmonisierung (blockierend für B2/B3/B4).**
  Vereinheitliche `bool get isLoading` in allen Providern, die
  Skeleton bekommen (`InventoryProvider`, `DealsProvider`,
  `TicketsProvider`, `InboxProvider`, `SuppliersProvider`). Plus
  `bool get initialLoadAttempted` (true sobald erster
  `fetch`-Call returned, egal ob success/error). Race-Condition-
  Pattern: Skeleton aktiv nur bei `isLoading && !initialLoadAttempted`.
  Unit-Tests pro Provider.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **B1** Erstelle `lib/widgets/skeletons/list_skeleton.dart` und
  `lib/widgets/skeletons/card_skeleton.dart`. Übernehme Pattern
  aus `dashboard_screen.dart` (Skeletonizer-Wrapper,
  `Key('skeletonLoader')`-Konvention). `ListSkeleton(itemCount: 6)`
  rendert sechs Skeleton-Items — **NIEMALS** echte Items wrappen.
  `AnimatedSwitcher` für Loading→Filled-Crossfade ist im Widget
  built-in (200ms). Unit-Test.
  `agent: ui-builder` · `model: sonnet` · `depends: []`

- [ ] **B2** Skeleton-Loader für `inventory_screen.dart` First-Load
  (ersetzt `CircularProgressIndicator`). Nutzt
  `isLoading && !initialLoadAttempted` aus B0.
  `agent: flutter-coder` · `model: sonnet` · `depends: [B0, B1]`

- [ ] **B3** Skeleton-Loader für `deals_screen.dart` First-Load
  (Tabelle + Master-Detail-Pane).
  `agent: flutter-coder` · `model: sonnet` · `depends: [B0, B1]`

- [ ] **B4** Skeleton-Loader für `tickets_screen.dart`,
  `inbox_screen.dart`, `suppliers_screen.dart` First-Load.
  Sub-Tasks pro Screen wenn nötig.
  `agent: flutter-coder` · `model: sonnet` · `depends: [B0, B1]`

- [ ] **B5** **States-Audit (Post-Skeleton).** Pro Listen-Screen
  (inventory, deals, tickets, inbox, suppliers, warehouses,
  categories, stocktake, purchase_orders) prüfen ob `error`-State
  + `no-permission`-State als eigene `EmptyState`-Variante
  existieren. Fehlt: hinzufügen mit ARB-Keys + Retry-/Switch-
  Workspace-CTA.
  `agent: flutter-coder` · `model: sonnet` · `depends: [B2, B3, B4]`

### Epic C — l10n + Color-Hygiene (P0)

- [x] **C1** ARB-Keys in `app_de.arb` + `app_en.arb` für alle 16+
  `inbox_screen.dart`-Strings hinzufügen, idiomatische EN-
  Übersetzungen. `flutter gen-l10n`-Pass.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [x] **C2** ARB-Keys + EN-Übersetzungen für alle hardcoded
  Settings-Strings + Confirm-Dialog-Body. `confirmTypeNamePrompt`
  EN-Variante nutzt ASCII-`"…"`-Quotes (siehe §5.3).
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [x] **C3** `inbox_screen.dart` — alle 16+ hardcoded Strings auf
  `l10n.*` umbiegen.
  `agent: flutter-coder` · `model: sonnet` · `depends: [C1]`

- [ ] **C4** `settings_screen.dart` — alle hardcoded Strings auf
  `l10n.*`. Rohe Exception-Strings sanitisieren (kein `'$e'` in
  Body — generic `l10n.feedbackErrorDefault` ODER
  Error-Code-Mapping).
  `agent: flutter-coder` · `model: sonnet` · `depends: [C2]`

- [ ] **C5a** **Hardcoded-Colors-Cluster: Confirm-/Modal-Dialog-Bereich.**
  `settings_screen.dart` Z. ~278/432/1318/1339/1354/1386/2284/
  2935/3762 — Dialog-Buttons, Modal-Backgrounds, destruktive
  Akzente auf `AppTheme.*`-Tokens (`AppTheme.danger`,
  `AppTheme.surface`, `AppTheme.onSurface`). Brand-Color-
  Whitelist beachten (Discord `0xFF5865F2`, Amazon `0xFFD97706`
  bleiben hardcoded — siehe Risiko #4).
  Scope-Hinweis: ~55+ Treffer in `settings_screen.dart` gesamt,
  nicht 5. Dark-Mode-Audit Pflicht.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **C5b** **Hardcoded-Colors-Cluster: Plan-Card / Mailbox-Card.**
  `settings_screen.dart` Z. ~2147–2210, 2683–2710, 2772–2781 —
  Plan-Card-Backgrounds, Mailbox-Card-Borders, Badge-Colors.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **C5c** **Hardcoded-Colors-Cluster: Onboarding / Status /
  Logout.** `settings_screen.dart` Z. ~215–280, 828–1170,
  1418–1482, 1622–1628 — Status-Badge-Farben (live-deal-status),
  Onboarding-Akzente, Logout-/Danger-Zone.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **C6** `python3 .claude/scripts/check-l10n.py` ausführen,
  Restdrift in `lib/` (außerhalb inbox/settings) als Liste
  reporten. Nur reporten, nicht beheben — Nachfolge-Task.
  `agent: flutter-coder` · `model: sonnet` · `depends: [C3, C4]`

### Epic D — A11y + Keyboard-Nav (P1)

- [x] **D0** `accessibility_tools` v2.8.0 als `dev_dependency` in
  `pubspec.yaml` ergänzen. `AccessibilityTools`-Builder in
  `main.dart` (Debug-only via `kDebugMode`) einklinken.
  Subtree-Exclusion für `statistics_screen` (Charts):
  `AccessibilityTools(checkSemanticLabels: false, child: ...)`
  oder `ExcludeSemantics` (siehe Risiko #11). Smoke-Lauf in
  Debug-Mode dokumentiert in PR-Body.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **D1a** **NavigationRail-Foundation.** Replace
  `_Sidebar`-Custom-Widget in `main_screen.dart` durch
  Flutter-`NavigationRail`. API-Spec:
  - `extended: true` (Width ≥ 1200) → `labelType: null`
  - `extended: false` (900–1199) → `labelType: NavigationRailLabelType.all`
  - `scrollable: true` (Flutter 3.27+) bei > 7 Destinations.
  Phone-Pfad (`isPhoneViewport`) unverändert (BottomNav bleibt).
  Keys: `Key('mainNavRail')`.
  `agent: ui-builder` · `model: opus` · `depends: []`

- [ ] **D1b** **NavigationRail Branding + Feature-Gating.**
  Branding-Header übernehmen 1:1 aus `_Sidebar`:
  `leading: SizedBox(height: 56, child: BrandMark + optional BrandWordmark)`.
  `_navVisibility`-Filter (Free-Plan-Gating + Feature-Flags)
  erhalten — `NavigationRail.destinations` aus gefilterter Liste
  bauen. Akzeptanzkriterium: Free-User sieht keine Premium-Tabs.
  Pro Destination `Key('navRailDestination-<tab>')` (snake-case).
  `agent: ui-builder` · `model: sonnet` · `depends: [D1a]`

- [ ] **D1c** **NavigationRail Index-Mapping + Tests.** Helper
  `visibleTabAtRailIndex(int index) → MainTab` (mappt dichten
  Rail-Index auf realen `MainTab` durch die `_navVisibility`-
  Filter-Liste). Umgekehrter Helper
  `railIndexForTab(MainTab tab) → int?` (gibt `null` wenn Tab
  ausgeblendet). Unit-Tests mit Free-Plan-Permutationen.
  Vorher/Nachher-Screenshots in PR-Body (Light + Dark + Free +
  Premium).
  `agent: flutter-coder` · `model: sonnet` · `depends: [D1b]`

- [ ] **D2** Semantics-Labels für KPI-Karten im Dashboard.
  `Semantics(label: 'KPI <title>, Wert <value>, Trend <trend>')`.
  `agent: flutter-coder` · `model: sonnet` · `depends: [D0]`

- [ ] **D3** Semantics-Labels für Status-Badges in `deal_card`,
  `deal_table`, `tickets_screen`, `purchase_order_detail`.
  `agent: flutter-coder` · `model: sonnet` · `depends: [D0]`

- [ ] **D4** Semantics-Labels für FABs + Bottom-Nav-Items
  (`main_screen.dart`, `inventory_screen.dart`,
  `warehouses_screen.dart`, `categories_screen.dart`,
  `purchase_orders_screen.dart`, `stocktake_screen.dart`).
  `agent: flutter-coder` · `model: sonnet` · `depends: [D0]`

- [ ] **D5** Semantics-Summary für Charts in `statistics_screen.dart`
  (textuelle Zusammenfassung „Donut-Chart, Top-Buyer: X, Y, Z").
  `ExcludeSemantics`-Wrapper um die einzelnen Chart-Slices.
  `agent: flutter-coder` · `model: sonnet` · `depends: [D0]`

### Epic E — Form-UX (P1)

- [ ] **E1** Implementiere `lib/widgets/unsaved_changes_guard.dart`
  mit `PopScope`-Wrapper (NICHT `WillPopScope` — deprecated ab
  Flutter 3.16). `PopScope` liegt INNERHALB des Dialog-Trees
  (siehe §5.1 PopScope-Pattern). Zeigt `showConfirmDialog` bei
  Dirty-Flag. Keys: `Key('unsavedChangesGuard-dialog')`,
  `Key('unsavedChangesGuard-discard')`. Unit-Test mit Dirty/
  Clean-Branches.
  `agent: ui-builder` · `model: sonnet` · `depends: [A2]`

- [ ] **E2** Integriere `UnsavedChangesGuard` + Save-Button-Loading-
  State (`isSaving=true` → disabled + Spinner-Inline) in
  `add_edit_deal_dialog.dart`. `HapticFeedback.lightImpact()` bei
  Save-Success.
  `agent: flutter-coder` · `model: sonnet` · `depends: [E1]`

- [ ] **E3** Dito für `add_edit_product_dialog.dart`,
  `add_edit_supplier_dialog.dart`.
  `agent: flutter-coder` · `model: sonnet` · `depends: [E1]`

- [ ] **E4** Dito für `add_edit_buyer_dialog.dart`,
  `add_edit_shop_dialog.dart`, `add_edit_mailbox_dialog.dart`.
  `HapticFeedback.lightImpact()` bei Save-Success.
  `agent: flutter-coder` · `model: sonnet` · `depends: [E1]`

- [ ] **E5** Inline-Validation-Pattern in den 6 Add/Edit-Dialogs:
  TextField validiert `onChanged`, Fehler erscheint unterhalb
  des Felds (nicht erst beim Submit). Wo Validierungs-Logik
  schon existiert: nur Trigger-Zeitpunkt ändern.
  `agent: flutter-coder` · `model: sonnet` · `depends: [E2, E3, E4]`

### Epic F — Visual-Polish + Onboarding (P1)

- [ ] **F1** `lib/app_theme.dart`: `space*` + `radius*`-Konstanten
  hinzufügen (siehe §5.4). Verhaltensneutral, nur Tokens.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **F2** Magic-Number-Migration für die 6 häufigsten
  Padding-/Spacing-Werte (`grep -E "EdgeInsets\.(all|symmetric)\((const )?[0-9]+"`)
  auf `AppTheme.space*`. Inkrementell — nicht alle Stellen, nur
  Schlüssel-Screens (`dashboard`, `inventory`, `deals`).
  `agent: flutter-coder` · `model: sonnet` · `depends: [F1]`

- [ ] **F4** `Hero`-Animation für Item-Card → Detail-Push in
  `inventory_screen.dart` → `product_detail_screen.dart`.
  **Phone-Gating Pflicht:**
  ```dart
  if (isPhoneViewport(context))
    Hero(tag: 'product-${item.id}', child: card)
  else
    card
  ```
  Hero-Tag-Unique-Garantie (Item-ID).
  Smoke-Test `smoke-hero-no-desktop-regression` bestätigt
  Desktop-Verhalten (Master-Detail bleibt ohne Push).
  `agent: ui-builder` · `model: sonnet` · `depends: []`

- [ ] **F5** Onboarding-Politur: konsistente Progress-
  Indikator-Optik (heute 6 Schritte als PageView-Dots —
  durch M3-LinearProgressIndicator mit Schritt-Label
  „Schritt {current} von {total}" ersetzen), AnimatedSwitcher
  zwischen Steps, AppFeedback statt rohe SnackBars (Z. 91ff.).
  **Hinweis:** Onboarding-Strings sind bereits l10n'd — F5 ist
  reiner Styling- + Animation-Task, keine ARB-Edits nötig
  (außer `onboardingStepLabel`).
  `agent: ui-builder` · `model: sonnet` · `depends: [A1, F1]`

- [ ] **F6a** **Icon-Stil-Audit (Report-Only).** Durch `lib/screens`
  greppen (`Icons\.[a-z_]+_outlined` vs. nicht-outlined),
  Statistik erstellen (Outlined-Anteil pro Screen). Empfehlung
  „konsequent outlined" oder „gemischt OK" mit Begründung als
  Markdown-Report unter `plans/2026-05-24_icon-style-audit.md`.
  `agent: flutter-coder` · `model: sonnet` · `depends: []`

- [ ] **F6b** **Icon-Stil-Migration.** Nur ausführen wenn F6a
  „konsequent outlined" empfiehlt UND Stakeholder zustimmt.
  Diff-Patch über die Non-Outlined-Stellen, inkrementell pro
  Cluster.
  `agent: flutter-coder` · `model: sonnet` · `depends: [F6a]`

### Epic G — Phone-Reachability + MoreNavSheet (P2, Stretch)

- [ ] **G1** `_MoreNavSheet` in `main_screen.dart` polieren:
  Section-Header (z.B. „Verwalten" / „Mehr"), Spacing-Polish,
  Top-Tile „Suchen…" → öffnet `global_search_dialog` (kein
  Vollbild). Tests: `smoke-more-nav-sheet`.
  `agent: ui-builder` · `model: sonnet` · `depends: []`

- [ ] **G2** (Stretch) Bottom-Sheet-Action-Center für Phone-
  Reachability: FAB-Long-Press öffnet ein Sheet mit den
  3–5 häufigsten AppBar-Aktionen des aktuellen Screens
  (Search, Help, Filter). Erst implementieren wenn Epic A–F
  stabil. Genau prüfen, ob das Über-Engineering ist — User-
  Validation Pflicht.
  `agent: ui-builder` · `model: opus` · `depends: [G1]`

---

## 9. Reihenfolge / Empfehlung

**MVP-Polish (Minimum Viable):** Epic A + B + C. Liefert das
spürbarste „premium feel"-Delta. Geschätzte 30+ Tasks (durch
Splits), aber jeder Task klein und atomar.

**Full-Uplift:** + Epic D + E + F. Liefert A11y-Basis,
Form-UX-Politur, Visual-Polish.

**Optional / Stretch:** Epic G. Nur wenn restlicher Plan
sauber landet und Stakeholder weiter „premium" priorisiert.

**Pre-Flight-Gates:**
- A7 (Undo-Audit) muss vor A3/A5 fertig sein.
- B0 (Provider-Harmonisierung) muss vor B2/B3/B4 fertig sein.
- D0 (`accessibility_tools` Setup) muss vor D2–D5 fertig sein.
- D1a → D1b → D1c sequenziell (keine Parallelität in Epic D1).

---

## 10. Out-of-Scope-Folge-Pläne (NICHT in diesem Plan)

Aus dem IST-Audit identifiziert, aber bewusst verschoben:

1. **Notification-Center mit Read/Unread** — eigener Backend-
   Plan, neue Tabelle `notifications`, RLS, Push-Hooks.
2. **Settings-Hub-Refactor** — Settings als Hub mit Sub-Routen
   statt 8-Tab-Inferno.
3. **IA-Konsolidierung Inventory ↔ Warehouse — DIREKTER NACHFOLGER
   dieses Plans.** Eigener IA-Plan, schreibt Datenflüsse. Soll
   unmittelbar nach Abschluss von Epic A–C dieses Plans gestartet
   werden (Stakeholder-Wunsch).
4. **`StatisticsScreen` embeddable + Warehouse-Hub Reporting-
   Master-Detail** — bewusster Trade-off aus Vorgänger-Plan
   T3.4. Eigener kleiner Plan.
5. **Theme-Customization-UI** (Light/Dark/Auto + Palette-
   Wechsler bereits in Settings, aber Custom-Accent-Color-
   Wheel nicht).
6. **Global-Settings-Search innerhalb von Settings-Screen** —
   8 Tabs sind unübersichtlich; Search-Feld würde finden
   helfen.

---

## 11. Committee-Review-Historie

### 2026-05-24 — Phase-2-Council (5 Reviewer)

| Rolle | Modell | Verdict | Hauptpunkte |
|---|---|---|---|
| Architekt | Opus | ⚠️ ÜBERARBEITUNG | C5-Scope (55+ Treffer, nicht 5), A4/A6 zu grob, fehlende Pre-Audits (Undo, Provider-API), Index-Mapping bei NavigationRail. |
| Bug-Hunter / Pessimist | Opus | KRITISCH — 14 Findings | `WillPopScope` deprecated → `PopScope`, PopScope-Position falsch, SnackBar-Margin ignoriert Bottom-Nav, Dialog-Context-Pattern fehlt, Confirm-Phone-Variante als BottomSheet, NavigationRail-API-Assertion (`extended` + `labelType`), Branding/Filter-Verlust bei D1, Hero-Tag-Collisions, Exception-Strings in SnackBar, RLS-blockierte Undo-Pfade, Optimistic-Restore ohne Cache-Marker, BiDi-Override in `requireTypeName`, EN-Quote-Stil, Index-Mapping-Bug. |
| External-Solutions-Scout | Sonnet | HYBRID | `MemberRemoveConfirmDialog` existiert bereits — generalisieren statt neu bauen. `accessibility_tools`-Package empfohlen statt Eigenbau. `skeletonizer` bereits im pubspec — kein neues Paket. |
| Security-Reviewer | Opus | pass | Keine neuen RLS-Pfade, keine Edge-Functions, keine Secret-Touches. Hinweis: Exception-Strings nicht roh in UI ausgeben (Info-Leak). |
| UX/Mobile | Opus | ⚠️ ÜBERARBEITUNG | Confirm-Dialog auf Phone als BottomSheet, Touch-Targets ≥48dp, Keyboard-Awareness bei `requireTypeName`, Hero nur Phone, `_MoreNavSheet` Sektionierung, Reachability-Hebel realistisch einordnen. |

**Notiz:** Alle 19 Pflicht-Findings (5 Architekt + 14 Bug-Hunter) +
empfohlene Verbesserungen (Scout, UX/Mobile) eingearbeitet. Plan
ging von 34 Tasks auf 52 Tasks (Splits + Pre-Audits + Token-Tasks).

**Hauptänderungen gegenüber Draft:**
- `WillPopScope` → `PopScope` durchgängig (§5.1 + E1).
- C5 in C5a/b/c gesplittet, Scope-Hinweis 55+ Treffer.
- A4 in A4a/b/c gesplittet (Mailbox/Team-Buyer-Shop/Subscription).
- A6 in 16 Sub-Tasks (A6a–A6p) pro Screen.
- D1 in D1a/b/c gesplittet (Foundation + Branding/Gating + Index-
  Mapping).
- F6 in F6a (Audit) + F6b (Migration).
- Neue Tasks: A7 (Undo-Audit), A8 (Page-Registry), B0 (Provider-
  Harmonisierung), B5 (States-Audit), D0 (accessibility_tools).
- A2 generalisiert `MemberRemoveConfirmDialog` statt Neu-Bau.
- F3 gestrichen (AnimatedSwitcher in B1 built-in).
- 3 neue Smoke-Tests (`smoke-form-keyboard-phone`,
  `smoke-nav-feature-gating`, `smoke-hero-no-desktop-regression`).
- AppFeedback-Spec mit Phone-Bottom-Margin + Dialog-Context-Pattern.
- A11y-Key-Inventar §5.1.1 als neue Sub-Sektion.
- Brand-Color-Whitelist explizit (Discord/Amazon).
- Risiken 11–13 ergänzt (a11y_tools False-Positives, RLS-Undo,
  Index-Mapping-Bug).
- §10: IA-Folge-Plan als „direkter Nachfolger" markiert.
- `HapticFeedback.lightImpact()` in A2 + E2 + E4.
- Exception-String-Sanitize in A3/A4a/C4.
- Unicode-Bidi-Sanitize in A2.
