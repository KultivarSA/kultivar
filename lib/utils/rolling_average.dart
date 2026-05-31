import '../utils/analytics_time_series.dart';

List<SeriesPoint> applyRollingAverage(
  List<SeriesPoint> series, {
  int windowSize = 3,
}) {
  if (series.length < windowSize) return series;

  final List<SeriesPoint> smoothed = [];

  for (int i = 0; i < series.length; i++) {
    final start = i - (windowSize - 1);
    if (start < 0) continue;

    final window = series.sublist(start, i + 1);
    final avg =
        window.map((p) => p.value).reduce((a, b) => a + b) / window.length;

    smoothed.add(
      SeriesPoint(series[i].date, avg, series[i].series),
    );
  }

  return smoothed;
}
