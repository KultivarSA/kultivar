import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';

class PlantLifecycleStepper extends StatelessWidget {
  final Plant plant;

  const PlantLifecycleStepper({
    super.key,
    required this.plant,
  });

  @override
  Widget build(BuildContext context) {
    if (plant.status == PlantStatus.removed) {
      return _removedState(context);
    }

    if (plant.status == PlantStatus.completed || plant.isArchived) {
      return _completedState(context);
    }

    final steps = [
      PlantStatus.growing,
      PlantStatus.harvested,
      PlantStatus.drying,
      PlantStatus.curing,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        steps.length * 2 - 1,
        (index) {
          if (index.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: _lineColor(context, steps[index ~/ 2], plant.status),
              ),
            );
          }
          final step = steps[index ~/ 2];
          return _step(
            context,
            label: _label(step),
            isActive: _isActive(step),
            isCompleted: _isCompleted(step),
            dateLabel: _dateForStep(step),
          );
        },
      ),
    );
  }

  // ── Step dot ──────────────────────────────────

  Widget _step(
    BuildContext context, {
    required String label,
    required bool isActive,
    required bool isCompleted,
    String? dateLabel,
  }) {
    final color = isCompleted
        ? AppColors.growing
        : isActive
            ? AppColors.harvested
            : context.colTextMuted;

    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.labelSmall(context).copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (dateLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            dateLabel,
            style: AppTypography.labelSmall(context).copyWith(
              color: color.withValues(alpha: 0.65),
              fontSize: 9,
            ),
          ),
        ],
      ],
    );
  }

  // ── Terminal states ───────────────────────────

  Widget _removedState(BuildContext context) {
    return Row(children: [
      const Icon(Icons.cancel, color: AppColors.danger, size: 20),
      const SizedBox(width: AppSpacing.sm),
      Text(
        'Plant Removed',
        style:
            AppTypography.labelLarge(context).copyWith(color: AppColors.danger),
      ),
    ]);
  }

  Widget _completedState(BuildContext context) {
    return Row(children: [
      const Icon(Icons.verified, color: AppColors.completed, size: 20),
      const SizedBox(width: AppSpacing.sm),
      Text(
        'Lifecycle Complete',
        style: AppTypography.labelLarge(context)
            .copyWith(color: AppColors.completed),
      ),
      const Spacer(),
      Text(
        plant.archivedAt != null
            ? 'Archived ${fmtShortDate(plant.archivedAt!)}'
            : '',
        style: AppTypography.bodySmall(context),
      ),
    ]);
  }

  // ── Helpers ───────────────────────────────────

  bool _isCompleted(PlantStatus step) => _order(step) < _order(plant.status);

  bool _isActive(PlantStatus step) => step == plant.status;

  Color _lineColor(BuildContext context, PlantStatus step, PlantStatus current) =>
      _order(step) < _order(current) ? AppColors.growing : context.colBorder;

  int _order(PlantStatus status) {
    switch (status) {
      case PlantStatus.growing:
        return 0;
      case PlantStatus.harvested:
        return 1;
      case PlantStatus.drying:
        return 2;
      case PlantStatus.curing:
        return 3;
      case PlantStatus.completed:
        return 4;
      case PlantStatus.removed:
        return 99;
    }
  }

  String _label(PlantStatus status) {
    switch (status) {
      case PlantStatus.growing:
        return 'Grow';
      case PlantStatus.harvested:
        return 'Harvest';
      case PlantStatus.drying:
        return 'Dry';
      case PlantStatus.curing:
        return 'Cure';
      case PlantStatus.completed:
        return 'Done';
      case PlantStatus.removed:
        return 'Removed';
    }
  }

  /// Returns a short date label for each lifecycle step:
  /// • Growing  → start date
  /// • Harvested → harvest date
  /// • Drying   → drying end / due date
  /// • Curing   → curing end / due date
  String? _dateForStep(PlantStatus step) {
    DateTime? dt;
    switch (step) {
      case PlantStatus.growing:
        dt = plant.startDate;
      case PlantStatus.harvested:
        dt = plant.harvestedDate;
      case PlantStatus.drying:
        dt = plant.dryingEndDate;
      case PlantStatus.curing:
        dt = plant.curingEndDate;
      default:
        dt = null;
    }
    return dt != null ? fmtShortDate(dt) : null;
  }
}
