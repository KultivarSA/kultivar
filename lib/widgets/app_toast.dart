import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Toast type — controls icon and accent colour.
enum ToastType { success, error, info }

/// A lightweight centred notification card for non-reversible feedback
/// (backup saved, thresholds applied, env logged, etc.).
///
/// Smaller than [UndoOverlay] — no buttons, just icon + message + countdown.
///
/// Usage:
/// ```dart
/// AppToast.show(context, 'Backup exported successfully');
/// AppToast.show(context, 'Export failed: $e', type: ToastType.error);
/// ```
class AppToast {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _entry?.remove();
    _entry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastCard(
        message: message,
        type: type,
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

class _ToastCard extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastCard({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with TickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
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
    if (_dragOffset.abs() > 70 || velocity.abs() > 400) {
      _dismiss();
    } else {
      setState(() => _dragOffset = 0.0);
    }
  }

  (IconData, Color) get _style => switch (widget.type) {
        ToastType.success => (Icons.check_circle_rounded, AppColors.optimal),
        ToastType.error   => (Icons.error_rounded,         AppColors.danger),
        ToastType.info    => (Icons.info_rounded,           AppColors.primary),
      };

  @override
  Widget build(BuildContext context) {
    // UX6 — only downward drag dismisses now that the toast lives at the
    // bottom of the screen.  Upward drags get clamped to 0 so the user
    // can't accidentally drag it off the top edge.
    final clampedOffset = _dragOffset < 0 ? 0.0 : _dragOffset;
    final dragFade = (1.0 - (clampedOffset / 150)).clamp(0.0, 1.0);
    final (icon, color) = _style;

    // UX6 — sit the toast above the system nav bar / home indicator and
    // any floating FABs.  The 100px clearance is a deliberate buffer to
    // keep the message away from primary actions like the home FAB or
    // batch-action bar.  Same anchor for every ToastType so positioning
    // is predictable regardless of severity.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + 100,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: GestureDetector(
                onTap: _dismiss,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Transform.translate(
                  offset: Offset(0, clampedOffset),
                  child: Opacity(
                    opacity: dragFade,
                    child: _buildCard(context, icon, color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, Color color) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
            color: color.withValues(alpha: AppOpacity.borderFaint),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppOpacity.textPlaceholder),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Content ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: AppOpacity.tintMedium),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppTypography.bodyMedium(context),
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
                minHeight: 3,
                backgroundColor: context.colSurface3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                        color.withValues(alpha: AppOpacity.scrimMedium)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
