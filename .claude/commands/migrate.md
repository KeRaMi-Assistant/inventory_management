---
description: Erstellt eine Supabase-Migration via db-migrator-Agent
argument-hint: <migration-slug-und-beschreibung>
---

Rufe den `db-migrator`-Subagenten auf:

> Erstelle eine Supabase-Migration für: $ARGUMENTS
>
> Pflicht: RLS-Policies, Indexes, Audit-Spalten falls anwendbar. Lokal mit `supabase db reset` testen. Niemals `supabase db push` oder `supabase link`.
>
> Output: Pfad zur neuen Migration + Zusammenfassung.

Nach Erstellung: Frage User, ob auch der `flutter-coder` die Provider/Repository-Anpassungen machen soll.
