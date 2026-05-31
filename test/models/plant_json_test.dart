import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/plant.dart';

/// Plant JSON round-trip — guards against B7-style regressions where a new
/// field is added to the model but accidentally omitted from `toJson` or
/// `fromJson`, causing data loss after save/reload.

void main() {
  group('Plant JSON', () {
    test('every meaningful field survives a round-trip', () {
      final original = Plant(
        id: 'p1',
        name: 'Test Plant',
        strain: 'Blue Dream',
        strainId: 'strain-id-1',
        startDate: DateTime.utc(2026, 1, 1),
        targetHarvestDate: DateTime.utc(2026, 5, 1),
        growSpaceId: 'space-A',
        isClone: true,
        status: PlantStatus.curing,
        isArchived: false,
        harvestedDate: DateTime.utc(2026, 4, 15),
        dryingEndDate: DateTime.utc(2026, 4, 25),
        curingEndDate: DateTime.utc(2026, 5, 25),
        wetWeight: 200.5,
        dryWeight: 65.2,
        archiveReason: 'Test reason',
        archivedAt: DateTime.utc(2026, 6, 1),
        burpingRemindersEnabled: true,
        burpingSchedule: 'week2',
        curingCompleteNotification: true,
        dryingCheckNotification: true,
        growStage: GrowStage.lateFlower,
        isAutoflower: true,
        flipDate: DateTime.utc(2026, 3, 1),
        medium: 'coco',
        lightType: 'hps',
        phenotypeTag: 'Pheno #3',
        potSizeLitres: 11.0,
        motherPlantId: 'mother-plant-id',
        wateringReminderEnabled: true,
        wateringIntervalDays: 3,
        feedingReminderEnabled: true,
        feedingIntervalDays: 5,
        ipmReminderEnabled: true,
        ipmIntervalDays: 14,
      );

      // Encode → string → decode → reconstruct (proves serialisation is
      // self-consistent, not just identity-shaped).
      final raw = jsonEncode(original.toJson());
      final restored =
          Plant.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      // Spot-check every field — explicit per-field assertions surface
      // exactly which field went missing if a regression lands.
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.strain, original.strain);
      expect(restored.strainId, original.strainId);
      expect(restored.startDate, original.startDate);
      expect(restored.targetHarvestDate, original.targetHarvestDate);
      expect(restored.growSpaceId, original.growSpaceId);
      expect(restored.isClone, original.isClone);
      expect(restored.status, original.status);
      expect(restored.harvestedDate, original.harvestedDate);
      expect(restored.dryingEndDate, original.dryingEndDate);
      expect(restored.curingEndDate, original.curingEndDate);
      expect(restored.wetWeight, original.wetWeight);
      expect(restored.dryWeight, original.dryWeight);
      expect(restored.archiveReason, original.archiveReason);
      expect(restored.archivedAt, original.archivedAt);
      expect(restored.burpingRemindersEnabled, original.burpingRemindersEnabled);
      expect(restored.burpingSchedule, original.burpingSchedule);
      expect(restored.curingCompleteNotification,
          original.curingCompleteNotification);
      expect(restored.dryingCheckNotification, original.dryingCheckNotification);
      expect(restored.growStage, original.growStage);
      expect(restored.isAutoflower, original.isAutoflower);
      expect(restored.flipDate, original.flipDate);
      expect(restored.medium, original.medium);
      expect(restored.lightType, original.lightType);
      expect(restored.phenotypeTag, original.phenotypeTag);
      expect(restored.potSizeLitres, original.potSizeLitres);
      expect(restored.motherPlantId, original.motherPlantId);
      expect(restored.wateringReminderEnabled, original.wateringReminderEnabled);
      expect(restored.wateringIntervalDays, original.wateringIntervalDays);
      expect(restored.feedingReminderEnabled, original.feedingReminderEnabled);
      expect(restored.feedingIntervalDays, original.feedingIntervalDays);
      expect(restored.ipmReminderEnabled, original.ipmReminderEnabled);
      expect(restored.ipmIntervalDays, original.ipmIntervalDays);
    });

    test('minimal plant (just required fields) round-trips', () {
      final original = Plant(
        id: 'min',
        name: 'Just a name',
        strain: 'Unknown',
        startDate: DateTime.utc(2026, 1, 1),
        growSpaceId: 'space-A',
      );
      final restored = Plant.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

      expect(restored.id, 'min');
      expect(restored.strainId, isNull);
      expect(restored.motherPlantId, isNull);
      expect(restored.targetHarvestDate, isNull);
      expect(restored.isClone, false);
      expect(restored.isArchived, false);
      expect(restored.status, PlantStatus.growing);
    });

    test('per-plant location override survives the round-trip (B8)', () {
      // Catches regressions where someone adds a location field but
      // forgets one of fromJson / toJson — the field would silently
      // round-trip to null on next launch.
      final outdoor = Plant(
        id: 'out-1',
        name: 'Garden plant',
        strain: 'Auto White Widow',
        startDate: DateTime.utc(2026, 4, 15),
        growSpaceId: 'space-out',
        lightType: 'outdoor',
        latitude: 51.5074,
        longitude: -0.1278,
        locationLabel: 'Back garden',
      );
      final restored = Plant.fromJson(jsonDecode(jsonEncode(outdoor.toJson()))
          as Map<String, dynamic>);

      expect(restored.latitude, closeTo(51.5074, 0.0001));
      expect(restored.longitude, closeTo(-0.1278, 0.0001));
      expect(restored.locationLabel, 'Back garden');
    });

    test('clone with mother lineage explicitly survives the round-trip', () {
      // The B7 regression scenario: ensure motherPlantId still serialises
      // when the plant is constructed via the production flow's exact field
      // ordering (the add-plant sheet sets isClone before motherPlantId).
      final clone = Plant(
        id: 'clone-1',
        name: 'Daughter #1',
        strain: 'Blue Dream',
        startDate: DateTime.utc(2026, 4, 15),
        growSpaceId: 'space-A',
        isClone: true,
        motherPlantId: 'mother-42',
      );
      final restored = Plant.fromJson(
          jsonDecode(jsonEncode(clone.toJson())) as Map<String, dynamic>);

      expect(restored.isClone, true);
      expect(restored.motherPlantId, 'mother-42');
    });
  });
}
