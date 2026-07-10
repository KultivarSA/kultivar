import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../screens/paywall_screen.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProGate
//
// Shows `child` when the user has Pro; otherwise shows a locked placeholder.
//
// Usage — wrap any Pro-only widget:
//
//   ProGate(
//     feature: 'Unlimited Spaces',
//     child: _AddSpaceButton(),
//   )
//
// Usage — card-sized lock UI (e.g. gating a whole settings row):
//
//   ProGate.card(
//     feature: 'PDF Export',
//     description: 'Export your grow reports as PDF or CSV.',
//     icon: Icons.picture_as_pdf_rounded,
//   )
//
// Usage — inline chip (locks a single action button):
//
//   ProGate.chip(
//     feature: 'Compare Strains',
//     child: _CompareButton(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ProGate extends StatelessWidget {
  /// Human-readable feature name shown in the lock prompt.
  final String feature;

  /// Shown when the user has Pro.
  final Widget child;

  /// Custom widget to show when locked (defaults to [_DefaultLock]).
  final Widget? lockedChild;

  const ProGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedChild,
  });

  // ── Factory constructors ──────────────────────────────────────────────────

  /// A card-sized locked tile with icon, feature name, description, and
  /// an "Upgrade" button.  Use when the gated feature would normally occupy
  /// a full card or list tile.
  factory ProGate.card({
    Key? key,
    required String feature,
    String? description,
    IconData? icon,
    Widget? child,
  }) {
    return ProGate(
      key: key,
      feature: feature,
      lockedChild: _CardLock(
        feature: feature,
        description: description,
        icon: icon,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  /// Overlays a small lock icon + tap-to-upgrade on top of a dimmed `child`.
  /// Good for buttons, tiles, or small inline elements.
  factory ProGate.overlay({
    Key? key,
    required String feature,
    required Widget child,
  }) {
    return ProGate(
      key: key,
      feature: feature,
      lockedChild: _OverlayLock(feature: feature, child: child),
      child: child,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPro = context.select<SubscriptionService, bool>((s) => s.isPro);
    if (isPro) return child;
    return lockedChild ?? _DefaultLock(feature: feature);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — open the paywall and return whether Pro was activated.
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> showPaywall(BuildContext context) => PaywallScreen.show(context);

// ─────────────────────────────────────────────────────────────────────────────
// Lock widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Simple inline banner lock — used by default.
class _DefaultLock extends StatelessWidget {
  final String feature;
  const _DefaultLock({required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPaywall(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: AppColors.accent, size: 15),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$feature · Pro',
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card-sized lock placeholder.
class _CardLock extends StatelessWidget {
  final String feature;
  final String? description;
  final IconData? icon;

  const _CardLock({required this.feature, this.description, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPaywall(context),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                icon ?? Icons.workspace_premium_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        feature,
                        style: AppTypography.labelLarge(context).copyWith(
                          fontSize: 13,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ProBadge(),
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: AppTypography.bodySmall(context).copyWith(
                        color: context.colTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Arrow
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// Overlays a lock icon on top of a dimmed widget.
class _OverlayLock extends StatelessWidget {
  final String feature;
  final Widget child;

  const _OverlayLock({required this.feature, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPaywall(context),
      child: Stack(
        children: [
          // Dimmed original content
          Opacity(
            opacity: 0.25,
            child: IgnorePointer(child: child),
          ),
          // Lock overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.accent, size: 20),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Pro',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Pro badge chip
// ─────────────────────────────────────────────────────────────────────────────

class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) => _ProBadge();
}

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border:
            Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 9, color: AppColors.accent),
          SizedBox(width: 3),
          Text(
            'PRO',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProLimitBanner
//
// Shows a banner when the user is approaching or has hit a free-tier limit.
// Typically placed at the top of a list screen.
//
// Example:
//   ProLimitBanner(
//     message: 'You\'ve reached the 3-plant limit on the free plan.',
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ProLimitBanner extends StatelessWidget {
  final String message;

  const ProLimitBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPaywall(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding, AppSpacing.sm,
            AppSpacing.pagePadding, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: AppColors.accent, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall(context).copyWith(
                  color: AppColors.accent,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${AppLocalizations.of(context).proGateUpgradeAction} →',
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
