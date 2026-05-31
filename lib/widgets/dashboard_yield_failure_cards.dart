import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../models/plant_note.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class DashboardYieldFailureCards extends StatelessWidget {
  final List<Plant> plants;
  final List<PlantNote> notes;

  const DashboardYieldFailureCards({
    super.key,
    required this.plants,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    // Harvests with a recorded dry weight — primary yield source.
    final harvested = plants.where((p) =>
        p.isArchived &&
        p.status == PlantStatus.harvested &&
        p.dryWeight != null &&
        p.dryWeight! > 0);

    final removed = plants.where((p) => p.status == PlantStatus.removed);

    final dryWeights = harvested.map((p) => p.dryWeight!).toList();

    final avgDryWeight = dryWeights.isNotEmpty
        ? dryWeights.reduce((a, b) => a + b) / dryWeights.length
        : null;

    final bestDryWeight =
        dryWeights.isNotEmpty ? dryWeights.reduce((a, b) => a > b ? a : b) : null;

    // Wet→dry ratio (drying efficiency) — only for plants with both weights.
    final harvestedWithBoth = plants.where((p) =>
        p.isArchived &&
        p.status == PlantStatus.harvested &&
        p.wetWeight != null &&
        p.dryWeight != null &&
        p.wetWeight! > 0);
    final ratios = harvestedWithBoth
        .map((p) => (p.dryWeight! / p.wetWeight!) * 100)
        .toList();
    final avgRatio = ratios.isNotEmpty
        ? ratios.reduce((a, b) => a + b) / ratios.length
        : null;

    final failureReasonCounts = <String, int>{};
    for (final note in notes.where((n) => n.category == NoteCategory.issue)) {
      failureReasonCounts[note.content] =
          (failureReasonCounts[note.content] ?? 0) + 1;
    }

    final topFailure = failureReasonCounts.isNotEmpty
        ? failureReasonCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
        : null;

    final failureRate =
        plants.isNotEmpty ? (removed.length / plants.length) * 100 : 0.0;

    return Column(
      children: [
        _card(
          context,
          title: 'Yield Overview',
          color: AppColors.growing,
          rows: [
            _row(context, 'Avg Dry Weight',
                avgDryWeight != null ? '${avgDryWeight.toStringAsFixed(1)} g' : '—'),
            _row(context, 'Best Dry Weight',
                bestDryWeight != null ? '${bestDryWeight.toStringAsFixed(1)} g' : '—'),
            _row(
              context,
              'Wet→Dry Ratio',
              avgRatio != null ? '${avgRatio.toStringAsFixed(1)}%' : '—',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _card(
          context,
          title: 'Failure Overview',
          color: AppColors.danger,
          rows: [
            _row(context, 'Plants Removed', removed.length.toString()),
            _row(context, 'Failure Rate', '${failureRate.toStringAsFixed(1)}%'),
            _row(context, 'Top Issue',
                topFailure != null ? topFailure.key : '—'),
          ],
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required Color color,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  AppTypography.headlineSmall(context).copyWith(color: color)),
          const SizedBox(height: AppSpacing.sm),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall(context)),
          Text(value, style: AppTypography.labelLarge(context)),
        ],
      ),
    );
  }
}
