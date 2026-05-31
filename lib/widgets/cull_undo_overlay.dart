import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A centred, swipe-to-dismiss overlay card shown after a plant is culled.
///
/// Call [CullUndoOverlay.show] from any screen after archiving a plant.
/// The card auto-dismisses after [duration] (default 5 s) and exposes an
/// Undo button.  Swiping up or down also dismisses it.
class CullUndoOverlay {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required String plantName,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    // Remove any lingering previous overlay first.
    _entry?.remove();
    _entry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CullUndoCard(
        plantName: plantName,
        duration: duration,
        onUndo: () {
          onUndo();
          _remove(entry);
        },
        onDismiss: () => _remove(entry),
      ),
    );

    _entry = entry;
    Overlay.of(context).insert(entry);
  }

  static void _remove(OverlayEntry entry) {
    if (entry.mounted) {
      entry.remove();
    }
    if (_entry == entry) _entry = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal card widget
// ─────────────────────────────────────────────────────────────────────────────

class _CullUndoCard extends StatefulWidget {
  final String plantName;
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  const _CullUndoCard({
    required this.plantName,
    required this.duration,
    required this.onUndo,
    required this.onDismiss,
  });

  @override
  State<_CullUndoCard> createState() => _CullUndoCardState();
}

class _CullUndoCardState extends State<_CullUndoCard>
    with TickerProviderStateMixin {
  // ── Entrance animation ──────────────────────────
  late final AnimationController _enterCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  // ── Countdown bar ───────────────────────────────
  late final AnimationController _countdownCtrl;

  // ── Swipe-to-dismiss state ──────────────────────
  double _dragOffset = 0.0;
  bool _dismissed = false;

  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();

    // Entrance: scale from 0.88→1.0 + fade 0→1 over 280 ms
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );
    _enterCtrl.forward();

    // Countdown: 0→1 over [duration], bar reads 1−value so starts full.
    _countdownCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();

    _autoTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _enterCtrl.dispose();
    _countdownCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  // ── Drag gesture handlers ───────────────────────

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragOffset += d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    // Dismiss on fast flick OR if dragged far enough.
    if (_dragOffset.abs() > 90 || velocity.abs() > 450) {
      _dismiss();
    } else {
      // Snap back.
      setState(() => _dragOffset = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Opacity fades as the card is dragged away.
    final dragFade = (1.0 - (_dragOffset.abs() / 180)).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: GestureDetector(
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: Opacity(
                    opacity: dragFade,
                    child: _buildCard(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Body ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              children: [
                // Icon circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(
                    Icons.content_cut_rounded,
                    color: AppColors.danger,
                    size: 26,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Title
                Text(
                  'Plant Archived',
                  style: AppTypography.headlineMedium(context),
                ),

                const SizedBox(height: AppSpacing.xs),

                // Subtitle
                Text(
                  '"${widget.plantName}" has been culled\nand moved to the archive.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Swipe hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_rounded,
                        size: 13, color: context.colTextMuted),
                    const SizedBox(width: 5),
                    Text(
                      'Swipe up or down to dismiss',
                      style: AppTypography.labelSmall(context).copyWith(
                        color: context.colTextMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: context.colBorder),

          // ── Undo button ────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.undo_rounded, size: 17),
                label: const Text('Undo Archive'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: AppTypography.labelLarge(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  elevation: 0,
                ),
                onPressed: widget.onUndo,
              ),
            ),
          ),

          // ── Countdown bar ──────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppSpacing.radiusXl),
              bottomRight: Radius.circular(AppSpacing.radiusXl),
            ),
            child: AnimatedBuilder(
              animation: _countdownCtrl,
              builder: (_, __) => LinearProgressIndicator(
                // Starts at 1.0 (full) and drains to 0.0 as time runs out.
                value: 1.0 - _countdownCtrl.value,
                minHeight: 4,
                backgroundColor: context.colSurface3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.danger.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
