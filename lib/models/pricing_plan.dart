import 'billing_profile.dart';

/// Statische Definition der Pricing-Tiers. Wird sowohl vom Pricing-Screen
/// als auch (perspektivisch) von Quota-Checks im Inventory/Workspace-Code
/// gelesen. Single source of truth — wenn sich Preise oder Limits ändern,
/// passiert das hier zentral.
class PricingPlan {
  final BillingPlan plan;
  final String tagline;
  final double monthlyPriceEur;
  final double yearlyPriceEur;
  final int productLimit;
  final int dealsPerMonthLimit;
  final int teamMembers;
  final int imagesPerEntity;
  final int storageMb;
  final List<String> highlights;
  final bool mostPopular;
  final bool customPricing;

  const PricingPlan({
    required this.plan,
    required this.tagline,
    required this.monthlyPriceEur,
    required this.yearlyPriceEur,
    required this.productLimit,
    required this.dealsPerMonthLimit,
    required this.teamMembers,
    required this.imagesPerEntity,
    required this.storageMb,
    required this.highlights,
    this.mostPopular = false,
    this.customPricing = false,
  });

  static const int unlimited = -1;

  bool get isFree => plan == BillingPlan.free;

  /// Statischer Katalog. Reihenfolge = Anzeige-Reihenfolge im Pricing-Grid.
  static const List<PricingPlan> all = <PricingPlan>[
    PricingPlan(
      plan: BillingPlan.free,
      tagline: 'Zum Reinschnuppern',
      monthlyPriceEur: 0,
      yearlyPriceEur: 0,
      productLimit: 50,
      dealsPerMonthLimit: 25,
      teamMembers: 1,
      imagesPerEntity: 1,
      storageMb: 50,
      highlights: [
        'Bis zu 50 Produkte',
        '25 Deals pro Monat',
        '1 Bild pro Eintrag',
        'Nur Übersichts-Statistik',
        'Community-Support',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.starter,
      tagline: 'Für Solo-Reseller',
      monthlyPriceEur: 6.99,
      yearlyPriceEur: 69,
      productLimit: 500,
      dealsPerMonthLimit: unlimited,
      teamMembers: 1,
      imagesPerEntity: 5,
      storageMb: 1024,
      highlights: [
        'Bis zu 500 Produkte',
        'Unbegrenzt Deals',
        '5 Bilder pro Eintrag · 1 GB Storage',
        'Alle 5 Statistik-Tabs',
        'CSV Import & Export',
        'PDF/Excel Reports',
        'Barcode-Scanner',
        'E-Mail-Support (48h)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.pro,
      tagline: 'Für aktive Reseller',
      monthlyPriceEur: 14.99,
      yearlyPriceEur: 149,
      productLimit: 5000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 3,
      imagesPerEntity: 10,
      storageMb: 10240,
      mostPopular: true,
      highlights: [
        'Bis zu 5.000 Produkte',
        'Unbegrenzt Deals',
        'Bis zu 3 Team-Mitglieder',
        '10 Bilder pro Eintrag · 10 GB Storage',
        'Drilldowns, Heatmaps & Trends',
        'Activity-Log & Audit-Trail',
        'Deal-Kommentare',
        'Push-Benachrichtigungen',
        'Priority-Support (24h)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.business,
      tagline: 'Für Power-Reseller & Teams',
      monthlyPriceEur: 34.99,
      yearlyPriceEur: 349,
      productLimit: unlimited,
      dealsPerMonthLimit: unlimited,
      teamMembers: 10,
      imagesPerEntity: 25,
      storageMb: 51200,
      highlights: [
        'Unbegrenzte Produkte',
        'Bis zu 10 Team-Mitglieder',
        '25 Bilder pro Eintrag · 50 GB Storage',
        'DATEV-Export (geplant)',
        'Marketplace-Sync (geplant)',
        'API-Zugriff & Webhooks',
        'Custom Branding für Reports',
        'Priority-SLA (12h)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.enterprise,
      tagline: 'Für Wholesale & Multi-Standort',
      monthlyPriceEur: 99,
      yearlyPriceEur: 990,
      productLimit: unlimited,
      dealsPerMonthLimit: unlimited,
      teamMembers: unlimited,
      imagesPerEntity: unlimited,
      storageMb: unlimited,
      customPricing: true,
      highlights: [
        'Alles unbegrenzt',
        'Unbegrenzt Team-Mitglieder',
        'Single Sign-On (SAML/OIDC)',
        'White-Label-Option',
        'On-Premise möglich',
        'Dedizierter Account Manager',
        'Uptime-SLA 99,9%',
        'Auftragsverarbeitungsvertrag (AVV)',
      ],
    ),
  ];

  static PricingPlan forBillingPlan(BillingPlan plan) =>
      all.firstWhere((p) => p.plan == plan, orElse: () => all.first);
}
