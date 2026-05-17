import 'billing_profile.dart';

/// Kategorie-Gruppierung für die Pricing-Anzeige.
///
/// - [PricingCategory.personal] = B2C, brutto-Preise (inkl. 19 % MwSt).
///   Reseller, Solo-User, Privathaushalte.
/// - [PricingCategory.enterprise] = B2B, netto-Preise (excl. MwSt).
///   Firmen, Teams, Power-User mit Vorsteuer-Abzug.
enum PricingCategory { personal, enterprise }

/// Statische Definition der Pricing-Tiers. Wird sowohl vom Pricing-Screen
/// als auch von den Quota-Checks (Inbox-Limit, Mailbox-Anzahl,
/// Sichtbarkeit etc.) gelesen — single source of truth.
///
/// Preis-Konventionen:
/// - [monthlyPriceEur] und [yearlyPriceEur] sind **so wie sie dem User
///   angezeigt werden** — also brutto bei `personal`, netto bei `enterprise`.
/// - [vatIncluded] sagt, was der Preis ist:
///     `true`  → Preis enthält bereits 19 % VAT (B2C-Anzeige).
///     `false` → Preis ist netto, VAT kommt zusätzlich oben drauf (B2B).
/// - [vatRate] ist konstant 0.19 für DE. Andere Länder werden später
///   über Stripe-Tax dynamisch korrigiert.
///
/// Marge-Regel (siehe [marketing/PRICING.md](../../marketing/PRICING.md)):
/// Listenpreis ≥ 10 × Worst-Case-Backend-Kosten dieses Tiers,
/// d. h. ≥ 80 % Marge selbst beim teuersten denkbaren User pro Tier.
class PricingPlan {
  final BillingPlan plan;
  final PricingCategory category;
  final String tagline;

  /// Preis pro Monat, **wie er dem User angezeigt wird**.
  /// Bei `personal` brutto inkl. VAT, bei `enterprise` netto excl. VAT.
  final double monthlyPriceEur;
  final double yearlyPriceEur;

  /// Wenn `true`, enthält [monthlyPriceEur]/[yearlyPriceEur] bereits die
  /// MwSt. Wenn `false`, muss sie für die brutto-Anzeige aufaddiert werden.
  final bool vatIncluded;

  final int productLimit;
  final int dealsPerMonthLimit;
  final int teamMembers;
  final int workspaceLimit;
  final int imagesPerEntity;
  final int storageMb;

  /// Anzahl der IMAP-Konten, die der User parallel verbinden darf.
  /// 0 = Postfach-Feature komplett ausgeblendet — gilt für alle
  /// Privat-Tiers (Enterprise-only-Feature).
  final int mailboxLimit;

  /// Wie weit die Inbox in die Vergangenheit zeigt — Suggestions/Mails
  /// älter als das werden im UI ausgeblendet (DB-Cleanup läuft separat
  /// nach 30 Tagen). 0 für Pläne ohne Postfach.
  final int inboxVisibilityDays;

  final List<String> highlights;
  final bool mostPopular;

  const PricingPlan({
    required this.plan,
    required this.category,
    required this.tagline,
    required this.monthlyPriceEur,
    required this.yearlyPriceEur,
    required this.vatIncluded,
    required this.productLimit,
    required this.dealsPerMonthLimit,
    required this.teamMembers,
    required this.workspaceLimit,
    required this.imagesPerEntity,
    required this.storageMb,
    required this.mailboxLimit,
    required this.inboxVisibilityDays,
    required this.highlights,
    this.mostPopular = false,
  });

  static const int unlimited = -1;
  static const double vatRate = 0.19;

  bool get isFree => plan == BillingPlan.free;

  bool get hasInbox => mailboxLimit != 0;

  /// Anzeige-Preis netto. Für `personal` aus dem Brutto-Preis raus-
  /// gerechnet; für `enterprise` identisch zu [monthlyPriceEur].
  double get monthlyPriceNet =>
      vatIncluded ? monthlyPriceEur / (1 + vatRate) : monthlyPriceEur;

  /// Anzeige-Preis brutto. Für `enterprise` aus dem Netto-Preis
  /// hinzugerechnet; für `personal` identisch zu [monthlyPriceEur].
  double get monthlyPriceGross =>
      vatIncluded ? monthlyPriceEur : monthlyPriceEur * (1 + vatRate);

  double get yearlyPriceNet =>
      vatIncluded ? yearlyPriceEur / (1 + vatRate) : yearlyPriceEur;

  double get yearlyPriceGross =>
      vatIncluded ? yearlyPriceEur : yearlyPriceEur * (1 + vatRate);

  /// Statischer Katalog. Reihenfolge = Anzeige-Reihenfolge im Pricing-Grid,
  /// gruppiert nach [category].
  static const List<PricingPlan> all = <PricingPlan>[
    // ─── Privat-Kategorie (B2C, brutto-Preise inkl. 19 % VAT) ─────────
    PricingPlan(
      plan: BillingPlan.free,
      category: PricingCategory.personal,
      tagline: 'Zum Reinschnuppern',
      monthlyPriceEur: 0,
      yearlyPriceEur: 0,
      vatIncluded: true,
      productLimit: 50,
      dealsPerMonthLimit: 25,
      teamMembers: 1,
      workspaceLimit: 1,
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
      plan: BillingPlan.solo,
      category: PricingCategory.personal,
      tagline: 'Solo-Reseller, das Wesentliche',
      monthlyPriceEur: 4.99,
      yearlyPriceEur: 49.90,
      vatIncluded: true,
      productLimit: 2000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 1,
      workspaceLimit: 1,
      imagesPerEntity: 3,
      storageMb: 5120,
      mailboxLimit: 0,
      inboxVisibilityDays: 0,
      highlights: [
        'Bis zu 2.000 Produkte',
        'Unbegrenzt Deals',
        '3 Bilder pro Eintrag · 5 GB Storage',
        'Volle Statistik (Drilldowns, Heatmaps)',
        'CSV + PDF + Excel-Export',
        'Eigene Carrier-API-Keys',
        'E-Mail-Support (48h)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.soloPlus,
      category: PricingCategory.personal,
      tagline: 'Power-Solo-User',
      monthlyPriceEur: 9.99,
      yearlyPriceEur: 99.90,
      vatIncluded: true,
      mostPopular: true,
      productLimit: 10000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 1,
      workspaceLimit: 1,
      imagesPerEntity: 8,
      storageMb: 25600,
      mailboxLimit: 0,
      inboxVisibilityDays: 0,
      highlights: [
        'Bis zu 10.000 Produkte',
        'Unbegrenzt Deals',
        '8 Bilder pro Eintrag · 25 GB Storage',
        'Volle Statistik + Forecast',
        'DATEV-Export (in Vorbereitung)',
        'Activity-Log & Audit-Trail',
        'Custom-Branding für PDFs',
        'E-Mail-Support (24h)',
      ],
    ),
    // ─── Enterprise-Kategorie (B2B, netto-Preise excl. VAT) ───────────
    PricingPlan(
      plan: BillingPlan.team,
      category: PricingCategory.enterprise,
      tagline: 'Kleine Crews, erstes Postfach',
      monthlyPriceEur: 19.99,
      yearlyPriceEur: 199.90,
      vatIncluded: false,
      productLimit: 25000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 5,
      workspaceLimit: 3,
      imagesPerEntity: 5,
      storageMb: 51200,
      mailboxLimit: 1,
      inboxVisibilityDays: 30,
      highlights: [
        'Bis zu 25.000 Produkte',
        '5 Team-Mitglieder · 3 Workspaces',
        '5 Bilder pro Eintrag · 50 GB Storage',
        '1 Postfach · 30 Tage Inbox-Verlauf',
        'Mail-Tracking-Auto-Detect',
        'Workspace-Einladungen',
        'API (Read-only)',
        'E-Mail-Support (24h)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.business,
      category: PricingCategory.enterprise,
      tagline: 'Wachsende Reseller-Crews',
      monthlyPriceEur: 49.99,
      yearlyPriceEur: 499.90,
      vatIncluded: false,
      productLimit: 100000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 15,
      workspaceLimit: 5,
      imagesPerEntity: 10,
      storageMb: 102400,
      mailboxLimit: 5,
      inboxVisibilityDays: 60,
      highlights: [
        'Bis zu 100.000 Produkte',
        '15 Team-Mitglieder · 5 Workspaces',
        '10 Bilder pro Eintrag · 100 GB Storage',
        '5 Postfächer · 60 Tage Inbox-Verlauf',
        'Mail-Tracking-Auto-Detect',
        'API (Read + Write) + Webhooks',
        'Custom-Branding für Reports',
        'Priority-Support (12h SLA)',
      ],
    ),
    PricingPlan(
      plan: BillingPlan.enterprise,
      category: PricingCategory.enterprise,
      tagline: 'Wholesale & Multi-Brand',
      monthlyPriceEur: 99.99,
      yearlyPriceEur: 999.90,
      vatIncluded: false,
      productLimit: 300000,
      dealsPerMonthLimit: unlimited,
      teamMembers: 50,
      workspaceLimit: 10,
      imagesPerEntity: 20,
      storageMb: 256000,
      mailboxLimit: 15,
      inboxVisibilityDays: 90,
      highlights: [
        'Bis zu 300.000 Produkte',
        '50 Team-Mitglieder · 10 Workspaces',
        '20 Bilder pro Eintrag · 250 GB Storage',
        '15 Postfächer · 90 Tage Inbox-Verlauf',
        'API (Read + Write + Bulk) + Webhooks',
        'Single Sign-On (SAML/OIDC)',
        'White-Label-Option',
        'Dedizierter Account-Manager',
        'Uptime-SLA 99,9 %',
      ],
    ),
  ];

  static PricingPlan forBillingPlan(BillingPlan plan) =>
      all.firstWhere((p) => p.plan == plan, orElse: () => all.first);

  /// Alle Tiers einer Kategorie, in Anzeige-Reihenfolge.
  static List<PricingPlan> forCategory(PricingCategory cat) =>
      all.where((p) => p.category == cat).toList(growable: false);
}
