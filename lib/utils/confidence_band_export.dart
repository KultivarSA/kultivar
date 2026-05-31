import 'confidence_band_engine.dart';

String exportBandsToCsv(
  Map<String, List<ConfidenceBand>> bands,
) {
  final buffer = StringBuffer();
  buffer.writeln('date,series,mean,min,max');

  for (final entry in bands.entries) {
    for (final b in entry.value) {
      buffer.writeln(
        '${b.date.toIso8601String()},'
        '${b.series},'
        '${b.mean.toStringAsFixed(2)},'
        '${b.min.toStringAsFixed(2)},'
        '${b.max.toStringAsFixed(2)}',
      );
    }
  }

  return buffer.toString();
}