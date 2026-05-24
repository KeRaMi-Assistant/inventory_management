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
/// Layout: TabBar mit zwei Kategorien — **links Privat** (B2C, brutto-Preise
/// inkl. MwSt) und **rechts Enterprise** (B2B, netto-Preise zzgl. MwSt).
/// Free liegt im Privat-Tab.
///
/// Yearly-Toggle: der Preis-Block zeigt im Yearly-Modus den effektiven
/// Monatspreis groß (psychologisch günstiger) und den tatsächlichen
/// Jahres-Total klein ausgegraut darunter („49,90 € jährlich abgerechnet").
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen>
    with SingleTickerProviderStateMixin {
  BillingCycle _cycle = BillingCycle.monthly;
  bool _activating = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final billing = context.read<BillingProvider>();
    if (billing.profile == null && !billing.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => billing.load());
    }
    // Wenn der User aktuell auf einem Enterprise-Tier ist, direkt
    // den Enterprise-Tab vorauswählen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentPlan = context.read<BillingProvider>().currentPlan;
      final isEnterprise = PricingPlan.forBillingPlan(currentPlan).category ==
          PricingCategory.enterprise;
      if (isEnterprise) _tabController.index = 1;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                  const SizedBox(height: 16),

                  // ── Kategorie-Tabs ─────────────────────────────────
                  _CategoryTabs(controller: _tabController),
                  const SizedBox(height: 8),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        final isPersonal = _tabController.index == 0;
                        final tiers =
                            isPersonal ? personalTiers : enterpriseTiers;
                        return Column(
                          key: ValueKey(
                              'pricing-tab-${isPersonal ? "personal" : "enterprise"}'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            _CategoryHint(isPersonal: isPersonal),
                            const SizedBox(height: 14),
                            for (final plan in tiers) ...[
                              _PlanCard(
                                plan: plan,
                                cycle: _cycle,
                                isCurrent: plan.plan == billing.currentPlan,
                                busy: _activating,
                                onSelect: () => _onSelect(plan),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
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
    final l10nOuter = AppLocalizations.of(context);
    final isDowngradeToFree = plan.plan == BillingPlan.free;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(isDowngradeToFree
              ? l10n.pricingDowngradeToFreeTitle
              : l10n.pricingUpgradeToTitle(plan.plan.label)),
          content: Text(
            isDowngradeToFree
                ? l10n.pricingDowngradeLoseAccess
                : l10n.pricingDemoCheckoutNotice,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isDowngradeToFree
                  ? l10n.pricingDoSwitch
                  : l10n.pricingActivatePlan),
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
        SnackBar(
          content: Text(l10nOuter.pricingPlanActivated(plan.plan.label)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10nOuter.pricingActivationFailed)),
      );
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }
}

/// TabBar im „Pill-Toggle"-Look (statt Material-Default-Underline).
/// Material-Underline würde mit dem Cycle-Toggle darüber visuell kollidieren —
/// die Pill-Form macht klar: das hier ist ein primärer Filter.
class _CategoryTabs extends StatelessWidget {
  final TabController controller;
  const _CategoryTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: AppTheme.bgSurfaceOf(context),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.textPrimaryOf(context),
        unselectedLabelColor: AppTheme.textMutedOf(context),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        splashFactory: NoSplash.splashFactory,
        overlayColor:
            WidgetStateProperty.all<Color>(Colors.transparent),
        tabs: [
          Tab(
            height: 44,
            iconMargin: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Text(l10n.pricingCategoryPersonal),
              ],
            ),
          ),
          Tab(
            height: 44,
            iconMargin: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business_rounded, size: 18),
                const SizedBox(width: 8),
                Text(l10n.pricingCategoryEnterprise),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kleiner Subtitle unter dem aktiven Tab. Erklärt VAT-Handling der
/// jeweiligen Kategorie ohne Section-Header-Wiederholung.
class _CategoryHint extends StatelessWidget {
  final bool isPersonal;
  const _CategoryHint({required this.isPersonal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = isPersonal
        ? l10n.pricingCategoryPersonalHint
        : l10n.pricingCategoryEnterpriseHint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMutedOf(context),
            ),
      ),
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
              label: AppLocalizations.of(context).pricingCycleMonthly,
              onTap: () => onChanged(BillingCycle.monthly),
            ),
          ),
          Expanded(
            child: _ToggleChip(
              selected: cycle == BillingCycle.yearly,
              label: AppLocalizations.of(context).pricingCycleYearly,
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
    final isYearly = cycle == BillingCycle.yearly;

    // Haupt-Preis: bei Yearly zeigen wir den **effektiven Monatspreis**
    // (psychologisch günstiger), bei Monthly den Monatspreis direkt.
    // Free: konstant „0 €".
    final String primaryPriceLabel;
    if (plan.isFree) {
      primaryPriceLabel = '0 €';
    } else if (isYearly) {
      final effectiveMonthly = plan.yearlyPriceEur / 12;
      primaryPriceLabel = '${_fmtEur(effectiveMonthly)} / Monat';
    } else {
      primaryPriceLabel = '${_fmtEur(plan.monthlyPriceEur)} / Monat';
    }

    // VAT-Hinweis je nach Kategorie. Free hat keinen Hinweis.
    final vatHint = plan.isFree
        ? null
        : plan.vatIncluded
            ? l10n.pricingVatIncluded   // „inkl. MwSt"
            : l10n.pricingVatExcluded;  // „zzgl. MwSt"

    // Yearly-Subtitle: Jahres-Total klein ausgegraut darunter.
    final String? yearlyTotalLabel = (!plan.isFree && isYearly)
        ? l10n.pricingYearlyBilled(_fmtEur(plan.yearlyPriceEur))
        : null;

    // Brutto-Anzeige als Hilfsinformation für Enterprise-Tiers,
    // damit der User direkt sieht, was effektiv auf der Rechnung steht.
    // Bei Yearly auf den effektiven Monatspreis brutto umgerechnet.
    final showGrossHint = !plan.isFree && !plan.vatIncluded;
    final String? grossHintLabel;
    if (showGrossHint) {
      if (isYearly) {
        final effectiveMonthlyGross = plan.yearlyPriceGross / 12;
        grossHintLabel =
            '≈ ${_fmtEur(effectiveMonthlyGross)} / Monat brutto';
      } else {
        grossHintLabel =
            '≈ ${_fmtEur(plan.monthlyPriceGross)} / Monat brutto';
      }
    } else {
      grossHintLabel = null;
    }

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
                  primaryPriceLabel,
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
            // Yearly-Subtitle: Jahres-Total klein + ausgegraut.
            if (yearlyTotalLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  yearlyTotalLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textDisabledOf(context),
                  ),
                ),
              ),
            if (grossHintLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  grossHintLabel,
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
                child: Text(_buttonLabel(l10n, plan, isCurrent)),
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

  String _buttonLabel(
      AppLocalizations l10n, PricingPlan plan, bool isCurrent) {
    if (isCurrent) return l10n.pricingActivePlan;
    if (plan.isFree) return l10n.pricingSwitchToFree;
    return l10n.pricingSelectPlan;
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
