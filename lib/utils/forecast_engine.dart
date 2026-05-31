import 'dart:math';

import 'analytics_time_series.dart';

/// A single projected point with a symmetric uncertainty range.
class ForecastPoint {
  final DateTime date;
  final String series;

  /// Projected centre value (rolling-mean extrapolation).
  final double center;

  /// Lower bound of the uncertainty cone (center − uncertainty).
  final double low;

  /// Upper bound of the uncertainty cone (center + uncertainty).
  final double high;

  const ForecastPoint({
    required this.date,
    required this.series,
    required this.center,
    required this.low,
    required this.high,
  });
}

/// Result of a forecast computation for one series.
class ForecastResult {
  final List<ForecastPoint> points;

  /// How many historical data points were used to build the forecast.
  final int dataPointsUsed;

  const ForecastResult({
    required this.points,
    required this.dataPointsUsed,
  });

  bool get hasPoints => points.isNotEmpty;
}

/// Projects [forwardSteps] future points for [seriesPoints].
///
/// Returns `null` when there are fewer than [minPoints] data points —
/// not enough history to make a meaningful prediction.
///
/// Algorithm:
///  1. Take the last [lookback] points as the recent window.
///  2. Compute their rolling mean and population σ.
///  3. Extrapolate the centre using the average day-over-day delta.
///  4. Widen uncertainty by σ × step_index so the cone opens forward.
ForecastResult? buildForecast(
  List<SeriesPoint> seriesPoints, {
  int minPoints = 5,
  int lookback = 5,
  int forwardSteps = 3,
}) {
  if (seriesPoints.length < minPoints) return null;

  final recent = seriesPoints.sublist(seriesPoints.length - lookback);

  // Rolling mean of recent values.
  final mean =
      recent.map((p) => p.value).reduce((a, b) => a + b) / recent.length;

  // Population σ of recent values.
  final variance = recent
          .map((p) => pow(p.value - mean, 2).toDouble())
          .reduce((a, b) => a + b) /
      recent.length;
  final sigma = sqrt(variance);

  // Average day-over-day delta across the recent window.
  final totalDelta = recent.last.value - recent.first.value;
  final avgDailyDelta =
      recent.length > 1 ? totalDelta / (recent.length - 1) : 0.0;

  final lastDate = recent.last.date;
  final seriesName = recent.last.series;

  final points = <ForecastPoint>[];
  for (int step = 1; step <= forwardSteps; step++) {
    final center = (recent.last.value + avgDailyDelta * step).clamp(0, double.infinity);
    // Uncertainty widens linearly with each step.
    final uncertainty = sigma * step;

    points.add(ForecastPoint(
      date: lastDate.add(Duration(days: step * 30)), // monthly steps
      series: seriesName,
      center: center.toDouble(),
      low: (center - uncertainty).clamp(0, double.infinity).toDouble(),
      high: (center + uncertainty).toDouble(),
    ));
  }

  return ForecastResult(
    points: points,
    dataPointsUsed: seriesPoints.length,
  );
}
