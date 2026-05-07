---
slug: public-profile-page
priority: 5
plan: true
budget_usd: 8
---

**Verkaufsseite** — öffentliche Read-only-Seite pro Workspace, akquise-
optimiert.

URL-Schema (Web-only): `/u/<workspace-handle>` (z.B. `/u/mein-laden`).

Features:
- Workspace-Logo + Name (aus `workspaces`-Tabelle)
- Aktueller Bestand (nur Inventory-Items mit `status = 'Lager'` UND
  `is_public = true` — neues Feld)
- Bilder, Preise, Kurzbeschreibung
- "Anfrage senden"-Button → öffnet Mail-Client mit `mailto:`
- Footer: "Erstellt mit InventoryOS" → Link zur Landing-Page

Komponenten:
- Migration: `workspaces.handle text unique`,
  `workspaces.public_profile_enabled bool default false`,
  `inventory_items.is_public bool default false`
- Edge Function `public-profile` (oder direkt RLS-public-Policy für
  bestimmte Spalten + Public-Read-RLS auf `workspaces` mit Filter
  `public_profile_enabled = true`)
- Flutter Route: `/u/:handle` (extra Branch in `app.dart` Router)
- Settings-Tab "Öffentliches Profil" → Toggle + Handle-Eingabe + Liste
  der inventory_items mit Public-Toggle

Mobile-First (PFLICHT):
- Public-Page rendert auf Phone als gestapelte Cards.
- Auf Tablet/Desktop: 2-3-spaltiges Grid.
- Bilder Lazy-Load.
- "Anfrage senden"-Button als Bottom-Floating-Action auf Phone.

l10n: `public_profile_*` Keys (DE + EN).

Sicherheit:
- RLS-Policy: anonymer Zugriff NUR wenn `public_profile_enabled = true`
- Keine privaten Felder leaken (Käufer, EK-Preis, Notes)

Tests:
- Public-RLS-Policy verhindert Zugriff auf nicht-public-Workspaces
- `is_public = false` → Item taucht nicht in Public-View auf

`flutter analyze` + `flutter test` müssen grün sein.
`supabase db reset` muss grün durchlaufen.
