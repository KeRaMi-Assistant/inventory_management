import 'billing_profile.dart';

/// Statische Definition der Pricing-Tiers. Wird sowohl vom Pricing-Screen
/// als auch von den Quota-Checks (Inbox-Limit, Mailbox-Anzahl,
/// Sichtbarkeit etc.) gelesen — single source of truth.
class PricingPlan {
  final BillingPlan plan;
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

  final bool mostPopular;

  const PricingPlan({
    required this.plan,
    required this.monthlyPriceEur,
    required this.yearlyPriceEur,
    required this.productLimit,
    required this.dealsPerMonthLimit,
    required this.teamMembers,
    required this.imagesPerEntity,
    required this.storageMb,
    required this.mailboxLimit,
    required this.inboxVisibilityDays,
    this.mostPopular = false,
  });

  static const int unlimited = -1;

  bool get isFree => plan == BillingPlan.free;

  bool get hasInbox => mailboxLimit != 0;

  /// Statischer Katalog. Reihenfolge = Anzeige-Reihenfolge im Pricing-Grid.
  /// Tagline + Highlights pro Plan kommen aus der l10n-Schicht
  /// (`utils/pricing_plan_l10n.dart`), nicht aus dem Model.
  static const List<PricingPlan> all = <PricingPlan>[
    PricingPlan(
      plan: BillingPlan.free,
      monthlyPriceEur: 0,
      yearlyPriceEur: 0,
      productLimit: 50,
      dealsPerMonthLimit: 25,
      teamMembers: 1,
      imagesPerEntity: 0,
      storageMb: 50,
      mailboxLimit: 0,
      inboxVisibilityDays: 0,
    ),
    PricingPlan(
      plan: BillingPlan.starter,
      monthlyPriceEur: 6.99,
      yearlyPriceEur: 69,
      productLimit: 500,
      dealsPerMonthLimit: unlimited,
      teamMembers: 1,
      imagesPerEntity: 1,
      storageMb: 1024,
      mailboxLimit: 1,
      inboxVisibilityDays: 7,
    ),
    PricingPlan(
      plan: BillingPlan.pro,
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
    ),
    PricingPlan(
      plan: BillingPlan.business,
      monthlyPriceEur: 34.99,
      yearlyPriceEur: 349,
      productLimit: 100000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 10,
      imagesPerEntity: 10,
      storageMb: 51200,
      mailboxLimit: 10,
      inboxVisibilityDays: 30,
    ),
    PricingPlan(
      plan: BillingPlan.ultimate,
      monthlyPriceEur: 59.99,
      yearlyPriceEur: 599,
      productLimit: 300000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 50,
      imagesPerEntity: 25,
      storageMb: unlimited,
      mailboxLimit: 15,
      inboxVisibilityDays: 90,
    ),
  ];

  static PricingPlan forBillingPlan(BillingPlan plan) =>
      all.firstWhere((p) => p.plan == plan, orElse: () => all.first);
}
