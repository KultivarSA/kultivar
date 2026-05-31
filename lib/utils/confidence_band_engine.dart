import 'dart:math';

import 'analytics_time_series.dart';

class ConfidenceBand {
  final DateTime date;
  final String series;
  final double mean;
  final double min;
  final double max;

  const ConfidenceBand({
    required this.date,
    required this.series,
    required this.mean,
    required this.min,
    required this.max,
  });
}

/// Builds rolling trailing-window mean ± σ bands for each series.
///
/// Each point at index _i_ takes the window of the preceding [window] points
/// (inclusive of _i_ itself), computes their mean and population standard
/// deviation, and emits a band of [mean − σ, mean + σ].
///
/// A window of 1 (the first point of any series) produces σ = 0, so that
/// point's band collapses to a line — correct behaviour.
Map<String, List<ConfidenceBand>> buildConfidenceBands(
  List<SeriesPoint> points, {
  int window = 5,
}) {
  // Group by series, preserving chronological order.
  final Map<String, List<SeriesPoint>> grouped = {};
  for (final p in points) {
    grouped.putIfAbsent(p.series, () => []).add(p);
  }

  final Map<String, List<ConfidenceBand>> result = {};

  grouped.forEach((seriesName, pts) {
    final bands = <ConfidenceBand>[];

    for (int i = 0; i < pts.length; i++) {
      // Trailing window: from max(0, i − window + 1) to i inclusive.
      final start = (i - window + 1).clamp(0, i);
      final windowPts = pts.sublist(start, i + 1);

      final mean = windowPts.map((p) => p.value).reduce((a, b) => a + b) /
          windowPts.length;

      double sigma = 0;
      if (windowPts.length > 1) {
        final variance = windowPts
                .map((p) => pow(p.value - mean, 2).toDouble())
                .reduce((a, b) => a + b) /
            windowPts.length;
        sigma = sqrt(variance);
      }

      bands.add(ConfidenceBand(
        date: pts[i].date,
        series: seriesName,
        mean: mean,
        min: mean - sigma,
        max: mean + sigma,
      ));
    }

    result[seriesName] = bands;
  });

  return result;
}
