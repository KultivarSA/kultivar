import '../utils/analytics_time_series.dart';

String exportSeriesToCsv(List<SeriesPoint> series) {
  final buffer = StringBuffer();
  buffer.writeln('date,space,value');

  for (final p in series) {
    buffer.writeln(
      '${p.date.toIso8601String()},${p.series},${p.value.toStringAsFixed(2)}',
    );
  }

  return buffer.toString();
}
