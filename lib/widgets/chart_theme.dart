import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A7 — Centralised chart-theming helpers for fl_chart surfaces.
///
/// Before this helper existed every chart hand-rolled the same
/// `AppTypography.labelSmall(context).copyWith(color: context.colTextMuted,
/// fontSize: 9)` and `FlGridData(getDrawingHorizontalLine: …)` blocks.
/// The result was visual drift — one chart picked `fontSize: 9`,
/// another `fontSize: 10`, a third used `colBorder.withValues(alpha:
/// 0.5)` for its gridlines while another bypassed colBorderFaint.
///
/// All chart-axis text now flows through [axisLabelStyle] and all
/// horizontal grids through [horizontalGrid].  Adjust the look here
/// and every chart picks the change up.
///
/// Why these specific values:
///   • **10 pt** axis labels — small enough to fit dense charts on
///     phones but still above the 9 pt floor where character shapes
///     start collapsing on low-DPI screens.
///   • **colTextMuted** for labels — the same hue used by every "tertiary"
///     UI label across the app (settings subtitles, list metadata).
///   • **colBorderFaint** (A4-bumped) for gridlines — visible but
///     unobtrusive against `surface1`/`surface2` cards.
///   • **3 px dash / 4 px gap** — softer than a solid line, lets the
///     data series read as the primary visual.
class ChartTheme {
  ChartTheme._();

  // ── Axis labels ─────────────────────────────────────────────────────

  /// Style for tick labels on every fl_chart axis.
  ///
  /// Pulls from [AppTypography.labelSmall] (the existing label token)
  /// and overrides only the chart-specific bits — colour, font size, and
  /// a tighter line-height so two-line labels don't add visual noise.
  static TextStyle axisLabelStyle(BuildContext context) =>
      AppTypography.labelSmall(context).copyWith(
        color: context.colTextMuted,
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w500,
      );

  /// Style for tooltip body text — slightly larger than axis labels
  /// because tooltips are an interactive surface and need to read at
  /// a glance.  Used by [lineTooltip] so individual chart files
  /// shouldn't have to set tooltip text themselves; they only supply
  /// the per-point label strings.
  static TextStyle tooltipPrimaryStyle(BuildContext context, Color valueColor) =>
      AppTypography.labelLarge(context).copyWith(color: valueColor);

  /// Secondary tooltip line (e.g. the date under the value).
  static TextStyle tooltipSecondaryStyle(BuildContext context) =>
      AppTypography.bodySmall(context).copyWith(color: context.colTextMuted);

  // ── Gridlines ───────────────────────────────────────────────────────

  /// Horizontal-only gridline pattern.  Most of our charts hide
  /// vertical gridlines because the X-axis is dense (one tick per day)
  /// and vertical lines turn into visual stripes.
  static FlGridData horizontalGrid(BuildContext context) => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: context.colBorderFaint,
          strokeWidth: 1,
          dashArray: const [3, 4],
        ),
      );

  // ── Border ──────────────────────────────────────────────────────────

  /// Suppresses fl_chart's default boxed border.  We use gridlines +
  /// the parent card's border as the visual frame instead — cleaner
  /// against `surface1` cards.
  static FlBorderData get noBorder => FlBorderData(show: false);

  // ── Tooltips ────────────────────────────────────────────────────────

  /// Line-chart tooltip pre-themed with the surface2 background, the
  /// bumped colBorder stroke, and our radiusSm rounding.  Callers
  /// supply `getTooltipItems` (the chart-specific text formatting).
  static LineTouchTooltipData lineTooltip(
    BuildContext context, {
    required GetLineTooltipItems getTooltipItems,
  }) {
    return LineTouchTooltipData(
      getTooltipColor: (_) => context.colSurface2,
      tooltipBorderRadius:
          BorderRadius.circular(AppSpacing.radiusSm),
      tooltipBorder: BorderSide(color: context.colBorder, width: 1),
      getTooltipItems: getTooltipItems,
    );
  }
}

/// Convenience builder for `AxisTitles` that picks up the shared
/// [ChartTheme.axisLabelStyle].  Each chart still supplies its own
/// `valueFormatter` because the unit + formatting varies (°C, %, g,
/// dates), but the surrounding shell stays uniform.
///
/// Typical usage:
///
/// ```dart
/// leftTitles: themedAxis(
///   context,
///   reservedSize: 40,
///   interval: yInterval,
///   format: (v) => '${v.toStringAsFixed(0)}°C',
/// ),
/// ```
AxisTitles themedAxis(
  BuildContext context, {
  required double reservedSize,
  required double? interval,
  required String Function(double value) format,
  bool padTop = false,
  bool padRight = false,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: reservedSize,
      interval: interval,
      getTitlesWidget: (v, _) => Padding(
        padding: EdgeInsets.only(
          right: padRight ? AppSpacing.xxs : 0,
          top: padTop ? AppSpacing.xxs : 0,
        ),
        child: Text(
          format(v),
          style: ChartTheme.axisLabelStyle(context),
        ),
      ),
    ),
  );
}

/// Used by every chart's `titlesData.topTitles` and `rightTitles` —
/// suppresses the empty axis labels fl_chart would otherwise reserve
/// space for.
const hiddenAxis =
    AxisTitles(sideTitles: SideTitles(showTitles: false));
