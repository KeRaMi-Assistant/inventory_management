import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';

String localizePricingTagline(AppLocalizations l10n, BillingPlan plan) {
  switch (plan) {
    case BillingPlan.free:
      return l10n.pricingPlanFreeTagline;
    case BillingPlan.starter:
      return l10n.pricingPlanStarterTagline;
    case BillingPlan.pro:
      return l10n.pricingPlanProTagline;
    case BillingPlan.business:
      return l10n.pricingPlanBusinessTagline;
    case BillingPlan.ultimate:
      return l10n.pricingPlanUltimateTagline;
  }
}

List<String> localizePricingHighlights(
    AppLocalizations l10n, BillingPlan plan) {
  switch (plan) {
    case BillingPlan.free:
      return [
        l10n.pricingHighlightFreeProducts,
        l10n.pricingHighlightFreeDeals,
        l10n.pricingHighlightFreeNoImages,
        l10n.pricingHighlightFreeOverviewStats,
        l10n.pricingHighlightFreeNoMailbox,
        l10n.pricingHighlightFreeCommunitySupport,
      ];
    case BillingPlan.starter:
      return [
        l10n.pricingHighlightStarterProducts,
        l10n.pricingHighlightStarterDealsUnlimited,
        l10n.pricingHighlightStarterImageStorage,
        l10n.pricingHighlightStarterMailbox,
        l10n.pricingHighlightStarterCsv,
        l10n.pricingHighlightStarterBarcode,
        l10n.pricingHighlightStarterEmailSupport,
      ];
    case BillingPlan.pro:
      return [
        l10n.pricingHighlightProProducts,
        l10n.pricingHighlightProDealsUnlimited,
        l10n.pricingHighlightProTeam,
        l10n.pricingHighlightProImageStorage,
        l10n.pricingHighlightProMailbox,
        l10n.pricingHighlightProAnalytics,
        l10n.pricingHighlightProActivityLog,
        l10n.pricingHighlightProPush,
        l10n.pricingHighlightProPrioritySupport,
      ];
    case BillingPlan.business:
      return [
        l10n.pricingHighlightBusinessProducts,
        l10n.pricingHighlightBusinessTeam,
        l10n.pricingHighlightBusinessImageStorage,
        l10n.pricingHighlightBusinessMailbox,
        l10n.pricingHighlightBusinessApi,
        l10n.pricingHighlightBusinessDatev,
        l10n.pricingHighlightBusinessBranding,
        l10n.pricingHighlightBusinessSla,
      ];
    case BillingPlan.ultimate:
      return [
        l10n.pricingHighlightUltimateProducts,
        l10n.pricingHighlightUltimateMailbox,
        l10n.pricingHighlightUltimateTeam,
        l10n.pricingHighlightUltimateImageStorage,
        l10n.pricingHighlightUltimateSso,
        l10n.pricingHighlightUltimateWhitelabel,
        l10n.pricingHighlightUltimateMarketplace,
        l10n.pricingHighlightUltimateAccountManager,
        l10n.pricingHighlightUltimateUptime,
      ];
  }
}
