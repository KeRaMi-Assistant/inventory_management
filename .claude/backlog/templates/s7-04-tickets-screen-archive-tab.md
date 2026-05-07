---
slug: tickets-screen-archive-tab
priority: 7
plan: true
budget_usd: 6
---

UI-Erweiterung `lib/screens/tickets_screen.dart`:

Neuer Sub-Tab-Switcher oben: **"Aktiv | Archiv"**.

- **Aktiv:** zeigt `tickets WHERE archived_at IS NULL` (bisheriges
  Verhalten).
- **Archiv:** zeigt archivierte Tickets gruppiert nach `archived_at`-Monat.
  Pro Gruppe: Header mit Monat/Jahr + Profit-Summary (Sum aller Deal-VK
  minus EK).

Re-Open: Long-Press auf archiviertem Ticket → Bottom-Sheet mit
"Wieder öffnen" → setzt `archived_at = NULL`, schreibt ins Activity-Log.

Provider-Update in `lib/providers/inventory_provider.dart` (oder einem
neuen `tickets_provider.dart` falls inventory_provider zu fett wird):
- `loadTickets({bool archived})`-Method
- `archiveTicket(ticketId, reason)`
- `reopenTicket(ticketId)`

l10n-Keys (DE+EN):
- `tickets_tab_active`, `tickets_tab_archive`
- `tickets_archive_reopen`, `tickets_archive_reopen_confirm`
- `tickets_archive_month_profit` ({profit})

**Mobile-First-Pflicht:**
- Tab-Switcher nicht als Sidebar-Filter, sondern als horizontale TabBar
  oben.
- Monatsgruppen mit StickyHeader, keine Tabelle.
- Long-Press funktioniert auf Touch-Devices (haptic feedback).

`flutter analyze` + `flutter test` müssen grün sein.
