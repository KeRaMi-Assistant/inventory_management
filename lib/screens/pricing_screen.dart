import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../models/pricing_plan.dart';
import '../providers/billing_provider.dart';
import 'billing_profile_screen.dart';

/// Pricing-/Plan-Übersicht. Aktuell rein „Dummy" — keine Anbindung an
/// Stripe/Paddle, sondern nur clientseitiger Plan-Switch via [BillingProvider].
/// Bei Upgrade auf einen kostenpflichtigen Plan wird zuerst die
/// Rechnungsadresse abgefragt, damit ab dem ersten Cent zahlende Kunden
/// vollständige Stammdaten hinterlegt haben.
///
/// Layout: zwei Sektionen — „Privat" (B2C, brutto-Preise inkl. MwSt)
/// und „Enterprise" (B2B, netto-Preise zzgl. MwSt). Jeder Tier zeigt
/// den passenden VAT-Hinweis im Preis-Block.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  BillingCycle _cycle = BillingCycle.monthly;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    final billing = context.read<BillingProvider>();
    if (billing.profile == null && !billing.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => billing.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingProvider>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final personalTiers = PricingPlan.forCategory(PricingCategory.personal);
    final enterpriseTiers = PricingPlan.forCategory(PricingCategory.enterprise);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pricingTitle),
      ),
      body: billing.isLoading && billing.profile == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: billing.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    l10n.pricingHeadline,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.pricingIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BillingCycleToggle(
                    cycle: _cycle,
                    onChanged: (c) => setState(() => _cycle = c),
                  ),
                  const SizedBox(height: 28),

                  // ── Privat-Kategorie ────────────────────────────────
                  _CategoryHeader(
                    label: l10n.pricingCategoryPersonal,
                    subtitle: l10n.pricingCategoryPersonalHint,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  for (final plan in personalTiers) ...[
                    _PlanCard(
                      plan: plan,
                      cycle: _cycle,
                      isCurrent: plan.plan == billing.currentPlan,
                      busy: _activating,
                      onSelect: () => _onSelect(plan),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 16),

                  // ── Enterprise-Kategorie ────────────────────────────
                  _CategoryHeader(
                    label: l10n.pricingCategoryEnterprise,
                    subtitle: l10n.pricingCategoryEnterpriseHint,
                    icon: Icons.business_rounded,
                  ),
                  const SizedBox(height: 12),
                  for (final plan in enterpriseTiers) ...[
                    _PlanCard(
                      plan: plan,
                      cycle: _cycle,
                      isCurrent: plan.plan == billing.currentPlan,
                      busy: _activating,
                      onSelect: () => _onSelect(plan),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),
                  const _LegalFootnote(),
                ],
              ),
            ),
    );
  }

  Future<void> _onSelect(PricingPlan plan) async {
    final billing = context.read<BillingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (plan.plan == billing.currentPlan) return;

    // Free: kein Billing-Setup nötig. Direkt umschalten.
    if (plan.plan == BillingPlan.free) {
      await _confirmAndActivate(plan, billing, messenger);
      return;
    }

    // Paid Plan: Rechnungsadresse muss vollständig sein.
    var profile = billing.profile;
    if (profile == null) {
      await billing.load();
      profile = billing.profile;
    }

    if (profile == null || !profile.hasCompleteBillingAddress) {
      final result = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => const BillingProfileScreen(
            requireCompleteForPaidPlan: true,
          ),
        ),
      );
      if (result != true || !mounted) return;
      profile = context.read<BillingProvider>().profile;
      if (profile == null || !profile.hasCompleteBillingAddress) return;
    }

    await _confirmAndActivate(plan, billing, messenger);
  }

  Future<void> _confirmAndActivate(
    PricingPlan plan,
    BillingProvider billing,
    ScaffoldMessengerState messenger,
  ) async {
    final isDowngradeToFree = plan.plan == BillingPlan.free;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(isDowngradeToFree
              ? 'Auf Free wechseln?'
              : 'Auf ${plan.plan.label} upgraden?'),
          content: Text(
            isDowngradeToFree
                ? 'Du verlierst Zugang zu Pro-Features. Bestehende Daten bleiben erhalten.'
                : 'Hinweis: Dies ist ein Demo-Switch ohne Zahlungsabwicklung. '
                    'Sobald Stripe/Paddle integriert ist, läuft hier der echte Checkout.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isDowngradeToFree ? 'Wechseln' : 'Plan aktivieren'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _activating = true);
    try {
      await billing.activatePlan(
        plan: plan.plan,
        cycle: plan.plan == BillingPlan.free ? null : _cycle,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Plan ${plan.plan.label} aktiviert.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Aktivierung fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }
}

class _CategoryHeader extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  const _CategoryHeader({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentLightOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.accentTextOf(context)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillingCycleToggle extends StatelessWidget {
  final BillingCycle cycle;
  final ValueChanged<BillingCycle> onChanged;
  const _BillingCycleToggle({required this.cycle, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              selected: cycle == BillingCycle.monthly,
              label: 'Monatlich',
              onTap: () => onChanged(BillingCycle.monthly),
            ),
          ),
          Expanded(
            child: _ToggleChip(
              selected: cycle == BillingCycle.yearly,
              label: 'Jährlich · –17%',
              onTap: () => onChanged(BillingCycle.yearly),
              accent: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  const _ToggleChip({
    required this.selected,
    required this.label,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.bgSurfaceOf(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: selected
                ? (accent ?? AppTheme.textPrimaryOf(context))
                : AppTheme.textMutedOf(context),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PricingPlan plan;
  final BillingCycle cycle;
  final bool isCurrent;
  final bool busy;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.isCurrent,
    required this.busy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = theme.colorScheme.primary;
    final price = cycle == BillingCycle.yearly
        ? plan.yearlyPriceEur
        : plan.monthlyPriceEur;
    final priceLabel = plan.isFree
        ? '0 €'
        : cycle == BillingCycle.yearly
            ? '${_fmtEur(price)} / Jahr'
            : '${_fmtEur(price)} / Monat';

    // VAT-Hinweis je nach Kategorie. Free hat keinen Hinweis.
    final vatHint = plan.isFree
        ? null
        : plan.vatIncluded
            ? l10n.pricingVatIncluded   // „inkl. MwSt"
            : l10n.pricingVatExcluded;  // „zzgl. MwSt"

    // Brutto-Anzeige als Hilfsinformation für Enterprise-Tiers,
    // damit der User direkt sieht, was effektiv auf der Rechnung steht.
    final showGrossHint = !plan.isFree && !plan.vatIncluded;
    final grossPrice = cycle == BillingCycle.yearly
        ? plan.yearlyPriceGross
        : plan.monthlyPriceGross;
    final grossLabel = showGrossHint
        ? '≈ ${_fmtEur(grossPrice)} brutto'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.mostPopular
              ? accent.withAlpha(120)
              : AppTheme.borderOf(context),
          width: plan.mostPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  plan.plan.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 10),
                if (plan.mostPopular)
                  _Pill(
                    text: 'Most Popular',
                    bg: accent.withAlpha(30),
                    fg: accent,
                  ),
                if (isCurrent) ...[
                  if (plan.mostPopular) const SizedBox(width: 6),
                  _Pill(
                    text: 'Aktueller Plan',
                    bg: AppTheme.bgSubtleOf(context),
                    fg: AppTheme.textSecondaryOf(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.tagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMutedOf(context),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceLabel,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (vatHint != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      vatHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMutedOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (grossLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  grossLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              ),
            if (cycle == BillingCycle.yearly && !plan.isFree)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '≈ ${_fmtEur(price / 12)} / Monat',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isCurrent || busy) ? null : onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: plan.mostPopular ? accent : null,
                  foregroundColor: plan.mostPopular ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_buttonLabel(plan, isCurrent)),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            for (final h in plan.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buttonLabel(PricingPlan plan, bool isCurrent) {
    if (isCurrent) return 'Aktiver Plan';
    if (plan.isFree) return 'Auf Free wechseln';
    return 'Plan auswählen';
  }

  static String _fmtEur(double v) {
    if (v == v.roundToDouble()) return '${v.toStringAsFixed(0)} €';
    return '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _LegalFootnote extends StatelessWidget {
  const _LegalFootnote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.pricingLegalFootnote,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMutedOf(context),
          ),
    );
  }
}
