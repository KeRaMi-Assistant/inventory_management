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
}
