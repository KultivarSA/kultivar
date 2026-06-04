import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/analytics_time_series.dart';
import '../utils/confidence_band_engine.dart';
import '../utils/forecast_engine.dart';

class ChartAnnotation {
  final DateTime date;
  final String label;
  ChartAnnotation(this.date, this.label);
}

class MultiLineChart extends StatelessWidget {
  final List<SeriesPoint> series;
  final Set<String> hiddenSeries;
  final List<ChartAnnotation> annotations;
  final SeriesPoint? selectedPoint;
  final bool showConfidenceBands;

  /// Optional per-series forecasts. The key is the series name.
  final Map<String, ForecastResult> forecasts;

  final void Function(SeriesPoint point, ConfidenceBand? band)? onPointTap;

  const MultiLineChart({
    super.key,
    required this.series,
    required this.hiddenSeries,
    required this.showConfidenceBands,
    this.annotations = const [],
    this.selectedPoint,
    this.forecasts = const {},
    this.onPointTap,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Not enough data',
            style: TextStyle(color: context.colTextMuted),
          ),
        ),
      );
    }

    final visible =
        series.where((p) => !hiddenSeries.contains(p.series)).toList();

    final bands = showConfidenceBands
        ? buildConfidenceBands(visible)
        : <String, List<ConfidenceBand>>{};

    // Only include forecasts for visible series.
    final visibleForecasts = Map.fromEntries(
      forecasts.entries.where((e) => !hiddenSeries.contains(e.key)),
    );

    return Semantics(
      label: 'Yield chart. Lines show average dry weight per grow space. '
          'Shaded areas show variability. Tap points to view exact values.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onPointTap == null
            ? null
            : (details) {
                final box = context.findRenderObject() as RenderBox;
                final localX = box.globalToLocal(details.globalPosition).dx;

                final index = ((localX / box.size.width) * visible.length)
                    .clamp(0, visible.length - 1)
                    .floor();

                final point = visible[index];

                ConfidenceBand? band;
                final seriesBands = bands[point.series];

                if (seriesBands != null) {
                  for (final b in seriesBands) {
                    if (b.date == point.date) {
                      band = b;
                      break;
                    }
                  }
                }

                onPointTap!(point, band);
              },
        // Bug fix: CustomPaint without a child or explicit size sizes
        // itself to constraints.smallest.  The outer SizedBox only
        // constrained height (180), leaving width unbounded -- so the
        // CustomPaint painted into a 0-pixel-wide canvas.  Every
        // point's x mapped to 0, the line drew as a tiny vertical
        // sliver at the left edge (Marco's chart-empty bug -- the
        // diagnostic log from PR #24 showed data was reaching the
        // painter correctly, ruling out the data path).  Force the
        // SizedBox to expand to the parent's max width so the
        // CustomPaint inherits a proper canvas size.
        child: SizedBox(
          width: double.infinity,
          height: 180,
          child: CustomPaint(
            painter: _ChartPainter(
              series: visible,
              bands: bands,
              annotations: annotations,
              selectedPoint: selectedPoint,
              showBands: showConfidenceBands,
              forecasts: visibleForecasts,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<SeriesPoint> series;
  final Map<String, List<ConfidenceBand>> bands;
  final List<ChartAnnotation> annotations;
  final SeriesPoint? selectedPoint;
  final bool showBands;
  final Map<String, ForecastResult> forecasts;

  _ChartPainter({
    required this.series,
    required this.bands,
    required this.annotations,
    required this.selectedPoint,
    required this.showBands,
    required this.forecasts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gather all values — historical + forecast centres + forecast highs —
    // so the y-scale accounts for the full chart extent.
    double maxY = 0;
    for (final p in series) {
      if (p.value > maxY) maxY = p.value;
    }
    for (final fr in forecasts.values) {
      for (final fp in fr.points) {
        if (fp.high > maxY) maxY = fp.high;
      }
    }
    if (maxY == 0) maxY = 1;

    // Total x-axis length = historical points + longest forecast tail.
    final maxForecastSteps =
        forecasts.values.fold(0, (m, fr) => fr.points.length > m ? fr.points.length : m);

    final grouped = <String, List<SeriesPoint>>{};
    for (final p in series) {
      grouped.putIfAbsent(p.series, () => []).add(p);
    }

    // x-coordinate helper: maps an index within the combined
    // [historical + forecast] timeline to a pixel position.
    // All series share the same total count so x is consistent.
    final totalSeriesLength = grouped.values.fold(0, (m, pts) => pts.length > m ? pts.length : m);
    final totalPoints = totalSeriesLength + maxForecastSteps;

    double xFor(int idx) {
      if (totalPoints <= 1) return size.width / 2;
      return (idx / (totalPoints - 1)) * size.width;
    }

    double yFor(double value) => size.height - (value / maxY) * size.height;

    // ── Confidence bands ───────────────────────
    if (showBands) {
      for (final entry in bands.entries) {
        final bandPoints = entry.value;
        if (bandPoints.length < 2) continue;

        final isComparison = entry.key.contains('(comparison)');
        final path = Path();

        for (int i = 0; i < bandPoints.length; i++) {
          final x = xFor(i);
          final y = yFor(bandPoints[i].max);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        for (int i = bandPoints.length - 1; i >= 0; i--) {
          path.lineTo(xFor(i), yFor(bandPoints[i].min));
        }
        path.close();

        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              colors: isComparison
                  ? [
                      AppColors.secondary.withValues(alpha: 0.15),
                      AppColors.secondary.withValues(alpha: 0.05),
                    ]
                  : [
                      AppColors.growing.withValues(alpha: 0.18),
                      AppColors.growing.withValues(alpha: 0.05),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── Series lines ───────────────────────────
    for (final entry in grouped.entries) {
      final pts = entry.value;
      if (pts.length < 2) continue;

      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final x = xFor(i);
        final y = yFor(pts[i].value);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Forecast uncertainty cones ─────────────
    for (final entry in forecasts.entries) {
      final fr = entry.value;
      if (!fr.hasPoints) continue;

      final pts = grouped[entry.key];
      if (pts == null || pts.isEmpty) continue;

      // The cone starts at the last historical point.
      final lastHistIdx = pts.length - 1;
      final lastHistValue = pts.last.value;

      // Build cone path: upper edge forward, lower edge back.
      final conePath = Path();
      conePath.moveTo(xFor(lastHistIdx), yFor(lastHistValue));

      for (int i = 0; i < fr.points.length; i++) {
        conePath.lineTo(
          xFor(lastHistIdx + 1 + i),
          yFor(fr.points[i].high),
        );
      }
      for (int i = fr.points.length - 1; i >= 0; i--) {
        conePath.lineTo(
          xFor(lastHistIdx + 1 + i),
          yFor(fr.points[i].low),
        );
      }
      conePath.close();

      canvas.drawPath(
        conePath,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.10)
          ..style = PaintingStyle.fill,
      );

      // Dashed centre line.
      final centrePath = Path();
      centrePath.moveTo(xFor(lastHistIdx), yFor(lastHistValue));
      for (int i = 0; i < fr.points.length; i++) {
        centrePath.lineTo(
          xFor(lastHistIdx + 1 + i),
          yFor(fr.points[i].center),
        );
      }

      _drawDashed(
        canvas,
        centrePath,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.55)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
        dashLength: 5,
        gapLength: 6,
      );
    }

    // ── Selected point highlight ───────────────
    if (selectedPoint != null) {
      final idx = series.indexWhere(
        (p) =>
            p.series == selectedPoint!.series && p.date == selectedPoint!.date,
      );

      if (idx != -1) {
        final x = series.length > 1
            ? xFor(idx)
            : size.width / 2;
        final y = yFor(series[idx].value);

        canvas.drawCircle(
          Offset(x, y),
          5,
          Paint()..color = AppColors.harvested,
        );
      }
    }
  }

  /// Draws [path] as a dashed stroke using [dashLength]/[gapLength].
  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dashLength = 5,
    double gapLength = 5,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool drawing = true;
      while (distance < metric.length) {
        final segmentLength = drawing ? dashLength : gapLength;
        final end = (distance + segmentLength).clamp(0.0, metric.length);
        if (drawing) {
          canvas.drawPath(
            metric.extractPath(distance, end),
            paint,
          );
        }
        distance += segmentLength;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
