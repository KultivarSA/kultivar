/// Sentinel type used by [HarvestLog.copyWith] to distinguish "not supplied"
/// from an explicit `null`. `const` so it can be used as a default value.
class _AbsentMark {
  const _AbsentMark();
}

class HarvestLog {
  final String id;
  final String plantId;
  final String plantName;
  final String strain;
  final DateTime harvestedDate;
  final double? wetWeight;
  final double? dryWeight;
  final String? notes;
  final bool isDraft;

  /// Phenotype label copied from the plant at harvest time.
  /// Allows analytics to break down yield by phenotype within a strain.
  final String? phenotypeTag;

  // ── Quality assessment ────────────────────────
  // Ratings are 0.5–5.0 in 0.5 steps so users can pick half-stars (e.g.
  // 3.5/5).  The migration from the old int? format is automatic — old
  // values cleanly cast to double via [fromJson] (3 → 3.0) and still
  // render as the same number of full stars.
  final double? qualityRating; // 0.5–5.0 overall, in 0.5 steps
  final String? aromaNote;
  final String? flavorNotes;
  final String? effectNotes;

  // ── Sub-scores (0.5–5.0 each, 0.5 steps) ─────
  final double? smellRating;
  final double? effectRating;
  final double? bagAppealRating;

  bool get hasQualityAssessment =>
      qualityRating != null ||
      aromaNote != null ||
      flavorNotes != null ||
      effectNotes != null ||
      smellRating != null ||
      effectRating != null ||
      bagAppealRating != null;

  const HarvestLog({
    required this.id,
    required this.plantId,
    required this.plantName,
    required this.strain,
    required this.harvestedDate,
    this.wetWeight,
    this.dryWeight,
    this.notes,
    this.isDraft = true,
    this.phenotypeTag,
    this.qualityRating,
    this.aromaNote,
    this.flavorNotes,
    this.effectNotes,
    this.smellRating,
    this.effectRating,
    this.bagAppealRating,
  });

  /// Creates a copy with the given fields replaced.
  ///
  /// Quality fields ([qualityRating], [aromaNote], [flavorNotes], [effectNotes])
  /// support explicit `null` to *clear* an existing value:
  /// ```dart
  /// log.copyWith(qualityRating: null)  // clears rating
  /// log.copyWith()                     // rating unchanged
  /// ```
  HarvestLog copyWith({
    double? dryWeight,
    bool? isDraft,
    Object? phenotypeTag = const _AbsentMark(),
    Object? qualityRating = const _AbsentMark(),
    Object? aromaNote = const _AbsentMark(),
    Object? flavorNotes = const _AbsentMark(),
    Object? effectNotes = const _AbsentMark(),
    Object? smellRating = const _AbsentMark(),
    Object? effectRating = const _AbsentMark(),
    Object? bagAppealRating = const _AbsentMark(),
  }) {
    return HarvestLog(
      id: id,
      plantId: plantId,
      plantName: plantName,
      strain: strain,
      harvestedDate: harvestedDate,
      wetWeight: wetWeight,
      dryWeight: dryWeight ?? this.dryWeight,
      notes: notes,
      isDraft: isDraft ?? this.isDraft,
      phenotypeTag: phenotypeTag is _AbsentMark
          ? this.phenotypeTag
          : phenotypeTag as String?,
      qualityRating: qualityRating is _AbsentMark
          ? this.qualityRating
          : qualityRating as double?,
      aromaNote:
          aromaNote is _AbsentMark ? this.aromaNote : aromaNote as String?,
      flavorNotes: flavorNotes is _AbsentMark
          ? this.flavorNotes
          : flavorNotes as String?,
      effectNotes: effectNotes is _AbsentMark
          ? this.effectNotes
          : effectNotes as String?,
      smellRating: smellRating is _AbsentMark
          ? this.smellRating
          : smellRating as double?,
      effectRating: effectRating is _AbsentMark
          ? this.effectRating
          : effectRating as double?,
      bagAppealRating: bagAppealRating is _AbsentMark
          ? this.bagAppealRating
          : bagAppealRating as double?,
    );
  }

  double? get yieldPercentage {
    if (wetWeight != null && dryWeight != null && wetWeight! > 0) {
      return (dryWeight! / wetWeight!) * 100;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'plantName': plantName,
        'strain': strain,
        'harvestedDate': harvestedDate.toIso8601String(),
        'wetWeight': wetWeight,
        'dryWeight': dryWeight,
        'notes': notes,
        'isDraft': isDraft,
        'phenotypeTag': phenotypeTag,
        'qualityRating': qualityRating,
        'aromaNote': aromaNote,
        'flavorNotes': flavorNotes,
        'effectNotes': effectNotes,
        'smellRating': smellRating,
        'effectRating': effectRating,
        'bagAppealRating': bagAppealRating,
      };

  factory HarvestLog.fromJson(Map<String, dynamic> json) => HarvestLog(
        id: json['id'],
        plantId: json['plantId'] ?? '',
        plantName: json['plantName'],
        strain: json['strain'],
        harvestedDate: DateTime.parse(json['harvestedDate']),
        wetWeight: (json['wetWeight'] as num?)?.toDouble(),
        dryWeight: (json['dryWeight'] as num?)?.toDouble(),
        notes: json['notes'],
        isDraft: json['isDraft'] ?? false,
        phenotypeTag: json['phenotypeTag'] as String?,
        // num?.toDouble() auto-migrates legacy `int` values (3 → 3.0)
        // without forcing a separate migration pass.
        qualityRating: (json['qualityRating'] as num?)?.toDouble(),
        aromaNote: json['aromaNote'] as String?,
        flavorNotes: json['flavorNotes'] as String?,
        effectNotes: json['effectNotes'] as String?,
        smellRating: (json['smellRating'] as num?)?.toDouble(),
        effectRating: (json['effectRating'] as num?)?.toDouble(),
        bagAppealRating: (json['bagAppealRating'] as num?)?.toDouble(),
      );
}
