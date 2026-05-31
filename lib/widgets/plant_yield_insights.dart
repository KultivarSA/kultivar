import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class PlantYieldInsights extends StatelessWidget {
  final Plant plant;

  const PlantYieldInsights({
    super.key,
    required this.plant,
  });

  @override
  Widget build(BuildContext context) {
    if (plant.status == PlantStatus.removed) {
      return const SizedBox.shrink();
    }

    if (plant.wetWeight == null || plant.wetWeight! <= 0) {
      return const SizedBox.shrink();
    }

    final hasDryWeight = plant.dryWeight != null && plant.dryWeight! > 0;
    final yieldPercent =
        hasDryWeight ? (plant.dryWeight! / plant.wetWeight!) * 100 : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.growing.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _metric(
            context,
            label: 'Wet',
            value: '${plant.wetWeight!.toStringAsFixed(1)} g',
          ),
          _metric(
            context,
            label: 'Dry',
            value: hasDryWeight
                ? '${plant.dryWeight!.toStringAsFixed(1)} g'
                : 'Pending',
            muted: !hasDryWeight,
          ),
          _metric(
            context,
            label: 'Yield',
            value:
                hasDryWeight ? '${yieldPercent!.toStringAsFixed(1)} %' : '--',
            highlight: hasDryWeight,
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    bool muted = false,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTypography.bodySmall(context)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.labelLarge(context).copyWith(
            color: highlight
                ? AppColors.growing
                : muted
                    ? context.colTextMuted
                    : context.colTextPrimary,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
