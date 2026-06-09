import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/subscription_tier_config.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PaywallScreen
//
// Full-screen Pro upgrade paywall.  Renders three tiers:
//
//   • Lifetime Local — one-time IAP, no cloud, no sync
//   • Pro Cloud Annual — subscription, default selection
//   • Pro Cloud Monthly — subscription
//
// Reads live offerings from RevenueCat and falls back to hardcoded
// price strings while loading or when offline.  When [LifetimeLaunchPromo]
// is active the Lifetime card shows the promo badge + crossed-out
// regular price; the actual discount is enforced by RevenueCat /
// App Store introductory pricing, not client-side.
//
// Usage:
//   await PaywallScreen.show(context);
// ─────────────────────────────────────────────────────────────────────────────

class PaywallScreen extends StatefulWidget {
  /// Optional callback fired after a successful purchase.
  final VoidCallback? onUpgraded;

  const PaywallScreen({super.key, this.onUpgraded});

  /// Convenience — push the paywall as a full-screen modal route.
  static Future<bool> show(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PaywallScreen(),
      ),
    );
    return result ?? false;
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

// One slot per tier the user can purchase from this screen.  We track
// the *selected* slot so the bottom CTA can show the right copy & price.
enum _PricingOption { lifetime, annual, monthly }

class _PaywallScreenState extends State<PaywallScreen> {
  // Annual is the highlighted default — best LTV-friendly price point
  // and the option growers comparing apps usually expect to see first.
  _PricingOption _selected = _PricingOption.annual;

  bool _loadingOfferings = false;
  Package? _monthlyPkg;
  Package? _annualPkg;
  Package? _lifetimePkg;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    if (!mounted) return;
    setState(() => _loadingOfferings = true);
    final svc = context.read<SubscriptionService>();
    final offerings = await svc.fetchOfferings();
    if (!mounted) return;
    setState(() {
      _monthlyPkg  = offerings?.current?.monthly;
      _annualPkg   = offerings?.current?.annual;
      _lifetimePkg = svc.lifetimePackage;
      _loadingOfferings = false;
    });
  }

  Package? _packageForSelected() {
    switch (_selected) {
      case _PricingOption.lifetime: return _lifetimePkg;
      case _PricingOption.annual:   return _annualPkg;
      case _PricingOption.monthly:  return _monthlyPkg;
    }
  }

  Future<void> _purchase() async {
    final svc = context.read<SubscriptionService>();
    final pkg = _packageForSelected();
    if (pkg == null) return;

    final ok = await svc.purchasePackage(pkg);
    if (!mounted) return;

    if (ok) {
      widget.onUpgraded?.call();
      final tier = svc.tier;
      final message = tier == SubscriptionTier.lifetimeLocal
          ? 'Lifetime Local activated — enjoy!'
          : 'Welcome to Kultivar Pro!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.black, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(message),
            ],
          ),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } else {
      final err = svc.lastError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restore() async {
    final svc = context.read<SubscriptionService>();
    final ok = await svc.restorePurchases();
    if (!mounted) return;

    if (ok) {
      widget.onUpgraded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase restored successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(svc.lastError ?? 'No previous purchase found.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SubscriptionService>();

    // Already on a paid tier — show a thank-you state instead of the
    // purchase UI.  We show the *tier-aware* variant so a Lifetime
    // Local user doesn't see Pro Cloud copy.
    if (svc.tier != SubscriptionTier.free) {
      return _AlreadyPurchasedScreen(tier: svc.tier);
    }

    // Pricing strings — prefer the live RevenueCat price strings (which
    // include the user's locale + currency), fall back to USD defaults.
    final monthlyPrice  = _monthlyPkg?.storeProduct.priceString  ?? '\$4.99';
    final annualPrice   = _annualPkg?.storeProduct.priceString   ?? '\$29.99';
    final lifetimePrice = _lifetimePkg?.storeProduct.priceString ?? '\$49.99';

    // Derive per-month price for annual (for display only).
    String annualPerMonth = '\$2.50';
    try {
      if (_annualPkg != null) {
        final raw = _annualPkg!.storeProduct.price / 12;
        final symbol = _annualPkg!.storeProduct.currencyCode == 'USD' ? '\$' : '';
        annualPerMonth = '$symbol${raw.toStringAsFixed(2)}';
      }
    } catch (_) {}

    final promoActive = LifetimeLaunchPromo.isActive;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── App bar (close button + debug shortcut) ────────────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              color: AppColors.textSecondary,
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context, false),
            ),
            actions: [
              if (kIsDebug)
                TextButton(
                  // Capture navigator before async gap to satisfy lint.
                  onPressed: () {
                    final nav = Navigator.of(context);
                    context
                        .read<SubscriptionService>()
                        .debugCycleTier()
                        .then((_) {
                      if (mounted) nav.pop(true);
                    });
                  },
                  child: const Text('DEV: Cycle Tier',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: Column(
                children: [
                  // ── Hero ───────────────────────────────────────────
                  _ProHero(),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Feature comparison ─────────────────────────────
                  const _FeatureTable(),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Pricing cards ──────────────────────────────────
                  Text(
                    'Choose your plan',
                    style: AppTypography.labelLarge(context).copyWith(
                      color: context.colTextSecondary,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (_loadingOfferings)
                    const SizedBox(
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else ...[
                    // Lifetime card
                    _PricingCard(
                      option: _PricingOption.lifetime,
                      selected: _selected == _PricingOption.lifetime,
                      headline: 'Lifetime Local',
                      price: promoActive
                          ? LifetimeLaunchPromo.promoPrice
                          : lifetimePrice,
                      strikethroughPrice:
                          promoActive ? lifetimePrice : null,
                      subline: promoActive
                          ? 'One-time purchase · launch special'
                          : 'One-time purchase · no cloud or sync',
                      badge: promoActive ? 'LAUNCH SPECIAL' : null,
                      footnote:
                          'Unlimited plants & spaces. All local features. No community '
                          'percentile data, no cross-device sync.',
                      onTap: () => setState(
                          () => _selected = _PricingOption.lifetime),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Annual card
                    _PricingCard(
                      option: _PricingOption.annual,
                      selected: _selected == _PricingOption.annual,
                      headline: 'Pro Cloud — Annual',
                      price: annualPrice,
                      subline: '$annualPerMonth / month, billed annually',
                      badge: 'BEST VALUE — SAVE 50%',
                      onTap: () => setState(
                          () => _selected = _PricingOption.annual),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Monthly card
                    _PricingCard(
                      option: _PricingOption.monthly,
                      selected: _selected == _PricingOption.monthly,
                      headline: 'Pro Cloud — Monthly',
                      price: monthlyPrice,
                      subline: 'per month, cancel anytime',
                      onTap: () => setState(
                          () => _selected = _PricingOption.monthly),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // ── Purchase CTA ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: _PurchaseButton(
                      loading: svc.isPurchasing,
                      canPurchase: _packageForSelected() != null,
                      label: _ctaLabelFor(_selected),
                      onTap: svc.isPurchasing ? null : _purchase,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Restore ────────────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: svc.isPurchasing ? null : _restore,
                      child: Text(
                        'Restore purchases',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: context.colTextMuted,
                          decoration: TextDecoration.underline,
                          decorationColor: context.colTextMuted,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── Legal fine print ───────────────────────────────
                  Text(
                    'Pro Cloud subscriptions auto-renew unless cancelled at '
                    'least 24 hours before the end of the current period. '
                    'Manage or cancel in your device\'s App Store / Play Store '
                    'settings. Lifetime Local is a single payment with no '
                    'recurring charges.',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: context.colTextMuted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ctaLabelFor(_PricingOption opt) {
    switch (opt) {
      case _PricingOption.lifetime: return 'Buy Lifetime Local';
      case _PricingOption.annual:   return 'Subscribe Annually';
      case _PricingOption.monthly:  return 'Subscribe Monthly';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header
// ─────────────────────────────────────────────────────────────────────────────

class _ProHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Crown icon with amber glow
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradientAmber,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                blurRadius: 36,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.workspace_premium_rounded,
                color: Colors.black, size: 44),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Unlock Kultivar',
          style: AppTypography.displayMedium(context).copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Three ways to grow without limits.\nPick what fits how you grow.',
          style: AppTypography.bodyMedium(context).copyWith(
            color: context.colTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature comparison table — three columns: Free | Lifetime | Pro Cloud
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureTable extends StatelessWidget {
  const _FeatureTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          const _TableHeader(),
          const Divider(height: 1, color: AppColors.border),
          // Feature rows
          ..._kFeatures.map((f) => _FeatureRow(feature: f)),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'Free',
                style: AppTypography.labelLarge(context).copyWith(
                  color: context.colTextMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'Lifetime',
                style: AppTypography.labelLarge(context).copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Pro Cloud',
                  style: AppTypography.labelLarge(context).copyWith(
                    color: AppColors.accent,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 10),
          child: Row(
            children: [
              Icon(feature.icon, size: 15, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 5,
                child: Text(
                  feature.label,
                  style: AppTypography.bodySmall(context)
                      .copyWith(fontSize: 12.5),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                    child:
                        _Cell(value: feature.free, accent: AppColors.primary)),
              ),
              Expanded(
                flex: 2,
                child: Center(
                    child: _Cell(
                        value: feature.lifetime, accent: AppColors.primary)),
              ),
              Expanded(
                flex: 2,
                child: Center(
                    child: _Cell(
                        value: feature.pro, accent: AppColors.accent)),
              ),
            ],
          ),
        ),
        // A4 — theme-aware so light mode doesn't pick up the
        // bumped dark-mode borderFaint shade.
        Divider(height: 1, color: context.colBorderFaint),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String value;
  final Color accent;
  const _Cell({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isCheck = value == '✓';
    final isCross = value == '✗';

    if (isCheck) {
      return Icon(Icons.check_circle_rounded, size: 16, color: accent);
    }
    if (isCross) {
      return Icon(Icons.cancel_rounded,
          size: 16, color: context.colTextMuted.withValues(alpha: 0.4));
    }
    return Text(
      value,
      style: AppTypography.bodySmall(context).copyWith(
        fontSize: 10.5,
        color: accent,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pricing card
// ─────────────────────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final _PricingOption option;
  final bool selected;
  final String headline;
  final String price;
  /// When set, renders next to [price] with a strikethrough — used for
  /// the regular price during a launch promo so users see the discount.
  final String? strikethroughPrice;
  final String subline;
  final String? badge;
  /// Optional small-print line under the headline.  Currently used to
  /// spell out what the Lifetime tier does *not* include so the
  /// no-cloud limitation is impossible to miss.
  final String? footnote;
  final VoidCallback onTap;

  const _PricingCard({
    required this.option,
    required this.selected,
    required this.headline,
    required this.price,
    required this.subline,
    this.strikethroughPrice,
    this.badge,
    this.footnote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.surface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Center(
                          child: Icon(Icons.check_rounded,
                              color: Colors.black, size: 12),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),

                // Labels
                //
                // Bug #173 — the badge ("BEST VALUE — SAVE 50%") used
                // to live in the same Row as the headline.  With no
                // width cap on the badge container, on phones with
                // narrower content widths (or under in-app localised
                // labels) the headline got squeezed character-by-
                // character: "Pro Cloud — Annual" wrapped as
                // Pro / Cloud / — An / nual.  Same root cause as the
                // plant tile crush (#167).
                //
                // Fix: headline gets full width on its own line, with
                // maxLines:1 + ellipsis as a defensive cap.  The badge
                // sits ABOVE the headline as a small chip so the
                // savings call-out still has top-of-card prominence.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge(context).copyWith(
                          fontSize: 14,
                          color: selected
                              ? AppColors.accent
                              : context.colTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(context).copyWith(
                          fontSize: 11,
                          color: context.colTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Price block — strikethrough regular price stacks
                // above the active promo price when both are present.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (strikethroughPrice != null)
                      Text(
                        strikethroughPrice!,
                        style: AppTypography.labelSmall(context).copyWith(
                          fontSize: 11,
                          color: context.colTextMuted,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: context.colTextMuted,
                        ),
                      ),
                    Text(
                      price,
                      style: AppTypography.labelLarge(context).copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.accent
                            : context.colTextPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (footnote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                // Indent so the footnote aligns with the headline column,
                // visually associating it with the right card rather than
                // looking like a stray paragraph.
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: Text(
                  footnote!,
                  style: AppTypography.bodySmall(context).copyWith(
                    fontSize: 11,
                    color: context.colTextMuted,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Purchase button
// ─────────────────────────────────────────────────────────────────────────────

class _PurchaseButton extends StatelessWidget {
  final bool loading;
  final bool canPurchase;
  final String label;
  final VoidCallback? onTap;

  const _PurchaseButton({
    required this.loading,
    required this.canPurchase,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canPurchase ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: canPurchase ? AppColors.gradientAmber : null,
          color: canPurchase ? null : AppColors.surface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: canPurchase
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: Colors.black, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: TextStyle(
                        color: canPurchase ? Colors.black : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Already-purchased screen — tier-aware so the copy matches the
// actual entitlement (Lifetime Local users shouldn't see Pro Cloud branding).
// ─────────────────────────────────────────────────────────────────────────────

class _AlreadyPurchasedScreen extends StatelessWidget {
  final SubscriptionTier tier;
  const _AlreadyPurchasedScreen({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isLifetime = tier == SubscriptionTier.lifetimeLocal;
    final title = isLifetime ? 'Lifetime Local' : 'You\'re a Pro!';
    final body = isLifetime
        ? 'Your one-time purchase is active on this device.\n'
            'All local features unlocked, forever.'
        : 'All Pro Cloud features are active on this device.\n'
            'Thank you for supporting Kultivar.';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppColors.textSecondary),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.gradientAmber,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded,
                      color: Colors.black, size: 40),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: AppTypography.displayMedium(context)
                    .copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: AppTypography.bodyMedium(context)
                    .copyWith(color: context.colTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: const Text('Continue Growing',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature data
//
// `lifetime` and `pro` columns show what each *paid* tier includes; `free`
// shows what's available out of the box.  The strain library + comparisons
// are explicitly listed in Free as of the three-tier rollout — they cost
// nothing to provide and the comparison tool is a strong taste of the
// analytics depth the paid tiers expand on.
//
// Note: when a row says "✗" for Pro Cloud or "✓" for Free, double-check
// that the call site enforces it — the codebase doesn't yet hard-limit
// plant counts so those rows are aspirational until the cap is wired in.
// ─────────────────────────────────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final String label;
  final String free;
  final String lifetime;
  final String pro;
  const _Feature(this.icon, this.label, this.free, this.lifetime, this.pro);
}

const _kFeatures = [
  _Feature(Icons.home_work_rounded,      'Grow spaces',                '1',       'Unlimited', 'Unlimited'),
  _Feature(Icons.eco_rounded,            'Active plants',              '3',       'Unlimited', 'Unlimited'),
  _Feature(Icons.bar_chart_rounded,      'Analytics history',          '60 days', 'All time',  'All time'),
  _Feature(Icons.science_rounded,        'Built-in strain library',    '✓',       '✓',         '✓'),
  _Feature(Icons.compare_arrows_rounded, 'Strain comparisons',         '✓',       '✓',         '✓'),
  _Feature(Icons.picture_as_pdf_rounded, 'PDF / CSV export',           '✗',       '✓',         '✓'),
  _Feature(Icons.widgets_rounded,        'Home screen widget',         '✗',       '✓',         '✓'),
  _Feature(Icons.lock_outline_rounded,   'Local encrypted backups',    '✓',       '✓',         '✓'),
  _Feature(Icons.groups_rounded,         'Community percentile data',  '✗',       '✗',         '✓'),
  _Feature(Icons.sync_rounded,           'Cross-device sync (soon)',   '✗',       '✗',         '✓'),
  _Feature(Icons.cloud_upload_rounded,   'Cloud auto-backup (soon)',   '✗',       '✗',         '✓'),
  _Feature(Icons.support_agent_rounded,  'Priority support',           '✗',       'Email',     '✓'),
];

// ─────────────────────────────────────────────────────────────────────────────
// kIsDebug — resolves true only in debug mode (const, tree-shaken in release)
// ─────────────────────────────────────────────────────────────────────────────

const bool kIsDebug = !bool.fromEnvironment('dart.vm.product');
