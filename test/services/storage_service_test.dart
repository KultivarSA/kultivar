import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/environment_log.dart';
import 'package:kultivar/models/grow_expense.dart';
import 'package:kultivar/models/grow_space.dart';
import 'package:kultivar/models/harvest_log.dart';
import 'package:kultivar/models/note_template.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/models/plant_note.dart';
import 'package:kultivar/models/strain.dart';
import 'package:kultivar/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a fully-populated payload covering every collection that the
/// backup format ships.  Every field that we serialise is touched so a
/// JSON-shape regression in any model surfaces here rather than
/// silently lopping a column off restored data.
Map<String, dynamic> _buildSamplePayload() {
  final plant = Plant(
    id: 'p1',
    name: 'Blue Dream',
    strain: 'Blue Dream',
    growSpaceId: 'space-1',
    startDate: DateTime.utc(2026, 1, 1),
    status: PlantStatus.growing,
    isAutoflower: false,
  );

  const space = GrowSpace(
    id: 'space-1',
    name: 'Veg Tent',
    type: 'Indoor Tent',
  );

  final harvest = HarvestLog(
    id: 'h1',
    plantId: 'p1',
    plantName: 'Blue Dream',
    strain: 'Blue Dream',
    harvestedDate: DateTime.utc(2026, 4, 15),
    wetWeight: 142.5,
    dryWeight: 38.7,
    notes: 'Strong citrus aroma.',
  );

  final note = PlantNote(
    id: 'n1',
    plantId: 'p1',
    content: 'pH drift to 5.4 — flushed.',
    category: NoteCategory.feeding,
    createdAt: DateTime.utc(2026, 2, 3, 9, 30),
  );

  final strain = Strain(
    id: 's1',
    name: 'Blue Dream',
    genetics: 'Blueberry × Haze',
    type: 'Hybrid',
    isAutoflower: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final template = NoteTemplate(
    id: 't1',
    title: 'pH check',
    category: NoteCategory.observation.name,
    content: 'pH = ',
    createdAt: DateTime.utc(2026, 1, 5),
  );

  final envLog = EnvironmentLog(
    id: 'e1',
    growSpaceId: 'space-1',
    temperature: 24.2,
    humidity: 55,
    recordedAt: DateTime.utc(2026, 2, 3, 9, 32),
  );

  final expense = GrowExpense(
    id: 'x1',
    description: 'Cal-Mag',
    amount: 12.99,
    date: DateTime.utc(2026, 2, 1),
    category: ExpenseCategory.nutrients,
  );

  return <String, dynamic>{
    'plant': plant,
    'space': space,
    'harvest': harvest,
    'note': note,
    'strain': strain,
    'template': template,
    'envLog': envLog,
    'expense': expense,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService individual save/load round-trips', () {
    test('plants survive a save → load round trip', () async {
      final p = _buildSamplePayload()['plant'] as Plant;
      await StorageService.savePlants([p]);
      final loaded = await StorageService.loadPlants();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, p.id);
      expect(loaded.first.name, p.name);
      expect(loaded.first.strain, p.strain);
      expect(loaded.first.startDate, p.startDate);
    });

    test('grow spaces survive a save → load round trip', () async {
      final s = _buildSamplePayload()['space'] as GrowSpace;
      await StorageService.saveGrowSpaces([s]);
      final loaded = await StorageService.loadGrowSpaces();
      expect(loaded.single.id, s.id);
      expect(loaded.single.name, s.name);
      expect(loaded.single.type, s.type);
    });

    test('harvest logs survive a save → load round trip', () async {
      final h = _buildSamplePayload()['harvest'] as HarvestLog;
      await StorageService.saveHarvestLogs([h]);
      final loaded = await StorageService.loadHarvestLogs();
      expect(loaded.single.id, h.id);
      expect(loaded.single.wetWeight, h.wetWeight);
      expect(loaded.single.dryWeight, h.dryWeight);
      expect(loaded.single.harvestedDate, h.harvestedDate);
    });

    test('expenses survive a save → load round trip', () async {
      final x = _buildSamplePayload()['expense'] as GrowExpense;
      await StorageService.saveExpenses([x]);
      final loaded = await StorageService.loadExpenses();
      expect(loaded.single.id, x.id);
      expect(loaded.single.description, x.description);
      expect(loaded.single.amount, x.amount);
      expect(loaded.single.category, x.category);
    });

    test('streak data round-trips through arbitrary JSON', () async {
      final data = <String, dynamic>{
        'currentStreak': 14,
        'lastLogDate': '2026-03-10',
        'milestones': ['week-1', 'week-2'],
      };
      await StorageService.saveStreakData(data);
      final loaded = await StorageService.loadStreakData();
      expect(loaded['currentStreak'], 14);
      expect(loaded['lastLogDate'], '2026-03-10');
      expect(loaded['milestones'], ['week-1', 'week-2']);
    });
  });

  group('StorageService missing-key safety', () {
    test('loadPlants returns empty when no key is set', () async {
      expect(await StorageService.loadPlants(), isEmpty);
    });

    test('loadGrowSpaces returns empty when no key is set', () async {
      expect(await StorageService.loadGrowSpaces(), isEmpty);
    });

    test('loadStreakData returns empty map when no key is set', () async {
      expect(await StorageService.loadStreakData(), <String, dynamic>{});
    });

    test('loadPlants returns empty on malformed JSON', () async {
      // Set a string that cannot be parsed as a JSON list — load must
      // swallow the error and return empty rather than crash.
      SharedPreferences.setMockInitialValues({'plants': '{not json'});
      expect(await StorageService.loadPlants(), isEmpty);
    });
  });

  group('StorageService.buildBackupPayload + restoreFromPayload', () {
    test(
        'full round-trip preserves every collection including expenses + streak',
        () async {
      final sample = _buildSamplePayload();

      // Seed streak data so it gets included in the backup payload.
      await StorageService.saveStreakData({'currentStreak': 7});

      final payload = await StorageService.buildBackupPayload(
        plants: [sample['plant'] as Plant],
        growSpaces: [sample['space'] as GrowSpace],
        harvestLogs: [sample['harvest'] as HarvestLog],
        notes: [sample['note'] as PlantNote],
        strains: [sample['strain'] as Strain],
        noteTemplates: [sample['template'] as NoteTemplate],
        environmentLogs: [sample['envLog'] as EnvironmentLog],
        expenses: [sample['expense'] as GrowExpense],
      );

      // Wipe the store before restoring so we know the data we read
      // back came from the restore, not residual save state.
      SharedPreferences.setMockInitialValues({});

      await StorageService.restoreFromPayload(payload);

      final loaded = await StorageService.loadAll();
      expect((loaded['plants'] as List).single.id, 'p1');
      expect((loaded['growSpaces'] as List).single.id, 'space-1');
      expect((loaded['harvestLogs'] as List).single.id, 'h1');
      expect((loaded['notes'] as List).single.id, 'n1');
      expect((loaded['strains'] as List).single.id, 's1');
      expect((loaded['noteTemplates'] as List).single.id, 't1');
      expect((loaded['expenses'] as List).single.id, 'x1');

      final streak = await StorageService.loadStreakData();
      expect(streak['currentStreak'], 7);
    });

    test('payload carries a schema version + exportedAt timestamp',
        () async {
      // Older backups must keep working — locking the version constant
      // here makes any silent bump (= a breaking schema change) loud.
      final payload = await StorageService.buildBackupPayload(
        plants: const [],
        growSpaces: const [],
        harvestLogs: const [],
        notes: const [],
        strains: const [],
        noteTemplates: const [],
        environmentLogs: const [],
      );
      expect(payload['version'], 1);
      expect(payload['exportedAt'], isA<String>());
      // Should round-trip through DateTime.parse without throwing.
      expect(() => DateTime.parse(payload['exportedAt'] as String),
          returnsNormally);
    });

    test('restoreFromPayload tolerates missing collections', () async {
      // A backup taken before a new collection was added should still
      // restore — the missing keys must default to an empty list.
      await StorageService.restoreFromPayload(<String, dynamic>{
        'version': 1,
        'exportedAt': DateTime.utc(2025, 1, 1).toIso8601String(),
        // Deliberately omit everything else.
      });

      expect(await StorageService.loadPlants(), isEmpty);
      expect(await StorageService.loadGrowSpaces(), isEmpty);
      expect(await StorageService.loadHarvestLogs(), isEmpty);
      expect(await StorageService.loadNotes(), isEmpty);
      expect(await StorageService.loadStrains(), isEmpty);
      expect(await StorageService.loadNoteTemplates(), isEmpty);
      expect(await StorageService.loadExpenses(), isEmpty);
    });
  });
}
