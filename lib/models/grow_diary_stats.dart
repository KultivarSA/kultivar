/// Aggregated community grow-context stats for a single strain.
///
/// Sourced from the `strain_grow_stats` view (min 5 submissions).
/// Covers medium, light type, training technique popularity, and
/// average stage durations — the "how they grew it" complement to
/// [StrainCommunityStats]'s "how much they got" yield data.
class GrowDiaryStats {
  final String strainName;
  final int sampleCount;

  /// Most common medium across all submissions (DB key, e.g. 'coco').
  final String? topMedium;

  /// Most common light type (DB key, e.g. 'led').
  final String? topLightType;

  /// Percentage of submissions using each medium (0–100).
  final double? pctSoil;
  final double? pctCoco;
  final double? pctHydro;

  /// Percentage of submissions using LED / HPS.
  final double? pctLed;
  final double? pctHps;

  /// Average veg and flower durations in days.
  final int? avgVegDays;
  final int? avgFlowerDays;

  /// Average quality rating (1–5 scale), or null if not enough rated grows.
  final double? avgQualityRating;

  const GrowDiaryStats({
    required this.strainName,
    required this.sampleCount,
    this.topMedium,
    this.topLightType,
    this.pctSoil,
    this.pctCoco,
    this.pctHydro,
    this.pctLed,
    this.pctHps,
    this.avgVegDays,
    this.avgFlowerDays,
    this.avgQualityRating,
  });

  factory GrowDiaryStats.fromJson(Map<String, dynamic> json) {
    return GrowDiaryStats(
      strainName:       json['strain_name']        as String,
      sampleCount:      (json['sample_count'] as num).toInt(),
      topMedium:        json['top_medium']          as String?,
      topLightType:     json['top_light_type']      as String?,
      pctSoil:          (json['pct_soil']      as num?)?.toDouble(),
      pctCoco:          (json['pct_coco']      as num?)?.toDouble(),
      pctHydro:         (json['pct_hydro']     as num?)?.toDouble(),
      pctLed:           (json['pct_led']       as num?)?.toDouble(),
      pctHps:           (json['pct_hps']       as num?)?.toDouble(),
      avgVegDays:       (json['avg_veg_days']   as num?)?.toInt(),
      avgFlowerDays:    (json['avg_flower_days'] as num?)?.toInt(),
      avgQualityRating: (json['avg_quality_rating'] as num?)?.toDouble(),
    );
  }

  // ── Label helpers ──────────────────────────────────────────────────────────

  /// Human-readable label for a medium DB key.
  static String mediumLabel(String key) => switch (key) {
    'soil'        => 'Soil',
    'coco'        => 'Coco',
    'hydro'       => 'Hydro',
    'living_soil' => 'Living Soil',
    _             => 'Other',
  };

  /// Human-readable label for a light-type DB key.
  static String lightLabel(String key) => switch (key) {
    'led'         => 'LED',
    'hps'         => 'HPS',
    'cmh'         => 'CMH',
    'fluorescent' => 'Fluorescent',
    'natural'     => 'Natural',
    _             => 'Other',
  };
}
