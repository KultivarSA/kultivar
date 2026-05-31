import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/grow_expense.dart';
import 'package:kultivar/models/grow_space.dart';
import 'package:kultivar/models/harvest_log.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/models/plant_note.dart';
import 'package:kultivar/repository/grow_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper: build a minimal valid Plant.
Plant _plant(
  String id, {
  String name = 'Test plant',
  String strain = 'Test strain',
  String growSpaceId = 'space-1',
  PlantStatus status = PlantStatus.growing,
}) {
  return Plant(
    id: id,
    name: name,
    strain: strain,
    growSpaceId: growSpaceId,
    startDate: DateTime.utc(2026, 1, 1),
    status: status,
  );
}

void main() {
  // Repository writes through SharedPreferences (via StorageService) when
  // its 300ms debounce fires.  We never pump that timer in these tests, so
  // mutations only touch in-memory state — but we still need the mocked
  // prefs so the streak-update path doesn't fail.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Plants CRUD', () {
    test('addPlant appends to the plants list', () {
      final repo = GrowRepository();
      expect(repo.plants, isEmpty);
      repo.addPlant(_plant('p1'));
      expect(repo.plants.length, 1);
      expect(repo.plants.first.id, 'p1');
    });

    test('updatePlant replaces the plant in place', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1', name: 'Original'));
      repo.updatePlant(_plant('p1', name: 'Renamed'));
      expect(repo.plants.length, 1);
      expect(repo.plants.first.name, 'Renamed');
    });

    test('updatePlant on a missing ID is a no-op', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));
      repo.updatePlant(_plant('p-does-not-exist'));
      expect(repo.plants.length, 1);
      expect(repo.plants.first.id, 'p1');
    });

    test('deletePlant removes the plant and its notes & harvest logs', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));
      repo.addPlant(_plant('p2'));
      repo.addNote(PlantNote(
        id: 'n1',
        plantId: 'p1',
        createdAt: DateTime.utc(2026, 2, 1),
        category: NoteCategory.observation,
        content: 'Looking healthy',
      ));
      repo.addNote(PlantNote(
        id: 'n2',
        plantId: 'p2',
        createdAt: DateTime.utc(2026, 2, 1),
        category: NoteCategory.observation,
        content: 'Different plant',
      ));
      repo.addHarvestLog(HarvestLog(
        id: 'h1',
        plantId: 'p1',
        plantName: 'Test plant',
        strain: 'Test strain',
        harvestedDate: DateTime.utc(2026, 5, 1),
        dryWeight: 50,
      ));

      repo.deletePlant('p1');

      expect(repo.plants.map((p) => p.id), ['p2']);
      // p1's note should be gone, p2's preserved.
      expect(repo.notes.map((n) => n.id), ['n2']);
      // p1's harvest log gone.
      expect(repo.harvestLogs, isEmpty);
    });
  });

  group('Spaces CRUD', () {
    test('addGrowSpace appends and is immutable from outside', () {
      final repo = GrowRepository();
      repo.addGrowSpace(const GrowSpace(
        id: 's1',
        name: 'Veg tent',
        type: 'Tent',
      ));
      expect(repo.growSpaces.length, 1);

      // Returned list is unmodifiable.
      expect(
        () => repo.growSpaces.add(const GrowSpace(
          id: 's2',
          name: 'Should not work',
          type: 'Tent',
        )),
        throwsUnsupportedError,
      );
    });
  });

  group('Expenses CRUD + cost-per-gram', () {
    final today = DateTime.utc(2026, 3, 1);

    test('totalCostForPlant sums attributed expenses', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));

      repo.addExpense(GrowExpense(
        id: 'e1',
        plantId: 'p1',
        date: today,
        category: ExpenseCategory.seeds,
        description: 'Seeds',
        amount: 30.0,
      ));
      repo.addExpense(GrowExpense(
        id: 'e2',
        plantId: 'p1',
        date: today,
        category: ExpenseCategory.nutrients,
        description: 'Nutrient kit',
        amount: 45.50,
      ));
      // Space-level — not attributed to p1.
      repo.addExpense(GrowExpense(
        id: 'e3',
        plantId: null,
        date: today,
        category: ExpenseCategory.electricity,
        description: 'Power',
        amount: 80.0,
      ));

      expect(repo.totalCostForPlant('p1'), 75.50);
      expect(repo.totalExpenditure, closeTo(155.50, 0.001));
    });

    test('costPerGram returns null when no dry weight or no expenses', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));
      // No expenses yet.
      expect(repo.costPerGram('p1', 50), isNull);

      repo.addExpense(GrowExpense(
        id: 'e1',
        plantId: 'p1',
        date: today,
        category: ExpenseCategory.seeds,
        description: 'Seeds',
        amount: 30,
      ));
      // No dry weight.
      expect(repo.costPerGram('p1', null), isNull);
      expect(repo.costPerGram('p1', 0), isNull);
    });

    test('costPerGram computes total / dry weight', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));
      repo.addExpense(GrowExpense(
        id: 'e1',
        plantId: 'p1',
        date: today,
        category: ExpenseCategory.nutrients,
        description: 'Feed',
        amount: 100.0,
      ));
      expect(repo.costPerGram('p1', 50.0), 2.0); // £100 / 50g
    });

    test('deleteExpense removes only the matching entry', () {
      final repo = GrowRepository();
      repo.addExpense(GrowExpense(
        id: 'e1',
        date: today,
        category: ExpenseCategory.seeds,
        description: 'A',
        amount: 10,
      ));
      repo.addExpense(GrowExpense(
        id: 'e2',
        date: today,
        category: ExpenseCategory.nutrients,
        description: 'B',
        amount: 20,
      ));
      repo.deleteExpense('e1');
      expect(repo.expenses.map((e) => e.id), ['e2']);
    });

    test('expensesForPlant returns newest first', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));
      repo.addExpense(GrowExpense(
        id: 'old',
        plantId: 'p1',
        date: DateTime.utc(2026, 1, 1),
        category: ExpenseCategory.seeds,
        description: 'Old',
        amount: 1,
      ));
      repo.addExpense(GrowExpense(
        id: 'new',
        plantId: 'p1',
        date: DateTime.utc(2026, 3, 1),
        category: ExpenseCategory.seeds,
        description: 'New',
        amount: 1,
      ));
      expect(repo.expensesForPlant('p1').map((e) => e.id),
          ['new', 'old']);
    });
  });

  group('newId', () {
    test('produces distinct IDs', () {
      final repo = GrowRepository();
      final ids = List.generate(50, (_) => repo.newId()).toSet();
      expect(ids.length, 50);
    });
  });

  // ── Soft-delete + Undo (B9) ──────────────────────────────────────────────

  group('softDeletePlant / restoreDeletedPlant', () {
    final today = DateTime.utc(2026, 3, 1);

    test('returns null for unknown plant ID', () {
      final repo = GrowRepository();
      expect(repo.softDeletePlant('nope'), isNull);
    });

    test('snapshot captures plant + notes + harvest + expenses', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1', name: 'Original'));
      repo.addNote(PlantNote(
        id: 'n1',
        plantId: 'p1',
        createdAt: today,
        category: NoteCategory.observation,
        content: 'Looking good',
      ));
      repo.addHarvestLog(HarvestLog(
        id: 'h1',
        plantId: 'p1',
        plantName: 'Original',
        strain: 'Test strain',
        harvestedDate: today,
        dryWeight: 30,
      ));
      repo.addExpense(GrowExpense(
        id: 'e1',
        plantId: 'p1',
        date: today,
        category: ExpenseCategory.seeds,
        description: 'Seeds',
        amount: 25,
      ));

      final snap = repo.softDeletePlant('p1');
      expect(snap, isNotNull);
      expect(snap!.plant.id, 'p1');
      expect(snap.notes.length, 1);
      expect(snap.notes.first.id, 'n1');
      expect(snap.harvestLogs.length, 1);
      expect(snap.expenses.length, 1);

      // Repo state cleared.
      expect(repo.plants, isEmpty);
      expect(repo.notes, isEmpty);
      expect(repo.harvestLogs, isEmpty);
      expect(repo.expenses, isEmpty);
    });

    test('restoreDeletedPlant puts everything back', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1', name: 'Original'));
      repo.addNote(PlantNote(
        id: 'n1',
        plantId: 'p1',
        createdAt: today,
        category: NoteCategory.observation,
        content: 'Note A',
      ));
      repo.addExpense(GrowExpense(
        id: 'e1',
        plantId: 'p1',
        date: today,
        category: ExpenseCategory.seeds,
        description: 'Seeds',
        amount: 25,
      ));

      final snap = repo.softDeletePlant('p1')!;
      repo.restoreDeletedPlant(snap);

      expect(repo.plants.length, 1);
      expect(repo.plants.first.id, 'p1');
      expect(repo.notes.length, 1);
      expect(repo.expenses.length, 1);
    });

    test('softDelete + restore is a no-op end-to-end', () {
      final repo = GrowRepository();
      // Add 3 plants, mutate, restore the middle one.
      repo.addPlant(_plant('p1'));
      repo.addPlant(_plant('p2'));
      repo.addPlant(_plant('p3'));

      final snap = repo.softDeletePlant('p2')!;
      expect(repo.plants.map((p) => p.id).toSet(), {'p1', 'p3'});

      repo.restoreDeletedPlant(snap);
      expect(repo.plants.map((p) => p.id).toSet(), {'p1', 'p2', 'p3'});
    });

    test('does not affect siblings\' data', () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));
      repo.addPlant(_plant('p2'));
      repo.addNote(PlantNote(
        id: 'n-p1',
        plantId: 'p1',
        createdAt: today,
        category: NoteCategory.observation,
        content: 'For p1',
      ));
      repo.addNote(PlantNote(
        id: 'n-p2',
        plantId: 'p2',
        createdAt: today,
        category: NoteCategory.observation,
        content: 'For p2',
      ));

      repo.softDeletePlant('p1');
      // p2 and its note untouched.
      expect(repo.plants.single.id, 'p2');
      expect(repo.notes.single.id, 'n-p2');
    });

    test('commitDeletedPlant is idempotent / safe to call without files',
        () {
      final repo = GrowRepository();
      repo.addPlant(_plant('p1'));
      repo.addNote(PlantNote(
        id: 'n1',
        plantId: 'p1',
        createdAt: today,
        category: NoteCategory.observation,
        content: 'No attachments',
        // photoUrls defaults to []
      ));

      final snap = repo.softDeletePlant('p1')!;
      // Empty photoUrls + commit should be a no-op rather than throwing.
      expect(() => repo.commitDeletedPlant(snap), returnsNormally);
      expect(() => repo.commitDeletedPlant(snap), returnsNormally);
    });
  });

  group('load() race-condition guard (onboarding bug)', () {
    test(
        'initial load() does NOT clobber in-memory writes added before it '
        'completes', () async {
      // Simulates the onboarding race: the user added a space and a plant
      // via addGrowSpace / addPlant BEFORE the async initial load()
      // completed.  Without the guard, replaceAll(...) from load() would
      // wipe both — destroying the space and orphaning the plant.
      final repo = GrowRepository();
      repo.addGrowSpace(const GrowSpace(id: 'space-1', name: 'Tent', type: 'Indoor'));
      repo.addPlant(_plant('p1', growSpaceId: 'space-1'));

      // Now the initial load() races in — disk is empty (fresh install).
      await repo.load();

      // The user's writes must survive.
      expect(repo.growSpaces.length, 1,
          reason: 'space added during onboarding must not be wiped');
      expect(repo.growSpaces.first.id, 'space-1');
      expect(repo.plants.length, 1,
          reason: 'plant added during onboarding must not be orphaned');
      expect(repo.plants.first.growSpaceId, 'space-1');
    });

    test('subsequent load() after initial DOES overwrite (demo seed path)',
        () async {
      // Demo seed + backup restore both call load() explicitly *after*
      // initial setup, expecting the in-memory state to be replaced with
      // whatever is on disk.  The guard only fires on the *initial* load.
      final repo = GrowRepository();
      await repo.load(); // initial load — disk empty, ends with empty state
      expect(repo.plants, isEmpty);

      // User somehow added in-memory data after initial load completed.
      repo.addGrowSpace(const GrowSpace(id: 's', name: 'X', type: 'Indoor'));
      repo.addPlant(_plant('p1'));
      expect(repo.plants.length, 1);

      // Subsequent explicit load() — disk is still empty.  Now the guard
      // is OFF (initial load already done), so replaceAll fires and wipes.
      await repo.load();
      expect(repo.plants, isEmpty,
          reason:
              'subsequent loads (demo seed, backup restore) must clobber '
              'in-memory state as designed');
      expect(repo.growSpaces, isEmpty);
    });
  });
}
