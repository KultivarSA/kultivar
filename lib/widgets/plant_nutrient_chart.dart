import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/plant_note.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/feeding_analytics.dart';
import 'chart_theme.dart';

/// Renders pH and EC trend charts for a single plant, derived from its
/// feeding and watering notes.
///
/// Shows:
///  • pH chart — `feedingDetails.phIn`, `wateringDetails.phIn`,
///    `wateringDetails.runoffPh`
///  • EC chart  — `feedingDetails.ecIn`
///
/// Either section is omitted when fewer than 2 data points exist.
class PlantNutrientChart extends StatelessWidget {
  final List<PlantNote> notes;

  const PlantNutrientChart({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    // ── Collect data points ───────────────────────
    // Sort all notes chronologically once.
    final sorted = [...notes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // pH data series.
    final feedPhPoints  = <_DataPoint>[];
    final waterPhPoints = <_DataPoint>[];
    final runoffPoints  = <_DataPoint>[];
    // EC data series.
    final ecPoints      = <_DataPoint>[];

    for (final note in sorted) {
      if (note.feedingDetails != null) {
        final fd = note.feedingDetails!;
        if (fd.phIn != null) {
          feedPhPoints.add(_DataPoint(note.createdAt, fd.phIn!));
        }
        if (fd.ecIn != null) {
          ecPoints.add(_DataPoint(note.createdAt, fd.ecIn!));
        }
      }
      if (note.wateringDetails != null) {
        final wd = note.wateringDetails!;
        if (wd.phIn != null) {
          waterPhPoints.add(_DataPoint(note.createdAt, wd.phIn!));
        }
        if (wd.runoffPh != null) {
          runoffPoints.add(_DataPoint(note.createdAt, wd.runoffPh!));
        }
      }
    }

    // Merge all pH sources to determine whether the section has enough data.
    final allPhPoints = [...feedPhPoints, ...waterPhPoints, ...runoffPoints]
      ..sort((a, b) => a.date.compareTo(b.date));

    final hasPhData = allPhPoints.length >= 2;
    final hasEcData = ecPoints.length >= 2;

    final feedAnalytics = computeFeedingAnalytics(notes);

    if (!hasPhData && !hasEcData) return const SizedBox.shrink();

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
          // ── Header ─────────────────────────────
          Row(
            children: [
              const Icon(Icons.science_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('Nutrient Trends',
                  style: AppTypography.headlineSmall(context)),
            ],
          ),

          // ── pH chart ───────────────────────────
          if (hasPhData) ...[
            const SizedBox(height: AppSpacing.md),
            _chartSection(
              context,
              label: 'pH',
              icon: Icons.water_drop_rounded,
              series: [
                if (feedPhPoints.isNotEmpty)
                  _Series('Feed pH', AppColors.curing, feedPhPoints),
                if (waterPhPoints.isNotEmpty)
                  _Series('Water pH', AppColors.water, waterPhPoints),
                if (runoffPoints.isNotEmpty)
                  _Series('Runoff pH', AppColors.secondary, runoffPoints),
              ],
              // pH sweet-spot band for cannabis: 6.0–7.0 soil / 5.5–6.5 hydro.
              // Use 5.8–7.0 as a reasonable general band.
              bandMin: 5.8,
              bandMax: 7.0,
              yDecimals: 1,
            ),
          ],

          // ── EC chart ───────────────────────────
          if (hasEcData) ...[
            const SizedBox(height: AppSpacing.md),
            _chartSection(
              context,
              label: 'EC (mS/cm)',
              icon: Icons.bolt_rounded,
              series: [
                _Series('EC', AppColors.ipmColor, ecPoints),
              ],
              bandMin: null,
              bandMax: null,
              yDecimals: 2,
            ),
          ],

          // ── Feeding alerts ──────────────────────
          if (feedAnalytics.hasAlerts) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.sm),
            ...feedAnalytics.alerts.map((alert) {
              final isWarning =
                  alert.severity == FeedingAlertSeverity.warning;
              final color =
                  isWarning ? AppColors.warning : AppColors.info;
              final icon = isWarning
                  ? Icons.warning_rounded
                  : Icons.info_outline_rounded;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        alert.message,
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Single chart section ───────────────────────

  Widget _chartSection(
    BuildContext context, {
    required String label,
    required IconData icon,
    required List<_Series> series,
    required double? bandMin,
    required double? bandMax,
    required int yDecimals,
  }) {
    if (series.every((s) => s.points.isEmpty)) return const SizedBox.shrink();

    // Build a unified timeline: all unique dates across all series, sorted.
    final allDates = series
        .expand((s) => s.points.map((p) => p.date))
        .toSet()
        .toList()
      ..sort();

    // Map each date to an x index so the x-axis is evenly spaced.
    final dateIndex = {
      for (var i = 0; i < allDates.length; i++) allDates[i]: i.toDouble(),
    };

    // Convert each series' points to FlSpots.
    final barData = series.map((s) {
      final spots = s.points
          .map((p) => FlSpot(dateIndex[p.date]!, p.value))
          .toList();
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        color: s.color,
        barWidth: 2,
        dotData: FlDotData(
          show: spots.length <= 14,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 2.5,
            color: s.color,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: s.color.withValues(alpha: 0.06),
        ),
      );
    }).toList();

    // Y-axis range.
    final allValues = series.expand((s) => s.points.map((p) => p.value));
    final dataMin = allValues.reduce(min);
    final dataMax = allValues.reduce(max);
    final padding = max(0.2, (dataMax - dataMin) * 0.2);
    final effectiveBandMin = bandMin;
    final effectiveBandMax = bandMax;
    final minY = (min(dataMin, effectiveBandMin ?? dataMin) - padding);
    final maxY = (max(dataMax, effectiveBandMax ?? dataMax) + padding);

    final xInterval = max(1.0, (allDates.length / 4).ceilToDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini header + legend
        Row(
          children: [
            Icon(icon, size: 12, color: context.colTextMuted),
            const SizedBox(width: AppSpacing.xxs),
            Text(label,
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 10)),
            const Spacer(),
            ...series.where((s) => s.points.isNotEmpty).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 3,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(s.name,
                            style: AppTypography.labelSmall(context)
                                .copyWith(
                                    color: s.color, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        SizedBox(
          height: 130,
          child: LineChart(
            LineChartData(
              lineBarsData: barData,

              // ── Optimal band ──────────────────
              rangeAnnotations: effectiveBandMin != null &&
                      effectiveBandMax != null
                  ? RangeAnnotations(
                      horizontalRangeAnnotations: [
                        HorizontalRangeAnnotation(
                          y1: effectiveBandMin.clamp(minY, maxY),
                          y2: effectiveBandMax.clamp(minY, maxY),
                          color:
                              AppColors.optimal.withValues(alpha: 0.10),
                        ),
                      ],
                    )
                  : const RangeAnnotations(),

              minY: minY,
              maxY: maxY,

              // ── Axes ─────────────────────────
              // A7 — axis labels + gridlines flow through ChartTheme.
              titlesData: FlTitlesData(
                topTitles: hiddenAxis,
                rightTitles: hiddenAxis,
                leftTitles: themedAxis(
                  context,
                  reservedSize: 40,
                  interval: max(0.1, (maxY - minY) / 3),
                  padRight: true,
                  format: (v) => v.toStringAsFixed(yDecimals),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: xInterval,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= allDates.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          fmtShortDate(allDates[idx]),
                          style: ChartTheme.axisLabelStyle(context),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Grid ─────────────────────────
              gridData: ChartTheme.horizontalGrid(context),
              borderData: ChartTheme.noBorder,

              // ── Tooltip ───────────────────────
              lineTouchData: LineTouchData(
                touchTooltipData: ChartTheme.lineTooltip(
                  context,
                  getTooltipItems: (spots) => spots.map((s) {
                    final seriesIdx = s.barIndex;
                    final ser = series[seriesIdx];
                    final xIdx = s.x.toInt().clamp(0, allDates.length - 1);
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(yDecimals)}\n',
                      ChartTheme.tooltipPrimaryStyle(context, ser.color),
                      children: [
                        TextSpan(
                          text:
                              '${ser.name} · ${fmtShortDate(allDates[xIdx])}',
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
}

// ── Private helpers ────────────────────────────────

class _DataPoint {
  final DateTime date;
  final double value;
  const _DataPoint(this.date, this.value);
}

class _Series {
  final String name;
  final Color color;
  final List<_DataPoint> points;
  const _Series(this.name, this.color, this.points);
}
