import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/subscription_tier_config.dart';
import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/temp_format.dart';
import 'chart_theme.dart';
import 'pro_gate.dart';

class EnvironmentChart extends StatefulWidget {
  final List<EnvironmentLog> logs;
  final GrowSpace space;

  const EnvironmentChart({
    super.key,
    required this.logs,
    required this.space,
  });

  @override
  State<EnvironmentChart> createState() => _EnvironmentChartState();
}

class _EnvironmentChartState extends State<EnvironmentChart> {
  // Time-window selector state.
  String _range = '30d'; // '7d' | '30d' | 'all'

  // Returns logs sorted oldest → newest and clipped to the chosen window,
  // itself clamped to the tier's analytics-history allowance ('all' and
  // any window past 60 days collapse to 60 days on Free).
  List<EnvironmentLog> _filtered(SubscriptionTier tier) {
    final sorted = [...widget.logs]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final requested = _range == 'all' ? null : (_range == '7d' ? 7 : 30);
    final days = FreeTierGate.clampHistoryDays(tier, requested);
    if (days == null) return sorted;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return sorted.where((l) => l.recordedAt.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tier =
        context.select<SubscriptionService, SubscriptionTier>((s) => s.tier);
    final logs = _filtered(tier);
    final allLocked = !tier.hasUnlimitedFeatures;

    // Need at least two points to draw a line.
    final hasTempData = logs.where((l) => l.temperature != null).length >= 2;
    final hasHumData = logs.where((l) => l.humidity != null).length >= 2;

    if (!hasTempData && !hasHumData) {
      return _emptyState(context);
    }

    // Build spot lists — x = index in `logs` so the date lookup in tooltips
    // is simply logs[spot.x.toInt()].
    final tempSpots = <FlSpot>[];
    final humSpots = <FlSpot>[];
    for (var i = 0; i < logs.length; i++) {
      final l = logs[i];
      if (l.temperature != null) {
        tempSpots.add(FlSpot(i.toDouble(), fromStorageTemp(l.temperature!)));
      }
      if (l.humidity != null) {
        humSpots.add(FlSpot(i.toDouble(), l.humidity!));
      }
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
          // ── Header + range picker ─────────────
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('History',
                  style: AppTypography.headlineSmall(context)),
              const Spacer(),
              _rangeChip(context, '7d'),
              const SizedBox(width: AppSpacing.xs),
              _rangeChip(context, '30d'),
              const SizedBox(width: AppSpacing.xs),
              _rangeChip(context, 'all', locked: allLocked),
            ],
          ),

          // ── Temperature chart ─────────────────
          if (hasTempData) ...[
            const SizedBox(height: AppSpacing.md),
            _chartSection(
              context,
              label: 'Temperature',
              unit: tempUnitSuffix,
              color: AppColors.ipmColor,
              icon: Icons.thermostat,
              spots: tempSpots,
              optimalMin: fromStorageTemp(widget.space.tempMin),
              optimalMax: fromStorageTemp(widget.space.tempMax),
              logs: logs,
            ),
          ],

          // ── Humidity chart ────────────────────
          if (hasHumData) ...[
            const SizedBox(height: AppSpacing.md),
            _chartSection(
              context,
              label: 'Humidity',
              unit: '%',
              color: AppColors.water,
              icon: Icons.water_drop,
              spots: humSpots,
              optimalMin: widget.space.humidityMin,
              optimalMax: widget.space.humidityMax,
              logs: logs,
            ),
          ],
        ],
      ),
    );
  }

  // ── Single metric chart ───────────────────────

  Widget _chartSection(
    BuildContext context, {
    required String label,
    required String unit,
    required Color color,
    required IconData icon,
    required List<FlSpot> spots,
    required double optimalMin,
    required double optimalMax,
    required List<EnvironmentLog> logs,
  }) {
    final yValues = spots.map((s) => s.y).toList();
    final dataMin = yValues.reduce(min);
    final dataMax = yValues.reduce(max);

    // Give the chart a little breathing room above/below the data.
    final padding = max(2.0, (dataMax - dataMin) * 0.2);
    final minY = (min(dataMin, optimalMin) - padding).floorToDouble();
    final maxY = (max(dataMax, optimalMax) + padding).ceilToDouble();

    // Clamp the optimal band so it never exceeds the chart bounds.
    final bandMin = optimalMin.clamp(minY, maxY);
    final bandMax = optimalMax.clamp(minY, maxY);

    // How many x-axis labels to show (aim for ~4).
    final xInterval = max(1.0, (logs.length / 4).ceilToDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini section label
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.labelSmall(context)
                .copyWith(color: color, fontSize: 10),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),

        SizedBox(
          height: 130,
          child: LineChart(
            LineChartData(
              // ── Data line ──────────────────────
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: color,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: spots.length <= 14,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 2.5,
                      color: color,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.07),
                  ),
                ),
              ],

              // ── Optimal-range band ──────────────
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  HorizontalRangeAnnotation(
                    y1: bandMin,
                    y2: bandMax,
                    color: AppColors.optimal.withValues(alpha: 0.10),
                  ),
                ],
              ),

              // ── Axes ──────────────────────────
              minY: minY,
              maxY: maxY,
              // A7 — axis labels + gridlines flow through ChartTheme so
              // every chart in the app shares one source of truth for
              // font size, colour, dash pattern, etc.
              titlesData: FlTitlesData(
                topTitles: hiddenAxis,
                rightTitles: hiddenAxis,
                leftTitles: themedAxis(
                  context,
                  reservedSize: 40,
                  interval: max(1.0, (maxY - minY) / 3),
                  padRight: true,
                  format: (v) => '${v.toStringAsFixed(0)}$unit',
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: xInterval,
                    // Bottom axis can't go through themedAxis: it needs
                    // to skip ticks that fall outside the data range,
                    // not just format the raw double.
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= logs.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          fmtShortDate(logs[idx].recordedAt),
                          style: ChartTheme.axisLabelStyle(context),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Grid ──────────────────────────
              gridData: ChartTheme.horizontalGrid(context),
              borderData: ChartTheme.noBorder,

              // ── Touch tooltip ─────────────────
              lineTouchData: LineTouchData(
                touchTooltipData: ChartTheme.lineTooltip(
                  context,
                  getTooltipItems: (touchedSpots) =>
                      touchedSpots.map((s) {
                    final idx = s.x.toInt().clamp(0, logs.length - 1);
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(1)}$unit\n',
                      ChartTheme.tooltipPrimaryStyle(context, color),
                      children: [
                        TextSpan(
                          text: fmtShortDate(logs[idx].recordedAt),
                          style:
                              ChartTheme.tooltipSecondaryStyle(context),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Range chip ────────────────────────────────

  Widget _rangeChip(BuildContext context, String range,
      {bool locked = false}) {
    final selected = _range == range;
    return GestureDetector(
      onTap: locked
          ? () => showPaywall(context)
          : () => setState(() => _range = range),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.colSurface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected ? AppColors.primary : context.colBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) ...[
              const Icon(Icons.workspace_premium_rounded,
                  size: 11, color: AppColors.accent),
              const SizedBox(width: 3),
            ],
            Text(
              range == 'all' ? 'All' : range.toUpperCase(),
              style: AppTypography.labelSmall(context).copyWith(
                color: selected ? Colors.black : context.colTextSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.show_chart_rounded,
              size: 32, color: context.colTextMuted),
          const SizedBox(height: AppSpacing.sm),
          Text('No chart data yet',
              style: AppTypography.labelLarge(context)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Log at least 2 readings to see trends.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted),
          ),
        ],
      ),
    );
  }
}
