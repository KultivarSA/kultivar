import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// F12 — Expandable "lazy" section header.
///
/// Why this exists: `PlantDetailScreen` currently builds every panel
/// eagerly — yield insights, community benchmark, health score, multiple
/// charts.  On a phone with 10+ plants that's expensive even before the
/// frame paints (network calls fire, charts compute, photos resolve).
///
/// `LazySection` defers the heavy child until the user opens the panel
/// for the first time.  After that the child stays alive in the tree
/// even when collapsed — so re-opening a panel doesn't re-run any
/// initial network calls or charting work, and any internal state
/// (scroll position, half-played audio) survives a collapse.
///
/// Visual behaviour:
///  * Header tile with icon + title + (optional) subtitle + chevron.
///  * Tap toggles open/closed; the chevron rotates with a 200 ms ease.
///  * On expand, the child fades in beneath the header.
///  * Collapse hides via `Offstage` (cheap; keeps the widget mounted
///    but skips paint + hit-testing).
///
/// [builder] (rather than a raw `child`) lets the heavy widget tree
/// avoid even *constructing* its root before the first expand — useful
/// when the constructor itself isn't free.
///
/// [initiallyExpanded] supports "always-open" sections in case a future
/// caller wants a header that's collapsible but starts open.
class LazySection extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final WidgetBuilder builder;
  final bool initiallyExpanded;

  /// Optional trailing widget shown to the left of the chevron.
  /// Used by sections that surface a status badge ("12 days late")
  /// before the user expands.
  final Widget? headerTrailing;

  const LazySection({
    super.key,
    required this.icon,
    required this.title,
    required this.builder,
    this.iconColor = AppColors.primary,
    this.subtitle,
    this.headerTrailing,
    this.initiallyExpanded = false,
  });

  @override
  State<LazySection> createState() => _LazySectionState();
}

class _LazySectionState extends State<LazySection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
  // Once `true`, the child stays in the tree forever — toggling _expanded
  // only flips Offstage on/off.  Cheaper than rebuilding charts or
  // refetching community benchmarks every collapse → expand cycle.
  late bool _everOpened = widget.initiallyExpanded;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.initiallyExpanded ? 1 : 0,
  );
  late final Animation<double> _rotate =
      Tween<double>(begin: 0, end: 0.5).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _everOpened = true;
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorderFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(widget.icon,
                        color: widget.iconColor, size: 16),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: AppTypography.labelLarge(context)),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: AppTypography.bodySmall(context)
                                .copyWith(color: context.colTextMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (widget.headerTrailing != null) ...[
                    widget.headerTrailing!,
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  RotationTransition(
                    turns: _rotate,
                    child: Icon(Icons.expand_more_rounded,
                        color: context.colTextMuted, size: 22),
                  ),
                ],
              ),
            ),
          ),

          // ── Lazy child ────────────────────────
          //
          // Three states:
          //   never opened  → SizedBox.shrink(); child not constructed.
          //   opened, shown → child mounted + visible + paints.
          //   opened, hidden → child mounted, Offstage skips paint.
          //
          // `maintainState: true` on Visibility would do the same thing
          // semantically, but Offstage is the more idiomatic way to
          // keep a widget alive without participating in layout.
          if (_everOpened)
            Offstage(
              offstage: !_expanded,
              child: TickerMode(
                // When offstage we also pause animations / pollers in
                // descendants — saves CPU on collapsed charts.
                enabled: _expanded,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      0,
                      AppSpacing.sm,
                      AppSpacing.sm),
                  child: widget.builder(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
