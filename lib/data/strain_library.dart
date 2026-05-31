import '../models/strain_phase_targets.dart';

/// Built-in strain catalogue.
///
/// [flowerDays] meaning differs by type:
///   - Photoperiod: approximate days *from flip* to harvest.
///   - Autoflower:  approximate total days *from seed* to harvest.
///
/// Phase targets, feeding profiles and training data are populated for the
/// top ~16 most commonly grown strains.  All other entries carry only the
/// basic grow-timeline data — enough for harvest prediction.
class BuiltInStrain {
  // ── Core (all entries) ─────────────────────────────────────────────────────
  final String name;
  final String type; // 'Indica' | 'Sativa' | 'Hybrid'
  final bool isAutoflower;
  final int flowerDays;

  /// True for pure regional varieties (Afghani, Acapulco Gold, Durban
  /// Poison, Thai sativa, Hindu Kush, etc.) that haven't been crossed
  /// with Western hybrids.  Surfaced as a separate filter chip on the
  /// strain catalog so growers hunting authentic genetics don't have
  /// to scroll the full hybrid-heavy list.
  final bool isLandrace;

  // ── Identity ───────────────────────────────────────────────────────────────
  final String? breeder;
  final String? lineage; // e.g. "OG Kush × Durban Poison"

  // ── Growth timeline ────────────────────────────────────────────────────────
  final int? flowerWeeksMin;
  final int? flowerWeeksMax;
  final double? stretchFactor; // height multiplier during flower flip
  final int? heightCmMin;
  final int? heightCmMax;
  final int? yieldGPerM2Min;
  final int? yieldGPerM2Max;

  // ── Phase environment targets ──────────────────────────────────────────────
  final StrainPhaseTargets? vegTargets;
  final StrainPhaseTargets? earlyFlowerTargets;
  final StrainPhaseTargets? lateFlowerTargets;

  // ── Feeding ────────────────────────────────────────────────────────────────
  final String? feedingIntensity; // 'light' | 'medium' | 'heavy'
  final double? phMin;
  final double? phMax;
  final double? ecVegMin;
  final double? ecVegMax;
  final double? ecFlowerMin;
  final double? ecFlowerMax;

  // ── Training ───────────────────────────────────────────────────────────────
  final List<String> training; // ['lst', 'topping', 'scrog', 'sog', 'mainline', 'lollipopping']

  // ── Output ─────────────────────────────────────────────────────────────────
  final double? thcPctMin;
  final double? thcPctMax;
  final double? cbdPctMin;
  final double? cbdPctMax;
  final List<String> terpenes;
  final int? cureWeeksMin;
  final int? cureWeeksMax;

  const BuiltInStrain({
    required this.name,
    required this.type,
    required this.isAutoflower,
    required this.flowerDays,
    this.isLandrace = false,
    this.breeder,
    this.lineage,
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
    this.training = const [],
    this.thcPctMin,
    this.thcPctMax,
    this.cbdPctMin,
    this.cbdPctMax,
    this.terpenes = const [],
    this.cureWeeksMin,
    this.cureWeeksMax,
  });
}

// ── Phase-target constants shared across similar phenotypes ───────────────────
//
// Defined once here and referenced in multiple strain entries to avoid
// repeating identical numbers throughout the library.

// Standard hybrid veg window
const _hybridVeg = StrainPhaseTargets(
  tempDayMin: 22, tempDayMax: 28,
  tempNightMin: 18, tempNightMax: 22,
  rhMin: 55, rhMax: 70,
  vpdMin: 0.8, vpdMax: 1.2,
);

// Standard hybrid early-flower window
const _hybridEarlyFlower = StrainPhaseTargets(
  tempDayMin: 20, tempDayMax: 26,
  tempNightMin: 16, tempNightMax: 20,
  rhMin: 45, rhMax: 55,
  vpdMin: 1.0, vpdMax: 1.5,
);

// Standard hybrid late-flower window
const _hybridLateFlower = StrainPhaseTargets(
  tempDayMin: 18, tempDayMax: 24,
  tempNightMin: 14, tempNightMax: 18,
  rhMin: 35, rhMax: 45,
  vpdMin: 1.2, vpdMax: 1.6,
);

// Dense-Indica late-flower (lower RH — bud-rot prevention)
const _indicaLateFlower = StrainPhaseTargets(
  tempDayMin: 16, tempDayMax: 22,
  tempNightMin: 12, tempNightMax: 16,
  rhMin: 30, rhMax: 40,
  vpdMin: 1.2, vpdMax: 1.6,
);

// Indica veg (slightly cooler, tighter RH)
const _indicaVeg = StrainPhaseTargets(
  tempDayMin: 20, tempDayMax: 26,
  tempNightMin: 16, tempNightMax: 20,
  rhMin: 50, rhMax: 65,
  vpdMin: 0.8, vpdMax: 1.1,
);

// Indica early-flower
const _indicaEarlyFlower = StrainPhaseTargets(
  tempDayMin: 18, tempDayMax: 24,
  tempNightMin: 14, tempNightMax: 18,
  rhMin: 40, rhMax: 50,
  vpdMin: 1.0, vpdMax: 1.4,
);

// Sativa veg (heat-tolerant)
const _sativaVeg = StrainPhaseTargets(
  tempDayMin: 22, tempDayMax: 30,
  tempNightMin: 18, tempNightMax: 24,
  rhMin: 55, rhMax: 70,
  vpdMin: 0.8, vpdMax: 1.2,
);

// Sativa early-flower (warmer than Indicas)
const _sativaEarlyFlower = StrainPhaseTargets(
  tempDayMin: 20, tempDayMax: 28,
  tempNightMin: 16, tempNightMax: 22,
  rhMin: 45, rhMax: 55,
  vpdMin: 1.0, vpdMax: 1.5,
);

// Sativa late-flower
const _sativaLateFlower = StrainPhaseTargets(
  tempDayMin: 18, tempDayMax: 26,
  tempNightMin: 14, tempNightMax: 20,
  rhMin: 38, rhMax: 48,
  vpdMin: 1.2, vpdMax: 1.6,
);

// Autoflower — more forgiving across all phases
const _autoVeg = StrainPhaseTargets(
  tempDayMin: 20, tempDayMax: 28,
  tempNightMin: 16, tempNightMax: 22,
  rhMin: 50, rhMax: 70,
  vpdMin: 0.8, vpdMax: 1.2,
);

const _autoEarlyFlower = StrainPhaseTargets(
  tempDayMin: 18, tempDayMax: 26,
  tempNightMin: 14, tempNightMax: 20,
  rhMin: 40, rhMax: 55,
  vpdMin: 1.0, vpdMax: 1.5,
);

const _autoLateFlower = StrainPhaseTargets(
  tempDayMin: 18, tempDayMax: 24,
  tempNightMin: 14, tempNightMax: 18,
  rhMin: 35, rhMax: 45,
  vpdMin: 1.2, vpdMax: 1.6,
);

// ─────────────────────────────────────────────────────────────────────────────

const List<BuiltInStrain> kStrainLibrary = [

  // ── INDICA photoperiod ──────────────────────────────────────────────────────

  BuiltInStrain(
    name: 'Northern Lights',   type: 'Indica', isAutoflower: false, flowerDays: 56,
    breeder: 'Sensi Seeds', lineage: 'Afghan × Thai',
    flowerWeeksMin: 7, flowerWeeksMax: 8, stretchFactor: 1.3,
    heightCmMin: 50, heightCmMax: 80,
    yieldGPerM2Min: 450, yieldGPerM2Max: 550,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['sog', 'lst'],
    thcPctMin: 16, thcPctMax: 21, cbdPctMin: 0.0, cbdPctMax: 0.2,
    terpenes: ['myrcene', 'pinene', 'caryophyllene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Granddaddy Purple',  type: 'Indica', isAutoflower: false, flowerDays: 63,
    breeder: 'Ken Estes', lineage: 'Big Bud × Purple Urkle',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.4,
    heightCmMin: 60, heightCmMax: 120,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'lollipopping'],
    thcPctMin: 17, thcPctMax: 23, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['myrcene', 'caryophyllene', 'linalool'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'OG Kush',            type: 'Indica', isAutoflower: false, flowerDays: 63,
    breeder: 'Unknown / Matt Berger', lineage: 'Chemdawg × (Hindu Kush × Lemon Thai)',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.5,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'heavy', phMin: 6.0, phMax: 6.8,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.8, ecFlowerMax: 2.4,
    training: ['lst', 'lollipopping'],
    thcPctMin: 19, thcPctMax: 26, cbdPctMin: 0.0, cbdPctMax: 0.3,
    terpenes: ['limonene', 'myrcene', 'caryophyllene'],
    cureWeeksMin: 4, cureWeeksMax: 8,
  ),

  BuiltInStrain(
    name: 'Bubba Kush',            type: 'Indica', isAutoflower: false, flowerDays: 60,
    lineage: 'OG Kush × unknown Indica',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.2,
    heightCmMin: 50, heightCmMax: 90,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['sog', 'lst', 'lollipopping'],
    thcPctMin: 17, thcPctMax: 22, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['myrcene', 'caryophyllene', 'limonene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Purple Kush',           type: 'Indica', isAutoflower: false, flowerDays: 56,
    lineage: 'Hindu Kush × Purple Afghani',
    flowerWeeksMin: 7, flowerWeeksMax: 8, stretchFactor: 1.2,
    heightCmMin: 50, heightCmMax: 90,
    yieldGPerM2Min: 300, yieldGPerM2Max: 400,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.4, ecFlowerMin: 1.2, ecFlowerMax: 1.8,
    training: ['sog', 'lst'],
    thcPctMin: 17, thcPctMax: 22, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['myrcene', 'pinene', 'linalool'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),
  BuiltInStrain(name: 'Blueberry',             type: 'Indica', isAutoflower: false, flowerDays: 60,
    breeder: 'DJ Short', lineage: 'Afghan × Thai × Purple Thai',
    thcPctMin: 15, thcPctMax: 20, terpenes: ['myrcene', 'pinene', 'ocimene']),
  BuiltInStrain(name: 'Hindu Kush',            type: 'Indica', isAutoflower: false, flowerDays: 50,
    isLandrace: true,
    lineage: 'Hindu Kush landrace',
    thcPctMin: 15, thcPctMax: 20, terpenes: ['myrcene', 'pinene']),
  BuiltInStrain(name: 'Master Kush',           type: 'Indica', isAutoflower: false, flowerDays: 60,
    breeder: 'Dutch Passion', lineage: 'Hindu Kush × Skunk',
    thcPctMin: 16, thcPctMax: 20, terpenes: ['myrcene', 'caryophyllene']),
  BuiltInStrain(name: 'Afghan Kush',           type: 'Indica', isAutoflower: false, flowerDays: 56,
    isLandrace: true,
    lineage: 'Afghani landrace',
    thcPctMin: 15, thcPctMax: 20, terpenes: ['myrcene', 'pinene']),
  BuiltInStrain(name: 'Critical',              type: 'Indica', isAutoflower: false, flowerDays: 47,
    breeder: 'Dinafem', lineage: 'Skunk #1 × Afghan',
    thcPctMin: 16, thcPctMax: 22, terpenes: ['myrcene', 'caryophyllene']),
  BuiltInStrain(name: 'Critical Mass',         type: 'Indica', isAutoflower: false, flowerDays: 50,
    breeder: 'Mr. Nice Seeds', lineage: 'Afghani × Skunk #1',
    thcPctMin: 16, thcPctMax: 22, terpenes: ['myrcene', 'caryophyllene']),
  BuiltInStrain(name: 'Blackberry Kush',       type: 'Indica', isAutoflower: false, flowerDays: 56,
    lineage: 'Afghani × Blackberry',
    thcPctMin: 16, thcPctMax: 20, terpenes: ['myrcene', 'caryophyllene']),
  BuiltInStrain(name: 'G13',                   type: 'Indica', isAutoflower: false, flowerDays: 60),
  BuiltInStrain(name: 'Platinum OG',           type: 'Indica', isAutoflower: false, flowerDays: 63,
    lineage: 'OG Kush × Master Kush',
    thcPctMin: 17, thcPctMax: 24, terpenes: ['limonene', 'myrcene']),
  BuiltInStrain(name: 'Death Star',            type: 'Indica', isAutoflower: false, flowerDays: 60,
    lineage: 'Sensi Star × Sour Diesel'),
  BuiltInStrain(name: 'Romulan',               type: 'Indica', isAutoflower: false, flowerDays: 60),
  BuiltInStrain(name: 'Pre-98 Bubba Kush',     type: 'Indica', isAutoflower: false, flowerDays: 60),

  // ── SATIVA photoperiod ──────────────────────────────────────────────────────

  BuiltInStrain(
    name: 'Jack Herer',         type: 'Sativa', isAutoflower: false, flowerDays: 63,
    breeder: 'Sensi Seeds', lineage: 'Haze × (Northern Lights #5 × Shiva Skunk)',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 2.0,
    heightCmMin: 100, heightCmMax: 180,
    yieldGPerM2Min: 450, yieldGPerM2Max: 550,
    vegTargets: _sativaVeg, earlyFlowerTargets: _sativaEarlyFlower, lateFlowerTargets: _sativaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['scrog', 'lst'],
    thcPctMin: 18, thcPctMax: 24, cbdPctMin: 0.1, cbdPctMax: 0.3,
    terpenes: ['terpinolene', 'ocimene', 'myrcene'],
    cureWeeksMin: 3, cureWeeksMax: 5,
  ),

  BuiltInStrain(
    name: 'Sour Diesel',        type: 'Sativa', isAutoflower: false, flowerDays: 70,
    lineage: 'Chemdawg 91 × Super Skunk',
    flowerWeeksMin: 10, flowerWeeksMax: 11, stretchFactor: 2.2,
    heightCmMin: 120, heightCmMax: 200,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _sativaVeg, earlyFlowerTargets: _sativaEarlyFlower, lateFlowerTargets: _sativaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['scrog', 'lst', 'topping'],
    thcPctMin: 20, thcPctMax: 26, cbdPctMin: 0.0, cbdPctMax: 0.2,
    terpenes: ['caryophyllene', 'myrcene', 'limonene'],
    cureWeeksMin: 3, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Amnesia Haze',       type: 'Sativa', isAutoflower: false, flowerDays: 70,
    breeder: 'Soma Seeds / Hy-Pro', lineage: 'Haze × Afghan × Hawaiian',
    flowerWeeksMin: 10, flowerWeeksMax: 11, stretchFactor: 2.5,
    heightCmMin: 150, heightCmMax: 210,
    yieldGPerM2Min: 500, yieldGPerM2Max: 700,
    vegTargets: _sativaVeg, earlyFlowerTargets: _sativaEarlyFlower, lateFlowerTargets: _sativaLateFlower,
    feedingIntensity: 'heavy', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.8, ecFlowerMax: 2.4,
    training: ['scrog', 'lst'],
    thcPctMin: 20, thcPctMax: 25, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['terpinolene', 'myrcene', 'ocimene'],
    cureWeeksMin: 4, cureWeeksMax: 8,
  ),

  BuiltInStrain(
    name: 'Strawberry Cough',     type: 'Sativa', isAutoflower: false, flowerDays: 63,
    breeder: 'Kyle Kushman', lineage: 'Strawberry Fields × Haze',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 2.0,
    heightCmMin: 100, heightCmMax: 160,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _sativaVeg, earlyFlowerTargets: _sativaEarlyFlower, lateFlowerTargets: _sativaLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['scrog', 'lst', 'topping'],
    thcPctMin: 15, thcPctMax: 20, cbdPctMin: 0.1, cbdPctMax: 0.3,
    terpenes: ['terpinolene', 'myrcene', 'ocimene'],
    cureWeeksMin: 3, cureWeeksMax: 5,
  ),

  BuiltInStrain(
    name: 'Tangie',               type: 'Sativa', isAutoflower: false, flowerDays: 63,
    breeder: 'DNA Genetics', lineage: 'California Orange × Skunk #1',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 2.2,
    heightCmMin: 100, heightCmMax: 180,
    yieldGPerM2Min: 450, yieldGPerM2Max: 600,
    vegTargets: _sativaVeg, earlyFlowerTargets: _sativaEarlyFlower, lateFlowerTargets: _sativaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['scrog', 'lst'],
    thcPctMin: 19, thcPctMax: 22, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['terpinolene', 'myrcene', 'ocimene'],
    cureWeeksMin: 3, cureWeeksMax: 5,
  ),

  BuiltInStrain(
    name: 'Harlequin',            type: 'Sativa', isAutoflower: false, flowerDays: 60,
    lineage: 'Colombian Gold × Nepal × Thai × Swiss',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.8,
    heightCmMin: 80, heightCmMax: 150,
    yieldGPerM2Min: 350, yieldGPerM2Max: 500,
    vegTargets: _sativaVeg, earlyFlowerTargets: _sativaEarlyFlower, lateFlowerTargets: _sativaLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 0.8, ecVegMax: 1.4, ecFlowerMin: 1.2, ecFlowerMax: 1.8,
    training: ['lst', 'scrog'],
    thcPctMin: 5, thcPctMax: 10, cbdPctMin: 8, cbdPctMax: 16,
    terpenes: ['myrcene', 'pinene', 'caryophyllene'],
    cureWeeksMin: 3, cureWeeksMax: 4,
  ),

  BuiltInStrain(name: 'Durban Poison',         type: 'Sativa', isAutoflower: false, flowerDays: 70,
    isLandrace: true,
    lineage: 'South African landrace',
    thcPctMin: 16, thcPctMax: 20, terpenes: ['terpinolene', 'myrcene', 'ocimene']),
  BuiltInStrain(name: 'Green Crack',           type: 'Sativa', isAutoflower: false, flowerDays: 63,
    lineage: 'Skunk #1 × Afghani',
    thcPctMin: 16, thcPctMax: 21, terpenes: ['myrcene', 'caryophyllene', 'ocimene']),
  BuiltInStrain(name: 'Super Silver Haze',     type: 'Sativa', isAutoflower: false, flowerDays: 70,
    breeder: 'Green House Seeds', lineage: 'Skunk × Northern Lights × Haze',
    thcPctMin: 18, thcPctMax: 23, terpenes: ['terpinolene', 'myrcene']),
  BuiltInStrain(name: 'Super Lemon Haze',      type: 'Sativa', isAutoflower: false, flowerDays: 70,
    breeder: 'Green House Seeds', lineage: 'Lemon Skunk × Super Silver Haze',
    thcPctMin: 18, thcPctMax: 22, terpenes: ['terpinolene', 'ocimene', 'myrcene']),
  BuiltInStrain(name: 'Silver Haze',           type: 'Sativa', isAutoflower: false, flowerDays: 77,
    lineage: 'Northern Lights × Haze',
    thcPctMin: 16, thcPctMax: 21, terpenes: ['terpinolene', 'myrcene']),
  BuiltInStrain(name: 'Maui Wowie',            type: 'Sativa', isAutoflower: false, flowerDays: 70,
    lineage: 'Hawaiian landrace',
    thcPctMin: 14, thcPctMax: 20, terpenes: ['myrcene', 'pinene', 'terpinolene']),
  BuiltInStrain(name: 'Trainwreck',            type: 'Sativa', isAutoflower: false, flowerDays: 63,
    lineage: 'Mexican × Thai × Afghani',
    thcPctMin: 18, thcPctMax: 25, terpenes: ['terpinolene', 'ocimene', 'myrcene']),
  BuiltInStrain(name: 'Chocolope',             type: 'Sativa', isAutoflower: false, flowerDays: 70,
    breeder: 'DNA Genetics', lineage: 'Chocolate Thai × Cannalope Haze'),
  BuiltInStrain(name: 'Moby Dick',             type: 'Sativa', isAutoflower: false, flowerDays: 70,
    breeder: 'Dinafem', lineage: 'White Widow × Haze'),
  BuiltInStrain(name: 'Cinderella 99',         type: 'Sativa', isAutoflower: false, flowerDays: 56,
    lineage: 'Jack Herer × (Princess × P75)'),
  BuiltInStrain(name: 'Acapulco Gold',         type: 'Sativa', isAutoflower: false, flowerDays: 77,
    isLandrace: true,
    lineage: 'Mexican landrace'),

  // ── HYBRID photoperiod ──────────────────────────────────────────────────────

  BuiltInStrain(
    name: 'White Widow',        type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    breeder: 'Green House Seeds', lineage: 'Brazilian Sativa × South Indian Indica',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.7,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'topping', 'fim'],
    thcPctMin: 18, thcPctMax: 25, cbdPctMin: 0.1, cbdPctMax: 0.3,
    terpenes: ['myrcene', 'caryophyllene', 'pinene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Gorilla Glue #4',    type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    breeder: 'GG Strains', lineage: "Chem's Sister × Chocolate Diesel × Sour Dubb",
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 2.0,
    heightCmMin: 100, heightCmMax: 200,
    yieldGPerM2Min: 500, yieldGPerM2Max: 600,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'heavy', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.8, ecFlowerMax: 2.6,
    training: ['scrog', 'lst'],
    thcPctMin: 27, thcPctMax: 32, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'myrcene', 'limonene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Blue Dream',         type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'DJ Short / Santa Cruz', lineage: 'Blueberry × Haze',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.8,
    heightCmMin: 100, heightCmMax: 180,
    yieldGPerM2Min: 400, yieldGPerM2Max: 600,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'scrog', 'topping'],
    thcPctMin: 17, thcPctMax: 24, cbdPctMin: 0.1, cbdPctMax: 0.2,
    terpenes: ['myrcene', 'caryophyllene', 'pinene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Girl Scout Cookies', type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Cookie Fam / FTP Genetics', lineage: 'OG Kush × Durban Poison',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.6,
    heightCmMin: 60, heightCmMax: 120,
    yieldGPerM2Min: 300, yieldGPerM2Max: 400,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'mainline'],
    thcPctMin: 25, thcPctMax: 28, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Wedding Cake',       type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Seed Junky Genetics', lineage: 'Triangle Kush × Animal Mints',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.4,
    heightCmMin: 60, heightCmMax: 120,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'heavy', phMin: 6.0, phMax: 6.8,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.8, ecFlowerMax: 2.4,
    training: ['lst', 'lollipopping'],
    thcPctMin: 25, thcPctMax: 27, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Gelato',             type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    breeder: 'Cookie Fam / Sherbinski', lineage: 'Sunset Sherbet × Thin Mint GSC',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.4,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'lollipopping'],
    thcPctMin: 20, thcPctMax: 25, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Runtz',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Cookies', lineage: 'Zkittlez × Gelato',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.5,
    heightCmMin: 60, heightCmMax: 120,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'topping'],
    thcPctMin: 19, thcPctMax: 29, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['limonene', 'caryophyllene', 'linalool'],
    cureWeeksMin: 3, cureWeeksMax: 5,
  ),

  BuiltInStrain(
    name: 'AK-47',              type: 'Hybrid', isAutoflower: false, flowerDays: 56,
    breeder: 'Serious Seeds', lineage: 'Colombian × Mexican × Thai × Afghan',
    flowerWeeksMin: 7, flowerWeeksMax: 9, stretchFactor: 1.8,
    heightCmMin: 80, heightCmMax: 150,
    yieldGPerM2Min: 350, yieldGPerM2Max: 500,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'topping'],
    thcPctMin: 17, thcPctMax: 20, cbdPctMin: 0.2, cbdPctMax: 0.3,
    terpenes: ['myrcene', 'caryophyllene', 'ocimene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Zkittlez',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: '3rd Coast Genetics', lineage: 'Grape Ape × Grapefruit',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.3,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['lst', 'lollipopping'],
    thcPctMin: 17, thcPctMax: 23, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['limonene', 'myrcene', 'caryophyllene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Mimosa',                type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Symbiotic Genetics', lineage: 'Purple Punch × Clementine',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.8,
    heightCmMin: 80, heightCmMax: 150,
    yieldGPerM2Min: 400, yieldGPerM2Max: 550,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'scrog'],
    thcPctMin: 19, thcPctMax: 27, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['limonene', 'caryophyllene', 'myrcene'],
    cureWeeksMin: 3, cureWeeksMax: 5,
  ),

  BuiltInStrain(
    name: 'Purple Punch',          type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    lineage: 'Larry OG × Granddaddy Purple',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.3,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['lst', 'lollipopping'],
    thcPctMin: 18, thcPctMax: 25, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['myrcene', 'caryophyllene', 'linalool'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Do-Si-Dos',             type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Archive Seeds', lineage: 'Girl Scout Cookies × Face Off OG',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.4,
    heightCmMin: 60, heightCmMax: 110,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'mainline'],
    thcPctMin: 19, thcPctMax: 28, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['limonene', 'caryophyllene', 'linalool'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Jealousy',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Seed Junky Genetics', lineage: 'Sherbert Bx1 × Gelato 41',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.4,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 400, yieldGPerM2Max: 500,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'heavy', phMin: 6.0, phMax: 6.8,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.8, ecFlowerMax: 2.4,
    training: ['lst', 'lollipopping'],
    thcPctMin: 29, thcPctMax: 33, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'GMO Cookies',           type: 'Hybrid', isAutoflower: false, flowerDays: 67,
    lineage: 'Girl Scout Cookies × Chemdawg',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.4,
    heightCmMin: 60, heightCmMax: 110,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'heavy', phMin: 6.0, phMax: 6.8,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.8, ecFlowerMax: 2.4,
    training: ['lst', 'lollipopping'],
    thcPctMin: 20, thcPctMax: 30, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'myrcene', 'limonene'],
    cureWeeksMin: 4, cureWeeksMax: 8,
  ),

  BuiltInStrain(
    name: 'Ice Cream Cake',        type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Seed Junky Genetics', lineage: 'Wedding Cake × Gelato #33',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.3,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'lollipopping'],
    thcPctMin: 20, thcPctMax: 25, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(name: 'Cherry Pie',            type: 'Hybrid', isAutoflower: false, flowerDays: 58,
    lineage: 'Granddaddy Purple × Durban Poison',
    thcPctMin: 16, thcPctMax: 23, terpenes: ['myrcene', 'caryophyllene', 'pinene']),
  BuiltInStrain(name: 'Pineapple Express',     type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    lineage: 'Trainwreck × Hawaiian',
    thcPctMin: 17, thcPctMax: 25, terpenes: ['myrcene', 'caryophyllene', 'pinene']),
  BuiltInStrain(name: 'Sunset Sherbet',        type: 'Hybrid', isAutoflower: false, flowerDays: 56,
    lineage: 'Girl Scout Cookies × Pink Panties',
    thcPctMin: 19, thcPctMax: 24, terpenes: ['caryophyllene', 'limonene', 'myrcene']),
  BuiltInStrain(name: 'Lemon Cherry Gelato',   type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Sunset Sherbet × Girl Scout Cookies',
    thcPctMin: 25, thcPctMax: 35, terpenes: ['limonene', 'caryophyllene', 'myrcene']),
  BuiltInStrain(name: 'Banana Kush',           type: 'Hybrid', isAutoflower: false, flowerDays: 56,
    lineage: 'Ghost OG × Skunk Haze',
    thcPctMin: 18, thcPctMax: 27, terpenes: ['myrcene', 'caryophyllene', 'limonene']),
  BuiltInStrain(name: 'Blue Cheese',           type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    breeder: 'Big Buddha Seeds', lineage: 'Blueberry × UK Cheese',
    thcPctMin: 15, thcPctMax: 20, terpenes: ['myrcene', 'caryophyllene']),
  BuiltInStrain(name: 'Tropicana Cookies',     type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    lineage: 'GSC × Tangie',
    thcPctMin: 19, thcPctMax: 25, terpenes: ['limonene', 'caryophyllene', 'myrcene']),
  BuiltInStrain(name: 'Cereal Milk',           type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Cookies', lineage: 'Y Life × Snowman',
    thcPctMin: 18, thcPctMax: 23, terpenes: ['caryophyllene', 'limonene', 'myrcene']),
  BuiltInStrain(name: 'Biscotti',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Gelato 25 × South Florida OG × GSC',
    thcPctMin: 21, thcPctMax: 26, terpenes: ['caryophyllene', 'limonene', 'myrcene']),
  BuiltInStrain(name: 'Gary Payton',           type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Cookies × Powerzzzup Genetics', lineage: 'The Y × Snowman',
    thcPctMin: 20, thcPctMax: 25, terpenes: ['limonene', 'caryophyllene', 'myrcene']),
  BuiltInStrain(
    name: 'MAC 1',                 type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Capulator', lineage: 'Alien Cookies × (Colombian × Starfighter)',
    flowerWeeksMin: 9, flowerWeeksMax: 10, stretchFactor: 1.5,
    heightCmMin: 70, heightCmMax: 120,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'topping'],
    thcPctMin: 23, thcPctMax: 30, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Apple Fritter',         type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: "Lumpy's Flowers", lineage: 'Sour Apple × Animal Cookies',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.6,
    heightCmMin: 80, heightCmMax: 140,
    yieldGPerM2Min: 400, yieldGPerM2Max: 550,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'heavy', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.4, ecVegMax: 2.0, ecFlowerMin: 1.8, ecFlowerMax: 2.4,
    training: ['scrog', 'lst', 'topping'],
    thcPctMin: 28, thcPctMax: 32, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),

  BuiltInStrain(
    name: 'Tropicana Cookies',     type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    lineage: 'GSC × Tangie',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.8,
    heightCmMin: 80, heightCmMax: 150,
    yieldGPerM2Min: 400, yieldGPerM2Max: 550,
    vegTargets: _hybridVeg, earlyFlowerTargets: _hybridEarlyFlower, lateFlowerTargets: _hybridLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['scrog', 'lst'],
    thcPctMin: 19, thcPctMax: 25, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['limonene', 'caryophyllene', 'myrcene'],
    cureWeeksMin: 3, cureWeeksMax: 5,
  ),

  BuiltInStrain(
    name: 'Peanut Butter Breath',  type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    breeder: 'ThugPug Genetics', lineage: 'Do-Si-Dos × Mendo Breath',
    flowerWeeksMin: 8, flowerWeeksMax: 9, stretchFactor: 1.3,
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 350, yieldGPerM2Max: 450,
    vegTargets: _indicaVeg, earlyFlowerTargets: _indicaEarlyFlower, lateFlowerTargets: _indicaLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.2, ecVegMax: 1.8, ecFlowerMin: 1.6, ecFlowerMax: 2.2,
    training: ['lst', 'lollipopping'],
    thcPctMin: 18, thcPctMax: 28, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 4, cureWeeksMax: 6,
  ),
  BuiltInStrain(name: 'Gushers',               type: 'Hybrid', isAutoflower: false, flowerDays: 56,
    breeder: 'Cookies', lineage: 'Gelato #41 × Triangle Kush',
    thcPctMin: 15, thcPctMax: 22, terpenes: ['caryophyllene', 'limonene', 'myrcene']),
  BuiltInStrain(name: 'White Runtz',           type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Zkittlez × Gelato',
    thcPctMin: 23, thcPctMax: 25, terpenes: ['limonene', 'caryophyllene', 'myrcene']),
  BuiltInStrain(name: 'Pink Runtz',            type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Zkittlez × Gelato',
    thcPctMin: 23, thcPctMax: 25, terpenes: ['limonene', 'caryophyllene', 'myrcene']),
  BuiltInStrain(name: 'Bruce Banner',          type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'OG Kush × Strawberry Diesel',
    thcPctMin: 20, thcPctMax: 29, terpenes: ['caryophyllene', 'myrcene', 'limonene']),
  BuiltInStrain(name: 'Chemdawg',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Unknown (Nepalese × Thai)',
    thcPctMin: 15, thcPctMax: 20, terpenes: ['caryophyllene', 'myrcene', 'limonene']),
  BuiltInStrain(name: 'Headband',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'OG Kush × Sour Diesel',
    thcPctMin: 20, thcPctMax: 27, terpenes: ['myrcene', 'limonene', 'caryophyllene']),
  BuiltInStrain(name: 'Strawberry Banana',     type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'DNA Genetics × Serious Seeds', lineage: 'Crockett\'s Banana Kush × Bubblegum',
    thcPctMin: 22, thcPctMax: 26, terpenes: ['myrcene', 'caryophyllene', 'limonene']),
  BuiltInStrain(name: 'Gorilla Zkittlez',      type: 'Hybrid', isAutoflower: false, flowerDays: 60),
  BuiltInStrain(name: 'Permanent Marker',      type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Biscotti × Jealousy × Sherb Bx',
    thcPctMin: 30, thcPctMax: 35, terpenes: ['caryophyllene', 'limonene', 'myrcene']),
  BuiltInStrain(name: 'Grease Monkey',         type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Exotic Genetix', lineage: 'Gorilla Glue #4 × Cookies & Cream'),
  BuiltInStrain(name: 'London Pound Cake',     type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Sunset Sherbet × Unknown Heavy Indica',
    thcPctMin: 25, thcPctMax: 29, terpenes: ['myrcene', 'caryophyllene', 'limonene']),
  BuiltInStrain(name: 'Rainbow Belts',         type: 'Hybrid', isAutoflower: false, flowerDays: 60,
    lineage: 'Zkittlez × Do-Si-Dos'),
  BuiltInStrain(name: 'Watermelon Zkittlez',   type: 'Hybrid', isAutoflower: false, flowerDays: 63),
  BuiltInStrain(name: 'Purple Gelato',         type: 'Hybrid', isAutoflower: false, flowerDays: 63),

  // ── AUTOFLOWER ─────────────────────────────────────────────────────────────

  BuiltInStrain(
    name: 'Gorilla Glue Auto',  type: 'Hybrid', isAutoflower: true, flowerDays: 77,
    lineage: "Chem's Sister × Chocolate Diesel (Auto)",
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 300, yieldGPerM2Max: 450,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['lst'],
    thcPctMin: 20, thcPctMax: 26, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'myrcene', 'limonene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Wedding Cake Auto',  type: 'Hybrid', isAutoflower: true, flowerDays: 77,
    lineage: 'Triangle Kush × Animal Mints (Auto)',
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 350, yieldGPerM2Max: 500,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['lst'],
    thcPctMin: 20, thcPctMax: 25, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['caryophyllene', 'limonene', 'myrcene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Zkittlez Auto',      type: 'Hybrid', isAutoflower: true, flowerDays: 77,
    breeder: '3rd Coast Genetics', lineage: 'Grape Ape × Grapefruit (Auto)',
    heightCmMin: 50, heightCmMax: 90,
    yieldGPerM2Min: 300, yieldGPerM2Max: 400,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 0.8, ecVegMax: 1.4, ecFlowerMin: 1.2, ecFlowerMax: 1.8,
    training: ['lst'],
    thcPctMin: 15, thcPctMax: 20, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['limonene', 'myrcene', 'caryophyllene'],
    cureWeeksMin: 2, cureWeeksMax: 3,
  ),

  BuiltInStrain(
    name: 'Critical Auto',      type: 'Indica', isAutoflower: true, flowerDays: 70,
    breeder: 'Dinafem', lineage: 'Critical × Ruderalis',
    heightCmMin: 50, heightCmMax: 80,
    yieldGPerM2Min: 400, yieldGPerM2Max: 550,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 0.8, ecVegMax: 1.4, ecFlowerMin: 1.2, ecFlowerMax: 1.8,
    training: ['lst'],
    thcPctMin: 14, thcPctMax: 19, cbdPctMin: 0.0, cbdPctMax: 0.2,
    terpenes: ['myrcene', 'caryophyllene'],
    cureWeeksMin: 2, cureWeeksMax: 3,
  ),

  BuiltInStrain(
    name: 'Auto Blueberry',        type: 'Indica', isAutoflower: true, flowerDays: 70,
    breeder: 'Dutch Passion', lineage: 'Blueberry × Ruderalis',
    heightCmMin: 50, heightCmMax: 80,
    yieldGPerM2Min: 300, yieldGPerM2Max: 400,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 0.8, ecVegMax: 1.4, ecFlowerMin: 1.2, ecFlowerMax: 1.8,
    training: ['lst'],
    thcPctMin: 14, thcPctMax: 20, cbdPctMin: 0.0, cbdPctMax: 0.1,
    terpenes: ['myrcene', 'pinene', 'ocimene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Auto Northern Lights',  type: 'Indica', isAutoflower: true, flowerDays: 70,
    lineage: 'Northern Lights × Ruderalis',
    heightCmMin: 50, heightCmMax: 85,
    yieldGPerM2Min: 350, yieldGPerM2Max: 500,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'light', phMin: 6.0, phMax: 7.0,
    ecVegMin: 0.8, ecVegMax: 1.4, ecFlowerMin: 1.2, ecFlowerMax: 1.8,
    training: ['lst'],
    thcPctMin: 14, thcPctMax: 19, cbdPctMin: 0.0, cbdPctMax: 0.2,
    terpenes: ['myrcene', 'pinene', 'caryophyllene'],
    cureWeeksMin: 2, cureWeeksMax: 3,
  ),

  BuiltInStrain(
    name: 'Auto White Widow',      type: 'Hybrid', isAutoflower: true, flowerDays: 75,
    lineage: 'White Widow × Ruderalis',
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 300, yieldGPerM2Max: 450,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['lst'],
    thcPctMin: 15, thcPctMax: 20, cbdPctMin: 0.1, cbdPctMax: 0.2,
    terpenes: ['myrcene', 'caryophyllene', 'pinene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),

  BuiltInStrain(
    name: 'Auto AK-47',            type: 'Hybrid', isAutoflower: true, flowerDays: 70,
    lineage: 'AK-47 × Ruderalis',
    heightCmMin: 60, heightCmMax: 100,
    yieldGPerM2Min: 300, yieldGPerM2Max: 450,
    vegTargets: _autoVeg, earlyFlowerTargets: _autoEarlyFlower, lateFlowerTargets: _autoLateFlower,
    feedingIntensity: 'medium', phMin: 6.0, phMax: 7.0,
    ecVegMin: 1.0, ecVegMax: 1.6, ecFlowerMin: 1.4, ecFlowerMax: 2.0,
    training: ['lst'],
    thcPctMin: 16, thcPctMax: 20, cbdPctMin: 0.1, cbdPctMax: 0.3,
    terpenes: ['myrcene', 'caryophyllene', 'ocimene'],
    cureWeeksMin: 2, cureWeeksMax: 4,
  ),
  BuiltInStrain(name: 'Amnesia Haze Auto',     type: 'Sativa', isAutoflower: true,  flowerDays: 77,
    lineage: 'Amnesia Haze × Ruderalis'),
  BuiltInStrain(name: 'Bruce Banner Auto',     type: 'Hybrid', isAutoflower: true,  flowerDays: 77,
    lineage: 'OG Kush × Strawberry Diesel (Auto)'),
  BuiltInStrain(name: 'Girl Scout Cookies Auto', type: 'Hybrid', isAutoflower: true, flowerDays: 75,
    lineage: 'GSC × Ruderalis'),
  BuiltInStrain(name: 'Gelato Auto',           type: 'Hybrid', isAutoflower: true,  flowerDays: 75,
    lineage: 'Gelato × Ruderalis'),
  BuiltInStrain(name: 'Runtz Auto',            type: 'Hybrid', isAutoflower: true,  flowerDays: 77,
    lineage: 'Runtz × Ruderalis'),
  BuiltInStrain(name: 'Purple Punch Auto',     type: 'Indica', isAutoflower: true,  flowerDays: 75,
    lineage: 'Purple Punch × Ruderalis'),
  BuiltInStrain(name: 'Blue Dream Auto',       type: 'Hybrid', isAutoflower: true,  flowerDays: 75,
    lineage: 'Blue Dream × Ruderalis'),
  BuiltInStrain(name: 'Jack Herer Auto',       type: 'Sativa', isAutoflower: true,  flowerDays: 77,
    lineage: 'Jack Herer × Ruderalis'),
  BuiltInStrain(name: 'Sour Diesel Auto',      type: 'Sativa', isAutoflower: true,  flowerDays: 77,
    lineage: 'Sour Diesel × Ruderalis'),
  BuiltInStrain(name: 'Auto OG Kush',          type: 'Hybrid', isAutoflower: true,  flowerDays: 70,
    lineage: 'OG Kush × Ruderalis'),
  BuiltInStrain(name: 'Cream Caramel Auto',    type: 'Indica', isAutoflower: true,  flowerDays: 70,
    breeder: 'Sweet Seeds'),
  BuiltInStrain(name: 'Auto Cheese',           type: 'Hybrid', isAutoflower: true,  flowerDays: 70,
    lineage: 'UK Cheese × Ruderalis'),
  BuiltInStrain(name: 'Royal Dwarf Auto',      type: 'Indica', isAutoflower: true,  flowerDays: 60,
    breeder: 'Royal Queen Seeds'),
  BuiltInStrain(name: 'Watermelon Auto',       type: 'Hybrid', isAutoflower: true,  flowerDays: 70),
  BuiltInStrain(name: 'Strawberry Pie Auto',   type: 'Hybrid', isAutoflower: true,  flowerDays: 75),

  // ── LANDRACES ──────────────────────────────────────────────────────────────
  //
  // Pure regional varieties — untouched by Western hybridization.
  // Flowering windows reflect outdoor / equatorial origins; many of
  // these stretch hard indoors and need extended flower cycles.

  BuiltInStrain(name: 'Thai',                  type: 'Sativa', isAutoflower: false, flowerDays: 91,
    isLandrace: true,
    lineage: 'Thai landrace (Southeast Asia)',
    thcPctMin: 14, thcPctMax: 22, terpenes: ['limonene', 'pinene']),
  BuiltInStrain(name: 'Malawi Gold',           type: 'Sativa', isAutoflower: false, flowerDays: 98,
    isLandrace: true,
    lineage: 'Malawi landrace (Southern Africa)',
    thcPctMin: 16, thcPctMax: 24, terpenes: ['terpinolene', 'pinene']),
  BuiltInStrain(name: 'Panama Red',            type: 'Sativa', isAutoflower: false, flowerDays: 84,
    isLandrace: true,
    lineage: 'Panamanian landrace',
    thcPctMin: 13, thcPctMax: 20, terpenes: ['limonene', 'pinene']),
  BuiltInStrain(name: 'Lambs Bread',           type: 'Sativa', isAutoflower: false, flowerDays: 70,
    isLandrace: true,
    lineage: 'Jamaican landrace',
    thcPctMin: 16, thcPctMax: 21, terpenes: ['caryophyllene', 'limonene']),
  BuiltInStrain(name: 'Colombian Gold',        type: 'Sativa', isAutoflower: false, flowerDays: 84,
    isLandrace: true,
    lineage: 'Colombian landrace (Santa Marta)',
    thcPctMin: 14, thcPctMax: 20, terpenes: ['pinene', 'limonene']),
  BuiltInStrain(name: 'Hawaiian',              type: 'Sativa', isAutoflower: false, flowerDays: 77,
    isLandrace: true,
    lineage: 'Hawaiian landrace',
    thcPctMin: 13, thcPctMax: 20, terpenes: ['limonene', 'pinene']),
  BuiltInStrain(name: 'Mazar-i-Sharif',        type: 'Indica', isAutoflower: false, flowerDays: 56,
    isLandrace: true,
    lineage: 'Afghan landrace (Mazar-i-Sharif)',
    thcPctMin: 18, thcPctMax: 22, terpenes: ['myrcene', 'pinene']),
  BuiltInStrain(name: 'Nepalese',              type: 'Sativa', isAutoflower: false, flowerDays: 84,
    isLandrace: true,
    lineage: 'Nepalese landrace',
    thcPctMin: 14, thcPctMax: 18, terpenes: ['pinene', 'myrcene']),
  BuiltInStrain(name: 'Moroccan',              type: 'Indica', isAutoflower: false, flowerDays: 56,
    isLandrace: true,
    lineage: 'Moroccan landrace (Rif Mountains)',
    thcPctMin: 8, thcPctMax: 14, terpenes: ['myrcene', 'pinene']),
  BuiltInStrain(name: 'Pakistan Chitral Kush', type: 'Indica', isAutoflower: false, flowerDays: 63,
    isLandrace: true,
    lineage: 'Hindu Kush landrace (Chitral)',
    thcPctMin: 16, thcPctMax: 22, terpenes: ['myrcene', 'caryophyllene']),

  // ── Additional modern hybrids (round-out catalog) ──────────────────────────

  BuiltInStrain(name: 'Tropicana Cookies',     type: 'Sativa', isAutoflower: false, flowerDays: 70,
    breeder: 'Harry Palms', lineage: 'GSC × Tangie',
    thcPctMin: 20, thcPctMax: 28, terpenes: ['limonene', 'caryophyllene']),
  BuiltInStrain(name: 'Modified Grapes',       type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'GMO × Purple Punch',
    thcPctMin: 22, thcPctMax: 29, terpenes: ['limonene', 'caryophyllene']),
  BuiltInStrain(name: 'Apples and Bananas',    type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Cookies', lineage: '(Platinum × Granddaddy Purple) × (Blue Power × Gelatti)',
    thcPctMin: 22, thcPctMax: 30, terpenes: ['limonene', 'caryophyllene']),
  BuiltInStrain(name: 'Permanent Marker',      type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Seed Junky', lineage: 'Biscotti × Jealousy × Sherb Bx1',
    thcPctMin: 24, thcPctMax: 30, terpenes: ['limonene', 'caryophyllene']),
  BuiltInStrain(name: 'Lemon Cherry Gelato',   type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Backpackboyz', lineage: 'Sunset Sherbet × Girl Scout Cookies × Lemon Pound Cake',
    thcPctMin: 23, thcPctMax: 29, terpenes: ['limonene', 'caryophyllene']),
  BuiltInStrain(name: 'Biscotti',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Cookies Fam', lineage: 'Gelato #25 × South Florida OG',
    thcPctMin: 21, thcPctMax: 27, terpenes: ['limonene', 'caryophyllene']),
  BuiltInStrain(name: 'Jealousy',              type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    breeder: 'Seed Junky', lineage: 'Sherbert Bx1 × Gelato 41',
    thcPctMin: 24, thcPctMax: 30, terpenes: ['caryophyllene', 'limonene']),
  BuiltInStrain(name: 'Oreoz',                 type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Cookies and Cream × Secret Weapon',
    thcPctMin: 22, thcPctMax: 28, terpenes: ['caryophyllene', 'limonene']),
  BuiltInStrain(name: 'White Truffle',         type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Gorilla Butter F2 phenotype',
    thcPctMin: 22, thcPctMax: 28, terpenes: ['caryophyllene', 'limonene']),
  BuiltInStrain(name: 'Lemon Tree',            type: 'Hybrid', isAutoflower: false, flowerDays: 63,
    lineage: 'Sour Diesel × Lemon Skunk',
    thcPctMin: 22, thcPctMax: 27, terpenes: ['limonene', 'pinene']),
];
