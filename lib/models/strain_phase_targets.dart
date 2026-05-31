/// Per-phase environment targets for a strain.
///
/// All temperatures are stored in **Celsius** (same convention as
/// [GrowSpace] / [EnvironmentLog]).  VPD is in kPa.  RH is in %.
///
/// Values represent the breeder-recommended / scientifically established
/// optimum range for that strain in that growth phase.  The app displays
/// them converted to the user's preferred unit.
class StrainPhaseTargets {
  final double tempDayMin;
  final double tempDayMax;
  final double? tempNightMin; // optional — not all sources publish night temps
  final double? tempNightMax;
  final double rhMin;
  final double rhMax;
  final double vpdMin;
  final double vpdMax;

  const StrainPhaseTargets({
    required this.tempDayMin,
    required this.tempDayMax,
    this.tempNightMin,
    this.tempNightMax,
    required this.rhMin,
    required this.rhMax,
    required this.vpdMin,
    required this.vpdMax,
  });

  // ── Derived helpers ────────────────────────────────────────────────────────

  String get vpdLabel =>
      '${vpdMin.toStringAsFixed(1)}–${vpdMax.toStringAsFixed(1)} kPa';

  String get tempLabel =>
      '${tempDayMin.toStringAsFixed(0)}–${tempDayMax.toStringAsFixed(0)}°C';

  String get rhLabel =>
      '${rhMin.toStringAsFixed(0)}–${rhMax.toStringAsFixed(0)}%';

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'tempDayMin': tempDayMin,
        'tempDayMax': tempDayMax,
        if (tempNightMin != null) 'tempNightMin': tempNightMin,
        if (tempNightMax != null) 'tempNightMax': tempNightMax,
        'rhMin': rhMin,
        'rhMax': rhMax,
        'vpdMin': vpdMin,
        'vpdMax': vpdMax,
      };

  factory StrainPhaseTargets.fromJson(Map<String, dynamic> j) =>
      StrainPhaseTargets(
        tempDayMin:   (j['tempDayMin']   as num).toDouble(),
        tempDayMax:   (j['tempDayMax']   as num).toDouble(),
        tempNightMin: (j['tempNightMin'] as num?)?.toDouble(),
        tempNightMax: (j['tempNightMax'] as num?)?.toDouble(),
        rhMin:        (j['rhMin']        as num).toDouble(),
        rhMax:        (j['rhMax']        as num).toDouble(),
        vpdMin:       (j['vpdMin']       as num).toDouble(),
        vpdMax:       (j['vpdMax']       as num).toDouble(),
      );
}
