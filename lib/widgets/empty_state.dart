import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'empty_state_art.dart';

/// Shared empty-state hero block used across Home, Notes, Archive,
/// Strains, Search, Photos, Costs, Environment and Compare screens.
///
/// Two ways to render the hero:
///
///   • [art] — a value from [EmptyArt].  Renders one of the curated
///     line-art illustrations (A3).  This is the default for every
///     production surface.
///   • [icon] — a Material `IconData` rendered inside a square card.
///     Kept as a fallback for ad-hoc surfaces (e.g. one-off banners,
///     or tests that need a deterministic single-glyph hero).
///
/// Exactly one of [art] / [icon] must be supplied.  Passing both is an
/// `assert` violation in debug builds and falls back to the art hero
/// in release builds (silently prefers the new path).
class EmptyState extends StatelessWidget {
  /// Line-art illustration to render as the hero.  Prefer this for
  /// any new call site — the curated set keeps every empty state in
  /// the app visually cohesive.
  final EmptyArt? art;

  /// Single Material icon to render — legacy path.  Use [art] for
  /// production surfaces unless the empty state is genuinely a
  /// one-off (a sub-tab inside a settings screen, an error overlay,
  /// etc.) where curating a new illustration would be overkill.
  final IconData? icon;

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Accent colour for the line-art / icon hero.  Defaults to the
  /// app's primary green so every empty state shares the same brand
  /// hue; pass an override on screens that already use a different
  /// accent (e.g. amber on the harvest archive).
  final Color? accent;

  const EmptyState({
    super.key,
    this.art,
    this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accent,
  })  : assert(art != null || icon != null,
            'EmptyState needs either an art or icon hero.'),
        assert(art == null || icon == null,
            'EmptyState: supply art OR icon, not both.');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hero — line-art is preferred; fall through to the icon
            // card when only the legacy `icon:` param was supplied.
            if (art != null)
              LineArtIllustration(art: art!, accent: accent)
            else
              _IconCard(icon: icon!),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                style: AppTypography.headlineSmall(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle,
                style: AppTypography.bodyMedium(context),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Legacy icon hero — kept private to the file so call sites can't
/// hand-roll the old visual outside this widget.  Matches the
/// original 80px rounded-square card so existing screens that still
/// pass `icon:` continue to look correct while we migrate them.
class _IconCard extends StatelessWidget {
  final IconData icon;

  const _IconCard({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.colBorder),
      ),
      child: Icon(icon, size: 36, color: context.colTextMuted),
    );
  }
}
