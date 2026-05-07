---
slug: cmd-k-actions
priority: 9
plan: true
budget_usd: 5
---

Cmd+K / Ctrl+K Kommando-Palette ausbauen.

Foundation existiert in `lib/widgets/global_search_dialog.dart`. Was
fehlt:

1. **Action-Provider** in `lib/providers/action_provider.dart`:
   - Liste aller Actions: "Neuer Deal", "Neues Ticket",
     "Export Quartal", "Inventory durchsuchen", …
   - Jede Action: `String label`, `IconData icon`, `VoidCallback onInvoke`,
     `List<String> keywords` (für Match)

2. **Hotkey-Binding** im Web/Desktop:
   - In `app.dart` oder Top-Level-Widget einen `Shortcuts` +
     `Actions`-Block für `LogicalKeySet(LogicalKeyboardKey.metaLeft,
     LogicalKeyboardKey.keyK)` (macOS) und `controlLeft+keyK` (Win/Linux/Web).
   - Triggert `showDialog(builder: (_) => GlobalSearchDialog())`.

3. **Search-Dialog erweitern:**
   - Tab "Daten" (Deals/Items/Tickets/Käufer) — bestehend.
   - Tab "Aktionen" — Liste aller registrierten Actions, gefiltert
     nach Eingabe (fuzzy-match auf `label` + `keywords`).
   - Enter führt Action aus, schließt Dialog.

Mobile-First: Auf Phone öffnet sich der Dialog als Full-Screen-Sheet.
Hotkey gibt's auf Phone nicht — stattdessen prominenter Search-Icon
in der AppBar oder Bottom-Nav.

l10n: `cmd_k_actions_tab`, `cmd_k_data_tab`, `cmd_k_no_match`.

`flutter analyze` + `flutter test` müssen grün sein.
