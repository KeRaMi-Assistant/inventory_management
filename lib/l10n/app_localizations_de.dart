// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Lagerverwaltung';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionEdit => 'Bearbeiten';

  @override
  String get actionAdd => 'Hinzufügen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionBack => 'Zurück';

  @override
  String get actionOk => 'OK';

  @override
  String get actionYes => 'Ja';

  @override
  String get actionNo => 'Nein';

  @override
  String get actionConfirm => 'Bestätigen';

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get actionRefresh => 'Aktualisieren';

  @override
  String get actionReset => 'Zurücksetzen';

  @override
  String get actionSelectAll => 'Alle auswählen';

  @override
  String get actionDeselect => 'Auswahl aufheben';

  @override
  String get actionSearch => 'Suchen';

  @override
  String get actionClear => 'Leeren';

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionExport => 'Exportieren';

  @override
  String get actionImport => 'Importieren';

  @override
  String get actionDuplicate => 'Duplizieren';

  @override
  String get actionCopy => 'Kopieren';

  @override
  String get actionShare => 'Teilen';

  @override
  String get actionDownload => 'Herunterladen';

  @override
  String get actionUpload => 'Hochladen';

  @override
  String get actionOpen => 'Öffnen';

  @override
  String get actionApply => 'Anwenden';

  @override
  String get actionLoading => 'Lädt …';

  @override
  String get actionSaving => 'Speichert …';

  @override
  String get actionDeleting => 'Löscht …';

  @override
  String get commonAll => 'Alle';

  @override
  String get commonNone => 'Keiner';

  @override
  String get commonOptional => 'optional';

  @override
  String get commonRequired => 'Pflichtfeld';

  @override
  String get commonNotSet => 'Nicht gesetzt';

  @override
  String get commonUnknown => 'Unbekannt';

  @override
  String commonItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String commonSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDeals => 'Deals';

  @override
  String get navTickets => 'Tickets';

  @override
  String get navInventory => 'Lager';

  @override
  String get navSuppliers => 'Lieferanten';

  @override
  String get navStatistics => 'Statistiken';

  @override
  String get navActivity => 'Aktivität';

  @override
  String get navHelp => 'Hilfe';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get fieldEmail => 'E-Mail';

  @override
  String get fieldPassword => 'Passwort';

  @override
  String get fieldNewPassword => 'Neues Passwort';

  @override
  String get fieldConfirmPassword => 'Passwort bestätigen';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNote => 'Notiz';

  @override
  String get passwordRequired => 'Passwort erforderlich';

  @override
  String get loginSubtitle => 'Mit deinem Konto anmelden';

  @override
  String get loginModePersonal => 'Persönlich';

  @override
  String get loginModeTeam => 'Team';

  @override
  String get loginTeamIdLabel => 'Team-ID';

  @override
  String get loginTeamIdHelp =>
      'Die Workspace-ID, die der Team-Owner geteilt hat.';

  @override
  String get loginTeamIdRequired => 'Team-ID erforderlich';

  @override
  String get loginTeamIdInvalid => 'Ungültige Team-ID (UUID erwartet)';

  @override
  String get loginTeamNotMember => 'Du bist kein Mitglied dieses Teams.';

  @override
  String get loginForgotPassword => 'Passwort vergessen?';

  @override
  String get loginSubmit => 'Anmelden';

  @override
  String get loginInProgress => 'Anmelden …';

  @override
  String get loginContinueWith => 'oder weiter mit';

  @override
  String get loginWithGoogle => 'Mit Google anmelden';

  @override
  String get loginWithApple => 'Mit Apple anmelden';

  @override
  String get loginNoAccount => 'Noch kein Konto?';

  @override
  String get loginRegister => 'Registrieren';

  @override
  String get registerTitle => 'Konto erstellen';

  @override
  String get registerSubtitle => 'Lege ein neues Konto an, um loszulegen.';

  @override
  String get registerSubmit => 'Registrieren';

  @override
  String get registerInProgress => 'Registriert …';

  @override
  String get registerHasAccount => 'Bereits ein Konto?';

  @override
  String get registerLogin => 'Anmelden';

  @override
  String get forgotTitle => 'Passwort zurücksetzen';

  @override
  String get forgotSubtitle => 'Wir senden dir einen Link zum Zurücksetzen.';

  @override
  String get forgotSubmit => 'Link senden';

  @override
  String get forgotSent => 'Reset-Link gesendet. Bitte prüfe dein Postfach.';

  @override
  String get forgotBackToLogin => 'Zurück zum Login';

  @override
  String get resetTitle => 'Neues Passwort setzen';

  @override
  String get resetSubtitle => 'Wähle ein neues Passwort für dein Konto.';

  @override
  String get resetSubmit => 'Passwort speichern';

  @override
  String get resetSuccess => 'Passwort aktualisiert.';

  @override
  String get resetMismatch => 'Passwörter stimmen nicht überein.';

  @override
  String get verifyTitle => 'E-Mail bestätigen';

  @override
  String get verifySubtitle => 'Wir haben dir einen Bestätigungslink gesendet.';

  @override
  String get verifyResend => 'Erneut senden';

  @override
  String get splashSyncing => 'Synchronisiere mit Cloud …';

  @override
  String get sessionExpiringSoon => 'Sitzung läuft bald ab.';

  @override
  String get sessionExtend => 'Verlängern';

  @override
  String get sessionExtendFailed => 'Sitzung konnte nicht verlängert werden.';

  @override
  String get headerSearchHint => 'Suchen';

  @override
  String get headerImportCsv => 'CSV importieren';

  @override
  String get headerExportCsv => 'CSV exportieren';

  @override
  String csvExportSuccess(Object path) {
    return 'Exportiert: $path';
  }

  @override
  String get csvImportConfirmTitle => 'CSV importieren';

  @override
  String get csvImportConfirmText =>
      'Deals werden hinzugefügt. Shops, Käufer und Lagerbestand werden nur importiert, wenn noch kein Eintrag mit demselben Namen existiert.';

  @override
  String get csvImportPickFile => 'Datei auswählen';

  @override
  String csvImportSummary(
    int deals,
    int shops,
    int buyers,
    int suppliers,
    int items,
  ) {
    return '$deals Deals, $shops Shops, $buyers Käufer, $suppliers Lieferanten, $items Lagerartikel importiert.';
  }

  @override
  String errorPrefix(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get accountMenuSignedInAs => 'Angemeldet als';

  @override
  String get accountMenuSignOut => 'Abmelden';

  @override
  String get accountMenuDeleteAccount => 'Konto löschen';

  @override
  String get accountMenuActiveWorkspace => 'Aktiver Workspace';

  @override
  String get logoutConfirmTitle => 'Wirklich abmelden?';

  @override
  String get logoutConfirmText =>
      'Du wirst zurück zum Login geleitet. Nicht synchronisierte Eingaben gehen verloren.';

  @override
  String get deleteAccountTitle => 'Konto endgültig löschen?';

  @override
  String get deleteAccountText =>
      'Dein Konto und alle deine Daten werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountConfirmInstruction =>
      'Tippe LÖSCHEN zur Bestätigung:';

  @override
  String get deleteAccountConfirmKeyword => 'LÖSCHEN';

  @override
  String get deleteAccountSubtitle =>
      'Löscht dein Konto und alle Daten unwiderruflich.';

  @override
  String get deleteAccountFailed => 'Konto konnte nicht gelöscht werden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsTabBuyers => 'Käufer';

  @override
  String get settingsTabShops => 'Shops';

  @override
  String get settingsTabTeam => 'Team';

  @override
  String get settingsTabPush => 'Push';

  @override
  String get settingsTabShipping => 'Versand';

  @override
  String get settingsTabGeneral => 'Allgemein';

  @override
  String get shippingIntroTitle => 'Carrier-API-Keys';

  @override
  String get shippingIntroBody =>
      'Hinterlege je Carrier einen API-Key, damit die App alle 4 Stunden den Sendungsstatus pollt und Deals automatisch auf „Angekommen“ setzt.';

  @override
  String get shippingNoAccess =>
      'Nur Workspace-Owner und Admins dürfen Carrier-Keys pflegen.';

  @override
  String get shippingNotConfigured => 'Nicht hinterlegt';

  @override
  String get shippingSetKey => 'API-Key hinterlegen';

  @override
  String get shippingUpdateKey => 'API-Key ersetzen';

  @override
  String get shippingDeleteKey => 'Entfernen';

  @override
  String shippingKeyDialogTitle(Object carrier) {
    return '$carrier-API-Key';
  }

  @override
  String get shippingKeyHelp =>
      'Der Key wird serverseitig verschlüsselt. Nach dem Speichern siehst du nur noch die letzten 4 Zeichen.';

  @override
  String get shippingKeyTooShort => 'Mindestens 8 Zeichen eingeben.';

  @override
  String get shippingKeySaved => 'Gespeichert.';

  @override
  String get shippingKeyDeleted => 'Entfernt.';

  @override
  String shippingLastChecked(Object when) {
    return 'Zuletzt gepollt: $when';
  }

  @override
  String shippingLastError(Object error) {
    return 'Letzter Fehler: $error';
  }

  @override
  String get shippingLastNeverPolled => 'Noch nicht gepollt.';

  @override
  String get buyersEmpty => 'Noch keine Käufer angelegt.';

  @override
  String get buyersAdd => 'Käufer hinzufügen';

  @override
  String get buyersDeleteTitle => 'Käufer löschen';

  @override
  String buyersDeleteConfirm(Object name) {
    return 'Käufer „$name\" wirklich löschen?';
  }

  @override
  String get shopsEmpty => 'Noch keine Shops angelegt.';

  @override
  String get shopsAdd => 'Shop hinzufügen';

  @override
  String get shopsDeleteTitle => 'Shop löschen';

  @override
  String shopsDeleteConfirm(Object name) {
    return 'Shop „$name\" wirklich löschen?';
  }

  @override
  String teamLoadFailed(Object error) {
    return 'Team-Daten konnten nicht geladen werden: $error';
  }

  @override
  String get teamMigrationHint =>
      'Stelle sicher, dass die Workspace-Migration in Supabase ausgeführt wurde.';

  @override
  String get teamNoWorkspace => 'Kein Workspace gefunden.';

  @override
  String teamWorkspaceSummary(Object id, int count) {
    return 'Workspace-ID $id · $count Mitglied(er)';
  }

  @override
  String get teamCopyId => 'ID kopieren';

  @override
  String get teamCopyIdSnack => 'Workspace-ID kopiert.';

  @override
  String get teamRename => 'Umbenennen';

  @override
  String get teamRenameTitle => 'Workspace umbenennen';

  @override
  String get teamRenameLabel => 'Alias';

  @override
  String get teamRenameHint => 'z.B. Acme GmbH';

  @override
  String get teamRenameSuccess => 'Workspace umbenannt.';

  @override
  String teamRenameFailed(Object error) {
    return 'Umbenennen fehlgeschlagen: $error';
  }

  @override
  String get teamMembers => 'Mitglieder';

  @override
  String get teamInvites => 'Offene Einladungen';

  @override
  String get teamInvite => 'Einladen';

  @override
  String teamInviteFailed(Object error) {
    return 'Einladen fehlgeschlagen: $error';
  }

  @override
  String get teamInviteTitle => 'Mitglied einladen';

  @override
  String get teamInviteEmailLabel => 'E-Mail-Adresse';

  @override
  String get teamInviteRoleLabel => 'Rolle';

  @override
  String teamMemberSince(Object role, Object date) {
    return '$role · seit $date';
  }

  @override
  String teamInviteExpires(Object role, Object date) {
    return 'Rolle: $role · läuft ab $date';
  }

  @override
  String get teamMemberRemove => 'Entfernen';

  @override
  String get teamInviteRevoke => 'Einladung zurückziehen';

  @override
  String get teamSwitchWorkspace => 'Workspace wechseln';

  @override
  String get teamRoleOwner => 'Owner';

  @override
  String get teamRoleAdmin => 'Admin';

  @override
  String get teamRoleMember => 'Mitglied';

  @override
  String get teamRoleViewer => 'Read-only';

  @override
  String get settingsTaxRateTitle => 'MwSt-Satz';

  @override
  String get settingsTaxRateSubtitle =>
      'Standard: 19%. Neue Deals berechnen EK Brutto aktuell mit 1,19.';

  @override
  String get settingsSortTitle => 'Standard-Sortierung';

  @override
  String get settingsSortSubtitle =>
      'Deals werden standardmäßig nach Bestelldatum absteigend angezeigt.';

  @override
  String get settingsSortValue => 'Datum ↓';

  @override
  String get settingsCloudTitle => 'Cloud-Speicher';

  @override
  String get settingsCloudSubtitle =>
      'Daten werden in deinem Supabase-Konto gespeichert und über alle Geräte synchronisiert.';

  @override
  String get settingsDataTitle => 'Datenbestand';

  @override
  String settingsDataSubtitle(int deals, int buyers, int shops, int items) {
    return '$deals Deals · $buyers Käufer · $shops Shops · $items Lagerartikel';
  }

  @override
  String get settingsLanguageSection => 'Sprache';

  @override
  String get settingsLanguageTitle => 'Sprache / Language';

  @override
  String get settingsLanguageSubtitle =>
      'Auf Deutsch oder Englisch umstellen. „System\" folgt dem Geräte-Setting.';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageDe => 'Deutsch';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsStatsSection => 'Statistik';

  @override
  String get settingsMonthlyGoalTitle => 'Monatliches Profit-Ziel';

  @override
  String get settingsMonthlyGoalSubtitle =>
      'Wird in der Statistik als Fortschrittsring + Forecast angezeigt.';

  @override
  String get settingsMonthlyGoalDialogTitle => 'Profit-Ziel pro Monat';

  @override
  String get settingsLowStockTitle => 'Schwellwert „niedriger Bestand\"';

  @override
  String get settingsLowStockSubtitle =>
      'Lagerartikel unter diesem Wert werden als kritisch markiert.';

  @override
  String get settingsLowStockDialogTitle => 'Niedriger Bestand';

  @override
  String get settingsLowStockUnit => 'Stück';

  @override
  String settingsLowStockTrailing(int value) {
    return '< $value Stück';
  }

  @override
  String get pushFirebaseMissing =>
      'Firebase ist auf diesem Gerät nicht eingerichtet — Einstellungen werden gespeichert, aber Push-Nachrichten werden erst nach der Firebase-Einrichtung zugestellt.';

  @override
  String get pushSectionTypes => 'Benachrichtigungstypen';

  @override
  String get pushMhdTitle => 'MHD-Warnungen';

  @override
  String get pushMhdSubtitle => 'Charge läuft bald ab (basierend auf MHD)';

  @override
  String get pushMhdLeadTitle => 'MHD-Vorwarnung';

  @override
  String pushMhdLeadSubtitle(int days) {
    return '$days Tage vor Ablauf';
  }

  @override
  String pushMhdLeadSliderLabel(int days) {
    return '$days Tage';
  }

  @override
  String get pushDeliveryTitle => 'Lieferungs-Hinweise';

  @override
  String get pushDeliverySubtitle =>
      'Wenn ein Deal heute ankommen sollte (Status Unterwegs)';

  @override
  String get pushPaymentTitle => 'Zahlungs-Erinnerungen';

  @override
  String pushPaymentSubtitle(int days) {
    return 'Käufer hat nach $days Tagen noch nicht gezahlt';
  }

  @override
  String get pushPaymentLeadTitle => 'Mahn-Schwelle';

  @override
  String pushPaymentLeadSubtitle(int days) {
    return '$days Tage';
  }

  @override
  String get pushSectionInfo => 'Hinweise';

  @override
  String get pushDailyCheckTitle => 'Tägliche Prüfung';

  @override
  String get pushDailyCheckSubtitle =>
      'Server prüft täglich um 09:00 Uhr (Europe/Berlin) und versendet fällige Nachrichten.';

  @override
  String get pushDedupTitle => 'Dedup';

  @override
  String get pushDedupSubtitle =>
      'Jede Warnung wird pro Charge/Deal nur einmal versendet — auch über mehrere Geräte hinweg.';

  @override
  String pushSaveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get dealNew => 'Neuer Deal';

  @override
  String get dealEdit => 'Deal bearbeiten';

  @override
  String get dealOrderDate => 'Bestelldatum';

  @override
  String get dealArrivalDate => 'Ankunftsdatum';

  @override
  String get dealProduct => 'Produkt';

  @override
  String get dealShop => 'Shop';

  @override
  String get dealQuantity => 'Anzahl';

  @override
  String get dealQuantityShort => 'Anz.';

  @override
  String get dealShippingType => 'Versandtyp';

  @override
  String get dealReship => 'Reship';

  @override
  String get dealDropship => 'Dropship';

  @override
  String get dealReceipt => 'Beleg';

  @override
  String get dealReceiptYes => 'Ja';

  @override
  String get dealReceiptNo => 'Nein';

  @override
  String get dealStatus => 'Status';

  @override
  String get dealNote => 'Notiz';

  @override
  String get dealComments => 'Kommentare';

  @override
  String get dealCommentPlaceholder => 'Notiz oder Kommentar hinzufügen…';

  @override
  String get dealCommentSend => 'Senden';

  @override
  String get dealCommentEmpty => 'Noch keine Kommentare.';

  @override
  String dealCommentLoadFailed(Object error) {
    return 'Konnte Kommentare nicht laden: $error';
  }

  @override
  String dealCommentSaveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get dealCommentDeleteTitle => 'Kommentar löschen?';

  @override
  String get dealCommentDeleteText =>
      'Dieser Kommentar wird unwiderruflich entfernt.';

  @override
  String dealCommentDeleteFailed(Object error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get dealSectionProduct => 'Produkt & Versand';

  @override
  String get dealSectionPrices => 'Preise';

  @override
  String get dealSectionBuyer => 'Käufer & Status';

  @override
  String get dealSectionDateTracking => 'Datum & Tracking';

  @override
  String get dealSectionAttachments => 'Anhänge';

  @override
  String get dealSectionNote => 'Notiz';

  @override
  String get dealEkPriceLabel => 'EK Preis als:';

  @override
  String get dealPriceTypeNet => 'Netto';

  @override
  String get dealPriceTypeGross => 'Brutto';

  @override
  String get dealEkAmount => 'EK-Betrag';

  @override
  String get dealVkAmount => 'VK-Betrag';

  @override
  String get dealCurrency => 'Währung';

  @override
  String get dealTaxRate => 'MwSt-Satz %';

  @override
  String get dealTaxRateHint => 'z.B. 19';

  @override
  String get dealTaxRateInvalid => 'Ungültige Zahl';

  @override
  String get dealTaxRateRange => '0 – 100';

  @override
  String get dealBuyer => 'Käufer';

  @override
  String get dealBuyerNone => '— Kein —';

  @override
  String get dealTicketNumber => 'Ticketnummer';

  @override
  String get dealTracking => 'Tracking';

  @override
  String get dealTicketUrl => 'Ticket-URL (optional)';

  @override
  String get dealTicketUrlHint => 'Link aus Discord einfügen…';

  @override
  String get dealDiscordChannelHint =>
      'Kanal finden → Rechtsklick → „Link kopieren\" → hier einfügen';

  @override
  String get dealDiscordTicketOpen => 'Ticket in Discord öffnen';

  @override
  String dealDiscordServerOpen(int n) {
    return 'Server $n in Discord öffnen';
  }

  @override
  String get dealProfitPreviewMissing => 'Profit-Vorschau: EK und VK eintragen';

  @override
  String dealProfitPreviewLine(Object perUnit, Object total) {
    return 'Profit/Stück $perUnit · Gesamt $total';
  }

  @override
  String get dealStatusOrdered => 'Bestellt';

  @override
  String get dealStatusShipping => 'Unterwegs';

  @override
  String get dealStatusArrived => 'Angekommen';

  @override
  String get dealStatusInvoiced => 'Rechnung gestellt';

  @override
  String get dealStatusDone => 'Done';

  @override
  String get dealColId => 'ID';

  @override
  String get dealColEkNet => 'EK Netto';

  @override
  String get dealColEkGross => 'EK Brutto';

  @override
  String get dealColVk => 'VK';

  @override
  String get dealColArrival => 'Ankunft';

  @override
  String get dealColTicket => 'Ticket';

  @override
  String get dealColProfitUnit => 'Profit/Stk';

  @override
  String get dealColProfitTotal => 'Ges. Profit';

  @override
  String get dealColReceivable => 'Zu bekommen';

  @override
  String get dealsEmpty => 'Keine Deals gefunden';

  @override
  String get dealsEmptyHint => 'Filter anpassen oder einen neuen Deal anlegen.';

  @override
  String get dealsSearchHint => 'Produkt, Ticket, Tracking, Notiz';

  @override
  String get dealsFilterDate => 'Datum';

  @override
  String get dealsFilterReset => 'Filter zurücksetzen';

  @override
  String get dealDeleteTitle => 'Eintrag löschen';

  @override
  String dealDeleteConfirm(Object product, int id) {
    return '„$product\" (ID: $id) wirklich löschen?';
  }

  @override
  String get bulkStatus => 'Status';

  @override
  String get bulkBuyer => 'Käufer';

  @override
  String get bulkBuyerNone => 'Kein Käufer';

  @override
  String get bulkChangeStatusTooltip => 'Status ändern';

  @override
  String get bulkAssignBuyerTooltip => 'Käufer zuweisen';

  @override
  String get checkInDealTitle => 'Artikel ins Lager einbuchen?';

  @override
  String checkInDealText(int quantity, Object product) {
    return '${quantity}x $product als Lagerartikel anlegen.';
  }

  @override
  String get checkInButton => 'Einbuchen';

  @override
  String get checkInNo => 'Nein';

  @override
  String get inventoryStatusInStock => 'Im Lager';

  @override
  String get inventoryStatusReserved => 'Reserviert';

  @override
  String get inventoryStatusShipped => 'Versandt';

  @override
  String get inventoryStatusSold => 'Verkauft';

  @override
  String get helpTitle => 'Hilfe';

  @override
  String get helpQuickStart => 'Schnellstart';

  @override
  String get helpStepShopsBuyersTitle => 'Shops & Käufer anlegen';

  @override
  String get helpStepShopsBuyersDesc =>
      'Lege in den Einstellungen deine Bezugsquellen und Käufer an. Beides ist später Pflichtfeld beim Deal.';

  @override
  String get helpStepFirstDealTitle => 'Ersten Deal eintragen';

  @override
  String get helpStepFirstDealDesc =>
      'Tippe unten auf „Neuer Deal\". Das Produktfeld schlägt vorherige Produkte vor, sobald du tippst.';

  @override
  String get helpStepStatsTitle => 'Statistik & Ziele';

  @override
  String get helpStepStatsDesc =>
      'Im Tab „Statistiken\" siehst du Cashflow, Profit und MwSt-Quartale. Setze in den Einstellungen ein monatliches Profit-Ziel.';

  @override
  String get helpDiscordSection => 'Discord-Integration';

  @override
  String get helpDiscordHowTitle => 'So funktioniert die Verknüpfung';

  @override
  String get helpDiscordHowDesc =>
      'Trage beim Deal die Ticketnummer ein — die App zeigt dann Buttons zum direkten Öffnen der konfigurierten Discord-Server. Kanal finden, Link kopieren, in „Ticket-URL\" einfügen.';

  @override
  String get helpDiscordStep1Title => 'Entwicklermodus aktivieren';

  @override
  String get helpDiscordStep1Desc =>
      'Discord → Einstellungen → Erweitert → Entwicklermodus einschalten.';

  @override
  String get helpDiscordStep2Title => 'Server-ID kopieren';

  @override
  String get helpDiscordStep2Desc =>
      'Rechtsklick auf den Servernamen → „Server-ID kopieren\".';

  @override
  String get helpDiscordStep3Title => 'Server-ID beim Käufer hinterlegen';

  @override
  String get helpDiscordStep3Desc =>
      'Einstellungen → Käufer-Tab → Käufer bearbeiten → Discord Server IDs.';

  @override
  String get helpDiscordConfiguredIds => 'Konfigurierte Server-IDs';

  @override
  String get helpDiscordNoBuyers => 'Noch keine Käufer angelegt';

  @override
  String get helpDiscordNoBuyersDesc =>
      'Lege in den Einstellungen Käufer an, um Server-IDs zu hinterlegen.';

  @override
  String get helpDiscordNoServerIds => 'Keine Server-IDs konfiguriert';

  @override
  String get helpContactSection => 'Kontakt & Feedback';

  @override
  String get helpContactReportTitle => 'Probleme melden';

  @override
  String get helpContactReportDesc =>
      'Beschreibe das Problem so genau wie möglich. Screenshots helfen.';

  @override
  String get helpSearchHint => 'Hilfe durchsuchen…';

  @override
  String get helpSearchEmptyTitle => 'Nichts gefunden';

  @override
  String get helpSearchEmptyDesc =>
      'Versuche andere Begriffe, prüfe die Schreibweise oder lösche das Suchfeld, um alle Sektionen zu sehen.';

  @override
  String get helpExpandAll => 'Alle ausklappen';

  @override
  String get helpCollapseAll => 'Alle einklappen';

  @override
  String helpResultsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sektionen gefunden',
      one: '1 Sektion gefunden',
      zero: 'Keine Treffer',
    );
    return '$_temp0';
  }

  @override
  String get helpEntryWord => 'Eintrag';

  @override
  String get helpEntriesWord => 'Einträge';

  @override
  String get helpStepLoginTitle => 'Konto anlegen & einloggen';

  @override
  String get helpStepLoginDesc =>
      'Registriere dich mit E-Mail oder logge dich per Google/Apple ein. Bestätige bei Bedarf deine E-Mail über den zugesandten Link, dann kannst du sofort starten.';

  @override
  String get helpStepWorkspaceTitle => 'Workspace einrichten';

  @override
  String get helpStepWorkspaceDesc =>
      'Beim ersten Login wird automatisch ein Workspace für dich angelegt. Über das Workspace-Menü oben rechts kannst du weitere Workspaces erstellen oder Mitglieder einladen.';

  @override
  String get helpStepInboxTitle => 'Postfach verbinden';

  @override
  String get helpStepInboxDesc =>
      'Hänge dein Bestell-Postfach (Gmail/Outlook/IONOS) unter Einstellungen → Postfach an. Bestellbestätigungen, Versand- und Liefermails werden danach automatisch erkannt.';

  @override
  String get helpStepInventoryTitle => 'Lagerbestand pflegen';

  @override
  String get helpStepInventoryDesc =>
      'Lege im Lager-Tab Artikel mit Stückzahl und Mindestbestand an. Verkaufte Stück verschwinden automatisch aus dem Bestand und tauchen im „Verkauft\"-Tab auf.';

  @override
  String get helpInboxSection => 'Postfach (E-Mail-Import)';

  @override
  String get helpInboxIntro =>
      'Die App liest dein Mail-Postfach via IMAP, erkennt Bestellbestätigungen und Versandmails und schlägt sie als Deals vor. Es werden keine Mails verschickt.';

  @override
  String get helpInboxGmailTitle => 'Gmail / Google Workspace verbinden';

  @override
  String get helpInboxGmailDesc =>
      'Gmail erlaubt keinen Login mit deinem normalen Passwort. Du brauchst ein App-Passwort:\n• Aktiviere die 2-Faktor-Authentifizierung unter myaccount.google.com → Sicherheit.\n• Öffne myaccount.google.com/apppasswords, vergib einen Namen (z. B. „Lager-App\") und kopiere das 16-stellige App-Passwort.\n• In der App: Einstellungen → Postfach → IMAP-Server „imap.gmail.com\", Port 993, SSL, Benutzername = deine Mail, Passwort = das App-Passwort.';

  @override
  String get helpInboxOutlookTitle => 'Outlook.com / Microsoft 365 verbinden';

  @override
  String get helpInboxOutlookDesc =>
      'Outlook und Microsoft 365 nutzen ebenfalls App-Passwörter:\n• Logge dich in account.microsoft.com ein → Sicherheit → Erweiterte Sicherheitsoptionen → App-Passwort erstellen.\n• In der App: IMAP-Server „outlook.office365.com\", Port 993, SSL, Benutzername = deine Mail, Passwort = App-Passwort.\n• Hinweis: Schul-/Geschäftskonten erfordern oft eine Freigabe durch den Admin.';

  @override
  String get helpInboxIonosTitle => 'IONOS / 1&1 verbinden';

  @override
  String get helpInboxIonosDesc =>
      'Bei IONOS funktioniert der normale Mail-Login direkt:\n• IMAP-Server „imap.ionos.de\" (oder „.com\" je nach Region), Port 993, SSL.\n• Benutzername = vollständige Mail-Adresse, Passwort = dein Postfach-Passwort.\n• Falls Login scheitert: in der IONOS-Webmail unter „Einstellungen → Sicherheit\" prüfen, ob IMAP aktiviert ist.';

  @override
  String get helpInboxTabsTitle => 'Die drei Inbox-Tabs';

  @override
  String get helpInboxTabsDesc =>
      'Eingehende Mails landen in drei Tabs, je nachdem wie eindeutig die App sie zuordnen kann.';

  @override
  String get helpInboxTabSuggestions =>
      'Vorschläge — Bestellbestätigungen, die noch nicht zu einem Deal gehören. Tippe auf eine Mail, prüfe die erkannten Daten und übernimm sie als neuen Deal.';

  @override
  String get helpInboxTabUpdated =>
      'Aktualisiert — Mails, die einen bestehenden Deal verändern (z. B. Versand-Update, Stornierung). Hier siehst du, was die Pipeline automatisch eingespielt hat.';

  @override
  String get helpInboxTabUnclassified =>
      'Unklassifiziert — Mails, die nicht eindeutig zugeordnet werden konnten. Du kannst sie manuell einem Deal zuweisen oder als irrelevant markieren.';

  @override
  String get helpInboxWhitelistTitle => 'Warum sehe ich manche Mails nicht?';

  @override
  String get helpInboxWhitelistDesc =>
      'Die App liest nur Mails von bekannten Shops/Carriern (Whitelist). Werbe-Newsletter, persönliche Mails und unbekannte Absender werden ignoriert. Wenn ein Shop fehlt, melde ihn über „Probleme melden\" — neue Adapter werden serverseitig nachgepflegt.';

  @override
  String get helpDealsSection => 'Deals';

  @override
  String get helpDealsStatusFlow =>
      'Jeder Deal durchläuft fünf Status — du kannst ihn manuell weiterschalten oder die Mail-Pipeline macht es automatisch.';

  @override
  String get helpDealsStatusOrdered =>
      'Bestellt — der Deal ist angelegt, aber noch nicht versandt. Setze diesen Status, sobald du die Bestellung getätigt hast.';

  @override
  String get helpDealsStatusInTransit =>
      'Unterwegs — Versandbestätigung erkannt oder manuell gesetzt. Tracking-Nummer wird alle paar Stunden gepollt.';

  @override
  String get helpDealsStatusArrived =>
      'Angekommen — Carrier meldet Zustellung beim Absender (dir). Der Artikel ist bereit zum Listen/Versenden.';

  @override
  String get helpDealsStatusSold =>
      'Verkauft — Käufer steht fest, Verkaufspreis ist erfasst. Der Deal zählt jetzt in die Statistiken.';

  @override
  String get helpDealsStatusDelivered =>
      'Geliefert — Endkunde hat den Artikel erhalten. Letzter Status, Deal ist abgeschlossen.';

  @override
  String get helpDealsTrackingTitle => 'Auto-Tracking aus Mails';

  @override
  String get helpDealsTrackingDesc =>
      'Sobald eine Versandmail mit Tracking-Nummer eintrifft (Amazon, DHL, DPD, UPS, Hermes, GLS), wird der passende Deal automatisch auf „Unterwegs\" gesetzt. Sobald der Carrier die Zustellung meldet, springt der Deal auf „Angekommen\".';

  @override
  String get helpDealsDropShipTitle => 'Multi-Drop-Ship';

  @override
  String get helpDealsDropShipDesc =>
      'Wenn ein Deal aus mehreren Shops besteht (Drop-Ship), kannst du beim Anlegen mehrere Bezugsquellen samt Einkaufspreisen hinterlegen. Der Profit wird über alle Quellen summiert. Die Statistik zählt den Deal als einen Verkauf.';

  @override
  String get helpInventorySection => 'Lager (Inventory)';

  @override
  String get helpInventoryAddTitle => 'Artikel anlegen';

  @override
  String get helpInventoryAddDesc =>
      'Lager-Tab → „Artikel hinzufügen\". Pflicht: Name + Stückzahl. Optional: Einkaufspreis, Mindestbestand, Verkaufskanal, Foto. Mehrfach-Stück desselben Artikels: Stückzahl erhöhen statt neu anlegen.';

  @override
  String get helpInventoryStockTitle => 'Stückzahlen aktualisieren';

  @override
  String get helpInventoryStockDesc =>
      'Tippe einen Artikel an und nutze die +/- Buttons, oder bearbeite das Mengenfeld direkt. Beim Verkauf wird die Stückzahl automatisch um 1 reduziert, wenn du den Artikel im Deal-Form auswählst.';

  @override
  String get helpInventoryMinStockTitle => 'Mindestbestand & Warnungen';

  @override
  String get helpInventoryMinStockDesc =>
      'Setze einen Mindestbestand pro Artikel (z. B. 2). Sobald die Stückzahl darunter fällt, erscheint im Dashboard und im Lager-Tab eine gelbe Warnung — und optional eine Push-Notification.';

  @override
  String get helpInventorySoldTabTitle => 'Verkauft-Tab';

  @override
  String get helpInventorySoldTabDesc =>
      'Verkaufte Artikel verschwinden aus dem Bestand und tauchen im Tab „Verkauft\" auf. Dort siehst du Käufer, Verkaufspreis und Profit pro Stück. Filterbar nach Datum und Käufer.';

  @override
  String get helpInventoryStockValueTitle => 'Lagerwert berechnen';

  @override
  String get helpInventoryStockValueDesc =>
      'Der Lagerwert oben im Tab summiert (Stückzahl × Einkaufspreis) für alle Artikel mit Einkaufspreis. Artikel ohne Einkaufspreis fließen mit 0 ein — bitte nachpflegen, sonst stimmt die Statistik nicht.';

  @override
  String get helpEntitiesSection => 'Käufer, Shops & Lieferanten';

  @override
  String get helpEntitiesBuyersTitle => 'Käufer (Buyers)';

  @override
  String get helpEntitiesBuyersDesc =>
      'Personen oder Plattformen, an die du verkaufst (z. B. „Tobias\", „eBay-Kleinanzeigen\", „Vinted\"). Beim Deal-Form pflichtfeldartig auswählbar — ohne Käufer kein Verkauf.';

  @override
  String get helpEntitiesShopsTitle => 'Shops';

  @override
  String get helpEntitiesShopsDesc =>
      'Online-/Offline-Quellen, bei denen du einkaufst (z. B. „Amazon\", „Saturn\", „Otto\"). Bei Versand-Mails ordnet die App die Mail automatisch dem passenden Shop zu, sofern der Adapter den Absender kennt.';

  @override
  String get helpEntitiesSuppliersTitle => 'Lieferanten (Suppliers)';

  @override
  String get helpEntitiesSuppliersDesc =>
      'Spezialfall für B2B-Bezugsquellen mit Zahlungsfrist (Net 30, Net 60). Lieferanten werden im eigenen Tab geführt und im Deal als Quelle verlinkt — die Fälligkeitsstatistik zeigt dann offene Beträge.';

  @override
  String get helpEntitiesBuyerColorTitle => 'Farb-Kodierung der Käufer';

  @override
  String get helpEntitiesBuyerColorDesc =>
      'Jedem Käufer kannst du eine Farbe zuweisen (Käufer-Karte → Farbe wählen). In der Deal-Tabelle und in den Statistiken erscheint diese Farbe, sodass du auf einen Blick siehst, an wen ein Deal ging.';

  @override
  String get helpTicketsSection => 'Tickets';

  @override
  String get helpTicketsWhatTitle => 'Was ist ein Ticket?';

  @override
  String get helpTicketsWhatDesc =>
      'Ein Ticket bündelt mehrere Deals, die zusammen an einen Käufer gehen — z. B. eine Sammelbestellung mit fünf Artikeln. Das Ticket sieht den Gesamtpreis, alle Tracking-Nummern und einen einzigen Versand-Status.';

  @override
  String get helpTicketsArchiveTitle => 'Aktiv vs. Archiv';

  @override
  String get helpTicketsArchiveDesc =>
      'Aktive Tickets sind noch nicht abgeschlossen. Sobald alle Deals im Ticket auf „Geliefert\" stehen, kannst du das Ticket archivieren — es verschwindet aus der Hauptansicht, bleibt aber in den Statistiken sichtbar.';

  @override
  String get helpStatsSection => 'Statistiken';

  @override
  String get helpStatsKpiTitle => 'KPI-Cards';

  @override
  String get helpStatsKpiDesc =>
      'Oben siehst du Umsatz, Profit, Anzahl Deals und Cashflow für den gewählten Zeitraum. Tippe eine Card an, um auf die zugehörige Detail-Ansicht zu wechseln.';

  @override
  String get helpStatsChartsTitle => 'Diagramme';

  @override
  String get helpStatsChartsDesc =>
      'Linien-Diagramm für Umsatz/Profit über Zeit, Balken-Diagramm für Top-Käufer und Top-Shops. Tippe auf einen Balken, um nach diesem Käufer/Shop zu filtern.';

  @override
  String get helpStatsFiltersTitle => 'Filter (Käufer/Shop/Datum)';

  @override
  String get helpStatsFiltersDesc =>
      'Über das Filter-Icon oben rechts kannst du Käufer, Shops und Datumsbereich kombinieren. Die Filter werden in allen Cards und Diagrammen synchron angewendet.';

  @override
  String get helpStatsTaxTitle => 'Steuer-/MwSt-Reports';

  @override
  String get helpStatsTaxDesc =>
      'Statistiken → Reiter „Steuer\" zeigt Quartals-Umsätze + MwSt-Schätzung (Klein- oder Regelunternehmer). CSV-Export pro Quartal über das Download-Icon. Die Schätzung ersetzt keine Steuerberatung.';

  @override
  String get helpWorkspaceSection => 'Workspace & Team';

  @override
  String get helpWorkspaceWhatTitle => 'Was ist ein Workspace?';

  @override
  String get helpWorkspaceWhatDesc =>
      'Ein Workspace ist ein abgeschotteter Daten-Container — alle Deals, Käufer, Shops und Lager-Artikel gehören zu genau einem Workspace. Du kannst mehrere Workspaces parallel pflegen (z. B. „Privat\" und „Geschäft\").';

  @override
  String get helpWorkspaceInviteTitle => 'Mitglieder einladen';

  @override
  String get helpWorkspaceInviteDesc =>
      'Einstellungen → Team → „Mitglied einladen\". Gib eine Mail-Adresse und eine Rolle an. Der Eingeladene bekommt eine Mail mit Link; sobald er sich registriert, taucht der Workspace bei ihm auf.';

  @override
  String get helpWorkspaceRolesTitle => 'Rollen';

  @override
  String get helpWorkspaceRoleOwner =>
      'Owner — kann alles, inklusive Workspace löschen, Mitglieder kicken und Plan ändern.';

  @override
  String get helpWorkspaceRoleAdmin =>
      'Admin — kann Daten lesen/schreiben, Mitglieder einladen, Carrier-Keys pflegen. Kann den Workspace nicht löschen.';

  @override
  String get helpWorkspaceRoleMember =>
      'Member — kann Daten lesen/schreiben, aber keine Team- oder Carrier-Einstellungen ändern.';

  @override
  String get helpWorkspacePricingTitle => 'Pricing-Tier-Limits';

  @override
  String get helpWorkspacePricingDesc =>
      'Free, Pro und Business unterscheiden sich vor allem in der Anzahl Mitglieder, der Anzahl Postfächer und ob Carrier-Polling aktiv ist. Aktuelle Limits findest du auf dem Pricing-Screen.';

  @override
  String get helpPushSection => 'Push-Notifications';

  @override
  String get helpPushIosTitle => 'iOS aktivieren';

  @override
  String get helpPushIosDesc =>
      'Beim ersten Start fragt iOS, ob die App Mitteilungen senden darf — bestätige mit „Erlauben\". Falls du es abgelehnt hast: iOS-Einstellungen → Mitteilungen → Lager-App → Mitteilungen erlauben.';

  @override
  String get helpPushAndroidTitle => 'Android aktivieren';

  @override
  String get helpPushAndroidDesc =>
      'Android 13+ fragt explizit nach Push-Erlaubnis. Falls du sie abgelehnt hast: Android-Einstellungen → Apps → Lager-App → Benachrichtigungen → aktivieren.';

  @override
  String get helpPushWhenTitle => 'Wann werden Pushs verschickt?';

  @override
  String get helpPushWhenDesc =>
      '• Neue Bestellbestätigung im Postfach\n• Tracking-Update (Versandt / Angekommen)\n• Mindestbestand unterschritten (falls aktiviert)\n• Workspace-Einladung\nÜber Einstellungen → Push kannst du einzelne Kategorien deaktivieren.';

  @override
  String get helpFaqSection => 'Häufige Fragen (FAQ)';

  @override
  String get helpFaqQ1 => 'Warum sehe ich keine Mails nach dem Postfach-Add?';

  @override
  String get helpFaqA1 =>
      'Die erste Synchronisation läuft im Hintergrund und kann je nach Postfach-Größe 1–10 Minuten dauern. Außerdem werden nur Mails von bekannten Shops/Carriern eingelesen — Werbung und persönliche Mails werden ignoriert.';

  @override
  String get helpFaqQ2 => 'Wie ändere ich die Sprache?';

  @override
  String get helpFaqA2 =>
      'Einstellungen → Allgemein → Sprache. Aktuell verfügbar: Deutsch, Englisch. Die Änderung greift sofort.';

  @override
  String get helpFaqQ3 => 'Wie lösche ich meine Daten?';

  @override
  String get helpFaqA3 =>
      'Einstellungen → Allgemein → „Konto löschen\". Du musst das Wort LÖSCHEN tippen, um zu bestätigen. Account, Workspaces und Postfach-Konfiguration werden sofort gelöscht; Mail-Metadaten und gespeicherte Bilder werden innerhalb von 30 Tagen aus der Datenbank und dem Storage entfernt.';

  @override
  String get helpFaqQ4 => 'Was passiert, wenn ich downgrade?';

  @override
  String get helpFaqA4 =>
      'Bestehende Daten bleiben erhalten. Funktionen über dem Downgrade-Limit (z. B. zusätzliche Mitglieder, Carrier-Polling) werden pausiert, bis du wieder upgradest oder die Limits aktiv reduzierst.';

  @override
  String get helpFaqQ5 => 'Wie setze ich mein Passwort zurück?';

  @override
  String get helpFaqA5 =>
      'Login-Screen → „Passwort vergessen\". Gib deine Mail an, du bekommst einen Reset-Link. Klick im Link öffnet die App und du kannst ein neues Passwort setzen.';

  @override
  String get helpFaqQ6 => 'Warum stimmt der Lagerwert nicht?';

  @override
  String get helpFaqA6 =>
      'Der Lagerwert zählt nur Artikel mit hinterlegtem Einkaufspreis. Öffne den Lager-Tab und filtere nach „Ohne Einkaufspreis\" — pflege die fehlenden Werte nach, dann passt die Summe.';

  @override
  String get helpFaqQ7 => 'Tracking aktualisiert sich nicht — was tun?';

  @override
  String get helpFaqA7 =>
      'Carrier-Polling läuft alle 4 Stunden. Prüfe in Einstellungen → Versand, ob der Carrier-API-Key hinterlegt ist. Ohne Key kann die App den Status nicht abfragen — die Mail-Pipeline ergänzt das ggf. parallel über Versandmails.';

  @override
  String get helpFaqQ8 => 'Kann ich mehrere Workspaces nutzen?';

  @override
  String get helpFaqA8 =>
      'Ja. Tippe oben rechts auf den Workspace-Namen → „Neuer Workspace\". Du wechselst per Tap zwischen Workspaces; Daten sind strikt getrennt.';

  @override
  String get helpFaqQ9 => 'Discord-Buttons fehlen beim Deal — warum?';

  @override
  String get helpFaqA9 =>
      'Buttons erscheinen nur, wenn der Käufer mindestens eine Discord-Server-ID hinterlegt hat. Einstellungen → Käufer → Käufer bearbeiten → Discord-Server-IDs ergänzen.';

  @override
  String get helpFaqQ10 => 'Wie exportiere ich meine Daten als CSV?';

  @override
  String get helpFaqA10 =>
      'Statistiken → Steuer-Reiter → Download-Icon (pro Quartal). Vollständiger Daten-Export ist in Vorbereitung — bis dahin auf Anfrage über „Probleme melden\".';

  @override
  String get helpFaqQ11 => 'Wie erstelle ich einen Steuerreport?';

  @override
  String get helpFaqA11 =>
      'Statistiken → Steuer-Reiter → Quartal wählen → CSV herunterladen. Die App zeigt Brutto, Netto und MwSt-Anteil; je nach Steuermodell (Klein- oder Regelunternehmer) wird die MwSt unterschiedlich aufbereitet.';

  @override
  String get helpFaqQ12 => 'Wie aktiviere ich den Dunkelmodus?';

  @override
  String get helpFaqA12 =>
      'Einstellungen → Allgemein → Theme → „Dunkel\". Optional „System\" — folgt dann der iOS/Android-Systemeinstellung.';

  @override
  String get helpFaqQ13 => 'Kann ich mein Konto temporär deaktivieren?';

  @override
  String get helpFaqA13 =>
      'Aktuell nicht — es gibt nur „Konto löschen\". Wenn du Push und Mail-Sync pausieren willst: Postfach in den Einstellungen entfernen und Push-Kategorien deaktivieren. Daten bleiben dann unverändert liegen.';

  @override
  String get helpFaqQ14 => 'Wie deaktiviere ich Push-Mitteilungen?';

  @override
  String get helpFaqA14 =>
      'Entweder pro Kategorie in Einstellungen → Push, oder komplett über die OS-Einstellungen (iOS-Mitteilungen / Android-Benachrichtigungen → Lager-App).';

  @override
  String get helpFaqQ15 => 'Wie suche ich gezielt in der Inbox?';

  @override
  String get helpFaqA15 =>
      'Inbox-Tab → Suchsymbol oben rechts. Du kannst nach Absender, Betreff oder Tracking-Nummer suchen. Die Suche filtert alle drei Tabs (Vorschläge / Aktualisiert / Unklassifiziert) gleichzeitig.';

  @override
  String get helpFaqQ16 => 'Warum sehe ich Deals anderer Mitglieder nicht?';

  @override
  String get helpFaqA16 =>
      'Du bist möglicherweise im falschen Workspace. Prüfe oben rechts den Workspace-Namen und wechsle ggf. Auch Filter (Käufer/Shop/Datum) können Deals ausblenden — Filter zurücksetzen mit dem „Filter leeren\"-Button.';

  @override
  String get helpTroubleSection => 'Fehlerbehebung';

  @override
  String get helpTroubleConnectionTitle => '„Keine Verbindung zum Server\"';

  @override
  String get helpTroubleConnectionDesc =>
      'Prüfe deine Internet-Verbindung und versuche „Aktualisieren\" (Pull-to-Refresh). Wenn das Problem bleibt: Status-Seite über die Webseite prüfen, ggf. ein paar Minuten warten — Supabase-Restarts brauchen kurz.';

  @override
  String get helpTroubleImapAuthTitle => '„IMAP-Login fehlgeschlagen\"';

  @override
  String get helpTroubleImapAuthDesc =>
      'Bei Gmail/Outlook: stelle sicher, dass du ein App-Passwort verwendest, kein normales Login-Passwort. Bei IONOS prüfen, ob IMAP serverseitig aktiviert ist. Tippfehler im Server-Hostname sind die häufigste Ursache.';

  @override
  String get helpTroubleSyncStuckTitle => 'Postfach-Sync hängt';

  @override
  String get helpTroubleSyncStuckDesc =>
      'Einstellungen → Postfach → Mailbox auswählen → „Re-Sync\". Falls weiterhin keine Mails kommen: Postfach entfernen und neu hinzufügen — der Bootstrap-Pump zieht dann erneut alle Mails der letzten 60 Tage.';

  @override
  String get helpTroubleNotifMissingTitle =>
      'Push-Mitteilungen kommen nicht an';

  @override
  String get helpTroubleNotifMissingDesc =>
      'Prüfe zuerst die OS-Mitteilungseinstellungen (iOS-Mitteilungen / Android-Benachrichtigungen → Lager-App → Mitteilungen erlaubt?). Dann in der App Einstellungen → Push: prüfe, ob die einzelnen Kategorien aktiviert sind. Wenn alles auf „erlaubt\" steht und trotzdem nichts kommt, einmal aus- und wieder einloggen — dabei wird der Push-Token neu registriert.';

  @override
  String get helpTroubleStatsEmptyTitle => 'Statistiken sind leer';

  @override
  String get helpTroubleStatsEmptyDesc =>
      'Statistiken zählen nur Deals mit Status „Verkauft\" oder „Geliefert\" und Verkaufspreis > 0. Prüfe deinen Datumsfilter (oben rechts), eventuell ist er auf einen leeren Zeitraum gesetzt.';

  @override
  String get helpTroubleLoginFailedTitle => 'Login funktioniert nicht';

  @override
  String get helpTroubleLoginFailedDesc =>
      'Stelle sicher, dass die Mail bestätigt ist (Link aus Willkommens-Mail). Bei Google/Apple-Sign-In: hilf der App, den Browser-Tab zu öffnen — manche In-App-Browser blocken den Callback. Notfalls Passwort zurücksetzen.';

  @override
  String get helpTroubleUploadFailedTitle => 'Foto-Upload schlägt fehl';

  @override
  String get helpTroubleUploadFailedDesc =>
      'Bilder über 10 MB werden abgelehnt. Reduziere Größe/Qualität, oder erlaube der App in den OS-Einstellungen Zugriff auf Fotos/Mediathek. Bei sehr langsamer Verbindung kann der Upload nach 60 s timeoutten — erneut versuchen.';

  @override
  String get helpTroubleSlowTitle => 'App ist plötzlich langsam';

  @override
  String get helpTroubleSlowDesc =>
      'Sehr lange Deal-/Inbox-Listen? Filter setzen (Datum, Status, Käufer), das reduziert die Render-Last. App komplett beenden und neu starten leert flüchtige Caches im Speicher. Auf älteren Geräten kann es helfen, alte Tickets zu archivieren.';

  @override
  String get helpPrivacySection => 'Datenschutz & Kontakt';

  @override
  String get helpPrivacyDataTitle => 'Welche Daten werden gespeichert?';

  @override
  String get helpPrivacyDataDesc =>
      'Gespeichert werden: Stammdaten (Workspace, Deals, Käufer), Postfach-Konfiguration (Passwort verschlüsselt) und Foto-Uploads. Aus eingelesenen Mails werden Header (Absender, Betreff, Datum) und ein normalisierter JSON-Auszug (Bestellnummer, Tracking-Nummer, Beträge, Produkt) gespeichert; der vollständige Mail-Body bleibt nicht dauerhaft liegen. Mail-Metadaten werden nach 100 Tagen automatisch gelöscht. Details siehe Datenschutz-Erklärung in Einstellungen → Allgemein.';

  @override
  String get helpPrivacySupportTitle => 'Wie erreiche ich den Support?';

  @override
  String get helpPrivacySupportDesc =>
      'Über „Probleme melden\" wird eine Mail mit App-Version, OS und Workspace-ID generiert (keine Passwörter). Antwortzeit in der Regel < 48 h.';

  @override
  String get helpPrivacyNoteTitle => 'Wichtige Hinweise';

  @override
  String get helpPrivacyNoteDesc =>
      'Die App ersetzt keine Buchhaltung oder Steuerberatung — die Statistiken sind Schätzungen. Vor dem ersten Quartalsabschluss bitte mit einem Steuerberater sprechen.';

  @override
  String get ticketsEmpty => 'Keine Tickets gefunden';

  @override
  String get ticketsNoTicket => 'Kein Ticket';

  @override
  String get inventoryEmpty => 'Lager ist leer.';

  @override
  String get inventoryAddItem => 'Artikel hinzufügen';

  @override
  String get inventoryColName => 'Name';

  @override
  String get inventoryColSku => 'SKU';

  @override
  String get inventoryColEan => 'EAN';

  @override
  String get inventoryColQuantity => 'Menge';

  @override
  String get inventoryColMinStock => 'Min.';

  @override
  String get inventoryColLocation => 'Lagerort';

  @override
  String get inventoryColCost => 'EK';

  @override
  String get inventoryColArrival => 'Ankunft';

  @override
  String get inventoryColSupplier => 'Lieferant';

  @override
  String get suppliersEmpty => 'Noch keine Lieferanten angelegt.';

  @override
  String get suppliersAdd => 'Lieferant hinzufügen';

  @override
  String get suppliersDeleteTitle => 'Lieferant löschen';

  @override
  String suppliersDeleteConfirm(Object name) {
    return 'Lieferant „$name\" wirklich löschen?';
  }

  @override
  String get activityTitle => 'Aktivität';

  @override
  String get activityEmpty => 'Noch keine Aktivität.';

  @override
  String get dashboardOpenOrders => 'Offene Bestellungen';

  @override
  String get dashboardOpenAmount => 'Offene Beträge';

  @override
  String get dashboardArrivedToday => 'Heute angekommen';

  @override
  String get dashboardCriticalStock => 'Kritische Lager';

  @override
  String get dashboardMissingInvoice => 'Fehlende Belege';

  @override
  String get dashboardTotalProfit => 'Gesamt-Profit';

  @override
  String get dashboardOpenDeliveries => 'Offene Lieferungen';

  @override
  String get dashboardStockQuantity => 'Lagerbestand';

  @override
  String get dashboardStockValue => 'Lagerwert';

  @override
  String get dashboardKpiOpenOrders => 'Offene Bestellungen';

  @override
  String get dashboardKpiShipping => 'Unterwegs';

  @override
  String get dashboardKpiArrivedToday => 'Heute angekommen';

  @override
  String get dashboardKpiTotalProfit => 'Gesamtprofit';

  @override
  String get dashboardKpiOpenAmount => 'Offener Betrag';

  @override
  String get dashboardKpiCriticalStock => 'Lager kritisch';

  @override
  String get dashboardKpiMissingInvoice => 'Ausstehende Rechnungen';

  @override
  String get dashboardActivityFeed => 'Aktivitäts-Feed';

  @override
  String get dashboardActivityEmpty => 'Noch keine Aktionen vorhanden.';

  @override
  String get dashboardBuyerOverview => 'Käufer-Schnellübersicht';

  @override
  String get dashboardBuyerEmpty => 'Käufer in den Einstellungen anlegen.';

  @override
  String get dashboardColBuyer => 'KÄUFER';

  @override
  String get dashboardColDeals => 'DEALS';

  @override
  String get dashboardColOpen => 'OFFEN';

  @override
  String get dashboardColLastDeal => 'LETZTER DEAL';

  @override
  String get ticketsTitle => 'Tickets';

  @override
  String get ticketsSearchHint => 'Ticketnummer oder Produkt suchen';

  @override
  String get ticketsNewDeal => 'Neuer Deal';

  @override
  String get ticketsSelect => 'Ticket auswählen';

  @override
  String get ticketsSearchHintShort => 'Ticket suchen';

  @override
  String get ticketsTabList => 'Tickets';

  @override
  String get ticketsTabDetail => 'Detail';

  @override
  String get ticketsSortLabel => 'Sortierung';

  @override
  String get ticketsSortDate => 'Datum';

  @override
  String get ticketsSortProfit => 'Profit';

  @override
  String get ticketsSortDealCount => 'Anzahl Deals';

  @override
  String get ticketsOpenTooltip => 'Ticket öffnen';

  @override
  String get ticketsBulkEditTooltip => 'Bearbeiten';

  @override
  String get ticketsAddDealTooltip => 'Deal hinzufügen';

  @override
  String get ticketsEditTitle => 'Ticket bearbeiten';

  @override
  String get ticketsTicketNumber => 'Ticketnummer';

  @override
  String get ticketsRelatedItems => 'Zugehörige Lagerartikel';

  @override
  String get ticketsNoBuyerAssigned => 'Kein Käufer zugeordnet';

  @override
  String get ticketsBoxEkTotal => 'EK gesamt';

  @override
  String get ticketsBoxVkTotal => 'VK gesamt';

  @override
  String get ticketsBoxProfit => 'Profit';

  @override
  String get ticketsBoxQuantity => 'Stückzahl';

  @override
  String get ticketsColProduct => 'Produkt';

  @override
  String get ticketsColQuantity => 'Anzahl';

  @override
  String get ticketsColTracking => 'Tracking';

  @override
  String ticketsCount(int count) {
    return '$count Deal(s)';
  }

  @override
  String ticketsItemsCount(int count) {
    return '$count Artikel';
  }

  @override
  String get ticketsKeinTicket => 'Kein Ticket';

  @override
  String get ticketsNoBuyer => 'Kein Käufer';

  @override
  String get ticketsTabActive => 'Aktiv';

  @override
  String get ticketsTabArchive => 'Archiv';

  @override
  String get ticketsArchiveEmpty => 'Keine archivierten Tickets';

  @override
  String get ticketsArchiveReopen => 'Wieder öffnen';

  @override
  String get ticketsArchiveReopenConfirm =>
      'Dieses Ticket wieder öffnen? Archiv-Zeitpunkt und Grund werden zurückgesetzt.';

  @override
  String ticketsArchiveMonthProfit(Object profit) {
    return 'Profit: $profit';
  }

  @override
  String get ticketsArchiveLongPressHint => 'Lang drücken zum Wiedereröffnen';

  @override
  String get inventoryTitle => 'Lager';

  @override
  String get inventorySearchHint => 'Name, SKU, EAN, Lagerort suchen';

  @override
  String get inventoryAddBatch => 'Charge hinzufügen';

  @override
  String get inventoryAdjustStock => 'Bestand anpassen';

  @override
  String get inventoryNoSku => 'Keine SKU';

  @override
  String get inventoryNoLocation => 'Kein Lagerort';

  @override
  String get inventoryDeleteTitle => 'Lagerartikel löschen';

  @override
  String inventoryDeleteConfirm(Object name) {
    return 'Artikel „$name\" wirklich löschen?';
  }

  @override
  String get inventoryNoEan => 'Kein Artikel mit dieser EAN';

  @override
  String get inventoryCreate => 'Anlegen';

  @override
  String get inventoryKpiTotalItems => 'Gesamtartikel';

  @override
  String get inventoryKpiTotalStock => 'Gesamtbestand';

  @override
  String get inventoryKpiCriticalItems => 'Kritische Artikel';

  @override
  String get inventoryKpiStockValue => 'Lagerwert';

  @override
  String get inventoryStockIn => 'Ein';

  @override
  String get inventoryStockOut => 'Aus';

  @override
  String get inventoryColLocationLong => 'Lagerort';

  @override
  String get inventoryColMin => 'Mindestbestand';

  @override
  String get inventoryColActions => 'Aktionen';

  @override
  String get inventoryColStock => 'Bestand';

  @override
  String get inventoryStockInTooltip => 'Einbuchen';

  @override
  String get inventoryStockOutTooltip => 'Ausbuchen';

  @override
  String get inventoryStockInTitle => 'Einbuchen';

  @override
  String get inventoryStockOutTitle => 'Ausbuchen';

  @override
  String get inventoryQuantity => 'Menge';

  @override
  String get inventoryReason => 'Grund';

  @override
  String get inventoryReasonStockIn => 'Einbuchung';

  @override
  String get inventoryReasonSale => 'Verkauf';

  @override
  String get inventoryHelpTextTicket =>
      'Aus Ticket auswählen oder frei eingeben';

  @override
  String get inventoryAddItemTitle => 'Artikel hinzufügen';

  @override
  String get inventoryEditItemTitle => 'Artikel bearbeiten';

  @override
  String get inventorySectionGeneral => 'Allgemein';

  @override
  String get inventorySectionId => 'Identifikation';

  @override
  String get inventorySectionAttachments => 'Anhänge';

  @override
  String get inventoryNoSupplier => 'Kein Lieferant';

  @override
  String get inventoryScanBarcode => 'Barcode scannen';

  @override
  String get inventoryClose => 'Schließen';

  @override
  String get inventoryTabStock => 'Lager';

  @override
  String get inventoryTabSold => 'Verkauft';

  @override
  String get inventorySoldEmpty => 'Noch keine verkauften Artikel.';

  @override
  String get inventorySoldKpiCount => 'Verkaufte Items';

  @override
  String get inventorySoldKpiProfit => 'Gesamt-Profit';

  @override
  String get inventorySoldKpiTopBuyers => 'Top 3 Käufer';

  @override
  String get inventorySoldNoBuyer => 'Noch keine Käufer-Daten';

  @override
  String inventorySoldBuyerItems(int count) {
    return '$count Stück';
  }

  @override
  String get supplierAddTitle => 'Lieferant anlegen';

  @override
  String get supplierEditTitle => 'Lieferant bearbeiten';

  @override
  String get supplierContactName => 'Ansprechpartner';

  @override
  String get supplierPhone => 'Telefon';

  @override
  String get supplierWebsite => 'Webseite';

  @override
  String get supplierActive => 'Aktiv';

  @override
  String supplierItems(int count) {
    return '$count Artikel';
  }

  @override
  String get suppliersNew => 'Neuer Lieferant';

  @override
  String suppliersDeletePrompt(Object name) {
    return '„$name\" wird in den Papierkorb verschoben. Du kannst ihn später wiederherstellen.';
  }

  @override
  String get suppliersInactive => 'Inaktiv';

  @override
  String get suppliersEmptyHint =>
      'Über den + Button kannst du den ersten Lieferanten hinzufügen.';

  @override
  String get activityHeading => 'Aktivitätsverlauf';

  @override
  String get activityFilterReset => 'Filter zurücksetzen';

  @override
  String get activityToday => 'HEUTE';

  @override
  String get activityYesterday => 'GESTERN';

  @override
  String get activityTypeDeal => 'Deal';

  @override
  String get activityTypeStatus => 'Status';

  @override
  String get activityTypeStock => 'Lager';

  @override
  String get activityTypeSupplier => 'Lieferant';

  @override
  String get activityTypeBatch => 'Charge';

  @override
  String get activityTypeBulk => 'Bulk';

  @override
  String get activityTypeImport => 'Import';

  @override
  String get activityTypeInfo => 'Info';

  @override
  String get activityTypeComment => 'Kommentar';

  @override
  String get activitySearchHint => 'Aktivitäten durchsuchen…';

  @override
  String activityCountTotal(int count) {
    return '$count Einträge (max. 50)';
  }

  @override
  String activityCountFiltered(int filtered, int total) {
    return '$filtered von $total Einträgen';
  }

  @override
  String get activityNoMatches => 'Keine Treffer.';

  @override
  String get activityNoActivitiesYet => 'Noch keine Aktivitäten.';

  @override
  String get activityAdjustFilters => 'Filter anpassen oder zurücksetzen.';

  @override
  String get activityAutoAppears =>
      'Aktionen wie Deal-Anlage erscheinen hier automatisch.';

  @override
  String get statisticsTabRevenue => 'Umsatz';

  @override
  String get statisticsTabBuyers => 'Käufer';

  @override
  String get statisticsTabShops => 'Shops';

  @override
  String get statisticsTabInventory => 'Lager';

  @override
  String get statisticsTabCashflow => 'Cashflow';

  @override
  String get statisticsTabTax => 'Steuer';

  @override
  String get csvExportToolbar => 'Exportieren';

  @override
  String get csvImportToolbar => 'Importieren';

  @override
  String get buyerEditTitle => 'Käufer bearbeiten';

  @override
  String get buyerNewTitle => 'Neuer Käufer';

  @override
  String get buyerSortOrder => 'Sortierreihenfolge';

  @override
  String get buyerActive => 'Aktiv';

  @override
  String get buyerColorBlue => 'Blau';

  @override
  String get buyerColorOrange => 'Orange';

  @override
  String get buyerColorGreen => 'Grün';

  @override
  String get buyerColorPurple => 'Lila';

  @override
  String get buyerColorYellow => 'Gelb';

  @override
  String get buyerColorRed => 'Rot';

  @override
  String get buyerColorTeal => 'Teal';

  @override
  String get buyerColorPink => 'Pink';

  @override
  String get buyerPreview => 'Vorschau';

  @override
  String get buyerSampleProduct => 'Beispiel-Produkt';

  @override
  String get buyerDiscordIds => 'Discord Server IDs';

  @override
  String get buyerAddIdLabel => 'Hinzufügen';

  @override
  String get buyerRemoveTooltip => 'Entfernen';

  @override
  String get shopEditTitle => 'Shop bearbeiten';

  @override
  String get shopNewTitle => 'Neuer Shop';

  @override
  String get shopRegion => 'Region';

  @override
  String get shopChannel => 'Kanal';

  @override
  String get shopActive => 'Aktiv';

  @override
  String get batchesNew => 'Neue Charge';

  @override
  String get batchesAdd => 'Charge hinzufügen';

  @override
  String get batchesNoMhd => 'Ohne MHD';

  @override
  String get attachmentTitle => 'Bilder';

  @override
  String get attachmentTakePhoto => 'Foto aufnehmen';

  @override
  String get attachmentPickGallery => 'Aus Galerie wählen';

  @override
  String get barcodeScannerTitle => 'Barcode scannen';

  @override
  String get barcodeScannerNoCamera => 'Kamera nicht verfügbar';

  @override
  String get passwordStrengthWeak => 'Schwach';

  @override
  String get passwordStrengthMedium => 'Mittel';

  @override
  String get passwordStrengthStrong => 'Stark';

  @override
  String get passwordStrengthVeryStrong => 'Sehr stark';

  @override
  String get summaryHeading => 'Übersicht';

  @override
  String get summaryByBuyer => 'Nach Käufer';

  @override
  String get summaryByStatus => 'Nach Status';

  @override
  String get statsLabelRevenue => 'Umsatz';

  @override
  String get statsLabelProfit => 'Profit';

  @override
  String get statsLabelMargin => 'Marge';

  @override
  String get statsAllDeals => 'Alle Deals';

  @override
  String get statsProfitPerMonth => 'Profit pro Monat';

  @override
  String get statsTabOverview => 'Übersicht';

  @override
  String get statsTabBuyers => 'Käufer';

  @override
  String get statsTabProductsShops => 'Produkte & Shops';

  @override
  String get statsTabInventorySuppliers => 'Lager & Lieferanten';

  @override
  String get statsTabFinance => 'Finanzen';

  @override
  String get statsExportPdfTitle => 'PDF-Übersicht';

  @override
  String get statsExportPdfDesc =>
      'Einseitiger Report mit KPIs, Produkten, Käufern, Cashflow';

  @override
  String get statsExportXlsxTitle => 'Excel (XLSX)';

  @override
  String get statsExportXlsxDesc => 'Roh-Daten der gefilterten Deals';

  @override
  String get statsExportCsvTitle => 'CSV';

  @override
  String get statsExportCsvDesc => 'Roh-Daten der gefilterten Deals';

  @override
  String get statsExportPrintTitle => 'Drucken / Vorschau';

  @override
  String get statsReportExported => 'Report exportiert.';

  @override
  String statsExportFailed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get statsTaxExportSaved => 'MwSt-Export gespeichert.';

  @override
  String get globalSearchKeyNav => 'Navigieren';

  @override
  String get globalSearchKeyOpen => 'Öffnen';

  @override
  String get globalSearchKeyClose => 'Schließen';

  @override
  String get buyerLegendTitle => 'Käufer';

  @override
  String get statsCompareToPrevious => 'vs. Vorperiode';

  @override
  String get statsExportReport => 'Report';

  @override
  String get statsCashflow => 'Cashflow';

  @override
  String get statsReceived => 'Eingegangen';

  @override
  String get statsOutstanding => 'Ausstehend';

  @override
  String get statsAgingHeading => 'Forderungen nach Alter';

  @override
  String get statsOldestOpen => 'Älteste offene';

  @override
  String get statsQuarter => 'Quartal';

  @override
  String get statsCurrency => 'Währung';

  @override
  String get statsNet => 'Netto';

  @override
  String get statsTax => 'MwSt';

  @override
  String get statsGross => 'Brutto';

  @override
  String get statsCurrentMonth => 'Aktueller Monat';

  @override
  String get statsCurrent => 'Aktuell';

  @override
  String get statsTarget => 'Ziel';

  @override
  String get statsForecast => 'Forecast';

  @override
  String get statsGoalNotMet => 'Noch nicht erreicht';

  @override
  String get statsGoalsInRow => 'Ziele in Folge erreicht';

  @override
  String get statsOpenReceivables => 'Offene Forderungen';

  @override
  String get statsDealCount => 'Anzahl Deals';

  @override
  String get statsProfitPerBucket => 'Profit pro Bucket';

  @override
  String get statsProfitByBuyer => 'Profit nach Käufer';

  @override
  String get statsRevenueByShop => 'Umsatz nach Shop';

  @override
  String get statsTotal => 'GESAMT';

  @override
  String get statsBuyerLabel => 'Käufer';

  @override
  String get statsDealsLabel => 'Deals';

  @override
  String get statsOpenLabel => 'Offen';

  @override
  String get statsFrequency => 'Frequenz';

  @override
  String get statsFirst => 'First';

  @override
  String get statsLast => 'Last';

  @override
  String get statsActiveDays => 'Tage aktiv';

  @override
  String get statsHealthHeading => 'Lager-Gesundheit';

  @override
  String get statsStockValueEk => 'Lagerwert (EK)';

  @override
  String get statsLowStock => 'Niedriger Bestand';

  @override
  String get statsLowStockHint => 'Items unter Schwellwert';

  @override
  String get statsExpiringSoon => 'Bald ablaufend';

  @override
  String get statsExpiringSoonHint => 'Chargen mit MHD < 30 Tage';

  @override
  String get statsExpired => 'Abgelaufen';

  @override
  String get statsDeadStock => 'Tote Bestände';

  @override
  String get statsDeadStockHint => 'Kein Verkauf seit > 90 Tagen';

  @override
  String get statsSupplierPerformance => 'Lieferanten-Performance';

  @override
  String get statsItems => 'Items';

  @override
  String get statsStockValueShort => 'Lagerwert';

  @override
  String get statsAvgEk => 'Ø EK';

  @override
  String get inboxMarkAllRead => 'Alle als gelesen markieren';

  @override
  String inboxMarkAllReadTooltip(int count) {
    return 'Alle als gelesen markieren ($count)';
  }

  @override
  String get inboxMarkAllReadConfirmTitle => 'Alle als gelesen markieren?';

  @override
  String inboxMarkAllReadConfirmBody(int count) {
    return '$count ungelesene Einträge werden als gelesen markiert. Vorschläge und Mails bleiben in der Inbox.';
  }

  @override
  String inboxMarkAllReadSuccess(int count) {
    return '$count Einträge als gelesen markiert.';
  }

  @override
  String inboxMarkAllReadFailure(Object error) {
    return 'Markieren fehlgeschlagen: $error';
  }

  @override
  String inboxUnreadBadge(int count) {
    return '$count neu';
  }

  @override
  String get invitesBellTooltip => 'Einladungen';

  @override
  String get invitesEmpty => 'Keine offenen Einladungen.';

  @override
  String get invitesHeader => 'Workspace-Einladungen';

  @override
  String get invitesFrom => 'Eingeladen von Workspace';

  @override
  String get invitesAccept => 'Beitreten';

  @override
  String get invitesDecline => 'Ablehnen';

  @override
  String get invitesAcceptedSnack => 'Workspace beigetreten.';

  @override
  String get invitesDeclinedSnack => 'Einladung abgelehnt.';

  @override
  String invitesAcceptFailed(Object error) {
    return 'Beitritt fehlgeschlagen: $error';
  }

  @override
  String invitesExpiresOn(Object date) {
    return 'Läuft am $date ab';
  }

  @override
  String invitesRoleLabel(Object role) {
    return 'Rolle: $role';
  }

  @override
  String get settingsThemeSection => 'Erscheinungsbild';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get publicProfileTab => 'Öffentliches Profil';

  @override
  String get publicProfileSectionTitle => 'Verkaufsseite';

  @override
  String get publicProfileSectionDesc =>
      'Aktiviere eine öffentliche Seite mit deinem Lagerbestand. Anfragen erreichen dich per Mail.';

  @override
  String get publicProfileEnableLabel => 'Öffentliches Profil aktiv';

  @override
  String get publicProfileHandleLabel => 'Handle';

  @override
  String get publicProfileHandleHint => 'z.B. mein-laden';

  @override
  String get publicProfileHandleHelp =>
      'Kleinbuchstaben, Zahlen und Bindestriche, 3–32 Zeichen. Erreichbar unter /u/<handle>.';

  @override
  String get publicProfileHandleInvalid =>
      'Nur a-z, 0-9 und Bindestrich. 3–32 Zeichen, nicht mit \"-\" beginnen oder enden.';

  @override
  String get publicProfileHandleTaken => 'Handle bereits vergeben.';

  @override
  String get publicProfileSaved => 'Profil aktualisiert.';

  @override
  String publicProfileSaveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get publicProfileNeedsHandle =>
      'Lege zuerst einen Handle fest, um das Profil zu aktivieren.';

  @override
  String get publicProfileLink => 'Öffentlicher Link';

  @override
  String get publicProfileCopyLink => 'Link kopieren';

  @override
  String get publicProfileLinkCopied => 'Link kopiert.';

  @override
  String get publicProfileItemsTitle => 'Sichtbare Artikel';

  @override
  String get publicProfileItemsHint =>
      'Tippe einen Artikel an, um ihn auf der Verkaufsseite zu zeigen oder zu verstecken.';

  @override
  String get publicProfileItemPublic => 'Öffentlich';

  @override
  String get publicProfileNoEligibleItems =>
      'Keine Artikel im Lager. Lege zuerst Bestand an.';

  @override
  String get publicProfileNotFoundTitle => 'Profil nicht gefunden';

  @override
  String get publicProfileNotFoundBody =>
      'Diese Verkaufsseite existiert nicht oder ist nicht öffentlich.';

  @override
  String get publicProfileEmptyItems => 'Aktuell sind keine Artikel verfügbar.';

  @override
  String get publicProfileContact => 'Anfrage senden';

  @override
  String get publicProfileContactSubject => 'Anfrage zu deinem Angebot';

  @override
  String get publicProfileItemPrice => 'Preis';

  @override
  String publicProfileItemQuantity(int count) {
    return 'Verfügbar: $count';
  }

  @override
  String get publicProfileFooter => 'Erstellt mit InventoryOS';

  @override
  String get settingsDemoSection => 'Demo / Daten';

  @override
  String get settingsDemoReloadTitle => 'Demo-Daten neu laden';

  @override
  String get settingsDemoReloadDescription =>
      'Setzt diesen Workspace zurück und füllt ihn mit 30–50 realistischen Beispiel-Deals aus deinen Mails der letzten 90 Tage. Alle aktuellen Daten gehen verloren.';

  @override
  String get settingsDemoReload => 'Demo neu laden';

  @override
  String get settingsDemoReloadConfirmTitle => 'Demo-Daten neu laden?';

  @override
  String get settingsDemoReloadConfirm =>
      'Dieser Workspace wird zurückgesetzt und mit frischen Demo-Daten gefüllt. Alle aktuellen Deals, Käufer, Shops und Lagerartikel gehen verloren. Fortfahren?';

  @override
  String get settingsDemoReloadSuccess => 'Demo-Daten neu geladen.';

  @override
  String settingsDemoReloadError(Object error) {
    return 'Demo-Reload fehlgeschlagen: $error';
  }

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingBack => 'Zurück';

  @override
  String get onboardingFinish => 'Fertig';

  @override
  String get onboardingStepWelcomeTitle => 'Willkommen';

  @override
  String get onboardingStepWelcomeSubtitle =>
      'InventoryOS hilft dir, Bestellungen, Lager und Käufer im Blick zu behalten. Wir richten dich in 6 kurzen Schritten ein.';

  @override
  String get onboardingStepWorkspaceTitle => 'Dein Workspace';

  @override
  String get onboardingStepWorkspaceSubtitle =>
      'Alle Daten landen in einem Workspace. Du kannst später Team-Mitglieder einladen oder weitere Workspaces anlegen.';

  @override
  String get onboardingWorkspaceFallback => 'Mein Workspace';

  @override
  String get onboardingWorkspaceReady => 'Bereit. Dieser Workspace gehört dir.';

  @override
  String get onboardingStepShopsTitle => 'Welche Shops nutzt du?';

  @override
  String get onboardingStepShopsSubtitle =>
      'Wähle die Shops, von denen du regelmäßig bestellst. Du kannst später jederzeit weitere hinzufügen.';

  @override
  String get onboardingStepSuppliersTitle => 'Wer sind deine Lieferanten?';

  @override
  String get onboardingStepSuppliersSubtitle =>
      'Optional. Trage deine wichtigsten Lieferanten ein, damit Lagerartikel direkt zugeordnet werden können.';

  @override
  String get onboardingSuppliersHint => 'Lieferanten-Name';

  @override
  String get onboardingSuppliersAdd => 'Hinzufügen';

  @override
  String get onboardingStepFirstTicketTitle => 'Erstes Ticket anlegen';

  @override
  String get onboardingStepFirstTicketSubtitle =>
      'Optional. Lege gleich einen ersten Deal an, damit dein Dashboard nicht leer ist. Du kannst diesen Schritt überspringen.';

  @override
  String get onboardingFirstTicketProductHint => 'Produkt (z.B. AirPods Pro 2)';

  @override
  String get onboardingFirstTicketQuantity => 'Menge';

  @override
  String get onboardingFirstTicketShop => 'Shop';

  @override
  String get onboardingStepOutroTitle => 'Fast geschafft!';

  @override
  String get onboardingStepOutroSubtitle =>
      'Diese Funktionen findest du in den Einstellungen — kein Stress, du musst sie nicht sofort einrichten:';

  @override
  String get onboardingOutroDiscord =>
      'Discord-Server verbinden, um Käufer-Bountys automatisch zuzuordnen.';

  @override
  String get onboardingOutroInbox =>
      'Postfach verbinden — Bestellbestätigungen werden dann automatisch erkannt.';

  @override
  String get onboardingOutroDemo =>
      'Wenn du dich erstmal umsehen willst: \'Beispiel-Daten laden\' auf dem Dashboard.';

  @override
  String get onboardingErrorNoWorkspace =>
      'Kein aktiver Workspace gefunden. Bitte ausloggen und erneut anmelden.';

  @override
  String onboardingErrorGeneric(Object error) {
    return 'Onboarding fehlgeschlagen: $error';
  }

  @override
  String get dashboardEmptyTitle => 'Noch keine Daten';

  @override
  String get dashboardEmptySubtitle =>
      'Lade ein paar Beispiel-Tickets, Käufer und Lagerartikel, um dich in der App zurechtzufinden.';

  @override
  String get dashboardEmptyLoadDemo => 'Beispiel-Daten laden';

  @override
  String dashboardDemoLoadSuccess(int count) {
    return '$count Beispiel-Einträge geladen.';
  }

  @override
  String dashboardDemoLoadError(Object error) {
    return 'Beispiel-Daten konnten nicht geladen werden: $error';
  }

  @override
  String get settingsDemoWipeSection => 'Beispiel-Daten';

  @override
  String get settingsDemoWipeTitle => 'Demo-Daten löschen';

  @override
  String get settingsDemoWipeDescription =>
      'Entfernt nur die Einträge, die der \'Beispiel-Daten laden\'-Button erstellt hat. Eigene Daten bleiben unangetastet.';

  @override
  String get settingsDemoWipe => 'Demo-Daten löschen';

  @override
  String get settingsDemoWipeConfirmTitle => 'Demo-Daten löschen?';

  @override
  String get settingsDemoWipeConfirm =>
      'Alle Einträge, die als Beispiel-Daten markiert sind, werden entfernt. Fortfahren?';

  @override
  String settingsDemoWipeSuccess(int count) {
    return '$count Demo-Einträge gelöscht.';
  }

  @override
  String settingsDemoWipeError(Object error) {
    return 'Löschen fehlgeschlagen: $error';
  }
}
