import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/main.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/repository/grow_repository.dart';
import 'package:kultivar/services/notification_service.dart';
import 'package:kultivar/workflows/plant_workflow_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a minimal growing-stage plant.
Plant _plant({
  String id = 'p1',
  PlantStatus status = PlantStatus.growing,
  DateTime? startDate,
  DateTime? harvestedDate,
  DateTime? dryingEndDate,
}) {
  return Plant(
    id: id,
    name: 'Test plant',
    strain: 'Test strain',
    growSpaceId: 'space-1',
    startDate: startDate ?? DateTime.utc(2026, 1, 1),
    status: status,
    harvestedDate: harvestedDate,
    dryingEndDate: dryingEndDate,
  );
}

void main() {
  // We need the test binding so SharedPreferences mocking + platform-
  // channel no-ops both work.  PlantWorkflowService passes through a
  // real NotificationService instance, but every notification-emitting
  // branch is conditional on the `KultivarApp.notif*Enabled` value
  // notifiers, which we flip to false in setUp.  Cancel calls still
  // fire on lifecycle exits — those hit `FlutterLocalNotificationsPlugin
  // .cancel(int)` which is a no-op under the test binding (the platform
  // channel has no handler bound, so the call returns null without
  // throwing).  The result: workflow tests exercise the repo state
  // machine without bringing any platform plugins into the loop.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    // Short-circuit NotificationService at the source — every
    // schedule / cancel call returns immediately without touching the
    // platform channel.  This is the @visibleForTesting flag on the
    // service itself; cleaner than registering mock handlers for the
    // half-dozen channels the plugin spans.
    NotificationService.stubAllCalls = true;

    // Disable every notification gate so schedule* branches inside the
    // workflow are also skipped (defence in depth — even if the flag
    // ever drifts, the gates keep the workflow side untouched).
    KultivarApp.notifDryingEnabled.value = false;
    KultivarApp.notifCuringEnabled.value = false;
    KultivarApp.notifBurpingEnabled.value = false;
    KultivarApp.notifEnvAlertsEnabled.value = false;
    KultivarApp.notifWateringEnabled.value = false;
    KultivarApp.notifFeedingEnabled.value = false;
    KultivarApp.notifIpmEnabled.value = false;
    KultivarApp.notifTargetHarvestEnabled.value = false;
  });

  tearDown(() {
    NotificationService.stubAllCalls = false;
  });

  group('harvestPlant', () {
    test('flips status to harvested and stamps the harvest date', () {
      final repo = GrowRepository();
      final p = _plant();
      repo.addPlant(p);

      final svc = PlantWorkflowService(repo, NotificationService());
      final harvestedAt = DateTime.utc(2026, 4, 1);
      svc.harvestPlant(plant: p, wetWeight: 120.5, harvestedDate: harvestedAt);

      final updated = repo.plants.firstWhere((x) => x.id == p.id);
      expect(updated.status, PlantStatus.harvested);
      expect(updated.harvestedDate, harvestedAt);
      expect(updated.wetWeight, 120.5);
    });

    test('creates a draft HarvestLog with the plant + strain stamped',
        () {
      final repo = GrowRepository();
      final p = _plant();
      repo.addPlant(p);

      final svc = PlantWorkflowService(repo, NotificationService());
      svc.harvestPlant(
          plant: p, wetWeight: 90.0, notes: 'Healthy trichomes.');

      expect(repo.harvestLogs, hasLength(1));
      final log = repo.harvestLogs.single;
      expect(log.plantId, p.id);
      expect(log.plantName, p.name);
      expect(log.strain, p.strain);
      expect(log.wetWeight, 90.0);
      expect(log.notes, 'Healthy trichomes.');
      // Draft state is the explicit "harvest exists but the user hasn't
      // confirmed the final dry weight yet" signal.  Lock it in.
      expect(log.isDraft, isTrue);
    });

    test('wet weight is optional', () {
      // Q37 — wet weight is optional in the harvest dialog.  The
      // workflow must accept null without losing the harvest log.
      final repo = GrowRepository();
      final p = _plant();
      repo.addPlant(p);

      final svc = PlantWorkflowService(repo, NotificationService());
      svc.harvestPlant(plant: p);

      expect(repo.plants.single.status, PlantStatus.harvested);
      expect(repo.plants.single.wetWeight, isNull);
      expect(repo.harvestLogs.single.wetWeight, isNull);
    });
  });

  group('startDrying', () {
    test('moves plant to drying status and records the end date', () {
      final repo = GrowRepository();
      final p = _plant(
        status: PlantStatus.harvested,
        harvestedDate: DateTime.utc(2026, 4, 1),
      );
      repo.addPlant(p);

      final svc = PlantWorkflowService(repo, NotificationService());
      final dryEnd = DateTime.utc(2026, 4, 11);
      svc.startDrying(plant: p, dryingEndDate: dryEnd);

      final updated = repo.plants.single;
      expect(updated.status, PlantStatus.drying);
      expect(updated.dryingEndDate, dryEnd);
    });
  });

  group('completeDrying', () {
    test('flips to curing, persists dry weight, and sets a 28-day cure',
        () {
      final repo = GrowRepository();
      final p = _plant(
        status: PlantStatus.drying,
        harvestedDate: DateTime.utc(2026, 4, 1),
        dryingEndDate: DateTime.utc(2026, 4, 11),
      );
      repo.addPlant(p);
      // Workflow updates the harvest log's dryWeight via
      // GrowRepository.updateHarvestDryWeight — seed a log first or the
      // update is a no-op.
      final svc = PlantWorkflowService(repo, NotificationService());
      svc.harvestPlant(
          plant: p,
          wetWeight: 100,
          harvestedDate: DateTime.utc(2026, 4, 1));
      // Re-fetch — harvestPlant flipped the plant to "harvested".
      final harvested = repo.plants.single;
      // Manually push it back to drying for the cure step.
      repo.updatePlant(harvested.copyWith(
        status: PlantStatus.drying,
        dryingEndDate: DateTime.utc(2026, 4, 11),
      ));

      final before = DateTime.now();
      svc.completeDrying(plant: repo.plants.single, dryWeight: 28.5);
      final after = DateTime.now();

      final cured = repo.plants.single;
      expect(cured.status, PlantStatus.curing);
      expect(cured.dryWeight, 28.5);

      // 28-day cure window — verify it's the documented duration
      // relative to a "now" sampled around the call.
      final expectedMin = before
          .add(const Duration(days: 28))
          .subtract(const Duration(seconds: 5));
      final expectedMax =
          after.add(const Duration(days: 28, seconds: 5));
      expect(cured.curingEndDate!.isAfter(expectedMin), isTrue);
      expect(cured.curingEndDate!.isBefore(expectedMax), isTrue);

      // Harvest log gets the dry weight written back.
      expect(repo.harvestLogs.single.dryWeight, 28.5);
    });

    test('burping reminder schedule is persisted on the plant', () {
      final repo = GrowRepository();
      final p = _plant(status: PlantStatus.drying);
      repo.addPlant(p);

      final svc = PlantWorkflowService(repo, NotificationService());
      svc.completeDrying(
        plant: p,
        dryWeight: 30,
        enableBurpingReminders: true,
        burpingSchedule: 'week2',
      );

      final cured = repo.plants.single;
      expect(cured.burpingRemindersEnabled, isTrue);
      expect(cured.burpingSchedule, 'week2');
    });
  });

  group('completeCure', () {
    test('archives the plant + marks it completed + finalises the log',
        () {
      final repo = GrowRepository();
      final p = _plant(status: PlantStatus.curing);
      repo.addPlant(p);
      // Seed a draft harvest log; completeCure should finalise it
      // (clear the isDraft flag).
      final svc = PlantWorkflowService(repo, NotificationService());
      svc.harvestPlant(plant: p, wetWeight: 110);
      expect(repo.harvestLogs.single.isDraft, isTrue);

      // Push the plant back to curing so completeCure has a valid
      // source state.
      repo.updatePlant(repo.plants.single
          .copyWith(status: PlantStatus.curing));

      final before = DateTime.now();
      svc.completeCure(repo.plants.single);
      final after = DateTime.now();

      final completed = repo.plants.single;
      expect(completed.status, PlantStatus.completed);
      expect(completed.isArchived, isTrue);
      expect(completed.archiveReason, contains('Curing'));
      expect(completed.archivedAt, isNotNull);
      expect(completed.archivedAt!.isAfter(
          before.subtract(const Duration(seconds: 5))), isTrue);
      expect(completed.archivedAt!.isBefore(
          after.add(const Duration(seconds: 5))), isTrue);

      // Harvest log is no longer a draft once curing is wrapped up.
      expect(repo.harvestLogs.single.isDraft, isFalse);
    });
  });

  group('removePlant', () {
    test('archives the plant with the supplied reason', () {
      final repo = GrowRepository();
      final p = _plant();
      repo.addPlant(p);

      final svc = PlantWorkflowService(repo, NotificationService());
      svc.removePlant(plant: p, reason: 'Suspected hermie');

      final removed = repo.plants.single;
      expect(removed.status, PlantStatus.removed);
      expect(removed.isArchived, isTrue);
      expect(removed.archiveReason, 'Suspected hermie');
      expect(removed.archivedAt, isNotNull);
    });
  });
}
