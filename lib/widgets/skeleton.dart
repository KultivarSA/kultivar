import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A6 — Skeleton loading primitives
//
// Replaces "centre-the-screen spinner" loading states with content-
// shaped placeholders that pulse with a subtle shimmer.  Perceived
// performance research (Nielsen, Apple HIG, Material) consistently
// finds skeletons read as "data is on its way and will fill in" — vs
// spinners which read as "the app is busy and you must wait" — so
// the perceived latency drops noticeably even when the actual fetch
// time is identical.
//
// Design choices:
//   • Pure Dart, no extra deps (shimmer package would add ~15 KB
//     and a transitive vsync handle we don't need).
//   • Base colour follows `context.colSurface3` so the skeleton sits
//     "above" the card surface in the theme's surface hierarchy and
//     respects light + dark mode automatically.
//   • Shimmer is a 1.2 s sliding linear gradient — slow enough to
//     read as "alive" without distracting from sibling UI.
//   • Animation is shared via a single `_SkeletonShimmerController`
//     scoped to the Skeleton's nearest TickerProvider, so a screen
//     full of skeletons paints with one ticker not N.
// ─────────────────────────────────────────────────────────────────────────────

/// Animated rectangular placeholder.  Use as a drop-in for any
/// content that is still being fetched / decoded — give it the same
/// dimensions the real content will occupy and the layout doesn't
/// jump when the data arrives.
///
/// Composed primitives are exposed below ([SkeletonLine],
/// [SkeletonCircle], [SkeletonCard]) for the common patterns.
class Skeleton extends StatefulWidget {
  /// Box width.  Null = expand to parent's max.
  final double? width;

  /// Box height.  Defaults to 16 — about a typography baseline.
  final double height;

  /// Corner radius.  Defaults to [AppSpacing.radiusSm] (8 px) so
  /// skeletons line up with the rest of the rounded-rect language.
  final BorderRadius? borderRadius;

  /// Set false to render the placeholder colour without the shimmer
  /// gradient — useful for very short-lived loading states where
  /// the moving highlight would be more distracting than helpful.
  final bool animate;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.animate = true,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  // Lazily created — only when `widget.animate` is true.  Starting
  // the ticker unconditionally would (a) waste a frame-callback per
  // static skeleton, and (b) deadlock `pumpAndSettle` in tests that
  // explicitly opt out of animation.
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colSurface3;
    final highlight = Color.lerp(base, context.colTextMuted, 0.18)!;
    final radius = widget.borderRadius ??
        BorderRadius.circular(AppSpacing.radiusSm);

    final ctrl = _ctrl;
    if (!widget.animate || ctrl == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        // Sweep a soft highlight band from -1 → 2 of the box width so
        // the moving gradient enters and exits the bounds cleanly.
        // Use the locally-promoted `ctrl` (the early-return above already
        // narrowed it to non-null) — reading `_ctrl.value` here trips
        // analyzer's unchecked_use_of_nullable_value under stricter
        // flow-analysis (notably after the fl_chart 1.0 dep bump).
        final t = ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + t * 3, 0),
              end: Alignment(1.0 + t * 3, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composed primitives
// ─────────────────────────────────────────────────────────────────────────────

/// Text-line skeleton — defaults to 12 px tall which matches our
/// body / label text height.  Pass a custom [width] (or omit for
/// full-width) to vary the visual rhythm in stacks.
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }
}

/// Circular skeleton — for avatars, leaf badges, sun discs, anything
/// that will resolve to a `BoxShape.circle`.
class SkeletonCircle extends StatelessWidget {
  final double diameter;

  const SkeletonCircle({super.key, required this.diameter});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      width: diameter,
      height: diameter,
      borderRadius: BorderRadius.circular(diameter),
    );
  }
}

/// Card-shaped skeleton — wraps a content block in the same surface
/// chrome the loaded card will use, so the layout doesn't shift
/// when the real data arrives.
class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorder),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain skeletons — pre-shaped placeholders for the surfaces that
// were previously spinner-loading.  Keeping them in this file means
// a single place to tweak shimmer rhythm / spacing for all of them.
// ─────────────────────────────────────────────────────────────────────────────

/// SpaceCard skeleton — matches the dimensions of `_SpaceCard` in
/// `home_screen.dart`, so the Home grid can stack N of these during
/// the initial repository load without any layout jump when data
/// arrives.
class SkeletonSpaceCard extends StatelessWidget {
  const SkeletonSpaceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.xs,
      ),
      child: SkeletonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + env badge row
            const Row(
              children: [
                SkeletonCircle(diameter: 24),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 140, height: 14),
                      SizedBox(height: 6),
                      SkeletonLine(width: 90),
                    ],
                  ),
                ),
                SkeletonLine(width: 56),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Plant thumbnails strip
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Skeleton(
                    width: 60,
                    height: 60,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  if (i < 2) const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CommunityBenchmarkCard skeleton — three lines of varying widths
/// inside the card chrome.  Used by `community_benchmark_card.dart`
/// while a percentile fetch is in flight.
class SkeletonBenchmarkCard extends StatelessWidget {
  const SkeletonBenchmarkCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Row(
        children: [
          SkeletonCircle(diameter: 34),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonLine(width: 150, height: 12),
                SizedBox(height: 6),
                SkeletonLine(width: 90, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// OutdoorWeatherCard skeleton — header row + a wide bar.  Sized
/// roughly to the loaded weather card so the surrounding plant
/// detail layout doesn't shift when the real data arrives.
class SkeletonWeatherCard extends StatelessWidget {
  const SkeletonWeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — icon + location label
          Row(
            children: [
              SkeletonCircle(diameter: 28),
              SizedBox(width: AppSpacing.sm),
              SkeletonLine(width: 120, height: 14),
              Spacer(),
              SkeletonLine(width: 48, height: 14),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Temperature + humidity row
          Row(
            children: [
              SkeletonLine(width: 60, height: 24),
              SizedBox(width: AppSpacing.md),
              SkeletonLine(width: 60, height: 24),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          // Forecast strip placeholder
          SkeletonLine(height: 36),
        ],
      ),
    );
  }
}

/// Image skeleton — Use as the `frameBuilder` placeholder for
/// `Image.file` so still-decoding photos show the shimmer surface
/// instead of an empty hole.
class SkeletonImage extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonImage({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppSpacing.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
