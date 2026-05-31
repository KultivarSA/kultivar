import 'package:flutter/material.dart';

import '../models/grow_space.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../screens/harvest_archive_screen.dart';
import '../screens/plant_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class DashboardTrendInsights extends StatelessWidget {
  final List<Plant> plants;
  final List<PlantNote> notes;
  final List<GrowSpace> spaces;

  const DashboardTrendInsights({
    super.key,
    required this.plants,
    required this.notes,
    required this.spaces,
  });

  @override
  Widget build(BuildContext context) {
    final insights = <_Insight>[];

    final removedPlants =
        plants.where((p) => p.status == PlantStatus.removed).toList();

    if (removedPlants.length >= 3) {
      insights.add(_Insight.warning(
        'Multiple plants removed (${removedPlants.length})',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HarvestArchiveScreen()),
        ),
      ));
    }

    final failureRate =
        plants.isNotEmpty ? (removedPlants.length / plants.length) * 100 : 0.0;

    if (failureRate >= 30) {
      insights.add(_Insight.warning(
        'High failure rate (${failureRate.toStringAsFixed(1)}%)',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HarvestArchiveScreen()),
        ),
      ));
    }

    final issueNotes =
        notes.where((n) => n.category == NoteCategory.issue).toList();
    final issueCounts = <String, int>{};
    for (final note in issueNotes) {
      issueCounts[note.content] = (issueCounts[note.content] ?? 0) + 1;
    }

    for (final entry in issueCounts.entries) {
      if (entry.value >= 2 && removedPlants.isNotEmpty) {
        insights.add(_Insight.warning(
          'Repeated issue detected: ${entry.key}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlantDetailScreen(plant: removedPlants.first),
            ),
          ),
        ));
      }
    }

    final completedHarvests = plants.where((p) =>
        p.isArchived &&
        p.status == PlantStatus.harvested &&
        p.wetWeight != null &&
        p.dryWeight != null &&
        p.wetWeight! > 0);

    if (completedHarvests.isNotEmpty) {
      final yields = completedHarvests
          .map((p) => (p.dryWeight! / p.wetWeight!) * 100)
          .toList();
      final avgYield = yields.reduce((a, b) => a + b) / yields.length;

      if (avgYield >= 25) {
        insights.add(_Insight.good(
          'Healthy average yield (${avgYield.toStringAsFixed(1)}%)',
        ));
      } else if (avgYield < 20) {
        insights.add(_Insight.warning(
          'Low average yield (${avgYield.toStringAsFixed(1)}%)',
        ));
      }
    }

    final spaceYields = <String, double>{};
    for (final space in spaces) {
      final sh = completedHarvests.where((p) => p.growSpaceId == space.id);
      if (sh.isEmpty) continue;
      final avg = sh
              .map((p) => (p.dryWeight! / p.wetWeight!) * 100)
              .reduce((a, b) => a + b) /
          sh.length;
      spaceYields[space.name] = avg;
    }

    if (spaceYields.length >= 2) {
      final sorted = spaceYields.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final best = sorted.first;
      final worst = sorted.last;
      if (best.value - worst.value >= 5) {
        insights.add(_Insight.good(
          'Best performing space: ${best.key}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HarvestArchiveScreen()),
          ),
        ));
      }
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trends & Warnings', style: AppTypography.headlineSmall(context)),
        const SizedBox(height: AppSpacing.sm),
        ...insights.map((i) => _buildCard(context, i)),
      ],
    );
  }

  Widget _buildCard(BuildContext context, _Insight insight) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: insight.color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(insight.icon, color: insight.color, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(insight.message,
              style: AppTypography.bodyMedium(context)
                  .copyWith(color: insight.color)),
        ),
        if (insight.onTap != null)
          Icon(Icons.chevron_right, color: context.colTextMuted, size: 16),
      ]),
    );

    return insight.onTap == null
        ? card
        : InkWell(
            onTap: insight.onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: card,
          );
  }
}

class _Insight {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _Insight._(this.message, this.color, this.icon, {this.onTap});

  factory _Insight.warning(String message, {VoidCallback? onTap}) =>
      _Insight._(message, AppColors.danger, Icons.warning_rounded,
          onTap: onTap);

  factory _Insight.good(String message, {VoidCallback? onTap}) =>
      _Insight._(message, AppColors.growing, Icons.trending_up, onTap: onTap);
}
