/// Aggregated community data for a single strain, returned by the
/// `strain_community_stats` view in Supabase.
///
/// All values represent the pool of anonymous submissions for that strain
/// over the last 2 years, with a minimum sample size of 5.
class StrainCommunityStats {
  final String strainName;

  /// Number of anonymous submissions in this aggregate.
  final int sampleCount;

  /// Dry-weight percentiles (grams).
  final double p25Grams;
  final double medianGrams;
  final double p75Grams;

  /// Average durations in days (null when not enough submissions include them).
  final int? avgGrowDays;
  final int? avgVegDays;
  final int? avgFlowerDays;

  const StrainCommunityStats({
    required this.strainName,
    required this.sampleCount,
    required this.p25Grams,
    required this.medianGrams,
    required this.p75Grams,
    this.avgGrowDays,
    this.avgVegDays,
    this.avgFlowerDays,
  });

  factory StrainCommunityStats.fromJson(Map<String, dynamic> json) {
    return StrainCommunityStats(
      strainName:   json['strain_name'] as String,
      sampleCount:  (json['sample_count'] as num).toInt(),
      p25Grams:     (json['p25_g'] as num).toDouble(),
      medianGrams:  (json['median_g'] as num).toDouble(),
      p75Grams:     (json['p75_g'] as num).toDouble(),
      avgGrowDays:  (json['avg_grow_days'] as num?)?.toInt(),
      avgVegDays:   (json['avg_veg_days'] as num?)?.toInt(),
      avgFlowerDays:(json['avg_flower_days'] as num?)?.toInt(),
    );
  }

  // ── Interpretation helpers ─────────────────────────────────────────────

  /// Where a local dry-weight result sits relative to the community pool.
  CommunityPercentile classify(double localGrams) {
    if (localGrams < p25Grams)    return CommunityPercentile.bottom25;
    if (localGrams < medianGrams) return CommunityPercentile.p25to50;
    if (localGrams < p75Grams)    return CommunityPercentile.p50to75;
    return CommunityPercentile.top25;
  }

  /// Human-readable label for [classify].
  String percentileLabel(double localGrams) {
    switch (classify(localGrams)) {
      case CommunityPercentile.bottom25:
        return 'bottom 25%';
      case CommunityPercentile.p25to50:
        return 'around average';
      case CommunityPercentile.p50to75:
        return 'above average';
      case CommunityPercentile.top25:
        return 'top 25%';
    }
  }

  /// Interquartile range — how spread out the community results are.
  double get iqrGrams => p75Grams - p25Grams;
}

enum CommunityPercentile { bottom25, p25to50, p50to75, top25 }
