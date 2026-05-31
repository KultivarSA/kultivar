import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A themed confirmation bottom sheet that replaces plain [AlertDialog]
/// confirmations throughout the app.
///
/// Returns `true` when the user confirms, `false` / `null` on cancel.
///
/// Usage:
/// ```dart
/// final confirmed = await ConfirmSheet.show(
///   context,
///   icon: Icons.delete_rounded,
///   iconColor: AppColors.danger,
///   title: 'Delete Plant?',
///   body: 'This action cannot be undone.',
///   confirmLabel: 'Delete',
/// );
/// if (confirmed) { ... }
/// ```
///
/// Pass [extraContent] for additional contextual warnings (e.g. a "N active
/// plants will be archived" banner).
///
/// Pass [onConfirm] to run async work (import, delete) inside the sheet before
/// it closes — the button shows a spinner while it runs.
class ConfirmSheet {
  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    Widget? extraContent,
    required String confirmLabel,
    Color? confirmColor,
    String? cancelLabel,
    Future<void> Function()? onConfirm,
  }) async {
    // UX2 — when the caller doesn't supply a cancel label, resolve the
    // localized "Cancel" string here so every call site automatically
    // gets the user's chosen language without having to pass it in.
    final resolvedCancel =
        cancelLabel ?? AppLocalizations.of(context).commonCancel;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheetBody(
        icon: icon,
        iconColor: iconColor,
        title: title,
        body: body,
        extraContent: extraContent,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor ?? AppColors.danger,
        cancelLabel: resolvedCancel,
        onConfirm: onConfirm,
      ),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmSheetBody extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? extraContent;
  final String confirmLabel;
  final Color confirmColor;
  final String cancelLabel;
  final Future<void> Function()? onConfirm;

  const _ConfirmSheetBody({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.extraContent,
    required this.confirmLabel,
    required this.confirmColor,
    required this.cancelLabel,
    required this.onConfirm,
  });

  @override
  State<_ConfirmSheetBody> createState() => _ConfirmSheetBodyState();
}

class _ConfirmSheetBodyState extends State<_ConfirmSheetBody> {
  bool _loading = false;

  Future<void> _handleConfirm() async {
    if (widget.onConfirm != null) {
      setState(() => _loading = true);
      try {
        await widget.onConfirm!();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // Sit above the system navigation bar.
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final c = widget.iconColor;

    return Container(
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.lg + bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ───────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),

          // ── Icon circle ───────────────────────
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: c.withValues(alpha: 0.28)),
            ),
            child: Icon(widget.icon, color: c, size: 28),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Title ─────────────────────────────
          Text(
            widget.title,
            style: AppTypography.headlineMedium(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Body ──────────────────────────────
          Text(
            widget.body,
            style: AppTypography.bodyMedium(context)
                .copyWith(color: context.colTextMuted),
            textAlign: TextAlign.center,
          ),

          // ── Extra content (optional warning) ──
          if (widget.extraContent != null) ...[
            const SizedBox(height: AppSpacing.md),
            widget.extraContent!,
          ],

          const SizedBox(height: AppSpacing.xl),

          // ── Confirm button ────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.confirmColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    widget.confirmColor.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
                textStyle: AppTypography.labelLarge(context).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                  : Text(widget.confirmLabel),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Cancel button ─────────────────────
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed:
                  _loading ? null : () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              child: Text(
                widget.cancelLabel,
                style: AppTypography.labelLarge(context).copyWith(
                  color: context.colTextSecondary,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
