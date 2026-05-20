/// Plan-Tier des Users. `free` ist Default; alles ab `solo` ist
/// kostenpflichtig und erfordert eine vollständige Rechnungsadresse.
///
/// Pricing-Restruktur 2026-05-17 → 2026-05-20: 6-Tier-Schema in zwei
/// sichtbaren Kategorien.
/// - Privat (B2C, brutto): free / solo / soloPro
/// - Enterprise (B2B, netto): team / business / enterprise
///
/// Legacy-DB-Werte werden in `fromString` auf das neue Schema gemappt.
enum BillingPlan {
  free,

  // ── Privat-Kategorie (B2C, brutto-Preise) ──────────────────────────
  solo,
  soloPro,

  // ── Enterprise-Kategorie (B2B, netto-Preise) ───────────────────────
  team,
  business,
  enterprise;

  /// Tolerant gegenüber Legacy-Werten in der DB.
  ///
  /// Mapping-Tabelle:
  /// - `starter` (uralt €6.99)    → `solo`     (neu €4.99)
  /// - `pro` (uralt €14.99)       → `soloPro`  (neu €14.99)
  /// - `solo_plus`/`soloplus`     → `soloPro`  (Zwischen-Rename 2026-05-17→20)
  /// - `business` (uralt €34.99)  → `business` (neu €49.99 netto)
  /// - `ultimate` (uralt €59.99)  → `enterprise` (neu €99.99 netto)
  /// - Unbekannt → `free` (Sicherheits-Fallback).
  static BillingPlan fromString(String s) => switch (s.toLowerCase()) {
        'solo' => solo,
        'solo_pro' || 'solopro' => soloPro,
        'team' => team,
        'business' => business,
        'enterprise' => enterprise,
        // Legacy aliases (pre-restructure DB values)
        'starter' => solo,
        'pro' => soloPro,
        'solo_plus' || 'soloplus' => soloPro,
        'ultimate' => enterprise,
        _ => free,
      };

  /// DB-/Stripe-Bezeichner. Snake-case wo nötig (`soloPro` → `solo_pro`),
  /// sonst Dart-name.
  String get apiName => switch (this) {
        BillingPlan.soloPro => 'solo_pro',
        _ => name,
      };

  bool get isPaid => this != BillingPlan.free;

  String get label => switch (this) {
        BillingPlan.free => 'Free',
        BillingPlan.solo => 'Solo',
        BillingPlan.soloPro => 'Solo Pro',
        BillingPlan.team => 'Team',
        BillingPlan.business => 'Business',
        BillingPlan.enterprise => 'Enterprise',
      };

  /// Aufsteigende Sortierung, z. B. für „ist mein Plan ≥ X?"-Checks.
  /// Sortiert über beide Kategorien hinweg (Privat-Tiers vor Enterprise-
  /// Tiers, weil Enterprise grundsätzlich mehr Features hat).
  int get rank => switch (this) {
        BillingPlan.free => 0,
        BillingPlan.solo => 1,
        BillingPlan.soloPro => 2,
        BillingPlan.team => 3,
        BillingPlan.business => 4,
        BillingPlan.enterprise => 5,
      };
}

enum BillingCycle {
  monthly,
  yearly;

  static BillingCycle? tryFromString(String? s) => switch (s?.toLowerCase()) {
        'monthly' => monthly,
        'yearly' => yearly,
        _ => null,
      };

  String get apiName => name;
}

/// Rechnungs- & Plan-Profil eines Users (1:1 zur `auth.users`-Zeile).
/// Felder sind bewusst alle nullable, weil Free-User keine Adresse
/// pflegen müssen. Ab `BillingPlan.solo` validiert [requiredFieldsMissing]
/// die Pflichtangaben.
class BillingProfile {
  final String userId;
  final BillingPlan plan;
  final BillingCycle? billingCycle;
  final DateTime? planStartedAt;
  final DateTime? planRenewsAt;
  final String? fullName;
  final String? company;
  final String? vatId;
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final String? city;
  final String? region;
  final String country;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BillingProfile({
    required this.userId,
    required this.plan,
    required this.country,
    required this.createdAt,
    required this.updatedAt,
    this.billingCycle,
    this.planStartedAt,
    this.planRenewsAt,
    this.fullName,
    this.company,
    this.vatId,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.city,
    this.region,
  });

  /// Default-Profil für einen frisch angemeldeten User. Wird genutzt, wenn
  /// die DB-Zeile (warum auch immer) noch nicht existiert.
  factory BillingProfile.defaultFor(String userId) => BillingProfile(
        userId: userId,
        plan: BillingPlan.free,
        country: 'DE',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  factory BillingProfile.fromSupabase(Map<String, dynamic> row) =>
      BillingProfile(
        userId: row['user_id'] as String,
        plan: BillingPlan.fromString(row['plan'] as String? ?? 'free'),
        billingCycle:
            BillingCycle.tryFromString(row['billing_cycle'] as String?),
        planStartedAt: _parseDate(row['plan_started_at']),
        planRenewsAt: _parseDate(row['plan_renews_at']),
        fullName: row['full_name'] as String?,
        company: row['company'] as String?,
        vatId: row['vat_id'] as String?,
        phone: row['phone'] as String?,
        addressLine1: row['address_line1'] as String?,
        addressLine2: row['address_line2'] as String?,
        postalCode: row['postal_code'] as String?,
        city: row['city'] as String?,
        region: row['region'] as String?,
        country: (row['country'] as String?) ?? 'DE',
        createdAt: _parseDate(row['created_at']) ?? DateTime.now().toUtc(),
        updatedAt: _parseDate(row['updated_at']) ?? DateTime.now().toUtc(),
      );

  static DateTime? _parseDate(Object? raw) {
    if (raw is String) return DateTime.parse(raw);
    return null;
  }

  /// Pflichtfelder für kostenpflichtige Pläne. Liefert die Liste der
  /// fehlenden Feldnamen (lokalisierungs-frei) — leer = alles okay.
  List<String> get requiredFieldsMissing {
    final missing = <String>[];
    if ((fullName ?? '').trim().isEmpty) missing.add('fullName');
    if ((addressLine1 ?? '').trim().isEmpty) missing.add('addressLine1');
    if ((postalCode ?? '').trim().isEmpty) missing.add('postalCode');
    if ((city ?? '').trim().isEmpty) missing.add('city');
    if (country.trim().length != 2) missing.add('country');
    if ((phone ?? '').trim().isEmpty) missing.add('phone');
    return missing;
  }

  bool get hasCompleteBillingAddress => requiredFieldsMissing.isEmpty;

  BillingProfile copyWith({
    BillingPlan? plan,
    BillingCycle? billingCycle,
    DateTime? planStartedAt,
    DateTime? planRenewsAt,
    String? fullName,
    String? company,
    String? vatId,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? city,
    String? region,
    String? country,
    DateTime? updatedAt,
  }) =>
      BillingProfile(
        userId: userId,
        plan: plan ?? this.plan,
        billingCycle: billingCycle ?? this.billingCycle,
        planStartedAt: planStartedAt ?? this.planStartedAt,
        planRenewsAt: planRenewsAt ?? this.planRenewsAt,
        fullName: fullName ?? this.fullName,
        company: company ?? this.company,
        vatId: vatId ?? this.vatId,
        phone: phone ?? this.phone,
        addressLine1: addressLine1 ?? this.addressLine1,
        addressLine2: addressLine2 ?? this.addressLine2,
        postalCode: postalCode ?? this.postalCode,
        city: city ?? this.city,
        region: region ?? this.region,
        country: country ?? this.country,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toUpsertPayload() => {
        'user_id': userId,
        'plan': plan.apiName,
        if (billingCycle != null) 'billing_cycle': billingCycle!.apiName,
        if (planStartedAt != null)
          'plan_started_at': planStartedAt!.toIso8601String(),
        if (planRenewsAt != null)
          'plan_renews_at': planRenewsAt!.toIso8601String(),
        'full_name': _emptyToNull(fullName),
        'company': _emptyToNull(company),
        'vat_id': _emptyToNull(vatId),
        'phone': _emptyToNull(phone),
        'address_line1': _emptyToNull(addressLine1),
        'address_line2': _emptyToNull(addressLine2),
        'postal_code': _emptyToNull(postalCode),
        'city': _emptyToNull(city),
        'region': _emptyToNull(region),
        'country': country,
      };

  static String? _emptyToNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
