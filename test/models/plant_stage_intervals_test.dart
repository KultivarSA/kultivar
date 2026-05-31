import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/plant.dart';

void main() {
  // Minimal Plant builder for these focused tests.  Only the fields
  // F10 actually inspects (growStage, the three base intervals, the
  // toggle) need to be filled in.
  Plant build({
    required int waterDays,
    required int feedDays,
    required int ipmDays,
    GrowStage? stage,
    bool autoAdjust = false,
  }) =>
      Plant(
        id: 'p',
        name: 'p',
        strain: 's',
        startDate: DateTime(2024, 1, 1),
        growSpaceId: 'space',
        wateringIntervalDays: waterDays,
        feedingIntervalDays: feedDays,
        ipmIntervalDays: ipmDays,
        growStage: stage,
        autoAdjustIntervalsByStage: autoAdjust,
      );

  group('F10 — effective intervals (toggle OFF)', () {
    test('returns base values for every stage', () {
      for (final stage in GrowStage.values) {
        final p = build(
          waterDays: 2, feedDays: 7, ipmDays: 7,
          stage: stage,
        );
        expect(p.effectiveWateringIntervalDays(), 2,
            reason: 'water · $stage');
        expect(p.effectiveFeedingIntervalDays(), 7,
            reason: 'feed · $stage');
        expect(p.effectiveIpmIntervalDays(), 7,
            reason: 'ipm · $stage');
      }
    });

    test('null growStage → base values', () {
      final p = build(waterDays: 3, feedDays: 5, ipmDays: 6);
      expect(p.effectiveWateringIntervalDays(), 3);
      expect(p.effectiveFeedingIntervalDays(), 5);
      expect(p.effectiveIpmIntervalDays(), 6);
    });
  });

  group('F10 — effective intervals (toggle ON)', () {
    test('seedling: water shrinks, feed/IPM skip (0)', () {
      final p = build(
        waterDays: 2, feedDays: 7, ipmDays: 7,
        stage: GrowStage.seedling, autoAdjust: true,
      );
      // 2 × 0.7 = 1.4 → rounds to 1, never below 1.
      expect(p.effectiveWateringIntervalDays(), 1);
      expect(p.effectiveFeedingIntervalDays(), 0);
      expect(p.effectiveIpmIntervalDays(), 0);
    });

    test('vegetative: all multipliers ×1.0 (no change)', () {
      final p = build(
        waterDays: 2, feedDays: 7, ipmDays: 7,
        stage: GrowStage.vegetative, autoAdjust: true,
      );
      expect(p.effectiveWateringIntervalDays(), 2);
      expect(p.effectiveFeedingIntervalDays(), 7);
      expect(p.effectiveIpmIntervalDays(), 7);
    });

    test('early flower: water +25%, feed unchanged, IPM +50%', () {
      final p = build(
        waterDays: 2, feedDays: 7, ipmDays: 4,
        stage: GrowStage.earlyFlower, autoAdjust: true,
      );
      // 2 × 1.25 = 2.5 → rounds to 3 (banker's rounding doesn't apply
      // to Dart's int.round on .5 → away-from-zero, so 2.5 → 3).
      expect(p.effectiveWateringIntervalDays(), 3);
      expect(p.effectiveFeedingIntervalDays(), 7);
      // 4 × 1.5 = 6
      expect(p.effectiveIpmIntervalDays(), 6);
    });

    test('late flower: water +50%, feed unchanged, IPM +100%', () {
      final p = build(
        waterDays: 2, feedDays: 7, ipmDays: 4,
        stage: GrowStage.lateFlower, autoAdjust: true,
      );
      expect(p.effectiveWateringIntervalDays(), 3); // 2 × 1.5
      expect(p.effectiveFeedingIntervalDays(), 7);
      expect(p.effectiveIpmIntervalDays(), 8);     // 4 × 2.0
    });

    test('flush: feed + IPM skip, water still +50%', () {
      final p = build(
        waterDays: 2, feedDays: 7, ipmDays: 5,
        stage: GrowStage.flush, autoAdjust: true,
      );
      expect(p.effectiveWateringIntervalDays(), 3);
      expect(p.effectiveFeedingIntervalDays(), 0);
      expect(p.effectiveIpmIntervalDays(), 0);
    });

    test('intervals never round below 1 even with tiny base × small mult',
        () {
      final p = build(
        waterDays: 1, feedDays: 1, ipmDays: 1,
        stage: GrowStage.seedling, autoAdjust: true,
      );
      // water: 1 × 0.7 = 0.7 → rounds to 1 (floor of effective is 1).
      expect(p.effectiveWateringIntervalDays(), 1);
    });

    test('null growStage with toggle on still returns base values', () {
      // Toggle implies stage-awareness — if we don't know the stage we
      // can't pick a multiplier, so we conservatively fall through to
      // the base value.  Stops the reminder cadence from changing
      // unexpectedly for plants whose stage hasn't been set yet.
      final p = build(
        waterDays: 4, feedDays: 7, ipmDays: 7,
        stage: null, autoAdjust: true,
      );
      expect(p.effectiveWateringIntervalDays(), 4);
      expect(p.effectiveFeedingIntervalDays(), 7);
      expect(p.effectiveIpmIntervalDays(), 7);
    });
  });
}
