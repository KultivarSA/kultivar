import 'strain_phase_targets.dart';

class Strain {
  // ── Identity ───────────────────────────────────────────────────────────────
  final String id;
  final String name;
  final String genetics; // free-text lineage string (legacy / user-edited)
  final String type;     // 'Indica' | 'Sativa' | 'Hybrid'
  final bool isAutoflower;
  final String? breeder;

  // ── Growth timeline ────────────────────────────────────────────────────────
  /// Legacy single value kept for backward-compat.  Prefer [flowerWeeksMin]/[flowerWeeksMax].
  final int? expectedFlowerDays;
  final int? flowerWeeksMin;
  final int? flowerWeeksMax;
  final double? stretchFactor;    // e.g. 1.8 means plant ~doubles in height at flip
  final int? heightCmMin;
  final int? heightCmMax;
  final int? yieldGPerM2Min;
  final int? yieldGPerM2Max;

  // ── Phase environment targets ──────────────────────────────────────────────
  final StrainPhaseTargets? vegTargets;
  final StrainPhaseTargets? earlyFlowerTargets;
  final StrainPhaseTargets? lateFlowerTargets;

  // ── Feeding profile ────────────────────────────────────────────────────────
  /// 'light' | 'medium' | 'heavy'
  final String? feedingIntensity;
  final double? phMin;
  final double? phMax;
  final double? ecVegMin;
  final double? ecVegMax;
  final double? ecFlowerMin;
  final double? ecFlowerMax;

  // ── Training ───────────────────────────────────────────────────────────────
  /// e.g. ['lst', 'topping', 'scrog', 'sog', 'mainline', 'lollipopping']
  final List<String> recommendedTraining;

  // ── Output ─────────────────────────────────────────────────────────────────
  final double? thcPctMin;
  final double? thcPctMax;
  final double? cbdPctMin;
  final double? cbdPctMax;
  /// e.g. ['myrcene', 'caryophyllene', 'limonene']
  final List<String> terpenes;
  final int? cureWeeksMin;
  final int? cureWeeksMax;

  // ── Legacy / user ──────────────────────────────────────────────────────────
  final double? expectedYieldPercent;
  final String? notes;
  final DateTime createdAt;

  const Strain({
    required this.id,
    required this.name,
    required this.genetics,
    required this.type,
    this.isAutoflower = false,
    this.breeder,
    this.expectedFlowerDays,
    this.flowerWeeksMin,
    this.flowerWeeksMax,
    this.stretchFactor,
    this.heightCmMin,
    this.heightCmMax,
    this.yieldGPerM2Min,
    this.yieldGPerM2Max,
    this.vegTargets,
    this.earlyFlowerTargets,
    this.lateFlowerTargets,
    this.feedingIntensity,
    this.phMin,
    this.phMax,
    this.ecVegMin,
    this.ecVegMax,
    this.ecFlowerMin,
    this.ecFlowerMax,
    this.recommendedTraining = const [],
    this.thcPctMin,
    this.thcPctMax,
    this.cbdPctMin,
    this.cbdPctMax,
    this.terpenes = const [],
    this.cureWeeksMin,
    this.cureWeeksMax,
    this.expectedYieldPercent,
    this.notes,
    required this.createdAt,
  });

  // ── Computed helpers ───────────────────────────────────────────────────────

  String get typeLabel => type;

  /// Human-readable flowering time, always in **days** for consistency
  /// across the catalog, preview sheet, and compare screen.  When the
  /// underlying data is a week range, we multiply by 7 — the unit
  /// shown to the user stays "d" regardless of how the strain entry
  /// was authored.
  String get flowerTimeLabel {
    if (flowerWeeksMin != null && flowerWeeksMax != null) {
      return '${flowerWeeksMin! * 7}–${flowerWeeksMax! * 7} days';
    }
    if (expectedFlowerDays != null) return '$expectedFlowerDays days';
    return 'Unknown';
  }

  String? get thcLabel {
    if (thcPctMin == null && thcPctMax == null) return null;
    if (thcPctMin != null && thcPctMax != null) {
      return '${thcPctMin!.toStringAsFixed(0)}–${thcPctMax!.toStringAsFixed(0)}%';
    }
    return '${(thcPctMin ?? thcPctMax)!.toStringAsFixed(0)}%';
  }

  String? get cbdLabel {
    if (cbdPctMin == null && cbdPctMax == null) return null;
    final max = cbdPctMax ?? cbdPctMin!;
    if (max < 0.5) return '<1%';
    if (cbdPctMin != null && cbdPctMax != null) {
      return '${cbdPctMin!.toStringAsFixed(1)}–${cbdPctMax!.toStringAsFixed(1)}%';
    }
    return '${max.toStringAsFixed(1)}%';
  }

  bool get hasRichData =>
      vegTargets != null ||
      earlyFlowerTargets != null ||
      lateFlowerTargets != null ||
      feedingIntensity != null ||
      thcPctMin != null ||
      recommendedTraining.isNotEmpty;

  // ── copyWith ───────────────────────────────────────────────────────────────

  static const _unset = Object();

  Strain copyWith({
    String? name,
    String? genetics,
    String? type,
    bool? isAutoflower,
    Object? breeder = _unset,
    Object? expectedFlowerDays = _unset,
    Object? flowerWeeksMin = _unset,
    Object? flowerWeeksMax = _unset,
    Object? stretchFactor = _unset,
    Object? heightCmMin = _unset,
    Object? heightCmMax = _unset,
    Object? yieldGPerM2Min = _unset,
    Object? yieldGPerM2Max = _unset,
    Object? vegTargets = _unset,
    Object? earlyFlowerTargets = _unset,
    Object? lateFlowerTargets = _unset,
    Object? feedingIntensity = _unset,
    Object? phMin = _unset,
    Object? phMax = _unset,
    Object? ecVegMin = _unset,
    Object? ecVegMax = _unset,
    Object? ecFlowerMin = _unset,
    Object? ecFlowerMax = _unset,
    List<String>? recommendedTraining,
    Object? thcPctMin = _unset,
    Object? thcPctMax = _unset,
    Object? cbdPctMin = _unset,
    Object? cbdPctMax = _unset,
    List<String>? terpenes,
    Object? cureWeeksMin = _unset,
    Object? cureWeeksMax = _unset,
    Object? expectedYieldPercent = _unset,
    Object? notes = _unset,
  }) {
    return Strain(
      id: id,
      name:       name       ?? this.name,
      genetics:   genetics   ?? this.genetics,
      type:       type       ?? this.type,
      isAutoflower: isAutoflower ?? this.isAutoflower,
      breeder: identical(breeder, _unset) ? this.breeder : breeder as String?,
      expectedFlowerDays: identical(expectedFlowerDays, _unset) ? this.expectedFlowerDays : expectedFlowerDays as int?,
      flowerWeeksMin: identical(flowerWeeksMin, _unset) ? this.flowerWeeksMin : flowerWeeksMin as int?,
      flowerWeeksMax: identical(flowerWeeksMax, _unset) ? this.flowerWeeksMax : flowerWeeksMax as int?,
      stretchFactor: identical(stretchFactor, _unset) ? this.stretchFactor : stretchFactor as double?,
      heightCmMin: identical(heightCmMin, _unset) ? this.heightCmMin : heightCmMin as int?,
      heightCmMax: identical(heightCmMax, _unset) ? this.heightCmMax : heightCmMax as int?,
      yieldGPerM2Min: identical(yieldGPerM2Min, _unset) ? this.yieldGPerM2Min : yieldGPerM2Min as int?,
      yieldGPerM2Max: identical(yieldGPerM2Max, _unset) ? this.yieldGPerM2Max : yieldGPerM2Max as int?,
      vegTargets: identical(vegTargets, _unset) ? this.vegTargets : vegTargets as StrainPhaseTargets?,
      earlyFlowerTargets: identical(earlyFlowerTargets, _unset) ? this.earlyFlowerTargets : earlyFlowerTargets as StrainPhaseTargets?,
      lateFlowerTargets: identical(lateFlowerTargets, _unset) ? this.lateFlowerTargets : lateFlowerTargets as StrainPhaseTargets?,
      feedingIntensity: identical(feedingIntensity, _unset) ? this.feedingIntensity : feedingIntensity as String?,
      phMin: identical(phMin, _unset) ? this.phMin : phMin as double?,
      phMax: identical(phMax, _unset) ? this.phMax : phMax as double?,
      ecVegMin: identical(ecVegMin, _unset) ? this.ecVegMin : ecVegMin as double?,
      ecVegMax: identical(ecVegMax, _unset) ? this.ecVegMax : ecVegMax as double?,
      ecFlowerMin: identical(ecFlowerMin, _unset) ? this.ecFlowerMin : ecFlowerMin as double?,
      ecFlowerMax: identical(ecFlowerMax, _unset) ? this.ecFlowerMax : ecFlowerMax as double?,
      recommendedTraining: recommendedTraining ?? this.recommendedTraining,
      thcPctMin: identical(thcPctMin, _unset) ? this.thcPctMin : thcPctMin as double?,
      thcPctMax: identical(thcPctMax, _unset) ? this.thcPctMax : thcPctMax as double?,
      cbdPctMin: identical(cbdPctMin, _unset) ? this.cbdPctMin : cbdPctMin as double?,
      cbdPctMax: identical(cbdPctMax, _unset) ? this.cbdPctMax : cbdPctMax as double?,
      terpenes: terpenes ?? this.terpenes,
      cureWeeksMin: identical(cureWeeksMin, _unset) ? this.cureWeeksMin : cureWeeksMin as int?,
      cureWeeksMax: identical(cureWeeksMax, _unset) ? this.cureWeeksMax : cureWeeksMax as int?,
      expectedYieldPercent: identical(expectedYieldPercent, _unset) ? this.expectedYieldPercent : expectedYieldPercent as double?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      createdAt: createdAt,
    );
  }

  // ── JSON ───────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genetics': genetics,
        'type': type,
        'isAutoflower': isAutoflower,
        if (breeder != null) 'breeder': breeder,
        'expectedFlowerDays': expectedFlowerDays,
        if (flowerWeeksMin != null) 'flowerWeeksMin': flowerWeeksMin,
        if (flowerWeeksMax != null) 'flowerWeeksMax': flowerWeeksMax,
        if (stretchFactor != null) 'stretchFactor': stretchFactor,
        if (heightCmMin != null) 'heightCmMin': heightCmMin,
        if (heightCmMax != null) 'heightCmMax': heightCmMax,
        if (yieldGPerM2Min != null) 'yieldGPerM2Min': yieldGPerM2Min,
        if (yieldGPerM2Max != null) 'yieldGPerM2Max': yieldGPerM2Max,
        if (vegTargets != null) 'vegTargets': vegTargets!.toJson(),
        if (earlyFlowerTargets != null) 'earlyFlowerTargets': earlyFlowerTargets!.toJson(),
        if (lateFlowerTargets != null) 'lateFlowerTargets': lateFlowerTargets!.toJson(),
        if (feedingIntensity != null) 'feedingIntensity': feedingIntensity,
        if (phMin != null) 'phMin': phMin,
        if (phMax != null) 'phMax': phMax,
        if (ecVegMin != null) 'ecVegMin': ecVegMin,
        if (ecVegMax != null) 'ecVegMax': ecVegMax,
        if (ecFlowerMin != null) 'ecFlowerMin': ecFlowerMin,
        if (ecFlowerMax != null) 'ecFlowerMax': ecFlowerMax,
        if (recommendedTraining.isNotEmpty) 'recommendedTraining': recommendedTraining,
        if (thcPctMin != null) 'thcPctMin': thcPctMin,
        if (thcPctMax != null) 'thcPctMax': thcPctMax,
        if (cbdPctMin != null) 'cbdPctMin': cbdPctMin,
        if (cbdPctMax != null) 'cbdPctMax': cbdPctMax,
        if (terpenes.isNotEmpty) 'terpenes': terpenes,
        if (cureWeeksMin != null) 'cureWeeksMin': cureWeeksMin,
        if (cureWeeksMax != null) 'cureWeeksMax': cureWeeksMax,
        'expectedYieldPercent': expectedYieldPercent,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Strain.fromJson(Map<String, dynamic> json) => Strain(
        id:          json['id'],
        name:        json['name'],
        genetics:    json['genetics'] ?? '',
        type:        json['type'] ?? 'Hybrid',
        isAutoflower: json['isAutoflower'] as bool? ?? false,
        breeder:     json['breeder'] as String?,
        expectedFlowerDays: json['expectedFlowerDays'] as int?,
        flowerWeeksMin: json['flowerWeeksMin'] as int?,
        flowerWeeksMax: json['flowerWeeksMax'] as int?,
        stretchFactor: (json['stretchFactor'] as num?)?.toDouble(),
        heightCmMin: json['heightCmMin'] as int?,
        heightCmMax: json['heightCmMax'] as int?,
        yieldGPerM2Min: json['yieldGPerM2Min'] as int?,
        yieldGPerM2Max: json['yieldGPerM2Max'] as int?,
        vegTargets: json['vegTargets'] != null
            ? StrainPhaseTargets.fromJson(json['vegTargets'] as Map<String, dynamic>)
            : null,
        earlyFlowerTargets: json['earlyFlowerTargets'] != null
            ? StrainPhaseTargets.fromJson(json['earlyFlowerTargets'] as Map<String, dynamic>)
            : null,
        lateFlowerTargets: json['lateFlowerTargets'] != null
            ? StrainPhaseTargets.fromJson(json['lateFlowerTargets'] as Map<String, dynamic>)
            : null,
        feedingIntensity: json['feedingIntensity'] as String?,
        phMin: (json['phMin'] as num?)?.toDouble(),
        phMax: (json['phMax'] as num?)?.toDouble(),
        ecVegMin: (json['ecVegMin'] as num?)?.toDouble(),
        ecVegMax: (json['ecVegMax'] as num?)?.toDouble(),
        ecFlowerMin: (json['ecFlowerMin'] as num?)?.toDouble(),
        ecFlowerMax: (json['ecFlowerMax'] as num?)?.toDouble(),
        recommendedTraining: (json['recommendedTraining'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        thcPctMin: (json['thcPctMin'] as num?)?.toDouble(),
        thcPctMax: (json['thcPctMax'] as num?)?.toDouble(),
        cbdPctMin: (json['cbdPctMin'] as num?)?.toDouble(),
        cbdPctMax: (json['cbdPctMax'] as num?)?.toDouble(),
        terpenes: (json['terpenes'] as List<dynamic>?)?.cast<String>() ?? const [],
        cureWeeksMin: json['cureWeeksMin'] as int?,
        cureWeeksMax: json['cureWeeksMax'] as int?,
        expectedYieldPercent: (json['expectedYieldPercent'] as num?)?.toDouble(),
        notes:   json['notes'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );
}
