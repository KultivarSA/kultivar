import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Full-screen celebration overlay shown when a grow is harvested.
///
/// Shows plant name, strain, wet weight (if entered), and days grown.
/// Animated gold sparkles drift upward behind the card.
/// Tap anywhere or wait 7 s to dismiss.
///
/// Usage:
/// ```dart
/// HarvestCelebrationOverlay.show(
///   context,
///   plantName: plant.name,
///   strain: plant.strain,
///   wetWeightG: wetWeight,
///   growDays: DateTime.now().difference(plant.startDate).inDays,
/// );
/// ```
class HarvestCelebrationOverlay {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required String plantName,
    required String strain,
    double? wetWeightG,
    required int growDays,
    Duration duration = const Duration(seconds: 7),
  }) {
    _entry?.remove();
    _entry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HarvestCard(
        plantName: plantName,
        strain: strain,
        wetWeightG: wetWeightG,
        growDays: growDays,
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

class _HarvestCard extends StatefulWidget {
  final String plantName;
  final String strain;
  final double? wetWeightG;
  final int growDays;
  final Duration duration;
  final VoidCallback onDismiss;

  const _HarvestCard({
    required this.plantName,
    required this.strain,
    required this.wetWeightG,
    required this.growDays,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_HarvestCard> createState() => _HarvestCardState();
}

class _HarvestCardState extends State<_HarvestCard>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _countdownCtrl;
  late final AnimationController _sparkleCtrl;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _trophyBounce;

  bool _dismissed = false;
  Timer? _autoTimer;

  // Pre-generated sparkle particles so they don't rebuild each frame.
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    final rng = Random(42); // fixed seed → consistent layout
    _particles = List.generate(
      18,
      (_) => _Particle(
        x: rng.nextDouble(),
        startY: 0.4 + rng.nextDouble() * 0.6, // lower half of screen
        size: 3.0 + rng.nextDouble() * 5.0,
        speed: 0.3 + rng.nextDouble() * 0.7,
        phase: rng.nextDouble(),
        color: _sparkleColors[rng.nextInt(_sparkleColors.length)],
      ),
    );

    // Entrance
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

    // Trophy icon bounce: pulses 0→1 once after card appears
    _trophyBounce = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );

    _enterCtrl.forward();

    // Countdown
    _countdownCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();

    // Sparkles loop continuously
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _autoTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _enterCtrl.dispose();
    _countdownCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  static const _sparkleColors = [
    AppColors.harvested,          // gold
    Color(0xFFFFF176),            // pale yellow
    AppColors.optimal,            // green
    Color(0xFFFFCC80),            // light amber
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dismiss,
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          child: Stack(
            children: [
              // ── Sparkle layer ─────────────────
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _sparkleCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _SparklePainter(
                      t: _sparkleCtrl.value,
                      particles: _particles,
                    ),
                  ),
                ),
              ),

              // ── Card ─────────────────────────
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: _buildCard(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    const gold = AppColors.harvested;

    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: gold.withValues(alpha: 0.40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: gold.withValues(alpha: 0.18),
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
                colors: [Color(0xFFFFB547), Color(0xFFFFF176), Color(0xFFFFB547)],
              ),
            ),
          ),

          // ── Body ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              children: [
                // Trophy icon with bounce
                ScaleTransition(
                  scale: _trophyBounce,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          gold.withValues(alpha: 0.30),
                          gold.withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: gold.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: gold,
                      size: 34,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  'Harvest Complete!',
                  style: AppTypography.headlineLarge(context)
                      .copyWith(color: gold),
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

                // ── Stats row ─────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.wetWeightG != null) ...[
                      _statPill(
                        context,
                        icon: Icons.water_drop_rounded,
                        label:
                            '${widget.wetWeightG!.toStringAsFixed(0)} g',
                        sublabel: 'wet weight',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    _statPill(
                      context,
                      icon: Icons.calendar_today_rounded,
                      label: '${widget.growDays}d',
                      sublabel: 'total grow',
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Tap-to-dismiss hint
                Text(
                  'Tap anywhere to dismiss',
                  style: AppTypography.labelSmall(context).copyWith(
                    color: context.colTextMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // ── Countdown bar ─────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppSpacing.radiusXl),
              bottomRight: Radius.circular(AppSpacing.radiusXl),
            ),
            child: AnimatedBuilder(
              animation: _countdownCtrl,
              builder: (_, __) => LinearProgressIndicator(
                value: 1.0 - _countdownCtrl.value,
                minHeight: 4,
                backgroundColor: context.colSurface3,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(gold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.harvested.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: AppColors.harvested.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.harvested),
          const SizedBox(height: 3),
          Text(label,
              style: AppTypography.labelLarge(context)
                  .copyWith(color: AppColors.harvested, fontSize: 15)),
          Text(sublabel,
              style: AppTypography.labelSmall(context).copyWith(
                  color: context.colTextMuted, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sparkle particle system
// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  final double x;       // 0–1 horizontal position
  final double startY;  // 0–1 starting vertical position
  final double size;    // radius in logical pixels
  final double speed;   // relative drift speed (0–1)
  final double phase;   // animation phase offset (0–1)
  final Color color;

  const _Particle({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.phase,
    required this.color,
  });
}

class _SparklePainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;

  const _SparklePainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Each particle has its own phase offset so they stagger naturally.
      final pt = (t * p.speed + p.phase) % 1.0;

      // Fade in then out over the particle's lifetime.
      final opacity = pt < 0.15
          ? pt / 0.15
          : pt > 0.70
              ? (1.0 - pt) / 0.30
              : 1.0;

      if (opacity <= 0) continue;

      // Drift upward; particles that started lower drift further.
      final y = (p.startY - pt * 0.55 * p.speed) * size.height;
      final x = p.x * size.width +
          sin(pt * pi * 2 + p.phase * pi) * 12; // gentle sway

      final radius = p.size * (0.6 + 0.4 * sin(pt * pi));

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = p.color.withValues(alpha: (opacity * 0.65).clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}
