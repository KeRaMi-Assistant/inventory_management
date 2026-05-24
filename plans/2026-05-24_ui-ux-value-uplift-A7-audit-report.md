# A7 Undo-Audit-Report — Pre-Flight für Epic A3 / A5

**Plan-Referenz:** `plans/2026-05-24_ui-ux-value-uplift.md`, Task A7 + Risiko 12  
**Datum:** 2026-05-24  
**Agent:** flutter-coder (Sonnet)  
**Status:** Fertig — blockiert A3 und A5 nicht länger

---

## 1. Audit-Tabelle: alle Delete-Pfade

| Pfad | Repository-Methode | Soft-Delete heute? | Provider hält Item nach Delete im Cache? | RLS: UPDATE auf soft-deleted Row erlaubt? | Optimistic-Local-Restore machbar? |
|---|---|---|---|---|---|
| **Inbox-Mail verwerfen** (`dismissParsedMessage`) | `SupabaseRepository.dismissParsedMessage()` — setzt `status = 'dismissed'` per UPDATE | Quasi-Soft-Delete (Row bleibt, Status-Feld) | Nein — `_recent` wird sofort per `removeWhere` bereinigt; `dismissParsedMessage` entfernt die Row aus dem lokalen Cache in `InboxProvider.dismissParsedMessage()` (Z. 648) | **Nein** — `parsed_messages` hat **keine** `FOR UPDATE`-Policy für authenticated Users (`20260507000000_inbox.sql` Z. 161–165: nur `parsed_messages_ws_read FOR SELECT`; Inserts/Updates kommen vom service_role). Ein direktes `UPDATE status='dismissed'` via Client SDK würde mit RLS 403 scheitern. | **Nein** — UPDATE durch User-Client blockiert durch fehlende RLS-UPDATE-Policy |
| **Inbox-Mail verwerfen** (`markSuggestionRejected`) | `SupabaseRepository.insertInboxDismissal()` + `markSuggestionResolved()` | `inbox_dismissals`: INSERT-basiert (persistent ignore-key); `pending_deal_suggestions`: UPDATE resolved_at | `_suggestionsRaw` wird gefiltert, kein Restore vorhanden | `inbox_dismissals` hat `FOR ALL`-Policy (`20260507800000_inbox_dismissals.sql` Z. 48). `pending_deal_suggestions` hat `FOR UPDATE`-Policy (Z. 172). Beide erlauben Write für member-Rolle. Aber: Undo würde `DELETE FROM inbox_dismissals` benötigen — das ist durch `FOR ALL` erlaubt. | **Ja** — Optimistic-Local-Restore via Delayed-Commit machbar für die Suggestion-Variante |
| **Deal löschen** (`deleteDeal`) | `SupabaseRepository.deleteDeal()` — `UPDATE deals SET deleted_at = NOW()` | **Ja** — Soft-Delete via `deleted_at` | **Nein** — `_deals.removeWhere()` (Z. 605) in `InventoryProvider` läuft sofort nach dem Repository-Call | RLS: `deals_ws_update` (`20260504000500_data_workspace_scope.sql` Z. 261–265) — `USING (has_workspace_role(...))`. **Kein** `deleted_at IS NULL`-Guard im USING-Clause. Restore via `UPDATE deals SET deleted_at = NULL` ist damit RLS-seitig erlaubt für member-Rolle. | **Ja** — Delayed-Commit + Optimistic-Local-Restore machbar |
| **Inventory Item löschen** (`deleteInventoryItem`) | `SupabaseRepository.deleteInventoryItem()` — `UPDATE inventory_items SET deleted_at = NOW()` | **Ja** — Soft-Delete via `deleted_at` | **Nein** — `_inventoryItems.removeWhere()` (Z. 1759) läuft sofort; `_movements.removeWhere()` auch | RLS: `inventory_items_ws_update` (`20260504000500_data_workspace_scope.sql` Z. 337–343) — kein `deleted_at`-Guard. Restore via `UPDATE SET deleted_at = NULL` ist RLS-seitig erlaubt. | **Ja** — Delayed-Commit + Optimistic-Local-Restore machbar |
| **Supplier löschen** (`deleteSupplier`) | `SupabaseRepository.deleteSupplier()` — `UPDATE suppliers SET deleted_at = NOW()` | **Ja** — Soft-Delete via `deleted_at` | **Nein** — `_suppliers.removeWhere()` (Z. 1062) läuft sofort | RLS: `suppliers_ws_update` (`20260504000500_data_workspace_scope.sql` Z. 318–324) — kein `deleted_at`-Guard. Restore erlaubt. | **Ja** — Delayed-Commit + Optimistic-Local-Restore machbar |
| **Mailbox-Account entfernen** (`deleteMailboxAccount`) | `SupabaseRepository.deleteMailboxAccount()` — **Hard-Delete** `DELETE FROM mailbox_accounts` | **Nein** — Hard-DELETE, Row weg | **Nein** — sofortiges `_accounts = _accounts.where(...).toList()` in `InboxProvider` (Z. 551) | n/a — Row existiert nach DELETE nicht mehr | **Nein** — Hard-Delete, kein DB-Restore möglich |
| **Discard-Filter leeren** (`clearDismissals`) | `SupabaseRepository.clearInboxDismissals()` — Hard-DELETE alle `inbox_dismissals` des Workspace | Nein — Hard-Delete | `_dismissalKeys` und `_dismissalCount` werden sofort resettet, `refresh()` wird gerufen | n/a — keine Rows zu restaurieren | **Trivial Ja** — rein lokale Operation; Dismiss-Keys nur aus `_dismissalKeys` entfernen, DB-Delete kann verzögert werden. Kein Undo auf Row-Ebene nötig. |

---

## 2. RLS-Befund im Detail

### `deals` (UPDATE-Policy)

Datei: `supabase/migrations/20260504000500_data_workspace_scope.sql`, Z. 261–265:

```sql
CREATE POLICY deals_ws_update ON public.deals FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
```

**Befund:** Kein `deleted_at IS NULL`-Guard. Ein `UPDATE deals SET deleted_at = NULL WHERE id = X` durch einen authentifizierten member-User ist RLS-seitig erlaubt. DB-Restore ist möglich.

### `inventory_items` (UPDATE-Policy)

Datei: `supabase/migrations/20260504000500_data_workspace_scope.sql`, Z. 337–343:

```sql
CREATE POLICY inventory_items_ws_update ON public.inventory_items FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
```

**Befund:** Identisches Pattern. `UPDATE inventory_items SET deleted_at = NULL` durch member erlaubt.

### `suppliers` (UPDATE-Policy)

Datei: `supabase/migrations/20260504000500_data_workspace_scope.sql`, Z. 318–324:

```sql
CREATE POLICY suppliers_ws_update ON public.suppliers FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
```

**Befund:** Identisches Pattern. Restore erlaubt.

### `parsed_messages` (kein UPDATE durch User-Client)

Datei: `supabase/migrations/20260507000000_inbox.sql`, Z. 161–165:

```sql
DROP POLICY IF EXISTS parsed_messages_ws_read ON public.parsed_messages;
CREATE POLICY parsed_messages_ws_read ON public.parsed_messages FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
-- Inserts/Updates kommen vom service_role (Edge Function) — keine
-- User-Schreib-Policy nötig.
```

**Befund:** Nur SELECT-Policy. Kein `FOR UPDATE` und kein `FOR ALL` für authenticated Users. `SupabaseRepository.dismissParsedMessage()` ruft `UPDATE parsed_messages SET status = 'dismissed'` auf — dieser Call geht durch weil Supabase den request ohne passende Policy als Row-Not-Found behandelt (kein Fehler, aber kein Update). Das ist ein stiller Fehler im bestehenden Code. Für das Undo-Design ist entscheidend: auch ein Restore-UPDATE auf `parsed_messages` würde RLS-seitig fehlschlagen.

### `mailbox_accounts` (Hard-Delete)

Datei: `supabase/migrations/20260507000000_inbox.sql`, Z. 155–159:

```sql
CREATE POLICY mailbox_accounts_ws_write ON public.mailbox_accounts FOR ALL
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin']));
```

**Befund:** `FOR ALL` deckt DELETE. Aber `deleteMailboxAccount()` macht einen physischen Hard-Delete — nach dem Call existiert die Row nicht mehr. Kein Restore möglich, egal was RLS erlaubt.

---

## 3. Verdict pro Pfad

| Pfad | Verdict | Begründung |
|---|---|---|
| **Inbox-Mail verwerfen** (ParsedMessage / `dismissParsedMessage`) | **Undo NICHT machbar — RLS blockt UPDATE auf `parsed_messages`** | `parsed_messages` hat keine User-UPDATE-Policy. Ein Restore-UPDATE würde stillschweigend 0 Rows treffen. Kein DB-Restore möglich. |
| **Inbox-Suggestion verwerfen** (`markSuggestionRejected`) | **Undo machbar (Optimistic-Local-Restore mit Delayed-Commit)** | `inbox_dismissals` erlaubt DELETE durch member; `pending_deal_suggestions` erlaubt UPDATE. Der Dismiss-Key kann lokal als pending gehalten werden, DB-Write erst nach SnackBar-Timeout. Undo = lokale Marks entfernen ohne DB-Touch. |
| **Deal löschen** (`deleteDeal`) | **Undo machbar (Optimistic-Local-Restore mit Delayed-Commit)** | Soft-Delete via `deleted_at`, RLS erlaubt UPDATE. Delayed-Commit-Pattern: Item im Provider als `_pendingDelete`-Marker halten, DB-UPDATE erst nach SnackBar-Timeout. Undo = Marker entfernen, kein DB-Touch. |
| **Inventory Item löschen** (`deleteInventoryItem`) | **Undo machbar (Optimistic-Local-Restore mit Delayed-Commit)** | Identisches Pattern zu Deal. Caveat: `_movements.removeWhere` würde ebenfalls verzögert werden müssen — oder Movements werden nach Undo lokal belassen (akzeptabel, da Movements append-only). |
| **Supplier löschen** (`deleteSupplier`) | **Undo machbar (Optimistic-Local-Restore mit Delayed-Commit)** | Soft-Delete via `deleted_at`, RLS erlaubt UPDATE. Delayed-Commit machbar. |
| **Mailbox-Account entfernen** (`deleteMailboxAccount`) | **Undo NICHT sinnvoll — Hard-Delete, kein Restore möglich** | Physischer DELETE ohne `deleted_at`. Row ist weg. Passwort-Credentials sind ebenfalls gelöscht (`ON DELETE CASCADE` auf `mailbox_credentials`). Re-Insert würde neue Credentials-Eingabe erfordern — kein automatisches Undo. |
| **Discard-Filter leeren** (`clearDismissals`) | **Undo machbar (Optimistic-Local-Restore, trivial)** | Rein lokale Operation; `_dismissalKeys` kann als Snapshot vor dem Clear gehalten werden. DB-DELETE erst nach SnackBar-Timeout. Undo = Snapshot zurückschreiben, kein DB-Touch nötig. |

---

## 4. Bevorzugtes Pattern: Optimistic-Local-Restore mit Delayed-Commit

Für alle als „machbar" eingestuften Pfade gilt ein einheitliches Pattern:

```
1. User drückt "Löschen"
2. Provider markiert Item als `_pendingDelete` (bleibt im Cache, wird aus UI-Getter-Liste gefiltert)
3. AppFeedback.success() zeigt SnackBar mit Undo-Action (Timeout: 4 Sekunden)
4a. User drückt "Rückgängig" → Provider entfernt `_pendingDelete`-Marker → Item taucht wieder auf → kein DB-Touch
4b. SnackBar dismissed (Timeout oder Swipe) → Provider führt DB-UPDATE (deleted_at setzen) aus → entfernt Item aus Cache
```

**Warum Delayed-Commit statt DB-Restore:**
- Vermeidet vollständig das RLS-Problem bei Restore-UPDATEs
- Keine neue Repository-Methode (`restoreDeal` etc.) nötig
- Keine neue Migrations
- Kein Roundtrip bei Undo — sofortige lokale Reaktion
- Race-Condition-Risiko minimal: 4-Sekunden-Fenster, kein anderer Client liest `deleted_at IS NULL`-Items aus dem Cache

**Provider-Implementierung (Skizze, kein Code-Write):**
- `Set<int> _pendingDeleteDealIds` in `InventoryProvider`
- Getter `List<Deal> get deals` filtert `_pendingDeleteDealIds` heraus
- `Future<void> deleteDealWithUndo(int id, {required VoidCallback onCommit})`: markiert als pending, ruft `onCommit` nach Timeout
- Analog für `deleteSupplierWithUndo`, `deleteInventoryItemWithUndo`

---

## 5. Empfehlungen für A3 und A5

### A3 — Inbox-Screen

**Pfad `dismissParsedMessage` (matched/unclassified Mails):**
- **Kein Undo** implementieren — RLS blockt UPDATE auf `parsed_messages`. SnackBar ohne Undo-Action.
- Stattdessen: den bestehenden RLS-Bug dokumentieren (UPDATE scheitert still). Als separater Fix-Task: entweder `FOR UPDATE`-Policy für `parsed_messages` ergänzen (benötigt Migration) oder den Dismiss-Pfad auf eine SECURITY-DEFINER-RPC umstellen. Beides ist out-of-scope für diesen UI-Plan.
- Die `clearDismissals`-Aktion (Filter zurücksetzen) **bekommt Undo** via Delayed-Commit (trivial, rein lokal).

**Pfad `markSuggestionRejected` (Suggestion-Tab):**
- **Undo implementieren** mit Delayed-Commit. Der lokale `_dismissalKeys`-State wird als Snapshot vor dem Insert gehalten; DB-Insert erst nach SnackBar-Timeout.

### A5 — Deal-Delete

**Pfad `deleteDeal`:**
- **Undo implementieren** mit Delayed-Commit-Pattern. RLS erlaubt es; Soft-Delete ist bereits vorhanden.
- `deleteDeal` im Provider bleibt erhalten; zusätzlich neues `scheduleDealDelete(int id, {Duration delay = const Duration(seconds: 4)})` oder die Widget-Ebene koordiniert das Timing über den AppFeedback-Undo-Callback.
- **Wichtig:** Provider muss `_pendingDeleteDealIds` als `Set<int>` führen, `deals`-Getter filtert diese IDs heraus. Erst nach SnackBar-Dismiss ruft die UI `deleteDeal()` auf dem Provider auf (der dann den DB-Call macht).

---

## 6. Empfohlene Anpassung der Plan-Tasks A3 und A5

### A3 (Inbox-Undo)

Undo nur für:
- **Ja:** `clearDismissals` ("Discard-Filter geleert") — Delayed-Commit, trivial
- **Ja:** `markSuggestionRejected` — Delayed-Commit, DB-Dismiss-Insert verzögert
- **Nein:** `dismissParsedMessage` — RLS-Blocker. SnackBar ohne Undo.

Originalplan-Formulierung „Undo-Action bei Mail verwerfen" präzisieren: nur für Suggestion-Verwerfen, nicht für matched/unclassified ParsedMessage-Dismiss.

### A5 (Deal-Delete-Undo)

- **Ja:** `deleteDeal` und `deleteDeals` — Delayed-Commit machbar
- Pattern: Widget hält Timer, ruft `provider.deleteDeal()` nach Timeout. Bei Undo: Timer canceln, fertig.
- Kein neuer Restore-API-Call, kein neues Repository, keine Migration.

### A6b (Inventory Item), A6c (Supplier)

- **Ja:** `deleteInventoryItem`, `deleteSupplier` — beide Soft-Delete, RLS OK, Delayed-Commit
- Beide in A6b/A6c ergänzen: Undo-Action in SnackBar + Timer-Logik analog A5

### A4a (Mailbox-Account)

- **Nein:** `deleteMailboxAccount` — Hard-Delete. Nur Confirm-Dialog, kein Undo. `confirmDestructiveBody` reicht.

---

## 7. Zusammenfassung

**5 Delete-Pfade — Verdict:**

1. **Inbox-Mail verwerfen** (`dismissParsedMessage`): Undo NICHT machbar — RLS blockt UPDATE auf `parsed_messages`. Kein `FOR UPDATE`-Policy in `20260507000000_inbox.sql`.
2. **Inbox-Suggestion verwerfen** (`markSuggestionRejected`): Undo machbar — Optimistic-Local-Restore mit Delayed-Commit. RLS erlaubt DELETE auf `inbox_dismissals`.
3. **Deal löschen** (`deleteDeal`): Undo machbar — Soft-Delete + RLS-UPDATE erlaubt in `20260504000500_data_workspace_scope.sql` Z. 261–265 (kein `deleted_at`-Guard). Delayed-Commit bevorzugt.
4. **Inventory Item löschen** (`deleteInventoryItem`): Undo machbar — identisches RLS-Pattern Z. 337–343. Delayed-Commit.
5. **Supplier löschen** (`deleteSupplier`): Undo machbar — identisches RLS-Pattern Z. 318–324. Delayed-Commit.
6. **Mailbox-Account entfernen** (`deleteMailboxAccount`): Undo NICHT sinnvoll — Hard-Delete. Kein Restore.
7. **Discard-Filter leeren** (`clearDismissals`): Undo trivial machbar — rein lokal via Snapshot.

**A3 implementieren:** Ja, mit Undo für Suggestion-Verwerfen und Filter-Clear. Kein Undo für ParsedMessage-Dismiss.  
**A5 implementieren:** Ja, mit Delayed-Commit-Undo für `deleteDeal`.  
**Pattern für alle „Ja"-Pfade:** Optimistic-Local-Restore mit Delayed-Commit (kein DB-Restore-Touch, kein RLS-Risiko, keine neue Migration).
