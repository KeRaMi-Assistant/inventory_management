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
  String get settingsTabGeneral => 'General';

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
  String get settingsThemeSection => 'Appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

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
}
