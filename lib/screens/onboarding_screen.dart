import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/deal.dart';
import '../models/shop.dart';
import '../models/supplier.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/deals_provider.dart';
import '../providers/purchasing_provider.dart';
import '../providers/onboarding_provider.dart';
import '../utils/responsive.dart';
import '../widgets/app_feedback.dart';

/// First-time-user-Flow als Phone-First-PageView. 6 Steps:
///   1. Willkommen
///   2. Workspace (Info — Personal-Workspace existiert bereits)
///   3. Shops (Multi-Select aus Liste)
///   4. Lieferanten (optional, freitext)
///   5. Erstes Ticket (Mini-Form, kann skippen)
///   6. Outro: Postfach + Discord (Hinweis auf Settings)
///
/// Layout-Constraints:
///   * Phone: full-width PageView mit Indicator-Dots oben.
///   * Tablet/Desktop: maxWidth 480, vertikal zentriert.
///   * Skip-Button immer rechts oben sichtbar.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _stepCount = 6;
  static const _uuid = Uuid();

  static const List<String> _shopOptions = [
    'Amazon',
    'MediaMarkt',
    'Saturn',
    'Otto',
    'Galeria',
    'eBay',
    'Tink',
    'Anker',
    'Euronics',
    'LEGO',
  ];

  final PageController _pageController = PageController();
  int _index = 0;
  final _supplierCtrl = TextEditingController();
  final _firstProductCtrl = TextEditingController();
  final _firstQuantityCtrl = TextEditingController(text: '1');
  String? _firstShop;

  @override
  void dispose() {
    _pageController.dispose();
    _supplierCtrl.dispose();
    _firstProductCtrl.dispose();
    _firstQuantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index >= _stepCount - 1) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_index == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    final activeWs = context.read<ActiveWorkspaceProvider>();
    final ob = context.read<OnboardingProvider>();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final wsId = activeWs.active?.id;
    if (wsId == null) {
      AppFeedback.errorOn(
        messenger,
        l10n.onboardingErrorNoWorkspace,
        rootContext: context,
      );
      return;
    }
    final ok = await ob.skipOnboarding(activeWs: activeWs, workspaceId: wsId);
    if (!mounted) return;
    if (!ok) {
      AppFeedback.errorOn(
        messenger,
        l10n.onboardingErrorGeneric(ob.lastError ?? ''),
        rootContext: context,
      );
    }
  }

  Future<void> _finish() async {
    final inv = context.read<DealsProvider>();
    // Suppliers now live in PurchasingProvider; shops/deals stay on Inventory.
    final purchasing = context.read<PurchasingProvider>();
    final activeWs = context.read<ActiveWorkspaceProvider>();
    final ob = context.read<OnboardingProvider>();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final wsId = activeWs.active?.id;
    if (wsId == null) {
      AppFeedback.errorOn(
        messenger,
        l10n.onboardingErrorNoWorkspace,
        rootContext: context,
      );
      return;
    }
    // Optional: ersten Deal aus Step 5 in den Provider übernehmen.
    if (_firstProductCtrl.text.trim().isNotEmpty &&
        (_firstShop ?? '').isNotEmpty) {
      ob.setFirstTicket(
        product: _firstProductCtrl.text.trim(),
        quantity: int.tryParse(_firstQuantityCtrl.text) ?? 1,
        shop: _firstShop!,
      );
    }

    final ok = await ob.completeOnboarding(
      activeWs: activeWs,
      workspaceId: wsId,
      onAddShop: (name) async {
        if (inv.shops.any((s) =>
            s.name.toLowerCase() == name.toLowerCase())) {
          return;
        }
        await inv.addShop(Shop(
          id: _uuid.v4(),
          name: name,
          region: 'DE',
          channel: '',
          active: true,
        ));
      },
      onAddSupplier: (name) async {
        if (purchasing.suppliers.any((s) =>
            s.name.toLowerCase() == name.toLowerCase())) {
          return;
        }
        await purchasing.addSupplier(Supplier(
          id: _uuid.v4(),
          name: name,
          contactName: 'Onboarding',
          active: true,
        ));
      },
      onAddFirstDeal: (product, quantity, shop) async {
        await inv.addDeal(Deal(
          id: 0,
          product: product,
          quantity: quantity,
          isDropship: false,
          shop: shop,
          orderDate: DateTime.now(),
          status: 'Bestellt',
        ));
      },
    );
    if (!mounted) return;
    if (!ok) {
      AppFeedback.errorOn(
        messenger,
        l10n.onboardingErrorGeneric(ob.lastError ?? ''),
        rootContext: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Auf Tablet/Desktop maximal 480px, sonst voll. PageView braucht
            // bounded-width — ohne Constraint wirkt der Carousel "zerflosen".
            final isWide = constraints.maxWidth >= Breakpoints.phone;
            final content = _OnboardingBody(
              pageController: _pageController,
              index: _index,
              stepCount: _stepCount,
              onPageChanged: (i) => setState(() => _index = i),
              onNext: _next,
              onBack: _back,
              onSkip: _skip,
              children: _buildSteps(context),
            );
            if (isWide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: content,
                ),
              );
            }
            return content;
          },
        ),
      ),
    );
  }

  List<Widget> _buildSteps(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _StepWelcome(title: l10n.onboardingStepWelcomeTitle, subtitle: l10n.onboardingStepWelcomeSubtitle),
      _StepWorkspace(
        title: l10n.onboardingStepWorkspaceTitle,
        subtitle: l10n.onboardingStepWorkspaceSubtitle,
      ),
      _StepShops(
        title: l10n.onboardingStepShopsTitle,
        subtitle: l10n.onboardingStepShopsSubtitle,
        options: _shopOptions,
      ),
      _StepSuppliers(
        title: l10n.onboardingStepSuppliersTitle,
        subtitle: l10n.onboardingStepSuppliersSubtitle,
        controller: _supplierCtrl,
        hint: l10n.onboardingSuppliersHint,
        addLabel: l10n.onboardingSuppliersAdd,
      ),
      _StepFirstTicket(
        title: l10n.onboardingStepFirstTicketTitle,
        subtitle: l10n.onboardingStepFirstTicketSubtitle,
        productCtrl: _firstProductCtrl,
        quantityCtrl: _firstQuantityCtrl,
        productHint: l10n.onboardingFirstTicketProductHint,
        quantityLabel: l10n.onboardingFirstTicketQuantity,
        shopLabel: l10n.onboardingFirstTicketShop,
        shopOptions: _shopOptions,
        selectedShop: _firstShop,
        onShopChanged: (s) => setState(() => _firstShop = s),
      ),
      _StepOutro(
        title: l10n.onboardingStepOutroTitle,
        subtitle: l10n.onboardingStepOutroSubtitle,
        bullets: [
          l10n.onboardingOutroDiscord,
          l10n.onboardingOutroInbox,
          l10n.onboardingOutroDemo,
        ],
      ),
    ];
  }
}

// ─── Body / Layout ──────────────────────────────────────────────────────────

class _OnboardingBody extends StatelessWidget {
  final PageController pageController;
  final int index;
  final int stepCount;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onNext;
  final Future<void> Function() onBack;
  final Future<void> Function() onSkip;
  final List<Widget> children;
  const _OnboardingBody({
    required this.pageController,
    required this.index,
    required this.stepCount,
    required this.onPageChanged,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ob = context.watch<OnboardingProvider>();
    final isLast = index == stepCount - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top bar: Back + Skip ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
          child: Row(
            children: [
              // Back button — 48×48 touch target
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: l10n.onboardingBack,
                  onPressed: index == 0 ? null : onBack,
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                ),
              ),
              const Spacer(),
              // Skip — secondary TextButton, min 48dp height via padding
              TextButton(
                onPressed: ob.busy ? null : onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(l10n.onboardingSkip),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Progress indicator + step label ──────────────────────────────
        _StepProgressBar(
          stepCount: stepCount,
          currentIndex: index,
        ),
        const SizedBox(height: 8),
        // ── PageView (slides per swipe / button) ─────────────────────────
        Expanded(
          child: PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            children: children,
          ),
        ),
        // ── Primary action button ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: ob.busy ? null : onNext,
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: ob.busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context)
                            .elevatedButtonTheme
                            .style
                            ?.foregroundColor
                            ?.resolve({}) ??
                            AppTheme.bgSurfaceOf(context),
                      ),
                    )
                  : Text(isLast ? l10n.onboardingFinish : l10n.onboardingNext),
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated LinearProgressIndicator + step label replacing the dot-row.
///
/// The progress value animates smoothly via [TweenAnimationBuilder] whenever
/// [currentIndex] changes. The step label ("Schritt X von Y") sits right-
/// aligned next to the bar so the user always knows how many steps remain.
class _StepProgressBar extends StatelessWidget {
  final int stepCount;
  final int currentIndex;
  const _StepProgressBar({
    required this.stepCount,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Progress goes from 1/N (first step shown) to N/N (last step).
    final targetValue = (currentIndex + 1) / stepCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step label — right-aligned, muted text
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              l10n.onboardingStepLabel(currentIndex + 1, stepCount),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: targetValue),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppTheme.borderOf(context),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.accent),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepFrame extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _StepFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  State<_StepFrame> createState() => _StepFrameState();
}

class _StepFrameState extends State<_StepFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(height: 24),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: Welcome ────────────────────────────────────────────────────────

class _StepWelcome extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepWelcome({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: title,
      subtitle: subtitle,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, t, child) =>
              Transform.scale(scale: t, child: child),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.accentLightOf(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accentBorderOf(context),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppTheme.accent,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 2: Workspace ──────────────────────────────────────────────────────

class _StepWorkspace extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepWorkspace({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ws = context.watch<ActiveWorkspaceProvider>().active;
    return _StepFrame(
      title: title,
      subtitle: subtitle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgSurfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentLightOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.workspaces_outlined,
                  color: AppTheme.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ws?.name ?? l10n.onboardingWorkspaceFallback,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.onboardingWorkspaceReady,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMutedOf(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 3: Shops ──────────────────────────────────────────────────────────

class _StepShops extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  const _StepShops({
    required this.title,
    required this.subtitle,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final ob = context.watch<OnboardingProvider>();
    return _StepFrame(
      title: title,
      subtitle: subtitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((shop) {
          final selected = ob.selectedShops.contains(shop);
          return FilterChip(
            label: Text(shop),
            selected: selected,
            onSelected: (_) => context.read<OnboardingProvider>().toggleShop(shop),
            // Mind. 48 dp Touch-Target — Material erzwingt das nur in
            // VisualDensity.standard, hier explizit auf >=44 gehalten.
            materialTapTargetSize: MaterialTapTargetSize.padded,
          );
        }).toList(),
      ),
    );
  }
}

// ─── Step 4: Suppliers ──────────────────────────────────────────────────────

class _StepSuppliers extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final String hint;
  final String addLabel;
  const _StepSuppliers({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.hint,
    required this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ob = context.watch<OnboardingProvider>();
    return _StepFrame(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(context),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: Text(addLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ob.suppliers
                .map((s) => InputChip(
                      label: Text(s),
                      onDeleted: () =>
                          context.read<OnboardingProvider>().removeSupplier(s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _add(BuildContext context) {
    final v = controller.text.trim();
    if (v.isEmpty) return;
    context.read<OnboardingProvider>().addSupplier(v);
    controller.clear();
  }
}

// ─── Step 5: First Ticket ───────────────────────────────────────────────────

class _StepFirstTicket extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController productCtrl;
  final TextEditingController quantityCtrl;
  final String productHint;
  final String quantityLabel;
  final String shopLabel;
  final List<String> shopOptions;
  final String? selectedShop;
  final ValueChanged<String?> onShopChanged;
  const _StepFirstTicket({
    required this.title,
    required this.subtitle,
    required this.productCtrl,
    required this.quantityCtrl,
    required this.productHint,
    required this.quantityLabel,
    required this.shopLabel,
    required this.shopOptions,
    required this.selectedShop,
    required this.onShopChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: productCtrl,
            decoration: InputDecoration(
              hintText: productHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: quantityLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedShop,
                  decoration: InputDecoration(
                    labelText: shopLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: shopOptions
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: onShopChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Step 6: Outro ──────────────────────────────────────────────────────────

class _StepOutro extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> bullets;
  const _StepOutro({
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: bullets
            .map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outlined,
                          color: AppTheme.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(b,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

