import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Full-screen celebration shown when a grow finishes its curing phase
/// — i.e. transitions from `PlantStatus.curing` to `PlantStatus.completed`.
///
/// Mirrors the design of [HarvestCelebrationOverlay] (gold-bordered
/// card, trophy icon, tap-to-dismiss) but with two important
/// differences:
///
///   1. Copy focuses on completion rather than harvest — the user has
///      already seen the harvest celebration earlier in the cycle.
///   2. Includes a clear pointer to the Archive tab so the user
///      doesn't panic when the plant disappears from the active list
///      ("their grow lives on in the Archive").
///
/// Usage:
/// ```dart
/// CompletionCelebrationOverlay.show(
///   context,
///   plantName: plant.name,
///   strain: plant.strain,
///   totalDays: DateTime.now().difference(plant.startDate).inDays,
/// );
/// ```
class CompletionCelebrationOverlay {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required String plantName,
    required String strain,
    required int totalDays,
    Duration duration = const Duration(seconds: 8),
  }) {
    _entry?.remove();
    _entry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CompletionCard(
        plantName: plantName,
        strain: strain,
        totalDays: totalDays,
        duration: duration,
        onDismiss: () => _remove(entry),
      ),
    );

    _entry = entry;
    Overlay.of(context).insert(entry);
  }

  static void _remove(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
    if (_entry == entry) _entry = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CompletionCard extends StatefulWidget {
  final String plantName;
  final String strain;
  final int totalDays;
  final Duration duration;
  final VoidCallback onDismiss;

  const _CompletionCard({
    required this.plantName,
    required this.strain,
    required this.totalDays,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_CompletionCard> createState() => _CompletionCardState();
}

class _CompletionCardState extends State<_CompletionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _trophyBounce;

  bool _dismissed = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );
    _trophyBounce = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );
    _enterCtrl.forward();
    _autoTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dismiss,
        child: Material(
          color: Colors.black.withValues(alpha: 0.40),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: _buildCard(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    // Use AppColors.completed (the same hue the lifecycle stepper +
    // status pill use for finished grows) so this card slots into the
    // app's visual language for "done" rather than reusing the harvest
    // gold the user saw earlier.
    const accent = AppColors.completed;

    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header gradient bar ───────────────
          Container(
            width: double.infinity,
            height: 6,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusXl),
                topRight: Radius.circular(AppSpacing.radiusXl),
              ),
              gradient: LinearGradient(
                colors: [accent, Color(0xFFB9F6CA), accent],
              ),
            ),
          ),

          // ── Body ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              children: [
                // Trophy with elastic bounce
                ScaleTransition(
                  scale: _trophyBounce,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.30),
                          accent.withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: accent,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Text(
                  'Grow Complete!',
                  style: AppTypography.headlineLarge(context)
                      .copyWith(color: accent),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '"${widget.plantName}"',
                  style: AppTypography.headlineSmall(context),
                ),
                if (widget.strain.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.strain,
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                // ── Total grow time stat ──────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: accent),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${widget.totalDays} days from start to finish',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: accent),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Archive pointer ─────────────
                //
                // Core purpose of this overlay: tell the user their
                // plant ISN'T lost — it has moved to the Archive tab.
                // Mirroring the icon used in the bottom-nav so the
                // visual link is immediate.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colSurface3,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: context.colBorderFaint),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.harvested.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm),
                        ),
                        child: const Icon(Icons.archive_rounded,
                            size: 18, color: AppColors.harvested),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find this grow anytime',
                              style: AppTypography.labelLarge(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your full plant history — photos, notes, '
                              'environment logs and harvest data — is '
                              'preserved in the Archive tab.',
                              style: AppTypography.bodySmall(context)
                                  .copyWith(color: context.colTextMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                Text(
                  'Tap anywhere to dismiss',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
