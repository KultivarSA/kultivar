import 'dart:math';

import '../models/environment_log.dart';
import '../models/plant.dart';

// ── VPD formula ───────────────────────────────────────────────────────────────
//
// Tetens equation: SVP = 0.6108 * exp(17.27 * T / (T + 237.3))
// VPD (kPa)      = SVP * (1 − RH / 100)

/// Calculates Vapour Pressure Deficit in kPa.
/// [tempC] must be in Celsius; [humidity] is relative humidity 0–100.
double computeVpd(double tempC, double humidity) {
  final svp = 0.6108 * exp(17.27 * tempC / (tempC + 237.3));
  return svp * (1 - humidity / 100);
}

// ── Grow phases ───────────────────────────────────────────────────────────────
//
// We derive phases from lifecycle timestamps (startDate / flipDate /
// harvestedDate) because individual env logs don't carry a stage field.
//
// Phase split:
//   startDate  → flipDate           = Vegetative
//   flipDate   → midpoint(flower)   = Early Flower
//   midpoint   → harvestedDate      = Late Flower
//
// When no flipDate is recorded the entire grow is labelled Vegetative so
// callers always get at least one phase with data.

enum GrowPhase { vegetative, earlyFlower, lateFlower }

extension GrowPhaseExt on GrowPhase {
  String get label {
    switch (this) {
      case GrowPhase.vegetative:
        return 'Vegetative';
      case GrowPhase.earlyFlower:
        return 'Early Flower';
      case GrowPhase.lateFlower:
        return 'Late Flower';
    }
  }

  String get shortLabel {
    switch (this) {
      case GrowPhase.vegetative:
        return 'Veg';
      case GrowPhase.earlyFlower:
        return 'E.Flower';
      case GrowPhase.lateFlower:
        return 'L.Flower';
    }
  }

  /// Ideal VPD band lower bound (kPa).
  double get targetLow {
    switch (this) {
      case GrowPhase.vegetative:
        return 0.8;
      case GrowPhase.earlyFlower:
        return 1.0;
      case GrowPhase.lateFlower:
        return 1.2;
    }
  }

  /// Ideal VPD band upper bound (kPa).
  double get targetHigh {
    switch (this) {
      case GrowPhase.vegetative:
        return 1.2;
      case GrowPhase.earlyFlower:
        return 1.6;
      case GrowPhase.lateFlower:
        return 1.6;
    }
  }

  String get targetLabel =>
      '${targetLow.toStringAsFixed(1)}–${targetHigh.toStringAsFixed(1)} kPa';
}

// ── Result types ─────────────────────────────────────────────────────────────

class VpdPhaseResult {
  final GrowPhase phase;
  final int readingCount;

  /// Average VPD across all readings in this phase (kPa).
  final double avgVpd;

  /// Percentage of readings whose VPD fell within the phase's ideal band.
  final double pctInRange; // 0–100

  const VpdPhaseResult({
    required this.phase,
    required this.readingCount,
    required this.avgVpd,
    required this.pctInRange,
  });

  /// Whether the average VPD is inside the ideal band.
  bool get avgInRange =>
      avgVpd >= phase.targetLow && avgVpd <= phase.targetHigh;

  /// High / in-range / low relative to the ideal band.
  VpdStatus get status {
    if (avgVpd < phase.targetLow) return VpdStatus.low;
    if (avgVpd > phase.targetHigh) return VpdStatus.high;
    return VpdStatus.ideal;
  }
}

enum VpdStatus { low, ideal, high }

class PlantVpdSummary {
  final List<VpdPhaseResult> phases;
  final double overallAvgVpd;

  /// % of readings in range across all phases (each phase uses its own band).
  final double overallPctInRange;
  final int totalReadings;

  const PlantVpdSummary({
    required this.phases,
    required this.overallAvgVpd,
    required this.overallPctInRange,
    required this.totalReadings,
  });

  /// True when enough data exists to display meaningful results.
  bool get hasData => totalReadings >= 3;

  static const empty = PlantVpdSummary(
    phases: [],
    overallAvgVpd: 0,
    overallPctInRange: 0,
    totalReadings: 0,
  );
}

// ── Phase assignment ──────────────────────────────────────────────────────────

/// Returns the [GrowPhase] that [ts] falls into for [plant], or null when
/// [ts] is outside the grow window (before startDate or after harvest/now).
///
/// Used by both VPD and issue-pattern engines.
GrowPhase? growPhaseForTimestamp(DateTime ts, Plant plant) {
  final growEnd = plant.harvestedDate ?? DateTime.now();

  if (ts.isBefore(plant.startDate) || ts.isAfter(growEnd)) return null;

  if (plant.flipDate == null) {
    // No flip recorded — treat entire grow as vegetative.
    return GrowPhase.vegetative;
  }

  if (ts.isBefore(plant.flipDate!)) return GrowPhase.vegetative;

  // Split flower phase at its midpoint.
  final flowerMs = growEnd.difference(plant.flipDate!).inMilliseconds;
  final midpoint =
      plant.flipDate!.add(Duration(milliseconds: flowerMs ~/ 2));

  return ts.isBefore(midpoint) ? GrowPhase.earlyFlower : GrowPhase.lateFlower;
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Computes per-phase VPD analytics for [plant] using [logs].
///
/// Only logs from the plant's own grow space and within the grow window
/// (startDate → harvestedDate or now) are considered. Logs missing either
/// temperature or humidity are skipped.
PlantVpdSummary computePlantVpdAnalytics(
  Plant plant,
  List<EnvironmentLog> logs,
) {
  final growEnd = plant.harvestedDate ?? DateTime.now();

  final relevant = logs.where((l) =>
      l.growSpaceId == plant.growSpaceId &&
      l.temperature != null &&
      l.humidity != null &&
      l.recordedAt.isAfter(plant.startDate) &&
      l.recordedAt.isBefore(growEnd));

  if (relevant.isEmpty) return PlantVpdSummary.empty;

  final Map<GrowPhase, List<double>> byPhase = {};

  for (final log in relevant) {
    final phase = growPhaseForTimestamp(log.recordedAt, plant);
    if (phase == null) continue;
    final vpd = computeVpd(log.temperature!, log.humidity!);
    byPhase.putIfAbsent(phase, () => []).add(vpd);
  }

  if (byPhase.isEmpty) return PlantVpdSummary.empty;

  final results = <VpdPhaseResult>[];

  for (final phase in GrowPhase.values) {
    final vpds = byPhase[phase];
    if (vpds == null || vpds.isEmpty) continue;

    final avg = vpds.reduce((a, b) => a + b) / vpds.length;
    final inRange = vpds
        .where((v) => v >= phase.targetLow && v <= phase.targetHigh)
        .length;

    results.add(VpdPhaseResult(
      phase: phase,
      readingCount: vpds.length,
      avgVpd: avg,
      pctInRange: (inRange / vpds.length) * 100,
    ));
  }

  // Overall stats — each phase's readings are judged by that phase's band.
  final allVpds = byPhase.values.expand((v) => v).toList();
  final overallAvg = allVpds.reduce((a, b) => a + b) / allVpds.length;

  int totalInRange = 0;
  int totalCount = 0;
  byPhase.forEach((phase, vpds) {
    totalCount += vpds.length;
    totalInRange += vpds
        .where((v) => v >= phase.targetLow && v <= phase.targetHigh)
        .length;
  });

  return PlantVpdSummary(
    phases: results,
    overallAvgVpd: overallAvg,
    overallPctInRange: totalCount > 0 ? (totalInRange / totalCount) * 100 : 0,
    totalReadings: allVpds.length,
  );
}
