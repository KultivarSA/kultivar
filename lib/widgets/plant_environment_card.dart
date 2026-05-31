import 'package:flutter/material.dart';

import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/plant_environment_analytics.dart';
import '../utils/stage_duration_analytics.dart';
import '../utils/temp_format.dart';
import '../utils/vpd_analytics.dart';

class PlantEnvironmentCard extends StatelessWidget {
  final Plant plant;
  final List<EnvironmentLog> logs;
  final GrowSpace? space;

  /// Pre-computed historical averages — pass from the call site using
  /// `computeHistoricalAverages(repo.plants)` so the widget stays pure.
  final HistoricalStageDurations? historicalDurations;

  const PlantEnvironmentCard({
    super.key,
    required this.plant,
    required this.logs,
    this.space,
    this.historicalDurations,
  });

  @override
  Widget build(BuildContext context) {
    if (space == null && logs.isEmpty) return const SizedBox.shrink();

    final stay = space != null
        ? PlantEnvironmentAnalytics.buildSpaceStay(
            plant: plant,
            space: space!,
            logs: logs,
          )
        : null;

    final phaseOptimal = space != null
        ? PlantEnvironmentAnalytics.computePhaseOptimalPercent(
            plant: plant,
            space: space!,
            logs: logs,
          )
        : <GrowPhase, double>{};

    final insights = space != null
        ? PlantEnvironmentAnalytics.generateInsights(
            plant: plant,
            logs: logs,
            space: space!,
          )
        : <PlantEnvironmentInsight>[];

    final vpdSummary = computePlantVpdAnalytics(plant, logs);
    final durations = computeStageDurations(plant);

    // Only render the card when there is at least one section worth showing.
    final hasEnvData = stay != null;
    final hasVpd = vpdSummary.hasData;
    final hasDurations = durations.totalGrowDays > 0;

    if (!hasEnvData && !hasVpd && !hasDurations) {
      return const SizedBox.shrink();
    }

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
          // ── Header ───────────────────────────────
          Row(children: [
            const Icon(Icons.thermostat, color: AppColors.drying, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text('Environment Summary',
                style: AppTypography.headlineSmall(context)),
          ]),

          // ── Avg metrics row ───────────────────────
          if (hasEnvData) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                _metric(
                  context,
                  'Time in Space',
                  '${stay.duration.inDays}d',
                  context.colTextSecondary,
                ),
                if (stay.avgTemp != null)
                  _metric(
                    context,
                    'Avg Temp',
                    formatTemp(stay.avgTemp!),
                    Colors.orange,
                  ),
                if (stay.avgHumidity != null)
                  _metric(
                    context,
                    'Avg RH',
                    '${stay.avgHumidity!.toStringAsFixed(1)}%',
                    AppColors.water,
                  ),
              ],
            ),
          ],

          // ── Per-phase optimal zone ────────────────
          if (phaseOptimal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.sm),
            _sectionHeader(
                context, Icons.thermostat_rounded, 'Optimal Zone by Phase'),
            const SizedBox(height: AppSpacing.sm),
            ...GrowPhase.values
                .where((p) => phaseOptimal.containsKey(p))
                .map((p) => _optimalPhaseRow(context, p, phaseOptimal[p]!)),
          ],

          // ── VPD by phase ──────────────────────────
          if (hasVpd) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.sm),
            _sectionHeader(context, Icons.air_rounded, 'VPD by Phase'),
            const SizedBox(height: AppSpacing.sm),
            ...vpdSummary.phases.map((r) => _vpdPhaseRow(context, r)),
            const SizedBox(height: AppSpacing.xxs),
            // Overall summary line
            Text(
              '${vpdSummary.totalReadings} readings · '
              '${vpdSummary.overallPctInRange.toStringAsFixed(0)}% '
              'within target overall',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted, fontSize: 11),
            ),
          ],

          // ── Stage durations ───────────────────────
          if (hasDurations) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.sm),
            _sectionHeader(context, Icons.timeline_rounded, 'Stage Durations'),
            const SizedBox(height: AppSpacing.sm),
            _stageDurationsBody(context, durations),
          ],

          // ── Text insights ─────────────────────────
          if (insights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.sm),
            ...insights.map((i) => _insightRow(context, i)),
          ],
        ],
      ),
    );
  }

  // ── Optimal zone phase row ───────────────────────────────────────────────

  Widget _optimalPhaseRow(
      BuildContext context, GrowPhase phase, double pct) {
    final color = pct >= 75
        ? AppColors.optimal
        : pct >= 50
            ? AppColors.warning
            : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              phase.label,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextSecondary, fontSize: 12),
            ),
          ),
          // % badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              style: AppTypography.labelSmall(context).copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Bar
          Expanded(
            child: LayoutBuilder(builder: (ctx, constraints) {
              return Stack(children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colSurface3,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
                Container(
                  height: 4,
                  width: constraints.maxWidth * (pct / 100).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ]);
            }),
          ),
        ],
      ),
    );
  }

  // ── VPD phase row ─────────────────────────────────────────────────────────

  Widget _vpdPhaseRow(BuildContext context, VpdPhaseResult r) {
    final color = _vpdColor(r.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          // Phase label
          SizedBox(
            width: 80,
            child: Text(
              r.phase.label,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextSecondary, fontSize: 12),
            ),
          ),

          // Avg VPD chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${r.avgVpd.toStringAsFixed(2)} kPa',
              style: AppTypography.labelSmall(context).copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // % in range bar + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                LayoutBuilder(builder: (ctx, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.colSurface3,
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull),
                        ),
                      ),
                      Container(
                        height: 4,
                        width: constraints.maxWidth *
                            (r.pctInRange / 100).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 3),
                Text(
                  '${r.pctInRange.toStringAsFixed(0)}% in range '
                  '· target ${r.phase.targetLabel}',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: context.colTextMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stage durations body ──────────────────────────────────────────────────

  Widget _stageDurationsBody(
      BuildContext context, StageDurations durations) {
    final hist = historicalDurations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Veg + flower side-by-side if flip data available
        if (durations.hasFlipBreakdown) ...[
          Row(
            children: [
              _durationTile(
                context,
                label: 'Vegetative',
                days: durations.vegDays!,
                compareDays: hist?.avgVegDays,
                color: AppColors.growing,
                icon: Icons.eco_rounded,
              ),
              const SizedBox(width: AppSpacing.sm),
              _durationTile(
                context,
                label: 'Flower',
                days: durations.flowerDays!,
                compareDays: hist?.avgFlowerDays,
                color: AppColors.harvested,
                icon: Icons.local_florist_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else ...[
          // No flip date — show total grow days only
          _durationTile(
            context,
            label: 'Total Grow',
            days: durations.totalGrowDays,
            compareDays: hist?.avgTotalGrowDays,
            color: AppColors.growing,
            icon: Icons.schedule_rounded,
            note: durations.isOngoing ? 'ongoing' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Drying + curing if reached those stages
        if (durations.dryingDays != null || durations.curingDays != null) ...[
          Row(
            children: [
              if (durations.dryingDays != null)
                Expanded(
                  child: _durationTile(
                    context,
                    label: 'Drying',
                    days: durations.dryingDays!,
                    compareDays: hist?.avgDryingDays,
                    color: AppColors.drying,
                    icon: Icons.air_rounded,
                    note: plant.status == PlantStatus.drying ||
                            plant.status == PlantStatus.harvested
                        ? 'in progress'
                        : null,
                  ),
                ),
              if (durations.dryingDays != null && durations.curingDays != null)
                const SizedBox(width: AppSpacing.sm),
              if (durations.curingDays != null)
                Expanded(
                  child: _durationTile(
                    context,
                    label: 'Curing',
                    days: durations.curingDays!,
                    compareDays: null,
                    color: AppColors.curing,
                    icon: Icons.inventory_2_rounded,
                    note: plant.status == PlantStatus.curing
                        ? 'in progress'
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Target variance
        if (durations.targetVarianceDays != null) ...[
          _varianceRow(context, durations.targetVarianceDays!),
        ],
      ],
    );
  }

  Widget _durationTile(
    BuildContext context, {
    required String label,
    required int days,
    required double? compareDays,
    required Color color,
    required IconData icon,
    String? note,
  }) {
    final diffDays = compareDays != null ? days - compareDays.round() : null;
    final diffText = diffDays != null
        ? (diffDays > 0
            ? '+${diffDays}d vs avg'
            : diffDays < 0
                ? '${diffDays}d vs avg'
                : 'on avg')
        : null;
    final diffColor = diffDays == null
        ? context.colTextMuted
        : diffDays.abs() <= 3
            ? AppColors.optimal
            : AppColors.warning;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  label,
                  style: AppTypography.labelSmall(context).copyWith(
                    color: color,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${days}d',
              style: AppTypography.headlineSmall(context).copyWith(
                color: context.colTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (diffText != null)
              Text(
                diffText,
                style: AppTypography.bodySmall(context).copyWith(
                  color: diffColor,
                  fontSize: 10,
                ),
              )
            else if (note != null)
              Text(
                note,
                style: AppTypography.bodySmall(context).copyWith(
                  color: context.colTextMuted,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _varianceRow(BuildContext context, int varianceDays) {
    final isLate = varianceDays > 0;
    final isEarly = varianceDays < 0;
    final abs = varianceDays.abs();
    final color = abs <= 3
        ? AppColors.optimal
        : abs <= 7
            ? AppColors.warning
            : AppColors.danger;
    final label = isLate
        ? 'Harvested ${abs}d after target'
        : isEarly
            ? 'Harvested ${abs}d before target'
            : 'Harvested on target date';

    return Row(
      children: [
        Icon(Icons.flag_rounded, size: 13, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.bodySmall(context)
              .copyWith(color: color, fontSize: 11),
        ),
      ],
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _sectionHeader(
      BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.colTextMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: AppTypography.labelSmall(context).copyWith(
            color: context.colTextMuted,
            letterSpacing: 0.8,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ── Insight row ───────────────────────────────────────────────────────────

  Widget _insightRow(BuildContext context, PlantEnvironmentInsight i) {
    final color = i.severity == InsightSeverity.positive
        ? AppColors.growing
        : i.severity == InsightSeverity.warning
            ? AppColors.warning
            : context.colTextMuted;
    final icon = i.severity == InsightSeverity.positive
        ? Icons.check_circle
        : i.severity == InsightSeverity.warning
            ? Icons.warning_rounded
            : Icons.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(i.message,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  // ── Metric tile ───────────────────────────────────────────────────────────

  Widget _metric(
      BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style:
                AppTypography.headlineSmall(context).copyWith(color: color)),
        Text(label, style: AppTypography.bodySmall(context)),
      ],
    );
  }

  // ── VPD status → colour ───────────────────────────────────────────────────

  static Color _vpdColor(VpdStatus status) {
    switch (status) {
      case VpdStatus.ideal:
        return AppColors.optimal;
      case VpdStatus.high:
        return AppColors.danger;
      case VpdStatus.low:
        return const Color(0xFF64B5F6); // light blue
    }
  }
}
