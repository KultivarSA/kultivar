class GrowSpace {
  final String id;
  final String name;
  final String type;
  final String? notes;

  // ✅ Per-space optimal ranges
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;

  // ✅ Hardware metadata (optional)
  final double? wattage;   // lighting wattage
  final double? areaSqM;   // canopy area in m²

  // ✅ Space-level care-schedule reminders
  // When enabled, all plants in the space share the same care cadence.
  final bool wateringEnabled;
  final int wateringIntervalDays;
  final bool feedingEnabled;
  final int feedingIntervalDays;
  final bool ipmEnabled;
  final int ipmIntervalDays;

  const GrowSpace({
    required this.id,
    required this.name,
    required this.type,
    this.notes,
    this.tempMin = 18,
    this.tempMax = 28,
    this.humidityMin = 40,
    this.humidityMax = 70,
    this.wattage,
    this.areaSqM,
    this.wateringEnabled = false,
    this.wateringIntervalDays = 2,
    this.feedingEnabled = false,
    this.feedingIntervalDays = 7,
    this.ipmEnabled = false,
    this.ipmIntervalDays = 7,
  });

  bool isOptimalTemp(double temp) => temp >= tempMin && temp <= tempMax;

  bool isOptimalHumidity(double humidity) =>
      humidity >= humidityMin && humidity <= humidityMax;

  bool isOptimal(double? temp, double? humidity) {
    if (temp == null || humidity == null) return false;
    return isOptimalTemp(temp) && isOptimalHumidity(humidity);
  }

  /// Returns `null` when either reading is absent (no data), `true` when both
  /// are within per-space thresholds, and `false` when out of range.
  /// Prefer this over [isOptimal] where you want to distinguish "no data" from
  /// "out of range".
  bool? isOptimalAvailable(double? temp, double? humidity) {
    if (temp == null || humidity == null) return null;
    return isOptimalTemp(temp) && isOptimalHumidity(humidity);
  }

  GrowSpace copyWith({
    String? name,
    String? type,
    String? notes,
    double? tempMin,
    double? tempMax,
    double? humidityMin,
    double? humidityMax,
    double? wattage,
    double? areaSqM,
    bool? wateringEnabled,
    int? wateringIntervalDays,
    bool? feedingEnabled,
    int? feedingIntervalDays,
    bool? ipmEnabled,
    int? ipmIntervalDays,
  }) {
    return GrowSpace(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      humidityMin: humidityMin ?? this.humidityMin,
      humidityMax: humidityMax ?? this.humidityMax,
      wattage: wattage ?? this.wattage,
      areaSqM: areaSqM ?? this.areaSqM,
      wateringEnabled: wateringEnabled ?? this.wateringEnabled,
      wateringIntervalDays: wateringIntervalDays ?? this.wateringIntervalDays,
      feedingEnabled: feedingEnabled ?? this.feedingEnabled,
      feedingIntervalDays: feedingIntervalDays ?? this.feedingIntervalDays,
      ipmEnabled: ipmEnabled ?? this.ipmEnabled,
      ipmIntervalDays: ipmIntervalDays ?? this.ipmIntervalDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'notes': notes,
        'tempMin': tempMin,
        'tempMax': tempMax,
        'humidityMin': humidityMin,
        'humidityMax': humidityMax,
        'wattage': wattage,
        'areaSqM': areaSqM,
        'wateringEnabled': wateringEnabled,
        'wateringIntervalDays': wateringIntervalDays,
        'feedingEnabled': feedingEnabled,
        'feedingIntervalDays': feedingIntervalDays,
        'ipmEnabled': ipmEnabled,
        'ipmIntervalDays': ipmIntervalDays,
      };

  factory GrowSpace.fromJson(Map<String, dynamic> json) => GrowSpace(
        id: json['id'],
        name: json['name'],
        type: json['type'],
        notes: json['notes'],
        tempMin: (json['tempMin'] as num?)?.toDouble() ?? 18,
        tempMax: (json['tempMax'] as num?)?.toDouble() ?? 28,
        humidityMin: (json['humidityMin'] as num?)?.toDouble() ?? 40,
        humidityMax: (json['humidityMax'] as num?)?.toDouble() ?? 70,
        wattage: (json['wattage'] as num?)?.toDouble(),
        areaSqM: (json['areaSqM'] as num?)?.toDouble(),
        wateringEnabled: json['wateringEnabled'] ?? false,
        wateringIntervalDays: json['wateringIntervalDays'] ?? 2,
        feedingEnabled: json['feedingEnabled'] ?? false,
        feedingIntervalDays: json['feedingIntervalDays'] ?? 7,
        ipmEnabled: json['ipmEnabled'] ?? false,
        ipmIntervalDays: json['ipmIntervalDays'] ?? 7,
      );
}
