import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'stage_milestone_sheet.dart';

class GrowStageStepper extends StatelessWidget {
  final Plant plant;
  final void Function(GrowStage stage) onStageChanged;

  const GrowStageStepper({
    super.key,
    required this.plant,
    required this.onStageChanged,
  });

  // Fixed cell/connector widths keep dots + labels aligned
  static const double _cellW = 48;
  static const double _connW = 20;

  Color _color(GrowStage stage) {
    switch (stage) {
      case GrowStage.germination:
      case GrowStage.seedling:
      case GrowStage.vegetative:
        return AppColors.growing;
      case GrowStage.stretch:
        return AppColors.drying;
      case GrowStage.earlyFlower:
      case GrowStage.lateFlower:
        return AppColors.curing;
      case GrowStage.flush:
        return AppColors.completed;
    }
  }

  void _confirmChange(
    BuildContext context,
    GrowStage newStage,
    GrowStage current,
  ) async {
    if (newStage == current) return;
    final confirmed = await showStageMilestoneSheet(context, newStage);
    if (confirmed) onStageChanged(newStage);
  }

  @override
  Widget build(BuildContext context) {
    final current = plant.growStage ?? GrowStage.germination;
    const all = GrowStage.values;

    // Build dots and labels as separate rows for pixel-perfect alignment
    final dotCells = <Widget>[];
    final labelCells = <Widget>[];

    for (int i = 0; i < all.length; i++) {
      final stage = all[i];
      final isCurrent = stage == current;
      final isPast = stage.order < current.order;
      final color = _color(stage);
      final dotSize = isCurrent ? 20.0 : 14.0;

      // Dot cell
      dotCells.add(
        GestureDetector(
          onTap: () => _confirmChange(context, stage, current),
          child: SizedBox(
            width: _cellW,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isCurrent || isPast) ? color : Colors.transparent,
                  border: Border.all(
                    color: (isCurrent || isPast) ? color : context.colBorder,
                    width: isCurrent ? 2 : 1.5,
                  ),
                ),
                child: isCurrent
                    ? const Icon(Icons.circle, size: 7, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
      );

      // Label cell
      labelCells.add(SizedBox(
        width: _cellW,
        child: Text(
          stage.shortLabel,
          style: TextStyle(
            fontSize: 9,
            color: isCurrent
                ? color
                : isPast
                    ? color.withValues(alpha: 0.5)
                    : context.colTextMuted,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ));

      // Connector between dots
      if (i < all.length - 1) {
        final connColor =
            stage.order < current.order ? _color(stage) : context.colBorder;

        dotCells.add(SizedBox(
          width: _connW,
          child: Center(
            child: Container(height: 2, color: connColor),
          ),
        ));
        labelCells.add(const SizedBox(width: _connW));
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: _color(current).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Growth Stage',
                      style: AppTypography.headlineSmall(context)),
                  if (plant.isAutoflower) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.drying.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                            color: AppColors.drying.withValues(alpha: 0.4)),
                      ),
                      child: Text('AUTO',
                          style: AppTypography.labelSmall(context).copyWith(
                              color: AppColors.drying,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color(current).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border:
                      Border.all(color: _color(current).withValues(alpha: 0.4)),
                ),
                child: Text(
                  current.label,
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: _color(current)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Scrollable stepper ──────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: dotCells),
                const SizedBox(height: AppSpacing.xxs),
                Row(children: labelCells),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap any stage to update',
            style: AppTypography.bodySmall(context),
          ),
        ],
      ),
    );
  }
}
