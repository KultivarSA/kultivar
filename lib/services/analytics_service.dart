import '../repository/grow_repository.dart';

class AnalyticsService {
  final GrowRepository repo;

  AnalyticsService(this.repo);

  /// Average dry weight in grams across all harvest logs that recorded one.
  double averageYield() {
    final values = repo.harvestLogs
        .where((l) => l.dryWeight != null && l.dryWeight! > 0)
        .map((l) => l.dryWeight!)
        .toList();

    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Duration averageDryingTime() {
    final durations = repo.plants
        .where((p) => p.harvestedDate != null && p.dryingEndDate != null)
        .map((p) => p.dryingEndDate!.difference(p.harvestedDate!))
        .toList();

    if (durations.isEmpty) return Duration.zero;
    return durations.reduce((a, b) => a + b) ~/ durations.length;
  }

  double totalHarvestedWeight() {
    return repo.harvestLogs.fold(
      0.0,
      (sum, log) => sum + (log.dryWeight ?? 0),
    );
  }
}
