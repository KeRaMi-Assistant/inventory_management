import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'Lagerverwaltung'**
  String get appTitle;

  /// No description provided for @actionSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get actionEdit;

  /// No description provided for @actionAdd.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get actionAdd;

  /// No description provided for @actionClose.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get actionClose;

  /// No description provided for @actionBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get actionBack;

  /// No description provided for @actionOk.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionYes.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get actionYes;

  /// No description provided for @actionNo.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get actionNo;

  /// No description provided for @actionConfirm.
  ///
  /// In de, this message translates to:
  /// **'Bestätigen'**
  String get actionConfirm;

  /// No description provided for @actionRetry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get actionRetry;

  /// No description provided for @actionRefresh.
  ///
  /// In de, this message translates to:
  /// **'Aktualisieren'**
  String get actionRefresh;

  /// No description provided for @actionReset.
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get actionReset;

  /// No description provided for @actionSelectAll.
  ///
  /// In de, this message translates to:
  /// **'Alle auswählen'**
  String get actionSelectAll;

  /// No description provided for @actionDeselect.
  ///
  /// In de, this message translates to:
  /// **'Auswahl aufheben'**
  String get actionDeselect;

  /// No description provided for @actionSearch.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get actionSearch;

  /// No description provided for @actionHelp.
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get actionHelp;

  /// No description provided for @actionClear.
  ///
  /// In de, this message translates to:
  /// **'Leeren'**
  String get actionClear;

  /// No description provided for @actionFilter.
  ///
  /// In de, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// No description provided for @actionExport.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get actionExport;

  /// No description provided for @actionImport.
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get actionImport;

  /// No description provided for @actionDuplicate.
  ///
  /// In de, this message translates to:
  /// **'Duplizieren'**
  String get actionDuplicate;

  /// No description provided for @actionCopy.
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get actionCopy;

  /// No description provided for @actionShare.
  ///
  /// In de, this message translates to:
  /// **'Teilen'**
  String get actionShare;

  /// No description provided for @actionDownload.
  ///
  /// In de, this message translates to:
  /// **'Herunterladen'**
  String get actionDownload;

  /// No description provided for @actionUpload.
  ///
  /// In de, this message translates to:
  /// **'Hochladen'**
  String get actionUpload;

  /// No description provided for @actionOpen.
  ///
  /// In de, this message translates to:
  /// **'Öffnen'**
  String get actionOpen;

  /// No description provided for @actionApply.
  ///
  /// In de, this message translates to:
  /// **'Anwenden'**
  String get actionApply;

  /// No description provided for @actionLoading.
  ///
  /// In de, this message translates to:
  /// **'Lädt …'**
  String get actionLoading;

  /// No description provided for @actionSaving.
  ///
  /// In de, this message translates to:
  /// **'Speichert …'**
  String get actionSaving;

  /// No description provided for @actionDeleting.
  ///
  /// In de, this message translates to:
  /// **'Löscht …'**
  String get actionDeleting;

  /// No description provided for @commonAll.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get commonAll;

  /// No description provided for @commonNone.
  ///
  /// In de, this message translates to:
  /// **'Keiner'**
  String get commonNone;

  /// No description provided for @commonOptional.
  ///
  /// In de, this message translates to:
  /// **'optional'**
  String get commonOptional;

  /// No description provided for @commonRequired.
  ///
  /// In de, this message translates to:
  /// **'Pflichtfeld'**
  String get commonRequired;

  /// No description provided for @commonNotSet.
  ///
  /// In de, this message translates to:
  /// **'Nicht gesetzt'**
  String get commonNotSet;

  /// No description provided for @commonUnknown.
  ///
  /// In de, this message translates to:
  /// **'Unbekannt'**
  String get commonUnknown;

  /// No description provided for @commonItems.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Eintrag} other{{count} Einträge}}'**
  String commonItems(int count);

  /// No description provided for @commonSelected.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 ausgewählt} other{{count} ausgewählt}}'**
  String commonSelected(int count);

  /// No description provided for @navDashboard.
  ///
  /// In de, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navDeals.
  ///
  /// In de, this message translates to:
  /// **'Deals'**
  String get navDeals;

  /// No description provided for @navTickets.
  ///
  /// In de, this message translates to:
  /// **'Tickets'**
  String get navTickets;

  /// No description provided for @navInbox.
  ///
  /// In de, this message translates to:
  /// **'Postfach'**
  String get navInbox;

  /// No description provided for @navInventory.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get navInventory;

  /// No description provided for @navSuppliers.
  ///
  /// In de, this message translates to:
  /// **'Lieferanten'**
  String get navSuppliers;

  /// No description provided for @navStatistics.
  ///
  /// In de, this message translates to:
  /// **'Statistiken'**
  String get navStatistics;

  /// No description provided for @navActivity.
  ///
  /// In de, this message translates to:
  /// **'Aktivität'**
  String get navActivity;

  /// No description provided for @navHelp.
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get navHelp;

  /// No description provided for @navSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get navSettings;

  /// No description provided for @navMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get navMore;

  /// No description provided for @navMoreSheetTitle.
  ///
  /// In de, this message translates to:
  /// **'Weitere Bereiche'**
  String get navMoreSheetTitle;

  /// No description provided for @fieldEmail.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get fieldPassword;

  /// No description provided for @fieldNewPassword.
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort'**
  String get fieldNewPassword;

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort bestätigen'**
  String get fieldConfirmPassword;

  /// No description provided for @fieldName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get fieldNote;

  /// No description provided for @passwordRequired.
  ///
  /// In de, this message translates to:
  /// **'Passwort erforderlich'**
  String get passwordRequired;

  /// No description provided for @loginSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Mit deinem Konto anmelden'**
  String get loginSubtitle;

  /// No description provided for @loginModePersonal.
  ///
  /// In de, this message translates to:
  /// **'Persönlich'**
  String get loginModePersonal;

  /// No description provided for @loginModeTeam.
  ///
  /// In de, this message translates to:
  /// **'Team'**
  String get loginModeTeam;

  /// No description provided for @loginTeamIdLabel.
  ///
  /// In de, this message translates to:
  /// **'Team-ID'**
  String get loginTeamIdLabel;

  /// No description provided for @loginTeamIdHelp.
  ///
  /// In de, this message translates to:
  /// **'Die Workspace-ID, die der Team-Owner geteilt hat.'**
  String get loginTeamIdHelp;

  /// No description provided for @loginTeamIdRequired.
  ///
  /// In de, this message translates to:
  /// **'Team-ID erforderlich'**
  String get loginTeamIdRequired;

  /// No description provided for @loginTeamIdInvalid.
  ///
  /// In de, this message translates to:
  /// **'Ungültige Team-ID (UUID erwartet)'**
  String get loginTeamIdInvalid;

  /// No description provided for @loginTeamNotMember.
  ///
  /// In de, this message translates to:
  /// **'Du bist kein Mitglied dieses Teams.'**
  String get loginTeamNotMember;

  /// No description provided for @loginForgotPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort vergessen?'**
  String get loginForgotPassword;

  /// No description provided for @loginSubmit.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get loginSubmit;

  /// No description provided for @loginInProgress.
  ///
  /// In de, this message translates to:
  /// **'Anmelden …'**
  String get loginInProgress;

  /// No description provided for @loginContinueWith.
  ///
  /// In de, this message translates to:
  /// **'oder weiter mit'**
  String get loginContinueWith;

  /// No description provided for @loginWithGoogle.
  ///
  /// In de, this message translates to:
  /// **'Mit Google anmelden'**
  String get loginWithGoogle;

  /// No description provided for @loginWithApple.
  ///
  /// In de, this message translates to:
  /// **'Mit Apple anmelden'**
  String get loginWithApple;

  /// No description provided for @loginNoAccount.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Konto?'**
  String get loginNoAccount;

  /// No description provided for @loginRegister.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get loginRegister;

  /// No description provided for @registerTitle.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellen'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Lege ein neues Konto an, um loszulegen.'**
  String get registerSubtitle;

  /// No description provided for @registerSubmit.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get registerSubmit;

  /// No description provided for @registerInProgress.
  ///
  /// In de, this message translates to:
  /// **'Registriert …'**
  String get registerInProgress;

  /// No description provided for @registerHasAccount.
  ///
  /// In de, this message translates to:
  /// **'Bereits ein Konto?'**
  String get registerHasAccount;

  /// No description provided for @registerLogin.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get registerLogin;

  /// No description provided for @forgotTitle.
  ///
  /// In de, this message translates to:
  /// **'Passwort zurücksetzen'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wir senden dir einen Link zum Zurücksetzen.'**
  String get forgotSubtitle;

  /// No description provided for @forgotSubmit.
  ///
  /// In de, this message translates to:
  /// **'Link senden'**
  String get forgotSubmit;

  /// No description provided for @forgotSent.
  ///
  /// In de, this message translates to:
  /// **'Reset-Link gesendet. Bitte prüfe dein Postfach.'**
  String get forgotSent;

  /// No description provided for @forgotBackToLogin.
  ///
  /// In de, this message translates to:
  /// **'Zurück zum Login'**
  String get forgotBackToLogin;

  /// No description provided for @resetTitle.
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort setzen'**
  String get resetTitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wähle ein neues Passwort für dein Konto.'**
  String get resetSubtitle;

  /// No description provided for @resetSubmit.
  ///
  /// In de, this message translates to:
  /// **'Passwort speichern'**
  String get resetSubmit;

  /// No description provided for @resetSuccess.
  ///
  /// In de, this message translates to:
  /// **'Passwort aktualisiert.'**
  String get resetSuccess;

  /// No description provided for @resetMismatch.
  ///
  /// In de, this message translates to:
  /// **'Passwörter stimmen nicht überein.'**
  String get resetMismatch;

  /// No description provided for @verifyTitle.
  ///
  /// In de, this message translates to:
  /// **'E-Mail bestätigen'**
  String get verifyTitle;

  /// No description provided for @verifySubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wir haben dir einen Bestätigungslink gesendet.'**
  String get verifySubtitle;

  /// No description provided for @verifyResend.
  ///
  /// In de, this message translates to:
  /// **'Erneut senden'**
  String get verifyResend;

  /// No description provided for @splashSyncing.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiere mit Cloud …'**
  String get splashSyncing;

  /// No description provided for @sessionExpiringSoon.
  ///
  /// In de, this message translates to:
  /// **'Sitzung läuft bald ab.'**
  String get sessionExpiringSoon;

  /// No description provided for @sessionExtend.
  ///
  /// In de, this message translates to:
  /// **'Verlängern'**
  String get sessionExtend;

  /// No description provided for @sessionExtendFailed.
  ///
  /// In de, this message translates to:
  /// **'Sitzung konnte nicht verlängert werden.'**
  String get sessionExtendFailed;

  /// No description provided for @headerSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get headerSearchHint;

  /// No description provided for @headerImportCsv.
  ///
  /// In de, this message translates to:
  /// **'CSV importieren'**
  String get headerImportCsv;

  /// No description provided for @headerExportCsv.
  ///
  /// In de, this message translates to:
  /// **'CSV exportieren'**
  String get headerExportCsv;

  /// No description provided for @csvExportSuccess.
  ///
  /// In de, this message translates to:
  /// **'Exportiert: {path}'**
  String csvExportSuccess(Object path);

  /// No description provided for @csvImportConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'CSV importieren'**
  String get csvImportConfirmTitle;

  /// No description provided for @csvImportConfirmText.
  ///
  /// In de, this message translates to:
  /// **'Deals werden hinzugefügt. Shops, Käufer und Lagerbestand werden nur importiert, wenn noch kein Eintrag mit demselben Namen existiert.'**
  String get csvImportConfirmText;

  /// No description provided for @csvImportPickFile.
  ///
  /// In de, this message translates to:
  /// **'Datei auswählen'**
  String get csvImportPickFile;

  /// No description provided for @csvImportSummary.
  ///
  /// In de, this message translates to:
  /// **'{deals} Deals, {shops} Shops, {buyers} Käufer, {suppliers} Lieferanten, {items} Lagerartikel importiert.'**
  String csvImportSummary(
    int deals,
    int shops,
    int buyers,
    int suppliers,
    int items,
  );

  /// No description provided for @errorPrefix.
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String errorPrefix(Object error);

  /// No description provided for @accountMenuSignedInAs.
  ///
  /// In de, this message translates to:
  /// **'Angemeldet als'**
  String get accountMenuSignedInAs;

  /// No description provided for @accountMenuSignOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get accountMenuSignOut;

  /// No description provided for @accountMenuDeleteAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto löschen'**
  String get accountMenuDeleteAccount;

  /// No description provided for @accountMenuActiveWorkspace.
  ///
  /// In de, this message translates to:
  /// **'Aktiver Workspace'**
  String get accountMenuActiveWorkspace;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Wirklich abmelden?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmText.
  ///
  /// In de, this message translates to:
  /// **'Du wirst zurück zum Login geleitet. Nicht synchronisierte Eingaben gehen verloren.'**
  String get logoutConfirmText;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In de, this message translates to:
  /// **'Konto endgültig löschen?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountText.
  ///
  /// In de, this message translates to:
  /// **'Dein Konto und alle deine Daten werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get deleteAccountText;

  /// No description provided for @deleteAccountConfirmInstruction.
  ///
  /// In de, this message translates to:
  /// **'Tippe LÖSCHEN zur Bestätigung:'**
  String get deleteAccountConfirmInstruction;

  /// No description provided for @deleteAccountConfirmKeyword.
  ///
  /// In de, this message translates to:
  /// **'LÖSCHEN'**
  String get deleteAccountConfirmKeyword;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Löscht dein Konto und alle Daten unwiderruflich.'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In de, this message translates to:
  /// **'Konto konnte nicht gelöscht werden.'**
  String get deleteAccountFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsTitle;

  /// No description provided for @settingsTabBuyers.
  ///
  /// In de, this message translates to:
  /// **'Käufer'**
  String get settingsTabBuyers;

  /// No description provided for @settingsTabShops.
  ///
  /// In de, this message translates to:
  /// **'Shops'**
  String get settingsTabShops;

  /// No description provided for @settingsTabTeam.
  ///
  /// In de, this message translates to:
  /// **'Team'**
  String get settingsTabTeam;

  /// No description provided for @settingsTabPush.
  ///
  /// In de, this message translates to:
  /// **'Push'**
  String get settingsTabPush;

  /// No description provided for @settingsTabShipping.
  ///
  /// In de, this message translates to:
  /// **'Versand'**
  String get settingsTabShipping;

  /// No description provided for @settingsTabGeneral.
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get settingsTabGeneral;

  /// No description provided for @shippingIntroTitle.
  ///
  /// In de, this message translates to:
  /// **'Carrier-API-Keys'**
  String get shippingIntroTitle;

  /// No description provided for @shippingIntroBody.
  ///
  /// In de, this message translates to:
  /// **'Hinterlege je Carrier einen API-Key, damit die App alle 4 Stunden den Sendungsstatus pollt und Deals automatisch auf „Angekommen“ setzt.'**
  String get shippingIntroBody;

  /// No description provided for @shippingNoAccess.
  ///
  /// In de, this message translates to:
  /// **'Nur Workspace-Owner und Admins dürfen Carrier-Keys pflegen.'**
  String get shippingNoAccess;

  /// No description provided for @shippingNotConfigured.
  ///
  /// In de, this message translates to:
  /// **'Nicht hinterlegt'**
  String get shippingNotConfigured;

  /// No description provided for @shippingSetKey.
  ///
  /// In de, this message translates to:
  /// **'API-Key hinterlegen'**
  String get shippingSetKey;

  /// No description provided for @shippingUpdateKey.
  ///
  /// In de, this message translates to:
  /// **'API-Key ersetzen'**
  String get shippingUpdateKey;

  /// No description provided for @shippingDeleteKey.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get shippingDeleteKey;

  /// No description provided for @shippingKeyDialogTitle.
  ///
  /// In de, this message translates to:
  /// **'{carrier}-API-Key'**
  String shippingKeyDialogTitle(Object carrier);

  /// No description provided for @shippingKeyHelp.
  ///
  /// In de, this message translates to:
  /// **'Der Key wird serverseitig verschlüsselt. Nach dem Speichern siehst du nur noch die letzten 4 Zeichen.'**
  String get shippingKeyHelp;

  /// No description provided for @shippingKeyTooShort.
  ///
  /// In de, this message translates to:
  /// **'Mindestens 8 Zeichen eingeben.'**
  String get shippingKeyTooShort;

  /// No description provided for @shippingKeySaved.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert.'**
  String get shippingKeySaved;

  /// No description provided for @shippingKeyDeleted.
  ///
  /// In de, this message translates to:
  /// **'Entfernt.'**
  String get shippingKeyDeleted;

  /// No description provided for @shippingLastChecked.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gepollt: {when}'**
  String shippingLastChecked(Object when);

  /// No description provided for @shippingLastError.
  ///
  /// In de, this message translates to:
  /// **'Letzter Fehler: {error}'**
  String shippingLastError(Object error);

  /// No description provided for @shippingLastNeverPolled.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht gepollt.'**
  String get shippingLastNeverPolled;

  /// No description provided for @shippingCarrierComingSoon.
  ///
  /// In de, this message translates to:
  /// **'Bald verfügbar'**
  String get shippingCarrierComingSoon;

  /// No description provided for @shippingSetupError.
  ///
  /// In de, this message translates to:
  /// **'Setup unvollständig: Master-Key nicht konfiguriert. Bitte Hilfe öffnen.'**
  String get shippingSetupError;

  /// No description provided for @shippingSetupHelpAction.
  ///
  /// In de, this message translates to:
  /// **'Hilfe öffnen'**
  String get shippingSetupHelpAction;

  /// No description provided for @buyersEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Käufer angelegt.'**
  String get buyersEmpty;

  /// No description provided for @buyersAdd.
  ///
  /// In de, this message translates to:
  /// **'Käufer hinzufügen'**
  String get buyersAdd;

  /// No description provided for @buyersDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Käufer löschen'**
  String get buyersDeleteTitle;

  /// No description provided for @buyersDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Käufer „{name}\" wirklich löschen?'**
  String buyersDeleteConfirm(Object name);

  /// No description provided for @shopsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Shops angelegt.'**
  String get shopsEmpty;

  /// No description provided for @shopsAdd.
  ///
  /// In de, this message translates to:
  /// **'Shop hinzufügen'**
  String get shopsAdd;

  /// No description provided for @shopsDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Shop löschen'**
  String get shopsDeleteTitle;

  /// No description provided for @shopsDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Shop „{name}\" wirklich löschen?'**
  String shopsDeleteConfirm(Object name);

  /// No description provided for @teamLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Team-Daten konnten nicht geladen werden: {error}'**
  String teamLoadFailed(Object error);

  /// No description provided for @teamMigrationHint.
  ///
  /// In de, this message translates to:
  /// **'Stelle sicher, dass die Workspace-Migration in Supabase ausgeführt wurde.'**
  String get teamMigrationHint;

  /// No description provided for @teamNoWorkspace.
  ///
  /// In de, this message translates to:
  /// **'Kein Workspace gefunden.'**
  String get teamNoWorkspace;

  /// No description provided for @teamWorkspaceSummary.
  ///
  /// In de, this message translates to:
  /// **'Workspace-ID {id} · {count} Mitglied(er)'**
  String teamWorkspaceSummary(Object id, int count);

  /// No description provided for @teamCopyId.
  ///
  /// In de, this message translates to:
  /// **'ID kopieren'**
  String get teamCopyId;

  /// No description provided for @teamCopyIdSnack.
  ///
  /// In de, this message translates to:
  /// **'Workspace-ID kopiert.'**
  String get teamCopyIdSnack;

  /// No description provided for @teamRename.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get teamRename;

  /// No description provided for @teamRenameTitle.
  ///
  /// In de, this message translates to:
  /// **'Workspace umbenennen'**
  String get teamRenameTitle;

  /// No description provided for @teamRenameLabel.
  ///
  /// In de, this message translates to:
  /// **'Alias'**
  String get teamRenameLabel;

  /// No description provided for @teamRenameHint.
  ///
  /// In de, this message translates to:
  /// **'z.B. Acme GmbH'**
  String get teamRenameHint;

  /// No description provided for @teamRenameSuccess.
  ///
  /// In de, this message translates to:
  /// **'Workspace umbenannt.'**
  String get teamRenameSuccess;

  /// No description provided for @teamRenameFailed.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen fehlgeschlagen: {error}'**
  String teamRenameFailed(Object error);

  /// No description provided for @teamMembers.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get teamMembers;

  /// No description provided for @teamInvites.
  ///
  /// In de, this message translates to:
  /// **'Offene Einladungen'**
  String get teamInvites;

  /// No description provided for @teamInvite.
  ///
  /// In de, this message translates to:
  /// **'Einladen'**
  String get teamInvite;

  /// No description provided for @teamInviteFailed.
  ///
  /// In de, this message translates to:
  /// **'Einladen fehlgeschlagen: {error}'**
  String teamInviteFailed(Object error);

  /// No description provided for @teamInviteTitle.
  ///
  /// In de, this message translates to:
  /// **'Mitglied einladen'**
  String get teamInviteTitle;

  /// No description provided for @teamInviteEmailLabel.
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse'**
  String get teamInviteEmailLabel;

  /// No description provided for @teamInviteRoleLabel.
  ///
  /// In de, this message translates to:
  /// **'Rolle'**
  String get teamInviteRoleLabel;

  /// No description provided for @teamMemberSince.
  ///
  /// In de, this message translates to:
  /// **'{role} · seit {date}'**
  String teamMemberSince(Object role, Object date);

  /// No description provided for @teamInviteExpires.
  ///
  /// In de, this message translates to:
  /// **'Rolle: {role} · läuft ab {date}'**
  String teamInviteExpires(Object role, Object date);

  /// No description provided for @teamMemberRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get teamMemberRemove;

  /// No description provided for @teamInviteRevoke.
  ///
  /// In de, this message translates to:
  /// **'Einladung zurückziehen'**
  String get teamInviteRevoke;

  /// No description provided for @teamSwitchWorkspace.
  ///
  /// In de, this message translates to:
  /// **'Workspace wechseln'**
  String get teamSwitchWorkspace;

  /// No description provided for @teamRoleOwner.
  ///
  /// In de, this message translates to:
  /// **'Owner'**
  String get teamRoleOwner;

  /// No description provided for @teamRoleAdmin.
  ///
  /// In de, this message translates to:
  /// **'Admin'**
  String get teamRoleAdmin;

  /// No description provided for @teamRoleMember.
  ///
  /// In de, this message translates to:
  /// **'Mitglied'**
  String get teamRoleMember;

  /// No description provided for @teamRoleViewer.
  ///
  /// In de, this message translates to:
  /// **'Read-only'**
  String get teamRoleViewer;

  /// No description provided for @settingsTaxRateTitle.
  ///
  /// In de, this message translates to:
  /// **'MwSt-Satz'**
  String get settingsTaxRateTitle;

  /// No description provided for @settingsTaxRateSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Standard: 19%. Neue Deals berechnen EK Brutto aktuell mit 1,19.'**
  String get settingsTaxRateSubtitle;

  /// No description provided for @settingsSortTitle.
  ///
  /// In de, this message translates to:
  /// **'Standard-Sortierung'**
  String get settingsSortTitle;

  /// No description provided for @settingsSortSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Deals werden standardmäßig nach Bestelldatum absteigend angezeigt.'**
  String get settingsSortSubtitle;

  /// No description provided for @settingsSortValue.
  ///
  /// In de, this message translates to:
  /// **'Datum ↓'**
  String get settingsSortValue;

  /// No description provided for @settingsCloudTitle.
  ///
  /// In de, this message translates to:
  /// **'Cloud-Speicher'**
  String get settingsCloudTitle;

  /// No description provided for @settingsCloudSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Daten werden in deinem Supabase-Konto gespeichert und über alle Geräte synchronisiert.'**
  String get settingsCloudSubtitle;

  /// No description provided for @settingsDataTitle.
  ///
  /// In de, this message translates to:
  /// **'Datenbestand'**
  String get settingsDataTitle;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In de, this message translates to:
  /// **'{deals} Deals · {buyers} Käufer · {shops} Shops · {items} Lagerartikel'**
  String settingsDataSubtitle(int deals, int buyers, int shops, int items);

  /// No description provided for @settingsLanguageSection.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In de, this message translates to:
  /// **'Sprache / Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Auf Deutsch oder Englisch umstellen. „System\" folgt dem Geräte-Setting.'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageDe.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageDe;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsStatsSection.
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get settingsStatsSection;

  /// No description provided for @settingsMonthlyGoalTitle.
  ///
  /// In de, this message translates to:
  /// **'Monatliches Profit-Ziel'**
  String get settingsMonthlyGoalTitle;

  /// No description provided for @settingsMonthlyGoalSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wird in der Statistik als Fortschrittsring + Forecast angezeigt.'**
  String get settingsMonthlyGoalSubtitle;

  /// No description provided for @settingsMonthlyGoalDialogTitle.
  ///
  /// In de, this message translates to:
  /// **'Profit-Ziel pro Monat'**
  String get settingsMonthlyGoalDialogTitle;

  /// No description provided for @settingsLowStockTitle.
  ///
  /// In de, this message translates to:
  /// **'Schwellwert „niedriger Bestand\"'**
  String get settingsLowStockTitle;

  /// No description provided for @settingsLowStockSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Lagerartikel unter diesem Wert werden als kritisch markiert.'**
  String get settingsLowStockSubtitle;

  /// No description provided for @settingsLowStockDialogTitle.
  ///
  /// In de, this message translates to:
  /// **'Niedriger Bestand'**
  String get settingsLowStockDialogTitle;

  /// No description provided for @settingsLowStockUnit.
  ///
  /// In de, this message translates to:
  /// **'Stück'**
  String get settingsLowStockUnit;

  /// No description provided for @settingsLowStockTrailing.
  ///
  /// In de, this message translates to:
  /// **'< {value} Stück'**
  String settingsLowStockTrailing(int value);

  /// No description provided for @pushFirebaseMissing.
  ///
  /// In de, this message translates to:
  /// **'Firebase ist auf diesem Gerät nicht eingerichtet — Einstellungen werden gespeichert, aber Push-Nachrichten werden erst nach der Firebase-Einrichtung zugestellt.'**
  String get pushFirebaseMissing;

  /// No description provided for @pushSectionTypes.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungstypen'**
  String get pushSectionTypes;

  /// No description provided for @pushMhdTitle.
  ///
  /// In de, this message translates to:
  /// **'MHD-Warnungen'**
  String get pushMhdTitle;

  /// No description provided for @pushMhdSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Charge läuft bald ab (basierend auf MHD)'**
  String get pushMhdSubtitle;

  /// No description provided for @pushMhdLeadTitle.
  ///
  /// In de, this message translates to:
  /// **'MHD-Vorwarnung'**
  String get pushMhdLeadTitle;

  /// No description provided for @pushMhdLeadSubtitle.
  ///
  /// In de, this message translates to:
  /// **'{days} Tage vor Ablauf'**
  String pushMhdLeadSubtitle(int days);

  /// No description provided for @pushMhdLeadSliderLabel.
  ///
  /// In de, this message translates to:
  /// **'{days} Tage'**
  String pushMhdLeadSliderLabel(int days);

  /// No description provided for @pushDeliveryTitle.
  ///
  /// In de, this message translates to:
  /// **'Lieferungs-Hinweise'**
  String get pushDeliveryTitle;

  /// No description provided for @pushDeliverySubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wenn ein Deal heute ankommen sollte (Status Unterwegs)'**
  String get pushDeliverySubtitle;

  /// No description provided for @pushPaymentTitle.
  ///
  /// In de, this message translates to:
  /// **'Zahlungs-Erinnerungen'**
  String get pushPaymentTitle;

  /// No description provided for @pushPaymentSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Käufer hat nach {days} Tagen noch nicht gezahlt'**
  String pushPaymentSubtitle(int days);

  /// No description provided for @pushPaymentLeadTitle.
  ///
  /// In de, this message translates to:
  /// **'Mahn-Schwelle'**
  String get pushPaymentLeadTitle;

  /// No description provided for @pushPaymentLeadSubtitle.
  ///
  /// In de, this message translates to:
  /// **'{days} Tage'**
  String pushPaymentLeadSubtitle(int days);

  /// No description provided for @pushSectionInfo.
  ///
  /// In de, this message translates to:
  /// **'Hinweise'**
  String get pushSectionInfo;

  /// No description provided for @pushDailyCheckTitle.
  ///
  /// In de, this message translates to:
  /// **'Tägliche Prüfung'**
  String get pushDailyCheckTitle;

  /// No description provided for @pushDailyCheckSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Server prüft täglich um 09:00 Uhr (Europe/Berlin) und versendet fällige Nachrichten.'**
  String get pushDailyCheckSubtitle;

  /// No description provided for @pushDedupTitle.
  ///
  /// In de, this message translates to:
  /// **'Dedup'**
  String get pushDedupTitle;

  /// No description provided for @pushDedupSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Jede Warnung wird pro Charge/Deal nur einmal versendet — auch über mehrere Geräte hinweg.'**
  String get pushDedupSubtitle;

  /// No description provided for @pushSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen: {error}'**
  String pushSaveFailed(Object error);

  /// No description provided for @dealNew.
  ///
  /// In de, this message translates to:
  /// **'Neuer Deal'**
  String get dealNew;

  /// No description provided for @dealEdit.
  ///
  /// In de, this message translates to:
  /// **'Deal bearbeiten'**
  String get dealEdit;

  /// No description provided for @dealOrderDate.
  ///
  /// In de, this message translates to:
  /// **'Bestelldatum'**
  String get dealOrderDate;

  /// No description provided for @dealArrivalDate.
  ///
  /// In de, this message translates to:
  /// **'Ankunftsdatum'**
  String get dealArrivalDate;

  /// No description provided for @dealProduct.
  ///
  /// In de, this message translates to:
  /// **'Produkt'**
  String get dealProduct;

  /// No description provided for @dealShop.
  ///
  /// In de, this message translates to:
  /// **'Shop'**
  String get dealShop;

  /// No description provided for @dealQuantity.
  ///
  /// In de, this message translates to:
  /// **'Anzahl'**
  String get dealQuantity;

  /// No description provided for @dealQuantityShort.
  ///
  /// In de, this message translates to:
  /// **'Anz.'**
  String get dealQuantityShort;

  /// No description provided for @dealShippingType.
  ///
  /// In de, this message translates to:
  /// **'Versandtyp'**
  String get dealShippingType;

  /// No description provided for @dealReship.
  ///
  /// In de, this message translates to:
  /// **'Reship'**
  String get dealReship;

  /// No description provided for @dealDropship.
  ///
  /// In de, this message translates to:
  /// **'Dropship'**
  String get dealDropship;

  /// No description provided for @dealReceipt.
  ///
  /// In de, this message translates to:
  /// **'Beleg'**
  String get dealReceipt;

  /// No description provided for @dealReceiptYes.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get dealReceiptYes;

  /// No description provided for @dealReceiptNo.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get dealReceiptNo;

  /// No description provided for @dealStatus.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get dealStatus;

  /// No description provided for @dealNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get dealNote;

  /// No description provided for @dealComments.
  ///
  /// In de, this message translates to:
  /// **'Kommentare'**
  String get dealComments;

  /// No description provided for @dealCommentPlaceholder.
  ///
  /// In de, this message translates to:
  /// **'Notiz oder Kommentar hinzufügen…'**
  String get dealCommentPlaceholder;

  /// No description provided for @dealCommentSend.
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get dealCommentSend;

  /// No description provided for @dealCommentEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Kommentare.'**
  String get dealCommentEmpty;

  /// No description provided for @dealCommentLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Konnte Kommentare nicht laden: {error}'**
  String dealCommentLoadFailed(Object error);

  /// No description provided for @dealCommentSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen: {error}'**
  String dealCommentSaveFailed(Object error);

  /// No description provided for @dealCommentDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Kommentar löschen?'**
  String get dealCommentDeleteTitle;

  /// No description provided for @dealCommentDeleteText.
  ///
  /// In de, this message translates to:
  /// **'Dieser Kommentar wird unwiderruflich entfernt.'**
  String get dealCommentDeleteText;

  /// No description provided for @dealCommentDeleteFailed.
  ///
  /// In de, this message translates to:
  /// **'Löschen fehlgeschlagen: {error}'**
  String dealCommentDeleteFailed(Object error);

  /// No description provided for @dealSectionProduct.
  ///
  /// In de, this message translates to:
  /// **'Produkt & Versand'**
  String get dealSectionProduct;

  /// No description provided for @dealSectionPrices.
  ///
  /// In de, this message translates to:
  /// **'Preise'**
  String get dealSectionPrices;

  /// No description provided for @dealSectionBuyer.
  ///
  /// In de, this message translates to:
  /// **'Käufer & Status'**
  String get dealSectionBuyer;

  /// No description provided for @dealSectionDateTracking.
  ///
  /// In de, this message translates to:
  /// **'Datum & Tracking'**
  String get dealSectionDateTracking;

  /// No description provided for @dealSectionAttachments.
  ///
  /// In de, this message translates to:
  /// **'Anhänge'**
  String get dealSectionAttachments;

  /// No description provided for @dealSectionNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get dealSectionNote;

  /// No description provided for @dealEkPriceLabel.
  ///
  /// In de, this message translates to:
  /// **'EK Preis als:'**
  String get dealEkPriceLabel;

  /// No description provided for @dealPriceTypeNet.
  ///
  /// In de, this message translates to:
  /// **'Netto'**
  String get dealPriceTypeNet;

  /// No description provided for @dealPriceTypeGross.
  ///
  /// In de, this message translates to:
  /// **'Brutto'**
  String get dealPriceTypeGross;

  /// No description provided for @dealEkAmount.
  ///
  /// In de, this message translates to:
  /// **'EK-Betrag'**
  String get dealEkAmount;

  /// No description provided for @dealVkAmount.
  ///
  /// In de, this message translates to:
  /// **'VK-Betrag'**
  String get dealVkAmount;

  /// No description provided for @dealCurrency.
  ///
  /// In de, this message translates to:
  /// **'Währung'**
  String get dealCurrency;

  /// No description provided for @dealTaxRate.
  ///
  /// In de, this message translates to:
  /// **'MwSt-Satz %'**
  String get dealTaxRate;

  /// No description provided for @dealTaxRateHint.
  ///
  /// In de, this message translates to:
  /// **'z.B. 19'**
  String get dealTaxRateHint;

  /// No description provided for @dealTaxRateInvalid.
  ///
  /// In de, this message translates to:
  /// **'Ungültige Zahl'**
  String get dealTaxRateInvalid;

  /// No description provided for @dealTaxRateRange.
  ///
  /// In de, this message translates to:
  /// **'0 – 100'**
  String get dealTaxRateRange;

  /// No description provided for @dealBuyer.
  ///
  /// In de, this message translates to:
  /// **'Käufer'**
  String get dealBuyer;

  /// No description provided for @dealBuyerNone.
  ///
  /// In de, this message translates to:
  /// **'— Kein —'**
  String get dealBuyerNone;

  /// No description provided for @dealTicketNumber.
  ///
  /// In de, this message translates to:
  /// **'Ticketnummer'**
  String get dealTicketNumber;

  /// No description provided for @dealTracking.
  ///
  /// In de, this message translates to:
  /// **'Tracking'**
  String get dealTracking;

  /// No description provided for @dealTicketUrl.
  ///
  /// In de, this message translates to:
  /// **'Ticket-URL (optional)'**
  String get dealTicketUrl;

  /// No description provided for @dealTicketUrlHint.
  ///
  /// In de, this message translates to:
  /// **'Link aus Discord einfügen…'**
  String get dealTicketUrlHint;

  /// No description provided for @dealDiscordChannelHint.
  ///
  /// In de, this message translates to:
  /// **'Kanal finden → Rechtsklick → „Link kopieren\" → hier einfügen'**
  String get dealDiscordChannelHint;

  /// No description provided for @dealDiscordTicketOpen.
  ///
  /// In de, this message translates to:
  /// **'Ticket in Discord öffnen'**
  String get dealDiscordTicketOpen;

  /// No description provided for @dealDiscordServerOpen.
  ///
  /// In de, this message translates to:
  /// **'Server {n} in Discord öffnen'**
  String dealDiscordServerOpen(int n);

  /// No description provided for @dealProfitPreviewMissing.
  ///
  /// In de, this message translates to:
  /// **'Profit-Vorschau: EK und VK eintragen'**
  String get dealProfitPreviewMissing;

  /// No description provided for @dealProfitPreviewLine.
  ///
  /// In de, this message translates to:
  /// **'Profit/Stück {perUnit} · Gesamt {total}'**
  String dealProfitPreviewLine(Object perUnit, Object total);

  /// No description provided for @dealStatusOrdered.
  ///
  /// In de, this message translates to:
  /// **'Bestellt'**
  String get dealStatusOrdered;

  /// No description provided for @dealStatusShipping.
  ///
  /// In de, this message translates to:
  /// **'Unterwegs'**
  String get dealStatusShipping;

  /// No description provided for @dealStatusArrived.
  ///
  /// In de, this message translates to:
  /// **'Angekommen'**
  String get dealStatusArrived;

  /// No description provided for @dealStatusInvoiced.
  ///
  /// In de, this message translates to:
  /// **'Rechnung gestellt'**
  String get dealStatusInvoiced;

  /// No description provided for @dealStatusDone.
  ///
  /// In de, this message translates to:
  /// **'Done'**
  String get dealStatusDone;

  /// No description provided for @dealQuickStatusTitle.
  ///
  /// In de, this message translates to:
  /// **'Status ändern'**
  String get dealQuickStatusTitle;

  /// No description provided for @dealQuickStatusUndo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get dealQuickStatusUndo;

  /// No description provided for @dealQuickStatusChanged.
  ///
  /// In de, this message translates to:
  /// **'Status auf {status} geändert'**
  String dealQuickStatusChanged(String status);

  /// No description provided for @dealQuickStatusError.
  ///
  /// In de, this message translates to:
  /// **'Status konnte nicht geändert werden: {error}'**
  String dealQuickStatusError(String error);

  /// No description provided for @dealColId.
  ///
  /// In de, this message translates to:
  /// **'ID'**
  String get dealColId;

  /// No description provided for @dealColEkNet.
  ///
  /// In de, this message translates to:
  /// **'EK Netto'**
  String get dealColEkNet;

  /// No description provided for @dealColEkGross.
  ///
  /// In de, this message translates to:
  /// **'EK Brutto'**
  String get dealColEkGross;

  /// No description provided for @dealColVk.
  ///
  /// In de, this message translates to:
  /// **'VK'**
  String get dealColVk;

  /// No description provided for @dealColArrival.
  ///
  /// In de, this message translates to:
  /// **'Ankunft'**
  String get dealColArrival;

  /// No description provided for @dealColTicket.
  ///
  /// In de, this message translates to:
  /// **'Ticket'**
  String get dealColTicket;

  /// No description provided for @dealColProfitUnit.
  ///
  /// In de, this message translates to:
  /// **'Profit/Stk'**
  String get dealColProfitUnit;

  /// No description provided for @dealColProfitTotal.
  ///
  /// In de, this message translates to:
  /// **'Ges. Profit'**
  String get dealColProfitTotal;

  /// No description provided for @dealColReceivable.
  ///
  /// In de, this message translates to:
  /// **'Zu bekommen'**
  String get dealColReceivable;

  /// No description provided for @dealsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Deals gefunden'**
  String get dealsEmpty;

  /// No description provided for @dealsEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Filter anpassen oder einen neuen Deal anlegen.'**
  String get dealsEmptyHint;

  /// No description provided for @dealsSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Produkt, Ticket, Tracking, Notiz'**
  String get dealsSearchHint;

  /// No description provided for @dealsFilterDate.
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get dealsFilterDate;

  /// No description provided for @dealsFilterReset.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get dealsFilterReset;

  /// No description provided for @dealDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Eintrag löschen'**
  String get dealDeleteTitle;

  /// No description provided for @dealDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'„{product}\" (ID: {id}) wirklich löschen?'**
  String dealDeleteConfirm(Object product, int id);

  /// No description provided for @bulkStatus.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get bulkStatus;

  /// No description provided for @bulkBuyer.
  ///
  /// In de, this message translates to:
  /// **'Käufer'**
  String get bulkBuyer;

  /// No description provided for @bulkBuyerNone.
  ///
  /// In de, this message translates to:
  /// **'Kein Käufer'**
  String get bulkBuyerNone;

  /// No description provided for @bulkChangeStatusTooltip.
  ///
  /// In de, this message translates to:
  /// **'Status ändern'**
  String get bulkChangeStatusTooltip;

  /// No description provided for @bulkAssignBuyerTooltip.
  ///
  /// In de, this message translates to:
  /// **'Käufer zuweisen'**
  String get bulkAssignBuyerTooltip;

  /// No description provided for @checkInDealTitle.
  ///
  /// In de, this message translates to:
  /// **'Artikel ins Lager einbuchen?'**
  String get checkInDealTitle;

  /// No description provided for @checkInDealText.
  ///
  /// In de, this message translates to:
  /// **'{quantity}x {product} als Lagerartikel anlegen.'**
  String checkInDealText(int quantity, Object product);

  /// No description provided for @checkInButton.
  ///
  /// In de, this message translates to:
  /// **'Einbuchen'**
  String get checkInButton;

  /// No description provided for @checkInNo.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get checkInNo;

  /// No description provided for @inventoryStatusInStock.
  ///
  /// In de, this message translates to:
  /// **'Im Lager'**
  String get inventoryStatusInStock;

  /// No description provided for @inventoryStatusReserved.
  ///
  /// In de, this message translates to:
  /// **'Reserviert'**
  String get inventoryStatusReserved;

  /// No description provided for @inventoryStatusShipped.
  ///
  /// In de, this message translates to:
  /// **'Versandt'**
  String get inventoryStatusShipped;

  /// No description provided for @inventoryStatusSold.
  ///
  /// In de, this message translates to:
  /// **'Verkauft'**
  String get inventoryStatusSold;

  /// No description provided for @helpTitle.
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get helpTitle;

  /// No description provided for @helpQuickStart.
  ///
  /// In de, this message translates to:
  /// **'Schnellstart'**
  String get helpQuickStart;

  /// No description provided for @helpStepShopsBuyersTitle.
  ///
  /// In de, this message translates to:
  /// **'Shops & Käufer anlegen'**
  String get helpStepShopsBuyersTitle;

  /// No description provided for @helpStepShopsBuyersDesc.
  ///
  /// In de, this message translates to:
  /// **'Lege in den Einstellungen deine Bezugsquellen und Käufer an. Beides ist später Pflichtfeld beim Deal.'**
  String get helpStepShopsBuyersDesc;

  /// No description provided for @helpStepFirstDealTitle.
  ///
  /// In de, this message translates to:
  /// **'Ersten Deal eintragen'**
  String get helpStepFirstDealTitle;

  /// No description provided for @helpStepFirstDealDesc.
  ///
  /// In de, this message translates to:
  /// **'Tippe unten auf „Neuer Deal\". Das Produktfeld schlägt vorherige Produkte vor, sobald du tippst.'**
  String get helpStepFirstDealDesc;

  /// No description provided for @helpStepStatsTitle.
  ///
  /// In de, this message translates to:
  /// **'Statistik & Ziele'**
  String get helpStepStatsTitle;

  /// No description provided for @helpStepStatsDesc.
  ///
  /// In de, this message translates to:
  /// **'Im Tab „Statistiken\" siehst du Cashflow, Profit und MwSt-Quartale. Setze in den Einstellungen ein monatliches Profit-Ziel.'**
  String get helpStepStatsDesc;

  /// No description provided for @helpDiscordSection.
  ///
  /// In de, this message translates to:
  /// **'Discord-Integration'**
  String get helpDiscordSection;

  /// No description provided for @helpDiscordHowTitle.
  ///
  /// In de, this message translates to:
  /// **'So funktioniert die Verknüpfung'**
  String get helpDiscordHowTitle;

  /// No description provided for @helpDiscordHowDesc.
  ///
  /// In de, this message translates to:
  /// **'Trage beim Deal die Ticketnummer ein — die App zeigt dann Buttons zum direkten Öffnen der konfigurierten Discord-Server. Kanal finden, Link kopieren, in „Ticket-URL\" einfügen.'**
  String get helpDiscordHowDesc;

  /// No description provided for @helpDiscordStep1Title.
  ///
  /// In de, this message translates to:
  /// **'Entwicklermodus aktivieren'**
  String get helpDiscordStep1Title;

  /// No description provided for @helpDiscordStep1Desc.
  ///
  /// In de, this message translates to:
  /// **'Discord → Einstellungen → Erweitert → Entwicklermodus einschalten.'**
  String get helpDiscordStep1Desc;

  /// No description provided for @helpDiscordStep2Title.
  ///
  /// In de, this message translates to:
  /// **'Server-ID kopieren'**
  String get helpDiscordStep2Title;

  /// No description provided for @helpDiscordStep2Desc.
  ///
  /// In de, this message translates to:
  /// **'Rechtsklick auf den Servernamen → „Server-ID kopieren\".'**
  String get helpDiscordStep2Desc;

  /// No description provided for @helpDiscordStep3Title.
  ///
  /// In de, this message translates to:
  /// **'Server-ID beim Käufer hinterlegen'**
  String get helpDiscordStep3Title;

  /// No description provided for @helpDiscordStep3Desc.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen → Käufer-Tab → Käufer bearbeiten → Discord Server IDs.'**
  String get helpDiscordStep3Desc;

  /// No description provided for @helpDiscordConfiguredIds.
  ///
  /// In de, this message translates to:
  /// **'Konfigurierte Server-IDs'**
  String get helpDiscordConfiguredIds;

  /// No description provided for @helpDiscordNoBuyers.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Käufer angelegt'**
  String get helpDiscordNoBuyers;

  /// No description provided for @helpDiscordNoBuyersDesc.
  ///
  /// In de, this message translates to:
  /// **'Lege in den Einstellungen Käufer an, um Server-IDs zu hinterlegen.'**
  String get helpDiscordNoBuyersDesc;

  /// No description provided for @helpDiscordNoServerIds.
  ///
  /// In de, this message translates to:
  /// **'Keine Server-IDs konfiguriert'**
  String get helpDiscordNoServerIds;

  /// No description provided for @helpContactSection.
  ///
  /// In de, this message translates to:
  /// **'Kontakt & Feedback'**
  String get helpContactSection;

  /// No description provided for @helpContactReportTitle.
  ///
  /// In de, this message translates to:
  /// **'Probleme melden'**
  String get helpContactReportTitle;

  /// No description provided for @helpContactReportDesc.
  ///
  /// In de, this message translates to:
  /// **'Beschreibe das Problem so genau wie möglich. Screenshots helfen.'**
  String get helpContactReportDesc;

  /// No description provided for @helpSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Hilfe durchsuchen…'**
  String get helpSearchHint;

  /// No description provided for @helpSearchEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Nichts gefunden'**
  String get helpSearchEmptyTitle;

  /// No description provided for @helpSearchEmptyDesc.
  ///
  /// In de, this message translates to:
  /// **'Versuche andere Begriffe, prüfe die Schreibweise oder lösche das Suchfeld, um alle Sektionen zu sehen.'**
  String get helpSearchEmptyDesc;

  /// No description provided for @helpExpandAll.
  ///
  /// In de, this message translates to:
  /// **'Alle ausklappen'**
  String get helpExpandAll;

  /// No description provided for @helpCollapseAll.
  ///
  /// In de, this message translates to:
  /// **'Alle einklappen'**
  String get helpCollapseAll;

  /// No description provided for @helpResultsLabel.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Treffer} =1{1 Sektion gefunden} other{{count} Sektionen gefunden}}'**
  String helpResultsLabel(int count);

  /// No description provided for @helpEntryWord.
  ///
  /// In de, this message translates to:
  /// **'Eintrag'**
  String get helpEntryWord;

  /// No description provided for @helpEntriesWord.
  ///
  /// In de, this message translates to:
  /// **'Einträge'**
  String get helpEntriesWord;

  /// No description provided for @helpStepLoginTitle.
  ///
  /// In de, this message translates to:
  /// **'Konto anlegen & einloggen'**
  String get helpStepLoginTitle;

  /// No description provided for @helpStepLoginDesc.
  ///
  /// In de, this message translates to:
  /// **'Registriere dich mit E-Mail oder logge dich per Google/Apple ein. Bestätige bei Bedarf deine E-Mail über den zugesandten Link, dann kannst du sofort starten.'**
  String get helpStepLoginDesc;

  /// No description provided for @helpStepWorkspaceTitle.
  ///
  /// In de, this message translates to:
  /// **'Workspace einrichten'**
  String get helpStepWorkspaceTitle;

  /// No description provided for @helpStepWorkspaceDesc.
  ///
  /// In de, this message translates to:
  /// **'Beim ersten Login wird automatisch ein Workspace für dich angelegt. Über das Workspace-Menü oben rechts kannst du weitere Workspaces erstellen oder Mitglieder einladen.'**
  String get helpStepWorkspaceDesc;

  /// No description provided for @helpStepInboxTitle.
  ///
  /// In de, this message translates to:
  /// **'Postfach verbinden'**
  String get helpStepInboxTitle;

  /// No description provided for @helpStepInboxDesc.
  ///
  /// In de, this message translates to:
  /// **'Hänge dein Bestell-Postfach (Gmail/Outlook/IONOS) unter Einstellungen → Postfach an. Bestellbestätigungen, Versand- und Liefermails werden danach automatisch erkannt.'**
  String get helpStepInboxDesc;

  /// No description provided for @helpStepInventoryTitle.
  ///
  /// In de, this message translates to:
  /// **'Lagerbestand pflegen'**
  String get helpStepInventoryTitle;

  /// No description provided for @helpStepInventoryDesc.
  ///
  /// In de, this message translates to:
  /// **'Lege im Lager-Tab Artikel mit Stückzahl und Mindestbestand an. Verkaufte Stück verschwinden automatisch aus dem Bestand und tauchen im „Verkauft\"-Tab auf.'**
  String get helpStepInventoryDesc;

  /// No description provided for @helpInboxSection.
  ///
  /// In de, this message translates to:
  /// **'Postfach (E-Mail-Import)'**
  String get helpInboxSection;

  /// No description provided for @helpInboxIntro.
  ///
  /// In de, this message translates to:
  /// **'Die App liest dein Mail-Postfach via IMAP, erkennt Bestellbestätigungen und Versandmails und schlägt sie als Deals vor. Es werden keine Mails verschickt.'**
  String get helpInboxIntro;

  /// No description provided for @helpInboxGmailTitle.
  ///
  /// In de, this message translates to:
  /// **'Gmail / Google Workspace verbinden'**
  String get helpInboxGmailTitle;

  /// No description provided for @helpInboxGmailDesc.
  ///
  /// In de, this message translates to:
  /// **'Gmail erlaubt keinen Login mit deinem normalen Passwort. Du brauchst ein App-Passwort:\n• Aktiviere die 2-Faktor-Authentifizierung unter myaccount.google.com → Sicherheit.\n• Öffne myaccount.google.com/apppasswords, vergib einen Namen (z. B. „Lager-App\") und kopiere das 16-stellige App-Passwort.\n• In der App: Einstellungen → Postfach → IMAP-Server „imap.gmail.com\", Port 993, SSL, Benutzername = deine Mail, Passwort = das App-Passwort.'**
  String get helpInboxGmailDesc;

  /// No description provided for @helpInboxOutlookTitle.
  ///
  /// In de, this message translates to:
  /// **'Outlook.com / Microsoft 365 verbinden'**
  String get helpInboxOutlookTitle;

  /// No description provided for @helpInboxOutlookDesc.
  ///
  /// In de, this message translates to:
  /// **'Outlook und Microsoft 365 nutzen ebenfalls App-Passwörter:\n• Logge dich in account.microsoft.com ein → Sicherheit → Erweiterte Sicherheitsoptionen → App-Passwort erstellen.\n• In der App: IMAP-Server „outlook.office365.com\", Port 993, SSL, Benutzername = deine Mail, Passwort = App-Passwort.\n• Hinweis: Schul-/Geschäftskonten erfordern oft eine Freigabe durch den Admin.'**
  String get helpInboxOutlookDesc;

  /// No description provided for @helpInboxIonosTitle.
  ///
  /// In de, this message translates to:
  /// **'IONOS / 1&1 verbinden'**
  String get helpInboxIonosTitle;

  /// No description provided for @helpInboxIonosDesc.
  ///
  /// In de, this message translates to:
  /// **'Bei IONOS funktioniert der normale Mail-Login direkt:\n• IMAP-Server „imap.ionos.de\" (oder „.com\" je nach Region), Port 993, SSL.\n• Benutzername = vollständige Mail-Adresse, Passwort = dein Postfach-Passwort.\n• Falls Login scheitert: in der IONOS-Webmail unter „Einstellungen → Sicherheit\" prüfen, ob IMAP aktiviert ist.'**
  String get helpInboxIonosDesc;

  /// No description provided for @helpInboxTabsTitle.
  ///
  /// In de, this message translates to:
  /// **'Die drei Inbox-Tabs'**
  String get helpInboxTabsTitle;

  /// No description provided for @helpInboxTabsDesc.
  ///
  /// In de, this message translates to:
  /// **'Eingehende Mails landen in drei Tabs, je nachdem wie eindeutig die App sie zuordnen kann.'**
  String get helpInboxTabsDesc;

  /// No description provided for @helpInboxTabSuggestions.
  ///
  /// In de, this message translates to:
  /// **'Vorschläge — Bestellbestätigungen, die noch nicht zu einem Deal gehören. Tippe auf eine Mail, prüfe die erkannten Daten und übernimm sie als neuen Deal.'**
  String get helpInboxTabSuggestions;

  /// No description provided for @helpInboxTabUpdated.
  ///
  /// In de, this message translates to:
  /// **'Aktualisiert — Mails, die einen bestehenden Deal verändern (z. B. Versand-Update, Stornierung). Hier siehst du, was die Pipeline automatisch eingespielt hat.'**
  String get helpInboxTabUpdated;

  /// No description provided for @helpInboxTabUnclassified.
  ///
  /// In de, this message translates to:
  /// **'Unklassifiziert — Mails, die nicht eindeutig zugeordnet werden konnten. Du kannst sie manuell einem Deal zuweisen oder als irrelevant markieren.'**
  String get helpInboxTabUnclassified;

  /// No description provided for @helpInboxWhitelistTitle.
  ///
  /// In de, this message translates to:
  /// **'Warum sehe ich manche Mails nicht?'**
  String get helpInboxWhitelistTitle;

  /// No description provided for @helpInboxWhitelistDesc.
  ///
  /// In de, this message translates to:
  /// **'Die App liest nur Mails von bekannten Shops/Carriern (Whitelist). Werbe-Newsletter, persönliche Mails und unbekannte Absender werden ignoriert. Wenn ein Shop fehlt, melde ihn über „Probleme melden\" — neue Adapter werden serverseitig nachgepflegt.'**
  String get helpInboxWhitelistDesc;

  /// No description provided for @helpDealsSection.
  ///
  /// In de, this message translates to:
  /// **'Deals'**
  String get helpDealsSection;

  /// No description provided for @helpDealsStatusFlow.
  ///
  /// In de, this message translates to:
  /// **'Jeder Deal durchläuft fünf Status — du kannst ihn manuell weiterschalten oder die Mail-Pipeline macht es automatisch.'**
  String get helpDealsStatusFlow;

  /// No description provided for @helpDealsStatusOrdered.
  ///
  /// In de, this message translates to:
  /// **'Bestellt — der Deal ist angelegt, aber noch nicht versandt. Setze diesen Status, sobald du die Bestellung getätigt hast.'**
  String get helpDealsStatusOrdered;

  /// No description provided for @helpDealsStatusInTransit.
  ///
  /// In de, this message translates to:
  /// **'Unterwegs — Versandbestätigung erkannt oder manuell gesetzt. Tracking-Nummer wird alle paar Stunden gepollt.'**
  String get helpDealsStatusInTransit;

  /// No description provided for @helpDealsStatusArrived.
  ///
  /// In de, this message translates to:
  /// **'Angekommen — Carrier meldet Zustellung beim Absender (dir). Der Artikel ist bereit zum Listen/Versenden.'**
  String get helpDealsStatusArrived;

  /// No description provided for @helpDealsStatusSold.
  ///
  /// In de, this message translates to:
  /// **'Verkauft — Käufer steht fest, Verkaufspreis ist erfasst. Der Deal zählt jetzt in die Statistiken.'**
  String get helpDealsStatusSold;

  /// No description provided for @helpDealsStatusDelivered.
  ///
  /// In de, this message translates to:
  /// **'Geliefert — Endkunde hat den Artikel erhalten. Letzter Status, Deal ist abgeschlossen.'**
  String get helpDealsStatusDelivered;

  /// No description provided for @helpDealsTrackingTitle.
  ///
  /// In de, this message translates to:
  /// **'Auto-Tracking aus Mails'**
  String get helpDealsTrackingTitle;

  /// No description provided for @helpDealsTrackingDesc.
  ///
  /// In de, this message translates to:
  /// **'Wenn eine Versandmail mit einer DHL-Tracking-Nummer eintrifft, fragt die App die DHL-API direkt an: nur wenn DHL die Nummer bestätigt, wird der Deal automatisch auf „Unterwegs\" gesetzt. Sobald DHL die Zustellung meldet, springt der Deal auf „Angekommen\". Andere Carrier (DPD, UPS, Hermes, Amazon Logistics, GLS) werden nicht mehr aus Mails erkannt — Tracking-Nummern dort manuell im Deal eintragen. Details siehe Sektion „Versand & Carrier-API-Keys\".'**
  String get helpDealsTrackingDesc;

  /// No description provided for @helpDealsDropShipTitle.
  ///
  /// In de, this message translates to:
  /// **'Multi-Drop-Ship'**
  String get helpDealsDropShipTitle;

  /// No description provided for @helpDealsDropShipDesc.
  ///
  /// In de, this message translates to:
  /// **'Wenn ein Deal aus mehreren Shops besteht (Drop-Ship), kannst du beim Anlegen mehrere Bezugsquellen samt Einkaufspreisen hinterlegen. Der Profit wird über alle Quellen summiert. Die Statistik zählt den Deal als einen Verkauf.'**
  String get helpDealsDropShipDesc;

  /// No description provided for @helpDealsRetrackTitle.
  ///
  /// In de, this message translates to:
  /// **'Sendungsstatus sofort aktualisieren (Retrack)'**
  String get helpDealsRetrackTitle;

  /// No description provided for @helpDealsRetrackDesc.
  ///
  /// In de, this message translates to:
  /// **'Im Deal-Detail neben der Sendungsnummer gibt es ein Refresh-Icon „Status aktualisieren\". Damit fragst du den Carrier sofort nach dem aktuellen Status, ohne auf den nächsten automatischen Poll zu warten — praktisch z. B. kurz vor einem geplanten Versand.\nEin Retrack pro Deal ist alle 30 Sekunden möglich. Während der Sperre ist der Button ausgegraut und zeigt „Bitte 30s warten\" — das schützt den Carrier vor unnötigen API-Calls und dich vor Rate-Limits.'**
  String get helpDealsRetrackDesc;

  /// No description provided for @helpShippingSection.
  ///
  /// In de, this message translates to:
  /// **'Versand & Carrier-API-Keys'**
  String get helpShippingSection;

  /// No description provided for @helpShippingIntroTitle.
  ///
  /// In de, this message translates to:
  /// **'Wozu Carrier-API-Keys?'**
  String get helpShippingIntroTitle;

  /// No description provided for @helpShippingIntroDesc.
  ///
  /// In de, this message translates to:
  /// **'Damit die App den Live-Status deiner Sendungen direkt beim Versanddienstleister abfragen kann (statt nur aus Mails zu lesen), hinterlegst du pro Carrier einen API-Key unter Einstellungen → Versand. Pro Workspace ist ein Key je Carrier nötig — alle Mitglieder profitieren davon.'**
  String get helpShippingIntroDesc;

  /// No description provided for @helpShippingDhlTitle.
  ///
  /// In de, this message translates to:
  /// **'DHL — aktiv unterstützt'**
  String get helpShippingDhlTitle;

  /// No description provided for @helpShippingDhlDesc.
  ///
  /// In de, this message translates to:
  /// **'DHL kannst du sofort anbinden:\n• Account auf developer.dhl.com anlegen (kostenlos).\n• Dort die API „Shipment Tracking - Unified\" abonnieren — Free-Tier reicht für privaten Gebrauch.\n• Den API-Key kopieren und unter Einstellungen → Versand → DHL → „API-Key hinterlegen\" einfügen.\n• Direkt danach einmal Einstellungen → „Sendungsnummern neu prüfen\" tippen, damit deine bestehenden Mails von der neuen DHL-API-Pipeline geparst werden.\nAb sofort werden Deals mit DHL-Trackingnummer in regelmäßigen Abständen aktualisiert und der Status (unterwegs, in Zustellung, zugestellt) erscheint direkt im Deal.'**
  String get helpShippingDhlDesc;

  /// No description provided for @helpShippingApiOnlyTitle.
  ///
  /// In de, this message translates to:
  /// **'Warum DHL-API statt Mail-Heuristik?'**
  String get helpShippingApiOnlyTitle;

  /// No description provided for @helpShippingApiOnlyDesc.
  ///
  /// In de, this message translates to:
  /// **'Bis vor kurzem hat die App Tracking-Nummern aus Mails mit Regex-Patterns erkannt. Resultat: pro Mail oft mehrere Kandidaten, von denen nur eine echt war (Bestell-Nr, Kunden-Nr, Rechnung-Nr — alle 12-stellige Zahlen sehen wie Tracking aus). Jetzt fragt die App bei jedem Kandidaten direkt die DHL-API: liefert sie ein Shipment zurück → echte Tracking-Nummer wird übernommen, sonst verworfen. Du siehst maximal eine Pill pro Mail, und sie ist immer real.'**
  String get helpShippingApiOnlyDesc;

  /// No description provided for @helpShippingComingSoonTitle.
  ///
  /// In de, this message translates to:
  /// **'DPD, UPS, Hermes, Amazon Logistics — bald oder nie'**
  String get helpShippingComingSoonTitle;

  /// No description provided for @helpShippingComingSoonDesc.
  ///
  /// In de, this message translates to:
  /// **'Aktuell läuft die automatische Tracking-Erkennung ausschließlich über die DHL-API. Andere Carrier (DPD, UPS, Hermes, Amazon Logistics, GLS) werden nicht mehr aus Versandmails geraten — das war die Hauptquelle der Falsch-Positive. DPD und UPS bekommen ihre eigene API-Anbindung in einem späteren Update. Hermes und Amazon Logistics bieten keine öffentliche Tracking-API — dort musst du die Tracking-Nummer manuell im Deal eintragen.'**
  String get helpShippingComingSoonDesc;

  /// No description provided for @helpShippingKeySafetyTitle.
  ///
  /// In de, this message translates to:
  /// **'Was passiert mit meinem API-Key?'**
  String get helpShippingKeySafetyTitle;

  /// No description provided for @helpShippingKeySafetyDesc.
  ///
  /// In de, this message translates to:
  /// **'Der Klartext-Key verlässt dein Gerät nur einmal, beim Speichern, und wird serverseitig in der Datenbank verschlüsselt abgelegt. In der App siehst du danach nur noch die letzten vier Zeichen, z. B. „••••••••a1b2\". Du kannst den Key jederzeit ersetzen oder löschen — beim Löschen pausieren wir die automatischen Status-Abfragen für diesen Carrier.'**
  String get helpShippingKeySafetyDesc;

  /// No description provided for @helpInventorySection.
  ///
  /// In de, this message translates to:
  /// **'Lager (Inventory)'**
  String get helpInventorySection;

  /// No description provided for @helpInventoryAddTitle.
  ///
  /// In de, this message translates to:
  /// **'Artikel anlegen'**
  String get helpInventoryAddTitle;

  /// No description provided for @helpInventoryAddDesc.
  ///
  /// In de, this message translates to:
  /// **'Lager-Tab → „Artikel hinzufügen\". Pflicht: Name + Stückzahl. Optional: Einkaufspreis, Mindestbestand, Verkaufskanal, Foto. Mehrfach-Stück desselben Artikels: Stückzahl erhöhen statt neu anlegen.'**
  String get helpInventoryAddDesc;

  /// No description provided for @helpInventoryStockTitle.
  ///
  /// In de, this message translates to:
  /// **'Stückzahlen aktualisieren'**
  String get helpInventoryStockTitle;

  /// No description provided for @helpInventoryStockDesc.
  ///
  /// In de, this message translates to:
  /// **'Tippe einen Artikel an und nutze die +/- Buttons, oder bearbeite das Mengenfeld direkt. Beim Verkauf wird die Stückzahl automatisch um 1 reduziert, wenn du den Artikel im Deal-Form auswählst.'**
  String get helpInventoryStockDesc;

  /// No description provided for @helpInventoryMinStockTitle.
  ///
  /// In de, this message translates to:
  /// **'Mindestbestand & Warnungen'**
  String get helpInventoryMinStockTitle;

  /// No description provided for @helpInventoryMinStockDesc.
  ///
  /// In de, this message translates to:
  /// **'Setze einen Mindestbestand pro Artikel (z. B. 2). Sobald die Stückzahl darunter fällt, erscheint im Dashboard und im Lager-Tab eine gelbe Warnung — und optional eine Push-Notification.'**
  String get helpInventoryMinStockDesc;

  /// No description provided for @helpInventorySoldTabTitle.
  ///
  /// In de, this message translates to:
  /// **'Verkauft-Tab'**
  String get helpInventorySoldTabTitle;

  /// No description provided for @helpInventorySoldTabDesc.
  ///
  /// In de, this message translates to:
  /// **'Verkaufte Artikel verschwinden aus dem Bestand und tauchen im Tab „Verkauft\" auf. Dort siehst du Käufer, Verkaufspreis und Profit pro Stück. Filterbar nach Datum und Käufer.'**
  String get helpInventorySoldTabDesc;

  /// No description provided for @helpInventoryStockValueTitle.
  ///
  /// In de, this message translates to:
  /// **'Lagerwert berechnen'**
  String get helpInventoryStockValueTitle;

  /// No description provided for @helpInventoryStockValueDesc.
  ///
  /// In de, this message translates to:
  /// **'Der Lagerwert oben im Tab summiert (Stückzahl × Einkaufspreis) für alle Artikel mit Einkaufspreis. Artikel ohne Einkaufspreis fließen mit 0 ein — bitte nachpflegen, sonst stimmt die Statistik nicht.'**
  String get helpInventoryStockValueDesc;

  /// No description provided for @helpEntitiesSection.
  ///
  /// In de, this message translates to:
  /// **'Käufer, Shops & Lieferanten'**
  String get helpEntitiesSection;

  /// No description provided for @helpEntitiesBuyersTitle.
  ///
  /// In de, this message translates to:
  /// **'Käufer (Buyers)'**
  String get helpEntitiesBuyersTitle;

  /// No description provided for @helpEntitiesBuyersDesc.
  ///
  /// In de, this message translates to:
  /// **'Personen oder Plattformen, an die du verkaufst (z. B. „Tobias\", „eBay-Kleinanzeigen\", „Vinted\"). Beim Deal-Form pflichtfeldartig auswählbar — ohne Käufer kein Verkauf.'**
  String get helpEntitiesBuyersDesc;

  /// No description provided for @helpEntitiesShopsTitle.
  ///
  /// In de, this message translates to:
  /// **'Shops'**
  String get helpEntitiesShopsTitle;

  /// No description provided for @helpEntitiesShopsDesc.
  ///
  /// In de, this message translates to:
  /// **'Online-/Offline-Quellen, bei denen du einkaufst (z. B. „Amazon\", „Saturn\", „Otto\"). Bei Versand-Mails ordnet die App die Mail automatisch dem passenden Shop zu, sofern der Adapter den Absender kennt.'**
  String get helpEntitiesShopsDesc;

  /// No description provided for @helpEntitiesSuppliersTitle.
  ///
  /// In de, this message translates to:
  /// **'Lieferanten (Suppliers)'**
  String get helpEntitiesSuppliersTitle;

  /// No description provided for @helpEntitiesSuppliersDesc.
  ///
  /// In de, this message translates to:
  /// **'Spezialfall für B2B-Bezugsquellen mit Zahlungsfrist (Net 30, Net 60). Lieferanten werden im eigenen Tab geführt und im Deal als Quelle verlinkt — die Fälligkeitsstatistik zeigt dann offene Beträge.'**
  String get helpEntitiesSuppliersDesc;

  /// No description provided for @helpEntitiesBuyerColorTitle.
  ///
  /// In de, this message translates to:
  /// **'Farb-Kodierung der Käufer'**
  String get helpEntitiesBuyerColorTitle;

  /// No description provided for @helpEntitiesBuyerColorDesc.
  ///
  /// In de, this message translates to:
  /// **'Jedem Käufer kannst du eine Farbe zuweisen (Käufer-Karte → Farbe wählen). In der Deal-Tabelle und in den Statistiken erscheint diese Farbe, sodass du auf einen Blick siehst, an wen ein Deal ging.'**
  String get helpEntitiesBuyerColorDesc;

  /// No description provided for @helpTicketsSection.
  ///
  /// In de, this message translates to:
  /// **'Tickets'**
  String get helpTicketsSection;

  /// No description provided for @helpTicketsWhatTitle.
  ///
  /// In de, this message translates to:
  /// **'Was ist ein Ticket?'**
  String get helpTicketsWhatTitle;

  /// No description provided for @helpTicketsWhatDesc.
  ///
  /// In de, this message translates to:
  /// **'Ein Ticket bündelt mehrere Deals, die zusammen an einen Käufer gehen — z. B. eine Sammelbestellung mit fünf Artikeln. Das Ticket sieht den Gesamtpreis, alle Tracking-Nummern und einen einzigen Versand-Status.'**
  String get helpTicketsWhatDesc;

  /// No description provided for @helpTicketsArchiveTitle.
  ///
  /// In de, this message translates to:
  /// **'Aktiv vs. Archiv'**
  String get helpTicketsArchiveTitle;

  /// No description provided for @helpTicketsArchiveDesc.
  ///
  /// In de, this message translates to:
  /// **'Aktive Tickets sind noch nicht abgeschlossen. Sobald alle Deals im Ticket auf „Geliefert\" stehen, kannst du das Ticket archivieren — es verschwindet aus der Hauptansicht, bleibt aber in den Statistiken sichtbar.'**
  String get helpTicketsArchiveDesc;

  /// No description provided for @helpStatsSection.
  ///
  /// In de, this message translates to:
  /// **'Statistiken'**
  String get helpStatsSection;

  /// No description provided for @helpStatsKpiTitle.
  ///
  /// In de, this message translates to:
  /// **'KPI-Cards'**
  String get helpStatsKpiTitle;

  /// No description provided for @helpStatsKpiDesc.
  ///
  /// In de, this message translates to:
  /// **'Oben siehst du Umsatz, Profit, Anzahl Deals und Cashflow für den gewählten Zeitraum. Tippe eine Card an, um auf die zugehörige Detail-Ansicht zu wechseln.'**
  String get helpStatsKpiDesc;

  /// No description provided for @helpStatsChartsTitle.
  ///
  /// In de, this message translates to:
  /// **'Diagramme'**
  String get helpStatsChartsTitle;

  /// No description provided for @helpStatsChartsDesc.
  ///
  /// In de, this message translates to:
  /// **'Linien-Diagramm für Umsatz/Profit über Zeit, Balken-Diagramm für Top-Käufer und Top-Shops. Tippe auf einen Balken, um nach diesem Käufer/Shop zu filtern.'**
  String get helpStatsChartsDesc;

  /// No description provided for @helpStatsFiltersTitle.
  ///
  /// In de, this message translates to:
  /// **'Filter (Käufer/Shop/Datum)'**
  String get helpStatsFiltersTitle;

  /// No description provided for @helpStatsFiltersDesc.
  ///
  /// In de, this message translates to:
  /// **'Über das Filter-Icon oben rechts kannst du Käufer, Shops und Datumsbereich kombinieren. Die Filter werden in allen Cards und Diagrammen synchron angewendet.'**
  String get helpStatsFiltersDesc;

  /// No description provided for @helpStatsTaxTitle.
  ///
  /// In de, this message translates to:
  /// **'Steuer-/MwSt-Reports'**
  String get helpStatsTaxTitle;

  /// No description provided for @helpStatsTaxDesc.
  ///
  /// In de, this message translates to:
  /// **'Statistiken → Reiter „Steuer\" zeigt Quartals-Umsätze + MwSt-Schätzung (Klein- oder Regelunternehmer). CSV-Export pro Quartal über das Download-Icon. Die Schätzung ersetzt keine Steuerberatung.'**
  String get helpStatsTaxDesc;

  /// No description provided for @helpWorkspaceSection.
  ///
  /// In de, this message translates to:
  /// **'Workspace & Team'**
  String get helpWorkspaceSection;

  /// No description provided for @helpWorkspaceWhatTitle.
  ///
  /// In de, this message translates to:
  /// **'Was ist ein Workspace?'**
  String get helpWorkspaceWhatTitle;

  /// No description provided for @helpWorkspaceWhatDesc.
  ///
  /// In de, this message translates to:
  /// **'Ein Workspace ist ein abgeschotteter Daten-Container — alle Deals, Käufer, Shops und Lager-Artikel gehören zu genau einem Workspace. Du kannst mehrere Workspaces parallel pflegen (z. B. „Privat\" und „Geschäft\").'**
  String get helpWorkspaceWhatDesc;

  /// No description provided for @helpWorkspaceInviteTitle.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder einladen'**
  String get helpWorkspaceInviteTitle;

  /// No description provided for @helpWorkspaceInviteDesc.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen → Team → „Mitglied einladen\". Gib eine Mail-Adresse und eine Rolle an. Der Eingeladene bekommt eine Mail mit Link; sobald er sich registriert, taucht der Workspace bei ihm auf.'**
  String get helpWorkspaceInviteDesc;

  /// No description provided for @helpWorkspaceRolesTitle.
  ///
  /// In de, this message translates to:
  /// **'Rollen'**
  String get helpWorkspaceRolesTitle;

  /// No description provided for @helpWorkspaceRoleOwner.
  ///
  /// In de, this message translates to:
  /// **'Owner — kann alles, inklusive Workspace löschen, Mitglieder kicken und Plan ändern.'**
  String get helpWorkspaceRoleOwner;

  /// No description provided for @helpWorkspaceRoleAdmin.
  ///
  /// In de, this message translates to:
  /// **'Admin — kann Daten lesen/schreiben, Mitglieder einladen, Carrier-Keys pflegen. Kann den Workspace nicht löschen.'**
  String get helpWorkspaceRoleAdmin;

  /// No description provided for @helpWorkspaceRoleMember.
  ///
  /// In de, this message translates to:
  /// **'Member — kann Daten lesen/schreiben, aber keine Team- oder Carrier-Einstellungen ändern.'**
  String get helpWorkspaceRoleMember;

  /// No description provided for @helpWorkspacePricingTitle.
  ///
  /// In de, this message translates to:
  /// **'Pricing-Tier-Limits'**
  String get helpWorkspacePricingTitle;

  /// No description provided for @helpWorkspacePricingDesc.
  ///
  /// In de, this message translates to:
  /// **'Free, Pro und Business unterscheiden sich vor allem in der Anzahl Mitglieder, der Anzahl Postfächer und ob Carrier-Polling aktiv ist. Aktuelle Limits findest du auf dem Pricing-Screen.'**
  String get helpWorkspacePricingDesc;

  /// No description provided for @helpPushSection.
  ///
  /// In de, this message translates to:
  /// **'Push-Notifications'**
  String get helpPushSection;

  /// No description provided for @helpPushIosTitle.
  ///
  /// In de, this message translates to:
  /// **'iOS aktivieren'**
  String get helpPushIosTitle;

  /// No description provided for @helpPushIosDesc.
  ///
  /// In de, this message translates to:
  /// **'Beim ersten Start fragt iOS, ob die App Mitteilungen senden darf — bestätige mit „Erlauben\". Falls du es abgelehnt hast: iOS-Einstellungen → Mitteilungen → Lager-App → Mitteilungen erlauben.'**
  String get helpPushIosDesc;

  /// No description provided for @helpPushAndroidTitle.
  ///
  /// In de, this message translates to:
  /// **'Android aktivieren'**
  String get helpPushAndroidTitle;

  /// No description provided for @helpPushAndroidDesc.
  ///
  /// In de, this message translates to:
  /// **'Android 13+ fragt explizit nach Push-Erlaubnis. Falls du sie abgelehnt hast: Android-Einstellungen → Apps → Lager-App → Benachrichtigungen → aktivieren.'**
  String get helpPushAndroidDesc;

  /// No description provided for @helpPushWhenTitle.
  ///
  /// In de, this message translates to:
  /// **'Wann werden Pushs verschickt?'**
  String get helpPushWhenTitle;

  /// No description provided for @helpPushWhenDesc.
  ///
  /// In de, this message translates to:
  /// **'• Neue Bestellbestätigung im Postfach\n• Tracking-Update (Versandt / Angekommen)\n• Mindestbestand unterschritten (falls aktiviert)\n• Workspace-Einladung\nÜber Einstellungen → Push kannst du einzelne Kategorien deaktivieren.'**
  String get helpPushWhenDesc;

  /// No description provided for @helpFaqSection.
  ///
  /// In de, this message translates to:
  /// **'Häufige Fragen (FAQ)'**
  String get helpFaqSection;

  /// No description provided for @helpFaqQ1.
  ///
  /// In de, this message translates to:
  /// **'Warum sehe ich keine Mails nach dem Postfach-Add?'**
  String get helpFaqQ1;

  /// No description provided for @helpFaqA1.
  ///
  /// In de, this message translates to:
  /// **'Die erste Synchronisation läuft im Hintergrund und kann je nach Postfach-Größe 1–10 Minuten dauern. Außerdem werden nur Mails von bekannten Shops/Carriern eingelesen — Werbung und persönliche Mails werden ignoriert.'**
  String get helpFaqA1;

  /// No description provided for @helpFaqQ2.
  ///
  /// In de, this message translates to:
  /// **'Wie ändere ich die Sprache?'**
  String get helpFaqQ2;

  /// No description provided for @helpFaqA2.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen → Allgemein → Sprache. Aktuell verfügbar: Deutsch, Englisch. Die Änderung greift sofort.'**
  String get helpFaqA2;

  /// No description provided for @helpFaqQ3.
  ///
  /// In de, this message translates to:
  /// **'Wie lösche ich meine Daten?'**
  String get helpFaqQ3;

  /// No description provided for @helpFaqA3.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen → Allgemein → „Konto löschen\". Du musst das Wort LÖSCHEN tippen, um zu bestätigen. Account, Workspaces und Postfach-Konfiguration werden sofort gelöscht; Mail-Metadaten und gespeicherte Bilder werden innerhalb von 30 Tagen aus der Datenbank und dem Storage entfernt.'**
  String get helpFaqA3;

  /// No description provided for @helpFaqQ4.
  ///
  /// In de, this message translates to:
  /// **'Was passiert, wenn ich downgrade?'**
  String get helpFaqQ4;

  /// No description provided for @helpFaqA4.
  ///
  /// In de, this message translates to:
  /// **'Bestehende Daten bleiben erhalten. Funktionen über dem Downgrade-Limit (z. B. zusätzliche Mitglieder, Carrier-Polling) werden pausiert, bis du wieder upgradest oder die Limits aktiv reduzierst.'**
  String get helpFaqA4;

  /// No description provided for @helpFaqQ5.
  ///
  /// In de, this message translates to:
  /// **'Wie setze ich mein Passwort zurück?'**
  String get helpFaqQ5;

  /// No description provided for @helpFaqA5.
  ///
  /// In de, this message translates to:
  /// **'Login-Screen → „Passwort vergessen\". Gib deine Mail an, du bekommst einen Reset-Link. Klick im Link öffnet die App und du kannst ein neues Passwort setzen.'**
  String get helpFaqA5;

  /// No description provided for @helpFaqQ6.
  ///
  /// In de, this message translates to:
  /// **'Warum stimmt der Lagerwert nicht?'**
  String get helpFaqQ6;

  /// No description provided for @helpFaqA6.
  ///
  /// In de, this message translates to:
  /// **'Der Lagerwert zählt nur Artikel mit hinterlegtem Einkaufspreis. Öffne den Lager-Tab und filtere nach „Ohne Einkaufspreis\" — pflege die fehlenden Werte nach, dann passt die Summe.'**
  String get helpFaqA6;

  /// No description provided for @helpFaqQ7.
  ///
  /// In de, this message translates to:
  /// **'Tracking aktualisiert sich nicht — was tun?'**
  String get helpFaqQ7;

  /// No description provided for @helpFaqA7.
  ///
  /// In de, this message translates to:
  /// **'Carrier-Polling läuft alle 4 Stunden. Prüfe in Einstellungen → Versand, ob der Carrier-API-Key hinterlegt ist. Ohne Key kann die App den Status nicht abfragen — die Mail-Pipeline ergänzt das ggf. parallel über Versandmails.'**
  String get helpFaqA7;

  /// No description provided for @helpFaqQ8.
  ///
  /// In de, this message translates to:
  /// **'Kann ich mehrere Workspaces nutzen?'**
  String get helpFaqQ8;

  /// No description provided for @helpFaqA8.
  ///
  /// In de, this message translates to:
  /// **'Ja. Tippe oben rechts auf den Workspace-Namen → „Neuer Workspace\". Du wechselst per Tap zwischen Workspaces; Daten sind strikt getrennt.'**
  String get helpFaqA8;

  /// No description provided for @helpFaqQ9.
  ///
  /// In de, this message translates to:
  /// **'Discord-Buttons fehlen beim Deal — warum?'**
  String get helpFaqQ9;

  /// No description provided for @helpFaqA9.
  ///
  /// In de, this message translates to:
  /// **'Buttons erscheinen nur, wenn der Käufer mindestens eine Discord-Server-ID hinterlegt hat. Einstellungen → Käufer → Käufer bearbeiten → Discord-Server-IDs ergänzen.'**
  String get helpFaqA9;

  /// No description provided for @helpFaqQ10.
  ///
  /// In de, this message translates to:
  /// **'Wie exportiere ich meine Daten als CSV?'**
  String get helpFaqQ10;

  /// No description provided for @helpFaqA10.
  ///
  /// In de, this message translates to:
  /// **'Statistiken → Steuer-Reiter → Download-Icon (pro Quartal). Vollständiger Daten-Export ist in Vorbereitung — bis dahin auf Anfrage über „Probleme melden\".'**
  String get helpFaqA10;

  /// No description provided for @helpFaqQ11.
  ///
  /// In de, this message translates to:
  /// **'Wie erstelle ich einen Steuerreport?'**
  String get helpFaqQ11;

  /// No description provided for @helpFaqA11.
  ///
  /// In de, this message translates to:
  /// **'Statistiken → Steuer-Reiter → Quartal wählen → CSV herunterladen. Die App zeigt Brutto, Netto und MwSt-Anteil; je nach Steuermodell (Klein- oder Regelunternehmer) wird die MwSt unterschiedlich aufbereitet.'**
  String get helpFaqA11;

  /// No description provided for @helpFaqQ12.
  ///
  /// In de, this message translates to:
  /// **'Wie aktiviere ich den Dunkelmodus?'**
  String get helpFaqQ12;

  /// No description provided for @helpFaqA12.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen → Allgemein → Theme → „Dunkel\". Optional „System\" — folgt dann der iOS/Android-Systemeinstellung.'**
  String get helpFaqA12;

  /// No description provided for @helpFaqQ13.
  ///
  /// In de, this message translates to:
  /// **'Kann ich mein Konto temporär deaktivieren?'**
  String get helpFaqQ13;

  /// No description provided for @helpFaqA13.
  ///
  /// In de, this message translates to:
  /// **'Aktuell nicht — es gibt nur „Konto löschen\". Wenn du Push und Mail-Sync pausieren willst: Postfach in den Einstellungen entfernen und Push-Kategorien deaktivieren. Daten bleiben dann unverändert liegen.'**
  String get helpFaqA13;

  /// No description provided for @helpFaqQ14.
  ///
  /// In de, this message translates to:
  /// **'Wie deaktiviere ich Push-Mitteilungen?'**
  String get helpFaqQ14;

  /// No description provided for @helpFaqA14.
  ///
  /// In de, this message translates to:
  /// **'Entweder pro Kategorie in Einstellungen → Push, oder komplett über die OS-Einstellungen (iOS-Mitteilungen / Android-Benachrichtigungen → Lager-App).'**
  String get helpFaqA14;

  /// No description provided for @helpFaqQ15.
  ///
  /// In de, this message translates to:
  /// **'Wie suche ich gezielt in der Inbox?'**
  String get helpFaqQ15;

  /// No description provided for @helpFaqA15.
  ///
  /// In de, this message translates to:
  /// **'Inbox-Tab → Suchsymbol oben rechts. Du kannst nach Absender, Betreff oder Tracking-Nummer suchen. Die Suche filtert alle drei Tabs (Vorschläge / Aktualisiert / Unklassifiziert) gleichzeitig.'**
  String get helpFaqA15;

  /// No description provided for @helpFaqQ16.
  ///
  /// In de, this message translates to:
  /// **'Warum sehe ich Deals anderer Mitglieder nicht?'**
  String get helpFaqQ16;

  /// No description provided for @helpFaqA16.
  ///
  /// In de, this message translates to:
  /// **'Du bist möglicherweise im falschen Workspace. Prüfe oben rechts den Workspace-Namen und wechsle ggf. Auch Filter (Käufer/Shop/Datum) können Deals ausblenden — Filter zurücksetzen mit dem „Filter leeren\"-Button.'**
  String get helpFaqA16;

  /// No description provided for @helpFaqQ17.
  ///
  /// In de, this message translates to:
  /// **'Was bedeutet das „Prüfen\"-Badge an einer Sendung?'**
  String get helpFaqQ17;

  /// No description provided for @helpFaqA17.
  ///
  /// In de, this message translates to:
  /// **'Die App hat den Tracking-Wert zwar gespeichert, aber unsere neue Erkennung ist sich nicht sicher, ob es wirklich eine echte Sendungsnummer ist (z. B. weil sie aus einer älteren Mail mit unklarem Format kommt). Tippe auf den Deal und prüfe in der Sendungsnummer-Karte: „Übernehmen\" bestätigt den Wert, „Verwerfen\" leert ihn. In der Deals-Liste oben filtert der Chip „Prüfen\" alle betroffenen Deals auf einen Schlag.'**
  String get helpFaqA17;

  /// No description provided for @helpFaqQ18.
  ///
  /// In de, this message translates to:
  /// **'Wie funktioniert „Sendungsnummern neu bewerten\" in den Einstellungen?'**
  String get helpFaqQ18;

  /// No description provided for @helpFaqA18.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen → Allgemein → „Sendungsnummern neu bewerten\" prüft alle gespeicherten Mails dieses Workspaces nochmal mit der neuesten, strikteren Erkennung. Falsch gespeicherte Werte werden auf „Prüfen\" gesetzt, neu erkannte echte Trackings ersetzen leere Einträge. Manuell eingetragene Sendungsnummern bleiben unangetastet. Aus Schutz vor Doppelläufen läuft das maximal einmal alle 5 Minuten pro Workspace.'**
  String get helpFaqA18;

  /// No description provided for @helpFaqQ19.
  ///
  /// In de, this message translates to:
  /// **'Warum ist eine Sendungsnummer manchmal leer, obwohl die Versandmail da ist?'**
  String get helpFaqQ19;

  /// No description provided for @helpFaqA19.
  ///
  /// In de, this message translates to:
  /// **'Seit Mai 2026 speichert die App eine Tracking-Nummer nur, wenn sie strukturell verifiziert ist (Carrier-Pattern + Längen-/Prüfsummen-Check). Wenn die Mail nur eine interne Shop-ID enthält (z. B. Amazon-Logistics-Shipment-ID) oder die Nummer unklar formatiert ist, lässt die App das Feld bewusst leer statt einen falschen Wert zu speichern. Du kannst die Sendungsnummer direkt im Deal manuell eintragen — manuelle Eingaben werden nie automatisch überschrieben.'**
  String get helpFaqA19;

  /// No description provided for @helpTroubleSection.
  ///
  /// In de, this message translates to:
  /// **'Fehlerbehebung'**
  String get helpTroubleSection;

  /// No description provided for @helpTroubleConnectionTitle.
  ///
  /// In de, this message translates to:
  /// **'„Keine Verbindung zum Server\"'**
  String get helpTroubleConnectionTitle;

  /// No description provided for @helpTroubleConnectionDesc.
  ///
  /// In de, this message translates to:
  /// **'Prüfe deine Internet-Verbindung und versuche „Aktualisieren\" (Pull-to-Refresh). Wenn das Problem bleibt: Status-Seite über die Webseite prüfen, ggf. ein paar Minuten warten — Supabase-Restarts brauchen kurz.'**
  String get helpTroubleConnectionDesc;

  /// No description provided for @helpTroubleImapAuthTitle.
  ///
  /// In de, this message translates to:
  /// **'„IMAP-Login fehlgeschlagen\"'**
  String get helpTroubleImapAuthTitle;

  /// No description provided for @helpTroubleImapAuthDesc.
  ///
  /// In de, this message translates to:
  /// **'Bei Gmail/Outlook: stelle sicher, dass du ein App-Passwort verwendest, kein normales Login-Passwort. Bei IONOS prüfen, ob IMAP serverseitig aktiviert ist. Tippfehler im Server-Hostname sind die häufigste Ursache.'**
  String get helpTroubleImapAuthDesc;

  /// No description provided for @helpTroubleSyncStuckTitle.
  ///
  /// In de, this message translates to:
  /// **'Postfach-Sync hängt'**
  String get helpTroubleSyncStuckTitle;

  /// No description provided for @helpTroubleSyncStuckDesc.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen → Postfach → Mailbox auswählen → „Re-Sync\". Falls weiterhin keine Mails kommen: Postfach entfernen und neu hinzufügen — der Bootstrap-Pump zieht dann erneut alle Mails der letzten 60 Tage.'**
  String get helpTroubleSyncStuckDesc;

  /// No description provided for @helpTroubleNotifMissingTitle.
  ///
  /// In de, this message translates to:
  /// **'Push-Mitteilungen kommen nicht an'**
  String get helpTroubleNotifMissingTitle;

  /// No description provided for @helpTroubleNotifMissingDesc.
  ///
  /// In de, this message translates to:
  /// **'Prüfe zuerst die OS-Mitteilungseinstellungen (iOS-Mitteilungen / Android-Benachrichtigungen → Lager-App → Mitteilungen erlaubt?). Dann in der App Einstellungen → Push: prüfe, ob die einzelnen Kategorien aktiviert sind. Wenn alles auf „erlaubt\" steht und trotzdem nichts kommt, einmal aus- und wieder einloggen — dabei wird der Push-Token neu registriert.'**
  String get helpTroubleNotifMissingDesc;

  /// No description provided for @helpTroubleStatsEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Statistiken sind leer'**
  String get helpTroubleStatsEmptyTitle;

  /// No description provided for @helpTroubleStatsEmptyDesc.
  ///
  /// In de, this message translates to:
  /// **'Statistiken zählen nur Deals mit Status „Verkauft\" oder „Geliefert\" und Verkaufspreis > 0. Prüfe deinen Datumsfilter (oben rechts), eventuell ist er auf einen leeren Zeitraum gesetzt.'**
  String get helpTroubleStatsEmptyDesc;

  /// No description provided for @helpTroubleLoginFailedTitle.
  ///
  /// In de, this message translates to:
  /// **'Login funktioniert nicht'**
  String get helpTroubleLoginFailedTitle;

  /// No description provided for @helpTroubleLoginFailedDesc.
  ///
  /// In de, this message translates to:
  /// **'Stelle sicher, dass die Mail bestätigt ist (Link aus Willkommens-Mail). Bei Google/Apple-Sign-In: hilf der App, den Browser-Tab zu öffnen — manche In-App-Browser blocken den Callback. Notfalls Passwort zurücksetzen.'**
  String get helpTroubleLoginFailedDesc;

  /// No description provided for @helpTroubleUploadFailedTitle.
  ///
  /// In de, this message translates to:
  /// **'Foto-Upload schlägt fehl'**
  String get helpTroubleUploadFailedTitle;

  /// No description provided for @helpTroubleUploadFailedDesc.
  ///
  /// In de, this message translates to:
  /// **'Bilder über 10 MB werden abgelehnt. Reduziere Größe/Qualität, oder erlaube der App in den OS-Einstellungen Zugriff auf Fotos/Mediathek. Bei sehr langsamer Verbindung kann der Upload nach 60 s timeoutten — erneut versuchen.'**
  String get helpTroubleUploadFailedDesc;

  /// No description provided for @helpTroubleSlowTitle.
  ///
  /// In de, this message translates to:
  /// **'App ist plötzlich langsam'**
  String get helpTroubleSlowTitle;

  /// No description provided for @helpTroubleSlowDesc.
  ///
  /// In de, this message translates to:
  /// **'Sehr lange Deal-/Inbox-Listen? Filter setzen (Datum, Status, Käufer), das reduziert die Render-Last. App komplett beenden und neu starten leert flüchtige Caches im Speicher. Auf älteren Geräten kann es helfen, alte Tickets zu archivieren.'**
  String get helpTroubleSlowDesc;

  /// No description provided for @helpTroubleCarrierSetupTitle.
  ///
  /// In de, this message translates to:
  /// **'„Setup unvollständig: Master-Key nicht konfiguriert\"'**
  String get helpTroubleCarrierSetupTitle;

  /// No description provided for @helpTroubleCarrierSetupDesc.
  ///
  /// In de, this message translates to:
  /// **'Diese Meldung erscheint, wenn du einen Carrier-API-Key speichern willst, aber das Backend keinen Master-Schlüssel hat, mit dem es deinen Key verschlüsselt ablegen kann. Das ist kein Fehler in deinem Account, sondern ein einmaliger Backend-Setup-Schritt:\n• Hosted-Variante (Standard-Nutzer): kurz warten und nochmal versuchen — wir setzen den Master-Key zentral, normalerweise innerhalb weniger Stunden.\n• Self-Hoster / Admin der Supabase-Instanz: die Migration `20260516000000_carrier_master_key_bootstrap.sql` muss eingespielt sein und der `CARRIER_MASTER_KEY`-Secret auf der Supabase-Projektebene gesetzt sein. Details für Admins liegen im Repo unter `supabase/functions/tracking-poll/SETUP.md`.\nBis das gefixt ist, kannst du deine Sendungen weiter manuell pflegen — nur der automatische Live-Status pro Carrier ist solange aus.'**
  String get helpTroubleCarrierSetupDesc;

  /// No description provided for @helpPrivacySection.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz & Kontakt'**
  String get helpPrivacySection;

  /// No description provided for @helpPrivacyDataTitle.
  ///
  /// In de, this message translates to:
  /// **'Welche Daten werden gespeichert?'**
  String get helpPrivacyDataTitle;

  /// No description provided for @helpPrivacyDataDesc.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert werden: Stammdaten (Workspace, Deals, Käufer), Postfach-Konfiguration (Passwort verschlüsselt) und Foto-Uploads. Aus eingelesenen Mails werden Header (Absender, Betreff, Datum) und ein normalisierter JSON-Auszug (Bestellnummer, Tracking-Nummer, Beträge, Produkt) gespeichert; der vollständige Mail-Body bleibt nicht dauerhaft liegen. Mail-Metadaten werden nach 100 Tagen automatisch gelöscht. Details siehe Datenschutz-Erklärung in Einstellungen → Allgemein.'**
  String get helpPrivacyDataDesc;

  /// No description provided for @helpPrivacySupportTitle.
  ///
  /// In de, this message translates to:
  /// **'Wie erreiche ich den Support?'**
  String get helpPrivacySupportTitle;

  /// No description provided for @helpPrivacySupportDesc.
  ///
  /// In de, this message translates to:
  /// **'Über „Probleme melden\" wird eine Mail mit App-Version, OS und Workspace-ID generiert (keine Passwörter). Antwortzeit in der Regel < 48 h.'**
  String get helpPrivacySupportDesc;

  /// No description provided for @helpPrivacyNoteTitle.
  ///
  /// In de, this message translates to:
  /// **'Wichtige Hinweise'**
  String get helpPrivacyNoteTitle;

  /// No description provided for @helpPrivacyNoteDesc.
  ///
  /// In de, this message translates to:
  /// **'Die App ersetzt keine Buchhaltung oder Steuerberatung — die Statistiken sind Schätzungen. Vor dem ersten Quartalsabschluss bitte mit einem Steuerberater sprechen.'**
  String get helpPrivacyNoteDesc;

  /// No description provided for @ticketsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Tickets gefunden'**
  String get ticketsEmpty;

  /// No description provided for @ticketsNoTicket.
  ///
  /// In de, this message translates to:
  /// **'Kein Ticket'**
  String get ticketsNoTicket;

  /// No description provided for @inventoryEmpty.
  ///
  /// In de, this message translates to:
  /// **'Lager ist leer.'**
  String get inventoryEmpty;

  /// No description provided for @inventoryAddItem.
  ///
  /// In de, this message translates to:
  /// **'Artikel hinzufügen'**
  String get inventoryAddItem;

  /// No description provided for @inventoryColName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get inventoryColName;

  /// No description provided for @inventoryColSku.
  ///
  /// In de, this message translates to:
  /// **'SKU'**
  String get inventoryColSku;

  /// No description provided for @inventoryColEan.
  ///
  /// In de, this message translates to:
  /// **'EAN'**
  String get inventoryColEan;

  /// No description provided for @inventoryColQuantity.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get inventoryColQuantity;

  /// No description provided for @inventoryColMinStock.
  ///
  /// In de, this message translates to:
  /// **'Min.'**
  String get inventoryColMinStock;

  /// No description provided for @inventoryColLocation.
  ///
  /// In de, this message translates to:
  /// **'Lagerort'**
  String get inventoryColLocation;

  /// No description provided for @inventoryColCost.
  ///
  /// In de, this message translates to:
  /// **'EK'**
  String get inventoryColCost;

  /// No description provided for @inventoryColArrival.
  ///
  /// In de, this message translates to:
  /// **'Ankunft'**
  String get inventoryColArrival;

  /// No description provided for @inventoryColSupplier.
  ///
  /// In de, this message translates to:
  /// **'Lieferant'**
  String get inventoryColSupplier;

  /// No description provided for @suppliersEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Lieferanten angelegt.'**
  String get suppliersEmpty;

  /// No description provided for @suppliersAdd.
  ///
  /// In de, this message translates to:
  /// **'Lieferant hinzufügen'**
  String get suppliersAdd;

  /// No description provided for @suppliersDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Lieferant löschen'**
  String get suppliersDeleteTitle;

  /// No description provided for @suppliersDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Lieferant „{name}\" wirklich löschen?'**
  String suppliersDeleteConfirm(Object name);

  /// No description provided for @activityTitle.
  ///
  /// In de, this message translates to:
  /// **'Aktivität'**
  String get activityTitle;

  /// No description provided for @activityEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Aktivität.'**
  String get activityEmpty;

  /// No description provided for @dashboardOpenOrders.
  ///
  /// In de, this message translates to:
  /// **'Offene Bestellungen'**
  String get dashboardOpenOrders;

  /// No description provided for @dashboardOpenAmount.
  ///
  /// In de, this message translates to:
  /// **'Offene Beträge'**
  String get dashboardOpenAmount;

  /// No description provided for @dashboardArrivedToday.
  ///
  /// In de, this message translates to:
  /// **'Heute angekommen'**
  String get dashboardArrivedToday;

  /// No description provided for @dashboardCriticalStock.
  ///
  /// In de, this message translates to:
  /// **'Kritische Lager'**
  String get dashboardCriticalStock;

  /// No description provided for @dashboardMissingInvoice.
  ///
  /// In de, this message translates to:
  /// **'Fehlende Belege'**
  String get dashboardMissingInvoice;

  /// No description provided for @dashboardTotalProfit.
  ///
  /// In de, this message translates to:
  /// **'Gesamt-Profit'**
  String get dashboardTotalProfit;

  /// No description provided for @dashboardOpenDeliveries.
  ///
  /// In de, this message translates to:
  /// **'Offene Lieferungen'**
  String get dashboardOpenDeliveries;

  /// No description provided for @dashboardStockQuantity.
  ///
  /// In de, this message translates to:
  /// **'Lagerbestand'**
  String get dashboardStockQuantity;

  /// No description provided for @dashboardStockValue.
  ///
  /// In de, this message translates to:
  /// **'Lagerwert'**
  String get dashboardStockValue;

  /// No description provided for @dashboardKpiOpenOrders.
  ///
  /// In de, this message translates to:
  /// **'Offene Bestellungen'**
  String get dashboardKpiOpenOrders;

  /// No description provided for @dashboardKpiShipping.
  ///
  /// In de, this message translates to:
  /// **'Unterwegs'**
  String get dashboardKpiShipping;

  /// No description provided for @dashboardKpiArrivedToday.
  ///
  /// In de, this message translates to:
  /// **'Heute angekommen'**
  String get dashboardKpiArrivedToday;

  /// No description provided for @dashboardKpiTotalProfit.
  ///
  /// In de, this message translates to:
  /// **'Gesamtprofit'**
  String get dashboardKpiTotalProfit;

  /// No description provided for @dashboardKpiOpenAmount.
  ///
  /// In de, this message translates to:
  /// **'Offener Betrag'**
  String get dashboardKpiOpenAmount;

  /// No description provided for @dashboardKpiCriticalStock.
  ///
  /// In de, this message translates to:
  /// **'Lager kritisch'**
  String get dashboardKpiCriticalStock;

  /// No description provided for @dashboardKpiMissingInvoice.
  ///
  /// In de, this message translates to:
  /// **'Ausstehende Rechnungen'**
  String get dashboardKpiMissingInvoice;

  /// No description provided for @dashboardActivityFeed.
  ///
  /// In de, this message translates to:
  /// **'Aktivitäts-Feed'**
  String get dashboardActivityFeed;

  /// No description provided for @dashboardActivityEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Aktionen vorhanden.'**
  String get dashboardActivityEmpty;

  /// No description provided for @dashboardBuyerOverview.
  ///
  /// In de, this message translates to:
  /// **'Käufer-Schnellübersicht'**
  String get dashboardBuyerOverview;

  /// No description provided for @dashboardBuyerEmpty.
  ///
  /// In de, this message translates to:
  /// **'Käufer in den Einstellungen anlegen.'**
  String get dashboardBuyerEmpty;

  /// No description provided for @dashboardColBuyer.
  ///
  /// In de, this message translates to:
  /// **'KÄUFER'**
  String get dashboardColBuyer;

  /// No description provided for @dashboardColDeals.
  ///
  /// In de, this message translates to:
  /// **'DEALS'**
  String get dashboardColDeals;

  /// No description provided for @dashboardColOpen.
  ///
  /// In de, this message translates to:
  /// **'OFFEN'**
  String get dashboardColOpen;

  /// No description provided for @dashboardColLastDeal.
  ///
  /// In de, this message translates to:
  /// **'LETZTER DEAL'**
  String get dashboardColLastDeal;

  /// No description provided for @ticketsTitle.
  ///
  /// In de, this message translates to:
  /// **'Tickets'**
  String get ticketsTitle;

  /// No description provided for @ticketsSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Ticketnummer oder Produkt suchen'**
  String get ticketsSearchHint;

  /// No description provided for @ticketsNewDeal.
  ///
  /// In de, this message translates to:
  /// **'Neuer Deal'**
  String get ticketsNewDeal;

  /// No description provided for @ticketsSelect.
  ///
  /// In de, this message translates to:
  /// **'Ticket auswählen'**
  String get ticketsSelect;

  /// No description provided for @ticketsSearchHintShort.
  ///
  /// In de, this message translates to:
  /// **'Ticket suchen'**
  String get ticketsSearchHintShort;

  /// No description provided for @ticketsTabList.
  ///
  /// In de, this message translates to:
  /// **'Tickets'**
  String get ticketsTabList;

  /// No description provided for @ticketsTabDetail.
  ///
  /// In de, this message translates to:
  /// **'Detail'**
  String get ticketsTabDetail;

  /// No description provided for @ticketsSortLabel.
  ///
  /// In de, this message translates to:
  /// **'Sortierung'**
  String get ticketsSortLabel;

  /// No description provided for @ticketsSortDate.
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get ticketsSortDate;

  /// No description provided for @ticketsSortProfit.
  ///
  /// In de, this message translates to:
  /// **'Profit'**
  String get ticketsSortProfit;

  /// No description provided for @ticketsSortDealCount.
  ///
  /// In de, this message translates to:
  /// **'Anzahl Deals'**
  String get ticketsSortDealCount;

  /// No description provided for @ticketsOpenTooltip.
  ///
  /// In de, this message translates to:
  /// **'Ticket öffnen'**
  String get ticketsOpenTooltip;

  /// No description provided for @ticketsBulkEditTooltip.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get ticketsBulkEditTooltip;

  /// No description provided for @ticketsAddDealTooltip.
  ///
  /// In de, this message translates to:
  /// **'Deal hinzufügen'**
  String get ticketsAddDealTooltip;

  /// No description provided for @ticketsEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Ticket bearbeiten'**
  String get ticketsEditTitle;

  /// No description provided for @ticketsTicketNumber.
  ///
  /// In de, this message translates to:
  /// **'Ticketnummer'**
  String get ticketsTicketNumber;

  /// No description provided for @ticketsRelatedItems.
  ///
  /// In de, this message translates to:
  /// **'Zugehörige Lagerartikel'**
  String get ticketsRelatedItems;

  /// No description provided for @ticketsNoBuyerAssigned.
  ///
  /// In de, this message translates to:
  /// **'Kein Käufer zugeordnet'**
  String get ticketsNoBuyerAssigned;

  /// No description provided for @ticketsBoxEkTotal.
  ///
  /// In de, this message translates to:
  /// **'EK gesamt'**
  String get ticketsBoxEkTotal;

  /// No description provided for @ticketsBoxVkTotal.
  ///
  /// In de, this message translates to:
  /// **'VK gesamt'**
  String get ticketsBoxVkTotal;

  /// No description provided for @ticketsBoxProfit.
  ///
  /// In de, this message translates to:
  /// **'Profit'**
  String get ticketsBoxProfit;

  /// No description provided for @ticketsBoxQuantity.
  ///
  /// In de, this message translates to:
  /// **'Stückzahl'**
  String get ticketsBoxQuantity;

  /// No description provided for @ticketsColProduct.
  ///
  /// In de, this message translates to:
  /// **'Produkt'**
  String get ticketsColProduct;

  /// No description provided for @ticketsColQuantity.
  ///
  /// In de, this message translates to:
  /// **'Anzahl'**
  String get ticketsColQuantity;

  /// No description provided for @ticketsColTracking.
  ///
  /// In de, this message translates to:
  /// **'Tracking'**
  String get ticketsColTracking;

  /// No description provided for @ticketsCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Deal(s)'**
  String ticketsCount(int count);

  /// No description provided for @ticketsItemsCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Artikel'**
  String ticketsItemsCount(int count);

  /// No description provided for @ticketsKeinTicket.
  ///
  /// In de, this message translates to:
  /// **'Kein Ticket'**
  String get ticketsKeinTicket;

  /// No description provided for @ticketsNoBuyer.
  ///
  /// In de, this message translates to:
  /// **'Kein Käufer'**
  String get ticketsNoBuyer;

  /// No description provided for @ticketsTabActive.
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get ticketsTabActive;

  /// No description provided for @ticketsTabArchive.
  ///
  /// In de, this message translates to:
  /// **'Archiv'**
  String get ticketsTabArchive;

  /// No description provided for @ticketsArchiveEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine archivierten Tickets'**
  String get ticketsArchiveEmpty;

  /// No description provided for @ticketsArchiveReopen.
  ///
  /// In de, this message translates to:
  /// **'Wieder öffnen'**
  String get ticketsArchiveReopen;

  /// No description provided for @ticketsArchiveReopenConfirm.
  ///
  /// In de, this message translates to:
  /// **'Dieses Ticket wieder öffnen? Archiv-Zeitpunkt und Grund werden zurückgesetzt.'**
  String get ticketsArchiveReopenConfirm;

  /// No description provided for @ticketsArchiveMonthProfit.
  ///
  /// In de, this message translates to:
  /// **'Profit: {profit}'**
  String ticketsArchiveMonthProfit(Object profit);

  /// No description provided for @ticketsArchiveLongPressHint.
  ///
  /// In de, this message translates to:
  /// **'Lang drücken zum Wiedereröffnen'**
  String get ticketsArchiveLongPressHint;

  /// No description provided for @inventoryTitle.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get inventoryTitle;

  /// No description provided for @inventorySearchHint.
  ///
  /// In de, this message translates to:
  /// **'Name, SKU, EAN, Lagerort suchen'**
  String get inventorySearchHint;

  /// No description provided for @inventoryAddBatch.
  ///
  /// In de, this message translates to:
  /// **'Charge hinzufügen'**
  String get inventoryAddBatch;

  /// No description provided for @inventoryAdjustStock.
  ///
  /// In de, this message translates to:
  /// **'Bestand anpassen'**
  String get inventoryAdjustStock;

  /// No description provided for @inventoryNoSku.
  ///
  /// In de, this message translates to:
  /// **'Keine SKU'**
  String get inventoryNoSku;

  /// No description provided for @inventoryNoLocation.
  ///
  /// In de, this message translates to:
  /// **'Kein Lagerort'**
  String get inventoryNoLocation;

  /// No description provided for @inventoryDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Lagerartikel löschen'**
  String get inventoryDeleteTitle;

  /// No description provided for @inventoryDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Artikel „{name}\" wirklich löschen?'**
  String inventoryDeleteConfirm(Object name);

  /// No description provided for @inventoryNoEan.
  ///
  /// In de, this message translates to:
  /// **'Kein Artikel mit dieser EAN'**
  String get inventoryNoEan;

  /// No description provided for @inventoryCreate.
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get inventoryCreate;

  /// No description provided for @inventoryKpiTotalItems.
  ///
  /// In de, this message translates to:
  /// **'Gesamtartikel'**
  String get inventoryKpiTotalItems;

  /// No description provided for @inventoryKpiTotalStock.
  ///
  /// In de, this message translates to:
  /// **'Gesamtbestand'**
  String get inventoryKpiTotalStock;

  /// No description provided for @inventoryKpiCriticalItems.
  ///
  /// In de, this message translates to:
  /// **'Kritische Artikel'**
  String get inventoryKpiCriticalItems;

  /// No description provided for @inventoryKpiStockValue.
  ///
  /// In de, this message translates to:
  /// **'Lagerwert'**
  String get inventoryKpiStockValue;

  /// No description provided for @inventoryStockIn.
  ///
  /// In de, this message translates to:
  /// **'Ein'**
  String get inventoryStockIn;

  /// No description provided for @inventoryStockOut.
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get inventoryStockOut;

  /// No description provided for @inventoryColLocationLong.
  ///
  /// In de, this message translates to:
  /// **'Lagerort'**
  String get inventoryColLocationLong;

  /// No description provided for @inventoryColMin.
  ///
  /// In de, this message translates to:
  /// **'Mindestbestand'**
  String get inventoryColMin;

  /// No description provided for @inventoryColActions.
  ///
  /// In de, this message translates to:
  /// **'Aktionen'**
  String get inventoryColActions;

  /// No description provided for @inventoryColStock.
  ///
  /// In de, this message translates to:
  /// **'Bestand'**
  String get inventoryColStock;

  /// No description provided for @inventoryStockInTooltip.
  ///
  /// In de, this message translates to:
  /// **'Einbuchen'**
  String get inventoryStockInTooltip;

  /// No description provided for @inventoryStockOutTooltip.
  ///
  /// In de, this message translates to:
  /// **'Ausbuchen'**
  String get inventoryStockOutTooltip;

  /// No description provided for @inventoryStockInTitle.
  ///
  /// In de, this message translates to:
  /// **'Einbuchen'**
  String get inventoryStockInTitle;

  /// No description provided for @inventoryStockOutTitle.
  ///
  /// In de, this message translates to:
  /// **'Ausbuchen'**
  String get inventoryStockOutTitle;

  /// No description provided for @inventoryQuantity.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get inventoryQuantity;

  /// No description provided for @inventoryReason.
  ///
  /// In de, this message translates to:
  /// **'Grund'**
  String get inventoryReason;

  /// No description provided for @inventoryReasonStockIn.
  ///
  /// In de, this message translates to:
  /// **'Einbuchung'**
  String get inventoryReasonStockIn;

  /// No description provided for @inventoryReasonSale.
  ///
  /// In de, this message translates to:
  /// **'Verkauf'**
  String get inventoryReasonSale;

  /// No description provided for @inventoryHelpTextTicket.
  ///
  /// In de, this message translates to:
  /// **'Aus Ticket auswählen oder frei eingeben'**
  String get inventoryHelpTextTicket;

  /// No description provided for @inventoryAddItemTitle.
  ///
  /// In de, this message translates to:
  /// **'Artikel hinzufügen'**
  String get inventoryAddItemTitle;

  /// No description provided for @inventoryEditItemTitle.
  ///
  /// In de, this message translates to:
  /// **'Artikel bearbeiten'**
  String get inventoryEditItemTitle;

  /// No description provided for @inventorySectionGeneral.
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get inventorySectionGeneral;

  /// No description provided for @inventorySectionId.
  ///
  /// In de, this message translates to:
  /// **'Identifikation'**
  String get inventorySectionId;

  /// No description provided for @inventorySectionAttachments.
  ///
  /// In de, this message translates to:
  /// **'Anhänge'**
  String get inventorySectionAttachments;

  /// No description provided for @inventoryNoSupplier.
  ///
  /// In de, this message translates to:
  /// **'Kein Lieferant'**
  String get inventoryNoSupplier;

  /// No description provided for @inventoryScanBarcode.
  ///
  /// In de, this message translates to:
  /// **'Barcode scannen'**
  String get inventoryScanBarcode;

  /// No description provided for @inventoryClose.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get inventoryClose;

  /// No description provided for @inventoryTabStock.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get inventoryTabStock;

  /// No description provided for @inventoryTabSold.
  ///
  /// In de, this message translates to:
  /// **'Verkauft'**
  String get inventoryTabSold;

  /// No description provided for @inventorySoldEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine verkauften Artikel.'**
  String get inventorySoldEmpty;

  /// No description provided for @inventorySoldKpiCount.
  ///
  /// In de, this message translates to:
  /// **'Verkaufte Items'**
  String get inventorySoldKpiCount;

  /// No description provided for @inventorySoldKpiProfit.
  ///
  /// In de, this message translates to:
  /// **'Gesamt-Profit'**
  String get inventorySoldKpiProfit;

  /// No description provided for @inventorySoldKpiTopBuyers.
  ///
  /// In de, this message translates to:
  /// **'Top 3 Käufer'**
  String get inventorySoldKpiTopBuyers;

  /// No description provided for @inventorySoldNoBuyer.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Käufer-Daten'**
  String get inventorySoldNoBuyer;

  /// No description provided for @inventorySoldBuyerItems.
  ///
  /// In de, this message translates to:
  /// **'{count} Stück'**
  String inventorySoldBuyerItems(int count);

  /// No description provided for @supplierAddTitle.
  ///
  /// In de, this message translates to:
  /// **'Lieferant anlegen'**
  String get supplierAddTitle;

  /// No description provided for @supplierEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Lieferant bearbeiten'**
  String get supplierEditTitle;

  /// No description provided for @supplierContactName.
  ///
  /// In de, this message translates to:
  /// **'Ansprechpartner'**
  String get supplierContactName;

  /// No description provided for @supplierPhone.
  ///
  /// In de, this message translates to:
  /// **'Telefon'**
  String get supplierPhone;

  /// No description provided for @supplierWebsite.
  ///
  /// In de, this message translates to:
  /// **'Webseite'**
  String get supplierWebsite;

  /// No description provided for @supplierActive.
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get supplierActive;

  /// No description provided for @supplierItems.
  ///
  /// In de, this message translates to:
  /// **'{count} Artikel'**
  String supplierItems(int count);

  /// No description provided for @suppliersNew.
  ///
  /// In de, this message translates to:
  /// **'Neuer Lieferant'**
  String get suppliersNew;

  /// No description provided for @suppliersDeletePrompt.
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wird in den Papierkorb verschoben. Du kannst ihn später wiederherstellen.'**
  String suppliersDeletePrompt(Object name);

  /// No description provided for @suppliersInactive.
  ///
  /// In de, this message translates to:
  /// **'Inaktiv'**
  String get suppliersInactive;

  /// No description provided for @suppliersEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Über den + Button kannst du den ersten Lieferanten hinzufügen.'**
  String get suppliersEmptyHint;

  /// No description provided for @activityHeading.
  ///
  /// In de, this message translates to:
  /// **'Aktivitätsverlauf'**
  String get activityHeading;

  /// No description provided for @activityFilterReset.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get activityFilterReset;

  /// No description provided for @activityToday.
  ///
  /// In de, this message translates to:
  /// **'HEUTE'**
  String get activityToday;

  /// No description provided for @activityYesterday.
  ///
  /// In de, this message translates to:
  /// **'GESTERN'**
  String get activityYesterday;

  /// No description provided for @activityTypeDeal.
  ///
  /// In de, this message translates to:
  /// **'Deal'**
  String get activityTypeDeal;

  /// No description provided for @activityTypeStatus.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get activityTypeStatus;

  /// No description provided for @activityTypeStock.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get activityTypeStock;

  /// No description provided for @activityTypeSupplier.
  ///
  /// In de, this message translates to:
  /// **'Lieferant'**
  String get activityTypeSupplier;

  /// No description provided for @activityTypeBatch.
  ///
  /// In de, this message translates to:
  /// **'Charge'**
  String get activityTypeBatch;

  /// No description provided for @activityTypeBulk.
  ///
  /// In de, this message translates to:
  /// **'Bulk'**
  String get activityTypeBulk;

  /// No description provided for @activityTypeImport.
  ///
  /// In de, this message translates to:
  /// **'Import'**
  String get activityTypeImport;

  /// No description provided for @activityTypeInfo.
  ///
  /// In de, this message translates to:
  /// **'Info'**
  String get activityTypeInfo;

  /// No description provided for @activityTypeComment.
  ///
  /// In de, this message translates to:
  /// **'Kommentar'**
  String get activityTypeComment;

  /// No description provided for @activitySearchHint.
  ///
  /// In de, this message translates to:
  /// **'Aktivitäten durchsuchen…'**
  String get activitySearchHint;

  /// No description provided for @activityCountTotal.
  ///
  /// In de, this message translates to:
  /// **'{count} Einträge (max. 50)'**
  String activityCountTotal(int count);

  /// No description provided for @activityCountFiltered.
  ///
  /// In de, this message translates to:
  /// **'{filtered} von {total} Einträgen'**
  String activityCountFiltered(int filtered, int total);

  /// No description provided for @activityNoMatches.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer.'**
  String get activityNoMatches;

  /// No description provided for @activityNoActivitiesYet.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Aktivitäten.'**
  String get activityNoActivitiesYet;

  /// No description provided for @activityAdjustFilters.
  ///
  /// In de, this message translates to:
  /// **'Filter anpassen oder zurücksetzen.'**
  String get activityAdjustFilters;

  /// No description provided for @activityAutoAppears.
  ///
  /// In de, this message translates to:
  /// **'Aktionen wie Deal-Anlage erscheinen hier automatisch.'**
  String get activityAutoAppears;

  /// No description provided for @statisticsTabRevenue.
  ///
  /// In de, this message translates to:
  /// **'Umsatz'**
  String get statisticsTabRevenue;

  /// No description provided for @statisticsTabBuyers.
  ///
  /// In de, this message translates to:
  /// **'Käufer'**
  String get statisticsTabBuyers;

  /// No description provided for @statisticsTabShops.
  ///
  /// In de, this message translates to:
  /// **'Shops'**
  String get statisticsTabShops;

  /// No description provided for @statisticsTabInventory.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get statisticsTabInventory;

  /// No description provided for @statisticsTabCashflow.
  ///
  /// In de, this message translates to:
  /// **'Cashflow'**
  String get statisticsTabCashflow;

  /// No description provided for @statisticsTabTax.
  ///
  /// In de, this message translates to:
  /// **'Steuer'**
  String get statisticsTabTax;

  /// No description provided for @csvExportToolbar.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get csvExportToolbar;

  /// No description provided for @csvImportToolbar.
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get csvImportToolbar;

  /// No description provided for @buyerEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Käufer bearbeiten'**
  String get buyerEditTitle;

  /// No description provided for @buyerNewTitle.
  ///
  /// In de, this message translates to:
  /// **'Neuer Käufer'**
  String get buyerNewTitle;

  /// No description provided for @buyerSortOrder.
  ///
  /// In de, this message translates to:
  /// **'Sortierreihenfolge'**
  String get buyerSortOrder;

  /// No description provided for @buyerActive.
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get buyerActive;

  /// No description provided for @buyerColorBlue.
  ///
  /// In de, this message translates to:
  /// **'Blau'**
  String get buyerColorBlue;

  /// No description provided for @buyerColorOrange.
  ///
  /// In de, this message translates to:
  /// **'Orange'**
  String get buyerColorOrange;

  /// No description provided for @buyerColorGreen.
  ///
  /// In de, this message translates to:
  /// **'Grün'**
  String get buyerColorGreen;

  /// No description provided for @buyerColorPurple.
  ///
  /// In de, this message translates to:
  /// **'Lila'**
  String get buyerColorPurple;

  /// No description provided for @buyerColorYellow.
  ///
  /// In de, this message translates to:
  /// **'Gelb'**
  String get buyerColorYellow;

  /// No description provided for @buyerColorRed.
  ///
  /// In de, this message translates to:
  /// **'Rot'**
  String get buyerColorRed;

  /// No description provided for @buyerColorTeal.
  ///
  /// In de, this message translates to:
  /// **'Teal'**
  String get buyerColorTeal;

  /// No description provided for @buyerColorPink.
  ///
  /// In de, this message translates to:
  /// **'Pink'**
  String get buyerColorPink;

  /// No description provided for @buyerPreview.
  ///
  /// In de, this message translates to:
  /// **'Vorschau'**
  String get buyerPreview;

  /// No description provided for @buyerSampleProduct.
  ///
  /// In de, this message translates to:
  /// **'Beispiel-Produkt'**
  String get buyerSampleProduct;

  /// No description provided for @buyerDiscordIds.
  ///
  /// In de, this message translates to:
  /// **'Discord Server IDs'**
  String get buyerDiscordIds;

  /// No description provided for @buyerAddIdLabel.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get buyerAddIdLabel;

  /// No description provided for @buyerRemoveTooltip.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get buyerRemoveTooltip;

  /// No description provided for @shopEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Shop bearbeiten'**
  String get shopEditTitle;

  /// No description provided for @shopNewTitle.
  ///
  /// In de, this message translates to:
  /// **'Neuer Shop'**
  String get shopNewTitle;

  /// No description provided for @shopRegion.
  ///
  /// In de, this message translates to:
  /// **'Region'**
  String get shopRegion;

  /// No description provided for @shopChannel.
  ///
  /// In de, this message translates to:
  /// **'Kanal'**
  String get shopChannel;

  /// No description provided for @shopActive.
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get shopActive;

  /// No description provided for @batchesNew.
  ///
  /// In de, this message translates to:
  /// **'Neue Charge'**
  String get batchesNew;

  /// No description provided for @batchesAdd.
  ///
  /// In de, this message translates to:
  /// **'Charge hinzufügen'**
  String get batchesAdd;

  /// No description provided for @batchesNoMhd.
  ///
  /// In de, this message translates to:
  /// **'Ohne MHD'**
  String get batchesNoMhd;

  /// No description provided for @attachmentTitle.
  ///
  /// In de, this message translates to:
  /// **'Bilder'**
  String get attachmentTitle;

  /// No description provided for @attachmentTakePhoto.
  ///
  /// In de, this message translates to:
  /// **'Foto aufnehmen'**
  String get attachmentTakePhoto;

  /// No description provided for @attachmentPickGallery.
  ///
  /// In de, this message translates to:
  /// **'Aus Galerie wählen'**
  String get attachmentPickGallery;

  /// No description provided for @barcodeScannerTitle.
  ///
  /// In de, this message translates to:
  /// **'Barcode scannen'**
  String get barcodeScannerTitle;

  /// No description provided for @barcodeScannerNoCamera.
  ///
  /// In de, this message translates to:
  /// **'Kamera nicht verfügbar'**
  String get barcodeScannerNoCamera;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In de, this message translates to:
  /// **'Schwach'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthMedium.
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get passwordStrengthMedium;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In de, this message translates to:
  /// **'Stark'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordStrengthVeryStrong.
  ///
  /// In de, this message translates to:
  /// **'Sehr stark'**
  String get passwordStrengthVeryStrong;

  /// No description provided for @summaryHeading.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get summaryHeading;

  /// No description provided for @summaryByBuyer.
  ///
  /// In de, this message translates to:
  /// **'Nach Käufer'**
  String get summaryByBuyer;

  /// No description provided for @summaryByStatus.
  ///
  /// In de, this message translates to:
  /// **'Nach Status'**
  String get summaryByStatus;

  /// No description provided for @statsLabelRevenue.
  ///
  /// In de, this message translates to:
  /// **'Umsatz'**
  String get statsLabelRevenue;

  /// No description provided for @statsLabelProfit.
  ///
  /// In de, this message translates to:
  /// **'Profit'**
  String get statsLabelProfit;

  /// No description provided for @statsLabelMargin.
  ///
  /// In de, this message translates to:
  /// **'Marge'**
  String get statsLabelMargin;

  /// No description provided for @statsAllDeals.
  ///
  /// In de, this message translates to:
  /// **'Alle Deals'**
  String get statsAllDeals;

  /// No description provided for @statsProfitPerMonth.
  ///
  /// In de, this message translates to:
  /// **'Profit pro Monat'**
  String get statsProfitPerMonth;

  /// No description provided for @statsTabOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get statsTabOverview;

  /// No description provided for @statsTabBuyers.
  ///
  /// In de, this message translates to:
  /// **'Käufer'**
  String get statsTabBuyers;

  /// No description provided for @statsTabProductsShops.
  ///
  /// In de, this message translates to:
  /// **'Produkte & Shops'**
  String get statsTabProductsShops;

  /// No description provided for @statsTabInventorySuppliers.
  ///
  /// In de, this message translates to:
  /// **'Lager & Lieferanten'**
  String get statsTabInventorySuppliers;

  /// No description provided for @statsTabFinance.
  ///
  /// In de, this message translates to:
  /// **'Finanzen'**
  String get statsTabFinance;

  /// No description provided for @statsExportPdfTitle.
  ///
  /// In de, this message translates to:
  /// **'PDF-Übersicht'**
  String get statsExportPdfTitle;

  /// No description provided for @statsExportPdfDesc.
  ///
  /// In de, this message translates to:
  /// **'Einseitiger Report mit KPIs, Produkten, Käufern, Cashflow'**
  String get statsExportPdfDesc;

  /// No description provided for @statsExportXlsxTitle.
  ///
  /// In de, this message translates to:
  /// **'Excel (XLSX)'**
  String get statsExportXlsxTitle;

  /// No description provided for @statsExportXlsxDesc.
  ///
  /// In de, this message translates to:
  /// **'Roh-Daten der gefilterten Deals'**
  String get statsExportXlsxDesc;

  /// No description provided for @statsExportCsvTitle.
  ///
  /// In de, this message translates to:
  /// **'CSV'**
  String get statsExportCsvTitle;

  /// No description provided for @statsExportCsvDesc.
  ///
  /// In de, this message translates to:
  /// **'Roh-Daten der gefilterten Deals'**
  String get statsExportCsvDesc;

  /// No description provided for @statsExportPrintTitle.
  ///
  /// In de, this message translates to:
  /// **'Drucken / Vorschau'**
  String get statsExportPrintTitle;

  /// No description provided for @statsReportExported.
  ///
  /// In de, this message translates to:
  /// **'Report exportiert.'**
  String get statsReportExported;

  /// No description provided for @statsExportFailed.
  ///
  /// In de, this message translates to:
  /// **'Export fehlgeschlagen: {error}'**
  String statsExportFailed(Object error);

  /// No description provided for @statsTaxExportSaved.
  ///
  /// In de, this message translates to:
  /// **'MwSt-Export gespeichert.'**
  String get statsTaxExportSaved;

  /// No description provided for @globalSearchKeyNav.
  ///
  /// In de, this message translates to:
  /// **'Navigieren'**
  String get globalSearchKeyNav;

  /// No description provided for @globalSearchKeyOpen.
  ///
  /// In de, this message translates to:
  /// **'Öffnen'**
  String get globalSearchKeyOpen;

  /// No description provided for @globalSearchKeyClose.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get globalSearchKeyClose;

  /// No description provided for @searchRecentTitle.
  ///
  /// In de, this message translates to:
  /// **'Letzte Suchen'**
  String get searchRecentTitle;

  /// No description provided for @searchRecentEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Suchen'**
  String get searchRecentEmpty;

  /// No description provided for @searchRecentClear.
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get searchRecentClear;

  /// No description provided for @buyerLegendTitle.
  ///
  /// In de, this message translates to:
  /// **'Käufer'**
  String get buyerLegendTitle;

  /// No description provided for @statsCompareToPrevious.
  ///
  /// In de, this message translates to:
  /// **'vs. Vorperiode'**
  String get statsCompareToPrevious;

  /// No description provided for @statsExportReport.
  ///
  /// In de, this message translates to:
  /// **'Report'**
  String get statsExportReport;

  /// No description provided for @statsCashflow.
  ///
  /// In de, this message translates to:
  /// **'Cashflow'**
  String get statsCashflow;

  /// No description provided for @statsReceived.
  ///
  /// In de, this message translates to:
  /// **'Eingegangen'**
  String get statsReceived;

  /// No description provided for @statsOutstanding.
  ///
  /// In de, this message translates to:
  /// **'Ausstehend'**
  String get statsOutstanding;

  /// No description provided for @statsAgingHeading.
  ///
  /// In de, this message translates to:
  /// **'Forderungen nach Alter'**
  String get statsAgingHeading;

  /// No description provided for @statsOldestOpen.
  ///
  /// In de, this message translates to:
  /// **'Älteste offene'**
  String get statsOldestOpen;

  /// No description provided for @statsQuarter.
  ///
  /// In de, this message translates to:
  /// **'Quartal'**
  String get statsQuarter;

  /// No description provided for @statsCurrency.
  ///
  /// In de, this message translates to:
  /// **'Währung'**
  String get statsCurrency;

  /// No description provided for @statsNet.
  ///
  /// In de, this message translates to:
  /// **'Netto'**
  String get statsNet;

  /// No description provided for @statsTax.
  ///
  /// In de, this message translates to:
  /// **'MwSt'**
  String get statsTax;

  /// No description provided for @statsGross.
  ///
  /// In de, this message translates to:
  /// **'Brutto'**
  String get statsGross;

  /// No description provided for @statsCurrentMonth.
  ///
  /// In de, this message translates to:
  /// **'Aktueller Monat'**
  String get statsCurrentMonth;

  /// No description provided for @statsCurrent.
  ///
  /// In de, this message translates to:
  /// **'Aktuell'**
  String get statsCurrent;

  /// No description provided for @statsTarget.
  ///
  /// In de, this message translates to:
  /// **'Ziel'**
  String get statsTarget;

  /// No description provided for @statsForecast.
  ///
  /// In de, this message translates to:
  /// **'Forecast'**
  String get statsForecast;

  /// No description provided for @statsGoalNotMet.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht erreicht'**
  String get statsGoalNotMet;

  /// No description provided for @statsGoalsInRow.
  ///
  /// In de, this message translates to:
  /// **'Ziele in Folge erreicht'**
  String get statsGoalsInRow;

  /// No description provided for @statsOpenReceivables.
  ///
  /// In de, this message translates to:
  /// **'Offene Forderungen'**
  String get statsOpenReceivables;

  /// No description provided for @statsDealCount.
  ///
  /// In de, this message translates to:
  /// **'Anzahl Deals'**
  String get statsDealCount;

  /// No description provided for @statsProfitPerBucket.
  ///
  /// In de, this message translates to:
  /// **'Profit pro Bucket'**
  String get statsProfitPerBucket;

  /// No description provided for @statsProfitByBuyer.
  ///
  /// In de, this message translates to:
  /// **'Profit nach Käufer'**
  String get statsProfitByBuyer;

  /// No description provided for @statsRevenueByShop.
  ///
  /// In de, this message translates to:
  /// **'Umsatz nach Shop'**
  String get statsRevenueByShop;

  /// No description provided for @statsTotal.
  ///
  /// In de, this message translates to:
  /// **'GESAMT'**
  String get statsTotal;

  /// No description provided for @statsBuyerLabel.
  ///
  /// In de, this message translates to:
  /// **'Käufer'**
  String get statsBuyerLabel;

  /// No description provided for @statsDealsLabel.
  ///
  /// In de, this message translates to:
  /// **'Deals'**
  String get statsDealsLabel;

  /// No description provided for @statsOpenLabel.
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get statsOpenLabel;

  /// No description provided for @statsFrequency.
  ///
  /// In de, this message translates to:
  /// **'Frequenz'**
  String get statsFrequency;

  /// No description provided for @statsFirst.
  ///
  /// In de, this message translates to:
  /// **'First'**
  String get statsFirst;

  /// No description provided for @statsLast.
  ///
  /// In de, this message translates to:
  /// **'Last'**
  String get statsLast;

  /// No description provided for @statsActiveDays.
  ///
  /// In de, this message translates to:
  /// **'Tage aktiv'**
  String get statsActiveDays;

  /// No description provided for @statsHealthHeading.
  ///
  /// In de, this message translates to:
  /// **'Lager-Gesundheit'**
  String get statsHealthHeading;

  /// No description provided for @statsStockValueEk.
  ///
  /// In de, this message translates to:
  /// **'Lagerwert (EK)'**
  String get statsStockValueEk;

  /// No description provided for @statsLowStock.
  ///
  /// In de, this message translates to:
  /// **'Niedriger Bestand'**
  String get statsLowStock;

  /// No description provided for @statsLowStockHint.
  ///
  /// In de, this message translates to:
  /// **'Items unter Schwellwert'**
  String get statsLowStockHint;

  /// No description provided for @statsExpiringSoon.
  ///
  /// In de, this message translates to:
  /// **'Bald ablaufend'**
  String get statsExpiringSoon;

  /// No description provided for @statsExpiringSoonHint.
  ///
  /// In de, this message translates to:
  /// **'Chargen mit MHD < 30 Tage'**
  String get statsExpiringSoonHint;

  /// No description provided for @statsExpired.
  ///
  /// In de, this message translates to:
  /// **'Abgelaufen'**
  String get statsExpired;

  /// No description provided for @statsDeadStock.
  ///
  /// In de, this message translates to:
  /// **'Tote Bestände'**
  String get statsDeadStock;

  /// No description provided for @statsDeadStockHint.
  ///
  /// In de, this message translates to:
  /// **'Kein Verkauf seit > 90 Tagen'**
  String get statsDeadStockHint;

  /// No description provided for @statsSupplierPerformance.
  ///
  /// In de, this message translates to:
  /// **'Lieferanten-Performance'**
  String get statsSupplierPerformance;

  /// No description provided for @statsItems.
  ///
  /// In de, this message translates to:
  /// **'Items'**
  String get statsItems;

  /// No description provided for @statsStockValueShort.
  ///
  /// In de, this message translates to:
  /// **'Lagerwert'**
  String get statsStockValueShort;

  /// No description provided for @statsAvgEk.
  ///
  /// In de, this message translates to:
  /// **'Ø EK'**
  String get statsAvgEk;

  /// No description provided for @inboxMarkAllRead.
  ///
  /// In de, this message translates to:
  /// **'Alle als gelesen markieren'**
  String get inboxMarkAllRead;

  /// No description provided for @inboxMarkAllReadTooltip.
  ///
  /// In de, this message translates to:
  /// **'Alle als gelesen markieren ({count})'**
  String inboxMarkAllReadTooltip(int count);

  /// No description provided for @inboxMarkAllReadConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Alle als gelesen markieren?'**
  String get inboxMarkAllReadConfirmTitle;

  /// No description provided for @inboxMarkAllReadConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'{count} ungelesene Einträge werden als gelesen markiert. Vorschläge und Mails bleiben in der Inbox.'**
  String inboxMarkAllReadConfirmBody(int count);

  /// No description provided for @inboxMarkAllReadSuccess.
  ///
  /// In de, this message translates to:
  /// **'{count} Einträge als gelesen markiert.'**
  String inboxMarkAllReadSuccess(int count);

  /// No description provided for @inboxMarkAllReadFailure.
  ///
  /// In de, this message translates to:
  /// **'Markieren fehlgeschlagen: {error}'**
  String inboxMarkAllReadFailure(Object error);

  /// No description provided for @inboxUnreadBadge.
  ///
  /// In de, this message translates to:
  /// **'{count} neu'**
  String inboxUnreadBadge(int count);

  /// No description provided for @invitesBellTooltip.
  ///
  /// In de, this message translates to:
  /// **'Einladungen'**
  String get invitesBellTooltip;

  /// No description provided for @invitesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine offenen Einladungen.'**
  String get invitesEmpty;

  /// No description provided for @invitesHeader.
  ///
  /// In de, this message translates to:
  /// **'Workspace-Einladungen'**
  String get invitesHeader;

  /// No description provided for @invitesFrom.
  ///
  /// In de, this message translates to:
  /// **'Eingeladen von Workspace'**
  String get invitesFrom;

  /// No description provided for @invitesAccept.
  ///
  /// In de, this message translates to:
  /// **'Beitreten'**
  String get invitesAccept;

  /// No description provided for @invitesDecline.
  ///
  /// In de, this message translates to:
  /// **'Ablehnen'**
  String get invitesDecline;

  /// No description provided for @invitesAcceptedSnack.
  ///
  /// In de, this message translates to:
  /// **'Workspace beigetreten.'**
  String get invitesAcceptedSnack;

  /// No description provided for @invitesDeclinedSnack.
  ///
  /// In de, this message translates to:
  /// **'Einladung abgelehnt.'**
  String get invitesDeclinedSnack;

  /// No description provided for @invitesAcceptFailed.
  ///
  /// In de, this message translates to:
  /// **'Beitritt fehlgeschlagen: {error}'**
  String invitesAcceptFailed(Object error);

  /// No description provided for @invitesExpiresOn.
  ///
  /// In de, this message translates to:
  /// **'Läuft am {date} ab'**
  String invitesExpiresOn(Object date);

  /// No description provided for @invitesRoleLabel.
  ///
  /// In de, this message translates to:
  /// **'Rolle: {role}'**
  String invitesRoleLabel(Object role);

  /// No description provided for @settingsPaletteSection.
  ///
  /// In de, this message translates to:
  /// **'Farbpalette'**
  String get settingsPaletteSection;

  /// No description provided for @settingsPaletteBlue.
  ///
  /// In de, this message translates to:
  /// **'Blau'**
  String get settingsPaletteBlue;

  /// No description provided for @settingsPaletteIndigo.
  ///
  /// In de, this message translates to:
  /// **'Indigo'**
  String get settingsPaletteIndigo;

  /// No description provided for @settingsPaletteViolet.
  ///
  /// In de, this message translates to:
  /// **'Violett'**
  String get settingsPaletteViolet;

  /// No description provided for @settingsPaletteTeal.
  ///
  /// In de, this message translates to:
  /// **'Petrol'**
  String get settingsPaletteTeal;

  /// No description provided for @settingsPaletteRose.
  ///
  /// In de, this message translates to:
  /// **'Rose'**
  String get settingsPaletteRose;

  /// No description provided for @settingsThemeSection.
  ///
  /// In de, this message translates to:
  /// **'Erscheinungsbild'**
  String get settingsThemeSection;

  /// No description provided for @settingsThemeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @publicProfileTab.
  ///
  /// In de, this message translates to:
  /// **'Öffentliches Profil'**
  String get publicProfileTab;

  /// No description provided for @publicProfileSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Verkaufsseite'**
  String get publicProfileSectionTitle;

  /// No description provided for @publicProfileSectionDesc.
  ///
  /// In de, this message translates to:
  /// **'Aktiviere eine öffentliche Seite mit deinem Lagerbestand. Anfragen erreichen dich per Mail.'**
  String get publicProfileSectionDesc;

  /// No description provided for @publicProfileEnableLabel.
  ///
  /// In de, this message translates to:
  /// **'Öffentliches Profil aktiv'**
  String get publicProfileEnableLabel;

  /// No description provided for @publicProfileHandleLabel.
  ///
  /// In de, this message translates to:
  /// **'Handle'**
  String get publicProfileHandleLabel;

  /// No description provided for @publicProfileHandleHint.
  ///
  /// In de, this message translates to:
  /// **'z.B. mein-laden'**
  String get publicProfileHandleHint;

  /// No description provided for @publicProfileHandleHelp.
  ///
  /// In de, this message translates to:
  /// **'Kleinbuchstaben, Zahlen und Bindestriche, 3–32 Zeichen. Erreichbar unter /u/<handle>.'**
  String get publicProfileHandleHelp;

  /// No description provided for @publicProfileHandleInvalid.
  ///
  /// In de, this message translates to:
  /// **'Nur a-z, 0-9 und Bindestrich. 3–32 Zeichen, nicht mit \"-\" beginnen oder enden.'**
  String get publicProfileHandleInvalid;

  /// No description provided for @publicProfileHandleTaken.
  ///
  /// In de, this message translates to:
  /// **'Handle bereits vergeben.'**
  String get publicProfileHandleTaken;

  /// No description provided for @publicProfileSaved.
  ///
  /// In de, this message translates to:
  /// **'Profil aktualisiert.'**
  String get publicProfileSaved;

  /// No description provided for @publicProfileSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen: {error}'**
  String publicProfileSaveFailed(Object error);

  /// No description provided for @publicProfileNeedsHandle.
  ///
  /// In de, this message translates to:
  /// **'Lege zuerst einen Handle fest, um das Profil zu aktivieren.'**
  String get publicProfileNeedsHandle;

  /// No description provided for @publicProfileLink.
  ///
  /// In de, this message translates to:
  /// **'Öffentlicher Link'**
  String get publicProfileLink;

  /// No description provided for @publicProfileCopyLink.
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get publicProfileCopyLink;

  /// No description provided for @publicProfileLinkCopied.
  ///
  /// In de, this message translates to:
  /// **'Link kopiert.'**
  String get publicProfileLinkCopied;

  /// No description provided for @publicProfileItemsTitle.
  ///
  /// In de, this message translates to:
  /// **'Sichtbare Artikel'**
  String get publicProfileItemsTitle;

  /// No description provided for @publicProfileItemsHint.
  ///
  /// In de, this message translates to:
  /// **'Tippe einen Artikel an, um ihn auf der Verkaufsseite zu zeigen oder zu verstecken.'**
  String get publicProfileItemsHint;

  /// No description provided for @publicProfileItemPublic.
  ///
  /// In de, this message translates to:
  /// **'Öffentlich'**
  String get publicProfileItemPublic;

  /// No description provided for @publicProfileNoEligibleItems.
  ///
  /// In de, this message translates to:
  /// **'Keine Artikel im Lager. Lege zuerst Bestand an.'**
  String get publicProfileNoEligibleItems;

  /// No description provided for @publicProfileNotFoundTitle.
  ///
  /// In de, this message translates to:
  /// **'Profil nicht gefunden'**
  String get publicProfileNotFoundTitle;

  /// No description provided for @publicProfileNotFoundBody.
  ///
  /// In de, this message translates to:
  /// **'Diese Verkaufsseite existiert nicht oder ist nicht öffentlich.'**
  String get publicProfileNotFoundBody;

  /// No description provided for @publicProfileEmptyItems.
  ///
  /// In de, this message translates to:
  /// **'Aktuell sind keine Artikel verfügbar.'**
  String get publicProfileEmptyItems;

  /// No description provided for @publicProfileContact.
  ///
  /// In de, this message translates to:
  /// **'Anfrage senden'**
  String get publicProfileContact;

  /// No description provided for @publicProfileContactSubject.
  ///
  /// In de, this message translates to:
  /// **'Anfrage zu deinem Angebot'**
  String get publicProfileContactSubject;

  /// No description provided for @publicProfileItemPrice.
  ///
  /// In de, this message translates to:
  /// **'Preis'**
  String get publicProfileItemPrice;

  /// No description provided for @publicProfileItemQuantity.
  ///
  /// In de, this message translates to:
  /// **'Verfügbar: {count}'**
  String publicProfileItemQuantity(int count);

  /// No description provided for @publicProfileFooter.
  ///
  /// In de, this message translates to:
  /// **'Erstellt mit InventoryOS'**
  String get publicProfileFooter;

  /// No description provided for @settingsDemoSection.
  ///
  /// In de, this message translates to:
  /// **'Demo / Daten'**
  String get settingsDemoSection;

  /// No description provided for @settingsDemoReloadTitle.
  ///
  /// In de, this message translates to:
  /// **'Demo-Daten neu laden'**
  String get settingsDemoReloadTitle;

  /// No description provided for @settingsDemoReloadDescription.
  ///
  /// In de, this message translates to:
  /// **'Setzt diesen Workspace zurück und füllt ihn mit 30–50 realistischen Beispiel-Deals aus deinen Mails der letzten 90 Tage. Alle aktuellen Daten gehen verloren.'**
  String get settingsDemoReloadDescription;

  /// No description provided for @settingsDemoReload.
  ///
  /// In de, this message translates to:
  /// **'Demo neu laden'**
  String get settingsDemoReload;

  /// No description provided for @settingsDemoReloadConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Demo-Daten neu laden?'**
  String get settingsDemoReloadConfirmTitle;

  /// No description provided for @settingsDemoReloadConfirm.
  ///
  /// In de, this message translates to:
  /// **'Dieser Workspace wird zurückgesetzt und mit frischen Demo-Daten gefüllt. Alle aktuellen Deals, Käufer, Shops und Lagerartikel gehen verloren. Fortfahren?'**
  String get settingsDemoReloadConfirm;

  /// No description provided for @settingsDemoReloadSuccess.
  ///
  /// In de, this message translates to:
  /// **'Demo-Daten neu geladen.'**
  String get settingsDemoReloadSuccess;

  /// No description provided for @settingsDemoReloadError.
  ///
  /// In de, this message translates to:
  /// **'Demo-Reload fehlgeschlagen: {error}'**
  String settingsDemoReloadError(Object error);

  /// No description provided for @onboardingSkip.
  ///
  /// In de, this message translates to:
  /// **'Überspringen'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get onboardingNext;

  /// No description provided for @onboardingBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get onboardingBack;

  /// No description provided for @onboardingFinish.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get onboardingFinish;

  /// No description provided for @onboardingStepWelcomeTitle.
  ///
  /// In de, this message translates to:
  /// **'Willkommen'**
  String get onboardingStepWelcomeTitle;

  /// No description provided for @onboardingStepWelcomeSubtitle.
  ///
  /// In de, this message translates to:
  /// **'InventoryOS hilft dir, Bestellungen, Lager und Käufer im Blick zu behalten. Wir richten dich in 6 kurzen Schritten ein.'**
  String get onboardingStepWelcomeSubtitle;

  /// No description provided for @onboardingStepWorkspaceTitle.
  ///
  /// In de, this message translates to:
  /// **'Dein Workspace'**
  String get onboardingStepWorkspaceTitle;

  /// No description provided for @onboardingStepWorkspaceSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Alle Daten landen in einem Workspace. Du kannst später Team-Mitglieder einladen oder weitere Workspaces anlegen.'**
  String get onboardingStepWorkspaceSubtitle;

  /// No description provided for @onboardingWorkspaceFallback.
  ///
  /// In de, this message translates to:
  /// **'Mein Workspace'**
  String get onboardingWorkspaceFallback;

  /// No description provided for @onboardingWorkspaceReady.
  ///
  /// In de, this message translates to:
  /// **'Bereit. Dieser Workspace gehört dir.'**
  String get onboardingWorkspaceReady;

  /// No description provided for @onboardingStepShopsTitle.
  ///
  /// In de, this message translates to:
  /// **'Welche Shops nutzt du?'**
  String get onboardingStepShopsTitle;

  /// No description provided for @onboardingStepShopsSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wähle die Shops, von denen du regelmäßig bestellst. Du kannst später jederzeit weitere hinzufügen.'**
  String get onboardingStepShopsSubtitle;

  /// No description provided for @onboardingStepSuppliersTitle.
  ///
  /// In de, this message translates to:
  /// **'Wer sind deine Lieferanten?'**
  String get onboardingStepSuppliersTitle;

  /// No description provided for @onboardingStepSuppliersSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Optional. Trage deine wichtigsten Lieferanten ein, damit Lagerartikel direkt zugeordnet werden können.'**
  String get onboardingStepSuppliersSubtitle;

  /// No description provided for @onboardingSuppliersHint.
  ///
  /// In de, this message translates to:
  /// **'Lieferanten-Name'**
  String get onboardingSuppliersHint;

  /// No description provided for @onboardingSuppliersAdd.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get onboardingSuppliersAdd;

  /// No description provided for @onboardingStepFirstTicketTitle.
  ///
  /// In de, this message translates to:
  /// **'Erstes Ticket anlegen'**
  String get onboardingStepFirstTicketTitle;

  /// No description provided for @onboardingStepFirstTicketSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Optional. Lege gleich einen ersten Deal an, damit dein Dashboard nicht leer ist. Du kannst diesen Schritt überspringen.'**
  String get onboardingStepFirstTicketSubtitle;

  /// No description provided for @onboardingFirstTicketProductHint.
  ///
  /// In de, this message translates to:
  /// **'Produkt (z.B. AirPods Pro 2)'**
  String get onboardingFirstTicketProductHint;

  /// No description provided for @onboardingFirstTicketQuantity.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get onboardingFirstTicketQuantity;

  /// No description provided for @onboardingFirstTicketShop.
  ///
  /// In de, this message translates to:
  /// **'Shop'**
  String get onboardingFirstTicketShop;

  /// No description provided for @onboardingStepOutroTitle.
  ///
  /// In de, this message translates to:
  /// **'Fast geschafft!'**
  String get onboardingStepOutroTitle;

  /// No description provided for @onboardingStepOutroSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Diese Funktionen findest du in den Einstellungen — kein Stress, du musst sie nicht sofort einrichten:'**
  String get onboardingStepOutroSubtitle;

  /// No description provided for @onboardingOutroDiscord.
  ///
  /// In de, this message translates to:
  /// **'Discord-Server verbinden, um Käufer-Bountys automatisch zuzuordnen.'**
  String get onboardingOutroDiscord;

  /// No description provided for @onboardingOutroInbox.
  ///
  /// In de, this message translates to:
  /// **'Postfach verbinden — Bestellbestätigungen werden dann automatisch erkannt.'**
  String get onboardingOutroInbox;

  /// No description provided for @onboardingOutroDemo.
  ///
  /// In de, this message translates to:
  /// **'Wenn du dich erstmal umsehen willst: \'Beispiel-Daten laden\' auf dem Dashboard.'**
  String get onboardingOutroDemo;

  /// No description provided for @onboardingErrorNoWorkspace.
  ///
  /// In de, this message translates to:
  /// **'Kein aktiver Workspace gefunden. Bitte ausloggen und erneut anmelden.'**
  String get onboardingErrorNoWorkspace;

  /// No description provided for @onboardingErrorGeneric.
  ///
  /// In de, this message translates to:
  /// **'Onboarding fehlgeschlagen: {error}'**
  String onboardingErrorGeneric(Object error);

  /// No description provided for @dashboardEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Daten'**
  String get dashboardEmptyTitle;

  /// No description provided for @dashboardEmptySubtitle.
  ///
  /// In de, this message translates to:
  /// **'Lade ein paar Beispiel-Tickets, Käufer und Lagerartikel, um dich in der App zurechtzufinden.'**
  String get dashboardEmptySubtitle;

  /// No description provided for @dashboardEmptyLoadDemo.
  ///
  /// In de, this message translates to:
  /// **'Beispiel-Daten laden'**
  String get dashboardEmptyLoadDemo;

  /// No description provided for @dashboardDemoLoadSuccess.
  ///
  /// In de, this message translates to:
  /// **'{count} Beispiel-Einträge geladen.'**
  String dashboardDemoLoadSuccess(int count);

  /// No description provided for @dashboardDemoLoadError.
  ///
  /// In de, this message translates to:
  /// **'Beispiel-Daten konnten nicht geladen werden: {error}'**
  String dashboardDemoLoadError(Object error);

  /// No description provided for @settingsDemoWipeSection.
  ///
  /// In de, this message translates to:
  /// **'Beispiel-Daten'**
  String get settingsDemoWipeSection;

  /// No description provided for @settingsDemoWipeTitle.
  ///
  /// In de, this message translates to:
  /// **'Demo-Daten löschen'**
  String get settingsDemoWipeTitle;

  /// No description provided for @settingsDemoWipeDescription.
  ///
  /// In de, this message translates to:
  /// **'Entfernt nur die Einträge, die der \'Beispiel-Daten laden\'-Button erstellt hat. Eigene Daten bleiben unangetastet.'**
  String get settingsDemoWipeDescription;

  /// No description provided for @settingsDemoWipe.
  ///
  /// In de, this message translates to:
  /// **'Demo-Daten löschen'**
  String get settingsDemoWipe;

  /// No description provided for @settingsDemoWipeConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Demo-Daten löschen?'**
  String get settingsDemoWipeConfirmTitle;

  /// No description provided for @settingsDemoWipeConfirm.
  ///
  /// In de, this message translates to:
  /// **'Alle Einträge, die als Beispiel-Daten markiert sind, werden entfernt. Fortfahren?'**
  String get settingsDemoWipeConfirm;

  /// No description provided for @settingsDemoWipeSuccess.
  ///
  /// In de, this message translates to:
  /// **'{count} Demo-Einträge gelöscht.'**
  String settingsDemoWipeSuccess(int count);

  /// No description provided for @settingsDemoWipeError.
  ///
  /// In de, this message translates to:
  /// **'Löschen fehlgeschlagen: {error}'**
  String settingsDemoWipeError(Object error);

  /// No description provided for @trackingAmazonShipmentIdHint.
  ///
  /// In de, this message translates to:
  /// **'Amazon-interne Shipment-ID — kein vollwertiges Carrier-Tracking'**
  String get trackingAmazonShipmentIdHint;

  /// No description provided for @trackingBannerImprovedDetection.
  ///
  /// In de, this message translates to:
  /// **'Wir haben die Tracking-Erkennung verbessert. Bitte einmal in „Prüfen“ schauen.'**
  String get trackingBannerImprovedDetection;

  /// No description provided for @trackingCarrierAmazonLogisticsHintShort.
  ///
  /// In de, this message translates to:
  /// **'Amazon Logistics'**
  String get trackingCarrierAmazonLogisticsHintShort;

  /// No description provided for @trackingCarrierUnknown.
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Versender'**
  String get trackingCarrierUnknown;

  /// No description provided for @trackingConfidenceLabelManual.
  ///
  /// In de, this message translates to:
  /// **'Manuell'**
  String get trackingConfidenceLabelManual;

  /// No description provided for @trackingConfidenceLabelNone.
  ///
  /// In de, this message translates to:
  /// **'Unklar'**
  String get trackingConfidenceLabelNone;

  /// No description provided for @trackingConfidenceLabelStrong.
  ///
  /// In de, this message translates to:
  /// **'Verifiziert'**
  String get trackingConfidenceLabelStrong;

  /// No description provided for @trackingEnterManuallyCta.
  ///
  /// In de, this message translates to:
  /// **'Manuell eingeben'**
  String get trackingEnterManuallyCta;

  /// No description provided for @trackingNoneDetectedSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wir konnten in dieser Mail keine eindeutige Sendungsnummer finden.'**
  String get trackingNoneDetectedSubtitle;

  /// No description provided for @trackingNoneDetectedTitle.
  ///
  /// In de, this message translates to:
  /// **'Keine Sendungsnummer erkannt'**
  String get trackingNoneDetectedTitle;

  /// No description provided for @trackingReparseCta.
  ///
  /// In de, this message translates to:
  /// **'Sendungsnummern neu bewerten'**
  String get trackingReparseCta;

  /// No description provided for @trackingReparseConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'Bestehende Sendungsnummern werden mit der verbesserten Erkennung neu geprüft. Manuelle Einträge bleiben unverändert.'**
  String get trackingReparseConfirmBody;

  /// No description provided for @trackingReparseConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Neubewertung starten?'**
  String get trackingReparseConfirmTitle;

  /// No description provided for @trackingReparseFailed.
  ///
  /// In de, this message translates to:
  /// **'Neubewertung fehlgeschlagen'**
  String get trackingReparseFailed;

  /// No description provided for @trackingReparseOffline.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung — bitte später erneut versuchen'**
  String get trackingReparseOffline;

  /// No description provided for @trackingReparseRunning.
  ///
  /// In de, this message translates to:
  /// **'Sendungsnummern werden neu bewertet…'**
  String get trackingReparseRunning;

  /// Number of tracking numbers updated during a re-evaluation run
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Sendungsnummer aktualisiert} =1{1 Sendungsnummer aktualisiert} other{{count} Sendungsnummern aktualisiert}}'**
  String trackingReparseSuccessCount(int count);

  /// No description provided for @inboxResetCta.
  ///
  /// In de, this message translates to:
  /// **'Postfach zurücksetzen'**
  String get inboxResetCta;

  /// No description provided for @inboxResetSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Alle Mails löschen und neu importieren. Beim Re-Import wird jede Mail gegen die DHL-API geprüft. Nicht rückgängig zu machen.'**
  String get inboxResetSubtitle;

  /// No description provided for @inboxResetConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Postfach wirklich zurücksetzen?'**
  String get inboxResetConfirmTitle;

  /// No description provided for @inboxResetConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'Alle bisher importierten Mails werden gelöscht, der IMAP-Cursor wird zurückgesetzt und beim nächsten Poll werden alle Mails neu geladen. Deine Deals bleiben erhalten.\n\nZur Bestätigung tippe RESET ein.'**
  String get inboxResetConfirmBody;

  /// No description provided for @inboxResetConfirmInputLabel.
  ///
  /// In de, this message translates to:
  /// **'Tippe RESET zur Bestätigung'**
  String get inboxResetConfirmInputLabel;

  /// No description provided for @inboxResetRunning.
  ///
  /// In de, this message translates to:
  /// **'Postfach wird zurückgesetzt…'**
  String get inboxResetRunning;

  /// No description provided for @inboxResetFailed.
  ///
  /// In de, this message translates to:
  /// **'Reset fehlgeschlagen — bitte später erneut versuchen.'**
  String get inboxResetFailed;

  /// SnackBar nach erfolgreichem Inbox-Reset
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Mails gelöscht — IMAP-Cursor wurde zurückgesetzt.} =1{1 Mail gelöscht. Nächster Poll lädt alles neu.} other{{count} Mails gelöscht. Nächster Poll lädt alles neu.}}'**
  String inboxResetSuccess(int count);

  /// Filter chip label showing number of deals needing tracking review
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Prüfen (1)} other{Prüfen ({count})}}'**
  String trackingNeedsReviewFilterChip(int count);

  /// No description provided for @trackingReviewAcceptCta.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get trackingReviewAcceptCta;

  /// No description provided for @trackingReviewDismissCta.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get trackingReviewDismissCta;

  /// No description provided for @trackingReviewListTitle.
  ///
  /// In de, this message translates to:
  /// **'Sendungsnummern prüfen'**
  String get trackingReviewListTitle;

  /// No description provided for @trackingReviewNeededBadge.
  ///
  /// In de, this message translates to:
  /// **'Prüfen'**
  String get trackingReviewNeededBadge;

  /// No description provided for @trackingStatusBlockA11yLabel.
  ///
  /// In de, this message translates to:
  /// **'Sendungsnummern-Status'**
  String get trackingStatusBlockA11yLabel;

  /// No description provided for @trackingRetrackCta.
  ///
  /// In de, this message translates to:
  /// **'Status aktualisieren'**
  String get trackingRetrackCta;

  /// No description provided for @trackingRetrackRunning.
  ///
  /// In de, this message translates to:
  /// **'Status wird abgerufen…'**
  String get trackingRetrackRunning;

  /// No description provided for @trackingRetrackSuccess.
  ///
  /// In de, this message translates to:
  /// **'Status aktualisiert'**
  String get trackingRetrackSuccess;

  /// No description provided for @trackingRetrackRateLimited.
  ///
  /// In de, this message translates to:
  /// **'Bitte 30s warten'**
  String get trackingRetrackRateLimited;

  /// No description provided for @trackingRetrackFailed.
  ///
  /// In de, this message translates to:
  /// **'Status konnte nicht abgerufen werden'**
  String get trackingRetrackFailed;

  /// No description provided for @trackingRetrackOffline.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung'**
  String get trackingRetrackOffline;

  /// No description provided for @inboxSectionOrder.
  ///
  /// In de, this message translates to:
  /// **'Bestellung'**
  String get inboxSectionOrder;

  /// No description provided for @inboxSectionShipping.
  ///
  /// In de, this message translates to:
  /// **'Versand'**
  String get inboxSectionShipping;

  /// No description provided for @inboxSectionLinkedTo.
  ///
  /// In de, this message translates to:
  /// **'Verknüpft mit'**
  String get inboxSectionLinkedTo;

  /// No description provided for @inboxFieldOrderId.
  ///
  /// In de, this message translates to:
  /// **'Order-ID'**
  String get inboxFieldOrderId;

  /// No description provided for @inboxFieldProduct.
  ///
  /// In de, this message translates to:
  /// **'Produkt'**
  String get inboxFieldProduct;

  /// No description provided for @inboxFieldAmount.
  ///
  /// In de, this message translates to:
  /// **'Betrag'**
  String get inboxFieldAmount;

  /// No description provided for @inboxFieldEta.
  ///
  /// In de, this message translates to:
  /// **'ETA'**
  String get inboxFieldEta;

  /// No description provided for @inboxFieldDeal.
  ///
  /// In de, this message translates to:
  /// **'Deal'**
  String get inboxFieldDeal;

  /// No description provided for @dealTrackingStatusTitle.
  ///
  /// In de, this message translates to:
  /// **'Sendungsnummer'**
  String get dealTrackingStatusTitle;

  /// No description provided for @dealSectionTrackingStatus.
  ///
  /// In de, this message translates to:
  /// **'Sendungsstatus'**
  String get dealSectionTrackingStatus;

  /// No description provided for @trackingUpdateError.
  ///
  /// In de, this message translates to:
  /// **'Tracking-Update fehlgeschlagen: {error}'**
  String trackingUpdateError(Object error);

  /// No description provided for @trackingAcceptError.
  ///
  /// In de, this message translates to:
  /// **'Tracking-Akzeptanz fehlgeschlagen: {error}'**
  String trackingAcceptError(Object error);

  /// No description provided for @trackingDiscardError.
  ///
  /// In de, this message translates to:
  /// **'Tracking-Verwerfen fehlgeschlagen: {error}'**
  String trackingDiscardError(Object error);

  /// No description provided for @liveStatusPending.
  ///
  /// In de, this message translates to:
  /// **'Wird vorbereitet'**
  String get liveStatusPending;

  /// No description provided for @liveStatusInTransit.
  ///
  /// In de, this message translates to:
  /// **'Unterwegs'**
  String get liveStatusInTransit;

  /// No description provided for @liveStatusOutForDelivery.
  ///
  /// In de, this message translates to:
  /// **'In Zustellung'**
  String get liveStatusOutForDelivery;

  /// No description provided for @liveStatusDelivered.
  ///
  /// In de, this message translates to:
  /// **'Zugestellt'**
  String get liveStatusDelivered;

  /// No description provided for @liveStatusException.
  ///
  /// In de, this message translates to:
  /// **'Problem — bitte prüfen'**
  String get liveStatusException;

  /// No description provided for @liveStatusExpired.
  ///
  /// In de, this message translates to:
  /// **'Status veraltet'**
  String get liveStatusExpired;

  /// No description provided for @inboxFilterResetLabel.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get inboxFilterResetLabel;

  /// No description provided for @inboxFilterResetTitle.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen?'**
  String get inboxFilterResetTitle;

  /// No description provided for @inboxCopyMessageIdSnackbar.
  ///
  /// In de, this message translates to:
  /// **'Message-ID in die Zwischenablage kopiert.'**
  String get inboxCopyMessageIdSnackbar;

  /// No description provided for @inboxNoMailLinkSnackbar.
  ///
  /// In de, this message translates to:
  /// **'Kein Mail-Link verfügbar.'**
  String get inboxNoMailLinkSnackbar;

  /// No description provided for @inboxNoTrackingSnackbar.
  ///
  /// In de, this message translates to:
  /// **'Diese Mail enthält kein Tracking.'**
  String get inboxNoTrackingSnackbar;

  /// No description provided for @inboxOpenMailInBrowserMenuItem.
  ///
  /// In de, this message translates to:
  /// **'Mail im Browser öffnen'**
  String get inboxOpenMailInBrowserMenuItem;

  /// No description provided for @inboxOpenMailLabel.
  ///
  /// In de, this message translates to:
  /// **'Mail öffnen'**
  String get inboxOpenMailLabel;

  /// No description provided for @inboxOpenTicketLabel.
  ///
  /// In de, this message translates to:
  /// **'Ticket öffnen'**
  String get inboxOpenTicketLabel;

  /// No description provided for @inventoryDiscordTooltip.
  ///
  /// In de, this message translates to:
  /// **'Discord-Ticket öffnen'**
  String get inventoryDiscordTooltip;

  /// No description provided for @inventoryProductHelperText.
  ///
  /// In de, this message translates to:
  /// **'Aus Ticket auswählen oder frei eingeben'**
  String get inventoryProductHelperText;

  /// No description provided for @settingsAddAmazonShops.
  ///
  /// In de, this message translates to:
  /// **'Amazon-Shops hinzufügen'**
  String get settingsAddAmazonShops;

  /// No description provided for @suppliersAddCarriers.
  ///
  /// In de, this message translates to:
  /// **'Versanddienste hinzufügen'**
  String get suppliersAddCarriers;

  /// No description provided for @urlHelperLinkOpenError.
  ///
  /// In de, this message translates to:
  /// **'Link konnte nicht geöffnet werden.'**
  String get urlHelperLinkOpenError;

  /// No description provided for @inboxAcceptedSnack.
  ///
  /// In de, this message translates to:
  /// **'Tracking {tracking} → Deal #{dealId} übernommen'**
  String inboxAcceptedSnack(Object tracking, int dealId);

  /// No description provided for @inboxAcceptedSnackNoTracking.
  ///
  /// In de, this message translates to:
  /// **'Deal #{dealId} angelegt'**
  String inboxAcceptedSnackNoTracking(int dealId);

  /// No description provided for @inboxAcceptedShowDeal.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get inboxAcceptedShowDeal;

  /// No description provided for @inboxSuggestionDismiss.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get inboxSuggestionDismiss;

  /// No description provided for @inboxSuggestionEdit.
  ///
  /// In de, this message translates to:
  /// **'Vor Übernahme bearbeiten'**
  String get inboxSuggestionEdit;

  /// No description provided for @inboxSuggestionAccept.
  ///
  /// In de, this message translates to:
  /// **'Annehmen'**
  String get inboxSuggestionAccept;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
