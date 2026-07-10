import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/config/subscription_tier_config.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/models/time_window.dart';
import 'package:kultivar/services/subscription_service.dart';

/// Builds a minimal plant; [archived] mirrors how the app archives —
/// completed and removed plants both carry isArchived: true.
Plant _plant({
  required String id,
  bool archived = false,
  PlantStatus status = PlantStatus.growing,
}) {
  return Plant(
    id: id,
    name: 'Plant $id',
    strain: 'Test strain',
    growSpaceId: 'space-1',
    startDate: DateTime.utc(2026, 1, 1),
    status: status,
    isArchived: archived,
    archivedAt: archived ? DateTime.utc(2026, 3, 1) : null,
  );
}

List<Plant> _active(int n) =>
    [for (var i = 0; i < n; i++) _plant(id: 'a$i')];

void main() {
  const free = SubscriptionTier.free;
  const lifetime = SubscriptionTier.lifetimeLocal;
  const pro = SubscriptionTier.proCloud;

  group('FreeTierGate.activePlantCount', () {
    test('counts only non-archived plants', () {
      final plants = [
        _plant(id: 'g1'),
        _plant(id: 'g2'),
        _plant(id: 'c1', archived: true, status: PlantStatus.completed),
        _plant(id: 'r1', archived: true, status: PlantStatus.removed),
      ];
      expect(FreeTierGate.activePlantCount(plants), 2);
    });

    test('empty list counts zero', () {
      expect(FreeTierGate.activePlantCount(const []), 0);
    });
  });

  group('FreeTierGate.canAddPlants', () {
    test('free can add up to the cap', () {
      expect(FreeTierGate.canAddPlants(free, _active(0)), isTrue);
      expect(FreeTierGate.canAddPlants(free, _active(2)), isTrue);
      expect(FreeTierGate.canAddPlants(free, _active(3)), isFalse);
    });

    test('free batch add must fit the remaining slots', () {
      final two = _active(2);
      expect(FreeTierGate.canAddPlants(free, two, count: 1), isTrue);
      expect(FreeTierGate.canAddPlants(free, two, count: 2), isFalse);
    });

    test('archived and completed plants free up slots', () {
      final plants = [
        ..._active(2),
        _plant(id: 'done', archived: true, status: PlantStatus.completed),
        _plant(id: 'culled', archived: true, status: PlantStatus.removed),
      ];
      expect(FreeTierGate.canAddPlants(free, plants), isTrue);
    });

    test('over-limit legacy data blocks new creates but nothing else', () {
      // A user who created 5 plants before the caps shipped: the gate
      // refuses a 6th, and there is deliberately no API here for
      // hiding or trimming the existing 5.
      final five = _active(5);
      expect(FreeTierGate.canAddPlants(free, five), isFalse);
      expect(FreeTierGate.activePlantCount(five), 5);
    });

    test('paid tiers are unlimited', () {
      expect(FreeTierGate.canAddPlants(lifetime, _active(50)), isTrue);
      expect(FreeTierGate.canAddPlants(pro, _active(50), count: 24), isTrue);
    });
  });

  group('FreeTierGate.atPlantCap', () {
    test('free flips at the cap and stays on past it', () {
      expect(FreeTierGate.atPlantCap(free, _active(2)), isFalse);
      expect(FreeTierGate.atPlantCap(free, _active(3)), isTrue);
      expect(FreeTierGate.atPlantCap(free, _active(5)), isTrue);
    });

    test('paid tiers are never at cap', () {
      expect(FreeTierGate.atPlantCap(lifetime, _active(50)), isFalse);
      expect(FreeTierGate.atPlantCap(pro, _active(50)), isFalse);
    });
  });

  group('FreeTierGate.canAddSpace', () {
    test('free allows the first space only', () {
      expect(FreeTierGate.canAddSpace(free, 0), isTrue);
      expect(FreeTierGate.canAddSpace(free, 1), isFalse);
      expect(FreeTierGate.canAddSpace(free, 3), isFalse);
    });

    test('paid tiers are unlimited', () {
      expect(FreeTierGate.canAddSpace(lifetime, 10), isTrue);
      expect(FreeTierGate.canAddSpace(pro, 10), isTrue);
    });
  });

  group('FreeTierGate.clampHistoryDays', () {
    const cap = 60; // FreeTierLimits.analyticsHistoryWindow

    test('free clamps all-time and wide windows to the cap', () {
      expect(FreeTierGate.clampHistoryDays(free, null), cap);
      expect(FreeTierGate.clampHistoryDays(free, -1), cap);
      expect(FreeTierGate.clampHistoryDays(free, 90), cap);
    });

    test('free passes windows inside the cap through', () {
      expect(FreeTierGate.clampHistoryDays(free, 7), 7);
      expect(FreeTierGate.clampHistoryDays(free, 30), 30);
      expect(FreeTierGate.clampHistoryDays(free, 60), 60);
    });

    test('paid tiers pass everything through', () {
      expect(FreeTierGate.clampHistoryDays(lifetime, null), isNull);
      expect(FreeTierGate.clampHistoryDays(pro, 90), 90);
    });
  });

  group('FreeTierGate.clampTimeWindow', () {
    test('free clamps all/90d down to the widest fitting preset', () {
      expect(FreeTierGate.clampTimeWindow(free, TimeWindow.all),
          TimeWindow.last60);
      expect(FreeTierGate.clampTimeWindow(free, TimeWindow.last90),
          TimeWindow.last60);
    });

    test('free keeps windows inside the cap', () {
      expect(FreeTierGate.clampTimeWindow(free, TimeWindow.last30),
          TimeWindow.last30);
      expect(FreeTierGate.clampTimeWindow(free, TimeWindow.last60),
          TimeWindow.last60);
    });

    test('paid tiers pass through unchanged', () {
      expect(FreeTierGate.clampTimeWindow(lifetime, TimeWindow.all),
          TimeWindow.all);
      expect(FreeTierGate.clampTimeWindow(pro, TimeWindow.last90),
          TimeWindow.last90);
    });
  });

  group('FreeTierGate.lockedTimeWindows', () {
    test('free locks exactly the presets wider than the cap', () {
      expect(FreeTierGate.lockedTimeWindows(free),
          {TimeWindow.last90, TimeWindow.all});
    });

    test('paid tiers lock nothing', () {
      expect(FreeTierGate.lockedTimeWindows(lifetime), isEmpty);
      expect(FreeTierGate.lockedTimeWindows(pro), isEmpty);
    });
  });

  group('Tier capability matrix (paywall promises)', () {
    test('strain comparison stays free — matrix lists it ✓ on every tier,'
        ' so no gate keys off hasUnlimitedFeatures for it', () {
      // Guards the FreeTierLimits doc comment: the strain library +
      // comparison tools are explicitly available on Free.
      expect(free.hasUnlimitedFeatures, isFalse);
      expect(lifetime.hasUnlimitedFeatures, isTrue);
      expect(pro.hasUnlimitedFeatures, isTrue);
    });

    test('community access is Pro Cloud only', () {
      expect(free.hasCommunityAccess, isFalse);
      expect(lifetime.hasCommunityAccess, isFalse);
      expect(pro.hasCommunityAccess, isTrue);
    });
  });
}
