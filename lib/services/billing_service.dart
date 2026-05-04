import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/billing_profile.dart';

/// Dünner Wrapper um die `billing_profiles`-Tabelle. Bewusst getrennt vom
/// monolithischen `SupabaseRepository`, weil das Billing-Modell quer zu
/// allen Daten-Tabellen liegt (User-Quotas, Plan-Gating).
class BillingService {
  BillingService(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('BillingService requires an authenticated user.');
    }
    return id;
  }

  /// Lädt das Billing-Profil des aktuellen Users. Gibt ein Default-Profil
  /// zurück, falls (theoretisch nie, aber defensiv) keine Zeile existiert.
  Future<BillingProfile> loadCurrent() async {
    final uid = _userId;
    final row = await _client
        .from('billing_profiles')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) {
      return BillingProfile.defaultFor(uid);
    }
    return BillingProfile.fromSupabase(row);
  }

  /// Schreibt das vollständige Profil (Upsert auf user_id). Liefert die
  /// frische Server-Zeile zurück (mit aktualisiertem updated_at).
  Future<BillingProfile> upsert(BillingProfile profile) async {
    final payload = profile.toUpsertPayload();
    final row = await _client
        .from('billing_profiles')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single();
    return BillingProfile.fromSupabase(row);
  }

  /// Setzt nur den Plan (z.B. nach erfolgreichem Upgrade-Flow). Hält die
  /// Adress-Felder unangetastet.
  Future<BillingProfile> setPlan({
    required BillingPlan plan,
    BillingCycle? cycle,
  }) async {
    final uid = _userId;
    final now = DateTime.now().toUtc();
    final patch = <String, dynamic>{
      'plan': plan.apiName,
      'billing_cycle': plan.isPaid ? (cycle?.apiName ?? 'monthly') : null,
      'plan_started_at': plan.isPaid ? now.toIso8601String() : null,
      'plan_renews_at': plan.isPaid
          ? _renewalDate(now, cycle ?? BillingCycle.monthly).toIso8601String()
          : null,
    };
    final row = await _client
        .from('billing_profiles')
        .update(patch)
        .eq('user_id', uid)
        .select()
        .single();
    return BillingProfile.fromSupabase(row);
  }

  static DateTime _renewalDate(DateTime from, BillingCycle cycle) =>
      switch (cycle) {
        BillingCycle.monthly =>
          DateTime.utc(from.year, from.month + 1, from.day),
        BillingCycle.yearly =>
          DateTime.utc(from.year + 1, from.month, from.day),
      };
}
