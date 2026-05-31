import '../models/harvest_log.dart';
import '../models/plant.dart';

// ── Bucket thresholds ─────────────────────────────────────────────────────────

const int _cureShortDays = 7;
const int _cureLongDays = 14;
const int _dryShortDays = 7;
const int _dryLongDays = 12;

// ── Result types ─────────────────────────────────────────────────────────────

/// A group of harvests bucketed by a duration range with their average rating.
class QualityBucket {
  final String label;
  final int count;
  final double avgRating;

  const QualityBucket({
    required this.label,
    required this.count,
    required this.avgRating,
  });
}

enum QualityInsightPolarity { positive, neutral, negative }

class QualityInsight {
  final String message;
  final QualityInsightPolarity polarity;

  const QualityInsight(this.message, this.polarity);
}

class QualityCorrelationSummary {
  /// Cure-duration buckets, sorted short → long.
  final List<QualityBucket> cureBuckets;

  /// Dry-duration buckets, sorted short → long.
  final List<QualityBucket> dryBuckets;

  /// Plain-English findings derived from the bucket comparisons.
  final List<QualityInsight> insights;

  /// Total harvests that had a quality rating (the denominator).
  final int totalRatedHarvests;

  /// Overall average rating across all rated harvests.
  final double? overallAvgRating;

  /// True when enough rated harvests exist to draw any conclusions.
  bool get hasData => totalRatedHarvests >= 3;

  /// True when cure-duration data is available for correlation.
  bool get hasCureCorrelation => cureBuckets.length >= 2;

  /// True when dry-duration data is available for correlation.
  bool get hasDryCorrelation => dryBuckets.length >= 2;

  const QualityCorrelationSummary({
    required this.cureBuckets,
    required this.dryBuckets,
    required this.insights,
    required this.totalRatedHarvests,
    this.overallAvgRating,
  });

  static const empty = QualityCorrelationSummary(
    cureBuckets: [],
    dryBuckets: [],
    insights: [],
    totalRatedHarvests: 0,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _avgRating(List<double> ratings) =>
    ratings.reduce((a, b) => a + b) / ratings.length;

/// Builds duration-bucketed rating groups. Returns empty list when fewer than
/// 2 buckets have data (not enough to draw conclusions).
List<QualityBucket> _buildBuckets(
  List<({int days, double rating})> data,
  int shortThreshold,
  int longThreshold,
  String shortLabel,
  String midLabel,
  String longLabel,
) {
  final short = <double>[];
  final mid = <double>[];
  final long = <double>[];

  for (final d in data) {
    if (d.days < shortThreshold) {
      short.add(d.rating);
    } else if (d.days < longThreshold) {
      mid.add(d.rating);
    } else {
      long.add(d.rating);
    }
  }

  final buckets = <QualityBucket>[];
  if (short.isNotEmpty) {
    buckets.add(QualityBucket(
        label: shortLabel, count: short.length, avgRating: _avgRating(short)));
  }
  if (mid.isNotEmpty) {
    buckets.add(QualityBucket(
        label: midLabel, count: mid.length, avgRating: _avgRating(mid)));
  }
  if (long.isNotEmpty) {
    buckets.add(QualityBucket(
        label: longLabel, count: long.length, avgRating: _avgRating(long)));
  }

  return buckets.length >= 2 ? buckets : [];
}

/// Generates a plain-English insight when the best and worst buckets differ
/// by a meaningful margin (≥0.5 stars).
QualityInsight? _correlationInsight(
  List<QualityBucket> buckets,
  String higherIsLabel, // "longer" / "shorter"
  String lowerIsLabel,  // "shorter" / "longer"
  String durationNoun,  // "cure" / "drying"
) {
  if (buckets.length < 2) return null;
  final best = buckets.reduce((a, b) => a.avgRating >= b.avgRating ? a : b);
  final worst = buckets.reduce((a, b) => a.avgRating <= b.avgRating ? a : b);
  if (best == worst) return null;

  final diff = best.avgRating - worst.avgRating;
  if (diff < 0.5) return null; // not meaningful enough

  final direction =
      buckets.last.avgRating >= buckets.first.avgRating ? 'longer' : 'shorter';
  final isPositive = direction == 'longer'; // longer = better is the "good" finding

  final totalBest = buckets
      .where((b) => b == best)
      .map((b) => b.count)
      .fold(0, (a, b) => a + b);

  return QualityInsight(
    '${direction[0].toUpperCase()}${direction.substring(1)} $durationNoun '
    'correlates with higher quality — '
    '${best.label} averaged ${best.avgRating.toStringAsFixed(1)}★ '
    'vs ${worst.avgRating.toStringAsFixed(1)}★ for ${worst.label} '
    '(across $totalBest harvests).',
    isPositive ? QualityInsightPolarity.positive : QualityInsightPolarity.neutral,
  );
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Correlates quality ratings against cure and drying durations.
///
/// Requires [plants] to look up lifecycle timestamps (dryingEndDate,
/// curingEndDate) since [HarvestLog] only stores the harvest date.
QualityCorrelationSummary computeQualityCorrelations(
  List<Plant> plants,
  List<HarvestLog> harvestLogs,
) {
  final plantById = {for (final p in plants) p.id: p};

  // Only use logs that have a quality rating and a matching plant.
  final rated = harvestLogs
      .where((l) => l.qualityRating != null && plantById.containsKey(l.plantId))
      .toList();

  if (rated.length < 3) return QualityCorrelationSummary.empty;

  // Overall average.
  final overallAvg = rated
          .map((l) => l.qualityRating!)
          .reduce((a, b) => a + b) /
      rated.length;

  // ── Cure duration correlation ─────────────────
  final cureData = <({int days, double rating})>[];
  for (final log in rated) {
    final plant = plantById[log.plantId]!;
    if (plant.dryingEndDate == null) continue;
    final cureEnd = plant.curingEndDate;
    if (cureEnd == null && plant.status != PlantStatus.curing) continue;

    final effectiveCureEnd = cureEnd ?? DateTime.now();
    final days = effectiveCureEnd.difference(plant.dryingEndDate!).inDays;
    if (days < 0) continue;
    cureData.add((days: days, rating: log.qualityRating!));
  }

  final cureBuckets = _buildBuckets(
    cureData,
    _cureShortDays,
    _cureLongDays,
    '< ${_cureShortDays}d cure',
    '$_cureShortDays–${_cureLongDays}d cure',
    '$_cureLongDays+ day cure',
  );

  // ── Dry duration correlation ──────────────────
  final dryData = <({int days, double rating})>[];
  for (final log in rated) {
    final plant = plantById[log.plantId]!;
    if (plant.harvestedDate == null || plant.dryingEndDate == null) continue;
    final days =
        plant.dryingEndDate!.difference(plant.harvestedDate!).inDays;
    if (days < 0) continue;
    dryData.add((days: days, rating: log.qualityRating!));
  }

  final dryBuckets = _buildBuckets(
    dryData,
    _dryShortDays,
    _dryLongDays,
    '< ${_dryShortDays}d dry',
    '$_dryShortDays–${_dryLongDays}d dry',
    '$_dryLongDays+ day dry',
  );

  // ── Insights ──────────────────────────────────
  final insights = <QualityInsight>[];

  final cureInsight =
      _correlationInsight(cureBuckets, 'longer', 'shorter', 'cure');
  if (cureInsight != null) insights.add(cureInsight);

  final dryInsight =
      _correlationInsight(dryBuckets, 'longer', 'shorter', 'drying');
  if (dryInsight != null) insights.add(dryInsight);

  // If rated harvests exist but no clear pattern emerged, say so.
  if (insights.isEmpty && rated.length >= 4) {
    insights.add(const QualityInsight(
      'No strong correlation found between cure/dry duration and quality '
      'in your data yet — log more harvests to refine the picture.',
      QualityInsightPolarity.neutral,
    ));
  }

  return QualityCorrelationSummary(
    cureBuckets: cureBuckets,
    dryBuckets: dryBuckets,
    insights: insights,
    totalRatedHarvests: rated.length,
    overallAvgRating: overallAvg,
  );
}
