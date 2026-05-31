import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ── Per-stage metadata ─────────────────────────────────────────────────────

class _StageInfo {
  final IconData icon;
  final Color color;
  final String tipHeading;
  final String tipBody;
  const _StageInfo({
    required this.icon,
    required this.color,
    required this.tipHeading,
    required this.tipBody,
  });
}

const _stageInfo = <GrowStage, _StageInfo>{
  GrowStage.germination: _StageInfo(
    icon: Icons.grain_rounded,
    color: AppColors.growing,
    tipHeading: 'Keep it warm & moist',
    tipBody:
        'Aim for 22–26 °C with 70–80 % RH. No nutrients yet — '
        'the seed contains everything it needs to sprout.',
  ),
  GrowStage.seedling: _StageInfo(
    icon: Icons.eco_rounded,
    color: AppColors.growing,
    tipHeading: 'Gentle light, high humidity',
    tipBody:
        'Keep humidity 65–80 % and light at low intensity (18/6). '
        'Avoid overwatering — water only when the top centimetre is dry.',
  ),
  GrowStage.vegetative: _StageInfo(
    icon: Icons.forest_rounded,
    color: AppColors.growing,
    tipHeading: 'Feed nitrogen, push growth',
    tipBody:
        'Target 50–70 % RH and 18/6 light. Nitrogen-heavy feeds '
        'support rapid canopy development. Top or LST now for better yields.',
  ),
  GrowStage.stretch: _StageInfo(
    icon: Icons.height_rounded,
    color: AppColors.drying,
    tipHeading: 'Plants double in size — be ready',
    tipBody:
        'Drop humidity to 40–60 % and switch to 12/12. Stake or '
        'screen branches now. Taper nitrogen; introduce phosphorus.',
  ),
  GrowStage.earlyFlower: _StageInfo(
    icon: Icons.local_florist_rounded,
    color: AppColors.curing,
    tipHeading: 'Bud sites forming',
    tipBody:
        'Hold 40–55 % RH to prevent bud rot. Boost phosphorus and '
        'potassium. Watch for pistil colour as an early ripeness signal.',
  ),
  GrowStage.lateFlower: _StageInfo(
    icon: Icons.spa_rounded,
    color: AppColors.curing,
    tipHeading: 'Maximise trichome development',
    tipBody:
        'Keep humidity below 50 %. Check trichome colour with a loupe — '
        'cloudy = potent, amber = more sedative. Reduce feeds gradually.',
  ),
  GrowStage.flush: _StageInfo(
    icon: Icons.water_drop_rounded,
    color: AppColors.water,
    tipHeading: 'Final flush before harvest',
    tipBody:
        'Feed plain pH\'d water for the last 1–2 weeks. This clears '
        'residual nutrients and can improve the final taste and smoothness.',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────

/// Slides up a stage-specific milestone bottom sheet.
///
/// Returns `true` when the user confirms the stage change, `false` / null on
/// cancel.
Future<bool> showStageMilestoneSheet(
  BuildContext context,
  GrowStage newStage,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StageMilestoneSheet(stage: newStage),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _StageMilestoneSheet extends StatelessWidget {
  final GrowStage stage;
  const _StageMilestoneSheet({required this.stage});

  @override
  Widget build(BuildContext context) {
    final info = _stageInfo[stage]!;
    final c = info.color;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.lg + bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),

          // ── Stage icon ───────────────────────
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  c.withValues(alpha: 0.25),
                  c.withValues(alpha: 0.06),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: c.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Icon(info.icon, color: c, size: 32),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Stage label ──────────────────────
          Text(
            stage.label,
            style: AppTypography.headlineLarge(context).copyWith(color: c),
          ),
          const SizedBox(height: 2),
          Text(
            'Entering new growth stage',
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Tip card ─────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: c.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 14, color: c),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      info.tipHeading,
                      style: AppTypography.labelLarge(context)
                          .copyWith(color: c, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  info.tipBody,
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted, height: 1.45),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Confirm button ───────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(info.icon, size: 17),
              label: Text('Enter ${stage.label}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
                textStyle: AppTypography.labelLarge(context).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Cancel ───────────────────────────
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              child: Text(
                'Keep Current Stage',
                style: AppTypography.labelLarge(context).copyWith(
                  color: context.colTextSecondary,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
