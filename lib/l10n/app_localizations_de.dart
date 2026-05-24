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
  String get actionHelp => 'Hilfe';

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
  String get navInbox => 'Postfach';

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
  String get navMore => 'Mehr';

  @override
  String get navMoreSheetTitle => 'Weitere Bereiche';

  @override
  String get navWarehouse => 'Warenwirtschaft';

  @override
  String get warehouseHubTitle => 'Warenwirtschaft';

  @override
  String get warehouseHubComingSoon => 'Bald verfügbar';

  @override
  String get warehouseHubComingSoonHint =>
      'Diese Funktion wird in einem der nächsten Updates freigeschaltet.';

  @override
  String get warehouseHubTileProductCatalog => 'Artikelstamm';

  @override
  String get warehouseHubTilePurchaseOrders => 'Bestellungen';

  @override
  String get warehouseHubTileWarehouses => 'Lager';

  @override
  String get warehouseHubTileCategories => 'Warengruppen';

  @override
  String get warehouseHubTileStocktake => 'Inventur';

  @override
  String get warehouseHubTileReporting => 'Reporting';

  @override
  String get warehouseHubDetailPaneEmpty => 'Wähle links einen Bereich aus.';

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
  String get loginBrandHeadline => 'Willkommen zurück.';

  @override
  String get pricingTitle => 'Pläne & Preise';

  @override
  String get pricingHeadline => 'Wähle den Plan, der zu dir passt';

  @override
  String get pricingIntro =>
      'Free bleibt dauerhaft kostenlos. Privat-Tarife für Solo-Reseller, Enterprise für Teams mit Postfach, Multi-Workspace und Einladungen.';

  @override
  String get pricingCategoryPersonal => 'Privat';

  @override
  String get pricingCategoryPersonalHint =>
      'Solo-Reseller · Brutto-Preise inkl. 19% MwSt';

  @override
  String get pricingCategoryEnterprise => 'Enterprise';

  @override
  String get pricingCategoryEnterpriseHint =>
      'Teams · Postfach · Multi-Workspace · Netto-Preise zzgl. MwSt';

  @override
  String get pricingVatIncluded => 'inkl. MwSt';

  @override
  String get pricingVatExcluded => 'zzgl. MwSt';

  @override
  String pricingYearlyBilled(String total) {
    return '$total jährlich abgerechnet';
  }

  @override
  String get pricingLegalFootnote =>
      'Privat-Tarife verstehen sich inkl. der gesetzlichen Mehrwertsteuer. Enterprise-Tarife werden netto ausgezeichnet — Mehrwertsteuer kommt auf der Rechnung dazu (bei gültiger USt-IdNr. innerhalb der EU als Reverse-Charge). Der Wechsel auf einen kostenpflichtigen Plan erfordert eine vollständige Rechnungsadresse.';

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
  String get shippingCarrierComingSoon => 'Bald verfügbar';

  @override
  String get shippingSetupError =>
      'Setup unvollständig: Master-Key nicht konfiguriert. Bitte Hilfe öffnen.';

  @override
  String get shippingSetupHelpAction => 'Hilfe öffnen';

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
  String get teamRenamePersonalWarnTitle => 'Persönlicher Workspace';

  @override
  String get teamRenamePersonalWarn =>
      'Dies ist dein persönlicher Standard-Workspace. Wirklich umbenennen?';

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
  String get teamMemberFallbackLabel => 'diesem Mitglied';

  @override
  String get teamInviteRevoke => 'Einladung zurückziehen';

  @override
  String get teamSwitchWorkspace => 'Workspace wechseln';

  @override
  String get teamRoleOwner => 'Eigentümer:in';

  @override
  String get teamRoleAdmin => 'Admin';

  @override
  String get teamRoleMember => 'Mitglied';

  @override
  String get teamRoleViewer => 'Read-only';

  @override
  String get teamRoleEditor => 'Editor';

  @override
  String get teamRoleObserver => 'Beobachter';

  @override
  String get teamRoleEditorHint => 'Kann lesen und bearbeiten.';

  @override
  String get teamRoleObserverHint => 'Nur Leserechte.';

  @override
  String get teamRoleOwnerHint => 'Volle Kontrolle inkl. Workspace-Verwaltung.';

  @override
  String get teamRoleAdminHint => 'Kann einladen und Carrier-Keys verwalten.';

  @override
  String get teamWorkspacesTitle => 'Workspaces';

  @override
  String get teamWorkspacesActiveLabel => 'Aktiv';

  @override
  String get teamWorkspacesActiveBadgeTooltip => 'Aktueller Workspace';

  @override
  String get teamWorkspacesCreate => 'Neuer Workspace';

  @override
  String get teamWorkspacesCreateTitle => 'Neuen Workspace anlegen';

  @override
  String get teamWorkspacesCreateLabel => 'Name';

  @override
  String get teamWorkspacesCreateHint => 'z. B. Acme GmbH';

  @override
  String get teamWorkspacesCreateSubmit => 'Anlegen';

  @override
  String teamWorkspacesCreateSuccess(String name) {
    return 'Workspace ‘$name’ angelegt.';
  }

  @override
  String teamWorkspacesCreateFailed(String error) {
    return 'Anlegen fehlgeschlagen: $error';
  }

  @override
  String get teamWorkspacesCreateValidationLength =>
      'Name muss 1–80 Zeichen sein.';

  @override
  String teamWorkspacesPlanUsage(String plan, int used, int limit) {
    return 'Plan $plan: $used/$limit Workspaces';
  }

  @override
  String teamWorkspacesPlanUsageUnlimited(String plan, int used) {
    return 'Plan $plan: $used Workspaces (unbegrenzt)';
  }

  @override
  String get teamWorkspacesLimitReachedTitle => 'Limit erreicht';

  @override
  String teamWorkspacesLimitReachedBody(String plan, int limit) {
    return 'Dein Plan $plan erlaubt $limit Workspaces. Upgrade, um weitere anzulegen.';
  }

  @override
  String get teamWorkspacesLimitReachedCta => 'Plan upgraden';

  @override
  String get teamWorkspacesSwitchTo => 'Wechseln';

  @override
  String get teamWorkspacesEmpty => 'Du hast noch keinen Workspace.';

  @override
  String get teamInviteRoleEditor => 'Editor';

  @override
  String get teamInviteRoleObserver => 'Beobachter';

  @override
  String get teamInviteRoleAdminGated => 'Admin (ab Plan Team)';

  @override
  String get teamInviteAdminLockedTooltip =>
      'Admin-Rolle ist ab Plan Team verfügbar.';

  @override
  String get teamInviteEmailInvalid => 'Ungültige E-Mail-Adresse.';

  @override
  String get teamInviteCreatedTitle => 'Einladung erstellt';

  @override
  String get teamInviteShareBody => 'Sende diesen Code an dein Teammitglied:';

  @override
  String get teamInviteCopyLink => 'Code kopieren';

  @override
  String get teamInviteCopyLinkSnack => 'Code kopiert.';

  @override
  String get teamInviteCopyFailed => 'Kopieren fehlgeschlagen.';

  @override
  String get teamInviteShareEmailHint =>
      'E-Mail-Versand kommt mit der nächsten Version.';

  @override
  String get teamMemberRemoveConfirmTitle => 'Mitglied entfernen?';

  @override
  String teamMemberRemoveConfirmBody(String email) {
    return '$email aus diesem Workspace entfernen?';
  }

  @override
  String get teamMemberRoleChangeLoading => 'Rolle wird gespeichert …';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonClose => 'Schließen';

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
      'Wenn eine Versandmail mit einer DHL-Tracking-Nummer eintrifft, fragt die App die DHL-API direkt an: nur wenn DHL die Nummer bestätigt, wird der Deal automatisch auf „Unterwegs\" gesetzt. Sobald DHL die Zustellung meldet, springt der Deal auf „Angekommen\". Andere Carrier (DPD, UPS, Hermes, Amazon Logistics, GLS) werden nicht mehr aus Mails erkannt — Tracking-Nummern dort manuell im Deal eintragen. Details siehe Sektion „Versand & Carrier-API-Keys\".';

  @override
  String get helpDealsDropShipTitle => 'Multi-Drop-Ship';

  @override
  String get helpDealsDropShipDesc =>
      'Wenn ein Deal aus mehreren Shops besteht (Drop-Ship), kannst du beim Anlegen mehrere Bezugsquellen samt Einkaufspreisen hinterlegen. Der Profit wird über alle Quellen summiert. Die Statistik zählt den Deal als einen Verkauf.';

  @override
  String get helpDealsRetrackTitle =>
      'Sendungsstatus sofort aktualisieren (Retrack)';

  @override
  String get helpDealsRetrackDesc =>
      'Im Deal-Detail neben der Sendungsnummer gibt es ein Refresh-Icon „Status aktualisieren\". Damit fragst du den Carrier sofort nach dem aktuellen Status, ohne auf den nächsten automatischen Poll zu warten — praktisch z. B. kurz vor einem geplanten Versand.\nEin Retrack pro Deal ist alle 30 Sekunden möglich. Während der Sperre ist der Button ausgegraut und zeigt „Bitte 30s warten\" — das schützt den Carrier vor unnötigen API-Calls und dich vor Rate-Limits.';

  @override
  String get helpShippingSection => 'Versand & Carrier-API-Keys';

  @override
  String get helpShippingIntroTitle => 'Wozu Carrier-API-Keys?';

  @override
  String get helpShippingIntroDesc =>
      'Damit die App den Live-Status deiner Sendungen direkt beim Versanddienstleister abfragen kann (statt nur aus Mails zu lesen), hinterlegst du pro Carrier einen API-Key unter Einstellungen → Versand. Pro Workspace ist ein Key je Carrier nötig — alle Mitglieder profitieren davon.';

  @override
  String get helpShippingDhlTitle => 'DHL — aktiv unterstützt';

  @override
  String get helpShippingDhlDesc =>
      'DHL kannst du sofort anbinden:\n• Account auf developer.dhl.com anlegen (kostenlos).\n• Dort die API „Shipment Tracking - Unified\" abonnieren — Free-Tier reicht für privaten Gebrauch.\n• Den API-Key kopieren und unter Einstellungen → Versand → DHL → „API-Key hinterlegen\" einfügen.\n• Direkt danach einmal Einstellungen → „Sendungsnummern neu prüfen\" tippen, damit deine bestehenden Mails von der neuen DHL-API-Pipeline geparst werden.\nAb sofort werden Deals mit DHL-Trackingnummer in regelmäßigen Abständen aktualisiert und der Status (unterwegs, in Zustellung, zugestellt) erscheint direkt im Deal.';

  @override
  String get helpShippingApiOnlyTitle => 'Warum DHL-API statt Mail-Heuristik?';

  @override
  String get helpShippingApiOnlyDesc =>
      'Bis vor kurzem hat die App Tracking-Nummern aus Mails mit Regex-Patterns erkannt. Resultat: pro Mail oft mehrere Kandidaten, von denen nur eine echt war (Bestell-Nr, Kunden-Nr, Rechnung-Nr — alle 12-stellige Zahlen sehen wie Tracking aus). Jetzt fragt die App bei jedem Kandidaten direkt die DHL-API: liefert sie ein Shipment zurück → echte Tracking-Nummer wird übernommen, sonst verworfen. Du siehst maximal eine Pill pro Mail, und sie ist immer real.';

  @override
  String get helpShippingComingSoonTitle =>
      'DPD, UPS, Hermes, Amazon Logistics — bald oder nie';

  @override
  String get helpShippingComingSoonDesc =>
      'Aktuell läuft die automatische Tracking-Erkennung ausschließlich über die DHL-API. Andere Carrier (DPD, UPS, Hermes, Amazon Logistics, GLS) werden nicht mehr aus Versandmails geraten — das war die Hauptquelle der Falsch-Positive. DPD und UPS bekommen ihre eigene API-Anbindung in einem späteren Update. Hermes und Amazon Logistics bieten keine öffentliche Tracking-API — dort musst du die Tracking-Nummer manuell im Deal eintragen.';

  @override
  String get helpShippingKeySafetyTitle => 'Was passiert mit meinem API-Key?';

  @override
  String get helpShippingKeySafetyDesc =>
      'Der Klartext-Key verlässt dein Gerät nur einmal, beim Speichern, und wird serverseitig in der Datenbank verschlüsselt abgelegt. In der App siehst du danach nur noch die letzten vier Zeichen, z. B. „••••••••a1b2\". Du kannst den Key jederzeit ersetzen oder löschen — beim Löschen pausieren wir die automatischen Status-Abfragen für diesen Carrier.';

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
  String get helpWorkspacesHowManyTitle =>
      'Wie viele Workspaces darf ich anlegen?';

  @override
  String get helpWorkspacesHowManyBody =>
      'Das hängt von deinem Plan ab: Free / Solo = 1, Solo Pro = 2, Team = 5, Business = 20, Enterprise = unbegrenzt. Beim Anlegen wird das Limit serverseitig geprüft. Wenn du mehr brauchst: Plan upgraden.';

  @override
  String get helpInviteHowTitle => 'Wie lade ich jemanden ein?';

  @override
  String get helpInviteHowBody =>
      'Settings → Team → „Einladen\". E-Mail + Rolle (Editor oder Beobachter) wählen. Du bekommst einen Code, den du dem Empfänger per Messenger/Mail teilst. Empfänger meldet sich mit derselben E-Mail an und sieht die Einladung im Postfach-Glöckchen oben rechts. E-Mail-Versand wird in einer späteren Version automatisch.';

  @override
  String get helpRolesEditorObserverTitle => 'Welche Rollen gibt es?';

  @override
  String get helpRolesEditorObserverBody =>
      'Vier Rollen: Eigentümer:in (volle Kontrolle, kann Workspace umbenennen/löschen), Admin (kann einladen, Mitglieder verwalten), Editor (kann Daten lesen und bearbeiten), Beobachter (nur Lesezugriff). Die Admin-Rolle ist ab Plan Team verfügbar.';

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
  String get helpFaqQ17 => 'Was bedeutet das „Prüfen\"-Badge an einer Sendung?';

  @override
  String get helpFaqA17 =>
      'Die App hat den Tracking-Wert zwar gespeichert, aber unsere neue Erkennung ist sich nicht sicher, ob es wirklich eine echte Sendungsnummer ist (z. B. weil sie aus einer älteren Mail mit unklarem Format kommt). Tippe auf den Deal und prüfe in der Sendungsnummer-Karte: „Übernehmen\" bestätigt den Wert, „Verwerfen\" leert ihn. In der Deals-Liste oben filtert der Chip „Prüfen\" alle betroffenen Deals auf einen Schlag.';

  @override
  String get helpFaqQ18 =>
      'Wie funktioniert „Sendungsnummern neu bewerten\" in den Einstellungen?';

  @override
  String get helpFaqA18 =>
      'Einstellungen → Allgemein → „Sendungsnummern neu bewerten\" prüft alle gespeicherten Mails dieses Workspaces nochmal mit der neuesten, strikteren Erkennung. Falsch gespeicherte Werte werden auf „Prüfen\" gesetzt, neu erkannte echte Trackings ersetzen leere Einträge. Manuell eingetragene Sendungsnummern bleiben unangetastet. Aus Schutz vor Doppelläufen läuft das maximal einmal alle 5 Minuten pro Workspace.';

  @override
  String get helpFaqQ19 =>
      'Warum ist eine Sendungsnummer manchmal leer, obwohl die Versandmail da ist?';

  @override
  String get helpFaqA19 =>
      'Seit Mai 2026 speichert die App eine Tracking-Nummer nur, wenn sie strukturell verifiziert ist (Carrier-Pattern + Längen-/Prüfsummen-Check). Wenn die Mail nur eine interne Shop-ID enthält (z. B. Amazon-Logistics-Shipment-ID) oder die Nummer unklar formatiert ist, lässt die App das Feld bewusst leer statt einen falschen Wert zu speichern. Du kannst die Sendungsnummer direkt im Deal manuell eintragen — manuelle Eingaben werden nie automatisch überschrieben.';

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
  String get helpTroubleCarrierSetupTitle =>
      '„Setup unvollständig: Master-Key nicht konfiguriert\"';

  @override
  String get helpTroubleCarrierSetupDesc =>
      'Diese Meldung erscheint, wenn du einen Carrier-API-Key speichern willst, aber das Backend keinen Master-Schlüssel hat, mit dem es deinen Key verschlüsselt ablegen kann. Das ist kein Fehler in deinem Account, sondern ein einmaliger Backend-Setup-Schritt:\n• Hosted-Variante (Standard-Nutzer): kurz warten und nochmal versuchen — wir setzen den Master-Key zentral, normalerweise innerhalb weniger Stunden.\n• Self-Hoster / Admin der Supabase-Instanz: die Migration `20260516000000_carrier_master_key_bootstrap.sql` muss eingespielt sein und der `CARRIER_MASTER_KEY`-Secret auf der Supabase-Projektebene gesetzt sein. Details für Admins liegen im Repo unter `supabase/functions/tracking-poll/SETUP.md`.\nBis das gefixt ist, kannst du deine Sendungen weiter manuell pflegen — nur der automatische Live-Status pro Carrier ist solange aus.';

  @override
  String get helpTroubleLowStockPushTitle => 'Low-Stock-Push kommt nicht an';

  @override
  String get helpTroubleLowStockPushDesc =>
      'Prüfe zuerst, ob Push-Mitteilungen generell zugestellt werden (OS-Einstellungen → Mitteilungen → Lager-App). Dann: Einstellungen → Push → Kategorie „Mindestbestand\" aktiviert? Wichtig: Low-Stock-Pushes werden pro Workspace zusammengefasst — der Push enthält nur eine Zahl, keine Produktnamen. Wenn das Dashboard bereits die betroffenen Artikel zeigt, ist die Benachrichtigung inhaltlich korrekt, nur der Push fehlt — einmal ausloggen und wieder einloggen, damit der Push-Token neu registriert wird.';

  @override
  String get helpWarenwirtschaftSection => 'Warenwirtschaft-Hub';

  @override
  String get helpWarenwirtschaftIntroTitle =>
      'Was ist der Warenwirtschaft-Tab?';

  @override
  String get helpWarenwirtschaftIntroDesc =>
      'Der Tab „Warenwirtschaft\" ist der zentrale Einstieg für alles rund um deinen Artikelstamm, Lager, Bestellungen und Inventur. Von dort erreichst du alle Unterbereiche mit einem Tipp.';

  @override
  String get helpWarenwirtschaftSubroutesTitle =>
      'Unterbereiche auf einen Blick';

  @override
  String get helpWarenwirtschaftSubroutesDesc =>
      '• Artikelstamm — wiederverwendbare Artikel anlegen und verwalten\n• Warengruppen — Kategorien für deine Artikel\n• Bestellungen — Nachbestellungen an Lieferanten\n• Lager — mehrere physische Lagerorte\n• Inventur — Bestände zählen und abgleichen\n• Berichte — Bestandsbewertung, Lagerumschlag, ABC-Analyse';

  @override
  String get helpProductCatalogSection => 'Artikelstamm & Warengruppen';

  @override
  String get helpProductCatalogWhatTitle => 'Was ist der Artikelstamm?';

  @override
  String get helpProductCatalogWhatDesc =>
      'Im Artikelstamm legst du Produkte einmalig als Vorlage an — mit Name, Artikelnummer (SKU), EAN, Einheit, Einkaufspreis und Mindestbestand. Sobald du Ware einbuchst oder eine Bestellung eingehst, verknüpft die App den Lagerbestand automatisch mit dem passenden Stammartikel.';

  @override
  String get helpProductCatalogNewTitle => 'Neuen Artikel anlegen';

  @override
  String get helpProductCatalogNewDesc =>
      'Warenwirtschaft → Artikelstamm → „+\"-Button. Pflicht: Name. Optional: SKU, EAN, Warengruppe, Lieferant, Standard-Einkaufspreis, Mindestbestand, Mengeneinheit. SKU muss innerhalb des Workspaces eindeutig sein.';

  @override
  String get helpProductCatalogCategoryTitle => 'Warengruppen';

  @override
  String get helpProductCatalogCategoryDesc =>
      'Warengruppen (Kategorien) helfen dir, deinen Artikelstamm zu strukturieren — z. B. „Elektronik\", „Bekleidung\", „Zubehör\". Du kannst bis zu zwei Ebenen anlegen (Gruppe → Untergruppe). Warenwirtschaft → Warengruppen → „+\"-Button.';

  @override
  String get helpProductCatalogDetailTitle => 'Artikel-Detailseite';

  @override
  String get helpProductCatalogDetailDesc =>
      'Tippe einen Artikel an, um die 360°-Ansicht zu öffnen: aktueller Bestand über alle Lager, Buchungshistorie (getypt nach Wareneingang, Verkauf, Korrektur, Inventur, Umlagerung), Chargen und verknüpfte Lieferanten.';

  @override
  String get helpProductCatalogMovementsTitle => 'Buchungsarten';

  @override
  String get helpProductCatalogMovementsDesc =>
      'Jede Bestandsveränderung wird mit einer Buchungsart protokolliert:\n• Wareneingang — Ware kommt ins Lager (z. B. Lieferung)\n• Warenausgang — Ware verlässt das Lager\n• Korrektur — manuelle Mengenanpassung\n• Inventur — Differenz aus einer Inventurzählung\n• Umlagerung — Wechsel zwischen Lagerorten\n• Verkauf — Deal abgeschlossen';

  @override
  String get helpPurchaseOrdersSection => 'Bestellwesen';

  @override
  String get helpPurchaseOrdersWhatTitle => 'Was sind Bestellungen?';

  @override
  String get helpPurchaseOrdersWhatDesc =>
      'Wenn dein Bestand zur Neige geht, legst du eine Bestellung (Purchase Order) an einen Lieferanten an. Die App verwaltet Bestellpositionen, Mengen und den Status der Lieferung — von Entwurf bis Vollständig erhalten.';

  @override
  String get helpPurchaseOrdersNewTitle => 'Neue Bestellung anlegen';

  @override
  String get helpPurchaseOrdersNewDesc =>
      'Warenwirtschaft → Bestellungen → „+\"-Button → Lieferanten wählen → Artikel und Mengen eintragen → Speichern. Die App vergilt automatisch eine Bestellnummer (z. B. PO-2026-0001).';

  @override
  String get helpPurchaseOrdersStatusTitle => 'Bestellstatus';

  @override
  String get helpPurchaseOrdersStatusDesc =>
      '• Entwurf — noch nicht abgeschickt\n• Bestellt — beim Lieferanten aufgegeben\n• Teilweise erhalten — erste Teillieferung eingegangen\n• Erhalten — vollständig geliefert\n• Storniert — Bestellung wurde abgebrochen';

  @override
  String get helpPurchaseOrdersReceiveTitle => 'Wareneingang buchen';

  @override
  String get helpPurchaseOrdersReceiveDesc =>
      'Öffne die Bestelldetails → „Wareneingang buchen\". Du siehst pro Position die bestellte und bereits erhaltene Menge und gibst die neu eingegangene Menge ein. Die App aktualisiert den Bestand und setzt den Bestellstatus automatisch auf „Teilweise erhalten\" oder „Erhalten\".';

  @override
  String get helpPurchaseOrdersPdfTitle => 'Bestellbeleg als PDF';

  @override
  String get helpPurchaseOrdersPdfDesc =>
      'Öffne eine Bestellung → PDF-Icon oben rechts. Die App erstellt einen Bestellbeleg mit allen Positionen, den du teilen oder drucken kannst.';

  @override
  String get helpPurchaseOrdersReorderTitle => 'Schnell nachbestellen';

  @override
  String get helpPurchaseOrdersReorderDesc =>
      'Im Dashboard erscheint ein Hinweis, wenn Artikel unter den Mindestbestand fallen. Tippe auf „Jetzt bestellen\", um direkt eine vorausgefüllte Bestellung für die betroffenen Artikel zu öffnen.';

  @override
  String get helpWarehousesSection => 'Lager verwalten';

  @override
  String get helpWarehousesWhatTitle => 'Mehrere Lager nutzen';

  @override
  String get helpWarehousesWhatDesc =>
      'Du kannst mehrere physische Lagerorte anlegen — z. B. „Hauptlager\", „Außenlager\" oder „Büro\". Beim Einbuchen von Ware wählst du, in welches Lager die Menge geht. Warenwirtschaft → Lager.';

  @override
  String get helpWarehousesNewTitle => 'Neues Lager anlegen';

  @override
  String get helpWarehousesNewDesc =>
      'Warenwirtschaft → Lager → „+\"-Button → Name eingeben (z. B. „Hauptlager\") → optional Adresse → Speichern. Das erste Lager wird automatisch als Hauptlager markiert.';

  @override
  String get helpWarehousesDefaultTitle => 'Hauptlager';

  @override
  String get helpWarehousesDefaultDesc =>
      'Das als Hauptlager markierte Lager ist vorausgewählt, wenn du Ware einbuchst. Pro Workspace kann genau ein Lager das Hauptlager sein. Du kannst das Hauptlager jederzeit wechseln.';

  @override
  String get helpWarehousesStockTitle => 'Bestand pro Lager sehen';

  @override
  String get helpWarehousesStockDesc =>
      'In der Artikel-Detailseite (Warenwirtschaft → Artikelstamm → Artikel antippen) siehst du den Bestand aufgeteilt nach Lager. Gesamtbestand und Mindestbestand werden über alle Lager zusammengerechnet.';

  @override
  String get helpStocktakeSection => 'Inventur';

  @override
  String get helpStocktakeWhatTitle => 'Was ist eine Inventur?';

  @override
  String get helpStocktakeWhatDesc =>
      'Bei einer Inventur zählst du den tatsächlichen Bestand deiner Artikel und vergleichst ihn mit dem in der App gespeicherten Soll-Bestand. Differenzen werden als Korrekturbuchungen automatisch eingetragen.';

  @override
  String get helpStocktakeStartTitle => 'Inventur starten';

  @override
  String get helpStocktakeStartDesc =>
      'Warenwirtschaft → Inventur → „+\"-Button → optional Lager und Titel wählen → „Inventur starten\". Die App legt einen Soll-Bestand-Snapshot aus den aktuellen Lagermengen an.';

  @override
  String get helpStocktakeCountTitle => 'Artikel zählen';

  @override
  String get helpStocktakeCountDesc =>
      'Gib für jeden Artikel die tatsächlich gezählte Menge ein. Der Filter „Nur ungezählte\" blendet bereits bearbeitete Artikel aus. Du kannst per Barcode-Scan direkt zum passenden Artikel springen. Eingaben werden sofort gespeichert — auch wenn die App zwischendurch offline ist.';

  @override
  String get helpStocktakeCloseTitle => 'Inventur abschließen';

  @override
  String get helpStocktakeCloseDesc =>
      'Wenn alle Positionen gezählt sind (Fortschrittsanzeige oben zeigt 100 %), tippe auf „Inventur abschließen\". Die App bucht alle Differenzen als Inventur-Korrekturen und erstellt einen Differenz-Report. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get helpStocktakeDiffTitle => 'Differenz-Report';

  @override
  String get helpStocktakeDiffDesc =>
      'Nach dem Abschluss siehst du eine Liste aller Artikel mit Soll-/Ist-Vergleich und der gebuchten Differenz. Positiv = mehr gezählt als erwartet, Negativ = weniger. Der Report bleibt in der Inventur-Liste abrufbar.';

  @override
  String get helpWwReportingSection => 'Berichte & Auswertungen';

  @override
  String get helpWwReportingWhatTitle => 'Welche Berichte gibt es?';

  @override
  String get helpWwReportingWhatDesc =>
      'Im Statistiken-Tab → Lager/Lieferanten findest du drei Auswertungen:\n• Bestandsbewertung — Lagerwert zum Stichtag (Menge × Einkaufspreis)\n• Lagerumschlag — wie oft dreht sich dein Lager pro Zeitraum\n• ABC-Analyse — welche Artikel machen den größten Wertanteil aus';

  @override
  String get helpWwReportingValuationTitle => 'Bestandsbewertung';

  @override
  String get helpWwReportingValuationDesc =>
      'Zeigt den Gesamtwert deines Lagers (Menge × Einkaufspreis aller Artikel mit hinterlegtem Preis). Artikel ohne Einkaufspreis werden mit 0 bewertet — pflege fehlende Preise nach, damit der Wert stimmt.';

  @override
  String get helpWwReportingTurnoverTitle => 'Lagerumschlag';

  @override
  String get helpWwReportingTurnoverDesc =>
      'Der Lagerumschlag zeigt, wie oft dein Durchschnittsbestand im gewählten Zeitraum umgeschlagen wurde. Ein hoher Wert bedeutet schnellen Abverkauf; ein niedriger Wert kann auf Ladenhüter hinweisen.';

  @override
  String get helpWwReportingAbcTitle => 'ABC-Analyse';

  @override
  String get helpWwReportingAbcDesc =>
      'Artikel werden nach ihrem Wertanteil am Gesamtbestand klassifiziert:\n• A-Artikel — ca. 70–80 % des Wertes, meist wenige Produkte\n• B-Artikel — ca. 15–25 % des Wertes\n• C-Artikel — ca. 5–10 % des Wertes, viele Produkte\nDie Klassifizierung hilft dir zu entscheiden, wo sich enger Einkauf und genauere Planung lohnen.';

  @override
  String get helpFaqQ20 =>
      'Wie verknüpfe ich einen bestehenden Lagerartikel mit dem Artikelstamm?';

  @override
  String get helpFaqA20 =>
      'Öffne den Artikel im Lager-Tab → Bearbeiten → „Produkt verknüpfen\" → Artikel aus dem Stamm suchen und auswählen. Nicht verknüpfte Lagerartikel erscheinen weiterhin in einer eigenen Gruppe „Ohne Artikel\".';

  @override
  String get helpFaqQ21 => 'Was passiert beim Wareneingang mit dem Bestand?';

  @override
  String get helpFaqA21 =>
      'Wenn du in einer Bestellung „Wareneingang buchen\" tippst, erhöht die App den Lagerbestand des verknüpften Artikels um die eingebuchte Menge und schreibt eine Buchung vom Typ „Wareneingang\" in die Buchungshistorie. Der Bestellstatus aktualisiert sich automatisch.';

  @override
  String get helpFaqQ22 => 'Kann ich einen Artikel in mehrere Lager aufteilen?';

  @override
  String get helpFaqA22 =>
      'Ja. Lege mehrere Lagerartikel für dasselbe Produkt an und weise sie verschiedenen Lagern zu. Die Artikel-Detailseite aggregiert den Gesamtbestand über alle Lager und zeigt ihn aufgeteilt.';

  @override
  String get helpFaqQ23 => 'Warum fehlen Artikel in der Inventur-Liste?';

  @override
  String get helpFaqA23 =>
      'Die Inventur erfasst nur Artikel, die mit einem Stammartikel verknüpft sind. Lagerartikel ohne Produktverknüpfung (Gruppe „Ohne Artikel\") tauchen nicht auf. Verknüpfe den Artikel zuerst im Lager-Tab → Artikel bearbeiten → „Produkt verknüpfen\".';

  @override
  String get helpFaqQ24 => 'Wie deaktiviere ich den Low-Stock-Push?';

  @override
  String get helpFaqA24 =>
      'Einstellungen → Push → Kategorie „Mindestbestand\" deaktivieren. Der Push wird dann nicht mehr verschickt; die gelbe Warnung im Dashboard und im Lager-Tab bleibt als stiller Hinweis sichtbar.';

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
  String get ticketsEmptyHint =>
      'Filter anpassen oder ein neues Ticket anlegen.';

  @override
  String get ticketsNoTicket => 'Kein Ticket';

  @override
  String get inventoryEmpty => 'Lager ist leer.';

  @override
  String get inventoryEmptyHint =>
      'Über den + Button kannst du den ersten Artikel hinzufügen.';

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
  String get ticketsArchiveEmptyHint =>
      'Abgeschlossene Tickets werden hier archiviert.';

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
  String get inventorySoldEmptyHint =>
      'Artikel, die du als verkauft markierst, erscheinen hier.';

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
  String get searchRecentTitle => 'Letzte Suchen';

  @override
  String get searchRecentEmpty => 'Noch keine Suchen';

  @override
  String get searchRecentClear => 'Zurücksetzen';

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
  String get settingsPaletteSection => 'Farbpalette';

  @override
  String get settingsPaletteBlue => 'Blau';

  @override
  String get settingsPaletteIndigo => 'Indigo';

  @override
  String get settingsPaletteViolet => 'Violett';

  @override
  String get settingsPaletteTeal => 'Petrol';

  @override
  String get settingsPaletteRose => 'Rose';

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

  @override
  String get trackingAmazonShipmentIdHint =>
      'Amazon-interne Shipment-ID — kein vollwertiges Carrier-Tracking';

  @override
  String get trackingBannerImprovedDetection =>
      'Wir haben die Tracking-Erkennung verbessert. Bitte einmal in „Prüfen“ schauen.';

  @override
  String get trackingCarrierAmazonLogisticsHintShort => 'Amazon Logistics';

  @override
  String get trackingCarrierUnknown => 'Unbekannter Versender';

  @override
  String get trackingConfidenceLabelManual => 'Manuell';

  @override
  String get trackingConfidenceLabelNone => 'Unklar';

  @override
  String get trackingConfidenceLabelStrong => 'Verifiziert';

  @override
  String get trackingEnterManuallyCta => 'Manuell eingeben';

  @override
  String get trackingNoneDetectedSubtitle =>
      'Wir konnten in dieser Mail keine eindeutige Sendungsnummer finden.';

  @override
  String get trackingNoneDetectedTitle => 'Keine Sendungsnummer erkannt';

  @override
  String get trackingReparseCta => 'Sendungsnummern neu bewerten';

  @override
  String get trackingReparseConfirmBody =>
      'Bestehende Sendungsnummern werden mit der verbesserten Erkennung neu geprüft. Manuelle Einträge bleiben unverändert.';

  @override
  String get trackingReparseConfirmTitle => 'Neubewertung starten?';

  @override
  String get trackingReparseFailed => 'Neubewertung fehlgeschlagen';

  @override
  String get trackingReparseOffline =>
      'Keine Verbindung — bitte später erneut versuchen';

  @override
  String get trackingReparseRunning => 'Sendungsnummern werden neu bewertet…';

  @override
  String trackingReparseSuccessCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Sendungsnummern aktualisiert',
      one: '1 Sendungsnummer aktualisiert',
      zero: 'Keine Sendungsnummer aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String get inboxResetCta => 'Postfach zurücksetzen';

  @override
  String get inboxResetSubtitle =>
      'Alle Mails löschen und neu importieren. Beim Re-Import wird jede Mail gegen die DHL-API geprüft. Nicht rückgängig zu machen.';

  @override
  String get inboxResetConfirmTitle => 'Postfach wirklich zurücksetzen?';

  @override
  String get inboxResetConfirmBody =>
      'Alle bisher importierten Mails werden gelöscht, der IMAP-Cursor wird zurückgesetzt und beim nächsten Poll werden alle Mails neu geladen. Deine Deals bleiben erhalten.\n\nZur Bestätigung tippe RESET ein.';

  @override
  String get inboxResetConfirmInputLabel => 'Tippe RESET zur Bestätigung';

  @override
  String get inboxResetRunning => 'Postfach wird zurückgesetzt…';

  @override
  String get inboxResetFailed =>
      'Reset fehlgeschlagen — bitte später erneut versuchen.';

  @override
  String inboxResetSuccess(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Mails gelöscht. Nächster Poll lädt alles neu.',
      one: '1 Mail gelöscht. Nächster Poll lädt alles neu.',
      zero: 'Keine Mails gelöscht — IMAP-Cursor wurde zurückgesetzt.',
    );
    return '$_temp0';
  }

  @override
  String trackingNeedsReviewFilterChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Prüfen ($count)',
      one: 'Prüfen (1)',
    );
    return '$_temp0';
  }

  @override
  String get trackingReviewAcceptCta => 'Übernehmen';

  @override
  String get trackingReviewDismissCta => 'Verwerfen';

  @override
  String get trackingReviewListTitle => 'Sendungsnummern prüfen';

  @override
  String get trackingReviewNeededBadge => 'Prüfen';

  @override
  String get trackingStatusBlockA11yLabel => 'Sendungsnummern-Status';

  @override
  String get trackingRetrackCta => 'Status aktualisieren';

  @override
  String get trackingRetrackRunning => 'Status wird abgerufen…';

  @override
  String get trackingRetrackSuccess => 'Status aktualisiert';

  @override
  String get trackingRetrackRateLimited => 'Bitte 30s warten';

  @override
  String get trackingRetrackFailed => 'Status konnte nicht abgerufen werden';

  @override
  String get trackingRetrackOffline => 'Keine Verbindung';

  @override
  String get inboxSectionOrder => 'Bestellung';

  @override
  String get inboxSectionShipping => 'Versand';

  @override
  String get inboxSectionLinkedTo => 'Verknüpft mit';

  @override
  String get inboxFieldOrderId => 'Order-ID';

  @override
  String get inboxFieldProduct => 'Produkt';

  @override
  String get inboxFieldAmount => 'Betrag';

  @override
  String get inboxFieldEta => 'ETA';

  @override
  String get inboxFieldDeal => 'Deal';

  @override
  String get dealTrackingStatusTitle => 'Sendungsnummer';

  @override
  String get dealSectionTrackingStatus => 'Sendungsstatus';

  @override
  String trackingUpdateError(Object error) {
    return 'Tracking-Update fehlgeschlagen: $error';
  }

  @override
  String trackingAcceptError(Object error) {
    return 'Tracking-Akzeptanz fehlgeschlagen: $error';
  }

  @override
  String trackingDiscardError(Object error) {
    return 'Tracking-Verwerfen fehlgeschlagen: $error';
  }

  @override
  String get liveStatusPending => 'Wird vorbereitet';

  @override
  String get liveStatusInTransit => 'Unterwegs';

  @override
  String get liveStatusOutForDelivery => 'In Zustellung';

  @override
  String get liveStatusDelivered => 'Zugestellt';

  @override
  String get liveStatusException => 'Problem — bitte prüfen';

  @override
  String get liveStatusExpired => 'Status veraltet';

  @override
  String get inboxFilterResetLabel => 'Filter zurücksetzen';

  @override
  String get inboxFilterResetTitle => 'Filter zurücksetzen?';

  @override
  String get inboxCopyMessageIdSnackbar =>
      'Message-ID in die Zwischenablage kopiert.';

  @override
  String get inboxNoMailLinkSnackbar => 'Kein Mail-Link verfügbar.';

  @override
  String get inboxNoTrackingSnackbar => 'Diese Mail enthält kein Tracking.';

  @override
  String get inboxOpenMailInBrowserMenuItem => 'Mail im Browser öffnen';

  @override
  String get inboxOpenMailLabel => 'Mail öffnen';

  @override
  String get inboxOpenTicketLabel => 'Ticket öffnen';

  @override
  String get inboxSuggestionsEmpty => 'Keine offenen Vorschläge';

  @override
  String get inboxSuggestionsEmptyHint =>
      'Neue Mails werden automatisch analysiert und erscheinen hier.';

  @override
  String get inboxUpdatedEmpty => 'Keine aktualisierten Deals';

  @override
  String get inboxUpdatedEmptyHint =>
      'Deals, bei denen der Versandstatus automatisch aktualisiert wurde, erscheinen hier.';

  @override
  String get inboxUnclassifiedEmpty => 'Keine unklassifizierten Mails';

  @override
  String get inboxUnclassifiedEmptyHint =>
      'Mails ohne zuordenbaren Deal oder Carrier werden hier gesammelt.';

  @override
  String get inventoryDiscordTooltip => 'Discord-Ticket öffnen';

  @override
  String get inventoryProductHelperText =>
      'Aus Ticket auswählen oder frei eingeben';

  @override
  String get settingsAddAmazonShops => 'Amazon-Shops hinzufügen';

  @override
  String get suppliersAddCarriers => 'Versanddienste hinzufügen';

  @override
  String get urlHelperLinkOpenError => 'Link konnte nicht geöffnet werden.';

  @override
  String inboxAcceptedSnack(Object tracking, int dealId) {
    return 'Tracking $tracking → Deal #$dealId übernommen';
  }

  @override
  String inboxAcceptedSnackNoTracking(int dealId) {
    return 'Deal #$dealId angelegt';
  }

  @override
  String get inboxAcceptedShowDeal => 'Anzeigen';

  @override
  String get inboxSuggestionDismiss => 'Verwerfen';

  @override
  String get inboxSuggestionEdit => 'Vor Übernahme bearbeiten';

  @override
  String get inboxSuggestionAccept => 'Annehmen';

  @override
  String get productCatalogTitle => 'Artikelstamm';

  @override
  String get productNew => 'Neuer Artikel';

  @override
  String get productUnit => 'Einheit';

  @override
  String get productDefaultCostPrice => 'Standard-EK';

  @override
  String get productDefaultSalePrice => 'Standard-VK';

  @override
  String get productCategory => 'Warengruppe';

  @override
  String get productDefaultSupplier => 'Standard-Lieferant';

  @override
  String get productMinStock => 'Mindestbestand';

  @override
  String get productTaxRate => 'MwSt.-Satz (%)';

  @override
  String get productIsActive => 'Aktiv';

  @override
  String get productAdvancedSection => 'Erweitert';

  @override
  String get productNameLabel => 'Artikelname';

  @override
  String get productSkuLabel => 'Artikelnummer (SKU)';

  @override
  String get productEanLabel => 'EAN / GTIN';

  @override
  String get productNoteLabel => 'Notiz';

  @override
  String get productEditTitle => 'Artikel bearbeiten';

  @override
  String get productAddTitle => 'Neuer Artikel';

  @override
  String get productGroupWithoutProduct => 'Ohne Artikel';

  @override
  String get productCatalogEmpty => 'Kein Artikelstamm';

  @override
  String get productCatalogEmptyHint => 'Lege deinen ersten Artikel an.';

  @override
  String get productCatalogLoadError =>
      'Artikelstamm konnte nicht geladen werden.';

  @override
  String get productCatalogNoPermission =>
      'Du hast keine Berechtigung, den Artikelstamm zu bearbeiten.';

  @override
  String get productCatalogViewerHint =>
      'Du siehst den Artikelstamm im Lesemodus.';

  @override
  String get productLinkLabel => 'Verknüpfter Stammartikel';

  @override
  String get productNoLink => 'Kein Stammartikel';

  @override
  String get productDetailTitle => 'Artikeldetails';

  @override
  String get productDetailEmpty => 'Keine Daten';

  @override
  String get productDetailEmptyHint =>
      'Für diesen Artikel gibt es noch keine Bewegungen.';

  @override
  String get productDetailLoadError =>
      'Artikeldetails konnten nicht geladen werden.';

  @override
  String get movementTypeGoodsIn => 'Wareneingang';

  @override
  String get movementTypeGoodsOut => 'Warenausgang';

  @override
  String get movementTypeCorrection => 'Korrektur';

  @override
  String get movementTypeStocktake => 'Inventur';

  @override
  String get movementTypeTransfer => 'Umlagerung';

  @override
  String get movementTypeSale => 'Verkauf';

  @override
  String get movementHistoryTitle => 'Bewegungshistorie';

  @override
  String get productDetailSectionStammdaten => 'Stammdaten';

  @override
  String get productDetailSectionStock => 'Bestand';

  @override
  String get productDetailSectionSupplier => 'Lieferant';

  @override
  String get productDetailSectionBatches => 'Chargen';

  @override
  String get productDetailLabelSku => 'Artikelnummer (SKU)';

  @override
  String get productDetailLabelEan => 'EAN';

  @override
  String get productDetailLabelLocation => 'Lagerort';

  @override
  String get productDetailLabelStatus => 'Status';

  @override
  String get productDetailLabelSupplier => 'Lieferant';

  @override
  String get productDetailLabelQuantity => 'Bestand';

  @override
  String get productDetailLabelMinStock => 'Mindestbestand';

  @override
  String get productDetailLabelCostPrice => 'Einstandspreis';

  @override
  String get productDetailLabelArrivalDate => 'Ankunftsdatum';

  @override
  String get productDetailLabelNote => 'Notiz';

  @override
  String get productDetailLabelCritical => 'Kritisch';

  @override
  String get productDetailLabelOk => 'OK';

  @override
  String get productDetailViewBatches => 'Chargen anzeigen';

  @override
  String get productDetailNoSupplier => 'Kein Lieferant';

  @override
  String get productDetailNoLocation => 'Kein Lagerort';

  @override
  String get productDetailViewerHint =>
      'Du hast nur Lesezugriff — Buchungsaktionen nicht verfügbar.';

  @override
  String get productDetailRetry => 'Erneut laden';

  @override
  String productDetailMovementQuantity(Object sign, int qty) {
    return '$sign$qty';
  }

  @override
  String get productDetailSectionProduct => 'Artikel (Stammdaten)';

  @override
  String get productDetailLabelProductUnit => 'Einheit';

  @override
  String get productDetailLabelDefaultCostPrice => 'Standard-EK';

  @override
  String get productDetailLabelDefaultSalePrice => 'Standard-VK';

  @override
  String get productDetailLabelMinStockProduct => 'Mindestbestand (Produkt)';

  @override
  String get productDetailLabelTaxRate => 'MwSt-Satz';

  @override
  String get productDetailSectionAggregatedStock => 'Gesamtbestand';

  @override
  String get productDetailLabelTotalQty => 'Gesamt (alle Lager)';

  @override
  String productDetailLabelWarehouseQty(Object warehouse) {
    return 'Lager $warehouse';
  }

  @override
  String get productDetailLabelNoWarehouse => 'Kein Lager zugeordnet';

  @override
  String get productDetailMovementsAllProduct =>
      'Alle Bewegungen dieses Produkts (alle Bestands-Rows).';

  @override
  String productDetailLoadMoreMovements(int count) {
    return 'Weitere $count laden';
  }

  @override
  String get productDetailAllMovementsShown => 'Alle Bewegungen angezeigt';

  @override
  String stockGroupItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Positionen',
      one: '1 Position',
    );
    return '$_temp0';
  }

  @override
  String stockGroupTotalQuantity(int qty) {
    return 'Gesamt: $qty Stk.';
  }

  @override
  String get categoriesTitle => 'Warengruppen';

  @override
  String get categoriesEmpty => 'Keine Warengruppen';

  @override
  String get categoriesEmptyHint => 'Lege deine erste Warengruppe an.';

  @override
  String get categoriesLoadError =>
      'Warengruppen konnten nicht geladen werden.';

  @override
  String get categoryNew => 'Neue Warengruppe';

  @override
  String get categoryEdit => 'Warengruppe bearbeiten';

  @override
  String get categoryDelete => 'Warengruppe löschen';

  @override
  String categoryDeletePrompt(Object name) {
    return '„$name\" wirklich löschen?';
  }

  @override
  String get categoryParent => 'Übergeordnet';

  @override
  String get categoryParentNone => 'Keine (Hauptgruppe)';

  @override
  String get categoryFieldName => 'Name';

  @override
  String get categoryFieldSortOrder => 'Sortierung';

  @override
  String get categoryMaxDepthError =>
      'Nur 2 Ebenen erlaubt. Bitte eine Hauptgruppe wählen.';

  @override
  String get categorySortOrderHint => 'Zahl, niedrig = zuerst';

  @override
  String get supplierAddress => 'Adresse';

  @override
  String get supplierAddressStreet => 'Straße';

  @override
  String get supplierAddressZip => 'PLZ';

  @override
  String get supplierAddressCity => 'Ort';

  @override
  String get supplierAddressCountry => 'Land';

  @override
  String get supplierVatId => 'USt-IdNr';

  @override
  String get supplierCustomerNumber => 'Kundennummer';

  @override
  String get supplierPaymentTerms => 'Zahlungsziel (Tage)';

  @override
  String get supplierLeadTime => 'Lieferzeit (Tage)';

  @override
  String get supplierMinOrderValue => 'Mindestbestellwert';

  @override
  String get supplierAdvancedSection => 'Erweiterte Angaben';

  @override
  String get commonDaysUnit => 'Tage';

  @override
  String get purchaseOrdersTitle => 'Bestellungen';

  @override
  String get purchaseOrdersEmpty => 'Keine Bestellungen';

  @override
  String get purchaseOrdersEmptyHint => 'Lege deine erste Bestellung an.';

  @override
  String get purchaseOrdersLoadError =>
      'Bestellungen konnten nicht geladen werden.';

  @override
  String get purchaseOrderNew => 'Neue Bestellung';

  @override
  String get purchaseOrderEdit => 'Bestellung bearbeiten';

  @override
  String get purchaseOrderDelete => 'Bestellung löschen';

  @override
  String purchaseOrderDeletePrompt(Object number) {
    return '„$number\" wirklich löschen?';
  }

  @override
  String get purchaseOrderStatusDraft => 'Entwurf';

  @override
  String get purchaseOrderStatusOrdered => 'Bestellt';

  @override
  String get purchaseOrderStatusPartial => 'Teilweise erhalten';

  @override
  String get purchaseOrderStatusReceived => 'Erhalten';

  @override
  String get purchaseOrderStatusCancelled => 'Storniert';

  @override
  String get purchaseOrderFieldSupplier => 'Lieferant';

  @override
  String get purchaseOrderFieldSupplierHint => 'Lieferant wählen';

  @override
  String get purchaseOrderFieldOrderDate => 'Bestelldatum';

  @override
  String get purchaseOrderFieldExpectedDate => 'Erwartetes Lieferdatum';

  @override
  String get purchaseOrderFieldNote => 'Notiz';

  @override
  String get purchaseOrderFieldNoteHint =>
      'Optionale Anmerkungen zur Bestellung';

  @override
  String get purchaseOrderSectionItems => 'Positionen';

  @override
  String get purchaseOrderItemsEmpty => 'Keine Positionen';

  @override
  String get purchaseOrderItemAdd => 'Position hinzufügen';

  @override
  String get purchaseOrderItemFieldProduct => 'Artikel';

  @override
  String get purchaseOrderItemFieldProductHint => 'Artikel wählen';

  @override
  String get purchaseOrderItemFieldQtyOrdered => 'Menge';

  @override
  String get purchaseOrderItemFieldUnitPrice => 'Einzelpreis (€)';

  @override
  String get purchaseOrderItemDelete => 'Position löschen';

  @override
  String get purchaseOrderItemDeletePrompt =>
      'Diese Position wirklich löschen?';

  @override
  String get purchaseOrderNoSupplierError =>
      'Bitte einen Lieferanten auswählen.';

  @override
  String get purchaseOrderNoItemsError =>
      'Mindestens eine Position erforderlich.';

  @override
  String get purchaseOrderStatusToOrdered => 'Als bestellt markieren';

  @override
  String get purchaseOrderStatusToCancelled => 'Stornieren';

  @override
  String get purchaseOrderStatusChangeConfirm => 'Status wirklich ändern?';

  @override
  String get purchaseOrderDetailTitle => 'Bestelldetails';

  @override
  String get purchaseOrderDetailSectionHead => 'Bestellkopf';

  @override
  String get purchaseOrderLabelNumber => 'Bestellnummer';

  @override
  String get purchaseOrderLabelSupplier => 'Lieferant';

  @override
  String get purchaseOrderLabelStatus => 'Status';

  @override
  String get purchaseOrderLabelOrderDate => 'Bestelldatum';

  @override
  String get purchaseOrderLabelExpectedDate => 'Erwartet';

  @override
  String get purchaseOrderLabelNote => 'Notiz';

  @override
  String get purchaseOrderLabelTotalNet => 'Nettosumme';

  @override
  String get purchaseOrderDetailSectionItems => 'Positionen';

  @override
  String get purchaseOrderItemsLoadError =>
      'Positionen konnten nicht geladen werden.';

  @override
  String get goodsReceiptBook => 'Wareneingang buchen';

  @override
  String get goodsReceiptSuccess => 'Wareneingang gebucht.';

  @override
  String get goodsReceiptError => 'Fehler beim Buchen des Wareneingangs.';

  @override
  String get goodsReceiptNoProduct =>
      'Diese Position hat kein verknüpftes Produkt und kann nicht eingebucht werden.';

  @override
  String get quantityOrdered => 'Bestellt';

  @override
  String get quantityReceived => 'Erhalten';

  @override
  String get purchaseOrderScanBarcode => 'Barcode scannen';

  @override
  String get purchaseOrderScanNoMatch =>
      'Kein Artikel für diesen Barcode gefunden.';

  @override
  String get purchaseOrderPdfExport => 'PDF-Beleg';

  @override
  String get purchaseOrderPdfExportComingSoon =>
      'PDF-Export kommt in einem späteren Update.';

  @override
  String get purchaseOrderPdfExportError =>
      'PDF-Beleg konnte nicht erstellt werden.';

  @override
  String get purchaseOrderStatusChangeError =>
      'Status konnte nicht geändert werden.';

  @override
  String get purchaseOrderViewerHint =>
      'Du hast nur Lesezugriff — Buchungsaktionen nicht verfügbar.';

  @override
  String get purchaseOrderStatusAutoManaged =>
      'Dieser Status wird automatisch gepflegt.';

  @override
  String get poPdfDocumentTitle => 'Bestellbeleg';

  @override
  String get poPdfSupplierLabel => 'Lieferant';

  @override
  String get poPdfVatIdLabel => 'USt-IdNr';

  @override
  String get poPdfOrderDateLabel => 'Bestelldatum';

  @override
  String get poPdfExpectedDateLabel => 'Erwartetes Lieferdatum';

  @override
  String get poPdfStatusLabel => 'Status';

  @override
  String get poPdfSectionItems => 'Positionen';

  @override
  String get poPdfColProduct => 'Artikel';

  @override
  String get poPdfColOrdered => 'Bestellt';

  @override
  String get poPdfColReceived => 'Erhalten';

  @override
  String get poPdfColUnitPrice => 'Einzelpreis';

  @override
  String get poPdfColLineTotal => 'Zeilensumme';

  @override
  String get poPdfTotalNetLabel => 'Nettosumme';

  @override
  String get poPdfNoteLabel => 'Notiz';

  @override
  String get warehousesTitle => 'Lager';

  @override
  String get warehousesEmpty => 'Keine Lager';

  @override
  String get warehousesEmptyHint => 'Lege dein erstes Lager an.';

  @override
  String get warehousesLoadError => 'Lager konnten nicht geladen werden.';

  @override
  String get warehouseNew => 'Neues Lager';

  @override
  String get warehouseDefault => 'Hauptlager';

  @override
  String get warehouseEdit => 'Lager bearbeiten';

  @override
  String get warehouseNameLabel => 'Name';

  @override
  String get warehouseAddressLabel => 'Adresse';

  @override
  String get warehouseIsDefaultLabel => 'Standardlager';

  @override
  String get warehouseIsActiveLabel => 'Aktiv';

  @override
  String get warehouseInactiveBadge => 'Inaktiv';

  @override
  String warehouseDeletePrompt(Object name) {
    return 'Lager \"$name\" wirklich löschen?';
  }

  @override
  String get inventoryWarehouseLabel => 'Lager';

  @override
  String get inventoryNoWarehouse => 'Kein Lager';

  @override
  String get lowStockAlertTitle => 'Niedriger Bestand';

  @override
  String lowStockAlertBody(Object count) {
    return '$count Artikel unter Mindestbestand';
  }

  @override
  String get lowStockReorderAction => 'Jetzt bestellen';

  @override
  String get reportStockValuation => 'Bestandsbewertung';

  @override
  String get reportStockValuationSubtitle =>
      'Gesamtwert des Lagerbestands (Einstandspreis)';

  @override
  String get reportStockValuationTotal => 'Gesamtwert';

  @override
  String get reportStockValuationUnits => 'Gesamtmenge';

  @override
  String get reportStockValuationItemName => 'Artikel';

  @override
  String get reportStockValuationQuantity => 'Menge';

  @override
  String get reportStockValuationCostPrice => 'EK';

  @override
  String get reportStockValuationValue => 'Wert';

  @override
  String get reportStockValuationEmpty =>
      'Kein Lagerbestand zur Bewertung vorhanden.';

  @override
  String get reportInventoryTurnover => 'Lagerumschlag';

  @override
  String get reportInventoryTurnoverSubtitle =>
      'Umschlagshäufigkeit des Lagerbestands';

  @override
  String get reportInventoryTurnoverRate => 'Umschlagshäufigkeit';

  @override
  String get reportInventoryTurnoverOutflow => 'Warenausgang (Stk.)';

  @override
  String get reportInventoryTurnoverAvgStock => 'Ø Bestand (Stk.)';

  @override
  String get reportInventoryTurnoverMovements => 'Abgangs-Buchungen';

  @override
  String get reportInventoryTurnoverNoData =>
      'Keine Abgangs-Buchungen vorhanden.';

  @override
  String get reportInventoryTurnoverHint =>
      'Verhältnis Warenausgang zu Ø Bestand';

  @override
  String get reportAbcAnalysis => 'ABC-Analyse';

  @override
  String get reportAbcAnalysisSubtitle =>
      'Artikel nach Bestandswert klassifiziert';

  @override
  String get reportAbcClassA => 'A — Werttreiber (≤ 80 %)';

  @override
  String get reportAbcClassB => 'B — Mittelfeld (80–95 %)';

  @override
  String get reportAbcClassC => 'C — Restmenge (> 95 %)';

  @override
  String get reportAbcItemName => 'Artikel';

  @override
  String get reportAbcItemValue => 'Wert';

  @override
  String get reportAbcItemShare => 'Anteil kum.';

  @override
  String get reportAbcItemClass => 'Klasse';

  @override
  String get reportAbcEmpty => 'Kein Lagerbestand für ABC-Analyse vorhanden.';

  @override
  String reportAbcCountItems(int count) {
    return '$count Artikel';
  }

  @override
  String get stocktakeTitle => 'Inventur';

  @override
  String get stocktakeEmpty => 'Keine Inventuren';

  @override
  String get stocktakeEmptyHint => 'Starte deine erste Inventur.';

  @override
  String get stocktakeLoadError => 'Inventuren konnten nicht geladen werden.';

  @override
  String get stocktakeNew => 'Neue Inventur';

  @override
  String stocktakeProgress(int counted, int total) {
    return '$counted/$total gezählt';
  }

  @override
  String get stocktakeFilterUncounted => 'Nur ungezählte';

  @override
  String get stocktakeExpected => 'Soll';

  @override
  String get stocktakeCounted => 'Gezählt';

  @override
  String get stocktakeDifference => 'Differenz';

  @override
  String get stocktakeStatusOpen => 'Offen';

  @override
  String get stocktakeStatusCounting => 'Läuft';

  @override
  String get stocktakeStatusClosed => 'Abgeschlossen';

  @override
  String get stocktakeStatusCancelled => 'Storniert';

  @override
  String get stocktakeTitleLabel => 'Titel (optional)';

  @override
  String get stocktakeTitleHint => 'z. B. Jahresabschluss 2026';

  @override
  String get stocktakeSelectWarehouse => 'Lager (optional)';

  @override
  String get stocktakeAllWarehouses => 'Alle Lager';

  @override
  String get stocktakeStartAction => 'Inventur starten';

  @override
  String get stocktakeStartError => 'Inventur konnte nicht gestartet werden.';

  @override
  String get stocktakeSaveError =>
      'Speichern fehlgeschlagen — Eingabe lokal gespeichert.';

  @override
  String get stocktakeScanBarcode => 'Barcode scannen';

  @override
  String get stocktakeScanNoMatch => 'Kein passender Artikel gefunden.';

  @override
  String get stocktakeCloseAction => 'Inventur abschließen';

  @override
  String get stocktakeCloseConfirm => 'Inventur abschließen?';

  @override
  String get stocktakeCloseConfirmHint =>
      'Die Inventur wird abgeschlossen und die Differenzen gebucht. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get stocktakeCloseSuccess => 'Inventur erfolgreich abgeschlossen.';

  @override
  String get stocktakeCloseError =>
      'Inventur konnte nicht abgeschlossen werden.';

  @override
  String get stocktakeAllCounted => 'Alle Positionen gezählt.';

  @override
  String get stocktakeDiffReportTitle => 'Differenz-Report';

  @override
  String get stocktakeDiffReportNoDiff =>
      'Keine Differenzen — Bestand ist korrekt.';

  @override
  String get stocktakeNoItems => 'Keine Positionen';

  @override
  String get detailPaneNoSelection => 'Kein Eintrag ausgewählt';

  @override
  String get detailPaneNoSelectionHint =>
      'Wähle links einen Artikel aus, um Details zu sehen.';

  @override
  String confirmTypeNamePrompt(String name) {
    return 'Gib „$name“ ein, um zu bestätigen.';
  }

  @override
  String get appFeedbackUndoAction => 'Rückgängig';

  @override
  String get appFeedbackErrorDefault =>
      'Etwas ist schiefgegangen. Bitte erneut versuchen.';
}
