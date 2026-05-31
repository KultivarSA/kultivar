import 'package:flutter/material.dart';

import '../models/grow_space.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class DashboardSpaceAnalytics extends StatelessWidget {
  final GrowSpace space;
  final List<Plant> plants;
  final List<PlantNote> notes;

  const DashboardSpaceAnalytics({
    super.key,
    required this.space,
    required this.plants,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final spacePlants = plants.where((p) => p.growSpaceId == space.id);

    final harvested = spacePlants.where((p) =>
        p.isArchived &&
        p.status == PlantStatus.harvested &&
        p.dryWeight != null &&
        p.dryWeight! > 0);

    final removed = spacePlants.where((p) => p.status == PlantStatus.removed);

    // Wet→dry ratio: useful as a drying-efficiency indicator.
    final harvestedWithBoth = spacePlants.where((p) =>
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

    final avgDryWeight = harvested.isNotEmpty
        ? harvested.map((p) => p.dryWeight!).reduce((a, b) => a + b) /
            harvested.length
        : null;

    final totalPlants = spacePlants.length;
    final failureRate =
        totalPlants > 0 ? (removed.length / totalPlants) * 100 : 0.0;

    final failureNotes = notes.where((n) =>
        removed.any((p) => p.id == n.plantId) &&
        n.category == NoteCategory.issue);

    final reasonCounts = <String, int>{};
    for (final note in failureNotes) {
      reasonCounts[note.content] = (reasonCounts[note.content] ?? 0) + 1;
    }

    final topReason = reasonCounts.isNotEmpty
        ? reasonCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(space.name, style: AppTypography.headlineSmall(context)),
          Text(space.type, style: AppTypography.bodySmall(context)),
          const SizedBox(height: AppSpacing.sm),
          _row(context, 'Completed Harvests', harvested.length.toString()),
          _row(
            context,
            'Avg Dry Weight',
            avgDryWeight != null ? '${avgDryWeight.toStringAsFixed(1)} g' : '—',
          ),
          _row(
            context,
            'Wet→Dry Ratio',
            avgRatio != null ? '${avgRatio.toStringAsFixed(1)}%' : '—',
          ),
          Divider(height: AppSpacing.lg, color: context.colBorder),
          _row(context, 'Plants Removed', removed.length.toString(),
              color: AppColors.danger),
          _row(context, 'Failure Rate', '${failureRate.toStringAsFixed(1)}%',
              color: AppColors.danger),
          _row(context, 'Top Issue', topReason ?? '—', color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall(context)),
          Text(
            value,
            style: AppTypography.labelLarge(context).copyWith(
              color: color ?? context.colTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
