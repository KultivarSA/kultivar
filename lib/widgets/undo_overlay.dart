import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A generic centred, swipe-to-dismiss overlay card for reversible delete
/// actions (note deleted, env log deleted, harvest record deleted, etc.).
///
/// Usage:
/// ```dart
/// UndoOverlay.show(
///   context,
///   icon: Icons.note_rounded,
///   color: AppColors.warning,
///   title: 'Note Deleted',
///   subtitle: 'The note has been removed.',
///   undoLabel: 'Undo',
///   onUndo: () => repo.readdNote(note),
/// );
/// ```
class UndoOverlay {
  static OverlayEntry? _entry;

  /// Show a centred undo card.
  ///
  /// [onUndo] fires when the user taps the Undo button.
  /// [onTimeout] (optional) fires when the user lets the card auto-dismiss
  /// or swipes it away WITHOUT tapping Undo — useful for "commit the
  /// destructive action now" cleanup like deleting on-disk photos that
  /// were left in place during the undo window.
  static void show(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String undoLabel = 'Undo',
    required VoidCallback onUndo,
    VoidCallback? onTimeout,
    Duration duration = const Duration(seconds: 5),
  }) {
    _entry?.remove();
    _entry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _UndoCard(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        undoLabel: undoLabel,
        duration: duration,
        onUndo: () {
          onUndo();
          _remove(entry);
        },
        onDismiss: () {
          _remove(entry);
          onTimeout?.call();
        },
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

class _UndoCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String undoLabel;
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  const _UndoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.undoLabel,
    required this.duration,
    required this.onUndo,
    required this.onDismiss,
  });

  @override
  State<_UndoCard> createState() => _UndoCardState();
}

class _UndoCardState extends State<_UndoCard> with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _countdownCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  double _dragOffset = 0.0;
  bool _dismissed = false;

  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );
    _enterCtrl.forward();

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

  void _onDragUpdate(DragUpdateDetails d) =>
      setState(() => _dragOffset += d.delta.dy);

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_dragOffset.abs() > 90 || velocity.abs() > 450) {
      _dismiss();
    } else {
      setState(() => _dragOffset = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final c = widget.color;

    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: c.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: c.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Body ─────────────────────────────
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
                    color: c.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withValues(alpha: 0.25)),
                  ),
                  child: Icon(widget.icon, color: c, size: 26),
                ),

                const SizedBox(height: AppSpacing.md),

                Text(widget.title,
                    style: AppTypography.headlineMedium(context)),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  widget.subtitle,
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

          // ── Undo button ───────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.undo_rounded, size: 17),
                label: Text(widget.undoLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: AppTypography.labelLarge(context)
                      .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
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
                valueColor: AlwaysStoppedAnimation<Color>(
                    c.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
