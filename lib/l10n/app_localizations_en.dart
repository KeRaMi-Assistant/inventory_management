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
  String get loginModePersonal => 'Personal';

  @override
  String get loginModeTeam => 'Team';

  @override
  String get loginTeamIdLabel => 'Team ID';

  @override
  String get loginTeamIdHelp => 'The workspace ID shared by your team owner.';

  @override
  String get loginTeamIdRequired => 'Team ID required';

  @override
  String get loginTeamIdInvalid => 'Invalid team ID (UUID expected)';

  @override
  String get loginTeamNotMember => 'You are not a member of this team.';

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
  String get shippingIntroTitle => 'Carrier API keys';

  @override
  String get shippingIntroBody =>
      'Enter an API key for each carrier you use so the inventory app can poll delivery status every 4 hours and mark deals as “Arrived” automatically.';

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
  String get teamInviteRevoke => 'Revoke invite';

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
      'In transit — shipping confirmation detected or set manually. Tracking number is polled every few hours.';

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
      'When a shipping mail with a tracking number arrives (Amazon, DHL, DPD, UPS, Hermes, GLS), the matching deal is set to \"In transit\" automatically. Once the carrier reports delivery, the deal flips to \"Arrived\".';

  @override
  String get helpDealsDropShipTitle => 'Multi drop-ship';

  @override
  String get helpDealsDropShipDesc =>
      'If a deal sources from several shops (drop-ship), you can record multiple sources with their purchase prices when creating it. Profit is summed across sources, but the statistic counts the deal as one sale.';

  @override
  String get helpDealsRetrackTitle => 'Refresh shipment status now (Retrack)';

  @override
  String get helpDealsRetrackDesc =>
      'In the deal detail view, next to the tracking number, you\'ll find a refresh icon labelled \"Refresh status\". It asks the carrier for the current status right away instead of waiting for the next scheduled poll — handy, for example, just before a planned delivery.\nOne retrack per deal is allowed every 30 seconds. While the lock is active the button is greyed out and shows \"Please wait 30s\" — that protects the carrier API from unnecessary calls and you from rate limits.';

  @override
  String get helpShippingSection => 'Shipping & carrier API keys';

  @override
  String get helpShippingIntroTitle => 'Why carrier API keys?';

  @override
  String get helpShippingIntroDesc =>
      'So the app can fetch the live status of your shipments straight from the carrier (rather than just reading mails), you store one API key per carrier under Settings → Shipping. One key per carrier per workspace is enough — every member benefits from it.';

  @override
  String get helpShippingDhlTitle => 'DHL — actively supported';

  @override
  String get helpShippingDhlDesc =>
      'DHL works out of the box:\n• Create an account on developer.dhl.com (free).\n• Subscribe to the \"Shipment Tracking - Unified\" API there — the free tier is enough for personal use.\n• Copy the API key and paste it under Settings → Shipping → DHL → \"Save API key\".\nFrom now on, deals with a DHL tracking number are refreshed at regular intervals and the status (in transit, out for delivery, delivered) appears directly on the deal.';

  @override
  String get helpShippingComingSoonTitle => 'DPD and UPS — coming soon';

  @override
  String get helpShippingComingSoonDesc =>
      'DPD and UPS show up in the list but are currently marked \"Coming soon\" and not editable. The integration ships in a later update — until then, shipments from these carriers are still detected from shipping mails, only the live status is missing. Nothing is broken, this is intentional.';

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
      '• New order confirmation in the mailbox\n• Tracking update (shipped / arrived)\n• Minimum stock undercut (if enabled)\n• Workspace invitation\nYou can disable individual categories under Settings → Push.';

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
      'Carrier polling runs every 4 hours. Check Settings → Shipping that the carrier API key is set. Without a key the app cannot query the status — the mail pipeline may fill the gap via shipping mails.';

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
      'Since May 2026 the app only stores a tracking number when it is structurally verified (carrier pattern + length/checksum check). When the mail only contains an internal shop ID (e.g. an Amazon Logistics shipment ID) or the number is ambiguously formatted, the app deliberately leaves the field empty instead of saving a wrong value. You can always enter the tracking number manually on the deal — manual entries are never overwritten automatically.';

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
  String get ticketsNoTicket => 'No ticket';

  @override
  String get inventoryEmpty => 'Inventory is empty.';

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
}
