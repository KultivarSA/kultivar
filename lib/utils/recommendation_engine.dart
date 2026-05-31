import '../models/plant.dart';
import '../utils/analytics_time_series.dart';

class Recommendation {
  final String message;
  Recommendation(this.message);
}

List<Recommendation> generateRecommendations({
  required List<Plant> plants,
  required List<SeriesPoint> yieldSeries,
}) {
  final recs = <Recommendation>[];

  if (yieldSeries.length >= 3) {
    final recentDelta =
        yieldSeries.last.value - yieldSeries[yieldSeries.length - 3].value;

    if (recentDelta < -3) {
      recs.add(
        Recommendation(
          'Recent yield decline detected. Consider checking environmental consistency.',
        ),
      );
    }
  }

  final failureRate =
      plants.where((p) => p.status == PlantStatus.removed).length /
          (plants.isEmpty ? 1 : plants.length);

  if (failureRate > 0.25) {
    recs.add(
      Recommendation(
        'Higher‑than‑normal removal rate observed. Review recent issues and grow space conditions.',
      ),
    );
  }

  if (recs.isEmpty) {
    recs.add(
      Recommendation(
        'No immediate issues detected. Current conditions appear stable.',
      ),
    );
  }

  return recs;
}
