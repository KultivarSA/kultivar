import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/environment_log.dart';
import '../models/grow_expense.dart';
import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain.dart';
import '../repository/grow_repository.dart';
import '../services/hive_service.dart';
import '../services/onboarding_service.dart';
import '../services/ui_preferences_service.dart';

/// Manages the app's demo / sample-data mode.
///
/// Calling [seed] populates the repository with a realistic multi-grow
/// dataset so new users can experience the full analytics, harvest archive,
/// and care-schedule features before entering their own data.
///
/// Calling [clear] wipes everything and resets onboarding so the user is
/// walked through proper setup when they start their own journal.
class DemoDataService {
  DemoDataService._();

  static const _uuid = Uuid();

  // ── Public API ────────────────────────────────

  static Future<void> seed(GrowRepository repo) async {
    final now = DateTime.now();
    final rand = Random(42); // fixed seed → reproducible data

    // ── Strains ──────────────────────────────────
    final sBlueDream = _strain('Blue Dream', 'Blueberry × Haze', 'Hybrid',
        flowerDays: 63, yieldPct: 22);
    final sOgKush = _strain('OG Kush', 'Chemdawg × Hindu Kush', 'Indica',
        flowerDays: 56, yieldPct: 20);
    final sWhiteWidow = _strain('White Widow', 'Brazilian × South Indian', 'Hybrid',
        flowerDays: 60, yieldPct: 21);
    final sGorillaGlue = _strain('Gorilla Glue #4', 'Chem Sis × Sour Dubb', 'Hybrid',
        flowerDays: 63, yieldPct: 24);
    final sAmnesiaHaze = _strain('Amnesia Haze', 'Haze × Afghani', 'Sativa',
        flowerDays: 70, yieldPct: 19);

    for (final s in [sBlueDream, sOgKush, sWhiteWidow, sGorillaGlue, sAmnesiaHaze]) {
      repo.addStrain(s);
    }

    // ── Grow spaces ───────────────────────────────
    final vegTent = GrowSpace(
      id: _uuid.v4(),
      name: 'Veg Tent',
      type: 'Indoor Tent',
      notes: 'T5 LED, 18/6 light schedule. Clones and seedlings.',
      tempMin: 20, tempMax: 28,
      humidityMin: 50, humidityMax: 70,
      wattage: 200, areaSqM: 0.9,
      wateringEnabled: true, wateringIntervalDays: 2,
      feedingEnabled: true,  feedingIntervalDays: 7,
      ipmEnabled: true,      ipmIntervalDays: 14,
    );

    final flowerRoom = GrowSpace(
      id: _uuid.v4(),
      name: 'Flower Room',
      type: 'Flower Room',
      notes: 'HPS 1000W + supplemental LED. 12/12 light schedule.',
      tempMin: 20, tempMax: 27,
      humidityMin: 40, humidityMax: 55,
      wattage: 1200, areaSqM: 2.4,
      wateringEnabled: true, wateringIntervalDays: 2,
      feedingEnabled: true,  feedingIntervalDays: 7,
      ipmEnabled: true,      ipmIntervalDays: 21,
    );

    final dryRoom = GrowSpace(
      id: _uuid.v4(),
      name: 'Dry Room',
      type: 'Dry Room',
      // SR8 — keep units consistent with the app's default °C display
      // so a reviewer who hasn't toggled Fahrenheit sees one numbering
      // scheme everywhere.
      notes: 'AC + dehumidifier. Target 16°C / 60%RH.',
      tempMin: 15, tempMax: 21,
      humidityMin: 55, humidityMax: 65,
    );

    for (final s in [vegTent, flowerRoom, dryRoom]) {
      repo.addGrowSpace(s);
    }

    // ── Completed plants + harvest logs ───────────
    //
    // 6 finished runs across two strains so the analytics screen shows a
    // meaningful strain leaderboard and yield trend.
    // SR8 — sub-scores on every run so the Grow Report's Quality
    // Assessment card renders the full half-star matrix, not just the
    // overall rating.  Real growers fill these in selectively but the
    // demo benefits from showing the full feature surface.
    final completedRuns = <_RunSpec>[
      _RunSpec('Blue Dream #1', sBlueDream, flowerRoom, daysAgo: 140,
          duration: 91, wet: 580, dry: 127, rating: 5,
          smell: 4.5, effect: 5, bagAppeal: 4.5,
          aroma: 'Sweet berry', flavor: 'Blueberry with earthy finish',
          effectNotes: 'Uplifting, creative'),
      _RunSpec('OG Kush #1', sOgKush, flowerRoom, daysAgo: 115,
          duration: 78, wet: 450, dry: 94, rating: 4,
          smell: 4, effect: 4.5, bagAppeal: 3.5,
          aroma: 'Pine and citrus', flavor: 'Earthy, woody',
          effectNotes: 'Relaxed, happy'),
      _RunSpec('White Widow #1', sWhiteWidow, flowerRoom, daysAgo: 95,
          duration: 84, wet: 520, dry: 108, rating: 4,
          smell: 3.5, effect: 4, bagAppeal: 4,
          aroma: 'Spicy and floral', flavor: 'Earthy sweetness',
          effectNotes: 'Balanced, euphoric'),
      _RunSpec('Gorilla Glue #1', sGorillaGlue, flowerRoom, daysAgo: 72,
          duration: 95, wet: 680, dry: 142, rating: 5,
          smell: 5, effect: 5, bagAppeal: 4.5,
          aroma: 'Pine, diesel', flavor: 'Earthy coffee notes',
          effectNotes: 'Heavy, full-body relaxation'),
      _RunSpec('Blue Dream #2', sBlueDream, flowerRoom, daysAgo: 50,
          duration: 88, wet: 555, dry: 119, rating: 4,
          smell: 4, effect: 4, bagAppeal: 4.5,
          aroma: 'Berry and vanilla', flavor: 'Sweet berry, smooth',
          effectNotes: 'Uplifting, cerebral'),
      _RunSpec('OG Kush #2', sOgKush, flowerRoom, daysAgo: 28,
          duration: 82, wet: 420, dry: 87, rating: 3,
          smell: 3.5, effect: 3, bagAppeal: 3,
          aroma: 'Fuel, lemon', flavor: 'Sour, earthy',
          effectNotes: 'Calming, focused'),
    ];

    for (final run in completedRuns) {
      final startDate = now.subtract(Duration(days: run.daysAgo + run.duration));
      final harvestDate = now.subtract(Duration(days: run.daysAgo));
      // SR8 — photoperiod plants flip ~28-35 days in.  Setting
      // `flipDate` is what makes the "Flipped to Flower" event appear
      // on the per-plant timeline; without it the lifecycle stepper
      // skips straight from "Seed started" to "Harvested" and the
      // demo reads like a feature gap.
      final flipDate = startDate.add(const Duration(days: 32));

      final plant = Plant(
        id: _uuid.v4(),
        name: run.name,
        strain: run.strain.name,
        startDate: startDate,
        flipDate: flipDate,
        growSpaceId: run.space.id,
        status: PlantStatus.completed,
        isArchived: true,
        archivedAt: harvestDate,
        harvestedDate: harvestDate,
        wetWeight: run.wet.toDouble(),
        dryWeight: run.dry.toDouble(),
        growStage: GrowStage.flush,
        archiveReason: 'Curing completed successfully',
      );
      repo.addPlant(plant);

      final log = HarvestLog(
        id: _uuid.v4(),
        plantId: plant.id,
        plantName: plant.name,
        strain: run.strain.name,
        harvestedDate: harvestDate,
        wetWeight: run.wet.toDouble(),
        dryWeight: run.dry.toDouble(),
        isDraft: false,
        qualityRating: run.rating.toDouble(),
        smellRating: run.smell,
        effectRating: run.effect,
        bagAppealRating: run.bagAppeal,
        aromaNote: run.aroma,
        flavorNotes: run.flavor,
        effectNotes: run.effectNotes,
        notes: 'Demo run. ${run.duration} days from seed to harvest.',
      );
      repo.addHarvestLog(log);
    }

    // ── Active plants ─────────────────────────────
    final activeSpecs = <_ActiveSpec>[
      _ActiveSpec('Blue Dream #3', sBlueDream, flowerRoom,
          daysAgo: 55, stage: GrowStage.lateFlower),
      _ActiveSpec('White Widow #2', sWhiteWidow, flowerRoom,
          daysAgo: 42, stage: GrowStage.earlyFlower),
      _ActiveSpec('Gorilla Glue #2', sGorillaGlue, vegTent,
          daysAgo: 28, stage: GrowStage.vegetative),
      _ActiveSpec('Amnesia Haze #1', sAmnesiaHaze, vegTent,
          daysAgo: 18, stage: GrowStage.seedling),
    ];

    final activePlants = <Plant>[];
    for (final spec in activeSpecs) {
      final plant = Plant(
        id: _uuid.v4(),
        name: spec.name,
        strain: spec.strain.name,
        startDate: now.subtract(Duration(days: spec.daysAgo)),
        growSpaceId: spec.space.id,
        status: PlantStatus.growing,
        growStage: spec.stage,
      );
      repo.addPlant(plant);
      activePlants.add(plant);
    }

    // ── Plant notes for active plants ─────────────
    final noteTemplates = <({String plantId, int daysAgo, NoteCategory cat, String text})>[
      (plantId: activePlants[0].id, daysAgo: 3,  cat: NoteCategory.watering,
       text: 'Watered 2L pH 6.2. Runoff pH 6.4, EC 1.8.'),
      (plantId: activePlants[0].id, daysAgo: 7,  cat: NoteCategory.feeding,
       text: 'Week 6 bloom feed. PK booster added. Plants looking vigorous.'),
      (plantId: activePlants[0].id, daysAgo: 10, cat: NoteCategory.observation,
       text: 'Trichomes 30% amber. Estimating 2 weeks to harvest.'),
      (plantId: activePlants[1].id, daysAgo: 2,  cat: NoteCategory.watering,
       text: 'Watered 1.5L. Soil slightly dry. Plants responsive.'),
      (plantId: activePlants[1].id, daysAgo: 5,  cat: NoteCategory.ipm,
       text: 'Weekly IPM spray — neem oil + potassium bicarbonate. No signs of pests.'),
      (plantId: activePlants[1].id, daysAgo: 12, cat: NoteCategory.training,
       text: 'LST adjustment. Tied down two main colas to even canopy.'),
      (plantId: activePlants[2].id, daysAgo: 1,  cat: NoteCategory.watering,
       text: 'Watered 1L. Starting light veg feed next watering.'),
      (plantId: activePlants[2].id, daysAgo: 8,  cat: NoteCategory.observation,
       text: 'Healthy root zone visible. Transplanting to final pot next week.'),
      (plantId: activePlants[3].id, daysAgo: 2,  cat: NoteCategory.observation,
       text: 'Second node showing. Strong tap root, healthy seedling.'),
    ];

    for (final n in noteTemplates) {
      repo.addNote(PlantNote(
        id: _uuid.v4(),
        plantId: n.plantId,
        createdAt: now.subtract(Duration(days: n.daysAgo)),
        category: n.cat,
        content: n.text,
      ));
    }

    // ── Environment logs ──────────────────────────
    //
    // ~30 days of readings per active space so charts render properly.
    final envLogs = <EnvironmentLog>[];

    envLogs.addAll(_generateEnvLogs(
      spaceId: flowerRoom.id,
      daysBack: 30,
      baseTemp: 24.5,
      baseHumidity: 48.0,
      rand: rand,
    ));
    envLogs.addAll(_generateEnvLogs(
      spaceId: vegTent.id,
      daysBack: 30,
      baseTemp: 25.5,
      baseHumidity: 62.0,
      rand: rand,
    ));
    envLogs.addAll(_generateEnvLogs(
      spaceId: dryRoom.id,
      daysBack: 14,
      baseTemp: 18.0,
      baseHumidity: 60.0,
      rand: rand,
    ));

    await HiveService.addEnvironmentLogs(envLogs);

    // ── Expenses ──────────────────────────────────
    //
    // SR8 — without this block the Costs tab shows an empty state on
    // a fresh demo install and the App Store reviewer never sees the
    // cost-per-gram analytics.  Seeds a realistic mix of:
    //   • Per-plant costs (seeds, clones, nutrients) on each completed
    //     run so cost-per-gram populates on the Grow Report.
    //   • Space-level recurring costs (electricity, substrate, IPM,
    //     water) so the "By Space" breakdown is non-trivial.
    //
    // Amounts are picked to land in the realistic indie-grower range
    // (US$ basis — the auto-detected currency for non-localised
    // demos): roughly $50-150 per cycle in consumables.
    final allPlants = repo.plants
        .where((p) => p.status == PlantStatus.completed)
        .toList();
    for (final plant in allPlants) {
      final harvestDate = plant.archivedAt ?? now;
      final startDate = plant.startDate;

      // Seeds / clones — bought at plant start.
      repo.addExpense(GrowExpense(
        id: _uuid.v4(),
        plantId: plant.id,
        growSpaceId: plant.growSpaceId,
        date: startDate,
        category: ExpenseCategory.seeds,
        description: 'Seed pack — ${plant.strain}',
        amount: 35 + rand.nextInt(20).toDouble(),
      ));

      // Nutrients across the cycle — bloom feed in mid-flower.
      repo.addExpense(GrowExpense(
        id: _uuid.v4(),
        plantId: plant.id,
        growSpaceId: plant.growSpaceId,
        date: startDate.add(const Duration(days: 35)),
        category: ExpenseCategory.nutrients,
        description: 'Base + bloom nutrient line',
        amount: 28 + rand.nextDouble() * 14,
      ));

      // Substrate / pots — bought near transplant.
      repo.addExpense(GrowExpense(
        id: _uuid.v4(),
        plantId: plant.id,
        growSpaceId: plant.growSpaceId,
        date: startDate.add(const Duration(days: 10)),
        category: ExpenseCategory.substrate,
        description: 'Coco coir + perlite',
        amount: 18 + rand.nextDouble() * 8,
      ));

      // IPM consumable mid-cycle.
      if (rand.nextBool()) {
        repo.addExpense(GrowExpense(
          id: _uuid.v4(),
          plantId: plant.id,
          growSpaceId: plant.growSpaceId,
          date: startDate.add(Duration(days: 25 + rand.nextInt(20))),
          category: ExpenseCategory.ipm,
          description: 'Neem oil + soap',
          amount: 12 + rand.nextDouble() * 6,
        ));
      }

      // Water bill share — small per-plant allocation around mid-cycle.
      repo.addExpense(GrowExpense(
        id: _uuid.v4(),
        plantId: plant.id,
        growSpaceId: plant.growSpaceId,
        date: startDate.add(Duration(days: 45 + rand.nextInt(15))),
        category: ExpenseCategory.water,
        description: 'Water (allocated share)',
        amount: 6 + rand.nextDouble() * 3,
      ));

      // Electricity charged at harvest — the biggest line item per
      // cycle.  Approximates 1.2 kW HPS @ ~12h/day across the run.
      repo.addExpense(GrowExpense(
        id: _uuid.v4(),
        plantId: plant.id,
        growSpaceId: plant.growSpaceId,
        date: harvestDate,
        category: ExpenseCategory.electricity,
        description: 'Electricity (cycle share)',
        amount: 35 + rand.nextDouble() * 25,
      ));
    }

    // ── Space-level recurring costs ──
    //
    // These aren't attributed to any single plant — they're the
    // shared overhead the user spreads across whatever's in the room.
    // Drives the "By Space" tab on the Costs screen.
    repo.addExpense(GrowExpense(
      id: _uuid.v4(),
      growSpaceId: flowerRoom.id,
      date: now.subtract(const Duration(days: 30)),
      category: ExpenseCategory.equipment,
      description: 'Inline fan replacement',
      amount: 89.50,
    ));
    repo.addExpense(GrowExpense(
      id: _uuid.v4(),
      growSpaceId: vegTent.id,
      date: now.subtract(const Duration(days: 60)),
      category: ExpenseCategory.equipment,
      description: 'New tent zipper repair kit',
      amount: 12.00,
    ));
    repo.addExpense(GrowExpense(
      id: _uuid.v4(),
      growSpaceId: dryRoom.id,
      date: now.subtract(const Duration(days: 95)),
      category: ExpenseCategory.equipment,
      description: 'Dehumidifier filter',
      amount: 24.00,
    ));

    await UiPreferencesService.saveIsDemoMode(true);
    await OnboardingService.markComplete();
    // Flush the in-memory data to disk now so it persists across an
    // app restart.
    //
    // Bug fix (real-device finding): the earlier code called
    // `repo.load()` here on the theory that "reload from storage so
    // all listeners see the full dataset" was needed.  In fact:
    //
    //   * Every addPlant / addGrowSpace / addNote etc. above already
    //     fired notifyListeners() synchronously, so the UI sees the
    //     full dataset without any reload.
    //   * Disk writes from those addX calls are DEBOUNCED 300ms.
    //     Calling load() within that window reads stale (empty) data
    //     from SharedPreferences and OVERWRITES the correct in-memory
    //     state -- producing the "demo banner shows but home grid is
    //     empty" symptom Marco saw on his Samsung S22.
    //
    // The right call is `save()` -- forces an immediate flush of
    // the pending debounced writes, no read involved.
    await repo.save();
  }

  /// Wipes all data and resets to fresh-user state.
  static Future<void> clear(GrowRepository repo) async {
    await repo.clearAllData();
    await UiPreferencesService.saveIsDemoMode(false);
    await OnboardingService.reset();
  }

  // ── Helpers ───────────────────────────────────

  static Strain _strain(
    String name,
    String genetics,
    String type, {
    required int flowerDays,
    required double yieldPct,
  }) =>
      Strain(
        id: _uuid.v4(),
        name: name,
        genetics: genetics,
        type: type,
        expectedFlowerDays: flowerDays,
        expectedYieldPercent: yieldPct,
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
      );

  static List<EnvironmentLog> _generateEnvLogs({
    required String spaceId,
    required int daysBack,
    required double baseTemp,
    required double baseHumidity,
    required Random rand,
  }) {
    final logs = <EnvironmentLog>[];
    final now = DateTime.now();

    // One reading every ~12 hours with slight random variance.
    for (int h = 0; h <= daysBack * 24; h += 10 + rand.nextInt(6)) {
      final recordedAt = now.subtract(Duration(hours: h));
      final temp = baseTemp + (rand.nextDouble() - 0.5) * 2.5;
      final humidity = baseHumidity + (rand.nextDouble() - 0.5) * 8;
      logs.add(EnvironmentLog(
        id: _uuid.v4(),
        growSpaceId: spaceId,
        recordedAt: recordedAt,
        temperature: double.parse(temp.toStringAsFixed(1)),
        humidity: double.parse(humidity.toStringAsFixed(1)),
      ));
    }
    return logs;
  }
}

// ── Internal data-spec helpers ────────────────────

class _RunSpec {
  final String name;
  final Strain strain;
  final GrowSpace space;
  final int daysAgo;
  final int duration;
  final int wet;
  final int dry;
  final int rating;
  // SR8 — sub-scores (smell / effect / bag-appeal) so the harvest
  // quality card on the Grow Report fully populates.
  final double smell;
  final double effect;
  final double bagAppeal;
  final String aroma;
  final String flavor;
  final String effectNotes;

  const _RunSpec(
    this.name,
    this.strain,
    this.space, {
    required this.daysAgo,
    required this.duration,
    required this.wet,
    required this.dry,
    required this.rating,
    required this.smell,
    required this.effect,
    required this.bagAppeal,
    required this.aroma,
    required this.flavor,
    required this.effectNotes,
  });
}

class _ActiveSpec {
  final String name;
  final Strain strain;
  final GrowSpace space;
  final int daysAgo;
  final GrowStage stage;

  const _ActiveSpec(
    this.name,
    this.strain,
    this.space, {
    required this.daysAgo,
    required this.stage,
  });
}
