import '../utils/analytics_time_series.dart';

enum AlertSeverity { info, warning }

class TrendAlert {
  final String message;
  final AlertSeverity severity;

  TrendAlert(this.message, this.severity);
}

List<TrendAlert> generateYieldAlerts(List<SeriesPoint> series) {
  if (series.length < 3) return [];

  final recent =
      series.length >= 3 ? series.sublist(series.length - 3) : series;

  final delta = recent.last.value - recent.first.value;

  if (delta < -3) {
    return [
      TrendAlert(
        'Yield is declining over the selected time window',
        AlertSeverity.warning,
      ),
    ];
  }

  return [];
}
