import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/time_window.dart';

class SeriesPoint {
  final DateTime date;
  final double value;
  final String series; // grow space name, or "Failures"

  SeriesPoint(this.date, this.value, this.series);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Builds per-space yield series from [harvestLogs].
///
/// [harvestLogs] is the canonical source for wet/dry weights — it reflects
/// any post-harvest edits made by the user.  [plants] is used only for the
/// grow-space association and harvest date; weight fields on [Plant] are
/// intentionally ignored here so edited logs are always reflected in the chart.
List<SeriesPoint> buildYieldSeries(
  List<Plant> plants,
  List<GrowSpace> spaces,
  TimeWindow window,
  List<HarvestLog> harvestLogs,
) {
  final cutoff = window.days == null
      ? null
      : DateTime.now().subtract(Duration(days: window.days!));

  // Build a quick lookup: plantId → most-recent HarvestLog.
  // A plant should have at most one log, but if duplicates exist we take
  // the last one in list order (insertion order = creation order).
  final logByPlantId = <String, HarvestLog>{};
  for (final log in harvestLogs) {
    logByPlantId[log.plantId] = log;
  }

  final List<SeriesPoint> output = [];

  for (final space in spaces) {
    final Map<DateTime, List<double>> buckets = {};

    for (final plant in plants) {
      if (plant.growSpaceId != space.id) continue;
      if (plant.harvestedDate == null) continue;
      if (cutoff != null && plant.harvestedDate!.isBefore(cutoff)) continue;

      // Prefer the harvest log's weights (may have been corrected by the
      // user); fall back to the plant's own fields for legacy records that
      // pre-date the harvest-log feature.
      final log = logByPlantId[plant.id];
      final dry = log?.dryWeight ?? plant.dryWeight;

      // Skip plants with no recorded dry weight.
      if (dry == null || dry <= 0) continue;

      final day = _day(plant.harvestedDate!);
      buckets.putIfAbsent(day, () => []).add(dry);
    }

    for (final entry in buckets.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      output.add(SeriesPoint(entry.key, avg, space.name));
    }
  }

  output.sort((a, b) => a.date.compareTo(b.date));
  return output;
}

List<SeriesPoint> buildFailureSeries(
  List<Plant> plants,
  TimeWindow window,
) {
  final cutoff = window.days == null
      ? null
      : DateTime.now().subtract(Duration(days: window.days!));

  final Map<DateTime, int> buckets = {};

  for (final plant in plants) {
    if (plant.status != PlantStatus.removed || plant.archivedAt == null) {
      continue;
    }
    if (cutoff != null && plant.archivedAt!.isBefore(cutoff)) {
      continue;
    }

    final day = _day(plant.archivedAt!);
    buckets[day] = (buckets[day] ?? 0) + 1;
  }

  return buckets.entries
      .map((e) => SeriesPoint(e.key, e.value.toDouble(), 'Failures'))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}
