# Icon-Stil-Audit — F6a Report

**Datum:** 2026-05-24
**Task:** F6a aus `plans/2026-05-24_ui-ux-value-uplift.md`
**Scope:** `lib/screens/` + `lib/widgets/`
**Empfehlung:** konsequent `_outlined`

---

## 1. Methodik

```bash
grep -rn "Icons\." lib/screens/ lib/widgets/
```

Drei Kategorien nach Suffix:

| Kategorie | Suffix | Material-Stil | Gesamt |
|---|---|---|---|
| M3-Outlined | `_outlined` | Material Design 3 Outlined | **270** |
| Sharp/Alt-Outlined | `_outline` (ohne `d`) | Material Icons Sharp / Alt-Outlined | **100** |
| Rounded | `_rounded` | Material Design Rounded | **58** |
| Plain (kein Suffix) | — | Filled / kein Pendant | **~206** |

**Gesamt-Icon-Referenzen:** ~634

---

## 2. Kritischer Befund: `_outline` ≠ `_outlined`

Die Namen unterscheiden sich nicht nur kosmetisch. Die Flutter-SDK weist
**unterschiedliche Codepoints** zu:

| Icon-Name | Codepoint | Style |
|---|---|---|
| `Icons.delete_outline` | `0xe1bb` | Material Icons Alt-Outlined (sharp look) |
| `Icons.delete_outlined` | `0xefaa` | Material Design 3 Outlined |
| `Icons.mail_outline` | `0xe3c4` | Material Icons Sharp |
| `Icons.mail_outlined` | `0xf1aa` | Material Design 3 Outlined |
| `Icons.help_outline` | `0xe30b` | Material Icons Sharp |
| `Icons.help_outlined` | `0xf0f8` | Material Design 3 Outlined |

Die App rendert damit in derselben UI-Zeile zwei verschiedene Icon-Stile.
Auf Retina-Displays ist der Unterschied in der Linienstärke und den
abgerundeten/spitzen Endpunkten sichtbar.

---

## 3. Häufigste Icons mit falscher Variante (`_outline` statt `_outlined`)

Top-10 nach Häufigkeit:

| Icon | Aufrufe | Hauptdateien |
|---|---|---|
| `Icons.delete_outline` | 22 | `settings_screen`, `inventory_screen`, `inbox_screen`, `deal_table`, `deal_card`, `categories_screen`, `suppliers_screen`, `warehouses_screen`, `purchase_orders_screen`, `deal_comments_section`, `inventory_batches_sheet` |
| `Icons.mail_outline` | 11 | `settings_screen` (Tab-Icons!), `inbox_screen`, `main_screen` (_navIcons Tuple) |
| `Icons.lock_outline` | 10 | `product_detail_screen`, `settings_screen`, `auth/` Screens |
| `Icons.people_outline` | 9 | `dashboard_screen`, `statistics_screen`, `settings_screen`, stat-widgets |
| `Icons.error_outline` | 9 | `product_detail_screen`, `categories_screen`, `stocktake_screen`, `purchase_orders_screen` |
| `Icons.info_outline` | 8 | `product_detail_screen`, `settings_screen`, `inbox_screen`, `help_screen` |
| `Icons.help_outline` | 8 | `main_screen` (AppBar!), `inbox_screen`, `inventory_screen`, `tracking_status_block` |
| `Icons.check_circle_outline` | 7 | `product_detail_screen`, `inventory_screen`, `billing_profile_screen` |
| `Icons.add_circle_outline` | 5 | `inventory_screen` (Mengen-Buttons) |
| `Icons.remove_circle_outline` | 4 | `inventory_screen` (Mengen-Buttons) |

---

## 4. Bereits konsequente Bereiche (keine Migration nötig)

### 4.1 BottomNav / NavigationBar (Phone)
`main_screen.dart` L45–57: Alle 11 Tabs nutzen `(outlined, rounded)`-Tuple
korrekt. Unselected = `_outlined`, Selected = `_rounded`. **Einzige Ausnahme:**
`Icons.mail_outline` in Zeile 49 (statt `Icons.mail_outlined`).

### 4.2 AppNavRail / Sidebar (Desktop)
`iconBuilder` in `main_screen.dart` liest aus demselben `_navIcons`-Tuple.
Korrekt bis auf das `mail_outline`-Problem.

### 4.3 Inline-Action-Buttons (Trailing)
`Icons.edit_outlined` (26 Aufrufe) konsistent. `Icons.delete_outline` (22)
ist die einzige große Ausnahme — sollte `Icons.delete_outlined` werden.

### 4.4 Status-Indikatoren (Cards/Badges)
`Icons.circle` für Status-Dots (filled, kein outlined): korrekt per M3
(höhere Sichtbarkeit für Status).

### 4.5 Rounded-Varianten in Activity-Feed
`Icons.*_rounded` in `activity_screen.dart` und Dashboard-Heatmap:
bewusst rund für Kategorie-Bullet-Icons im Activity-Log. Kein Fix nötig.

---

## 5. Plain-Icons ohne `_outlined`-Variante — kein Fix möglich/nötig

| Icon | Aufrufe | Begründung |
|---|---|---|
| `Icons.close` | 24 | Kein `close_outlined` in Flutter. Universell eingesetzt. |
| `Icons.add` | 19 | Kein `add_outlined`. FAB + Inline-Add. M3-FAB-Konvention: filled. |
| `Icons.refresh` | 15 | `refresh_outlined` existiert, aber `refresh` ist die universelle Form. |
| `Icons.check` | 12 | Kein `check_outlined`. Checkmark ist immer plain. |
| `Icons.search` | 10 | Kein `search_outlined` in Flutter Material. TextField-prefixIcon. |
| `Icons.open_in_new` | 10 | `open_in_new_outlined` existiert nicht als Standard. Inline-Link-Action. |
| `Icons.chevron_right` | 7 | Keine outlined-Variante sinnvoll. Navigation-Arrow. |
| `Icons.link` | 6 | Kein `link_outlined`. Inline-Linking-Action. |

**Ausnahme:** `Icons.refresh` hat `Icons.refresh_outlined` — der ein-Treffer
in `inbox_screen.dart:287` nutzt bereits korrekt `Icons.refresh_outlined`.

---

## 6. Empfehlung

**Empfehlung: konsequent `_outlined` (M3-Stil).**

Begründung:
- Der Codebase-Dominant ist schon `_outlined` (270 Treffer vs. 100 `_outline`).
- `_outline` (ohne `d`) rendert einen subtil anderen Linienstil (sharp statt rounded-end),
  der in M3-Dark-Mode-Kontext uneinheitlich wirkt.
- Migration ist mechanisch und risikoarm — kein Layout-Impact.
- BottomNav-Tab für „Inbox" (`mail_outline` → `mail_outlined`) ist ein sichtbarer Fix:
  der Tab-Icon weicht heute visuell vom Rest der Nav-Tab-Icons ab.

---

## 7. Priorisierte Migrations-Liste für F6b

Fokus: 5–10 Migrationen in den höchstfrequenten Files mit höchstem Sichtbarkeits-Impact.
KEIN globaler Replace. Brand-Icons (`discord`, `google`, `apple`, `amazon`) unverändert.

### Priorität 1 — Navigations-Konsistenz (höchste Sichtbarkeit)

| Datei | Zeile | Vorher | Nachher |
|---|---|---|---|
| `main_screen.dart` | 49 | `Icons.mail_outline` | `Icons.mail_outlined` |
| `main_screen.dart` | 388 | `Icons.help_outline` | `Icons.help_outlined` |

### Priorität 2 — Inline-Delete-Konsistenz (22 Stellen → unified look)

| Datei | Zeilen | Vorher | Nachher |
|---|---|---|---|
| `inventory_screen.dart` | 644, 1304, 1467 | `Icons.delete_outline` | `Icons.delete_outlined` |
| `inbox_screen.dart` | 1153, 1477, 1675 | `Icons.delete_outline` | `Icons.delete_outlined` |
| `deal_card.dart` | 289 | `Icons.delete_outline` | `Icons.delete_outlined` |
| `deal_table.dart` | 517, 789 | `Icons.delete_outline` | `Icons.delete_outlined` |

### Priorität 3 — Settings Tab-Icons (hohe Sichtbarkeit)

| Datei | Zeilen | Vorher | Nachher |
|---|---|---|---|
| `settings_screen.dart` | 65, 86 | `Icons.mail_outline` | `Icons.mail_outlined` |

---

## 8. Out-of-Scope

- `Icons.help_outline` in `inbox_screen.dart`, `inventory_screen.dart` (inline):
  Migration empfohlen aber nicht im 5–10-Fenster dieses Runs.
- `Icons.lock_outline` (10 Stellen): auth-Screens + product_detail. Korrektheit
  ist niedrigprioritär (lock = semantisch klar unabhängig vom Stil).
- `Icons.people_outline`, `Icons.error_outline`, `Icons.info_outline`, `Icons.check_circle_outline`:
  Migrations-Kandidaten für einen Folge-Task; nicht in diesem Run.
- `settings_screen.dart` weitere `delete_outline`-Stellen (Z. 249, 522, 606, 1040, 2644, 3229):
  Migration sinnvoll aber auf separaten Cluster-Task verschieben (Settings ist bereits P0-Hotspot
  für C4/C5).
