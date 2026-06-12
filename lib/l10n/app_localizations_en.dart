// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Inventory Manager';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Back';

  @override
  String get actionOk => 'OK';

  @override
  String get actionYes => 'Yes';

  @override
  String get actionNo => 'No';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionSelectAll => 'Select all';

  @override
  String get actionDeselect => 'Clear selection';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionHelp => 'Help';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionExport => 'Export';

  @override
  String get actionImport => 'Import';

  @override
  String get actionDuplicate => 'Duplicate';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionShare => 'Share';

  @override
  String get actionDownload => 'Download';

  @override
  String get actionUpload => 'Upload';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionLoading => 'Loading…';

  @override
  String get actionSaving => 'Saving…';

  @override
  String get actionDeleting => 'Deleting…';

  @override
  String get commonAll => 'All';

  @override
  String get commonNone => 'None';

  @override
  String get commonOptional => 'optional';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String commonItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String commonSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
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
  String get navInbox => 'Inbox';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navSuppliers => 'Suppliers';

  @override
  String get navStatistics => 'Statistics';

  @override
  String get navActivity => 'Activity';

  @override
  String get navHelp => 'Help';

  @override
  String get navSettings => 'Settings';

  @override
  String get navMore => 'More';

  @override
  String get navMoreSheetTitle => 'More sections';

  @override
  String get navMoreSearchHint => 'Search sections…';

  @override
  String get navMoreSearchNoResults => 'No sections found';

  @override
  String get navMoreSectionManage => 'Manage';

  @override
  String get navMoreSectionTools => 'Analytics & Tools';

  @override
  String get navMoreSectionAccount => 'Account';

  @override
  String get navSectionSales => 'Sales';

  @override
  String get navSectionWarehouse => 'Warehouse';

  @override
  String get navSectionInsights => 'Insights';

  @override
  String get navSectionAccount => 'Account';

  @override
  String get navWarehouse => 'Warehousing';

  @override
  String get warehouseHubTitle => 'Warehousing';

  @override
  String get warehouseHubComingSoon => 'Coming soon';

  @override
  String get warehouseHubComingSoonHint =>
      'This feature will be available in an upcoming update.';

  @override
  String get warehouseHubTileInventory => 'Stock';

  @override
  String get warehouseHubTileProductCatalog => 'Product catalog';

  @override
  String get warehouseHubTilePurchaseOrders => 'Orders';

  @override
  String get warehouseHubTileSuppliers => 'Suppliers';

  @override
  String get warehouseHubTileWarehouses => 'Warehouses';

  @override
  String get warehouseHubTileCategories => 'Categories';

  @override
  String get warehouseHubTileStocktake => 'Stocktake';

  @override
  String get warehouseHubTileReporting => 'Reporting';

  @override
  String get warehouseHubDetailPaneEmpty => 'Select an area on the left.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldNewPassword => 'New password';

  @override
  String get fieldConfirmPassword => 'Confirm password';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNote => 'Note';

  @override
  String get passwordRequired => 'Password required';

  @override
  String get loginSubtitle => 'Sign in with your account';

  @override
  String get loginBrandHeadline => 'Welcome back.';

  @override
  String get pricingTitle => 'Plans & Pricing';

  @override
  String get pricingHeadline => 'Pick the plan that fits you';

  @override
  String get pricingIntro =>
      'Free stays free forever. Personal tiers for solo resellers, Enterprise for teams with inbox, multi-workspace and invites.';

  @override
  String get pricingCategoryPersonal => 'Personal';

  @override
  String get pricingCategoryPersonalHint =>
      'Solo resellers · gross prices incl. 19% VAT';

  @override
  String get pricingCategoryEnterprise => 'Enterprise';

  @override
  String get pricingCategoryEnterpriseHint =>
      'Teams · inbox · multi-workspace · net prices excl. VAT';

  @override
  String get pricingVatIncluded => 'VAT incl.';

  @override
  String get pricingVatExcluded => 'VAT excl.';

  @override
  String pricingYearlyBilled(String total) {
    return '$total billed annually';
  }

  @override
  String get pricingLegalFootnote =>
      'Personal tiers include the statutory value-added tax. Enterprise tiers are listed net — VAT is added on the invoice (reverse-charge inside the EU with a valid VAT ID). Upgrading to a paid plan requires a complete billing address.';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginInProgress => 'Signing in…';

  @override
  String get loginContinueWith => 'or continue with';

  @override
  String get loginWithGoogle => 'Sign in with Google';

  @override
  String get loginWithApple => 'Sign in with Apple';

  @override
  String get loginNoAccount => 'No account yet?';

  @override
  String get loginRegister => 'Sign up';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle => 'Create a new account to get started.';

  @override
  String get registerSubmit => 'Sign up';

  @override
  String get registerInProgress => 'Signing up…';

  @override
  String get registerHasAccount => 'Already have an account?';

  @override
  String get registerLogin => 'Sign in';

  @override
  String get forgotTitle => 'Reset password';

  @override
  String get forgotSubtitle => 'We\'ll send you a reset link.';

  @override
  String get forgotSubmit => 'Send link';

  @override
  String get forgotSent => 'Reset link sent. Check your inbox.';

  @override
  String get forgotBackToLogin => 'Back to login';

  @override
  String get resetTitle => 'Set new password';

  @override
  String get resetSubtitle => 'Pick a new password for your account.';

  @override
  String get resetSubmit => 'Save password';

  @override
  String get resetSuccess => 'Password updated.';

  @override
  String get resetMismatch => 'Passwords don\'t match.';

  @override
  String get verifyTitle => 'Verify email';

  @override
  String get verifySubtitle => 'We sent you a verification link.';

  @override
  String get verifyResend => 'Resend';

  @override
  String get splashSyncing => 'Syncing with cloud…';

  @override
  String get sessionExpiringSoon => 'Session expires soon.';

  @override
  String get sessionExtend => 'Extend';

  @override
  String get sessionExtendFailed => 'Couldn\'t extend session.';

  @override
  String get headerSearchHint => 'Search';

  @override
  String get headerImportCsv => 'Import CSV';

  @override
  String get headerExportCsv => 'Export CSV';

  @override
  String csvExportSuccess(Object path) {
    return 'Exported: $path';
  }

  @override
  String get csvImportConfirmTitle => 'Import CSV';

  @override
  String get csvImportConfirmText =>
      'Deals will be appended. Shops, buyers and inventory entries are only added when no entry with the same name exists.';

  @override
  String get csvImportPickFile => 'Pick file';

  @override
  String csvImportSummary(
    int deals,
    int shops,
    int buyers,
    int suppliers,
    int items,
  ) {
    return 'Imported $deals deals, $shops shops, $buyers buyers, $suppliers suppliers, $items inventory items.';
  }

  @override
  String errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get accountMenuSignedInAs => 'Signed in as';

  @override
  String get accountMenuSignOut => 'Sign out';

  @override
  String get accountMenuDeleteAccount => 'Delete account';

  @override
  String get accountMenuActiveWorkspace => 'Active workspace';

  @override
  String get logoutConfirmTitle => 'Sign out?';

  @override
  String get logoutConfirmText =>
      'You\'ll be returned to the login screen. Unsynced edits will be lost.';

  @override
  String get deleteAccountTitle => 'Delete account permanently?';

  @override
  String get deleteAccountText =>
      'Your account and all data will be deleted permanently. This action cannot be undone.';

  @override
  String get deleteAccountConfirmInstruction => 'Type DELETE to confirm:';

  @override
  String get deleteAccountConfirmKeyword => 'DELETE';

  @override
  String get deleteAccountSubtitle =>
      'Permanently deletes your account and all data.';

  @override
  String get deleteAccountFailed => 'Couldn\'t delete account.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTabBuyers => 'Buyers';

  @override
  String get settingsTabShops => 'Shops';

  @override
  String get settingsTabTeam => 'Team';

  @override
  String get settingsTabPush => 'Push';

  @override
  String get settingsTabShipping => 'Shipping';

  @override
  String get settingsTabGeneral => 'General';

  @override
  String get settingsTabSupport => 'Support';

  @override
  String get supportIntro =>
      'Got a question, found a bug or have a feature request? Write to us — your request goes straight to the support inbox and we reply by email.';

  @override
  String get supportSubjectLabel => 'Subject';

  @override
  String get supportSubjectHint => 'What is it about?';

  @override
  String get supportSubjectTooShort => 'At least 3 characters';

  @override
  String get supportMessageLabel => 'Your message';

  @override
  String get supportMessageTooShort => 'At least 10 characters';

  @override
  String get supportPrivacyNote =>
      'We include your account email (for the reply), your plan and the workspace ID — nothing else.';

  @override
  String get supportSendCta => 'Send request';

  @override
  String get supportSending => 'Sending…';

  @override
  String get supportSentOk =>
      'Request sent — we will get back to you by email.';

  @override
  String get supportRateLimited =>
      'Too many requests — please try again in an hour.';

  @override
  String get supportSendFailed => 'Sending failed — please try again later.';

  @override
  String get supportOffline => 'No connection — please check your network.';

  @override
  String get shippingIntroTitle => 'Carrier API keys';

  @override
  String get shippingIntroBody =>
      'Tracking numbers are detected automatically from your emails (DHL, Amazon, DPD, GLS, UPS, Hermes) — no API key required. Store a carrier API key (currently DHL) so the app can fetch live delivery status (immediately when a tracking number is assigned, then automatically at the right cadence: out for delivery hourly, in transit ~every 4 hours) and mark deals as “Arrived” automatically.';

  @override
  String get shippingNoAccess =>
      'Only workspace owners and admins can manage carrier API keys.';

  @override
  String get shippingNotConfigured => 'Not configured';

  @override
  String get shippingSetKey => 'Set API key';

  @override
  String get shippingUpdateKey => 'Replace API key';

  @override
  String get shippingDeleteKey => 'Remove';

  @override
  String shippingKeyDialogTitle(Object carrier) {
    return '$carrier API key';
  }

  @override
  String get shippingKeyHelp =>
      'The key is encrypted on the server. After saving only the last 4 characters are shown.';

  @override
  String get shippingKeyTooShort => 'Enter at least 8 characters.';

  @override
  String get shippingKeySaved => 'Saved.';

  @override
  String get shippingKeyDeleted => 'Removed.';

  @override
  String shippingLastChecked(Object when) {
    return 'Last polled: $when';
  }

  @override
  String shippingLastError(Object error) {
    return 'Last error: $error';
  }

  @override
  String get shippingLastNeverPolled => 'Not polled yet.';

  @override
  String get shippingCarrierComingSoon => 'Coming soon';

  @override
  String get shippingSetupError =>
      'Setup incomplete: master key not configured. Open help.';

  @override
  String get shippingSetupHelpAction => 'Open help';

  @override
  String get buyersEmpty => 'No buyers yet.';

  @override
  String get buyersAdd => 'Add buyer';

  @override
  String get buyersDeleteTitle => 'Delete buyer';

  @override
  String buyersDeleteConfirm(Object name) {
    return 'Delete buyer \"$name\"?';
  }

  @override
  String get buyersDeletedSuccess => 'Buyer removed.';

  @override
  String get buyersDeleteFailed => 'Delete failed.';

  @override
  String get shopsEmpty => 'No shops yet.';

  @override
  String get shopsAdd => 'Add shop';

  @override
  String get shopsDeleteTitle => 'Delete shop';

  @override
  String shopsDeleteConfirm(Object name) {
    return 'Delete shop \"$name\"?';
  }

  @override
  String get shopsDeletedSuccess => 'Shop removed.';

  @override
  String get shopsDeleteFailed => 'Delete failed.';

  @override
  String teamLoadFailed(Object error) {
    return 'Couldn\'t load team data: $error';
  }

  @override
  String get teamMigrationHint =>
      'Make sure the workspace migration has been applied in Supabase.';

  @override
  String get teamNoWorkspace => 'No workspace found.';

  @override
  String teamWorkspaceSummary(Object id, int count) {
    return 'Workspace ID $id · $count member(s)';
  }

  @override
  String get teamCopyId => 'Copy ID';

  @override
  String get teamCopyIdSnack => 'Workspace ID copied.';

  @override
  String get teamRename => 'Rename';

  @override
  String get teamRenameTitle => 'Rename workspace';

  @override
  String get teamRenameLabel => 'Alias';

  @override
  String get teamRenameHint => 'e.g. Acme Ltd';

  @override
  String get teamRenameSuccess => 'Workspace renamed.';

  @override
  String teamRenameFailed(Object error) {
    return 'Rename failed: $error';
  }

  @override
  String get teamRenamePersonalWarnTitle => 'Personal Workspace';

  @override
  String get teamRenamePersonalWarn =>
      'This is your personal default workspace. Rename anyway?';

  @override
  String get teamMembers => 'Members';

  @override
  String get teamInvites => 'Pending invites';

  @override
  String get teamInvite => 'Invite';

  @override
  String teamInviteFailed(Object error) {
    return 'Invite failed: $error';
  }

  @override
  String get teamInviteTitle => 'Invite member';

  @override
  String get teamInviteEmailLabel => 'Email address';

  @override
  String get teamInviteRoleLabel => 'Role';

  @override
  String teamMemberSince(Object role, Object date) {
    return '$role · since $date';
  }

  @override
  String teamInviteExpires(Object role, Object date) {
    return 'Role: $role · expires $date';
  }

  @override
  String get teamMemberRemove => 'Remove';

  @override
  String get teamMemberFallbackLabel => 'this member';

  @override
  String get teamMemberRemovedSuccess => 'Member removed.';

  @override
  String get teamMemberRemoveFailed => 'Remove failed.';

  @override
  String get teamInviteRevoke => 'Revoke invite';

  @override
  String get teamInviteRevokedSuccess => 'Invite revoked.';

  @override
  String get teamInviteRevokeFailed => 'Revoke failed.';

  @override
  String get teamSwitchWorkspace => 'Switch workspace';

  @override
  String get teamRoleOwner => 'Owner';

  @override
  String get teamRoleAdmin => 'Admin';

  @override
  String get teamRoleMember => 'Member';

  @override
  String get teamRoleViewer => 'Read-only';

  @override
  String get teamRoleEditor => 'Editor';

  @override
  String get teamRoleObserver => 'Observer';

  @override
  String get teamRoleEditorHint => 'Can read and edit data.';

  @override
  String get teamRoleObserverHint => 'Read-only access.';

  @override
  String get teamRoleOwnerHint => 'Full control incl. workspace management.';

  @override
  String get teamRoleAdminHint => 'Can invite and manage carrier keys.';

  @override
  String get teamWorkspacesTitle => 'Workspaces';

  @override
  String get teamWorkspacesActiveLabel => 'Active';

  @override
  String get teamWorkspacesActiveBadgeTooltip => 'Currently active workspace';

  @override
  String get teamWorkspacesCreate => 'New workspace';

  @override
  String get teamWorkspacesCreateTitle => 'Create new workspace';

  @override
  String get teamWorkspacesCreateLabel => 'Name';

  @override
  String get teamWorkspacesCreateHint => 'e.g. Acme Ltd.';

  @override
  String get teamWorkspacesCreateSubmit => 'Create';

  @override
  String teamWorkspacesCreateSuccess(String name) {
    return 'Workspace \'$name\' created.';
  }

  @override
  String teamWorkspacesCreateFailed(String error) {
    return 'Create failed: $error';
  }

  @override
  String get teamWorkspacesCreateValidationLength =>
      'Name must be 1–80 characters.';

  @override
  String teamWorkspacesPlanUsage(String plan, int used, int limit) {
    return 'Plan $plan: $used/$limit workspaces';
  }

  @override
  String teamWorkspacesPlanUsageUnlimited(String plan, int used) {
    return 'Plan $plan: $used workspaces (unlimited)';
  }

  @override
  String get teamWorkspacesLimitReachedTitle => 'Limit reached';

  @override
  String teamWorkspacesLimitReachedBody(String plan, int limit) {
    return 'Your plan $plan allows $limit workspaces. Upgrade to create more.';
  }

  @override
  String get teamWorkspacesLimitReachedCta => 'Upgrade plan';

  @override
  String get teamWorkspacesSwitchTo => 'Switch';

  @override
  String get teamWorkspacesEmpty => 'You don\'t have any workspace yet.';

  @override
  String get teamInviteRoleEditor => 'Editor';

  @override
  String get teamInviteRoleObserver => 'Observer';

  @override
  String get teamInviteRoleAdminGated => 'Admin (Team plan and up)';

  @override
  String get teamInviteAdminLockedTooltip =>
      'Admin role requires Team plan or higher.';

  @override
  String get teamInviteEmailInvalid => 'Invalid email address.';

  @override
  String get teamInviteCreatedTitle => 'Invite created';

  @override
  String get teamInviteShareBody => 'Share this code with your teammate:';

  @override
  String get teamInviteCopyLink => 'Copy code';

  @override
  String get teamInviteCopyLinkSnack => 'Code copied.';

  @override
  String get teamInviteCopyFailed => 'Copy failed.';

  @override
  String get teamInviteShareEmailHint =>
      'E-mail dispatch ships with the next version.';

  @override
  String get teamMemberRemoveConfirmTitle => 'Remove member?';

  @override
  String teamMemberRemoveConfirmBody(String email) {
    return 'Remove $email from this workspace?';
  }

  @override
  String get teamMemberRoleChangeLoading => 'Saving role …';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get settingsTaxRateTitle => 'VAT rate';

  @override
  String get settingsTaxRateSubtitle =>
      'Default: 19%. New deals compute gross cost using factor 1.19.';

  @override
  String get settingsSortTitle => 'Default sort';

  @override
  String get settingsSortSubtitle =>
      'Deals are sorted by order date (descending) by default.';

  @override
  String get settingsSortValue => 'Date ↓';

  @override
  String get settingsCloudTitle => 'Cloud storage';

  @override
  String get settingsCloudSubtitle =>
      'Data is stored in your Supabase account and synced across devices.';

  @override
  String get settingsDataTitle => 'Data';

  @override
  String settingsDataSubtitle(int deals, int buyers, int shops, int items) {
    return '$deals deals · $buyers buyers · $shops shops · $items inventory items';
  }

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageTitle => 'Language / Sprache';

  @override
  String get settingsLanguageSubtitle =>
      'Switch between English and German. \"System\" follows the device setting.';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageDe => 'German';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsStatsSection => 'Statistics';

  @override
  String get settingsMonthlyGoalTitle => 'Monthly profit goal';

  @override
  String get settingsMonthlyGoalSubtitle =>
      'Shown in statistics as a progress ring + forecast.';

  @override
  String get settingsMonthlyGoalDialogTitle => 'Monthly profit goal';

  @override
  String get settingsLowStockTitle => 'Low-stock threshold';

  @override
  String get settingsLowStockSubtitle =>
      'Inventory items below this value are flagged as critical.';

  @override
  String get settingsLowStockDialogTitle => 'Low stock';

  @override
  String get settingsLowStockUnit => 'units';

  @override
  String settingsLowStockTrailing(int value) {
    return '< $value units';
  }

  @override
  String get pushFirebaseMissing =>
      'Firebase isn\'t configured on this device — preferences will be saved, but push notifications will only be delivered after Firebase is set up.';

  @override
  String get pushSectionTypes => 'Notification types';

  @override
  String get pushMhdTitle => 'Best-before warnings';

  @override
  String get pushMhdSubtitle => 'Batch is approaching its best-before date';

  @override
  String get pushMhdLeadTitle => 'Best-before lead time';

  @override
  String pushMhdLeadSubtitle(int days) {
    return '$days days before expiry';
  }

  @override
  String pushMhdLeadSliderLabel(int days) {
    return '$days days';
  }

  @override
  String get pushDeliveryTitle => 'Delivery hints';

  @override
  String get pushDeliverySubtitle =>
      'When a deal is expected to arrive today (in transit)';

  @override
  String get pushPaymentTitle => 'Payment reminders';

  @override
  String pushPaymentSubtitle(int days) {
    return 'Buyer hasn\'t paid after $days days';
  }

  @override
  String get pushPaymentLeadTitle => 'Reminder threshold';

  @override
  String pushPaymentLeadSubtitle(int days) {
    return '$days days';
  }

  @override
  String get pushSectionInfo => 'Notes';

  @override
  String get pushDailyCheckTitle => 'Daily check';

  @override
  String get pushDailyCheckSubtitle =>
      'The server runs daily at 09:00 (Europe/Berlin) and dispatches due notifications.';

  @override
  String get pushDedupTitle => 'Dedup';

  @override
  String get pushDedupSubtitle =>
      'Each warning is sent only once per batch/deal — across all your devices.';

  @override
  String pushSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get dealNew => 'New deal';

  @override
  String get dealEdit => 'Edit deal';

  @override
  String get dealOrderDate => 'Order date';

  @override
  String get dealArrivalDate => 'Arrival date';

  @override
  String get dealProduct => 'Product';

  @override
  String get dealShop => 'Shop';

  @override
  String get dealQuantity => 'Quantity';

  @override
  String get dealQuantityShort => 'Qty';

  @override
  String get dealShippingType => 'Shipping type';

  @override
  String get dealReship => 'Reship';

  @override
  String get dealDropship => 'Dropship';

  @override
  String get dealReceipt => 'Receipt';

  @override
  String get dealReceiptYes => 'Yes';

  @override
  String get dealReceiptNo => 'No';

  @override
  String get dealStatus => 'Status';

  @override
  String get dealNote => 'Note';

  @override
  String get dealComments => 'Comments';

  @override
  String get dealCommentPlaceholder => 'Add a note or comment…';

  @override
  String get dealCommentSend => 'Send';

  @override
  String get dealCommentEmpty => 'No comments yet.';

  @override
  String dealCommentLoadFailed(Object error) {
    return 'Couldn\'t load comments: $error';
  }

  @override
  String dealCommentSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get dealCommentDeleteTitle => 'Delete comment?';

  @override
  String get dealCommentDeleteText =>
      'This comment will be removed permanently.';

  @override
  String dealCommentDeleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String get dealSectionProduct => 'Product & shipping';

  @override
  String get dealSectionPrices => 'Prices';

  @override
  String get dealSectionBuyer => 'Buyer & status';

  @override
  String get dealSectionDateTracking => 'Date & tracking';

  @override
  String get dealSectionAttachments => 'Attachments';

  @override
  String get dealSectionNote => 'Note';

  @override
  String get dealEkPriceLabel => 'Cost price as:';

  @override
  String get dealPriceTypeNet => 'Net';

  @override
  String get dealPriceTypeGross => 'Gross';

  @override
  String get dealEkAmount => 'Cost amount';

  @override
  String get dealVkAmount => 'Sale amount';

  @override
  String get dealCurrency => 'Currency';

  @override
  String get dealTaxRate => 'VAT rate %';

  @override
  String get dealTaxRateHint => 'e.g. 19';

  @override
  String get dealTaxRateInvalid => 'Invalid number';

  @override
  String get dealTaxRateRange => '0 – 100';

  @override
  String get dealBuyer => 'Buyer';

  @override
  String get dealBuyerNone => '— None —';

  @override
  String get dealTicketNumber => 'Ticket number';

  @override
  String get dealTracking => 'Tracking';

  @override
  String get dealTicketUrl => 'Ticket URL (optional)';

  @override
  String get dealTicketUrlHint => 'Paste link from Discord…';

  @override
  String get dealDiscordChannelHint =>
      'Find channel → right-click → \"Copy link\" → paste here';

  @override
  String get dealDiscordTicketOpen => 'Open ticket in Discord';

  @override
  String dealDiscordServerOpen(int n) {
    return 'Open server $n in Discord';
  }

  @override
  String get dealProfitPreviewMissing =>
      'Profit preview: enter cost and sale price';

  @override
  String dealProfitPreviewLine(Object perUnit, Object total) {
    return 'Profit/unit $perUnit · Total $total';
  }

  @override
  String get dealStatusOrdered => 'Ordered';

  @override
  String get dealStatusShipping => 'Shipping';

  @override
  String get dealStatusArrived => 'Arrived';

  @override
  String get dealStatusInvoiced => 'Invoiced';

  @override
  String get dealStatusDone => 'Done';

  @override
  String get dealColId => 'ID';

  @override
  String get dealColEkNet => 'Cost (net)';

  @override
  String get dealColEkGross => 'Cost (gross)';

  @override
  String get dealColVk => 'Sale';

  @override
  String get dealColArrival => 'Arrival';

  @override
  String get dealColTicket => 'Ticket';

  @override
  String get dealColProfitUnit => 'Profit/unit';

  @override
  String get dealColProfitTotal => 'Total profit';

  @override
  String get dealColReceivable => 'Receivable';

  @override
  String get dealsEmpty => 'No deals found';

  @override
  String get dealsEmptyHint => 'Adjust filters or create a new deal.';

  @override
  String get dealsSearchHint => 'Product, ticket, tracking, note';

  @override
  String get dealsFilterDate => 'Date';

  @override
  String get dealsFilterReset => 'Reset filters';

  @override
  String get dealDeleteTitle => 'Delete entry';

  @override
  String dealDeleteConfirm(Object product, int id) {
    return 'Delete \"$product\" (ID: $id)?';
  }

  @override
  String get dealDeleteConfirmTitle => 'Delete deal?';

  @override
  String get dealDeleteConfirmMessage =>
      'This will remove the deal. You have 4 seconds to undo.';

  @override
  String get dealDeletedFeedback => 'Deal deleted';

  @override
  String get bulkStatus => 'Status';

  @override
  String get bulkBuyer => 'Buyer';

  @override
  String get bulkBuyerNone => 'No buyer';

  @override
  String get bulkChangeStatusTooltip => 'Change status';

  @override
  String get bulkAssignBuyerTooltip => 'Assign buyer';

  @override
  String get checkInDealTitle => 'Add to inventory?';

  @override
  String checkInDealText(int quantity, Object product) {
    return 'Create ${quantity}x $product as inventory item.';
  }

  @override
  String get checkInButton => 'Add to stock';

  @override
  String get checkInNo => 'No';

  @override
  String get inventoryStatusInStock => 'In stock';

  @override
  String get inventoryStatusReserved => 'Reserved';

  @override
  String get inventoryStatusShipped => 'Shipped';

  @override
  String get inventoryStatusSold => 'Sold';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpQuickStart => 'Quick start';

  @override
  String get helpStepShopsBuyersTitle => 'Add shops & buyers';

  @override
  String get helpStepShopsBuyersDesc =>
      'In Settings, add your sources and buyers. Both are required when creating a deal.';

  @override
  String get helpStepFirstDealTitle => 'Create your first deal';

  @override
  String get helpStepFirstDealDesc =>
      'Tap \"New deal\" at the bottom. The product field suggests previous products as you type.';

  @override
  String get helpStepStatsTitle => 'Statistics & goals';

  @override
  String get helpStepStatsDesc =>
      'The Statistics tab shows cashflow, profit and VAT quarters. Set a monthly profit goal in Settings.';

  @override
  String get helpDiscordSection => 'Discord integration';

  @override
  String get helpDiscordHowTitle => 'How linking works';

  @override
  String get helpDiscordHowDesc =>
      'Enter a ticket number on the deal — the app will show buttons to open the configured Discord servers. Find the channel, copy its link, paste it into \"Ticket URL\".';

  @override
  String get helpDiscordStep1Title => 'Enable developer mode';

  @override
  String get helpDiscordStep1Desc =>
      'Discord → Settings → Advanced → enable Developer Mode.';

  @override
  String get helpDiscordStep2Title => 'Copy server ID';

  @override
  String get helpDiscordStep2Desc =>
      'Right-click the server name → \"Copy server ID\".';

  @override
  String get helpDiscordStep3Title => 'Add server ID to a buyer';

  @override
  String get helpDiscordStep3Desc =>
      'Settings → Buyers tab → edit buyer → Discord server IDs.';

  @override
  String get helpDiscordConfiguredIds => 'Configured server IDs';

  @override
  String get helpDiscordNoBuyers => 'No buyers yet';

  @override
  String get helpDiscordNoBuyersDesc =>
      'Add buyers in Settings to attach server IDs.';

  @override
  String get helpDiscordNoServerIds => 'No server IDs configured';

  @override
  String get helpContactSection => 'Contact & feedback';

  @override
  String get helpContactReportTitle => 'Report issues';

  @override
  String get helpContactReportDesc =>
      'Describe the issue as precisely as possible. Screenshots help.';

  @override
  String get helpSearchHint => 'Search help…';

  @override
  String get helpSearchEmptyTitle => 'No results';

  @override
  String get helpSearchEmptyDesc =>
      'Try different terms, check the spelling, or clear the search field to see all sections.';

  @override
  String get helpExpandAll => 'Expand all';

  @override
  String get helpCollapseAll => 'Collapse all';

  @override
  String helpResultsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections found',
      one: '1 section found',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String get helpEntryWord => 'entry';

  @override
  String get helpEntriesWord => 'entries';

  @override
  String get helpStepLoginTitle => 'Create account & sign in';

  @override
  String get helpStepLoginDesc =>
      'Sign up with email or sign in with Google/Apple. Confirm your email via the link if asked, then you\'re ready to start.';

  @override
  String get helpStepWorkspaceTitle => 'Set up a workspace';

  @override
  String get helpStepWorkspaceDesc =>
      'On first sign-in a workspace is created for you automatically. From the workspace menu in the top-right you can create more workspaces or invite members.';

  @override
  String get helpStepInboxTitle => 'Connect your mailbox';

  @override
  String get helpStepInboxDesc =>
      'Attach your order mailbox (Gmail/Outlook/IONOS) under Settings → Mailbox. Order confirmations, shipping and delivery mails will then be detected automatically.';

  @override
  String get helpStepInventoryTitle => 'Maintain inventory';

  @override
  String get helpStepInventoryDesc =>
      'In the Inventory tab add items with stock count and minimum stock level. Sold items are removed from stock automatically and surface in the \"Sold\" tab.';

  @override
  String get helpInboxSection => 'Mailbox (email import)';

  @override
  String get helpInboxIntro =>
      'The app reads your mailbox via IMAP, detects order confirmations and shipping mails and proposes them as deals. No mail is ever sent.';

  @override
  String get helpInboxGmailTitle => 'Connect Gmail / Google Workspace';

  @override
  String get helpInboxGmailDesc =>
      'Gmail does not allow login with your normal password. You need an app password:\n• Enable two-factor authentication at myaccount.google.com → Security.\n• Open myaccount.google.com/apppasswords, name it (e.g. \"Inventory app\") and copy the 16-character app password.\n• In the app: Settings → Mailbox → IMAP server \"imap.gmail.com\", port 993, SSL, username = your mail, password = the app password.';

  @override
  String get helpInboxOutlookTitle => 'Connect Outlook.com / Microsoft 365';

  @override
  String get helpInboxOutlookDesc =>
      'Outlook and Microsoft 365 also use app passwords:\n• Sign in to account.microsoft.com → Security → Advanced security options → create an app password.\n• In the app: IMAP server \"outlook.office365.com\", port 993, SSL, username = your mail, password = the app password.\n• Note: school/work tenants often require admin approval first.';

  @override
  String get helpInboxIonosTitle => 'Connect IONOS / 1&1';

  @override
  String get helpInboxIonosDesc =>
      'IONOS supports the regular mail login directly:\n• IMAP server \"imap.ionos.de\" (or \".com\" depending on region), port 993, SSL.\n• Username = full mail address, password = your mailbox password.\n• If login fails: in IONOS Webmail under \"Settings → Security\" check whether IMAP is enabled.';

  @override
  String get helpInboxTabsTitle => 'The three inbox tabs';

  @override
  String get helpInboxTabsDesc =>
      'Incoming mails land in three tabs depending on how confidently the app can classify them.';

  @override
  String get helpInboxTabSuggestions =>
      'Suggestions — order confirmations not yet linked to a deal. Tap a mail, review the parsed fields, accept it as a new deal.';

  @override
  String get helpInboxTabUpdated =>
      'Updated — mails that change an existing deal (e.g. shipping update, cancellation). Here you see what the pipeline applied automatically.';

  @override
  String get helpInboxTabUnclassified =>
      'Unclassified — mails the app could not assign confidently. You can link them to a deal manually or mark them irrelevant.';

  @override
  String get helpInboxWhitelistTitle => 'Why don\'t I see some mails?';

  @override
  String get helpInboxWhitelistDesc =>
      'The app only reads mails from known shops/carriers (whitelist). Marketing newsletters, personal mail and unknown senders are ignored. If a shop is missing, report it via \"Report issues\" — new adapters are added server-side.';

  @override
  String get helpDealsSection => 'Deals';

  @override
  String get helpDealsStatusFlow =>
      'Each deal goes through five statuses — you can advance it manually or the mail pipeline does it for you.';

  @override
  String get helpDealsStatusOrdered =>
      'Ordered — the deal is created but not yet shipped. Set this once you have placed the order.';

  @override
  String get helpDealsStatusInTransit =>
      'In transit — shipping confirmation detected or set manually. As soon as a tracking number is assigned, the app checks the status once right away and then automatically at the right cadence: out for delivery every hour, in transit roughly every 4 hours (paused overnight). You don\'t have to tap anything.';

  @override
  String get helpDealsStatusArrived =>
      'Arrived — the carrier reports delivery to the sender (you). The item is ready to be listed/shipped onward.';

  @override
  String get helpDealsStatusSold =>
      'Sold — buyer is set, sales price recorded. The deal now counts toward statistics.';

  @override
  String get helpDealsStatusDelivered =>
      'Delivered — end customer received the item. Final status, deal is closed.';

  @override
  String get helpDealsTrackingTitle => 'Auto-tracking from mails';

  @override
  String get helpDealsTrackingDesc =>
      'When a shipping mail arrives, the app detects the tracking number purely from its structure (format + checksum) — DHL, DPD, Amazon Logistics, GLS, UPS and Hermes are recognised. No carrier API key is required for this: the number is always saved and the deal flips to \"In transit\" automatically. The live status (out for delivery, delivered) is fetched once a matching carrier API key is set — immediately on assignment and then automatically at the right cadence (out for delivery hourly, in transit ~every 4 hours, paused overnight). Amazon Logistics and GLS are detected but can\'t be tracked live (see FAQ) — for GLS there\'s at least a direct link to the tracking page. See the \"Shipping & carrier API keys\" section for details.';

  @override
  String get helpDealsDropShipTitle => 'Multi drop-ship';

  @override
  String get helpDealsDropShipDesc =>
      'If a deal sources from several shops (drop-ship), you can record multiple sources with their purchase prices when creating it. Profit is summed across sources, but the statistic counts the deal as one sale.';

  @override
  String get helpDealsRetrackTitle => 'Refresh shipment status now (Retrack)';

  @override
  String get helpDealsRetrackDesc =>
      'In the deal detail view, next to the tracking number, you\'ll find a refresh icon labelled \"Refresh status\". It asks the carrier for the current status right away instead of waiting for the next automatic check — handy, for example, just before a planned delivery.\nOne retrack per deal is allowed every 30 seconds. While the lock is active the button is greyed out and shows \"Please wait 30s\" — that protects the carrier API from unnecessary calls and you from rate limits.\nFor Amazon Logistics and GLS shipments the button stays greyed out permanently: there\'s no public live status to refresh for those services.';

  @override
  String get helpDealsTimelineTitle => 'Shipment timeline';

  @override
  String get helpDealsTimelineDesc =>
      'If a deal has a trackable tracking number, the deal detail shows a Klarna-style shipment timeline below the status: every stop of the parcel with a timestamp and — when the carrier provides it — the location. The newest entry sits at the top and is highlighted.\nThe timeline loads automatically when you open the deal. With many stops you\'ll see the latest four first; \"Show all events\" expands the full history and collapses it again.';

  @override
  String get helpDealsEtaTitle => 'Estimated delivery';

  @override
  String get helpDealsEtaDesc =>
      'As soon as the carrier provides a delivery estimate, an \"Estimated delivery\" line with the projected date appears in the tracking block. It\'s the carrier\'s estimate, not a guarantee — it can shift. Once the parcel is delivered, the line disappears.';

  @override
  String get helpDealsCopyLinkTitle => 'Copy & track the tracking number';

  @override
  String get helpDealsCopyLinkDesc =>
      'The tracking block in the deal detail has two buttons:\n• \"Copy\" puts the tracking number on the clipboard — handy for pasting it elsewhere.\n• \"Track shipment\" opens the carrier\'s official tracking page (e.g. DHL, DPD, GLS, UPS, Hermes) straight away with your number. Amazon Logistics has no public page, so the button is absent there.';

  @override
  String get helpShippingSection => 'Shipping & carrier API keys';

  @override
  String get helpShippingIntroTitle => 'Why carrier API keys?';

  @override
  String get helpShippingIntroDesc =>
      'The app detects tracking numbers from your mails automatically — no API key needed for that. The key is only required for the live status: so the app can fetch the current shipping status (out for delivery, delivered) straight from the carrier, you store one API key per carrier under Settings → Shipping. One key per carrier per workspace is enough — every member benefits from it.';

  @override
  String get helpShippingDhlTitle => 'DHL — actively supported';

  @override
  String get helpShippingDhlDesc =>
      'DHL works out of the box:\n• Create an account on developer.dhl.com (free).\n• Subscribe to the \"Shipment Tracking - Unified\" API there — the free tier is enough for personal use.\n• Copy the API key and paste it under Settings → Shipping → DHL → \"Save API key\".\n• Right after, tap Settings → \"Re-evaluate tracking numbers\" once so your existing mails are re-parsed by the new DHL-API pipeline.\nFrom now on, deals with a DHL tracking number are refreshed at regular intervals and the status (in transit, out for delivery, delivered) appears directly on the deal.';

  @override
  String get helpShippingApiOnlyTitle =>
      'How does the app spot a real tracking number?';

  @override
  String get helpShippingApiOnlyDesc =>
      'A single mail often contains several numbers that look like a tracking code (order no., customer no., invoice no.). The app checks each candidate against its structure: carrier format, length and checksum have to match exactly, and a shipping-related keyword must appear nearby. Values that only happen to look like a tracking code are discarded — a German VAT ID (two letters + nine digits, e.g. DE123456789) is therefore never mistakenly saved as a tracking number. You see at most one tracking number per mail, and it\'s structurally verified. This works entirely without an API key.';

  @override
  String get helpShippingComingSoonTitle => 'Which carriers are supported?';

  @override
  String get helpShippingComingSoonDesc =>
      'Tracking numbers from DHL, DPD, Amazon Logistics and GLS are detected automatically from mails.\n• DHL: detection plus live status once your DHL API key is set.\n• DPD: detection plus a direct link to DPD tracking — automatic live status is in preparation.\n• Amazon Logistics: detected and saved, but no live status — Amazon doesn\'t offer a public status API.\n• GLS: detected and saved (e.g. from shop mails like PcComponentes), no live status — but you get a direct link to GLS tracking.\n• UPS: detected reliably via the unique 1Z format — live status to follow; direct link until then.\n• Hermes: only detected with clear Hermes context in the mail (prevents mix-ups with DHL/DPD numbers) — direct link to Hermes tracking included.';

  @override
  String get helpShippingDpdTitle => 'DPD — live status coming soon';

  @override
  String get helpShippingDpdDesc =>
      'DPD tracking numbers are already detected from your mails automatically, and \"Track shipment\" on the deal takes you straight to DPD\'s tracking page. The automatic in-app live status for DPD (status-change push, timeline) is in preparation and will be enabled once available — the card under Settings → Shipping will then show the key field instead of \"Coming soon\".';

  @override
  String get helpShippingKeySafetyTitle => 'What happens to my API key?';

  @override
  String get helpShippingKeySafetyDesc =>
      'The plaintext key leaves your device exactly once, when you save it, and is then stored encrypted on the server. In the app you only see the last four characters afterwards, e.g. \"••••••••a1b2\". You can replace or delete the key at any time — deleting it pauses the automatic status polls for that carrier.';

  @override
  String get helpInventorySection => 'Inventory';

  @override
  String get helpInventoryAddTitle => 'Add an item';

  @override
  String get helpInventoryAddDesc =>
      'Inventory tab → \"Add item\". Required: name + quantity. Optional: purchase price, minimum stock, sales channel, photo. For multiple units of the same item, increase the quantity instead of creating a new entry.';

  @override
  String get helpInventoryStockTitle => 'Update quantities';

  @override
  String get helpInventoryStockDesc =>
      'Tap an item and use the +/- buttons, or edit the quantity field directly. On a sale the quantity is decreased automatically when you pick the item in the deal form.';

  @override
  String get helpInventoryMinStockTitle => 'Minimum stock & warnings';

  @override
  String get helpInventoryMinStockDesc =>
      'Set a minimum stock per item (e.g. 2). Once the quantity drops below it, a yellow warning appears on the dashboard and inventory tab — and optionally a push notification.';

  @override
  String get helpInventorySoldTabTitle => 'Sold tab';

  @override
  String get helpInventorySoldTabDesc =>
      'Sold items disappear from stock and surface in the \"Sold\" tab. There you see buyer, sales price and profit per unit, filterable by date and buyer.';

  @override
  String get helpInventoryStockValueTitle => 'Stock value calculation';

  @override
  String get helpInventoryStockValueDesc =>
      'The stock value at the top of the tab sums (quantity × purchase price) across items with a purchase price. Items without a purchase price contribute 0 — please backfill them, otherwise the statistic is off.';

  @override
  String get helpEntitiesSection => 'Buyers, shops & suppliers';

  @override
  String get helpEntitiesBuyersTitle => 'Buyers';

  @override
  String get helpEntitiesBuyersDesc =>
      'People or platforms you sell to (e.g. \"Tobias\", \"eBay-Kleinanzeigen\", \"Vinted\"). Required-ish in the deal form — without a buyer there is no sale.';

  @override
  String get helpEntitiesShopsTitle => 'Shops';

  @override
  String get helpEntitiesShopsDesc =>
      'Online/offline sources you buy from (e.g. \"Amazon\", \"Saturn\", \"Otto\"). On shipping mails the app maps the mail to the matching shop automatically if the adapter recognises the sender.';

  @override
  String get helpEntitiesSuppliersTitle => 'Suppliers';

  @override
  String get helpEntitiesSuppliersDesc =>
      'Special case for B2B sources with payment terms (Net 30, Net 60). Suppliers live in their own tab and are linked to deals as a source — the due-date statistic then shows open balances.';

  @override
  String get helpEntitiesBuyerColorTitle => 'Buyer colour coding';

  @override
  String get helpEntitiesBuyerColorDesc =>
      'Each buyer can be assigned a colour (buyer card → pick colour). The colour appears in the deal table and statistics so you can see who a deal went to at a glance.';

  @override
  String get helpTicketsSection => 'Tickets';

  @override
  String get helpTicketsWhatTitle => 'What is a ticket?';

  @override
  String get helpTicketsWhatDesc =>
      'A ticket bundles several deals that go to the same buyer together — e.g. a bulk order with five items. The ticket sees the total price, all tracking numbers and a single shipping status.';

  @override
  String get helpTicketsArchiveTitle => 'Active vs archive';

  @override
  String get helpTicketsArchiveDesc =>
      'Active tickets are not yet closed. Once all deals in a ticket are at \"Delivered\", you can archive it — it disappears from the main view but remains in statistics.';

  @override
  String get helpStatsSection => 'Statistics';

  @override
  String get helpStatsKpiTitle => 'KPI cards';

  @override
  String get helpStatsKpiDesc =>
      'At the top you see revenue, profit, deal count and cashflow for the chosen range. Tap a card to jump to its detail view.';

  @override
  String get helpStatsChartsTitle => 'Charts';

  @override
  String get helpStatsChartsDesc =>
      'Line chart for revenue/profit over time, bar chart for top buyers and shops. Tap a bar to filter by that buyer/shop.';

  @override
  String get helpStatsFiltersTitle => 'Filters (buyer/shop/date)';

  @override
  String get helpStatsFiltersDesc =>
      'Use the filter icon at the top right to combine buyer, shop and date range. Filters are applied to all cards and charts in sync.';

  @override
  String get helpStatsTaxTitle => 'Tax / VAT reports';

  @override
  String get helpStatsTaxDesc =>
      'Statistics → \"Tax\" tab shows quarterly revenue + a VAT estimate (small business or standard regime). CSV export per quarter via the download icon. The estimate does not replace tax advice.';

  @override
  String get helpWorkspaceSection => 'Workspace & team';

  @override
  String get helpWorkspaceWhatTitle => 'What is a workspace?';

  @override
  String get helpWorkspaceWhatDesc =>
      'A workspace is an isolated data container — every deal, buyer, shop and inventory item belongs to exactly one workspace. You can keep multiple workspaces in parallel (e.g. \"Personal\" and \"Business\").';

  @override
  String get helpWorkspaceInviteTitle => 'Invite members';

  @override
  String get helpWorkspaceInviteDesc =>
      'Settings → Team → \"Invite member\". Provide a mail address and a role. The invitee receives a mail with a link; once they sign up the workspace appears on their side.';

  @override
  String get helpWorkspaceRolesTitle => 'Roles';

  @override
  String get helpWorkspaceRoleOwner =>
      'Owner — can do everything, including deleting the workspace, removing members and changing the plan.';

  @override
  String get helpWorkspaceRoleAdmin =>
      'Admin — read/write access, can invite members and manage carrier keys. Cannot delete the workspace.';

  @override
  String get helpWorkspaceRoleMember =>
      'Member — read/write access but cannot change team or carrier settings.';

  @override
  String get helpWorkspacePricingTitle => 'Pricing tier limits';

  @override
  String get helpWorkspacePricingDesc =>
      'Free, Pro and Business mainly differ in number of members, number of mailboxes and whether carrier polling is active. Current limits are on the pricing screen.';

  @override
  String get helpWorkspacesHowManyTitle => 'How many workspaces can I create?';

  @override
  String get helpWorkspacesHowManyBody =>
      'Depends on your plan: Free / Solo = 1, Solo Pro = 2, Team = 5, Business = 20, Enterprise = unlimited. The limit is enforced server-side. Need more? Upgrade your plan.';

  @override
  String get helpInviteHowTitle => 'How do I invite someone?';

  @override
  String get helpInviteHowBody =>
      'Settings → Team → \'Invite\'. Pick an email + role (editor or observer). You\'ll get a code to share with the recipient via messenger/email. They sign up with the same email and accept the invite from the bell icon top-right. Automatic e-mail dispatch ships with a later version.';

  @override
  String get helpRolesEditorObserverTitle => 'What roles are available?';

  @override
  String get helpRolesEditorObserverBody =>
      'Four roles: Owner (full control, can rename/delete workspace), Admin (can invite + manage members), Editor (read + edit data), Observer (read-only). Admin role requires Team plan or higher.';

  @override
  String get helpPushSection => 'Push notifications';

  @override
  String get helpPushIosTitle => 'Enable on iOS';

  @override
  String get helpPushIosDesc =>
      'On first launch iOS asks whether the app may send notifications — confirm with \"Allow\". If you declined: iOS Settings → Notifications → Inventory app → Allow notifications.';

  @override
  String get helpPushAndroidTitle => 'Enable on Android';

  @override
  String get helpPushAndroidDesc =>
      'Android 13+ asks explicitly for push permission. If you declined: Android Settings → Apps → Inventory app → Notifications → enable.';

  @override
  String get helpPushWhenTitle => 'When are pushes sent?';

  @override
  String get helpPushWhenDesc =>
      '• New order confirmation in the mailbox\n• Shipment status change (in transit, out for delivery, delivered)\n• Minimum stock undercut (if enabled)\n• Workspace invitation\nYou can disable individual categories under Settings → Push.';

  @override
  String get helpPushDeliveryTitle => 'Push on shipment status change';

  @override
  String get helpPushDeliveryDesc =>
      'Whenever a shipment\'s real status changes, you get a push notification automatically — e.g. \"Parcel in transit 📦\", \"Parcel out for delivery 🚚\" or \"Parcel delivered ✅\". There\'s at most one notification per status change, so you won\'t get flooded with duplicates.\nTapping the notification opens the matching deal directly in the app.\nDon\'t want them? Disable the \"Deliveries\" category under Settings → Push — those pushes then stop, while the automatic background updates keep running.';

  @override
  String get helpFaqSection => 'Frequently asked questions (FAQ)';

  @override
  String get helpFaqQ1 =>
      'Why don\'t I see any mails after adding the mailbox?';

  @override
  String get helpFaqA1 =>
      'The first sync runs in the background and can take 1–10 minutes depending on mailbox size. Also, only mails from known shops/carriers are imported — marketing and personal mails are ignored.';

  @override
  String get helpFaqQ2 => 'How do I change the language?';

  @override
  String get helpFaqA2 =>
      'Settings → General → Language. Available right now: German, English. The change is applied immediately.';

  @override
  String get helpFaqQ3 => 'How do I delete my data?';

  @override
  String get helpFaqA3 =>
      'Settings → General → \"Delete account\". You must type the word DELETE to confirm. Account, workspaces and mailbox configuration are deleted immediately; mail metadata and stored images are removed from the database and storage within 30 days.';

  @override
  String get helpFaqQ4 => 'What happens if I downgrade?';

  @override
  String get helpFaqA4 =>
      'Existing data is preserved. Features above the downgrade limit (e.g. extra members, carrier polling) are paused until you upgrade again or actively reduce below the limit.';

  @override
  String get helpFaqQ5 => 'How do I reset my password?';

  @override
  String get helpFaqA5 =>
      'Login screen → \"Forgot password\". Enter your mail, you\'ll receive a reset link. Tapping the link opens the app and lets you set a new password.';

  @override
  String get helpFaqQ6 => 'Why is my stock value wrong?';

  @override
  String get helpFaqA6 =>
      'The stock value only counts items with a recorded purchase price. Open the inventory tab and filter for \"Without purchase price\" — backfill the missing values and the total will match.';

  @override
  String get helpFaqQ7 => 'Tracking is not updating — what now?';

  @override
  String get helpFaqA7 =>
      'The app fetches the live status once as soon as a deal gets a tracking number, and then daily at 1:00 PM. If you don\'t want to wait that long, use the \"Refresh status\" icon in the deal detail view (allowed every 30s per deal). If the status stays empty, check under Settings → Shipping whether the carrier API key is set — the tracking number itself is detected and saved even without a key, but the key is required for the live status. Amazon Logistics shipments never have a live status (see the next question).';

  @override
  String get helpFaqQ8 => 'Can I use multiple workspaces?';

  @override
  String get helpFaqA8 =>
      'Yes. Tap the workspace name top-right → \"New workspace\". Switch with one tap; data is strictly isolated.';

  @override
  String get helpFaqQ9 => 'Discord buttons are missing on a deal — why?';

  @override
  String get helpFaqA9 =>
      'Buttons only appear if the buyer has at least one Discord server ID configured. Settings → Buyers → edit buyer → add Discord server IDs.';

  @override
  String get helpFaqQ10 => 'How do I export my data as CSV?';

  @override
  String get helpFaqA10 =>
      'Statistics → Tax tab → download icon (per quarter). A full data export is in preparation — until then please request it via \"Report issues\".';

  @override
  String get helpFaqQ11 => 'How do I create a tax report?';

  @override
  String get helpFaqA11 =>
      'Statistics → Tax tab → pick a quarter → download CSV. The app shows gross, net and VAT share; the breakdown depends on your tax regime (small business or standard).';

  @override
  String get helpFaqQ12 => 'How do I enable dark mode?';

  @override
  String get helpFaqA12 =>
      'Settings → General → Theme → \"Dark\". Optionally \"System\" — then it follows the iOS/Android system setting.';

  @override
  String get helpFaqQ13 => 'Can I temporarily disable my account?';

  @override
  String get helpFaqA13 =>
      'Not directly — there is only \"Delete account\". To pause push and mail sync: remove the mailbox in settings and disable push categories. Data stays as-is.';

  @override
  String get helpFaqQ14 => 'How do I disable push notifications?';

  @override
  String get helpFaqA14 =>
      'Either per category in Settings → Push, or completely via OS settings (iOS Notifications / Android notifications → Inventory app).';

  @override
  String get helpFaqQ15 => 'How do I search inside the inbox?';

  @override
  String get helpFaqA15 =>
      'Inbox tab → search icon top-right. You can search by sender, subject or tracking number. The search filters all three tabs (Suggestions / Updated / Unclassified) at the same time.';

  @override
  String get helpFaqQ16 => 'Why don\'t I see deals from other members?';

  @override
  String get helpFaqA16 =>
      'You may be in the wrong workspace. Check the workspace name top-right and switch if needed. Filters (buyer/shop/date) can also hide deals — clear them with the \"Clear filters\" button.';

  @override
  String get helpFaqQ17 => 'What does the \"Review\" badge on a shipment mean?';

  @override
  String get helpFaqA17 =>
      'The app has stored a tracking value, but our new detector isn\'t sure it really is a valid tracking number (e.g. because it comes from an older mail with an unclear format). Tap the deal and check the tracking card: \"Accept\" confirms the value, \"Dismiss\" clears it. On the deals list, the \"Review\" chip filters all affected deals at once.';

  @override
  String get helpFaqQ18 =>
      'How does \"Re-evaluate tracking numbers\" in Settings work?';

  @override
  String get helpFaqA18 =>
      'Settings → General → \"Re-evaluate tracking numbers\" rechecks every stored mail in this workspace with the latest, stricter detector. Wrongly stored values get flagged as \"Review\", newly recognised real trackings replace empty entries. Manually entered tracking numbers stay untouched. To protect against runaway loops, this runs at most once every 5 minutes per workspace.';

  @override
  String get helpFaqQ19 =>
      'Why is a tracking number sometimes empty even though the shipping mail is there?';

  @override
  String get helpFaqA19 =>
      'The app only stores a tracking number when it is structurally verified (carrier format + length/checksum check + a shipping-related keyword nearby). When a mail only contains a similar-looking number (e.g. a VAT ID, IBAN or plain order number) or the number is ambiguously formatted, the app deliberately leaves the field empty instead of saving a wrong value. You can always enter the tracking number manually on the deal — manual entries are never overwritten automatically.';

  @override
  String get helpTroubleSection => 'Troubleshooting';

  @override
  String get helpTroubleConnectionTitle => '\"No connection to server\"';

  @override
  String get helpTroubleConnectionDesc =>
      'Check your internet connection and try \"Refresh\" (pull-to-refresh). If the issue persists: check the status page on the website, wait a few minutes — Supabase restarts can take a moment.';

  @override
  String get helpTroubleImapAuthTitle => '\"IMAP login failed\"';

  @override
  String get helpTroubleImapAuthDesc =>
      'For Gmail/Outlook: make sure you use an app password, not your normal login password. For IONOS check that IMAP is enabled server-side. Typos in the server hostname are the most common cause.';

  @override
  String get helpTroubleSyncStuckTitle => 'Mailbox sync is stuck';

  @override
  String get helpTroubleSyncStuckDesc =>
      'Settings → Mailbox → select mailbox → \"Re-sync\". If still no mails arrive: remove the mailbox and re-add it — the bootstrap pump will then re-fetch all mails from the past 60 days.';

  @override
  String get helpTroubleNotifMissingTitle => 'Push notifications don\'t arrive';

  @override
  String get helpTroubleNotifMissingDesc =>
      'First check the OS notification settings (iOS Notifications / Android notifications → Inventory app → notifications allowed?). Then in the app under Settings → Push verify the individual categories are enabled. If everything is set to \"allowed\" and still nothing arrives, sign out and back in — that re-registers the push token.';

  @override
  String get helpTroubleStatsEmptyTitle => 'Statistics are empty';

  @override
  String get helpTroubleStatsEmptyDesc =>
      'Statistics only count deals with status \"Sold\" or \"Delivered\" and a sales price > 0. Check your date filter (top right) — it may be set to an empty range.';

  @override
  String get helpTroubleLoginFailedTitle => 'Login does not work';

  @override
  String get helpTroubleLoginFailedDesc =>
      'Make sure your mail is confirmed (link from welcome mail). For Google/Apple sign-in: help the app open the browser tab — some in-app browsers block the callback. Worst case, reset the password.';

  @override
  String get helpTroubleUploadFailedTitle => 'Photo upload fails';

  @override
  String get helpTroubleUploadFailedDesc =>
      'Images larger than 10 MB are rejected. Reduce size/quality, or grant the app access to photos/media library in OS settings. On a very slow connection upload can time out after 60 s — retry.';

  @override
  String get helpTroubleSlowTitle => 'App is suddenly slow';

  @override
  String get helpTroubleSlowDesc =>
      'Very long deal/inbox lists? Apply filters (date, status, buyer) to reduce render load. Fully quitting and restarting the app clears volatile in-memory caches. On older devices, archiving old tickets also helps.';

  @override
  String get helpTroubleCarrierSetupTitle =>
      '\"Setup incomplete: master key not configured\"';

  @override
  String get helpTroubleCarrierSetupDesc =>
      'This message appears when you try to save a carrier API key but the backend has no master key to encrypt it with. It\'s not a problem with your account but a one-off backend setup step:\n• Hosted setup (regular users): wait a moment and try again — we set the master key centrally, usually within a few hours.\n• Self-hoster / Supabase admin: migration `20260516000000_carrier_master_key_bootstrap.sql` must be applied and the `CARRIER_MASTER_KEY` secret has to be set at the Supabase project level. Admin details live in the repo at `supabase/functions/tracking-poll/SETUP.md`.\nUntil it\'s fixed you can keep updating shipments manually — only the automatic per-carrier live status is paused.';

  @override
  String get helpTroubleLowStockPushTitle =>
      'Low-stock push notifications not arriving';

  @override
  String get helpTroubleLowStockPushDesc =>
      'First check that push notifications are generally allowed (OS Settings → Notifications → your app). Then: Settings → Push → is the \"Low stock\" category enabled? Note: low-stock pushes are batched per workspace — the notification contains a count only, no product names. If the dashboard already shows the affected items, the alert logic is working correctly; only the push token may be stale — log out and back in to re-register it.';

  @override
  String get helpTroubleStatusStaleTitle =>
      'Shipment status not updating / no status-change push';

  @override
  String get helpTroubleStatusStaleDesc =>
      'The automatic check runs at the right cadence (out for delivery hourly, in transit ~every 4 hours) and pauses overnight. So right after a shipment goes out it can take a moment for anything to show — for an instant snapshot, tap \"Refresh status\" on the deal.\nNot getting a status-change push? Settings → Push → is the \"Deliveries\" category enabled? It also needs a live status, which is currently only available for DHL with a stored API key (DPD coming soon) — Amazon Logistics and GLS have no live status and therefore no status-change push.';

  @override
  String get helpWarenwirtschaftSection => 'Warehouse hub';

  @override
  String get helpWarenwirtschaftIntroTitle => 'What is the Warehousing tab?';

  @override
  String get helpWarenwirtschaftIntroDesc =>
      'The Warehousing tab is the central entry point for everything related to your product catalog, warehouses, orders, and stocktakes. From there you can reach all sub-areas with a single tap.';

  @override
  String get helpWarenwirtschaftSubroutesTitle => 'Sub-areas at a glance';

  @override
  String get helpWarenwirtschaftSubroutesDesc =>
      '• Product catalog — create and manage reusable products\n• Categories — organise products into groups\n• Orders — purchase orders to suppliers\n• Warehouses — manage multiple physical storage locations\n• Stocktake — count and reconcile your stock\n• Reports — stock valuation, inventory turnover, ABC analysis';

  @override
  String get helpProductCatalogSection => 'Product catalog & categories';

  @override
  String get helpProductCatalogWhatTitle => 'What is the product catalog?';

  @override
  String get helpProductCatalogWhatDesc =>
      'The product catalog lets you create products once as a master record — with a name, SKU, EAN, unit, default cost price, and minimum stock level. Whenever you book goods in or receive a purchase order, the app automatically links the stock entry to the matching master product.';

  @override
  String get helpProductCatalogNewTitle => 'Create a new product';

  @override
  String get helpProductCatalogNewDesc =>
      'Warehousing → Product catalog → \"+\" button. Required: name. Optional: SKU, EAN, category, supplier, default cost price, minimum stock, unit. The SKU must be unique within your workspace.';

  @override
  String get helpProductCatalogCategoryTitle => 'Categories';

  @override
  String get helpProductCatalogCategoryDesc =>
      'Categories help you structure your product catalog — for example \"Electronics\", \"Clothing\", or \"Accessories\". You can create up to two levels (group → subgroup). Warehousing → Categories → \"+\" button.';

  @override
  String get helpProductCatalogDetailTitle => 'Product detail view';

  @override
  String get helpProductCatalogDetailDesc =>
      'Tap any product to open the 360° view: current stock across all warehouses, movement history (typed by goods-in, sale, correction, stocktake, transfer), batches, and linked suppliers.';

  @override
  String get helpProductCatalogMovementsTitle => 'Movement types';

  @override
  String get helpProductCatalogMovementsDesc =>
      'Every stock change is recorded with a movement type:\n• Goods in — stock arriving at your warehouse (e.g. a delivery)\n• Goods out — stock leaving your warehouse\n• Correction — manual quantity adjustment\n• Stocktake — difference posted from a stocktake session\n• Transfer — move between warehouse locations\n• Sale — deal completed';

  @override
  String get helpPurchaseOrdersSection => 'Purchase orders';

  @override
  String get helpPurchaseOrdersWhatTitle => 'What are purchase orders?';

  @override
  String get helpPurchaseOrdersWhatDesc =>
      'When stock runs low, you create a purchase order to a supplier. The app tracks order lines, quantities, and delivery status — from draft through to fully received.';

  @override
  String get helpPurchaseOrdersNewTitle => 'Create a new order';

  @override
  String get helpPurchaseOrdersNewDesc =>
      'Warehousing → Orders → \"+\" button → select supplier → add products and quantities → save. The app assigns an order number automatically (e.g. PO-2026-0001).';

  @override
  String get helpPurchaseOrdersStatusTitle => 'Order status';

  @override
  String get helpPurchaseOrdersStatusDesc =>
      '• Draft — not yet submitted to the supplier\n• Ordered — sent to the supplier\n• Partially received — first partial delivery arrived\n• Received — fully delivered\n• Cancelled — order was called off';

  @override
  String get helpPurchaseOrdersReceiveTitle => 'Book a goods receipt';

  @override
  String get helpPurchaseOrdersReceiveDesc =>
      'Open order details → \"Book goods receipt\". For each line you see the ordered and already received quantity; enter the newly arrived amount. The app updates stock and automatically sets the order status to \"Partially received\" or \"Received\".';

  @override
  String get helpPurchaseOrdersPdfTitle => 'Export order as PDF';

  @override
  String get helpPurchaseOrdersPdfDesc =>
      'Open an order → PDF icon in the top right. The app generates an order document with all lines, ready to share or print.';

  @override
  String get helpPurchaseOrdersReorderTitle => 'Quick reorder';

  @override
  String get helpPurchaseOrdersReorderDesc =>
      'The dashboard shows an alert when any article falls below its minimum stock. Tap \"Reorder now\" to open a pre-filled purchase order for the affected items.';

  @override
  String get helpWarehousesSection => 'Warehouse management';

  @override
  String get helpWarehousesWhatTitle => 'Using multiple warehouses';

  @override
  String get helpWarehousesWhatDesc =>
      'You can create several physical storage locations — for example \"Main warehouse\", \"Off-site storage\", or \"Office\". When booking stock in, you choose which warehouse receives the quantity. Warehousing → Warehouses.';

  @override
  String get helpWarehousesNewTitle => 'Create a new warehouse';

  @override
  String get helpWarehousesNewDesc =>
      'Warehousing → Warehouses → \"+\" button → enter a name (e.g. \"Main warehouse\") → optionally an address → save. The first warehouse is automatically set as the default.';

  @override
  String get helpWarehousesDefaultTitle => 'Default warehouse';

  @override
  String get helpWarehousesDefaultDesc =>
      'The warehouse marked as default is pre-selected when booking stock in. Each workspace can have exactly one default warehouse. You can change the default at any time.';

  @override
  String get helpWarehousesStockTitle => 'View stock per warehouse';

  @override
  String get helpWarehousesStockDesc =>
      'On the product detail page (Warehousing → Product catalog → tap a product) you see stock split by warehouse. Total stock and minimum stock are summed across all warehouses.';

  @override
  String get helpStocktakeSection => 'Stocktake';

  @override
  String get helpStocktakeWhatTitle => 'What is a stocktake?';

  @override
  String get helpStocktakeWhatDesc =>
      'A stocktake lets you count your actual stock and compare it to the quantities recorded in the app. Differences are automatically posted as correction entries.';

  @override
  String get helpStocktakeStartTitle => 'Start a stocktake';

  @override
  String get helpStocktakeStartDesc =>
      'Warehousing → Stocktake → \"+\" button → optionally choose a warehouse and title → \"Start stocktake\". The app takes a snapshot of current stock quantities as the expected values.';

  @override
  String get helpStocktakeCountTitle => 'Count items';

  @override
  String get helpStocktakeCountDesc =>
      'Enter the physically counted quantity for each item. The \"Uncounted only\" filter hides already processed items. You can jump straight to an item using the barcode scanner. Entries are saved immediately — even if the app goes offline.';

  @override
  String get helpStocktakeCloseTitle => 'Close a stocktake';

  @override
  String get helpStocktakeCloseDesc =>
      'Once all items are counted (the progress indicator at the top reaches 100 %), tap \"Close stocktake\". The app posts all differences as stocktake corrections and produces a difference report. This action cannot be undone.';

  @override
  String get helpStocktakeDiffTitle => 'Difference report';

  @override
  String get helpStocktakeDiffDesc =>
      'After closing, you see a list of all items with expected/counted comparison and the posted difference. Positive = more counted than expected, negative = less. The report stays available in the stocktake list.';

  @override
  String get helpWwReportingSection => 'Reports & analysis';

  @override
  String get helpWwReportingWhatTitle => 'What reports are available?';

  @override
  String get helpWwReportingWhatDesc =>
      'In the Statistics tab → Warehouse/Suppliers you find three reports:\n• Stock valuation — warehouse value at a given date (quantity × cost price)\n• Inventory turnover — how often your stock turns over in a period\n• ABC analysis — which items represent the greatest share of value';

  @override
  String get helpWwReportingValuationTitle => 'Stock valuation';

  @override
  String get helpWwReportingValuationDesc =>
      'Shows the total value of your warehouse (quantity × cost price for all items with a price set). Items without a cost price are counted as 0 — fill in missing prices so the figure is accurate.';

  @override
  String get helpWwReportingTurnoverTitle => 'Inventory turnover';

  @override
  String get helpWwReportingTurnoverDesc =>
      'Inventory turnover shows how many times your average stock was sold and replaced in the selected period. A high value means fast-moving stock; a low value may indicate slow-movers.';

  @override
  String get helpWwReportingAbcTitle => 'ABC analysis';

  @override
  String get helpWwReportingAbcDesc =>
      'Items are classified by their share of total stock value:\n• A-items — roughly 70–80 % of total value, usually few products\n• B-items — roughly 15–25 % of total value\n• C-items — roughly 5–10 % of total value, many products\nThe classification helps you decide where tighter purchasing and more precise planning pay off.';

  @override
  String get helpFaqQ20 =>
      'How do I link an existing stock item to the product catalog?';

  @override
  String get helpFaqA20 =>
      'Open the item in the Inventory tab → Edit → \"Link product\" → search for and select the catalog product. Unlinked stock items continue to appear in a separate \"Without product\" group.';

  @override
  String get helpFaqQ21 => 'What happens to stock when I book a goods receipt?';

  @override
  String get helpFaqA21 =>
      'When you tap \"Book goods receipt\" in a purchase order, the app increases the linked product\'s stock by the received quantity and writes a \"Goods in\" entry to the movement history. The order status updates automatically.';

  @override
  String get helpFaqQ22 => 'Can I split an item across multiple warehouses?';

  @override
  String get helpFaqA22 =>
      'Yes. Create multiple stock entries for the same product and assign them to different warehouses. The product detail page aggregates the total stock across all warehouses and shows it broken down by location.';

  @override
  String get helpFaqQ23 =>
      'Why are some items missing from the stocktake list?';

  @override
  String get helpFaqA23 =>
      'The stocktake only includes items linked to a catalog product. Stock items without a product link (the \"Without product\" group) do not appear. Link the item first in the Inventory tab → Edit item → \"Link product\".';

  @override
  String get helpFaqQ24 => 'How do I turn off the low-stock push notification?';

  @override
  String get helpFaqA24 =>
      'Settings → Push → disable the \"Low stock\" category. Push notifications for low stock will stop; the yellow warning in the dashboard and inventory tab remains as a silent indicator.';

  @override
  String get helpFaqQ25 => 'Why does my Amazon shipment have no live status?';

  @override
  String get helpFaqA25 =>
      'The app detects Amazon Logistics shipments and saves the tracking number, but Amazon doesn\'t offer a public interface to query the shipping status. That\'s why the deal only shows \"Shipment detected — live status unavailable\" and the \"Refresh status\" icon is greyed out. Amazon often hands the parcel over to DHL — if the same mail also contains a DHL number, the app uses that as the trackable shipment and you get a normal live status there.';

  @override
  String get helpFaqQ26 => 'Why does my GLS shipment have no live status?';

  @override
  String get helpFaqA26 =>
      'The app detects GLS tracking numbers automatically from shop mails (e.g. PcComponentes) and saves them. There\'s no automatic live status for GLS, though, because GLS doesn\'t offer a freely usable tracking service. Instead you get a \"Track shipment\" button that opens the official GLS page with your number.';

  @override
  String get helpFaqQ27 =>
      'How often does the shipment status update on its own?';

  @override
  String get helpFaqA27 =>
      'Automatically, without any action from you: parcels out for delivery are checked every hour, parcels still in transit roughly every 4 hours. At night (about 10 PM–6 AM) the check pauses, because hardly anything happens in the carrier network then. Delivered shipments are no longer queried. If you want a fresh snapshot right now, tap \"Refresh status\" on the deal (allowed every 30 seconds).';

  @override
  String get helpFaqQ28 =>
      'Can I jump from the dashboard straight to the right area?';

  @override
  String get helpFaqA28 =>
      'Yes. Tap a tile on the dashboard and the app jumps to the matching area — e.g. from \"Open deliveries\" to Deals or from \"Critical stock\" to Inventory. In the deal list and in Inventory you can also pull down from the top on your phone (pull-to-refresh) to reload the data.';

  @override
  String get helpPrivacySection => 'Privacy & contact';

  @override
  String get helpPrivacyDataTitle => 'What data is stored?';

  @override
  String get helpPrivacyDataDesc =>
      'What is stored: master data (workspace, deals, buyers), mailbox config (password encrypted) and photo uploads. From parsed mails we store headers (sender, subject, date) and a normalised JSON extract (order ID, tracking number, totals, product); the full mail body is not retained. Mail metadata is auto-deleted after 100 days. Details in the privacy policy under Settings → General.';

  @override
  String get helpPrivacySupportTitle => 'How do I reach support?';

  @override
  String get helpPrivacySupportDesc =>
      '\"Report issues\" generates a mail with app version, OS and workspace ID (no passwords). Reply time usually < 48 h.';

  @override
  String get helpPrivacyNoteTitle => 'Important notes';

  @override
  String get helpPrivacyNoteDesc =>
      'The app does not replace bookkeeping or tax advice — statistics are estimates. Before your first quarterly close please consult a tax advisor.';

  @override
  String get ticketsEmpty => 'No tickets found';

  @override
  String get ticketsEmptyHint => 'Adjust filters or create a new ticket.';

  @override
  String get ticketsNoTicket => 'No ticket';

  @override
  String get inventoryEmpty => 'Inventory is empty.';

  @override
  String get inventoryEmptyHint => 'Use the + button to add your first item.';

  @override
  String get inventoryAddItem => 'Add item';

  @override
  String get inventoryColName => 'Name';

  @override
  String get inventoryColSku => 'SKU';

  @override
  String get inventoryColEan => 'EAN';

  @override
  String get inventoryColQuantity => 'Quantity';

  @override
  String get inventoryColMinStock => 'Min.';

  @override
  String get inventoryColLocation => 'Location';

  @override
  String get inventoryColCost => 'Cost';

  @override
  String get inventoryColArrival => 'Arrival';

  @override
  String get inventoryColSupplier => 'Supplier';

  @override
  String get suppliersEmpty => 'No suppliers yet.';

  @override
  String get suppliersAdd => 'Add supplier';

  @override
  String get suppliersDeleteTitle => 'Delete supplier';

  @override
  String suppliersDeleteConfirm(Object name) {
    return 'Delete supplier \"$name\"?';
  }

  @override
  String get activityTitle => 'Activity';

  @override
  String get activityEmpty => 'No activity yet.';

  @override
  String get dashboardOpenOrders => 'Open orders';

  @override
  String get dashboardOpenAmount => 'Open amount';

  @override
  String get dashboardArrivedToday => 'Arrived today';

  @override
  String get dashboardCriticalStock => 'Critical stock';

  @override
  String get dashboardMissingInvoice => 'Missing receipts';

  @override
  String get dashboardTotalProfit => 'Total profit';

  @override
  String get dashboardOpenDeliveries => 'Pending deliveries';

  @override
  String get dashboardStockQuantity => 'Stock quantity';

  @override
  String get dashboardStockValue => 'Stock value';

  @override
  String get dashboardKpiOpenOrders => 'Open orders';

  @override
  String get dashboardKpiShipping => 'Shipping';

  @override
  String get dashboardKpiArrivedToday => 'Arrived today';

  @override
  String get dashboardKpiTotalProfit => 'Total profit';

  @override
  String get dashboardKpiOpenAmount => 'Open amount';

  @override
  String get dashboardKpiCriticalStock => 'Critical stock';

  @override
  String get dashboardKpiMissingInvoice => 'Pending invoices';

  @override
  String get dashboardActivityFeed => 'Activity feed';

  @override
  String get dashboardActivityEmpty => 'No actions yet.';

  @override
  String get dashboardBuyerOverview => 'Buyer overview';

  @override
  String get dashboardBuyerEmpty => 'Add buyers in Settings.';

  @override
  String get dashboardColBuyer => 'BUYER';

  @override
  String get dashboardColDeals => 'DEALS';

  @override
  String get dashboardColOpen => 'OPEN';

  @override
  String get dashboardColLastDeal => 'LAST DEAL';

  @override
  String get ticketsTitle => 'Tickets';

  @override
  String get ticketsSearchHint => 'Search ticket number or product';

  @override
  String get ticketsNewDeal => 'New deal';

  @override
  String get ticketsSelect => 'Select a ticket';

  @override
  String get ticketsSearchHintShort => 'Search tickets';

  @override
  String get ticketsTabList => 'Tickets';

  @override
  String get ticketsTabDetail => 'Detail';

  @override
  String get ticketsSortLabel => 'Sort';

  @override
  String get ticketsSortDate => 'Date';

  @override
  String get ticketsSortProfit => 'Profit';

  @override
  String get ticketsSortDealCount => 'Deal count';

  @override
  String get ticketsOpenTooltip => 'Open ticket';

  @override
  String get ticketsBulkEditTooltip => 'Edit';

  @override
  String get ticketsAddDealTooltip => 'Add deal';

  @override
  String get ticketsEditTitle => 'Edit ticket';

  @override
  String get ticketsTicketNumber => 'Ticket number';

  @override
  String get ticketsRelatedItems => 'Related inventory items';

  @override
  String get ticketsNoBuyerAssigned => 'No buyer assigned';

  @override
  String get ticketsBoxEkTotal => 'Cost total';

  @override
  String get ticketsBoxVkTotal => 'Sale total';

  @override
  String get ticketsBoxProfit => 'Profit';

  @override
  String get ticketsBoxQuantity => 'Quantity';

  @override
  String get ticketsColProduct => 'Product';

  @override
  String get ticketsColQuantity => 'Qty';

  @override
  String get ticketsColTracking => 'Tracking';

  @override
  String ticketsCount(int count) {
    return '$count deal(s)';
  }

  @override
  String ticketsItemsCount(int count) {
    return '$count items';
  }

  @override
  String get ticketsKeinTicket => 'No ticket';

  @override
  String get ticketsNoBuyer => 'No buyer';

  @override
  String get ticketsTabActive => 'Active';

  @override
  String get ticketsTabArchive => 'Archive';

  @override
  String get ticketsArchiveEmpty => 'No archived tickets';

  @override
  String get ticketsArchiveEmptyHint =>
      'Completed tickets will be archived here.';

  @override
  String get ticketsArchiveReopen => 'Reopen ticket';

  @override
  String get ticketsArchiveReopenConfirm =>
      'Reopen this ticket? Archive timestamp and reason will be cleared.';

  @override
  String ticketsArchiveMonthProfit(Object profit) {
    return 'Profit: $profit';
  }

  @override
  String get ticketsArchiveLongPressHint => 'Long-press a ticket to reopen it';

  @override
  String ticketsReopenSuccess(String ticketNumber) {
    return 'Ticket $ticketNumber reopened';
  }

  @override
  String get ticketsReopenFailed => 'Couldn\'t reopen ticket';

  @override
  String ticketsEditSaved(String ticketNumber) {
    return 'Ticket $ticketNumber saved';
  }

  @override
  String get ticketsEditFailed => 'Couldn\'t save ticket';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventorySearchHint => 'Search name, SKU, EAN, location';

  @override
  String get inventoryAddBatch => 'Add batch';

  @override
  String get inventoryAdjustStock => 'Adjust stock';

  @override
  String get inventoryNoSku => 'No SKU';

  @override
  String get inventoryNoLocation => 'No location';

  @override
  String get inventoryDeleteTitle => 'Delete inventory item';

  @override
  String inventoryDeleteConfirm(Object name) {
    return 'Delete item \"$name\"?';
  }

  @override
  String inventoryBarcodeFound(Object name) {
    return 'Found: $name';
  }

  @override
  String get inventoryNoEan => 'No item with this EAN';

  @override
  String get inventoryCreate => 'Create';

  @override
  String get inventoryKpiTotalItems => 'Total items';

  @override
  String get inventoryKpiTotalStock => 'Total stock';

  @override
  String get inventoryKpiCriticalItems => 'Critical items';

  @override
  String get inventoryKpiStockValue => 'Stock value';

  @override
  String get inventoryStockIn => 'In';

  @override
  String get inventoryStockOut => 'Out';

  @override
  String get inventoryColLocationLong => 'Location';

  @override
  String get inventoryColMin => 'Min. stock';

  @override
  String get inventoryColActions => 'Actions';

  @override
  String get inventoryColStock => 'Stock';

  @override
  String get inventoryStockInTooltip => 'Stock in';

  @override
  String get inventoryStockOutTooltip => 'Stock out';

  @override
  String get inventoryStockInTitle => 'Stock in';

  @override
  String get inventoryStockOutTitle => 'Stock out';

  @override
  String get inventoryQuantity => 'Quantity';

  @override
  String get inventoryReason => 'Reason';

  @override
  String get inventoryReasonStockIn => 'Stock-in';

  @override
  String get inventoryReasonSale => 'Sale';

  @override
  String get inventoryHelpTextTicket => 'Pick from a ticket or type freely';

  @override
  String get inventoryAddItemTitle => 'Add item';

  @override
  String get inventoryEditItemTitle => 'Edit item';

  @override
  String get inventorySectionGeneral => 'General';

  @override
  String get inventorySectionId => 'Identification';

  @override
  String get inventorySectionAttachments => 'Attachments';

  @override
  String get inventoryNoSupplier => 'No supplier';

  @override
  String get inventoryScanBarcode => 'Scan barcode';

  @override
  String get inventoryClose => 'Close';

  @override
  String get inventoryTabStock => 'Stock';

  @override
  String get inventoryTabSold => 'Sold';

  @override
  String get inventorySoldEmpty => 'No sold items yet.';

  @override
  String get inventorySoldEmptyHint =>
      'Items you mark as sold will appear here.';

  @override
  String get inventorySoldKpiCount => 'Items sold';

  @override
  String get inventorySoldKpiProfit => 'Total profit';

  @override
  String get inventorySoldKpiTopBuyers => 'Top 3 buyers';

  @override
  String get inventorySoldNoBuyer => 'No buyer data yet';

  @override
  String inventorySoldBuyerItems(int count) {
    return '$count pcs';
  }

  @override
  String get supplierAddTitle => 'Add supplier';

  @override
  String get supplierEditTitle => 'Edit supplier';

  @override
  String get supplierContactName => 'Contact person';

  @override
  String get supplierPhone => 'Phone';

  @override
  String get supplierWebsite => 'Website';

  @override
  String get supplierActive => 'Active';

  @override
  String supplierItems(int count) {
    return '$count items';
  }

  @override
  String get suppliersNew => 'New supplier';

  @override
  String suppliersDeletePrompt(Object name) {
    return '\"$name\" will be moved to trash. You can restore it later.';
  }

  @override
  String get suppliersInactive => 'Inactive';

  @override
  String get suppliersEmptyHint =>
      'Use the + button to add your first supplier.';

  @override
  String get activityHeading => 'Activity log';

  @override
  String get activityFilterReset => 'Reset filters';

  @override
  String get activityToday => 'TODAY';

  @override
  String get activityYesterday => 'YESTERDAY';

  @override
  String get activityTypeDeal => 'Deal';

  @override
  String get activityTypeStatus => 'Status';

  @override
  String get activityTypeStock => 'Stock';

  @override
  String get activityTypeSupplier => 'Supplier';

  @override
  String get activityTypeBatch => 'Batch';

  @override
  String get activityTypeBulk => 'Bulk';

  @override
  String get activityTypeImport => 'Import';

  @override
  String get activityTypeInfo => 'Info';

  @override
  String get activityTypeComment => 'Comment';

  @override
  String get activitySearchHint => 'Search activities…';

  @override
  String activityCountTotal(int count) {
    return '$count entries (max 50)';
  }

  @override
  String activityCountFiltered(int filtered, int total) {
    return '$filtered of $total entries';
  }

  @override
  String get activityNoMatches => 'No matches.';

  @override
  String get activityNoActivitiesYet => 'No activities yet.';

  @override
  String get activityAdjustFilters => 'Adjust or clear filters.';

  @override
  String get activityAutoAppears =>
      'Actions like creating a deal show up here automatically.';

  @override
  String get statisticsTabRevenue => 'Revenue';

  @override
  String get statisticsTabBuyers => 'Buyers';

  @override
  String get statisticsTabShops => 'Shops';

  @override
  String get statisticsTabInventory => 'Inventory';

  @override
  String get statisticsTabCashflow => 'Cashflow';

  @override
  String get statisticsTabTax => 'Tax';

  @override
  String get csvExportToolbar => 'Export';

  @override
  String get csvImportToolbar => 'Import';

  @override
  String get buyerEditTitle => 'Edit buyer';

  @override
  String get buyerNewTitle => 'New buyer';

  @override
  String get buyerSortOrder => 'Sort order';

  @override
  String get buyerActive => 'Active';

  @override
  String get buyerColorBlue => 'Blue';

  @override
  String get buyerColorOrange => 'Orange';

  @override
  String get buyerColorGreen => 'Green';

  @override
  String get buyerColorPurple => 'Purple';

  @override
  String get buyerColorYellow => 'Yellow';

  @override
  String get buyerColorRed => 'Red';

  @override
  String get buyerColorTeal => 'Teal';

  @override
  String get buyerColorPink => 'Pink';

  @override
  String get buyerPreview => 'Preview';

  @override
  String get buyerSampleProduct => 'Sample product';

  @override
  String get buyerDiscordIds => 'Discord server IDs';

  @override
  String get buyerAddIdLabel => 'Add';

  @override
  String get buyerRemoveTooltip => 'Remove';

  @override
  String get shopEditTitle => 'Edit shop';

  @override
  String get shopNewTitle => 'New shop';

  @override
  String get shopRegion => 'Region';

  @override
  String get shopChannel => 'Channel';

  @override
  String get shopActive => 'Active';

  @override
  String get batchesNew => 'New batch';

  @override
  String get batchesAdd => 'Add batch';

  @override
  String get batchesNoMhd => 'No best-before';

  @override
  String get attachmentTitle => 'Photos';

  @override
  String get attachmentTakePhoto => 'Take photo';

  @override
  String get attachmentPickGallery => 'Pick from gallery';

  @override
  String get barcodeScannerTitle => 'Scan barcode';

  @override
  String get barcodeScannerNoCamera => 'Camera unavailable';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthMedium => 'Medium';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get passwordStrengthVeryStrong => 'Very strong';

  @override
  String get summaryHeading => 'Overview';

  @override
  String get summaryByBuyer => 'By buyer';

  @override
  String get summaryByStatus => 'By status';

  @override
  String get statsLabelRevenue => 'Revenue';

  @override
  String get statsLabelProfit => 'Profit';

  @override
  String get statsLabelMargin => 'Margin';

  @override
  String get statsAllDeals => 'All deals';

  @override
  String get statsProfitPerMonth => 'Profit per month';

  @override
  String get statsTabOverview => 'Overview';

  @override
  String get statsTabBuyers => 'Buyers';

  @override
  String get statsTabProductsShops => 'Products & Shops';

  @override
  String get statsTabInventorySuppliers => 'Inventory & Suppliers';

  @override
  String get statsTabFinance => 'Finance';

  @override
  String get statsExportPdfTitle => 'PDF overview';

  @override
  String get statsExportPdfDesc =>
      'One-page report with KPIs, products, buyers, cashflow';

  @override
  String get statsExportXlsxTitle => 'Excel (XLSX)';

  @override
  String get statsExportXlsxDesc => 'Raw data of filtered deals';

  @override
  String get statsExportCsvTitle => 'CSV';

  @override
  String get statsExportCsvDesc => 'Raw data of filtered deals';

  @override
  String get statsExportPrintTitle => 'Print / preview';

  @override
  String get statsReportExported => 'Report exported.';

  @override
  String statsExportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get statsTaxExportSaved => 'VAT export saved.';

  @override
  String get globalSearchKeyNav => 'Navigate';

  @override
  String get globalSearchKeyOpen => 'Open';

  @override
  String get globalSearchKeyClose => 'Close';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchRecentEmpty => 'No recent searches';

  @override
  String get searchRecentClear => 'Clear';

  @override
  String get buyerLegendTitle => 'Buyers';

  @override
  String get statsCompareToPrevious => 'vs. previous';

  @override
  String get statsExportReport => 'Report';

  @override
  String get statsCashflow => 'Cashflow';

  @override
  String get statsReceived => 'Received';

  @override
  String get statsOutstanding => 'Outstanding';

  @override
  String get statsAgingHeading => 'Aging of receivables';

  @override
  String get statsOldestOpen => 'Oldest open';

  @override
  String get statsQuarter => 'Quarter';

  @override
  String get statsCurrency => 'Currency';

  @override
  String get statsNet => 'Net';

  @override
  String get statsTax => 'VAT';

  @override
  String get statsGross => 'Gross';

  @override
  String get statsCurrentMonth => 'Current month';

  @override
  String get statsCurrent => 'Current';

  @override
  String get statsTarget => 'Target';

  @override
  String get statsForecast => 'Forecast';

  @override
  String get statsGoalNotMet => 'Not yet reached';

  @override
  String get statsGoalsInRow => 'Goals reached in a row';

  @override
  String get statsOpenReceivables => 'Open receivables';

  @override
  String get statsDealCount => 'Deal count';

  @override
  String get statsProfitPerBucket => 'Profit per bucket';

  @override
  String get statsProfitByBuyer => 'Profit by buyer';

  @override
  String get statsRevenueByShop => 'Revenue by shop';

  @override
  String get statsTotal => 'TOTAL';

  @override
  String get statsBuyerLabel => 'Buyer';

  @override
  String get statsDealsLabel => 'Deals';

  @override
  String get statsOpenLabel => 'Open';

  @override
  String get statsFrequency => 'Frequency';

  @override
  String get statsFirst => 'First';

  @override
  String get statsLast => 'Last';

  @override
  String get statsActiveDays => 'Active days';

  @override
  String get statsHealthHeading => 'Stock health';

  @override
  String get statsStockValueEk => 'Stock value (cost)';

  @override
  String get statsLowStock => 'Low stock';

  @override
  String get statsLowStockHint => 'Items below threshold';

  @override
  String get statsExpiringSoon => 'Expiring soon';

  @override
  String get statsExpiringSoonHint => 'Batches with best-before < 30 days';

  @override
  String get statsExpired => 'Expired';

  @override
  String get statsDeadStock => 'Dead stock';

  @override
  String get statsDeadStockHint => 'No sale for more than 90 days';

  @override
  String get statsSupplierPerformance => 'Supplier performance';

  @override
  String get statsItems => 'Items';

  @override
  String get statsStockValueShort => 'Stock value';

  @override
  String get statsAvgEk => 'Avg. cost';

  @override
  String get inboxMarkAllRead => 'Mark all as read';

  @override
  String inboxMarkAllReadTooltip(int count) {
    return 'Mark all as read ($count)';
  }

  @override
  String get inboxMarkAllReadConfirmTitle => 'Mark all as read?';

  @override
  String inboxMarkAllReadConfirmBody(int count) {
    return '$count unread items will be marked as read. Suggestions and messages stay in the inbox.';
  }

  @override
  String inboxMarkAllReadSuccess(int count) {
    return '$count items marked as read.';
  }

  @override
  String inboxMarkAllReadFailure(Object error) {
    return 'Mark as read failed: $error';
  }

  @override
  String inboxUnreadBadge(int count) {
    return '$count new';
  }

  @override
  String get invitesBellTooltip => 'Invites';

  @override
  String get invitesEmpty => 'No pending invites.';

  @override
  String get invitesHeader => 'Workspace invites';

  @override
  String get invitesFrom => 'Invited to workspace';

  @override
  String get invitesAccept => 'Join';

  @override
  String get invitesDecline => 'Decline';

  @override
  String get invitesAcceptedSnack => 'Joined workspace.';

  @override
  String get invitesDeclinedSnack => 'Invite declined.';

  @override
  String invitesAcceptFailed(Object error) {
    return 'Join failed: $error';
  }

  @override
  String invitesDeclineFailed(Object error) {
    return 'Decline failed: $error';
  }

  @override
  String invitesExpiresOn(Object date) {
    return 'Expires $date';
  }

  @override
  String invitesRoleLabel(Object role) {
    return 'Role: $role';
  }

  @override
  String get settingsPaletteSection => 'Color Palette';

  @override
  String get settingsPaletteBlue => 'Blue';

  @override
  String get settingsPaletteIndigo => 'Indigo';

  @override
  String get settingsPaletteViolet => 'Violet';

  @override
  String get settingsPaletteTeal => 'Teal';

  @override
  String get settingsPaletteRose => 'Rose';

  @override
  String get settingsThemeSection => 'Appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get publicProfileTab => 'Public profile';

  @override
  String get publicProfileSectionTitle => 'Sales page';

  @override
  String get publicProfileSectionDesc =>
      'Publish a read-only page with your in-stock items. Inquiries arrive by email.';

  @override
  String get publicProfileEnableLabel => 'Public profile enabled';

  @override
  String get publicProfileHandleLabel => 'Handle';

  @override
  String get publicProfileHandleHint => 'e.g. my-shop';

  @override
  String get publicProfileHandleHelp =>
      'Lowercase letters, digits and dashes, 3–32 chars. Reachable at /u/<handle>.';

  @override
  String get publicProfileHandleInvalid =>
      'Use a-z, 0-9 and dash. 3–32 chars, must not start or end with \"-\".';

  @override
  String get publicProfileHandleTaken => 'Handle already taken.';

  @override
  String get publicProfileSaved => 'Profile updated.';

  @override
  String publicProfileSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get publicProfileNeedsHandle =>
      'Set a handle first to enable the profile.';

  @override
  String get publicProfileLink => 'Public link';

  @override
  String get publicProfileCopyLink => 'Copy link';

  @override
  String get publicProfileLinkCopied => 'Link copied.';

  @override
  String get publicProfileItemsTitle => 'Visible items';

  @override
  String get publicProfileItemsHint =>
      'Tap an item to show or hide it on the public page.';

  @override
  String get publicProfileItemPublic => 'Public';

  @override
  String get publicProfileNoEligibleItems => 'No items in stock yet.';

  @override
  String get publicProfileNotFoundTitle => 'Profile not found';

  @override
  String get publicProfileNotFoundBody =>
      'This sales page does not exist or is not public.';

  @override
  String get publicProfileEmptyItems => 'No items available right now.';

  @override
  String get publicProfileContact => 'Send inquiry';

  @override
  String get publicProfileContactSubject => 'Inquiry about your listing';

  @override
  String get publicProfileItemPrice => 'Price';

  @override
  String publicProfileItemQuantity(int count) {
    return 'Available: $count';
  }

  @override
  String get publicProfileFooter => 'Built with InventoryOS';

  @override
  String get settingsDemoSection => 'Demo / data';

  @override
  String get settingsDemoReloadTitle => 'Reload demo data';

  @override
  String get settingsDemoReloadDescription =>
      'Resets this workspace and fills it with 30–50 realistic sample deals from your mail of the last 90 days. All current data will be lost.';

  @override
  String get settingsDemoReload => 'Reload demo';

  @override
  String get settingsDemoReloadConfirmTitle => 'Reload demo data?';

  @override
  String get settingsDemoReloadConfirm =>
      'This workspace will be wiped and re-populated with fresh demo data. All current deals, buyers, shops and inventory items will be lost. Continue?';

  @override
  String get settingsDemoReloadSuccess => 'Demo data reloaded.';

  @override
  String settingsDemoReloadError(Object error) {
    return 'Demo reload failed: $error';
  }

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingFinish => 'Done';

  @override
  String get onboardingStepWelcomeTitle => 'Welcome';

  @override
  String get onboardingStepWelcomeSubtitle =>
      'InventoryOS helps you keep track of orders, inventory, and buyers. Six quick steps and you\'re set up.';

  @override
  String get onboardingStepWorkspaceTitle => 'Your workspace';

  @override
  String get onboardingStepWorkspaceSubtitle =>
      'All data lives inside a workspace. You can invite team members or create more workspaces later.';

  @override
  String get onboardingWorkspaceFallback => 'My workspace';

  @override
  String get onboardingWorkspaceReady => 'Ready. This workspace is yours.';

  @override
  String get onboardingStepShopsTitle => 'Which shops do you use?';

  @override
  String get onboardingStepShopsSubtitle =>
      'Pick the shops you order from regularly. You can always add more later.';

  @override
  String get onboardingStepSuppliersTitle => 'Who are your suppliers?';

  @override
  String get onboardingStepSuppliersSubtitle =>
      'Optional. Add your most important suppliers so inventory items can reference them right away.';

  @override
  String get onboardingSuppliersHint => 'Supplier name';

  @override
  String get onboardingSuppliersAdd => 'Add';

  @override
  String get onboardingStepFirstTicketTitle => 'Create your first ticket';

  @override
  String get onboardingStepFirstTicketSubtitle =>
      'Optional. Add a first deal so your dashboard isn\'t empty. You can skip this step.';

  @override
  String get onboardingFirstTicketProductHint => 'Product (e.g. AirPods Pro 2)';

  @override
  String get onboardingFirstTicketQuantity => 'Quantity';

  @override
  String get onboardingFirstTicketShop => 'Shop';

  @override
  String get onboardingStepOutroTitle => 'Almost there!';

  @override
  String get onboardingStepOutroSubtitle =>
      'Find these features in Settings — no rush, you don\'t have to set them up right away:';

  @override
  String get onboardingOutroDiscord =>
      'Connect your Discord server to auto-assign buyer bounties.';

  @override
  String get onboardingOutroInbox =>
      'Connect your inbox — order confirmations will be detected automatically.';

  @override
  String get onboardingOutroDemo =>
      'Just want to look around? Use \'Load sample data\' on the dashboard.';

  @override
  String get onboardingErrorNoWorkspace =>
      'No active workspace found. Please sign out and back in.';

  @override
  String onboardingErrorGeneric(Object error) {
    return 'Onboarding failed: $error';
  }

  @override
  String onboardingStepLabel(Object current, Object total) {
    return 'Step $current of $total';
  }

  @override
  String get dashboardEmptyTitle => 'No data yet';

  @override
  String get dashboardEmptySubtitle =>
      'Load some sample tickets, buyers, and inventory items to find your way around.';

  @override
  String get dashboardEmptyLoadDemo => 'Load sample data';

  @override
  String dashboardDemoLoadSuccess(int count) {
    return '$count sample entries loaded.';
  }

  @override
  String dashboardDemoLoadError(Object error) {
    return 'Sample data could not be loaded: $error';
  }

  @override
  String get settingsDemoWipeSection => 'Sample data';

  @override
  String get settingsDemoWipeTitle => 'Delete demo data';

  @override
  String get settingsDemoWipeDescription =>
      'Removes only the entries created by the \'Load sample data\' button. Your own data stays untouched.';

  @override
  String get settingsDemoWipe => 'Delete demo data';

  @override
  String get settingsDemoWipeConfirmTitle => 'Delete demo data?';

  @override
  String get settingsDemoWipeConfirm =>
      'All entries marked as demo data will be removed. Continue?';

  @override
  String settingsDemoWipeSuccess(int count) {
    return '$count demo entries deleted.';
  }

  @override
  String settingsDemoWipeError(Object error) {
    return 'Deletion failed: $error';
  }

  @override
  String get trackingAmazonShipmentIdHint =>
      'Amazon-internal shipment ID — not a real carrier tracking number';

  @override
  String get trackingBannerImprovedDetection =>
      'We improved tracking detection. Please review the items in \"Review\".';

  @override
  String get trackingCarrierAmazonLogisticsHintShort => 'Amazon Logistics';

  @override
  String get trackingCarrierUnknown => 'Unknown carrier';

  @override
  String get trackingConfidenceLabelManual => 'Manual';

  @override
  String get trackingConfidenceLabelNone => 'Unclear';

  @override
  String get trackingConfidenceLabelStrong => 'Verified';

  @override
  String get trackingEnterManuallyCta => 'Enter manually';

  @override
  String get trackingNoneDetectedSubtitle =>
      'We could not find a verified tracking number in this message.';

  @override
  String get trackingNoneDetectedTitle => 'No tracking number detected';

  @override
  String get trackingReparseCta => 'Re-evaluate tracking numbers';

  @override
  String get trackingReparseConfirmBody =>
      'Existing tracking numbers will be re-checked with the improved detector. Manual entries stay untouched.';

  @override
  String get trackingReparseConfirmTitle => 'Start re-evaluation?';

  @override
  String get trackingReparseFailed => 'Re-evaluation failed';

  @override
  String trackingReparseRateLimit(int seconds) {
    return 'Too many requests — please try again in $seconds s';
  }

  @override
  String get trackingReparseOffline => 'No connection — please try again later';

  @override
  String get trackingReparseRunning => 'Re-evaluating tracking numbers…';

  @override
  String trackingReparseSuccessCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tracking numbers updated',
      one: '1 tracking number updated',
      zero: 'No tracking number updated',
    );
    return '$_temp0';
  }

  @override
  String get inboxResetCta => 'Reset mailbox';

  @override
  String get inboxResetSubtitle =>
      'Delete all mails and re-import them. Each mail is checked against the DHL API during re-import. Not reversible.';

  @override
  String get inboxResetConfirmTitle => 'Really reset the mailbox?';

  @override
  String get inboxResetConfirmBody =>
      'All previously imported mails will be deleted, the IMAP cursor will be reset and the next poll will reload everything. Your deals stay untouched.\n\nType RESET to confirm.';

  @override
  String get inboxResetConfirmInputLabel => 'Type RESET to confirm';

  @override
  String get inboxResetRunning => 'Resetting mailbox…';

  @override
  String get inboxResetFailed => 'Reset failed — please try again later.';

  @override
  String inboxResetSuccess(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString mails deleted. Next poll will reload everything.',
      one: '1 mail deleted. Next poll will reload everything.',
      zero: 'No mails deleted — IMAP cursor has been reset.',
    );
    return '$_temp0';
  }

  @override
  String trackingNeedsReviewFilterChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Review ($count)',
      one: 'Review (1)',
    );
    return '$_temp0';
  }

  @override
  String get trackingReviewAcceptCta => 'Accept';

  @override
  String get trackingReviewDismissCta => 'Dismiss';

  @override
  String get trackingReviewListTitle => 'Review tracking numbers';

  @override
  String get trackingReviewNeededBadge => 'Review';

  @override
  String get trackingStatusBlockA11yLabel => 'Tracking status';

  @override
  String get trackingRetrackCta => 'Refresh status';

  @override
  String get trackingRetrackRunning => 'Refreshing status…';

  @override
  String get trackingRetrackSuccess => 'Status updated';

  @override
  String get trackingRetrackRateLimited => 'Please wait 30s';

  @override
  String get trackingRetrackFailed => 'Status refresh failed';

  @override
  String get trackingRetrackOffline => 'No connection';

  @override
  String get trackingAmazonNoLiveStatusBadge =>
      'Shipment detected — live status not available';

  @override
  String get trackingRetrackUnavailableAmazon =>
      'Live status not available for Amazon Logistics';

  @override
  String get trackingManualVatRejected =>
      'This looks like a VAT registration number (2 letters + 9 digits) and will not be saved as a tracking number.';

  @override
  String get trackingTimelineTitle => 'Shipment history';

  @override
  String trackingTimelineShowAll(Object count) {
    return 'Show all $count events';
  }

  @override
  String get trackingTimelineShowLess => 'Show less';

  @override
  String trackingEtaLabel(Object date) {
    return 'Estimated delivery: $date';
  }

  @override
  String get trackingCopyTooltip => 'Copy tracking number';

  @override
  String get trackingCopiedSnack => 'Tracking number copied';

  @override
  String get trackingOpenCarrierPage => 'Track shipment';

  @override
  String get inboxSectionOrder => 'Order';

  @override
  String get inboxSectionShipping => 'Shipping';

  @override
  String get inboxSectionLinkedTo => 'Linked to';

  @override
  String get inboxFieldOrderId => 'Order ID';

  @override
  String get inboxFieldProduct => 'Product';

  @override
  String get inboxFieldAmount => 'Amount';

  @override
  String get inboxFieldEta => 'ETA';

  @override
  String get inboxFieldDeal => 'Deal';

  @override
  String get dealTrackingStatusTitle => 'Tracking number';

  @override
  String get dealSectionTrackingStatus => 'Shipping status';

  @override
  String trackingUpdateError(Object error) {
    return 'Tracking update failed: $error';
  }

  @override
  String trackingAcceptError(Object error) {
    return 'Tracking acceptance failed: $error';
  }

  @override
  String trackingDiscardError(Object error) {
    return 'Tracking discard failed: $error';
  }

  @override
  String get liveStatusPending => 'Pending';

  @override
  String get liveStatusInTransit => 'In transit';

  @override
  String get liveStatusOutForDelivery => 'Out for delivery';

  @override
  String get liveStatusDelivered => 'Delivered';

  @override
  String get liveStatusException => 'Issue — please check';

  @override
  String get liveStatusExpired => 'Status outdated';

  @override
  String get inboxFilterResetLabel => 'Reset filter';

  @override
  String get inboxFilterResetTitle => 'Reset filter?';

  @override
  String get inboxCopyMessageIdSnackbar => 'Message ID copied to clipboard.';

  @override
  String get inboxNoMailLinkSnackbar => 'No mail link available.';

  @override
  String get inboxNoTrackingSnackbar => 'This mail contains no tracking.';

  @override
  String get inboxOpenMailInBrowserMenuItem => 'Open mail in browser';

  @override
  String get inboxOpenMailLabel => 'Open mail';

  @override
  String get inboxOpenTicketLabel => 'Open ticket';

  @override
  String get inboxSuggestionsEmpty => 'No open suggestions';

  @override
  String get inboxSuggestionsEmptyHint =>
      'New mails are analysed automatically and will appear here.';

  @override
  String get inboxUpdatedEmpty => 'No automatically updated deals';

  @override
  String get inboxUpdatedEmptyHint =>
      'Deals whose shipping status was automatically updated appear here.';

  @override
  String get inboxUnclassifiedEmpty => 'No unclassified mails';

  @override
  String get inboxUnclassifiedEmptyHint =>
      'Mails without a matching deal or carrier are collected here.';

  @override
  String get inventoryDiscordTooltip => 'Open Discord ticket';

  @override
  String get inventoryProductHelperText => 'Select from ticket or type freely';

  @override
  String get settingsAddAmazonShops => 'Add Amazon shops';

  @override
  String get suppliersAddCarriers => 'Add shipping carriers';

  @override
  String get urlHelperLinkOpenError => 'Could not open link.';

  @override
  String inboxAcceptedSnack(Object tracking, int dealId) {
    return 'Tracking $tracking → Deal #$dealId accepted';
  }

  @override
  String inboxAcceptedSnackNoTracking(int dealId) {
    return 'Deal #$dealId created';
  }

  @override
  String get inboxAcceptedShowDeal => 'Show';

  @override
  String get inboxSuggestionDismiss => 'Dismiss';

  @override
  String get inboxSuggestionEdit => 'Edit before accepting';

  @override
  String get inboxSuggestionAccept => 'Accept';

  @override
  String get productCatalogTitle => 'Product catalog';

  @override
  String get productNew => 'New product';

  @override
  String get productUnit => 'Unit';

  @override
  String get productDefaultCostPrice => 'Default cost price';

  @override
  String get productDefaultSalePrice => 'Default sale price';

  @override
  String get productCategory => 'Category';

  @override
  String get productDefaultSupplier => 'Default supplier';

  @override
  String get productMinStock => 'Minimum stock';

  @override
  String get productTaxRate => 'VAT rate (%)';

  @override
  String get productIsActive => 'Active';

  @override
  String get productAdvancedSection => 'Advanced';

  @override
  String get productNameLabel => 'Product name';

  @override
  String get productSkuLabel => 'Article number (SKU)';

  @override
  String get productEanLabel => 'EAN / GTIN';

  @override
  String get productNoteLabel => 'Note';

  @override
  String get productEditTitle => 'Edit product';

  @override
  String get productAddTitle => 'New product';

  @override
  String get productGroupWithoutProduct => 'Without product';

  @override
  String get productCatalogEmpty => 'Empty product catalog';

  @override
  String get productCatalogEmptyHint => 'Create your first product.';

  @override
  String get productCatalogLoadError => 'Could not load product catalog.';

  @override
  String get productCatalogNoPermission =>
      'You do not have permission to edit the product catalog.';

  @override
  String get productCatalogViewerHint =>
      'You are viewing the product catalog in read-only mode.';

  @override
  String get productLinkLabel => 'Linked product';

  @override
  String get productNoLink => 'No linked product';

  @override
  String get productDetailTitle => 'Product details';

  @override
  String get productDetailEmpty => 'No data';

  @override
  String get productDetailEmptyHint => 'No movements for this item yet.';

  @override
  String get productDetailLoadError => 'Could not load product details.';

  @override
  String get movementTypeGoodsIn => 'Goods in';

  @override
  String get movementTypeGoodsOut => 'Goods out';

  @override
  String get movementTypeCorrection => 'Correction';

  @override
  String get movementTypeStocktake => 'Stocktake';

  @override
  String get movementTypeTransfer => 'Transfer';

  @override
  String get movementTypeSale => 'Sale';

  @override
  String get movementHistoryTitle => 'Movement history';

  @override
  String get productDetailSectionStammdaten => 'Master data';

  @override
  String get productDetailSectionStock => 'Stock';

  @override
  String get productDetailSectionSupplier => 'Supplier';

  @override
  String get productDetailSectionBatches => 'Batches';

  @override
  String get productDetailLabelSku => 'Article number (SKU)';

  @override
  String get productDetailLabelEan => 'EAN';

  @override
  String get productDetailLabelLocation => 'Location';

  @override
  String get productDetailLabelStatus => 'Status';

  @override
  String get productDetailLabelSupplier => 'Supplier';

  @override
  String get productDetailLabelQuantity => 'Stock';

  @override
  String get productDetailLabelMinStock => 'Minimum stock';

  @override
  String get productDetailLabelCostPrice => 'Cost price';

  @override
  String get productDetailLabelArrivalDate => 'Arrival date';

  @override
  String get productDetailLabelNote => 'Note';

  @override
  String get productDetailLabelCritical => 'Critical';

  @override
  String get productDetailLabelOk => 'OK';

  @override
  String get productDetailViewBatches => 'View batches';

  @override
  String get productDetailNoSupplier => 'No supplier';

  @override
  String get productDetailNoLocation => 'No location';

  @override
  String get productDetailViewerHint =>
      'You have read-only access — booking actions unavailable.';

  @override
  String get productDetailRetry => 'Reload';

  @override
  String productDetailMovementQuantity(Object sign, int qty) {
    return '$sign$qty';
  }

  @override
  String get productDetailSectionProduct => 'Product (master data)';

  @override
  String get productDetailLabelProductUnit => 'Unit';

  @override
  String get productDetailLabelDefaultCostPrice => 'Default cost price';

  @override
  String get productDetailLabelDefaultSalePrice => 'Default sale price';

  @override
  String get productDetailLabelMinStockProduct => 'Min. stock (product)';

  @override
  String get productDetailLabelTaxRate => 'Tax rate';

  @override
  String get productDetailSectionAggregatedStock => 'Total stock';

  @override
  String get productDetailLabelTotalQty => 'Total (all warehouses)';

  @override
  String productDetailLabelWarehouseQty(Object warehouse) {
    return 'Warehouse $warehouse';
  }

  @override
  String get productDetailLabelNoWarehouse => 'No warehouse assigned';

  @override
  String get productDetailMovementsAllProduct =>
      'All movements for this product (all stock rows).';

  @override
  String productDetailLoadMoreMovements(int count) {
    return 'Load $count more';
  }

  @override
  String get productDetailAllMovementsShown => 'All movements shown';

  @override
  String stockGroupItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String stockGroupTotalQuantity(int qty) {
    return 'Total: $qty units';
  }

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesEmpty => 'No categories';

  @override
  String get categoriesEmptyHint => 'Create your first category.';

  @override
  String get categoriesLoadError => 'Could not load categories.';

  @override
  String get categoryNew => 'New category';

  @override
  String get categoryEdit => 'Edit category';

  @override
  String get categoryDelete => 'Delete category';

  @override
  String categoryDeletePrompt(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get categoryParent => 'Parent category';

  @override
  String get categoryParentNone => 'None (top-level)';

  @override
  String get categoryFieldName => 'Name';

  @override
  String get categoryFieldSortOrder => 'Sort order';

  @override
  String get categoryMaxDepthError =>
      'Only 2 levels allowed. Please select a top-level category.';

  @override
  String get categorySortOrderHint => 'Number, lower = first';

  @override
  String get supplierAddress => 'Address';

  @override
  String get supplierAddressStreet => 'Street';

  @override
  String get supplierAddressZip => 'ZIP / Postal code';

  @override
  String get supplierAddressCity => 'City';

  @override
  String get supplierAddressCountry => 'Country';

  @override
  String get supplierVatId => 'VAT ID';

  @override
  String get supplierCustomerNumber => 'Customer number';

  @override
  String get supplierPaymentTerms => 'Payment terms (days)';

  @override
  String get supplierLeadTime => 'Lead time (days)';

  @override
  String get supplierMinOrderValue => 'Minimum order value';

  @override
  String get supplierAdvancedSection => 'Advanced details';

  @override
  String get commonDaysUnit => 'days';

  @override
  String get purchaseOrdersTitle => 'Orders';

  @override
  String get purchaseOrdersEmpty => 'No orders';

  @override
  String get purchaseOrdersEmptyHint => 'Create your first order.';

  @override
  String get purchaseOrdersLoadError => 'Could not load orders.';

  @override
  String get purchaseOrderNew => 'New order';

  @override
  String get purchaseOrderEdit => 'Edit order';

  @override
  String get purchaseOrderDelete => 'Delete order';

  @override
  String purchaseOrderDeletePrompt(Object number) {
    return 'Delete order \"$number\"?';
  }

  @override
  String get purchaseOrderStatusDraft => 'Draft';

  @override
  String get purchaseOrderStatusOrdered => 'Ordered';

  @override
  String get purchaseOrderStatusPartial => 'Partially received';

  @override
  String get purchaseOrderStatusReceived => 'Received';

  @override
  String get purchaseOrderStatusCancelled => 'Cancelled';

  @override
  String get purchaseOrderFieldSupplier => 'Supplier';

  @override
  String get purchaseOrderFieldSupplierHint => 'Select supplier';

  @override
  String get purchaseOrderFieldOrderDate => 'Order date';

  @override
  String get purchaseOrderFieldExpectedDate => 'Expected delivery date';

  @override
  String get purchaseOrderFieldNote => 'Note';

  @override
  String get purchaseOrderFieldNoteHint => 'Optional notes about the order';

  @override
  String get purchaseOrderSectionItems => 'Items';

  @override
  String get purchaseOrderItemsEmpty => 'No items';

  @override
  String get purchaseOrderItemAdd => 'Add item';

  @override
  String get purchaseOrderItemFieldProduct => 'Product';

  @override
  String get purchaseOrderItemFieldProductHint => 'Select product';

  @override
  String get purchaseOrderItemFieldQtyOrdered => 'Quantity';

  @override
  String get purchaseOrderItemFieldUnitPrice => 'Unit price (€)';

  @override
  String get purchaseOrderItemDelete => 'Delete item';

  @override
  String get purchaseOrderItemDeletePrompt => 'Delete this item?';

  @override
  String get purchaseOrderNoSupplierError => 'Please select a supplier.';

  @override
  String get purchaseOrderNoItemsError => 'At least one item is required.';

  @override
  String get purchaseOrderStatusToOrdered => 'Mark as ordered';

  @override
  String get purchaseOrderStatusToCancelled => 'Cancel order';

  @override
  String get purchaseOrderStatusChangeConfirm => 'Change status?';

  @override
  String get purchaseOrderStatusChangeBody =>
      'The order status will be changed. This action cannot be undone.';

  @override
  String get purchaseOrderDetailTitle => 'Order details';

  @override
  String get purchaseOrderDetailSectionHead => 'Order header';

  @override
  String get purchaseOrderLabelNumber => 'Order number';

  @override
  String get purchaseOrderLabelSupplier => 'Supplier';

  @override
  String get purchaseOrderLabelStatus => 'Status';

  @override
  String get purchaseOrderLabelOrderDate => 'Order date';

  @override
  String get purchaseOrderLabelExpectedDate => 'Expected';

  @override
  String get purchaseOrderLabelNote => 'Note';

  @override
  String get purchaseOrderLabelTotalNet => 'Net total';

  @override
  String get purchaseOrderDetailSectionItems => 'Items';

  @override
  String get purchaseOrderItemsLoadError => 'Could not load items.';

  @override
  String get goodsReceiptBook => 'Book goods receipt';

  @override
  String get goodsReceiptSuccess => 'Goods receipt booked.';

  @override
  String get goodsReceiptError => 'Error booking goods receipt.';

  @override
  String get goodsReceiptNoProduct =>
      'This item has no linked product and cannot be booked.';

  @override
  String get quantityOrdered => 'Ordered';

  @override
  String get quantityReceived => 'Received';

  @override
  String get purchaseOrderScanBarcode => 'Scan barcode';

  @override
  String get purchaseOrderScanNoMatch => 'No product found for this barcode.';

  @override
  String get purchaseOrderPdfExport => 'PDF receipt';

  @override
  String get purchaseOrderPdfExportComingSoon =>
      'PDF export is coming in a future update.';

  @override
  String get purchaseOrderPdfExportError => 'Could not create PDF receipt.';

  @override
  String get purchaseOrderCreatedSuccess => 'Order created.';

  @override
  String get purchaseOrderCreateError => 'Could not create order.';

  @override
  String get purchaseOrderStatusChangeError => 'Could not change status.';

  @override
  String get purchaseOrderViewerHint =>
      'You have read-only access — booking actions unavailable.';

  @override
  String get purchaseOrderStatusAutoManaged =>
      'This status is managed automatically.';

  @override
  String get poPdfDocumentTitle => 'Purchase Order';

  @override
  String get poPdfSupplierLabel => 'Supplier';

  @override
  String get poPdfVatIdLabel => 'VAT ID';

  @override
  String get poPdfOrderDateLabel => 'Order date';

  @override
  String get poPdfExpectedDateLabel => 'Expected delivery date';

  @override
  String get poPdfStatusLabel => 'Status';

  @override
  String get poPdfSectionItems => 'Line items';

  @override
  String get poPdfColProduct => 'Product';

  @override
  String get poPdfColOrdered => 'Ordered';

  @override
  String get poPdfColReceived => 'Received';

  @override
  String get poPdfColUnitPrice => 'Unit price';

  @override
  String get poPdfColLineTotal => 'Line total';

  @override
  String get poPdfTotalNetLabel => 'Net total';

  @override
  String get poPdfNoteLabel => 'Note';

  @override
  String get warehousesTitle => 'Warehouses';

  @override
  String get warehousesEmpty => 'No warehouses';

  @override
  String get warehousesEmptyHint => 'Create your first warehouse.';

  @override
  String get warehousesLoadError => 'Could not load warehouses.';

  @override
  String get warehouseNew => 'New warehouse';

  @override
  String get warehouseDefault => 'Main warehouse';

  @override
  String get warehouseEdit => 'Edit warehouse';

  @override
  String get warehouseNameLabel => 'Name';

  @override
  String get warehouseAddressLabel => 'Address';

  @override
  String get warehouseIsDefaultLabel => 'Default warehouse';

  @override
  String get warehouseIsActiveLabel => 'Active';

  @override
  String get warehouseInactiveBadge => 'Inactive';

  @override
  String warehouseDeletePrompt(Object name) {
    return 'Delete warehouse \"$name\"?';
  }

  @override
  String get inventoryWarehouseLabel => 'Warehouse';

  @override
  String get inventoryNoWarehouse => 'No warehouse';

  @override
  String get lowStockAlertTitle => 'Low stock';

  @override
  String lowStockAlertBody(Object count) {
    return '$count items below minimum stock';
  }

  @override
  String get lowStockReorderAction => 'Reorder now';

  @override
  String get reportStockValuation => 'Stock valuation';

  @override
  String get reportStockValuationSubtitle =>
      'Total inventory value at cost price';

  @override
  String get reportStockValuationTotal => 'Total value';

  @override
  String get reportStockValuationUnits => 'Total units';

  @override
  String get reportStockValuationItemName => 'Item';

  @override
  String get reportStockValuationQuantity => 'Qty';

  @override
  String get reportStockValuationCostPrice => 'Cost';

  @override
  String get reportStockValuationValue => 'Value';

  @override
  String get reportStockValuationEmpty =>
      'No inventory available for valuation.';

  @override
  String get reportInventoryTurnover => 'Inventory turnover';

  @override
  String get reportInventoryTurnoverSubtitle =>
      'How often stock is sold and replaced';

  @override
  String get reportInventoryTurnoverRate => 'Turnover rate';

  @override
  String get reportInventoryTurnoverOutflow => 'Outflow (units)';

  @override
  String get reportInventoryTurnoverAvgStock => 'Avg. stock (units)';

  @override
  String get reportInventoryTurnoverMovements => 'Outflow entries';

  @override
  String get reportInventoryTurnoverNoData => 'No outflow movements available.';

  @override
  String get reportInventoryTurnoverHint => 'Ratio of outflow to average stock';

  @override
  String get reportAbcAnalysis => 'ABC analysis';

  @override
  String get reportAbcAnalysisSubtitle => 'Items classified by stock value';

  @override
  String get reportAbcClassA => 'A — High value (≤ 80 %)';

  @override
  String get reportAbcClassB => 'B — Medium value (80–95 %)';

  @override
  String get reportAbcClassC => 'C — Low value (> 95 %)';

  @override
  String get reportAbcItemName => 'Item';

  @override
  String get reportAbcItemValue => 'Value';

  @override
  String get reportAbcItemShare => 'Cum. share';

  @override
  String get reportAbcItemClass => 'Class';

  @override
  String get reportAbcEmpty => 'No inventory available for ABC analysis.';

  @override
  String reportAbcCountItems(int count) {
    return '$count items';
  }

  @override
  String get stocktakeTitle => 'Stocktake';

  @override
  String get stocktakeEmpty => 'No stocktakes';

  @override
  String get stocktakeEmptyHint => 'Start your first stocktake.';

  @override
  String get stocktakeLoadError => 'Could not load stocktakes.';

  @override
  String get stocktakeNew => 'New stocktake';

  @override
  String stocktakeProgress(int counted, int total) {
    return '$counted/$total counted';
  }

  @override
  String get stocktakeFilterUncounted => 'Uncounted only';

  @override
  String get stocktakeExpected => 'Expected';

  @override
  String get stocktakeCounted => 'Counted';

  @override
  String get stocktakeDifference => 'Difference';

  @override
  String get stocktakeStatusOpen => 'Open';

  @override
  String get stocktakeStatusCounting => 'Counting';

  @override
  String get stocktakeStatusClosed => 'Closed';

  @override
  String get stocktakeStatusCancelled => 'Cancelled';

  @override
  String get stocktakeTitleLabel => 'Title (optional)';

  @override
  String get stocktakeTitleHint => 'e.g. Year-end 2026';

  @override
  String get stocktakeSelectWarehouse => 'Warehouse (optional)';

  @override
  String get stocktakeAllWarehouses => 'All warehouses';

  @override
  String get stocktakeStartAction => 'Start stocktake';

  @override
  String get stocktakeStartError => 'Could not start stocktake.';

  @override
  String get stocktakeSaveError => 'Save failed — input kept locally.';

  @override
  String get stocktakeScanBarcode => 'Scan barcode';

  @override
  String get stocktakeScanNoMatch => 'No matching product found.';

  @override
  String get stocktakeCloseAction => 'Close stocktake';

  @override
  String get stocktakeCloseConfirm => 'Close stocktake?';

  @override
  String get stocktakeCloseConfirmHint =>
      'The stocktake will be closed and differences will be posted. This action cannot be undone.';

  @override
  String get stocktakeCloseSuccess => 'Stocktake closed successfully.';

  @override
  String get stocktakeCloseError => 'Could not close stocktake.';

  @override
  String get stocktakeAllCounted => 'All positions counted.';

  @override
  String get stocktakeDiffReportTitle => 'Difference report';

  @override
  String get stocktakeDiffReportNoDiff => 'No differences — stock is correct.';

  @override
  String get stocktakeNoItems => 'No items';

  @override
  String get detailPaneNoSelection => 'No item selected';

  @override
  String get detailPaneNoSelectionHint =>
      'Pick an item from the list to see its details.';

  @override
  String confirmTypeNamePrompt(String name) {
    return 'Type \"$name\" to confirm.';
  }

  @override
  String get appFeedbackUndoAction => 'Undo';

  @override
  String get appFeedbackSuccessDefault => 'Saved';

  @override
  String get appFeedbackErrorDefault =>
      'Something went wrong. Please try again.';

  @override
  String get errorNetworkOffline =>
      'No internet connection. Please check your network.';

  @override
  String get errorTimeout => 'Request timed out. Please try again.';

  @override
  String get errorAuthExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorFormatInvalid => 'Invalid data format.';

  @override
  String get errorUnknown => 'An unknown error occurred.';

  @override
  String inboxTabSuggestions(int count) {
    return 'Suggestions ($count)';
  }

  @override
  String inboxTabUpdated(int count) {
    return 'Updated ($count)';
  }

  @override
  String inboxTabUnclassified(int count) {
    return 'Unclassified ($count)';
  }

  @override
  String inboxMailboxConnectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mailboxes connected',
      one: '1 mailbox connected',
    );
    return '$_temp0';
  }

  @override
  String get inboxMailboxNone => 'No mailbox connected yet';

  @override
  String get inboxPollingHint =>
      'Polling every 5 min — only order confirmations, shipping and cancellation mails from configured shops appear here.';

  @override
  String get inboxMailboxNoneHint =>
      'Add an IMAP account under Settings → Mailbox.';

  @override
  String get inboxDismissalFilterTooltipEmpty => 'Dismissed filter (0)';

  @override
  String inboxDismissalFilterTooltipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return 'Reset dismissed filter ($_temp0)';
  }

  @override
  String inboxImportingTooltip(int count) {
    return 'Importing mails… ($count so far)';
  }

  @override
  String get inboxPollNowTooltip => 'Poll now (instead of waiting 5 min)';

  @override
  String get inboxConnectFirstTooltip => 'Connect a mailbox in Settings first';

  @override
  String get inboxReparseTrackingTitle => 'Re-read tracking data';

  @override
  String get inboxReparseTrackingSubtitle =>
      'Re-applies the current adapter registry to all suggestions. Fixes incorrectly extracted tracking numbers (e.g. when an adapter bug saved an internal shipment ID instead of the real carrier number).';

  @override
  String get inboxFilterAllShops => 'All shops';

  @override
  String get inboxFilterAllStatus => 'All statuses';

  @override
  String inboxFilterResetBodyCount(int count) {
    return '$count dismissed entries will be shown again. Order confirmations that arrived in the meantime will also reappear in the inbox tab.';
  }

  @override
  String get inboxDiscardFilterCleared => 'Dismissed filter cleared.';

  @override
  String inboxClearDismissalsFailed(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get inboxPolling => 'Polling mailbox…';

  @override
  String inboxPollingFailed(String error) {
    return 'Polling failed: $error';
  }

  @override
  String inboxPollFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mails fetched',
      one: '1 mail fetched',
    );
    return '$_temp0';
  }

  @override
  String inboxPollStored(int count) {
    return '$count stored';
  }

  @override
  String inboxPollSuggestedMerged(int suggested, int matched) {
    return '$suggested suggestions / $matched merged';
  }

  @override
  String get inboxPollUpToDate =>
      'No new matching mails. Mailbox is up to date.';

  @override
  String get inboxRetracking => 'Re-reading tracking data…';

  @override
  String inboxReparseFailed(String error) {
    return 'Re-parse failed: $error';
  }

  @override
  String inboxReparseRescued(int rescued, int scanned) {
    String _temp0 = intl.Intl.pluralLogic(
      rescued,
      locale: localeName,
      other: '$rescued suggestions',
      one: '1 suggestion',
    );
    return '$_temp0 corrected ($scanned checked).';
  }

  @override
  String inboxReparseNoCorrections(int scanned) {
    return 'No corrections needed ($scanned checked).';
  }

  @override
  String get inboxDiscardMailTitle => 'Discard mail?';

  @override
  String inboxDiscardMailBody(String subject) {
    return 'The mail \"$subject\" will be removed from the inbox and no longer shown.';
  }

  @override
  String get inboxMailDiscarded => 'Mail discarded.';

  @override
  String inboxDiscardFailed(String error) {
    return 'Discard failed: $error';
  }

  @override
  String inboxSuggestionCompleteFailed(String error) {
    return 'Could not complete suggestion: $error';
  }

  @override
  String inboxSuggestionRejectFailed(String error) {
    return 'Rejection failed: $error';
  }

  @override
  String inboxTrackingAdopted(int dealId) {
    return 'Tracking applied to deal #$dealId.';
  }

  @override
  String inboxTrackingAdoptionFailed(String error) {
    return 'Tracking adoption failed: $error';
  }

  @override
  String get inboxApplyTrackingToDeal => 'Apply tracking to deal';

  @override
  String inboxApplyTrackingHint(String tracking) {
    return 'Tracking $tracking → deal tracking, status will be set to \"In transit\".';
  }

  @override
  String inboxApplyTrackingHintShort(String tracking) {
    return 'Tracking $tracking → deal tracking.';
  }

  @override
  String get inboxLinkToDealTitle => 'Assign suggestion to deal';

  @override
  String get inboxLinkToDealHint =>
      'Order ID, tracking and ETA will be adopted into the selected deal, the suggestion will be ticked off.';

  @override
  String inboxSuggestionLinked(int dealId) {
    return 'Suggestion linked to deal #$dealId.';
  }

  @override
  String inboxLinkFailed(String error) {
    return 'Assignment failed: $error';
  }

  @override
  String get inboxDetailsAndTracking => 'Show details & tracking';

  @override
  String get inboxLinkToExistingDeal => 'Assign to existing deal';

  @override
  String inboxDealCreatedFromMail(int dealId) {
    return 'Deal #$dealId created from mail.';
  }

  @override
  String get inboxCreateDeal => 'Create deal';

  @override
  String get inboxApplyTrackingToDealShort => 'Tracking → Deal';

  @override
  String get inboxShowDetails => 'Show details';

  @override
  String get inboxCountdownToday => 'Gone today';

  @override
  String get inboxCountdownOneDay => '1 day left';

  @override
  String inboxCountdownDays(int days) {
    return '$days days left';
  }

  @override
  String inboxCountdownTooltip(int totalDays) {
    return 'Inbox visibility $totalDays days. Updates on next refresh.';
  }

  @override
  String get inboxTrackingCopied => 'Tracking number copied.';

  @override
  String get inboxSuggestionRejectedFeedback => 'Suggestion dismissed';

  @override
  String get inboxDiscardFilterClearedFeedback => 'Filter cleared';

  @override
  String get settingsTabMailbox => 'Mailbox';

  @override
  String get settingsBillingSectionTitle => 'Plan & Billing';

  @override
  String get settingsBillingPriceFree => 'free';

  @override
  String settingsBillingPricePerMonth(String price) {
    return '$price / month';
  }

  @override
  String get settingsBillingMostPopular => 'Most Popular';

  @override
  String get settingsBillingActionUpgrade => 'Upgrade';

  @override
  String get settingsBillingActionManage => 'Manage';

  @override
  String get settingsBillingDetailsTitle => 'Billing Details';

  @override
  String get settingsBillingAddressMissing =>
      'Required information incomplete — please complete';

  @override
  String get settingsBillingAddressAdd => 'Add billing address';

  @override
  String get settingsBillingAddressOptional =>
      'Optional — only needed when upgrading';

  @override
  String get settingsMailboxRemoveTitle => 'Remove mailbox';

  @override
  String settingsMailboxRemoveBody(String label) {
    return 'Are you sure you want to delete the IMAP account \"$label\"? All mails imported from this mailbox (suggestions + unclassified) will also be deleted. Orders already accepted into deals will remain unaffected.';
  }

  @override
  String get settingsMailboxDeleteError => 'Deletion failed';

  @override
  String get settingsMailboxRemovedFeedback => 'Mailbox removed';

  @override
  String get settingsMailboxAddLabel => 'IMAP account';

  @override
  String settingsMailboxLimitLabel(int limit) {
    return 'Limit reached ($limit)';
  }

  @override
  String get settingsMailboxLimitDialogTitle => 'Mailbox limit reached';

  @override
  String settingsMailboxLimitDialogBody(
    String plan,
    int limit,
    String mailboxWord,
  ) {
    return 'Your $plan plan allows $limit $mailboxWord. Upgrade to a higher plan to connect more.';
  }

  @override
  String get settingsMailboxWordSingular => 'mailbox';

  @override
  String get settingsMailboxWordPlural => 'mailboxes';

  @override
  String get settingsMailboxQuotaUnlimited => 'unlimited';

  @override
  String get settingsMailboxIntegrationTitle => 'Mailbox Integration';

  @override
  String get settingsMailboxIntegrationDesc =>
      'Connect an IMAP account to automatically detect order and shipping emails. Polling runs every 5 minutes server-side — passwords are stored encrypted with pgp_sym_encrypt. You can accept detected deals in the Inbox tab.';

  @override
  String settingsMailboxQuotaLine(
    String plan,
    String quota,
    String mailboxWord,
    int days,
  ) {
    return '$plan plan: $quota $mailboxWord · $days days inbox history';
  }

  @override
  String get settingsMailboxStatusPaused => 'Paused';

  @override
  String get settingsMailboxStatusError => 'Error';

  @override
  String get settingsMailboxStatusNeverPolled => 'Never polled';

  @override
  String settingsMailboxStatusLastPolled(String relative) {
    return 'Last polled: $relative';
  }

  @override
  String get settingsRelativeJustNow => 'just now';

  @override
  String settingsRelativeMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String settingsRelativeHours(int hours) {
    return '$hours h ago';
  }

  @override
  String settingsRelativeDays(int days) {
    return '$days d ago';
  }

  @override
  String get settingsMailboxEmptyHint => 'No mailbox connected yet.';

  @override
  String get settingsMailboxFreePlanTitle =>
      'Mailbox not included in free plan';

  @override
  String settingsMailboxFreePlanDesc(String plan) {
    return 'Your current plan: $plan. Automatic detection of order and shipping emails is available from the Starter plan — higher plans allow more mailboxes and a longer inbox history.';
  }

  @override
  String get settingsMailboxPlanSoloPro => '1 mailbox · 14-day history';

  @override
  String get settingsMailboxPlanTeam => '1 mailbox · 14-day history';

  @override
  String get settingsMailboxPlanBusiness => '5 mailboxes · 30-day history';

  @override
  String get settingsMailboxPlanEnterprise => '15 mailboxes · 30-day history';

  @override
  String settingsShopsAmazonAlreadyPresent(int skipped) {
    return 'Amazon shops already present ($skipped skipped).';
  }

  @override
  String settingsShopsAmazonAdded(int added, String skippedSuffix) {
    return '$added Amazon shops added$skippedSuffix.';
  }

  @override
  String settingsShopsAmazonSkippedSuffix(int skipped) {
    return ', $skipped already present';
  }

  @override
  String get settingsShopsAddError => 'Failed to add';

  @override
  String settingsShopsAmazonCountAccounts(int count, String word) {
    return '$count $word';
  }

  @override
  String get settingsShopsAmazonAccountSingular => 'Country Account';

  @override
  String get settingsShopsAmazonAccountPlural => 'Country Accounts';

  @override
  String get settingsShippingApiKeyLabel => 'API Key';

  @override
  String settingsShippingDeleteKeyConfirmBody(String carrier) {
    return '$carrier: really remove API key?';
  }

  @override
  String get unsavedChangesDiscardTitle => 'Discard unsaved changes?';

  @override
  String get unsavedChangesDiscardMessage => 'Your changes will be lost.';

  @override
  String get unsavedChangesDiscardLabel => 'Discard';

  @override
  String purchaseOrderScanItemAdded(String name) {
    return '$name +1';
  }

  @override
  String stocktakeScanIncrement(String name) {
    return '$name +1';
  }

  @override
  String suppliersSeedSuccess(int added) {
    return '$added shipping carriers added.';
  }

  @override
  String suppliersSeedAlreadyPresent(int skipped) {
    return 'Shipping carriers are already present ($skipped skipped).';
  }

  @override
  String get suppliersAddCarriersFailed => 'Failed to add shipping carriers.';

  @override
  String get suppliersDeleted => 'Supplier deleted.';

  @override
  String get suppliersDeleteFailed => 'Delete failed.';

  @override
  String get categoryDeleted => 'Category deleted.';

  @override
  String get categoryDeleteFailed => 'Delete failed.';

  @override
  String get warehouseDeleteTitle => 'Delete warehouse';

  @override
  String get warehouseDeleted => 'Warehouse deleted.';

  @override
  String get warehouseDeleteFailed => 'Delete failed.';

  @override
  String get warehouseSaved => 'Warehouse saved.';

  @override
  String get warehouseSaveFailed => 'Save failed.';

  @override
  String get inboxDetailNoSubject => '— no subject —';

  @override
  String inboxDetailFrom(Object address) {
    return 'From: $address';
  }

  @override
  String inboxDetailReceived(Object date) {
    return 'Received: $date';
  }

  @override
  String inboxDetailProcessed(Object date) {
    return 'Processed: $date';
  }

  @override
  String get inboxStatusMatched => 'Updated';

  @override
  String get inboxStatusSuggested => 'Suggestion';

  @override
  String get inboxStatusUnclassified => 'Unclassified';

  @override
  String get inboxStatusFailed => 'Error';

  @override
  String get inboxStatusDismissed => 'Dismissed';

  @override
  String get inboxStatusPending => 'Processing';

  @override
  String get trackingUpdateFailed => 'Tracking update failed.';

  @override
  String get trackingAcceptFailed => 'Tracking acceptance failed.';

  @override
  String get trackingDiscardFailed => 'Tracking discard failed.';

  @override
  String get billingProfileRequiredField => 'Required for paid plans';

  @override
  String get billingProfilePaidHint =>
      'For paid plans, we need a complete billing address (required fields marked with *).';

  @override
  String get billingProfileFieldFullName => 'Full name';

  @override
  String get billingProfileFieldStreet => 'Street & house number';

  @override
  String get billingProfileDataNotice =>
      'This data is used exclusively for invoices and legally required information.';

  @override
  String get billingProfileSaved => 'Billing details saved.';

  @override
  String get billingProfileSaveFailed => 'Save failed.';

  @override
  String get billingProfileSaving => 'Saving…';

  @override
  String get planMenuSelect => 'Select plan';

  @override
  String get planMenuManage => 'Manage plan';

  @override
  String planMenuCurrent(String label) {
    return 'Current: $label';
  }

  @override
  String get planMenuUpgradeBadge => 'Upgrade';

  @override
  String get pricingSelectPlan => 'Select plan';

  @override
  String get pricingActivePlan => 'Active plan';

  @override
  String get pricingSwitchToFree => 'Switch to free';

  @override
  String pricingUpgradeToTitle(String plan) {
    return 'Upgrade to $plan?';
  }

  @override
  String get pricingDowngradeToFreeTitle => 'Switch to free?';

  @override
  String get pricingDowngradeLoseAccess =>
      'You\'ll lose access to Pro features. Existing data will be retained.';

  @override
  String get pricingDemoCheckoutNotice =>
      'Note: This is a demo switch without payment processing. Once Stripe/Paddle is integrated, the real checkout will run here.';

  @override
  String get pricingActivatePlan => 'Activate plan';

  @override
  String get pricingDoSwitch => 'Switch';

  @override
  String get pricingCycleMonthly => 'Monthly';

  @override
  String get pricingCycleYearly => 'Yearly · –17%';

  @override
  String get trackingCarrierPickTitle => 'Select carrier';

  @override
  String get trackingAmazonCountryTitle => 'Amazon · Select country';

  @override
  String get trackingTooltipUnknown =>
      'Tracking — carrier not detected (long press to select)';

  @override
  String trackingTooltipKnown(String carrier) {
    return '$carrier · long press to change';
  }

  @override
  String get globalSearchHint =>
      'Search across deals, inventory, tickets, buyers, suppliers…';

  @override
  String get globalSearchBuyerFilterSubtitle => 'Buyer · filter deals';

  @override
  String get dealPickerSearchHint =>
      'Search by product, ticket, shop or buyer …';

  @override
  String get dealPickerEmpty => 'No matching deal found.';

  @override
  String get mailboxDialogEditTitle => 'Edit mailbox';

  @override
  String get mailboxDialogAddTitle => 'Add IMAP account';

  @override
  String get mailboxDialogPasswordEditLabel =>
      'App password (leave empty to keep unchanged)';

  @override
  String get productInvalidNumber => 'Invalid number';

  @override
  String inventoryPiecesCount(int quantity) {
    return '$quantity pcs';
  }

  @override
  String get heatmapTapHint => 'Tap a day for details';

  @override
  String get billingProfileSectionContact => 'Contact person';

  @override
  String get billingProfileSectionAddress => 'Billing address';

  @override
  String get billingProfileFieldCompany => 'Company (optional)';

  @override
  String get billingProfileFieldVatId => 'VAT ID (optional)';

  @override
  String get billingProfileFieldPhone => 'Phone';

  @override
  String get billingProfileFieldAddr2 => 'Address supplement (optional)';

  @override
  String get billingProfileFieldPostal => 'Postal code';

  @override
  String get billingProfileFieldCity => 'City';

  @override
  String get billingProfileFieldRegion => 'State / Region (optional)';

  @override
  String get billingProfileFieldCountry => 'Country';

  @override
  String get billingProfileCountryValidation => 'ISO 2-letter code';

  @override
  String pricingPlanActivated(String plan) {
    return 'Plan $plan activated.';
  }

  @override
  String get pricingActivationFailed => 'Activation failed.';

  @override
  String get heatmapLess => 'Less';

  @override
  String get heatmapMore => 'More';

  @override
  String get validationInvalidEmail => 'Invalid email address';

  @override
  String get validationInvalidPort => 'Port must be between 1 and 65535';

  @override
  String get mailboxDialogLabelLabel => 'Label';

  @override
  String get mailboxDialogLabelHint => 'e.g. \"Gmail Reseller\"';

  @override
  String get mailboxDialogHostLabel => 'IMAP server';

  @override
  String get mailboxDialogPortLabel => 'Port';

  @override
  String get mailboxDialogUsernameLabel => 'Username / email address';

  @override
  String get mailboxDialogPasswordNewLabel => 'App password';

  @override
  String get mailboxDialogPasswordHelper =>
      'For Gmail/Outlook: generate a separate app password.';

  @override
  String get mailboxDialogFolderLabel => 'Folder';

  @override
  String get mailboxDialogSslLabel => 'Use SSL/TLS';

  @override
  String get mailboxDialogPollingLabel => 'Polling active';

  @override
  String get mailboxDialogPollingSubtitle =>
      'Polled every 5 minutes by the edge function.';

  @override
  String get mailboxDialogRequiredError =>
      'Label, server and username are required fields.';

  @override
  String get mailboxDialogPasswordRequiredError =>
      'Password is required when creating a new account.';

  @override
  String mailboxDialogSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String semanticsChartBar(
    String title,
    int count,
    String topValue,
    String topLabel,
  ) {
    return 'Bar chart. $title. $count values. Highest value: $topValue for $topLabel.';
  }

  @override
  String semanticsChartLine(
    String title,
    int count,
    String topValue,
    String topLabel,
  ) {
    return 'Line chart. $title. $count data points. Highest value: $topValue for $topLabel.';
  }

  @override
  String semanticsChartPie(
    String title,
    int count,
    String topLabel,
    String topPct,
  ) {
    return 'Pie chart. $title. $count segments. Dominant segment: $topLabel at $topPct%.';
  }

  @override
  String get semanticsChartLoading => 'Chart loading.';

  @override
  String get paletteNavGroupLabel => 'Navigation';

  @override
  String get paletteActionGroupLabel => 'Actions';

  @override
  String get paletteNavDashboard => 'Open Dashboard';

  @override
  String get paletteNavDeals => 'Open Deals';

  @override
  String get paletteNavTickets => 'Open Tickets';

  @override
  String get paletteNavInbox => 'Open Inbox';

  @override
  String get paletteNavInventory => 'Open Inventory';

  @override
  String get paletteNavSuppliers => 'Open Suppliers';

  @override
  String get paletteNavStatistics => 'Open Statistics';

  @override
  String get paletteNavActivity => 'Open Activity';

  @override
  String get paletteNavSettings => 'Open Settings';

  @override
  String get paletteNavWarehouse => 'Open Warehousing';

  @override
  String get paletteNavHelp => 'Open Help';

  @override
  String get paletteSubInventory => 'Inventory (Stock)';

  @override
  String get paletteSubProductCatalog => 'Product catalog (Warehousing)';

  @override
  String get paletteSubPurchaseOrders => 'Orders (Warehousing)';

  @override
  String get paletteSubWarehouses => 'Warehouses (Warehousing)';

  @override
  String get paletteSubCategories => 'Categories (Warehousing)';

  @override
  String get paletteSubStocktake => 'Stocktake (Warehousing)';

  @override
  String get paletteSubSettingsInbox => 'Mailbox settings';

  @override
  String get paletteSubSettingsShipping => 'Shipping settings';

  @override
  String get paletteSubSettingsPush => 'Push settings';

  @override
  String get paletteSubSettingsTeam => 'Team settings';

  @override
  String get paletteSubSettingsGeneral => 'General settings';

  @override
  String get paletteActionNewDeal => 'New deal';

  @override
  String get paletteActionCsvImport => 'Import CSV';

  @override
  String get paletteActionCsvExport => 'Export CSV';

  @override
  String get paletteActionToggleTheme => 'Toggle theme (light/dark)';

  @override
  String get breadcrumbSeparatorTooltip => 'Navigation path';

  @override
  String get appBarMenuCsvImport => 'Import CSV';

  @override
  String get appBarMenuCsvExport => 'Export CSV';

  @override
  String get quickActionsTitle => 'Quick actions';

  @override
  String get quickActionsTooltip => 'Quick actions';
}
