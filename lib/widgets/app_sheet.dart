import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Standard bottom-sheet chrome used throughout the app.
///
/// Provides a drag handle, optional icon header (circle icon + title +
/// subtitle), correct horizontal/bottom padding, and keyboard avoidance.
/// Wrap in [StatefulBuilder] when the sheet needs reactive internal state.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   backgroundColor: Colors.transparent,
///   isScrollControlled: true,
///   builder: (_) => AppSheet(
///     title: 'Add Plant',
///     subtitle: 'Start tracking a new grow',
///     icon: Icons.eco_rounded,
///     iconColor: AppColors.growing,
///     children: [...],
///   ),
/// );
/// ```
class AppSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget> children;

  const AppSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? AppColors.primary;
    final mq = MediaQuery.of(context);

    // Maximum sheet height: full visible area above the keyboard.
    // This prevents overflow when the keyboard is up and content is tall.
    final maxHeight = mq.size.height - mq.viewInsets.bottom - mq.padding.top;

    return Padding(
      // Shift content above the keyboard.
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
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
            // xl bottom padding + device safe-area (home indicator).
            AppSpacing.xl + mq.padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ───────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.colBorder,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),

              // ── Header ───────────────────────────
              if (icon != null) ...[
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ic.withValues(alpha: AppOpacity.tintMedium),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: ic, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppTypography.headlineMedium(context)),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: AppTypography.bodySmall(context)
                                  .copyWith(color: context.colTextMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(title, style: AppTypography.headlineLarge(context)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextSecondary),
                  ),
                ],
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── Content ───────────────────────────
              // Flexible + SingleChildScrollView lets the content area shrink
              // and scroll when the keyboard or a tall dropdown eats into the
              // available height, rather than overflowing.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
