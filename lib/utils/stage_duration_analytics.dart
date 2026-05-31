import '../models/plant.dart';

// ── Single-plant durations ────────────────────────────────────────────────────

class StageDurations {
  /// Days from seed/clone start to flip (null when flipDate not recorded).
  final int? vegDays;

  /// Days from flip to harvest (null when flipDate not recorded).
  final int? flowerDays;

  /// Days spent drying (null when dates are incomplete or stage not reached).
  /// For a plant currently in drying, this is the elapsed count so far.
  final int? dryingDays;

  /// Days spent curing (null when dates are incomplete or stage not reached).
  /// For a plant currently in curing, this is the elapsed count so far.
  final int? curingDays;

  /// Total days from startDate to harvestedDate (or now for live plants).
  final int totalGrowDays;

  /// Positive = harvested later than target; negative = earlier; null = no target set.
  final int? targetVarianceDays;

  /// True when we're still computing (plant hasn't been harvested yet).
  final bool isOngoing;

  const StageDurations({
    this.vegDays,
    this.flowerDays,
    this.dryingDays,
    this.curingDays,
    required this.totalGrowDays,
    this.targetVarianceDays,
    this.isOngoing = false,
  });

  /// True when flip data is present and both veg + flower days are known.
  bool get hasFlipBreakdown => vegDays != null && flowerDays != null;
}

// ── Historical averages ───────────────────────────────────────────────────────

class HistoricalStageDurations {
  final double? avgVegDays;
  final double? avgFlowerDays;
  final double? avgDryingDays;
  final double? avgTotalGrowDays;

  /// Number of completed/harvested plants used in the calculation.
  final int plantCount;

  const HistoricalStageDurations({
    this.avgVegDays,
    this.avgFlowerDays,
    this.avgDryingDays,
    this.avgTotalGrowDays,
    required this.plantCount,
  });

  bool get hasData => plantCount > 0;

  static const empty = HistoricalStageDurations(plantCount: 0);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double? _avg(List<double> list) =>
    list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length;

// ── Public API ────────────────────────────────────────────────────────────────

/// Derives stage durations for a single [plant] from its lifecycle timestamps.
StageDurations computeStageDurations(Plant plant) {
  final now = DateTime.now();
  final isOngoing = plant.harvestedDate == null &&
      (plant.status == PlantStatus.growing);

  final growEnd = plant.harvestedDate ?? now;
  final totalGrowDays = growEnd.difference(plant.startDate).inDays;

  // Veg / flower split
  int? vegDays;
  int? flowerDays;
  if (plant.flipDate != null) {
    vegDays =
        plant.flipDate!.difference(plant.startDate).inDays.clamp(0, 9999);
    flowerDays =
        growEnd.difference(plant.flipDate!).inDays.clamp(0, 9999);
  }

  // Drying
  int? dryingDays;
  if (plant.harvestedDate != null) {
    if (plant.dryingEndDate != null) {
      // Completed drying.
      dryingDays = plant.dryingEndDate!
          .difference(plant.harvestedDate!)
          .inDays
          .clamp(0, 9999);
    } else if (plant.status == PlantStatus.drying ||
        plant.status == PlantStatus.harvested) {
      // Still drying — show elapsed so far.
      dryingDays = now.difference(plant.harvestedDate!).inDays;
    }
  }

  // Curing
  int? curingDays;
  if (plant.dryingEndDate != null) {
    final cureEnd = plant.curingEndDate ??
        (plant.status == PlantStatus.curing ? now : null);
    if (cureEnd != null) {
      curingDays = cureEnd
          .difference(plant.dryingEndDate!)
          .inDays
          .clamp(0, 9999);
    }
  }

  // Target variance
  int? targetVarianceDays;
  if (plant.targetHarvestDate != null && plant.harvestedDate != null) {
    targetVarianceDays =
        plant.harvestedDate!.difference(plant.targetHarvestDate!).inDays;
  }

  return StageDurations(
    vegDays: vegDays,
    flowerDays: flowerDays,
    dryingDays: dryingDays,
    curingDays: curingDays,
    totalGrowDays: totalGrowDays,
    targetVarianceDays: targetVarianceDays,
    isOngoing: isOngoing,
  );
}

/// Computes historical averages from a list of plants.
///
/// Pass all plants from the repo; optionally filter by strain before calling
/// to get strain-specific baselines. Only plants with a real [harvestedDate]
/// contribute to the averages.
HistoricalStageDurations computeHistoricalAverages(List<Plant> plants) {
  final completed = plants
      .where((p) =>
          p.harvestedDate != null &&
          (p.status == PlantStatus.completed ||
              p.status == PlantStatus.curing ||
              p.status == PlantStatus.drying ||
              p.status == PlantStatus.harvested))
      .toList();

  if (completed.isEmpty) return HistoricalStageDurations.empty;

  final vegList = completed
      .where((p) => p.flipDate != null)
      .map((p) => p.flipDate!.difference(p.startDate).inDays.toDouble())
      .toList();

  final flowerList = completed
      .where((p) => p.flipDate != null && p.harvestedDate != null)
      .map((p) =>
          p.harvestedDate!.difference(p.flipDate!).inDays.toDouble())
      .toList();

  final dryingList = completed
      .where((p) => p.harvestedDate != null && p.dryingEndDate != null)
      .map((p) => p.dryingEndDate!
          .difference(p.harvestedDate!)
          .inDays
          .toDouble())
      .toList();

  final totalList = completed
      .map((p) =>
          p.harvestedDate!.difference(p.startDate).inDays.toDouble())
      .toList();

  return HistoricalStageDurations(
    avgVegDays: _avg(vegList),
    avgFlowerDays: _avg(flowerList),
    avgDryingDays: _avg(dryingList),
    avgTotalGrowDays: _avg(totalList),
    plantCount: completed.length,
  );
}
