import '../models/plant.dart';

class HealthScore {
  final String space;
  final double score;

  HealthScore(this.space, this.score);
}

double _consistency(List<double> values) {
  if (values.length < 2) return 1;
  final avg = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((v) => (v - avg) * (v - avg)).reduce((a, b) => a + b) /
          values.length;
  return (1 / (1 + variance)).clamp(0, 1);
}

List<HealthScore> computeHealthScores(
  List<Plant> plants,
  Map<String, List<double>> yieldsBySpace,
) {
  final results = <HealthScore>[];

  yieldsBySpace.forEach((space, yields) {
    final avgYield =
        yields.isEmpty ? 0 : yields.reduce((a, b) => a + b) / yields.length;

    final failures = plants.where(
      (p) => p.growSpaceId == space && p.status == PlantStatus.removed,
    );

    final planted = plants.where((p) => p.growSpaceId == space).length;
    final failureRate = planted == 0 ? 0 : failures.length / planted;

    final consistency = _consistency(yields);

    final score =
        (avgYield * 0.5) + ((1 - failureRate) * 30) + (consistency * 20);

    results.add(HealthScore(space, score));
  });

  return results;
}
