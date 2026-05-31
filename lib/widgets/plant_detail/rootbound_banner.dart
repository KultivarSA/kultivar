import 'package:flutter/material.dart';

import '../../models/plant.dart';
import '../../models/plant_note.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/pot_label.dart';

/// Warns when a plant's last transplant was so long ago its roots are
/// probably hitting pot limits.  Tap → caller-supplied transplant log
/// callback.
///
/// Risk thresholds depend on pot size: tiny pots (< 3 L) trip at 14 d,
/// medium (3-7 L) at 21 d, large (7-15 L) at 42 d, and big fabric pots
/// (≥ 15 L) at 70 d.  Suppressed during flower because transplanting
/// after stretch is risky.
///
/// Extracted from `plant_detail_screen.dart` (Q1a).
class RootboundBanner extends StatelessWidget {
  final Plant plant;
  final List<PlantNote> notes;
  final VoidCallback onLogTransplant;

  const RootboundBanner({
    super.key,
    required this.plant,
    required this.notes,
    required this.onLogTransplant,
  });

  /// Days to rootbound risk by pot size (litres).
  static int _riskDays(double litres) {
    if (litres < 3) return 14;
    if (litres < 7) return 21;
    if (litres < 15) return 42;
    return 70;
  }

  @override
  Widget build(BuildContext context) {
    // Only warn for actively growing plants
    if (plant.status != PlantStatus.growing) return const SizedBox.shrink();
    // Don't warn during flower — transplanting is risky
    if (plant.growStage == GrowStage.earlyFlower ||
        plant.growStage == GrowStage.lateFlower ||
        plant.growStage == GrowStage.flush) {
      return const SizedBox.shrink();
    }

    final potSize = plant.potSizeLitres!;
    // Find most recent transplant date (or plant start date)
    final lastTransplant = notes
        .where((n) => n.category == NoteCategory.transplant)
        .fold<DateTime?>(
            null,
            (best, n) =>
                best == null || n.createdAt.isAfter(best) ? n.createdAt : best);
    final since = lastTransplant ?? plant.startDate;
    final daysSince = DateTime.now().difference(since).inDays;
    final riskThreshold = _riskDays(potSize);

    if (daysSince < riskThreshold) return const SizedBox.shrink();

    final overdue = daysSince - riskThreshold;
    final isUrgent = overdue >= 7;

    return GestureDetector(
      onTap: onLogTransplant,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: (isUrgent ? AppColors.warning : AppColors.growing)
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: (isUrgent ? AppColors.warning : AppColors.growing)
                .withValues(alpha: 0.40),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.yard_rounded,
              size: 16,
              color: isUrgent ? AppColors.warning : AppColors.growing,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrgent
                        ? 'Rootbound risk — consider transplanting'
                        : 'Roots may be approaching pot limits',
                    style: AppTypography.labelSmall(context).copyWith(
                      color:
                          isUrgent ? AppColors.warning : AppColors.growing,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    // potLabel comes from lib/utils/pot_label.dart — same
                    // formatting as the plant header so the user sees
                    // consistent "5 L" / "25 L+" labels everywhere.
                    '${daysSince}d in ${potLabel(potSize)} pot · Tap to log transplant',
                    style: AppTypography.bodySmall(context).copyWith(
                      fontSize: 10,
                      color: context.colTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: isUrgent ? AppColors.warning : AppColors.growing),
          ],
        ),
      ),
    );
  }
}
