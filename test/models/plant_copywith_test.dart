import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/plant.dart';

/// Tests for [Plant.copyWith] — specifically the `_unset` sentinel pattern.
///
/// The sentinel is fragile: if anyone ever changes one of the `Object? foo =
/// _unset` parameters back to `Type? foo`, the field can no longer be
/// *cleared* via `copyWith(foo: null)`.  That bug is silent — the field
/// just keeps its previous value when the caller meant to nuke it.
///
/// These tests would catch that regression on every nullable field.

void main() {
  // A plant with EVERY optional field populated, so we can verify
  //   (a) copyWith() with no args preserves them all (identity), and
  //   (b) copyWith(field: null) actually clears each one (sentinel works).
  Plant fullPlant() => Plant(
        id: 'p1',
        name: 'Test plant',
        strain: 'Blue Dream',
        strainId: 'strain-1',
        startDate: DateTime.utc(2026, 1, 1),
        targetHarvestDate: DateTime.utc(2026, 5, 1),
        growSpaceId: 'space-1',
        isClone: true,
        status: PlantStatus.growing,
        isArchived: false,
        harvestedDate: DateTime.utc(2026, 5, 2),
        dryingEndDate: DateTime.utc(2026, 5, 12),
        curingEndDate: DateTime.utc(2026, 6, 12),
        wetWeight: 200.0,
        dryWeight: 60.0,
        archiveReason: 'Pre-set reason',
        archivedAt: DateTime.utc(2026, 7, 1),
        burpingRemindersEnabled: true,
        burpingSchedule: 'week2',
        burpingTime: const TimeOfDay(hour: 9, minute: 30),
        curingCompleteNotification: true,
        dryingCheckNotification: true,
        growStage: GrowStage.earlyFlower,
        isAutoflower: true,
        flipDate: DateTime.utc(2026, 3, 1),
        medium: 'coco',
        lightType: 'led',
        phenotypeTag: 'Pheno #2',
        potSizeLitres: 11.0,
        motherPlantId: 'mother-1',
        latitude: 51.5074,
        longitude: -0.1278,
        locationLabel: 'Back garden',
        wateringReminderEnabled: true,
        wateringIntervalDays: 3,
        feedingReminderEnabled: true,
        feedingIntervalDays: 5,
        ipmReminderEnabled: true,
        ipmIntervalDays: 14,
      );

  group('Plant.copyWith identity', () {
    test('no args preserves every field', () {
      final original = fullPlant();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.strain, original.strain);
      expect(copy.strainId, original.strainId);
      expect(copy.startDate, original.startDate);
      expect(copy.targetHarvestDate, original.targetHarvestDate);
      expect(copy.growSpaceId, original.growSpaceId);
      expect(copy.isClone, original.isClone);
      expect(copy.status, original.status);
      expect(copy.isArchived, original.isArchived);
      expect(copy.harvestedDate, original.harvestedDate);
      expect(copy.dryingEndDate, original.dryingEndDate);
      expect(copy.curingEndDate, original.curingEndDate);
      expect(copy.wetWeight, original.wetWeight);
      expect(copy.dryWeight, original.dryWeight);
      expect(copy.archiveReason, original.archiveReason);
      expect(copy.archivedAt, original.archivedAt);
      expect(copy.burpingRemindersEnabled, original.burpingRemindersEnabled);
      expect(copy.burpingSchedule, original.burpingSchedule);
      expect(copy.burpingTime, original.burpingTime);
      expect(copy.curingCompleteNotification,
          original.curingCompleteNotification);
      expect(copy.dryingCheckNotification, original.dryingCheckNotification);
      expect(copy.growStage, original.growStage);
      expect(copy.isAutoflower, original.isAutoflower);
      expect(copy.flipDate, original.flipDate);
      expect(copy.medium, original.medium);
      expect(copy.lightType, original.lightType);
      expect(copy.phenotypeTag, original.phenotypeTag);
      expect(copy.potSizeLitres, original.potSizeLitres);
      expect(copy.motherPlantId, original.motherPlantId);
      expect(copy.latitude, original.latitude);
      expect(copy.longitude, original.longitude);
      expect(copy.locationLabel, original.locationLabel);
      expect(copy.wateringReminderEnabled, original.wateringReminderEnabled);
      expect(copy.wateringIntervalDays, original.wateringIntervalDays);
      expect(copy.feedingReminderEnabled, original.feedingReminderEnabled);
      expect(copy.feedingIntervalDays, original.feedingIntervalDays);
      expect(copy.ipmReminderEnabled, original.ipmReminderEnabled);
      expect(copy.ipmIntervalDays, original.ipmIntervalDays);
    });
  });

  group('Plant.copyWith required-field overrides', () {
    final original = fullPlant();

    test('name', () {
      final c = original.copyWith(name: 'Renamed');
      expect(c.name, 'Renamed');
      expect(c.strain, original.strain); // others preserved
    });

    test('strain', () {
      final c = original.copyWith(strain: 'OG Kush');
      expect(c.strain, 'OG Kush');
    });

    test('startDate', () {
      final newDate = DateTime.utc(2026, 2, 15);
      final c = original.copyWith(startDate: newDate);
      expect(c.startDate, newDate);
    });

    test('growSpaceId', () {
      final c = original.copyWith(growSpaceId: 'space-X');
      expect(c.growSpaceId, 'space-X');
    });

    test('status', () {
      final c = original.copyWith(status: PlantStatus.harvested);
      expect(c.status, PlantStatus.harvested);
    });

    test('isArchived', () {
      final c = original.copyWith(isArchived: true);
      expect(c.isArchived, true);
    });

    test('isClone', () {
      final c = original.copyWith(isClone: false);
      expect(c.isClone, false);
    });

    test('id is intentionally NOT exposed via copyWith', () {
      // Sanity-check the contract: id is intrinsic to a Plant and the
      // copyWith API should never let callers mutate it.  This is what
      // keeps "same plant edited" distinct from "different plant".
      expect(original.copyWith().id, original.id);
    });
  });

  // The heart of the test suite: every nullable field must support both
  // (a) explicit null clears, and (b) non-null assignment.  A regression
  // would manifest as the value silently sticking to its previous one
  // when the caller passed null.
  group('Plant.copyWith nullable-field sentinel', () {
    final original = fullPlant();

    void verifyNullableField<T>({
      required String fieldName,
      required T newValue,
      required Plant Function(Plant) clearer,
      required Plant Function(Plant) assigner,
      required T? Function(Plant) getter,
    }) {
      test('$fieldName: explicit null clears', () {
        final cleared = clearer(original);
        expect(getter(cleared), isNull,
            reason:
                '$fieldName was not cleared — sentinel may have regressed.');
      });
      test('$fieldName: non-null assignment replaces', () {
        final assigned = assigner(original);
        expect(getter(assigned), newValue);
      });
    }

    verifyNullableField<String>(
      fieldName: 'strainId',
      newValue: 'strain-2',
      clearer: (p) => p.copyWith(strainId: null),
      assigner: (p) => p.copyWith(strainId: 'strain-2'),
      getter: (p) => p.strainId,
    );

    verifyNullableField<DateTime>(
      fieldName: 'targetHarvestDate',
      newValue: DateTime.utc(2026, 9, 1),
      clearer: (p) => p.copyWith(targetHarvestDate: null),
      assigner: (p) =>
          p.copyWith(targetHarvestDate: DateTime.utc(2026, 9, 1)),
      getter: (p) => p.targetHarvestDate,
    );

    verifyNullableField<DateTime>(
      fieldName: 'harvestedDate',
      newValue: DateTime.utc(2026, 10, 1),
      clearer: (p) => p.copyWith(harvestedDate: null),
      assigner: (p) => p.copyWith(harvestedDate: DateTime.utc(2026, 10, 1)),
      getter: (p) => p.harvestedDate,
    );

    verifyNullableField<DateTime>(
      fieldName: 'dryingEndDate',
      newValue: DateTime.utc(2026, 10, 15),
      clearer: (p) => p.copyWith(dryingEndDate: null),
      assigner: (p) => p.copyWith(dryingEndDate: DateTime.utc(2026, 10, 15)),
      getter: (p) => p.dryingEndDate,
    );

    verifyNullableField<DateTime>(
      fieldName: 'curingEndDate',
      newValue: DateTime.utc(2026, 11, 15),
      clearer: (p) => p.copyWith(curingEndDate: null),
      assigner: (p) => p.copyWith(curingEndDate: DateTime.utc(2026, 11, 15)),
      getter: (p) => p.curingEndDate,
    );

    verifyNullableField<double>(
      fieldName: 'wetWeight',
      newValue: 250.0,
      clearer: (p) => p.copyWith(wetWeight: null),
      assigner: (p) => p.copyWith(wetWeight: 250.0),
      getter: (p) => p.wetWeight,
    );

    verifyNullableField<double>(
      fieldName: 'dryWeight',
      newValue: 80.0,
      clearer: (p) => p.copyWith(dryWeight: null),
      assigner: (p) => p.copyWith(dryWeight: 80.0),
      getter: (p) => p.dryWeight,
    );

    verifyNullableField<String>(
      fieldName: 'archiveReason',
      newValue: 'New reason',
      clearer: (p) => p.copyWith(archiveReason: null),
      assigner: (p) => p.copyWith(archiveReason: 'New reason'),
      getter: (p) => p.archiveReason,
    );

    verifyNullableField<DateTime>(
      fieldName: 'archivedAt',
      newValue: DateTime.utc(2026, 12, 1),
      clearer: (p) => p.copyWith(archivedAt: null),
      assigner: (p) => p.copyWith(archivedAt: DateTime.utc(2026, 12, 1)),
      getter: (p) => p.archivedAt,
    );

    verifyNullableField<TimeOfDay>(
      fieldName: 'burpingTime',
      newValue: const TimeOfDay(hour: 18, minute: 0),
      clearer: (p) => p.copyWith(burpingTime: null),
      assigner: (p) =>
          p.copyWith(burpingTime: const TimeOfDay(hour: 18, minute: 0)),
      getter: (p) => p.burpingTime,
    );

    verifyNullableField<GrowStage>(
      fieldName: 'growStage',
      newValue: GrowStage.flush,
      clearer: (p) => p.copyWith(growStage: null),
      assigner: (p) => p.copyWith(growStage: GrowStage.flush),
      getter: (p) => p.growStage,
    );

    verifyNullableField<DateTime>(
      fieldName: 'flipDate',
      newValue: DateTime.utc(2026, 4, 1),
      clearer: (p) => p.copyWith(flipDate: null),
      assigner: (p) => p.copyWith(flipDate: DateTime.utc(2026, 4, 1)),
      getter: (p) => p.flipDate,
    );

    verifyNullableField<String>(
      fieldName: 'medium',
      newValue: 'soil',
      clearer: (p) => p.copyWith(medium: null),
      assigner: (p) => p.copyWith(medium: 'soil'),
      getter: (p) => p.medium,
    );

    verifyNullableField<String>(
      fieldName: 'lightType',
      newValue: 'hps',
      clearer: (p) => p.copyWith(lightType: null),
      assigner: (p) => p.copyWith(lightType: 'hps'),
      getter: (p) => p.lightType,
    );

    verifyNullableField<String>(
      fieldName: 'phenotypeTag',
      newValue: 'Pheno #5',
      clearer: (p) => p.copyWith(phenotypeTag: null),
      assigner: (p) => p.copyWith(phenotypeTag: 'Pheno #5'),
      getter: (p) => p.phenotypeTag,
    );

    verifyNullableField<double>(
      fieldName: 'potSizeLitres',
      newValue: 15.0,
      clearer: (p) => p.copyWith(potSizeLitres: null),
      assigner: (p) => p.copyWith(potSizeLitres: 15.0),
      getter: (p) => p.potSizeLitres,
    );

    verifyNullableField<String>(
      fieldName: 'motherPlantId',
      newValue: 'mother-2',
      clearer: (p) => p.copyWith(motherPlantId: null),
      assigner: (p) => p.copyWith(motherPlantId: 'mother-2'),
      getter: (p) => p.motherPlantId,
    );

    verifyNullableField<double>(
      fieldName: 'latitude',
      newValue: 40.7128,
      clearer: (p) => p.copyWith(latitude: null),
      assigner: (p) => p.copyWith(latitude: 40.7128),
      getter: (p) => p.latitude,
    );

    verifyNullableField<double>(
      fieldName: 'longitude',
      newValue: -74.0060,
      clearer: (p) => p.copyWith(longitude: null),
      assigner: (p) => p.copyWith(longitude: -74.0060),
      getter: (p) => p.longitude,
    );

    verifyNullableField<String>(
      fieldName: 'locationLabel',
      newValue: 'Friend\'s allotment',
      clearer: (p) => p.copyWith(locationLabel: null),
      assigner: (p) => p.copyWith(locationLabel: 'Friend\'s allotment'),
      getter: (p) => p.locationLabel,
    );
  });

  group('Plant.copyWith partial updates', () {
    test('changing one nullable field does not nuke siblings', () {
      // Common-cause regression: an off-by-one in the sentinel could
      // make changes to one nullable also clear an adjacent one.
      // This guards against "I set growSpaceId and lost my phenotypeTag".
      final original = fullPlant();
      final copy = original.copyWith(growSpaceId: 'new-space');

      expect(copy.growSpaceId, 'new-space');
      expect(copy.phenotypeTag, original.phenotypeTag);
      expect(copy.medium, original.medium);
      expect(copy.lightType, original.lightType);
      expect(copy.motherPlantId, original.motherPlantId);
      expect(copy.flipDate, original.flipDate);
      expect(copy.harvestedDate, original.harvestedDate);
      expect(copy.dryWeight, original.dryWeight);
    });

    test('clearing one nullable does not clear adjacent ones', () {
      final original = fullPlant();
      final copy = original.copyWith(phenotypeTag: null);

      expect(copy.phenotypeTag, isNull);
      // Everything else stays put.
      expect(copy.medium, original.medium);
      expect(copy.lightType, original.lightType);
      expect(copy.potSizeLitres, original.potSizeLitres);
      expect(copy.motherPlantId, original.motherPlantId);
      expect(copy.strainId, original.strainId);
    });

    test('full archive flow: status + isArchived + archivedAt + reason', () {
      // Mirrors the production archive flow exactly.
      final original = fullPlant().copyWith(
        status: PlantStatus.growing,
        isArchived: false,
        archivedAt: null,
        archiveReason: null,
      );
      final at = DateTime.utc(2026, 8, 1);
      final archived = original.copyWith(
        status: PlantStatus.removed,
        isArchived: true,
        archivedAt: at,
        archiveReason: 'Powdery mildew',
      );

      expect(archived.status, PlantStatus.removed);
      expect(archived.isArchived, true);
      expect(archived.archivedAt, at);
      expect(archived.archiveReason, 'Powdery mildew');
      expect(archived.id, original.id); // identity preserved
    });
  });
}
