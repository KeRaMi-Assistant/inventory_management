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

  /// No description provided for @inboxFilterAllShops.
  ///
  /// In de, this message translates to:
  /// **'Alle Shops'**
  String get inboxFilterAllShops;

  /// No description provided for @inboxFilterAllStatus.
  ///
  /// In de, this message translates to:
  /// **'Alle Status'**
  String get inboxFilterAllStatus;

  /// No description provided for @inboxFilterResetConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen?'**
  String get inboxFilterResetConfirmTitle;

  /// No description provided for @inboxFilterResetSuccess.
  ///
  /// In de, this message translates to:
  /// **'Verworfen-Filter geleert.'**
  String get inboxFilterResetSuccess;

  /// No description provided for @inboxFilterResetFailed.
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen fehlgeschlagen: {error}'**
  String inboxFilterResetFailed(Object error);

  /// No description provided for @inboxPolling.
  ///
  /// In de, this message translates to:
  /// **'Pollt das Postfach…'**
  String get inboxPolling;

  /// No description provided for @inboxPollingFailed.
  ///
  /// In de, this message translates to:
  /// **'Polling fehlgeschlagen: {error}'**
  String inboxPollingFailed(Object error);

  /// No description provided for @inboxMessageIdCopied.
  ///
  /// In de, this message translates to:
  /// **'Message-ID in die Zwischenablage kopiert.'**
  String get inboxMessageIdCopied;

  /// No description provided for @inboxNoMailLink.
  ///
  /// In de, this message translates to:
  /// **'Kein Mail-Link verfügbar.'**
  String get inboxNoMailLink;

  /// No description provided for @inboxDiscardTitle.
  ///
  /// In de, this message translates to:
  /// **'Mail verwerfen?'**
  String get inboxDiscardTitle;

  /// No description provided for @inboxDiscardAction.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get inboxDiscardAction;

  /// No description provided for @inboxDiscardSuccess.
  ///
  /// In de, this message translates to:
  /// **'Mail verworfen.'**
  String get inboxDiscardSuccess;

  /// No description provided for @inboxDiscardFailed.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen fehlgeschlagen: {error}'**
  String inboxDiscardFailed(Object error);

  /// No description provided for @inboxNoSuggestions.
  ///
  /// In de, this message translates to:
  /// **'Keine offenen Vorschläge.'**
  String get inboxNoSuggestions;

  /// No description provided for @inboxDealCreatedFromSuggestion.
  ///
  /// In de, this message translates to:
  /// **'Deal #{id} aus Vorschlag erstellt.'**
  String inboxDealCreatedFromSuggestion(int id);

  /// No description provided for @inboxSuggestionAcceptFailed.
  ///
  /// In de, this message translates to:
  /// **'Konnte Vorschlag nicht abschließen: {error}'**
  String inboxSuggestionAcceptFailed(Object error);

  /// No description provided for @inboxSuggestionRejectFailed.
  ///
  /// In de, this message translates to:
  /// **'Ablehnen fehlgeschlagen: {error}'**
  String inboxSuggestionRejectFailed(Object error);

  /// No description provided for @inboxNoTracking.
  ///
  /// In de, this message translates to:
  /// **'Diese Mail enthält kein Tracking.'**
  String get inboxNoTracking;

  /// No description provided for @inboxTrackingApplied.
  ///
  /// In de, this message translates to:
  /// **'Tracking auf Deal #{id} übernommen.'**
  String inboxTrackingApplied(int id);

  /// No description provided for @inboxTrackingApplyFailed.
  ///
  /// In de, this message translates to:
  /// **'Tracking-Übernahme fehlgeschlagen: {error}'**
  String inboxTrackingApplyFailed(Object error);

  /// No description provided for @inboxSuggestionLinked.
  ///
  /// In de, this message translates to:
  /// **'Vorschlag mit Deal #{id} verknüpft.'**
  String inboxSuggestionLinked(int id);

  /// No description provided for @inboxAssignFailed.
  ///
  /// In de, this message translates to:
  /// **'Zuweisung fehlgeschlagen: {error}'**
  String inboxAssignFailed(Object error);

  /// No description provided for @inboxActionsTooltip.
  ///
  /// In de, this message translates to:
  /// **'Aktionen'**
  String get inboxActionsTooltip;

  /// No description provided for @inboxApplyTrackingToDeal.
  ///
  /// In de, this message translates to:
  /// **'Tracking auf Deal anwenden'**
  String get inboxApplyTrackingToDeal;

  /// No description provided for @inboxAssignToExistingDeal.
  ///
  /// In de, this message translates to:
  /// **'Zu bestehendem Deal zuweisen'**
  String get inboxAssignToExistingDeal;

  /// No description provided for @inboxOpenInBrowser.
  ///
  /// In de, this message translates to:
  /// **'Mail im Browser öffnen'**
  String get inboxOpenInBrowser;

  /// No description provided for @inboxOpenMail.
  ///
  /// In de, this message translates to:
  /// **'Mail öffnen'**
  String get inboxOpenMail;

  /// No description provided for @inboxAcceptAndEdit.
  ///
  /// In de, this message translates to:
  /// **'Annehmen & bearbeiten'**
  String get inboxAcceptAndEdit;

  /// No description provided for @inboxAutoUpdatesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine automatisch aktualisierten Deals.'**
  String get inboxAutoUpdatesEmpty;

  /// No description provided for @inboxOpenTicket.
  ///
  /// In de, this message translates to:
  /// **'Ticket öffnen'**
  String get inboxOpenTicket;

  /// No description provided for @inboxAllSorted.
  ///
  /// In de, this message translates to:
  /// **'Alles eingeordnet — keine unklaren Mails.'**
  String get inboxAllSorted;

  /// No description provided for @inboxDealCreatedFromMail.
  ///
  /// In de, this message translates to:
  /// **'Deal #{id} aus Mail angelegt.'**
  String inboxDealCreatedFromMail(int id);

  /// No description provided for @inboxCreateDeal.
  ///
  /// In de, this message translates to:
  /// **'Deal anlegen'**
  String get inboxCreateDeal;

  /// No description provided for @inboxTrackingToDeal.
  ///
  /// In de, this message translates to:
  /// **'Tracking → Deal'**
  String get inboxTrackingToDeal;

  /// No description provided for @inboxShowDetails.
  ///
  /// In de, this message translates to:
  /// **'Details anzeigen'**
  String get inboxShowDetails;

  /// No description provided for @inboxTrackingNumberCopied.
  ///
  /// In de, this message translates to:
  /// **'Tracking-Nummer kopiert.'**
  String get inboxTrackingNumberCopied;

  /// No description provided for @pricingTitle.
  ///
  /// In de, this message translates to:
  /// **'Pläne & Preise'**
  String get pricingTitle;

  /// No description provided for @pricingMostPopular.
  ///
  /// In de, this message translates to:
  /// **'Beliebteste Wahl'**
  String get pricingMostPopular;

  /// No description provided for @pricingCurrentPlan.
  ///
  /// In de, this message translates to:
  /// **'Aktueller Plan'**
  String get pricingCurrentPlan;

  /// No description provided for @pricingPlanActivated.
  ///
  /// In de, this message translates to:
  /// **'Plan {plan} aktiviert.'**
  String pricingPlanActivated(Object plan);

  /// No description provided for @pricingActivationFailed.
  ///
  /// In de, this message translates to:
  /// **'Aktivierung fehlgeschlagen: {error}'**
  String pricingActivationFailed(Object error);

  /// No description provided for @billingProfileTitle.
  ///
  /// In de, this message translates to:
  /// **'Rechnungsdaten'**
  String get billingProfileTitle;

  /// No description provided for @billingProfileSaved.
  ///
  /// In de, this message translates to:
  /// **'Rechnungsdaten gespeichert.'**
  String get billingProfileSaved;

  /// No description provided for @billingProfileSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen: {error}'**
  String billingProfileSaveFailed(Object error);

  /// No description provided for @settingsAddAmazonShops.
  ///
  /// In de, this message translates to:
  /// **'Amazon-Shops hinzufügen'**
  String get settingsAddAmazonShops;

  /// No description provided for @settingsAddFailed.
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen: {error}'**
  String settingsAddFailed(Object error);

  /// No description provided for @settingsMailboxRemoveTitle.
  ///
  /// In de, this message translates to:
  /// **'Postfach entfernen'**
  String get settingsMailboxRemoveTitle;

  /// No description provided for @settingsMailboxRemoveFailed.
  ///
  /// In de, this message translates to:
  /// **'Löschen fehlgeschlagen: {error}'**
  String settingsMailboxRemoveFailed(Object error);

  /// No description provided for @settingsMailboxLimitTitle.
  ///
  /// In de, this message translates to:
  /// **'Postfach-Limit erreicht'**
  String get settingsMailboxLimitTitle;

  /// No description provided for @settingsUpgradePlan.
  ///
  /// In de, this message translates to:
  /// **'Plan upgraden'**
  String get settingsUpgradePlan;

  /// No description provided for @settingsApiKeyLabel.
  ///
  /// In de, this message translates to:
  /// **'API-Key'**
  String get settingsApiKeyLabel;

  /// No description provided for @settingsMailboxSection.
  ///
  /// In de, this message translates to:
  /// **'Postfach'**
  String get settingsMailboxSection;

  /// No description provided for @settingsCloudBackend.
  ///
  /// In de, this message translates to:
  /// **'Supabase'**
  String get settingsCloudBackend;

  /// No description provided for @mailboxImapServer.
  ///
  /// In de, this message translates to:
  /// **'IMAP-Server'**
  String get mailboxImapServer;

  /// No description provided for @mailboxLabel.
  ///
  /// In de, this message translates to:
  /// **'Label'**
  String get mailboxLabel;

  /// No description provided for @mailboxPort.
  ///
  /// In de, this message translates to:
  /// **'Port'**
  String get mailboxPort;

  /// No description provided for @mailboxUsername.
  ///
  /// In de, this message translates to:
  /// **'Benutzername / Mail-Adresse'**
  String get mailboxUsername;

  /// No description provided for @mailboxFolder.
  ///
  /// In de, this message translates to:
  /// **'Ordner'**
  String get mailboxFolder;

  /// No description provided for @mailboxFolderHint.
  ///
  /// In de, this message translates to:
  /// **'INBOX'**
  String get mailboxFolderHint;

  /// No description provided for @mailboxUseSsl.
  ///
  /// In de, this message translates to:
  /// **'SSL/TLS verwenden'**
  String get mailboxUseSsl;

  /// No description provided for @mailboxPollingActive.
  ///
  /// In de, this message translates to:
  /// **'Polling aktiv'**
  String get mailboxPollingActive;

  /// No description provided for @inventoryEanCopied.
  ///
  /// In de, this message translates to:
  /// **'EAN: {code}'**
  String inventoryEanCopied(Object code);

  /// No description provided for @inventoryDiscordTicketOpen.
  ///
  /// In de, this message translates to:
  /// **'Discord-Ticket öffnen'**
  String get inventoryDiscordTicketOpen;

  /// No description provided for @inventoryColDealOrTicket.
  ///
  /// In de, this message translates to:
  /// **'Deal / Ticket'**
  String get inventoryColDealOrTicket;

  /// No description provided for @inventoryProductRequiredLabel.
  ///
  /// In de, this message translates to:
  /// **'Produkt *'**
  String get inventoryProductRequiredLabel;

  /// No description provided for @inventoryProductHint.
  ///
  /// In de, this message translates to:
  /// **'Aus Ticket auswählen oder frei eingeben'**
  String get inventoryProductHint;

  /// No description provided for @inventoryColEanGtin.
  ///
  /// In de, this message translates to:
  /// **'EAN / GTIN'**
  String get inventoryColEanGtin;

  /// No description provided for @ticketsBoxEkAmount.
  ///
  /// In de, this message translates to:
  /// **'EK {amount}'**
  String ticketsBoxEkAmount(Object amount);

  /// No description provided for @ticketsBoxVkAmount.
  ///
  /// In de, this message translates to:
  /// **'VK {amount}'**
  String ticketsBoxVkAmount(Object amount);

  /// No description provided for @ticketsColEk.
  ///
  /// In de, this message translates to:
  /// **'EK'**
  String get ticketsColEk;

  /// No description provided for @ticketsColVk.
  ///
  /// In de, this message translates to:
  /// **'VK'**
  String get ticketsColVk;

  /// No description provided for @suppliersAddCarriers.
  ///
  /// In de, this message translates to:
  /// **'Versanddienste hinzufügen'**
  String get suppliersAddCarriers;

  /// No description provided for @statsExportSheetMetrics.
  ///
  /// In de, this message translates to:
  /// **'Kennzahlen'**
  String get statsExportSheetMetrics;

  /// No description provided for @statsExportSheetTopProducts.
  ///
  /// In de, this message translates to:
  /// **'Top-Produkte (max. 10)'**
  String get statsExportSheetTopProducts;

  /// No description provided for @statsExportSheetBuyersTop.
  ///
  /// In de, this message translates to:
  /// **'Käufer (max. 10)'**
  String get statsExportSheetBuyersTop;

  /// No description provided for @statsExportSheetShopsTop.
  ///
  /// In de, this message translates to:
  /// **'Shops (max. 10)'**
  String get statsExportSheetShopsTop;

  /// No description provided for @statsExportSheetCashflow.
  ///
  /// In de, this message translates to:
  /// **'Cashflow'**
  String get statsExportSheetCashflow;

  /// No description provided for @statsExportFilenamePrefix.
  ///
  /// In de, this message translates to:
  /// **'Excel-Export: {file}'**
  String statsExportFilenamePrefix(Object file);

  /// No description provided for @urlOpenFailed.
  ///
  /// In de, this message translates to:
  /// **'Link konnte nicht geöffnet werden.'**
  String get urlOpenFailed;

  /// No description provided for @buyerServerIdN.
  ///
  /// In de, this message translates to:
  /// **'Server ID {n}'**
  String buyerServerIdN(int n);

  /// No description provided for @shopAmazonRegion.
  ///
  /// In de, this message translates to:
  /// **'Amazon · {region}'**
  String shopAmazonRegion(Object region);

  /// No description provided for @shopDerivedFromName.
  ///
  /// In de, this message translates to:
  /// **'Aus Shop-Namen abgeleitet'**
  String get shopDerivedFromName;

  /// No description provided for @dealPickerSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Suche nach Produkt, Ticket, Shop oder Käufer …'**
  String get dealPickerSearchHint;

  /// No description provided for @globalSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Suchen über Deals, Lager, Tickets, Käufer, Lieferanten…'**
  String get globalSearchHint;

  /// No description provided for @inboxMessageDetailsCopyTooltip.
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get inboxMessageDetailsCopyTooltip;

  /// No description provided for @inventoryBatchSnPrefix.
  ///
  /// In de, this message translates to:
  /// **'SN: {sn}'**
  String inventoryBatchSnPrefix(Object sn);

  /// No description provided for @inventoryBatchSnLabel.
  ///
  /// In de, this message translates to:
  /// **'SN'**
  String get inventoryBatchSnLabel;

  /// No description provided for @inventoryBatchExpiryLabel.
  ///
  /// In de, this message translates to:
  /// **'MHD'**
  String get inventoryBatchExpiryLabel;

  /// No description provided for @statsNoData.
  ///
  /// In de, this message translates to:
  /// **'Keine Daten.'**
  String get statsNoData;

  /// No description provided for @statsNoDataInPeriod.
  ///
  /// In de, this message translates to:
  /// **'Keine Daten im Zeitraum.'**
  String get statsNoDataInPeriod;

  /// No description provided for @statsNoDataAvailable.
  ///
  /// In de, this message translates to:
  /// **'Keine Daten vorhanden.'**
  String get statsNoDataAvailable;

  /// No description provided for @statsHeatmapLess.
  ///
  /// In de, this message translates to:
  /// **'Weniger'**
  String get statsHeatmapLess;

  /// No description provided for @statsHeatmapMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get statsHeatmapMore;

  /// No description provided for @dealTableEditTooltip.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get dealTableEditTooltip;

  /// No description provided for @dealTableDeleteTooltip.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get dealTableDeleteTooltip;

  /// No description provided for @ticketsCountPlural.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Deals} =1{1 Deal} other{{count} Deals}}'**
  String ticketsCountPlural(int count);

  /// No description provided for @ticketsItemsCountPlural.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Artikel} =1{1 Artikel} other{{count} Artikel}}'**
  String ticketsItemsCountPlural(int count);

  /// No description provided for @supplierItemsPlural.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Artikel} =1{1 Artikel} other{{count} Artikel}}'**
  String supplierItemsPlural(int count);

  /// No description provided for @inventorySoldBuyerItemsPlural.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Stück} other{{count} Stück}}'**
  String inventorySoldBuyerItemsPlural(int count);

  /// No description provided for @pushPaymentLeadDaysPlural.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =1{1 Tag} other{{days} Tage}}'**
  String pushPaymentLeadDaysPlural(int days);

  /// No description provided for @inboxTabSuggestions.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Vorschläge (1)} other{Vorschläge ({count})}}'**
  String inboxTabSuggestions(int count);

  /// No description provided for @inboxTabUpdated.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Aktualisiert (1)} other{Aktualisiert ({count})}}'**
  String inboxTabUpdated(int count);

  /// No description provided for @inboxTabUnclassified.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Unklassifiziert (1)} other{Unklassifiziert ({count})}}'**
  String inboxTabUnclassified(int count);

  /// No description provided for @inboxAccountsConnected.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Postfach verbunden} other{{count} Postfächer verbunden}}'**
  String inboxAccountsConnected(int count);

  /// No description provided for @inboxNoAccountConnected.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Postfach verbunden'**
  String get inboxNoAccountConnected;

  /// No description provided for @inboxFooterDescription.
  ///
  /// In de, this message translates to:
  /// **'Polling alle 5 min — nur Bestellbestätigungen, Versand- und Stornierungs-Mails der konfigurierten Shops landen hier.'**
  String get inboxFooterDescription;

  /// No description provided for @inboxFooterNoAccountHint.
  ///
  /// In de, this message translates to:
  /// **'Lege unter Einstellungen → Postfach ein IMAP-Konto an.'**
  String get inboxFooterNoAccountHint;

  /// No description provided for @inboxDismissalsTooltipEmpty.
  ///
  /// In de, this message translates to:
  /// **'Verworfen-Filter (0)'**
  String get inboxDismissalsTooltipEmpty;

  /// No description provided for @inboxDismissalsTooltipActive.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Verworfen-Filter zurücksetzen (1 Eintrag)} other{Verworfen-Filter zurücksetzen ({count} Einträge)}}'**
  String inboxDismissalsTooltipActive(int count);

  /// No description provided for @inboxImportingTooltip.
  ///
  /// In de, this message translates to:
  /// **'Importiere Mails… ({count} bisher)'**
  String inboxImportingTooltip(int count);

  /// No description provided for @inboxPollNowTooltip.
  ///
  /// In de, this message translates to:
  /// **'Jetzt pollen (statt 5 min warten)'**
  String get inboxPollNowTooltip;

  /// No description provided for @inboxPollNoAccountTooltip.
  ///
  /// In de, this message translates to:
  /// **'Erst Postfach in den Einstellungen verbinden'**
  String get inboxPollNoAccountTooltip;

  /// No description provided for @inboxFilterResetConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 verworfener Eintrag wird wieder angezeigt. Bestellbestätigungen, die zwischenzeitlich erneut gekommen sind, erscheinen ebenfalls wieder im Inbox-Tab.} other{{count} verworfene Einträge werden wieder angezeigt. Bestellbestätigungen, die zwischenzeitlich erneut gekommen sind, erscheinen ebenfalls wieder im Inbox-Tab.}}'**
  String inboxFilterResetConfirmBody(int count);

  /// No description provided for @inboxPollFetchedSummary.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Mail geholt} other{{count} Mails geholt}}'**
  String inboxPollFetchedSummary(int count);

  /// No description provided for @inboxPollStoredSummary.
  ///
  /// In de, this message translates to:
  /// **'{count} aufgenommen'**
  String inboxPollStoredSummary(int count);

  /// No description provided for @inboxPollSuggMatchedSummary.
  ///
  /// In de, this message translates to:
  /// **'{s} Vorschl. / {m} gemerged'**
  String inboxPollSuggMatchedSummary(int s, int m);

  /// No description provided for @inboxPollNoNewMails.
  ///
  /// In de, this message translates to:
  /// **'Keine neuen passenden Mails. Postfach ist aktuell.'**
  String get inboxPollNoNewMails;

  /// No description provided for @inboxDiscardConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'Die Mail \"{subject}\" wird aus der Inbox entfernt und nicht mehr angezeigt.'**
  String inboxDiscardConfirmBody(Object subject);

  /// No description provided for @inboxAssignSuggestionTitle.
  ///
  /// In de, this message translates to:
  /// **'Vorschlag zu Deal zuweisen'**
  String get inboxAssignSuggestionTitle;

  /// No description provided for @inboxAssignSuggestionBody.
  ///
  /// In de, this message translates to:
  /// **'Order-ID, Tracking und ETA werden in den ausgewählten Deal übernommen, der Vorschlag wird abgehakt.'**
  String get inboxAssignSuggestionBody;

  /// No description provided for @inboxApplyTrackingHint.
  ///
  /// In de, this message translates to:
  /// **'Tracking {tracking} → Deal-Tracking, Status wird auf „Unterwegs\" gesetzt.'**
  String inboxApplyTrackingHint(Object tracking);

  /// No description provided for @inboxManualMailEntry.
  ///
  /// In de, this message translates to:
  /// **'Manueller Eintrag aus Mail'**
  String get inboxManualMailEntry;

  /// No description provided for @inboxAutoUpdateRefreshHint.
  ///
  /// In de, this message translates to:
  /// **'Aktualisiert sich beim nächsten Refresh.'**
  String get inboxAutoUpdateRefreshHint;

  /// No description provided for @inboxNoProductName.
  ///
  /// In de, this message translates to:
  /// **'— ohne Produktnamen —'**
  String get inboxNoProductName;

  /// No description provided for @inboxQuantityShort.
  ///
  /// In de, this message translates to:
  /// **'{count} Stk.'**
  String inboxQuantityShort(int count);

  /// No description provided for @inboxEtaPrefix.
  ///
  /// In de, this message translates to:
  /// **'ETA {date}'**
  String inboxEtaPrefix(Object date);

  /// No description provided for @inboxOrderForShop.
  ///
  /// In de, this message translates to:
  /// **'Bestellung für {shop}'**
  String inboxOrderForShop(Object shop);

  /// No description provided for @inboxRecognizedOrder.
  ///
  /// In de, this message translates to:
  /// **'Erkannter Auftrag ({shop})'**
  String inboxRecognizedOrder(Object shop);

  /// No description provided for @inboxOrderPrefix.
  ///
  /// In de, this message translates to:
  /// **'Bestellung {id}'**
  String inboxOrderPrefix(Object id);

  /// No description provided for @billingProfileFullName.
  ///
  /// In de, this message translates to:
  /// **'Vollständiger Name'**
  String get billingProfileFullName;

  /// No description provided for @billingProfileStreet.
  ///
  /// In de, this message translates to:
  /// **'Straße & Hausnummer'**
  String get billingProfileStreet;

  /// No description provided for @billingProfileSavingDots.
  ///
  /// In de, this message translates to:
  /// **'Speichern…'**
  String get billingProfileSavingDots;

  /// No description provided for @billingProfileRequiredForPaid.
  ///
  /// In de, this message translates to:
  /// **'Pflichtfeld für kostenpflichtige Pläne'**
  String get billingProfileRequiredForPaid;

  /// No description provided for @billingProfileIntroBody.
  ///
  /// In de, this message translates to:
  /// **'Für kostenpflichtige Pläne benötigen wir eine vollständige Rechnungsadresse (Pflichtfelder mit *).'**
  String get billingProfileIntroBody;

  /// No description provided for @billingProfilePrivacyHint.
  ///
  /// In de, this message translates to:
  /// **'Diese Daten werden ausschließlich für Rechnungen und steuerrelevante Dokumente verwendet.'**
  String get billingProfilePrivacyHint;

  /// No description provided for @settingsAmazonExisting.
  ///
  /// In de, this message translates to:
  /// **'Amazon-Shops sind bereits vorhanden ({skipped} übersprungen).'**
  String settingsAmazonExisting(int skipped);

  /// No description provided for @settingsAmazonAdded.
  ///
  /// In de, this message translates to:
  /// **'{added, plural, =1{1 Amazon-Shop hinzugefügt} other{{added} Amazon-Shops hinzugefügt}}'**
  String settingsAmazonAdded(int added);

  /// No description provided for @settingsMailboxRemoveBody.
  ///
  /// In de, this message translates to:
  /// **'Postfach \"{label}\" wirklich löschen? Auch alle aus diesem Postfach importierten Mails (Vorschläge + Unklassifizierte) werden gelöscht. Bereits in Deals übernommene Bestellungen bleiben unberührt.'**
  String settingsMailboxRemoveBody(Object label);

  /// No description provided for @settingsMailboxLimitBody.
  ///
  /// In de, this message translates to:
  /// **'{plan} enthält nur {limit, plural, =1{1 Postfach} other{{limit} Postfächer}}. Upgrade auf einen höheren Plan, um weitere zu verbinden.'**
  String settingsMailboxLimitBody(Object plan, int limit);

  /// No description provided for @settingsMailboxFreeNotIncluded.
  ///
  /// In de, this message translates to:
  /// **'Postfach im Free-Plan nicht enthalten'**
  String get settingsMailboxFreeNotIncluded;

  /// No description provided for @settingsMailboxStarterUpgradeHint.
  ///
  /// In de, this message translates to:
  /// **'Importieren von Mails ist ab dem Starter-Plan verfügbar — höhere Pläne erlauben mehr Postfächer und längeren Inbox-Verlauf.'**
  String get settingsMailboxStarterUpgradeHint;

  /// No description provided for @settingsMailboxRequiredIncomplete.
  ///
  /// In de, this message translates to:
  /// **'Pflichtangaben unvollständig — bitte ergänzen'**
  String get settingsMailboxRequiredIncomplete;

  /// No description provided for @settingsMailboxOptional.
  ///
  /// In de, this message translates to:
  /// **'Optional — wird erst beim Upgrade benötigt'**
  String get settingsMailboxOptional;

  /// No description provided for @settingsMailboxNeverPolled.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht gepollt'**
  String get settingsMailboxNeverPolled;

  /// No description provided for @settingsMailboxIntroBody.
  ///
  /// In de, this message translates to:
  /// **'Verbinde ein IMAP-Konto, um Bestellbestätigungen automatisch erkennen zu lassen. Polling läuft alle 5 min serverseitig — Passwörter werden mit pgp_sym_encrypt verschlüsselt gespeichert. Im Inbox-Tab kannst du…'**
  String get settingsMailboxIntroBody;

  /// No description provided for @settingsAmazonShopsHeading.
  ///
  /// In de, this message translates to:
  /// **'Amazon'**
  String get settingsAmazonShopsHeading;

  /// No description provided for @settingsAddMailboxButton.
  ///
  /// In de, this message translates to:
  /// **'Postfach hinzufügen'**
  String get settingsAddMailboxButton;

  /// No description provided for @settingsMailboxesHeading.
  ///
  /// In de, this message translates to:
  /// **'Postfächer'**
  String get settingsMailboxesHeading;

  /// No description provided for @settingsMailboxesPlanHint.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Postfach · {days} Tage} other{{count} Postfächer · {days} Tage}}'**
  String settingsMailboxesPlanHint(int count, int days);

  /// No description provided for @suppliersCarriersExisting.
  ///
  /// In de, this message translates to:
  /// **'Versanddienste sind bereits vorhanden ({skipped} übersprungen).'**
  String suppliersCarriersExisting(int skipped);

  /// No description provided for @suppliersCarriersAdded.
  ///
  /// In de, this message translates to:
  /// **'{added, plural, =1{1 Versanddienst hinzugefügt} other{{added} Versanddienste hinzugefügt}}'**
  String suppliersCarriersAdded(int added);

  /// No description provided for @pricingChooseTitle.
  ///
  /// In de, this message translates to:
  /// **'Wähle den Plan, der zu dir passt'**
  String get pricingChooseTitle;

  /// No description provided for @pricingFreeIncluded.
  ///
  /// In de, this message translates to:
  /// **'Team-Plätze und Analyse-Features frei.'**
  String get pricingFreeIncluded;

  /// No description provided for @pricingCheckoutPlaceholder.
  ///
  /// In de, this message translates to:
  /// **'Sobald Stripe/Paddle integriert ist, läuft hier der echte Checkout.'**
  String get pricingCheckoutPlaceholder;

  /// No description provided for @pricingYearlyDiscount.
  ///
  /// In de, this message translates to:
  /// **'Jährlich · –17%'**
  String get pricingYearlyDiscount;

  /// No description provided for @pricingActivePlan.
  ///
  /// In de, this message translates to:
  /// **'Aktiver Plan'**
  String get pricingActivePlan;

  /// No description provided for @pricingSwitchToFree.
  ///
  /// In de, this message translates to:
  /// **'Auf Free wechseln'**
  String get pricingSwitchToFree;

  /// No description provided for @pricingChoosePlan.
  ///
  /// In de, this message translates to:
  /// **'Plan auswählen'**
  String get pricingChoosePlan;

  /// No description provided for @pricingPriceMonthlyApprox.
  ///
  /// In de, this message translates to:
  /// **'≈ {amount} / Monat'**
  String pricingPriceMonthlyApprox(Object amount);

  /// No description provided for @pricingPaidNeedsBillingHint.
  ///
  /// In de, this message translates to:
  /// **'Kostenpflichtige Pläne benötigen eine vollständige Rechnungsadresse. Diese kann unter „Rechnungsdaten\" jederzeit aktualisiert werden.'**
  String get pricingPaidNeedsBillingHint;

  /// No description provided for @authLoginNetworkError.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung fehlgeschlagen. Bitte Internetverbindung prüfen.'**
  String get authLoginNetworkError;

  /// No description provided for @authConfirmEmailFirst.
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätige zuerst deine E-Mail-Adresse.'**
  String get authConfirmEmailFirst;

  /// No description provided for @authRegisterNetworkError.
  ///
  /// In de, this message translates to:
  /// **'Registrierung fehlgeschlagen. Bitte Internetverbindung prüfen.'**
  String get authRegisterNetworkError;

  /// No description provided for @authResetLinkFailed.
  ///
  /// In de, this message translates to:
  /// **'Reset-Link konnte nicht gesendet werden.'**
  String get authResetLinkFailed;

  /// No description provided for @authPasswordChangeFailed.
  ///
  /// In de, this message translates to:
  /// **'Passwort konnte nicht geändert werden.'**
  String get authPasswordChangeFailed;

  /// No description provided for @authResendFailed.
  ///
  /// In de, this message translates to:
  /// **'E-Mail konnte nicht erneut gesendet werden.'**
  String get authResendFailed;

  /// No description provided for @authProviderLoginFailed.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung mit {provider} fehlgeschlagen.'**
  String authProviderLoginFailed(Object provider);

  /// No description provided for @authDeleteAccountFailed.
  ///
  /// In de, this message translates to:
  /// **'Konto konnte nicht gelöscht werden.'**
  String get authDeleteAccountFailed;

  /// No description provided for @authDeleteAccountNetworkError.
  ///
  /// In de, this message translates to:
  /// **'Konto konnte nicht gelöscht werden. Bitte Internetverbindung prüfen.'**
  String get authDeleteAccountNetworkError;

  /// No description provided for @authEmailOrPasswordWrong.
  ///
  /// In de, this message translates to:
  /// **'E-Mail oder Passwort ist falsch.'**
  String get authEmailOrPasswordWrong;

  /// No description provided for @authPasswordTooWeak.
  ///
  /// In de, this message translates to:
  /// **'Passwort ist zu schwach. Bitte stärkeres Passwort wählen.'**
  String get authPasswordTooWeak;

  /// No description provided for @authNoConnection.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung. Internetverbindung prüfen.'**
  String get authNoConnection;

  /// No description provided for @authNoAccountForEmail.
  ///
  /// In de, this message translates to:
  /// **'Kein Konto mit dieser E-Mail gefunden.'**
  String get authNoAccountForEmail;

  /// No description provided for @authRegistrationDisabled.
  ///
  /// In de, this message translates to:
  /// **'Registrierung ist derzeit deaktiviert.'**
  String get authRegistrationDisabled;

  /// No description provided for @authProviderNotEnabled.
  ///
  /// In de, this message translates to:
  /// **'Dieser Anmeldeweg ist im Backend nicht aktiviert.'**
  String get authProviderNotEnabled;

  /// No description provided for @inboxSuggestionMissingTrackingError.
  ///
  /// In de, this message translates to:
  /// **'Suggestion enthält kein Tracking.'**
  String get inboxSuggestionMissingTrackingError;

  /// No description provided for @ticketsArchiveColumnHeader.
  ///
  /// In de, this message translates to:
  /// **'Archiv'**
  String get ticketsArchiveColumnHeader;

  /// No description provided for @ticketsManualEntryFromMail.
  ///
  /// In de, this message translates to:
  /// **'Manueller Eintrag aus Mail'**
  String get ticketsManualEntryFromMail;

  /// No description provided for @pricingPlanFreeTagline.
  ///
  /// In de, this message translates to:
  /// **'Zum Reinschnuppern'**
  String get pricingPlanFreeTagline;

  /// No description provided for @pricingPlanStarterTagline.
  ///
  /// In de, this message translates to:
  /// **'Solo-Reseller, das Wesentliche'**
  String get pricingPlanStarterTagline;

  /// No description provided for @pricingPlanProTagline.
  ///
  /// In de, this message translates to:
  /// **'Für aktive Reseller'**
  String get pricingPlanProTagline;

  /// No description provided for @pricingPlanBusinessTagline.
  ///
  /// In de, this message translates to:
  /// **'Power-Reseller & Teams'**
  String get pricingPlanBusinessTagline;

  /// No description provided for @pricingPlanUltimateTagline.
  ///
  /// In de, this message translates to:
  /// **'Für Wholesale & Heavy-Volume'**
  String get pricingPlanUltimateTagline;

  /// No description provided for @pricingHighlightFreeProducts.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 50 Produkte'**
  String get pricingHighlightFreeProducts;

  /// No description provided for @pricingHighlightFreeDeals.
  ///
  /// In de, this message translates to:
  /// **'25 Deals pro Monat'**
  String get pricingHighlightFreeDeals;

  /// No description provided for @pricingHighlightFreeNoImages.
  ///
  /// In de, this message translates to:
  /// **'Keine Bilder pro Eintrag'**
  String get pricingHighlightFreeNoImages;

  /// No description provided for @pricingHighlightFreeOverviewStats.
  ///
  /// In de, this message translates to:
  /// **'Nur Übersichts-Statistik'**
  String get pricingHighlightFreeOverviewStats;

  /// No description provided for @pricingHighlightFreeNoMailbox.
  ///
  /// In de, this message translates to:
  /// **'Kein Postfach-Import'**
  String get pricingHighlightFreeNoMailbox;

  /// No description provided for @pricingHighlightFreeCommunitySupport.
  ///
  /// In de, this message translates to:
  /// **'Community-Support'**
  String get pricingHighlightFreeCommunitySupport;

  /// No description provided for @pricingHighlightStarterProducts.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 500 Produkte'**
  String get pricingHighlightStarterProducts;

  /// No description provided for @pricingHighlightStarterDealsUnlimited.
  ///
  /// In de, this message translates to:
  /// **'Unbegrenzt Deals'**
  String get pricingHighlightStarterDealsUnlimited;

  /// No description provided for @pricingHighlightStarterImageStorage.
  ///
  /// In de, this message translates to:
  /// **'1 Bild pro Eintrag · 1 GB Storage'**
  String get pricingHighlightStarterImageStorage;

  /// No description provided for @pricingHighlightStarterMailbox.
  ///
  /// In de, this message translates to:
  /// **'1 Postfach · 7 Tage Inbox-Verlauf'**
  String get pricingHighlightStarterMailbox;

  /// No description provided for @pricingHighlightStarterCsv.
  ///
  /// In de, this message translates to:
  /// **'CSV Import & Export'**
  String get pricingHighlightStarterCsv;

  /// No description provided for @pricingHighlightStarterBarcode.
  ///
  /// In de, this message translates to:
  /// **'Barcode-Scanner'**
  String get pricingHighlightStarterBarcode;

  /// No description provided for @pricingHighlightStarterEmailSupport.
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Support (48h)'**
  String get pricingHighlightStarterEmailSupport;

  /// No description provided for @pricingHighlightProProducts.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 5.000 Produkte'**
  String get pricingHighlightProProducts;

  /// No description provided for @pricingHighlightProDealsUnlimited.
  ///
  /// In de, this message translates to:
  /// **'Unbegrenzt Deals'**
  String get pricingHighlightProDealsUnlimited;

  /// No description provided for @pricingHighlightProTeam.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 3 Team-Mitglieder'**
  String get pricingHighlightProTeam;

  /// No description provided for @pricingHighlightProImageStorage.
  ///
  /// In de, this message translates to:
  /// **'5 Bilder pro Eintrag · 10 GB Storage'**
  String get pricingHighlightProImageStorage;

  /// No description provided for @pricingHighlightProMailbox.
  ///
  /// In de, this message translates to:
  /// **'3 Postfächer · 14 Tage Inbox-Verlauf'**
  String get pricingHighlightProMailbox;

  /// No description provided for @pricingHighlightProAnalytics.
  ///
  /// In de, this message translates to:
  /// **'Drilldowns, Heatmaps & Trends'**
  String get pricingHighlightProAnalytics;

  /// No description provided for @pricingHighlightProActivityLog.
  ///
  /// In de, this message translates to:
  /// **'Activity-Log & Audit-Trail'**
  String get pricingHighlightProActivityLog;

  /// No description provided for @pricingHighlightProPush.
  ///
  /// In de, this message translates to:
  /// **'Push-Benachrichtigungen'**
  String get pricingHighlightProPush;

  /// No description provided for @pricingHighlightProPrioritySupport.
  ///
  /// In de, this message translates to:
  /// **'Priority-Support (24h)'**
  String get pricingHighlightProPrioritySupport;

  /// No description provided for @pricingHighlightBusinessProducts.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 100.000 Produkte'**
  String get pricingHighlightBusinessProducts;

  /// No description provided for @pricingHighlightBusinessTeam.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 10 Team-Mitglieder'**
  String get pricingHighlightBusinessTeam;

  /// No description provided for @pricingHighlightBusinessImageStorage.
  ///
  /// In de, this message translates to:
  /// **'10 Bilder pro Eintrag · 50 GB Storage'**
  String get pricingHighlightBusinessImageStorage;

  /// No description provided for @pricingHighlightBusinessMailbox.
  ///
  /// In de, this message translates to:
  /// **'10 Postfächer · 30 Tage Inbox-Verlauf'**
  String get pricingHighlightBusinessMailbox;

  /// No description provided for @pricingHighlightBusinessApi.
  ///
  /// In de, this message translates to:
  /// **'API-Zugriff & Webhooks'**
  String get pricingHighlightBusinessApi;

  /// No description provided for @pricingHighlightBusinessDatev.
  ///
  /// In de, this message translates to:
  /// **'DATEV-Export (geplant)'**
  String get pricingHighlightBusinessDatev;

  /// No description provided for @pricingHighlightBusinessBranding.
  ///
  /// In de, this message translates to:
  /// **'Custom Branding für Reports'**
  String get pricingHighlightBusinessBranding;

  /// No description provided for @pricingHighlightBusinessSla.
  ///
  /// In de, this message translates to:
  /// **'Priority-SLA (12h)'**
  String get pricingHighlightBusinessSla;

  /// No description provided for @pricingHighlightUltimateProducts.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 300.000 Produkte'**
  String get pricingHighlightUltimateProducts;

  /// No description provided for @pricingHighlightUltimateMailbox.
  ///
  /// In de, this message translates to:
  /// **'15 Postfächer · 90 Tage Inbox-Verlauf'**
  String get pricingHighlightUltimateMailbox;

  /// No description provided for @pricingHighlightUltimateTeam.
  ///
  /// In de, this message translates to:
  /// **'Bis zu 50 Team-Mitglieder'**
  String get pricingHighlightUltimateTeam;

  /// No description provided for @pricingHighlightUltimateImageStorage.
  ///
  /// In de, this message translates to:
  /// **'25 Bilder pro Eintrag · unbegrenzter Storage'**
  String get pricingHighlightUltimateImageStorage;

  /// No description provided for @pricingHighlightUltimateSso.
  ///
  /// In de, this message translates to:
  /// **'Single Sign-On (SAML/OIDC)'**
  String get pricingHighlightUltimateSso;

  /// No description provided for @pricingHighlightUltimateWhitelabel.
  ///
  /// In de, this message translates to:
  /// **'White-Label-Option'**
  String get pricingHighlightUltimateWhitelabel;

  /// No description provided for @pricingHighlightUltimateMarketplace.
  ///
  /// In de, this message translates to:
  /// **'Marketplace-Sync (geplant)'**
  String get pricingHighlightUltimateMarketplace;

  /// No description provided for @pricingHighlightUltimateAccountManager.
  ///
  /// In de, this message translates to:
  /// **'Dedizierter Account Manager'**
  String get pricingHighlightUltimateAccountManager;

  /// No description provided for @pricingHighlightUltimateUptime.
  ///
  /// In de, this message translates to:
  /// **'Uptime-SLA 99,9%'**
  String get pricingHighlightUltimateUptime;

  /// No description provided for @statsServiceUnknownBuyer.
  ///
  /// In de, this message translates to:
  /// **'— Ohne Käufer'**
  String get statsServiceUnknownBuyer;

  /// No description provided for @pricingManageAction.
  ///
  /// In de, this message translates to:
  /// **'Plan verwalten'**
  String get pricingManageAction;

  /// No description provided for @pricingCurrentlyOnPlan.
  ///
  /// In de, this message translates to:
  /// **'Aktuell: {plan}'**
  String pricingCurrentlyOnPlan(Object plan);

  /// No description provided for @navInbox.
  ///
  /// In de, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @inboxCountdownToday.
  ///
  /// In de, this message translates to:
  /// **'Heute weg'**
  String get inboxCountdownToday;

  /// No description provided for @inboxCountdownOneDay.
  ///
  /// In de, this message translates to:
  /// **'Noch 1 Tag'**
  String get inboxCountdownOneDay;

  /// No description provided for @inboxCountdownDaysLeft.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Noch 1 Tag} other{Noch {count} Tage}}'**
  String inboxCountdownDaysLeft(int count);

  /// No description provided for @inboxVisibilityPrefix.
  ///
  /// In de, this message translates to:
  /// **'Inbox-Sichtbarkeit {days, plural, =1{1 Tag} other{{days} Tage}}. '**
  String inboxVisibilityPrefix(int days);

  /// No description provided for @inboxUpdatedDealDefault.
  ///
  /// In de, this message translates to:
  /// **'Aktualisierter Deal'**
  String get inboxUpdatedDealDefault;

  /// No description provided for @inboxNoSubject.
  ///
  /// In de, this message translates to:
  /// **'— ohne Betreff —'**
  String get inboxNoSubject;

  /// No description provided for @inboxOtherShop.
  ///
  /// In de, this message translates to:
  /// **'Sonstige'**
  String get inboxOtherShop;

  /// No description provided for @inboxUnknownSender.
  ///
  /// In de, this message translates to:
  /// **'Unbekannt'**
  String get inboxUnknownSender;

  /// No description provided for @inboxTrackingPrefix.
  ///
  /// In de, this message translates to:
  /// **'Tracking: {tracking}'**
  String inboxTrackingPrefix(Object tracking);
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
