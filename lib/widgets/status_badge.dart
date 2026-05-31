import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.small = false,
  });

  factory StatusBadge.fromStatus(String status, {bool small = false}) {
    return StatusBadge(
      label: status.toUpperCase(),
      color: AppColors.statusColor(status),
      small: small,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: (small
                ? AppTypography.labelSmall(context)
                : AppTypography.labelLarge(context))
            .copyWith(
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
