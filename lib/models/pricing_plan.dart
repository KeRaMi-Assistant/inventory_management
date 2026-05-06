import 'billing_profile.dart';

/// Statische Definition der Pricing-Tiers. Wird sowohl vom Pricing-Screen
/// als auch von den Quota-Checks (Inbox-Limit, Mailbox-Anzahl,
/// Sichtbarkeit etc.) gelesen — single source of truth.
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

  /// Anzahl der IMAP-Konten, die der User parallel verbinden darf.
  /// 0 = Postfach-Feature komplett ausgeblendet (Free-Tier).
  final int mailboxLimit;

  /// Wie weit die Inbox in die Vergangenheit zeigt — Suggestions/Mails
  /// älter als das werden im UI ausgeblendet (DB-Cleanup läuft separat
  /// nach 30 Tagen). 0 für Pläne ohne Postfach.
  final int inboxVisibilityDays;

  final List<String> highlights;
  final bool mostPopular;

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
    required this.mailboxLimit,
    required this.inboxVisibilityDays,
    required this.highlights,
    this.mostPopular = false,
  });

  static const int unlimited = -1;

  bool get isFree => plan == BillingPlan.free;

  bool get hasInbox => mailboxLimit != 0;

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
      imagesPerEntity: 0,
      storageMb: 50,
      mailboxLimit: 0,
      inboxVisibilityDays: 0,
      highlights: [
        'Bis zu 50 Produkte',
        '25 Deals pro Monat',
        'Keine Bilder pro Eintrag',
        'Nur Übersichts-Statistik',
        'Kein Postfach-Import',
        'Community-Support',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.starter,
      tagline: 'Solo-Reseller, das Wesentliche',
      monthlyPriceEur: 6.99,
      yearlyPriceEur: 69,
      productLimit: 500,
      dealsPerMonthLimit: unlimited,
      teamMembers: 1,
      imagesPerEntity: 1,
      storageMb: 1024,
      mailboxLimit: 1,
      inboxVisibilityDays: 7,
      highlights: [
        'Bis zu 500 Produkte',
        'Unbegrenzt Deals',
        '1 Bild pro Eintrag · 1 GB Storage',
        '1 Postfach · 7 Tage Inbox-Verlauf',
        'CSV Import & Export',
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
      imagesPerEntity: 5,
      storageMb: 10240,
      mailboxLimit: 3,
      inboxVisibilityDays: 14,
      mostPopular: true,
      highlights: [
        'Bis zu 5.000 Produkte',
        'Unbegrenzt Deals',
        'Bis zu 3 Team-Mitglieder',
        '5 Bilder pro Eintrag · 10 GB Storage',
        '3 Postfächer · 14 Tage Inbox-Verlauf',
        'Drilldowns, Heatmaps & Trends',
        'Activity-Log & Audit-Trail',
        'Push-Benachrichtigungen',
        'Priority-Support (24h)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.business,
      tagline: 'Power-Reseller & Teams',
      monthlyPriceEur: 34.99,
      yearlyPriceEur: 349,
      productLimit: 100000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 10,
      imagesPerEntity: 10,
      storageMb: 51200,
      mailboxLimit: 10,
      inboxVisibilityDays: 30,
      highlights: [
        'Bis zu 100.000 Produkte',
        'Bis zu 10 Team-Mitglieder',
        '10 Bilder pro Eintrag · 50 GB Storage',
        '10 Postfächer · 30 Tage Inbox-Verlauf',
        'API-Zugriff & Webhooks',
        'DATEV-Export (geplant)',
        'Custom Branding für Reports',
        'Priority-SLA (12h)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.ultimate,
      tagline: 'Für Wholesale & Heavy-Volume',
      monthlyPriceEur: 59.99,
      yearlyPriceEur: 599,
      productLimit: 300000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 50,
      imagesPerEntity: 25,
      storageMb: unlimited,
      mailboxLimit: 15,
      inboxVisibilityDays: 90,
      highlights: [
        'Bis zu 300.000 Produkte',
        '15 Postfächer · 90 Tage Inbox-Verlauf',
        'Bis zu 50 Team-Mitglieder',
        '25 Bilder pro Eintrag · unbegrenzter Storage',
        'Single Sign-On (SAML/OIDC)',
        'White-Label-Option',
        'Marketplace-Sync (geplant)',
        'Dedizierter Account Manager',
        'Uptime-SLA 99,9%',
      ],
    ),
  ];

  static PricingPlan forBillingPlan(BillingPlan plan) =>
      all.firstWhere((p) => p.plan == plan, orElse: () => all.first);
}
