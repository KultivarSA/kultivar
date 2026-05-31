import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class StrainYieldBarChart extends StatelessWidget {
  final List<Plant> plants;

  const StrainYieldBarChart({
    super.key,
    required this.plants,
  });

  @override
  Widget build(BuildContext context) {
    final harvested = plants.where(
        (p) => p.wetWeight != null && p.dryWeight != null && p.wetWeight! > 0);

    if (harvested.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: context.colBorder),
        ),
        child: Center(
          child: Text(
            'No yield data yet',
            style: AppTypography.bodyMedium(context),
          ),
        ),
      );
    }

    // Build data points — one bar per plant sorted by date
    final data = harvested.toList()
      ..sort((a, b) => (a.harvestedDate ?? a.startDate)
          .compareTo(b.harvestedDate ?? b.startDate));

    final yields =
        data.map((p) => (p.dryWeight! / p.wetWeight!) * 100).toList();
    final maxY = yields.reduce((a, b) => a > b ? a : b);
    final avgY = yields.reduce((a, b) => a + b) / yields.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Yield per Harvest',
                  style: AppTypography.headlineSmall(context)),
              Text(
                'Avg ${avgY.toStringAsFixed(1)}%',
                style: AppTypography.labelLarge(context)
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Chart
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((entry) {
                final idx = entry.key;
                final plant = entry.value;
                final yieldPct = (plant.dryWeight! / plant.wetWeight!) * 100;
                final fraction = maxY > 0 ? yieldPct / maxY : 0.0;
                final isAboveAvg = yieldPct >= avgY;
                final barColor =
                    isAboveAvg ? AppColors.primary : AppColors.harvested;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Value label
                        Text(
                          '${yieldPct.toStringAsFixed(0)}%',
                          style: AppTypography.labelSmall(context)
                              .copyWith(color: barColor, fontSize: 9),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        // Bar
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400 + idx * 50),
                          curve: Curves.easeOut,
                          height: 80 * fraction,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Average line label
          Row(children: [
            Container(
              width: 20,
              height: 2,
              color: context.colTextMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('Average', style: AppTypography.bodySmall(context)),
          ]),
        ],
      ),
    );
  }
}
