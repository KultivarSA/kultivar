import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'chart_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlantHeightChart
//
// Line chart plotting height measurements (cm) over the grow.
//
// X-axis  : day number from plant.startDate
// Y-axis  : centimetres
// Band    : strain expected height range (if available)
// Stats   : latest height · 7-day growth delta
// ─────────────────────────────────────────────────────────────────────────────

class PlantHeightChart extends StatelessWidget {
  final Plant plant;
  final List<PlantNote> notes;
  final Strain? strainModel;

  const PlantHeightChart({
    super.key,
    required this.plant,
    required this.notes,
    this.strainModel,
  });

  @override
  Widget build(BuildContext context) {
    // Collect height points, chronological
    final sorted = [...notes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final points = sorted
        .where((n) => n.heightCm != null)
        .map((n) => _DataPoint(
              day: n.createdAt.difference(plant.startDate).inDays
                  .clamp(0, 9999),
              height: n.heightCm!,
              date: n.createdAt,
            ))
        .toList();

    if (points.isEmpty) return const SizedBox.shrink();

    final latest = points.last;
    final latestLabel =
        '${latest.height.toStringAsFixed(1)} cm — Day ${latest.day}';

    // 7-day growth delta
    final weekAgo = latest.date.subtract(const Duration(days: 7));
    final pointsBeforeWeek =
        points.where((p) => !p.date.isAfter(weekAgo)).toList();
    double? weekDelta;
    if (pointsBeforeWeek.isNotEmpty) {
      weekDelta = latest.height - pointsBeforeWeek.last.height;
    }

    // Strain reference height
    final strainMax = strainModel?.heightCmMax?.toDouble();
    final strainMin = strainModel?.heightCmMin?.toDouble();

    // Build chart spots
    final spots =
        points.map((p) => FlSpot(p.day.toDouble(), p.height)).toList();

    // Y-axis range
    final dataMax = points.map((p) => p.height).reduce(max);
    final dataMin = points.map((p) => p.height).reduce(min);
    final effectiveMax =
        strainMax != null ? max(dataMax, strainMax) : dataMax;
    final effectiveMin = min(dataMin, 0.0);
    final yPadding = max(5.0, (effectiveMax - effectiveMin) * 0.15);
    final minY = effectiveMin - yPadding;
    final maxY = effectiveMax + yPadding;

    // X range
    final maxDay = points.map((p) => p.day).reduce(max);
    final xInterval = max(7.0, (maxDay / 4).ceilToDouble());

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
          // ── Header ─────────────────────────────────
          Row(
            children: [
              const Icon(Icons.straighten_rounded,
                  size: 18, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.xs),
              Text('Height Tracker',
                  style: AppTypography.headlineSmall(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Stats row ──────────────────────────────
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              _statPill(
                context,
                icon: Icons.height_rounded,
                label: latestLabel,
                color: AppColors.secondary,
              ),
              if (weekDelta != null)
                _statPill(
                  context,
                  icon: weekDelta >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  label:
                      '${weekDelta >= 0 ? '+' : ''}${weekDelta.toStringAsFixed(1)} cm this week',
                  color: weekDelta >= 0 ? AppColors.growing : AppColors.warning,
                ),
              if (strainMax != null)
                _statPill(
                  context,
                  icon: Icons.eco_rounded,
                  label:
                      'Strain target: ${strainMin != null ? '${strainMin.toStringAsFixed(0)}–' : ''}${strainMax.toStringAsFixed(0)} cm',
                  color: context.colTextMuted,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Chart ──────────────────────────────────
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: AppColors.secondary,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: spots.length <= 20,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.secondary,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.secondary.withValues(alpha: 0.07),
                    ),
                  ),
                ],

                // Strain expected height band
                rangeAnnotations: (strainMin != null || strainMax != null)
                    ? RangeAnnotations(
                        horizontalRangeAnnotations: [
                          HorizontalRangeAnnotation(
                            y1: (strainMin ?? strainMax!).clamp(minY, maxY),
                            y2: (strainMax ?? strainMin!).clamp(minY, maxY),
                            color:
                                AppColors.growing.withValues(alpha: 0.08),
                          ),
                        ],
                      )
                    : const RangeAnnotations(),

                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: maxDay.toDouble(),

                // A7 — axis labels + gridlines flow through ChartTheme.
                titlesData: FlTitlesData(
                  topTitles: hiddenAxis,
                  rightTitles: hiddenAxis,
                  leftTitles: themedAxis(
                    context,
                    reservedSize: 38,
                    interval: max(5.0, (maxY - minY) / 4),
                    padRight: true,
                    format: (v) => '${v.toStringAsFixed(0)} cm',
                  ),
                  bottomTitles: themedAxis(
                    context,
                    reservedSize: 20,
                    interval: xInterval,
                    padTop: true,
                    format: (v) => 'Day ${v.toInt()}',
                  ),
                ),

                gridData: ChartTheme.horizontalGrid(context),
                borderData: ChartTheme.noBorder,

                lineTouchData: LineTouchData(
                  touchTooltipData: ChartTheme.lineTooltip(
                    context,
                    getTooltipItems: (touchedSpots) =>
                        touchedSpots.map((s) {
                      // Find the matching point by day value
                      final match = points.where(
                          (p) => p.day == s.x.toInt()).firstOrNull;
                      final dateStr =
                          match != null ? fmtShortDate(match.date) : '';
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} cm\n',
                        ChartTheme.tooltipPrimaryStyle(
                            context, AppColors.secondary),
                        children: [
                          TextSpan(
                            text: 'Day ${s.x.toInt()} · $dateStr',
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

          // Strain reference legend (only when band is shown)
          if (strainMin != null || strainMax != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.growing.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                        color: AppColors.growing.withValues(alpha: 0.4),
                        width: 1),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Strain expected height range',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: color, fontSize: 10),
            ),
          ],
        ),
      );
}

// ── Private data class ────────────────────────────────────────────────────────

class _DataPoint {
  final int day;
  final double height;
  final DateTime date;
  const _DataPoint(
      {required this.day, required this.height, required this.date});
}
