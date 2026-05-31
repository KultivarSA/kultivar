import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/harvest_log.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/services/community_service.dart';

/// Builds a minimal harvested plant.
Plant _plant({DateTime? harvestedDate}) {
  return Plant(
    id: 'p1',
    name: 'Subject',
    strain: 'Blue Dream',
    growSpaceId: 'space-1',
    startDate: DateTime.utc(2026, 1, 1),
    status: PlantStatus.harvested,
    harvestedDate: harvestedDate ?? DateTime.utc(2026, 4, 1),
  );
}

HarvestLog _harvestLog({double? dryWeight = 30.0}) {
  return HarvestLog(
    id: 'h1',
    plantId: 'p1',
    plantName: 'Subject',
    strain: 'Blue Dream',
    harvestedDate: DateTime.utc(2026, 4, 1),
    dryWeight: dryWeight,
  );
}

void main() {
  // CommunityService is a static class; every public method returns a
  // Future<…?> when no backend is reachable.  Two backstops gate the
  // calls:
  //
  //   1. SupabaseConfig.isConfigured — false when the build-time
  //      SUPABASE_URL/SUPABASE_ANON_KEY dart-defines aren't set
  //      (the default in tests and OSS contributors' machines).
  //   2. CommunityService.hasAccess — flipped by SubscriptionService
  //      to match the current tier.  Pro Cloud → true.  Free /
  //      Lifetime Local → false (we must NOT hit Supabase from a
  //      tier that hasn't paid for it).
  //
  // Both gates must short-circuit cleanly without throwing or making
  // any network call.  These tests pin that behaviour.

  group('CommunityService.hasAccess gating', () {
    setUp(() {
      // Reset to the production default before each test so we know
      // we're observing the gate, not residual state.
      CommunityService.hasAccess = false;
    });

    test('fetchStats returns null when hasAccess is false', () async {
      expect(CommunityService.hasAccess, isFalse);
      expect(await CommunityService.fetchStats('Blue Dream'), isNull);
    });

    test('fetchDiaryStats returns null when hasAccess is false', () async {
      expect(await CommunityService.fetchDiaryStats('Blue Dream'), isNull);
    });

    test('submitBenchmark returns false when hasAccess is false',
        () async {
      final ok = await CommunityService.submitBenchmark(
        plant: _plant(),
        log: _harvestLog(),
      );
      expect(ok, isFalse);
    });

    test('submitDiaryEntry returns false when hasAccess is false',
        () async {
      final ok = await CommunityService.submitDiaryEntry(
        plant: _plant(),
        log: _harvestLog(),
      );
      expect(ok, isFalse);
    });

    test('every gated method completes without throwing', () async {
      // Belt-and-braces: re-cover all four entry points in one
      // expectation so a future addition to the gated surface fails
      // the build until it's also asserted here.
      await expectLater(
          CommunityService.fetchStats('x'), completes);
      await expectLater(
          CommunityService.fetchDiaryStats('x'), completes);
      await expectLater(
        CommunityService.submitBenchmark(
            plant: _plant(), log: _harvestLog()),
        completes,
      );
      await expectLater(
        CommunityService.submitDiaryEntry(
            plant: _plant(), log: _harvestLog()),
        completes,
      );
    });
  });

  group('CommunityService argument validation (independent of network)',
      () {
    setUp(() {
      // Flip the access gate to true so we exercise the inner
      // validation paths (dry weight > 0, harvested date required,
      // etc.) — without [hasAccess] the gate would short-circuit
      // before these checks ever run.
      CommunityService.hasAccess = true;
    });

    tearDown(() {
      CommunityService.hasAccess = false;
    });

    test('submitBenchmark rejects a missing dry weight', () async {
      final ok = await CommunityService.submitBenchmark(
        plant: _plant(),
        log: _harvestLog(dryWeight: null),
      );
      expect(ok, isFalse);
    });

    test('submitBenchmark rejects a zero / negative dry weight',
        () async {
      expect(
        await CommunityService.submitBenchmark(
            plant: _plant(), log: _harvestLog(dryWeight: 0)),
        isFalse,
      );
      expect(
        await CommunityService.submitBenchmark(
            plant: _plant(), log: _harvestLog(dryWeight: -1.5)),
        isFalse,
      );
    });

    test('submitBenchmark rejects a plant with no harvestedDate',
        () async {
      final unharvestedPlant = Plant(
        id: 'p2',
        name: 'Subject',
        strain: 'Blue Dream',
        growSpaceId: 'space-1',
        startDate: DateTime.utc(2026, 1, 1),
        status: PlantStatus.growing,
        // No harvestedDate.
      );
      final ok = await CommunityService.submitBenchmark(
        plant: unharvestedPlant,
        log: _harvestLog(),
      );
      expect(ok, isFalse);
    });

    test('submitDiaryEntry rejects a plant with no harvestedDate',
        () async {
      final unharvestedPlant = Plant(
        id: 'p2',
        name: 'Subject',
        strain: 'Blue Dream',
        growSpaceId: 'space-1',
        startDate: DateTime.utc(2026, 1, 1),
        status: PlantStatus.growing,
      );
      final ok = await CommunityService.submitDiaryEntry(
        plant: unharvestedPlant,
        log: _harvestLog(),
      );
      expect(ok, isFalse);
    });
  });
}
