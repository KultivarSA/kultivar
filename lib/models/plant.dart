import 'package:flutter/material.dart'; // ✅ fixes TimeOfDay

// ── Growth stage ──────────────────────────────────

enum GrowStage {
  germination,
  seedling,
  vegetative,
  stretch,
  earlyFlower,
  lateFlower,
  flush,
}

extension GrowStageExt on GrowStage {
  String get label {
    switch (this) {
      case GrowStage.germination:
        return 'Germination';
      case GrowStage.seedling:
        return 'Seedling';
      case GrowStage.vegetative:
        return 'Vegetative';
      case GrowStage.stretch:
        return 'Stretch';
      case GrowStage.earlyFlower:
        return 'Early Flower';
      case GrowStage.lateFlower:
        return 'Late Flower';
      case GrowStage.flush:
        return 'Flush';
    }
  }

  String get shortLabel {
    switch (this) {
      case GrowStage.germination:
        return 'Germ';
      case GrowStage.seedling:
        return 'Seedling';
      case GrowStage.vegetative:
        return 'Veg';
      case GrowStage.stretch:
        return 'Stretch';
      case GrowStage.earlyFlower:
        return 'E.Flower';
      case GrowStage.lateFlower:
        return 'L.Flower';
      case GrowStage.flush:
        return 'Flush';
    }
  }

  int get order => GrowStage.values.indexOf(this);

  GrowStage? get next {
    const all = GrowStage.values;
    final i = all.indexOf(this);
    return i < all.length - 1 ? all[i + 1] : null;
  }

  GrowStage? get previous {
    const all = GrowStage.values;
    final i = all.indexOf(this);
    return i > 0 ? all[i - 1] : null;
  }
}

// ── Plant status ───────────────────────────────────

enum PlantStatus {
  growing,
  harvested,
  drying,
  curing,
  completed,
  removed,
}

class Plant {
  final String id;
  final String name;
  final String strain;
  final String? strainId;
  final DateTime startDate;
  final DateTime? targetHarvestDate;
  final String growSpaceId;
  final bool isClone; // ✅ clone or seed

  final PlantStatus status;
  final bool isArchived;

  final DateTime? harvestedDate;
  final DateTime? dryingEndDate;
  final DateTime? curingEndDate;

  final double? wetWeight;
  final double? dryWeight;

  final String? archiveReason;
  final DateTime? archivedAt;

  final bool burpingRemindersEnabled;
  final String burpingSchedule;
  final TimeOfDay? burpingTime;
  final bool curingCompleteNotification;
  final bool dryingCheckNotification;
  final GrowStage? growStage;
  final bool isAutoflower;
  final DateTime? flipDate;

  /// Grow medium — one of 'soil' | 'coco' | 'hydro' | 'living_soil' | 'other'.
  /// Stored so the community diary form can pre-fill on the first harvest.
  final String? medium;

  /// Primary light type — one of 'led' | 'hps' | 'cmh' | 'fluorescent' | 'other'.
  final String? lightType;

  /// Free-text phenotype label, e.g. "Pheno #3", "Purple pheno", "Tall".
  /// Lets growers distinguish individual phenotype expressions of the same strain.
  final String? phenotypeTag;

  /// Current pot / container size in litres.
  /// Updated automatically when a transplant note is logged.
  final double? potSizeLitres;

  /// ID of the mother plant this plant was cloned from.
  /// Only meaningful when [isClone] is true.
  final String? motherPlantId;

  // ── Outdoor location override ─────────────────
  //
  // Per-plant lat/lon for outdoor weather lookups.  When null, the
  // [OutdoorWeatherCard] falls back to the global location stored in
  // [WeatherService].  This lets growers with plants at multiple sites
  // (e.g. one at home + one at a friend's) see the correct weather for
  // each plant individually.
  final double? latitude;
  final double? longitude;

  /// Optional human-readable label for the override location
  /// (e.g. "Back garden", "Friend's allotment").  Shown in the weather
  /// card when set so the user can tell at a glance which location the
  /// reading is for.
  final String? locationLabel;

  // ── Care-schedule reminders ───────────────────
  final bool wateringReminderEnabled;
  final int wateringIntervalDays;
  final bool feedingReminderEnabled;
  final int feedingIntervalDays;
  final bool ipmReminderEnabled;
  final int ipmIntervalDays;

  /// F10 — when true, the configured base intervals are treated as
  /// the *veg* baseline and lengthened automatically once the plant
  /// moves into flower stages.  Off by default for backwards compat.
  /// See [effectiveWateringIntervalDays] etc. for the per-stage curves.
  final bool autoAdjustIntervalsByStage;

  /// F8 — free-form labels.  Lower-cased, dedup'd, no leading `#`.
  /// Stored on the plant itself (separate from per-note tags) so growers
  /// can pin a single label like `#mother` or `#test-pheno` to the whole
  /// run and filter the Home / Plant list by it.
  final List<String> tags;

  // Dropped `const` because the [tags] field uses a runtime-default
  // (`tags ?? const []`) to keep callers concise while preserving the
  // immutability guarantee at the field level.  No call site used the
  // const form (grep confirmed only this declaration matches).
  Plant({
    required this.id,
    required this.name,
    required this.strain,
    this.strainId,
    required this.startDate,
    this.targetHarvestDate,
    required this.growSpaceId,
    this.isClone = false,
    this.status = PlantStatus.growing,
    this.isArchived = false,
    this.harvestedDate,
    this.dryingEndDate,
    this.curingEndDate,
    this.wetWeight,
    this.dryWeight,
    this.archiveReason,
    this.archivedAt,
    this.burpingRemindersEnabled = false,
    this.burpingSchedule = 'week1',
    this.burpingTime,
    this.curingCompleteNotification = false,
    this.dryingCheckNotification = false,
    this.growStage,
    this.isAutoflower = false,
    this.flipDate,
    this.medium,
    this.lightType,
    this.phenotypeTag,
    this.potSizeLitres,
    this.motherPlantId,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.wateringReminderEnabled = false,
    this.wateringIntervalDays = 2,
    this.feedingReminderEnabled = false,
    this.feedingIntervalDays = 7,
    this.ipmReminderEnabled = false,
    this.ipmIntervalDays = 7,
    this.autoAdjustIntervalsByStage = false,
    List<String>? tags,
  }) : tags = tags ?? const [];

  // ── Computed ─────────────────────────────────

  /// Total days from seed/clone start to now (or archive date).
  int get daysGrowing {
    final end = archivedAt ?? DateTime.now();
    return end.difference(startDate).inDays;
  }

  /// Days the plant has been in its *current* lifecycle phase.
  /// More contextually accurate than [daysGrowing] for post-harvest stages.
  /// Caps at [archivedAt] so removed/completed plants don't keep accumulating.
  int get daysInCurrentStatus {
    // Use archivedAt as the end point so archived plants freeze in time.
    final end = archivedAt ?? DateTime.now();
    switch (status) {
      case PlantStatus.growing:
        return end.difference(startDate).inDays;
      case PlantStatus.harvested:
      case PlantStatus.drying:
        return harvestedDate != null
            ? end.difference(harvestedDate!).inDays
            : 0;
      case PlantStatus.curing:
        return dryingEndDate != null
            ? end.difference(dryingEndDate!).inDays
            : 0;
      case PlantStatus.completed:
      case PlantStatus.removed:
        return 0;
    }
  }

  /// Short label shown in list-view rows — adapts to the current phase so
  /// the counter is always meaningful (e.g. "14d dry" instead of "120d").
  String get statusDaysLabel {
    switch (status) {
      case PlantStatus.growing:
        return '${daysInCurrentStatus}d';
      case PlantStatus.harvested:
      case PlantStatus.drying:
        return '${daysInCurrentStatus}d dry';
      case PlantStatus.curing:
        return '${daysInCurrentStatus}d cure';
      case PlantStatus.completed:
        return 'Done';
      case PlantStatus.removed:
        return 'Removed';
    }
  }

  int? get daysUntilTargetHarvest {
    if (targetHarvestDate == null) return null;
    return targetHarvestDate!.difference(DateTime.now()).inDays;
  }

  int get daysDrying {
    if (status != PlantStatus.drying || harvestedDate == null) return 0;
    final end = archivedAt ?? DateTime.now();
    return end.difference(harvestedDate!).inDays;
  }

  int get dryingDaysRemaining {
    if (dryingEndDate == null) return 0;
    return dryingEndDate!.difference(DateTime.now()).inDays.clamp(0, 365);
  }

  int get daysCuring {
    if (status != PlantStatus.curing || dryingEndDate == null) return 0;
    final end = archivedAt ?? DateTime.now();
    return end.difference(dryingEndDate!).inDays;
  }

  int get curingDaysRemaining {
    if (curingEndDate == null) return 0;
    return curingEndDate!.difference(DateTime.now()).inDays.clamp(0, 365);
  }

  String get statusLabel =>
      status.name[0].toUpperCase() + status.name.substring(1);

  String get burpingScheduleLabel {
    switch (burpingSchedule) {
      case 'week1':
        return 'Week 1: 1-2x daily (15-30 min)';
      case 'week2':
        return 'Week 2: 1x daily or every other day';
      case 'week3':
        return 'Week 3-4: Every 2-3 days';
      case 'week4plus':
        return 'Week 4+: Weekly or as needed';
      default:
        return 'Week 1: 1-2x daily (15-30 min)';
    }
  }

  // ── copyWith ─────────────────────────────────
  //
  // Nullable fields use a sentinel so callers can explicitly pass null to
  // clear a value: plant.copyWith(strainId: null) works as expected.

  static const _unset = Object();

  Plant copyWith({
    String? name,
    String? strain,
    DateTime? startDate,
    PlantStatus? status,
    bool? isArchived,
    bool? isClone,
    String? growSpaceId,
    Object? strainId = _unset,
    Object? targetHarvestDate = _unset,
    Object? harvestedDate = _unset,
    Object? dryingEndDate = _unset,
    Object? curingEndDate = _unset,
    Object? archivedAt = _unset,
    Object? archiveReason = _unset,
    Object? wetWeight = _unset,
    Object? dryWeight = _unset,
    bool? burpingRemindersEnabled,
    String? burpingSchedule,
    Object? burpingTime = _unset,
    bool? curingCompleteNotification,
    bool? dryingCheckNotification,
    Object? growStage = _unset,
    bool? isAutoflower,
    Object? flipDate = _unset,
    Object? medium = _unset,
    Object? lightType = _unset,
    Object? phenotypeTag = _unset,
    Object? potSizeLitres = _unset,
    Object? motherPlantId = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    Object? locationLabel = _unset,
    bool? wateringReminderEnabled,
    int? wateringIntervalDays,
    bool? feedingReminderEnabled,
    int? feedingIntervalDays,
    bool? ipmReminderEnabled,
    int? ipmIntervalDays,
    bool? autoAdjustIntervalsByStage,
    List<String>? tags,
  }) {
    return Plant(
      id: id,
      name: name ?? this.name,
      strain: strain ?? this.strain,
      strainId: identical(strainId, _unset) ? this.strainId : strainId as String?,
      startDate: startDate ?? this.startDate,
      targetHarvestDate: identical(targetHarvestDate, _unset)
          ? this.targetHarvestDate
          : targetHarvestDate as DateTime?,
      growSpaceId: growSpaceId ?? this.growSpaceId,
      isClone: isClone ?? this.isClone,
      status: status ?? this.status,
      isArchived: isArchived ?? this.isArchived,
      harvestedDate: identical(harvestedDate, _unset)
          ? this.harvestedDate
          : harvestedDate as DateTime?,
      dryingEndDate: identical(dryingEndDate, _unset)
          ? this.dryingEndDate
          : dryingEndDate as DateTime?,
      curingEndDate: identical(curingEndDate, _unset)
          ? this.curingEndDate
          : curingEndDate as DateTime?,
      wetWeight:
          identical(wetWeight, _unset) ? this.wetWeight : wetWeight as double?,
      dryWeight:
          identical(dryWeight, _unset) ? this.dryWeight : dryWeight as double?,
      archiveReason: identical(archiveReason, _unset)
          ? this.archiveReason
          : archiveReason as String?,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      burpingRemindersEnabled:
          burpingRemindersEnabled ?? this.burpingRemindersEnabled,
      burpingSchedule: burpingSchedule ?? this.burpingSchedule,
      burpingTime: identical(burpingTime, _unset)
          ? this.burpingTime
          : burpingTime as TimeOfDay?,
      curingCompleteNotification:
          curingCompleteNotification ?? this.curingCompleteNotification,
      dryingCheckNotification:
          dryingCheckNotification ?? this.dryingCheckNotification,
      growStage: identical(growStage, _unset)
          ? this.growStage
          : growStage as GrowStage?,
      isAutoflower: isAutoflower ?? this.isAutoflower,
      flipDate:
          identical(flipDate, _unset) ? this.flipDate : flipDate as DateTime?,
      medium:
          identical(medium, _unset) ? this.medium : medium as String?,
      lightType:
          identical(lightType, _unset) ? this.lightType : lightType as String?,
      phenotypeTag: identical(phenotypeTag, _unset)
          ? this.phenotypeTag
          : phenotypeTag as String?,
      potSizeLitres: identical(potSizeLitres, _unset)
          ? this.potSizeLitres
          : potSizeLitres as double?,
      motherPlantId: identical(motherPlantId, _unset)
          ? this.motherPlantId
          : motherPlantId as String?,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _unset)
          ? this.longitude
          : longitude as double?,
      locationLabel: identical(locationLabel, _unset)
          ? this.locationLabel
          : locationLabel as String?,
      wateringReminderEnabled:
          wateringReminderEnabled ?? this.wateringReminderEnabled,
      wateringIntervalDays: wateringIntervalDays ?? this.wateringIntervalDays,
      feedingReminderEnabled:
          feedingReminderEnabled ?? this.feedingReminderEnabled,
      feedingIntervalDays: feedingIntervalDays ?? this.feedingIntervalDays,
      ipmReminderEnabled: ipmReminderEnabled ?? this.ipmReminderEnabled,
      ipmIntervalDays: ipmIntervalDays ?? this.ipmIntervalDays,
      autoAdjustIntervalsByStage:
          autoAdjustIntervalsByStage ?? this.autoAdjustIntervalsByStage,
      tags: tags ?? this.tags,
    );
  }

  // ── F10 — stage-aware effective intervals ─────
  //
  // When [autoAdjustIntervalsByStage] is on, the user-set values are
  // treated as the *veg* baseline.  Flower stretches the cadence
  // because the canopy is denser and the substrate dries slower in
  // flower; flushing typically pulls feeding to zero.
  //
  // Curves (multipliers on the base, rounded to whole days, min 1):
  //
  //   ──────────────  watering  feeding  ipm
  //   Germ/Seedling    ×0.7      ×0      ×0      (no feeds, no spray)
  //   Veg / Stretch    ×1.0      ×1.0    ×1.0
  //   Early flower     ×1.25     ×1.0    ×1.5
  //   Late flower      ×1.5      ×1.0    ×2.0
  //   Flush            ×1.5      ×0      ×0      (no spray on swelling buds)
  //
  // Returns the base value when the toggle is off or the stage is
  // unknown so behaviour stays identical to pre-F10 for existing users.

  int _adjust(int base, double multiplier) {
    if (multiplier <= 0) return 0; // 0 == reminders should be skipped
    final v = (base * multiplier).round();
    return v < 1 ? 1 : v;
  }

  ({double water, double feed, double ipm}) _multipliersForStage(
      GrowStage? stage) {
    if (!autoAdjustIntervalsByStage || stage == null) {
      return (water: 1.0, feed: 1.0, ipm: 1.0);
    }
    switch (stage) {
      case GrowStage.germination:
      case GrowStage.seedling:
        return (water: 0.7, feed: 0.0, ipm: 0.0);
      case GrowStage.vegetative:
      case GrowStage.stretch:
        return (water: 1.0, feed: 1.0, ipm: 1.0);
      case GrowStage.earlyFlower:
        return (water: 1.25, feed: 1.0, ipm: 1.5);
      case GrowStage.lateFlower:
        return (water: 1.5, feed: 1.0, ipm: 2.0);
      case GrowStage.flush:
        return (water: 1.5, feed: 0.0, ipm: 0.0);
    }
  }

  /// Stage-adjusted watering interval (days).  Returns 0 to signal
  /// "skip" — e.g. flushing plants don't need IPM spray reminders.
  int effectiveWateringIntervalDays() =>
      _adjust(wateringIntervalDays, _multipliersForStage(growStage).water);

  int effectiveFeedingIntervalDays() =>
      _adjust(feedingIntervalDays, _multipliersForStage(growStage).feed);

  int effectiveIpmIntervalDays() =>
      _adjust(ipmIntervalDays, _multipliersForStage(growStage).ipm);

  // ── JSON ─────────────────────────────────────

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
        id: json['id'],
        name: json['name'],
        strain: json['strain'] ?? '',
        strainId: json['strainId'],
        startDate: DateTime.parse(json['startDate']),
        targetHarvestDate: json['targetHarvestDate'] != null
            ? DateTime.parse(json['targetHarvestDate'])
            : null,
        growSpaceId: json['growSpaceId'],
        isClone: json['isClone'] ?? false,
        status: PlantStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => PlantStatus.growing,
        ),
        isArchived: json['isArchived'] ?? false,
        harvestedDate: json['harvestedDate'] != null
            ? DateTime.parse(json['harvestedDate'])
            : null,
        dryingEndDate: json['dryingEndDate'] != null
            ? DateTime.parse(json['dryingEndDate'])
            : null,
        curingEndDate: json['curingEndDate'] != null
            ? DateTime.parse(json['curingEndDate'])
            : null,
        wetWeight: (json['wetWeight'] as num?)?.toDouble(),
        dryWeight: (json['dryWeight'] as num?)?.toDouble(),
        archiveReason: json['archiveReason'],
        archivedAt: json['archivedAt'] != null
            ? DateTime.parse(json['archivedAt'])
            : null,
        burpingRemindersEnabled: json['burpingRemindersEnabled'] ?? false,
        burpingSchedule: json['burpingSchedule'] ?? 'week1',
        burpingTime: json['burpingTimeHour'] != null
            ? TimeOfDay(
                hour: json['burpingTimeHour'],
                minute: json['burpingTimeMinute'] ?? 0,
              )
            : null,
        curingCompleteNotification: json['curingCompleteNotification'] ?? false,
        dryingCheckNotification: json['dryingCheckNotification'] ?? false,
        growStage: json['growStage'] != null
            ? GrowStage.values.firstWhere(
                (s) => s.name == json['growStage'],
                orElse: () => GrowStage.germination,
              )
            : null,
        isAutoflower: json['isAutoflower'] ?? false,
        flipDate:
            json['flipDate'] != null ? DateTime.parse(json['flipDate']) : null,
        medium: json['medium'] as String?,
        lightType: json['lightType'] as String?,
        phenotypeTag: json['phenotypeTag'] as String?,
        wateringReminderEnabled: json['wateringReminderEnabled'] ?? false,
        wateringIntervalDays: json['wateringIntervalDays'] ?? 2,
        feedingReminderEnabled: json['feedingReminderEnabled'] ?? false,
        feedingIntervalDays: json['feedingIntervalDays'] ?? 7,
        ipmReminderEnabled: json['ipmReminderEnabled'] ?? false,
        ipmIntervalDays: json['ipmIntervalDays'] ?? 7,
        potSizeLitres: (json['potSizeLitres'] as num?)?.toDouble(),
        motherPlantId: json['motherPlantId'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        locationLabel: json['locationLabel'] as String?,
        autoAdjustIntervalsByStage:
            json['autoAdjustIntervalsByStage'] as bool? ?? false,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'strain': strain,
        'strainId': strainId,
        'startDate': startDate.toIso8601String(),
        'targetHarvestDate': targetHarvestDate?.toIso8601String(),
        'growSpaceId': growSpaceId,
        'isClone': isClone,
        'status': status.name,
        'isArchived': isArchived,
        'harvestedDate': harvestedDate?.toIso8601String(),
        'dryingEndDate': dryingEndDate?.toIso8601String(),
        'curingEndDate': curingEndDate?.toIso8601String(),
        'wetWeight': wetWeight,
        'dryWeight': dryWeight,
        'archiveReason': archiveReason,
        'archivedAt': archivedAt?.toIso8601String(),
        'burpingRemindersEnabled': burpingRemindersEnabled,
        'burpingSchedule': burpingSchedule,
        'burpingTimeHour': burpingTime?.hour,
        'burpingTimeMinute': burpingTime?.minute,
        'curingCompleteNotification': curingCompleteNotification,
        'dryingCheckNotification': dryingCheckNotification,
        'growStage': growStage?.name,
        'isAutoflower': isAutoflower,
        'flipDate': flipDate?.toIso8601String(),
        'medium': medium,
        'lightType': lightType,
        'phenotypeTag': phenotypeTag,
        'wateringReminderEnabled': wateringReminderEnabled,
        'wateringIntervalDays': wateringIntervalDays,
        'feedingReminderEnabled': feedingReminderEnabled,
        'feedingIntervalDays': feedingIntervalDays,
        'ipmReminderEnabled': ipmReminderEnabled,
        'ipmIntervalDays': ipmIntervalDays,
        'potSizeLitres': potSizeLitres,
        'motherPlantId': motherPlantId,
        'latitude': latitude,
        'longitude': longitude,
        'locationLabel': locationLabel,
        'autoAdjustIntervalsByStage': autoAdjustIntervalsByStage,
        'tags': tags,
      };
}
