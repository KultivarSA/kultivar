import 'dart:math' as math;

/// Semantic meaning of an insight — the UI decides how to visualise it.
enum InsightType {
  positive,
  negative,
  neutral,
}

class Insight {
  final String message;
  final InsightType type;

  Insight(this.message, this.type);
}

/// Generates a list of insights by comparing [currentValues] (the smoothed
/// or raw series for the selected time window) against [baselineValues]
/// (always the raw series for the same window).
///
/// Returns an empty list when there is not enough data.
List<Insight> generateInsights(
  List<double> currentValues,
  List<double> baselineValues,
) {
  if (currentValues.isEmpty || baselineValues.isEmpty) return [];

  final insights = <Insight>[];

  final currentAvg =
      currentValues.reduce((a, b) => a + b) / currentValues.length;
  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  // ── Trend vs baseline ─────────────────────────
  if (currentAvg > baselineAvg + 3) {
    insights.add(Insight(
      'Yield has improved compared to baseline — keep up the good work.',
      InsightType.positive,
    ));
  } else if (currentAvg < baselineAvg - 3) {
    insights.add(Insight(
      'Yield is below the expected baseline — review your last few grows.',
      InsightType.negative,
    ));
  } else {
    insights.add(Insight(
      'Yield is stable relative to baseline.',
      InsightType.neutral,
    ));
  }

  // ── Consistency (standard deviation) ─────────
  if (baselineValues.length > 2) {
    final variance = baselineValues
            .map((v) => (v - baselineAvg) * (v - baselineAvg))
            .reduce((a, b) => a + b) /
        baselineValues.length;
    final stdDev = math.sqrt(variance);

    if (stdDev > 15) {
      insights.add(Insight(
        'High variability between grows (σ ${stdDev.toStringAsFixed(1)}%) '
        '— environmental consistency could be improved.',
        InsightType.negative,
      ));
    } else if (stdDev < 5 && baselineValues.length >= 3) {
      insights.add(Insight(
        'Very consistent yields across grows (σ ${stdDev.toStringAsFixed(1)}%).',
        InsightType.positive,
      ));
    }
  }

  // ── Recent trend (second half vs first half) ──
  if (baselineValues.length >= 4) {
    final half = baselineValues.length ~/ 2;
    final earlier = baselineValues.sublist(0, half);
    final recent = baselineValues.sublist(half);
    final earlierAvg = earlier.reduce((a, b) => a + b) / earlier.length;
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;

    if (recentAvg > earlierAvg + 5) {
      insights.add(Insight(
        'Yields are trending upward in the most recent grows.',
        InsightType.positive,
      ));
    } else if (recentAvg < earlierAvg - 5) {
      insights.add(Insight(
        'Yields are trending downward in the most recent grows.',
        InsightType.negative,
      ));
    }
  }

  // ── Best yield in period ──────────────────────
  if (baselineValues.isNotEmpty) {
    final best = baselineValues.reduce(math.max);
    if (best > 0) {
      insights.add(Insight(
        'Best yield this period: ${best.toStringAsFixed(1)}%.',
        InsightType.neutral,
      ));
    }
  }

  return insights;
}
