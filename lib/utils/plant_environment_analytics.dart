import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import 'temp_format.dart';
import 'vpd_analytics.dart';

class SpaceStay {
  final String spaceId;
  final String spaceName;
  final DateTime from;
  final DateTime to;
  final Duration duration;
  final double? avgTemp;
  final double? avgHumidity;
  final double? optimalPercent;

  const SpaceStay({
    required this.spaceId,
    required this.spaceName,
    required this.from,
    required this.to,
    required this.duration,
    this.avgTemp,
    this.avgHumidity,
    this.optimalPercent,
  });
}

class PlantEnvironmentInsight {
  final String message;
  final InsightSeverity severity;

  const PlantEnvironmentInsight({
    required this.message,
    required this.severity,
  });
}

enum InsightSeverity { positive, warning, neutral }

class PlantEnvironmentAnalytics {
  /// Build a summary of environmental conditions
  /// experienced during the plant's lifecycle.
  static SpaceStay buildSpaceStay({
    required Plant plant,
    required GrowSpace space,
    required List<EnvironmentLog> logs,
  }) {
    final relevantLogs = logs
        .where((l) =>
            l.growSpaceId == plant.growSpaceId &&
            l.recordedAt.isAfter(plant.startDate) &&
            (plant.harvestedDate == null ||
                l.recordedAt.isBefore(plant.harvestedDate!)))
        .toList();

    double? avgTemp;
    double? avgHumidity;
    double? optimalPct;

    if (relevantLogs.isNotEmpty) {
      final temps = relevantLogs
          .where((l) => l.temperature != null)
          .map((l) => l.temperature!)
          .toList();
      final hums = relevantLogs
          .where((l) => l.humidity != null)
          .map((l) => l.humidity!)
          .toList();

      if (temps.isNotEmpty) {
        avgTemp = temps.reduce((a, b) => a + b) / temps.length;
      }
      if (hums.isNotEmpty) {
        avgHumidity = hums.reduce((a, b) => a + b) / hums.length;
      }

      final optimalCount = relevantLogs.where((l) {
        if (l.temperature == null || l.humidity == null) return false;
        return space.isOptimalTemp(l.temperature!) &&
            space.isOptimalHumidity(l.humidity!);
      }).length;
      optimalPct = (optimalCount / relevantLogs.length) * 100;
    }

    final to = plant.harvestedDate ?? plant.archivedAt ?? DateTime.now();

    return SpaceStay(
      spaceId: space.id,
      spaceName: space.name,
      from: plant.startDate,
      to: to,
      duration: to.difference(plant.startDate),
      avgTemp: avgTemp,
      avgHumidity: avgHumidity,
      optimalPercent: optimalPct,
    );
  }

  /// Computes what percentage of environment readings fell within the space's
  /// optimal temp + humidity thresholds, broken down by grow phase.
  ///
  /// Returns a map of [GrowPhase] → optimal-% (0–100). Phases with no
  /// readings are omitted. Only considers logs during the grow window
  /// (startDate → harvestedDate or now).
  static Map<GrowPhase, double> computePhaseOptimalPercent({
    required Plant plant,
    required GrowSpace space,
    required List<EnvironmentLog> logs,
  }) {
    final growEnd = plant.harvestedDate ?? DateTime.now();

    final Map<GrowPhase, ({int total, int optimal})> stats = {};

    for (final log in logs) {
      if (log.growSpaceId != plant.growSpaceId) continue;
      if (log.recordedAt.isBefore(plant.startDate) ||
          log.recordedAt.isAfter(growEnd)) {
        continue;
      }
      if (log.temperature == null && log.humidity == null) continue;

      final phase = growPhaseForTimestamp(log.recordedAt, plant);
      if (phase == null) continue;

      final isOptimal = space.isOptimal(log.temperature, log.humidity);
      final prev = stats[phase] ?? (total: 0, optimal: 0);
      stats[phase] = (
        total: prev.total + 1,
        optimal: prev.optimal + (isOptimal ? 1 : 0),
      );
    }

    final result = <GrowPhase, double>{};
    stats.forEach((phase, s) {
      if (s.total > 0) result[phase] = (s.optimal / s.total) * 100;
    });
    return result;
  }

  /// Generate actionable insights linking
  /// environment to outcomes.
  static List<PlantEnvironmentInsight> generateInsights({
    required Plant plant,
    required List<EnvironmentLog> logs,
    required GrowSpace space,
  }) {
    final insights = <PlantEnvironmentInsight>[];

    if (logs.isEmpty) return insights;

    // Drying phase analysis
    if (plant.harvestedDate != null) {
      final dryingLogs = logs.where((l) =>
          l.growSpaceId == plant.growSpaceId &&
          l.recordedAt.isAfter(plant.harvestedDate!) &&
          (plant.dryingEndDate == null ||
              l.recordedAt.isBefore(plant.dryingEndDate!)));

      if (dryingLogs.isNotEmpty) {
        final avgHumDrying = dryingLogs
                .where((l) => l.humidity != null)
                .map((l) => l.humidity!)
                .fold(0.0, (a, b) => a + b) /
            dryingLogs.where((l) => l.humidity != null).length;

        if (avgHumDrying > 55) {
          insights.add(
            const PlantEnvironmentInsight(
              message: 'High humidity during drying '
                  '(>55%) likely slowed dry time '
                  'and may have reduced yield.',
              severity: InsightSeverity.warning,
            ),
          );
        } else if (avgHumDrying < 40) {
          insights.add(
            const PlantEnvironmentInsight(
              message: 'Low humidity during drying '
                  '(<40%) may have dried too fast, '
                  'affecting terpene retention.',
              severity: InsightSeverity.warning,
            ),
          );
        } else {
          insights.add(
            const PlantEnvironmentInsight(
              message: 'Humidity during drying was '
                  'within ideal range (40–55%).',
              severity: InsightSeverity.positive,
            ),
          );
        }
      }
    }

    // Curing phase analysis
    if (plant.dryingEndDate != null) {
      final curingLogs = logs.where((l) =>
          l.growSpaceId == plant.growSpaceId &&
          l.recordedAt.isAfter(plant.dryingEndDate!));

      if (curingLogs.isNotEmpty) {
        final avgHumCuring = curingLogs
                .where((l) => l.humidity != null)
                .map((l) => l.humidity!)
                .fold(0.0, (a, b) => a + b) /
            curingLogs.where((l) => l.humidity != null).length;

        if (avgHumCuring < 55) {
          insights.add(
            const PlantEnvironmentInsight(
              message: 'Curing humidity was below '
                  'ideal (55–65%). Buds may have '
                  'dried out faster than optimal.',
              severity: InsightSeverity.warning,
            ),
          );
        } else if (avgHumCuring > 65) {
          insights.add(
            const PlantEnvironmentInsight(
              message: 'Curing humidity exceeded 65%. '
                  'Risk of mold during cure.',
              severity: InsightSeverity.warning,
            ),
          );
        } else {
          insights.add(
            const PlantEnvironmentInsight(
              message: 'Curing humidity was in the '
                  'ideal 55–65% range.',
              severity: InsightSeverity.positive,
            ),
          );
        }
      }
    }

    // Growing temperature
    final growingLogs = logs.where((l) =>
        l.growSpaceId == plant.growSpaceId &&
        l.recordedAt.isAfter(plant.startDate) &&
        (plant.harvestedDate == null ||
            l.recordedAt.isBefore(plant.harvestedDate!)));

    if (growingLogs.isNotEmpty) {
      final temps = growingLogs
          .where((l) => l.temperature != null)
          .map((l) => l.temperature!)
          .toList();
      if (temps.isNotEmpty) {
        final avg = temps.reduce((a, b) => a + b) / temps.length;
        if (avg > space.tempMax) {
          insights.add(
            PlantEnvironmentInsight(
              message: 'Average growing temperature '
                  '(${formatTemp(avg)}) '
                  'exceeded your space threshold '
                  '(${formatTemp(space.tempMax)}).',
              severity: InsightSeverity.warning,
            ),
          );
        } else if (avg < space.tempMin) {
          insights.add(
            PlantEnvironmentInsight(
              message: 'Average growing temperature '
                  '(${formatTemp(avg)}) '
                  'was below your space minimum '
                  '(${formatTemp(space.tempMin)}).',
              severity: InsightSeverity.warning,
            ),
          );
        }
      }
    }

    // ── VPD insights ─────────────────────────────
    final vpdSummary = computePlantVpdAnalytics(plant, logs);
    if (vpdSummary.hasData) {
      // Surface the worst-performing phase as an actionable callout.
      VpdPhaseResult? worst;
      for (final phase in vpdSummary.phases) {
        if (phase.status != VpdStatus.ideal) {
          if (worst == null ||
              (phase.status == VpdStatus.high && worst.status != VpdStatus.high) ||
              phase.pctInRange < worst.pctInRange) {
            worst = phase;
          }
        }
      }

      if (worst != null) {
        final direction =
            worst.status == VpdStatus.high ? 'above' : 'below';
        final tip = worst.status == VpdStatus.high
            ? 'Lower humidity or reduce temperature to bring VPD down.'
            : 'Raise humidity or increase temperature to bring VPD up.';
        insights.add(PlantEnvironmentInsight(
          message: '${worst.phase.label} VPD averaged '
              '${worst.avgVpd.toStringAsFixed(2)} kPa — '
              '$direction the ideal ${worst.phase.targetLabel}. $tip',
          severity: InsightSeverity.warning,
        ));
      } else if (vpdSummary.phases.isNotEmpty &&
          vpdSummary.overallPctInRange >= 75) {
        insights.add(PlantEnvironmentInsight(
          message: 'VPD was within the ideal range for '
              '${vpdSummary.overallPctInRange.toStringAsFixed(0)}% '
              'of environment readings across all phases.',
          severity: InsightSeverity.positive,
        ));
      }
    }

    return insights;
  }
}
