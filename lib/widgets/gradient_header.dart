import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget? trailing;
  final List<Widget>? stats;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.accentColor,
    this.trailing,
    this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.xl,
        AppSpacing.pagePadding,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            context.colSurface1,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: context.colBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.displayMedium(context)
                            .copyWith(color: accentColor)),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle!, style: AppTypography.bodyMedium(context)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (stats != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: stats!
                  .expand((s) => [s, const SizedBox(width: AppSpacing.sm)])
                  .toList()
                ..removeLast(),
            ),
          ],
        ],
      ),
    );
  }
}
