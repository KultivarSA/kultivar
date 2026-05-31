import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/grow_expense.dart';
import 'package:kultivar/models/harvest_log.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/models/plant_note.dart';
import 'package:kultivar/repository/collections/expense_collection.dart';
import 'package:kultivar/repository/collections/harvest_collection.dart';
import 'package:kultivar/repository/collections/note_collection.dart';
import 'package:kultivar/repository/collections/plant_collection.dart';
import 'package:kultivar/repository/repo_types.dart';

// Helpers ─────────────────────────────────────────────────────────────────────

Plant _plant(String id, {String spaceId = 'space-1'}) => Plant(
      id: id,
      name: 'Plant $id',
      strain: 'Test strain',
      growSpaceId: spaceId,
      startDate: DateTime.utc(2026, 1, 1),
      status: PlantStatus.growing,
    );

PlantNote _note(
  String id, {
  required String plantId,
  required DateTime at,
  NoteCategory category = NoteCategory.observation,
  String content = '',
}) =>
    PlantNote(
      id: id,
      plantId: plantId,
      createdAt: at,
      content: content,
      category: category,
    );

GrowExpense _expense(
  String id, {
  String? plantId,
  String? spaceId,
  double amount = 10.0,
  DateTime? date,
}) =>
    GrowExpense(
      id: id,
      description: 'Receipt $id',
      amount: amount,
      date: date ?? DateTime.utc(2026, 3, 1),
      category: ExpenseCategory.nutrients,
      plantId: plantId,
      growSpaceId: spaceId,
    );

HarvestLog _harvest(
  String id, {
  required String plantId,
  double? dryWeight,
  bool isDraft = true,
}) =>
    HarvestLog(
      id: id,
      plantId: plantId,
      plantName: 'Plant $plantId',
      strain: 'Test strain',
      harvestedDate: DateTime.utc(2026, 4, 1),
      dryWeight: dryWeight,
      isDraft: isDraft,
    );

/// Captures every MarkDirty invocation so each test can assert which
/// [Coll] tag was raised — that's the dirty-tracking contract every
/// collection is required to honour.  Reset between tests via `clear()`.
class _MarkSpy {
  final List<Coll> calls = [];
  MarkDirty get fn => calls.add;
  void clear() => calls.clear();
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantCollection
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('PlantCollection', () {
    late _MarkSpy spy;
    late PlantCollection coll;

    setUp(() {
      spy = _MarkSpy();
      coll = PlantCollection(spy.fn);
    });

    test('add inserts the plant and marks dirty', () {
      coll.add(_plant('p1'));
      expect(coll.all.map((p) => p.id), ['p1']);
      expect(spy.calls, [Coll.plants]);
    });

    test('add returns an unmodifiable view', () {
      coll.add(_plant('p1'));
      expect(() => coll.all.add(_plant('p2')),
          throwsA(isA<UnsupportedError>()));
    });

    test('update replaces in place by id', () {
      coll.add(_plant('p1'));
      spy.clear();
      final renamed = _plant('p1').copyWith(name: 'Renamed');
      coll.update(renamed);
      expect(coll.all.single.name, 'Renamed');
      expect(spy.calls, [Coll.plants]);
    });

    test('update with an unknown id is a no-op', () {
      coll.add(_plant('p1'));
      spy.clear();
      coll.update(_plant('does-not-exist'));
      expect(coll.all.single.id, 'p1');
      // No-op = no dirty mark — otherwise the debounced flush wakes up
      // for nothing.
      expect(spy.calls, isEmpty);
    });

    test('plantById is O(1) and stays consistent with the list', () {
      coll.add(_plant('p1'));
      coll.add(_plant('p2'));
      expect(coll.plantById('p1')?.id, 'p1');
      expect(coll.plantById('p2')?.id, 'p2');
      expect(coll.plantById('missing'), isNull);
    });

    test(
        'byId map is rebuilt after add / update / removeById invalidates cache',
        () {
      coll.add(_plant('p1'));
      // Warm the cache.
      expect(coll.byId.containsKey('p1'), isTrue);

      coll.add(_plant('p2'));
      // If the cache wasn't invalidated, p2 would be missing here.
      expect(coll.byId.containsKey('p2'), isTrue);

      coll.removeById('p1');
      expect(coll.byId.containsKey('p1'), isFalse);

      // Update path: change name then look up by id; verifies cache
      // serves the latest object, not the stale one.
      coll.update(_plant('p2').copyWith(name: 'After-update'));
      expect(coll.plantById('p2')?.name, 'After-update');
    });

    test('removeById returns the removed plant and marks dirty', () {
      final p = _plant('p1');
      coll.add(p);
      spy.clear();
      final removed = coll.removeById('p1');
      expect(removed?.id, 'p1');
      expect(coll.all, isEmpty);
      expect(spy.calls, [Coll.plants]);
    });

    test('removeById on an unknown id returns null without marking dirty',
        () {
      coll.removeById('missing');
      expect(spy.calls, isEmpty);
    });

    test('replaceAll swaps the list AND invalidates the cache silently',
        () {
      coll.add(_plant('p1'));
      // Warm the cache, then bulk-replace.
      expect(coll.byId.containsKey('p1'), isTrue);
      spy.clear();

      coll.replaceAll([_plant('p2'), _plant('p3')]);
      expect(coll.all.map((p) => p.id), ['p2', 'p3']);
      // Old key must not survive in the cache.
      expect(coll.byId.containsKey('p1'), isFalse);
      expect(coll.byId.containsKey('p2'), isTrue);
      // replaceAll is meant for `load()` / `clearAllData` paths where
      // the parent repo issues a single notification — no dirty mark.
      expect(spy.calls, isEmpty);
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// NoteCollection
// ─────────────────────────────────────────────────────────────────────────────

  group('NoteCollection', () {
    late _MarkSpy spy;
    late NoteCollection coll;

    setUp(() {
      spy = _MarkSpy();
      coll = NoteCollection(spy.fn);
    });

    test('add inserts and marks dirty with Coll.notes', () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      expect(coll.all, hasLength(1));
      expect(spy.calls, [Coll.notes]);
    });

    test('notesForPlant defaults to newest-first', () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      coll.add(_note('n2', plantId: 'p1', at: DateTime.utc(2026, 3, 5)));
      coll.add(_note('n3', plantId: 'p1', at: DateTime.utc(2026, 3, 3)));

      final ids = coll.notesForPlant('p1').map((n) => n.id).toList();
      expect(ids, ['n2', 'n3', 'n1']);
    });

    test('notesForPlant ascending: true returns oldest-first', () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      coll.add(_note('n2', plantId: 'p1', at: DateTime.utc(2026, 3, 5)));

      final ids = coll
          .notesForPlant('p1', ascending: true)
          .map((n) => n.id)
          .toList();
      expect(ids, ['n1', 'n2']);
    });

    test('notesForPlant uses a stable id tiebreaker on identical dates',
        () {
      final t = DateTime.utc(2026, 3, 1);
      coll.add(_note('n2', plantId: 'p1', at: t));
      coll.add(_note('n1', plantId: 'p1', at: t));
      coll.add(_note('n3', plantId: 'p1', at: t));

      // Same timestamps → id ASC tiebreaker regardless of date order.
      expect(coll.notesForPlant('p1').map((n) => n.id), ['n1', 'n2', 'n3']);
      expect(coll.notesForPlant('p1', ascending: true).map((n) => n.id),
          ['n1', 'n2', 'n3']);
    });

    test('notesForPlant only returns notes for the requested plant', () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      coll.add(_note('n2', plantId: 'p2', at: DateTime.utc(2026, 3, 1)));
      expect(coll.notesForPlant('p1').map((n) => n.id), ['n1']);
      expect(coll.notesForPlant('p2').map((n) => n.id), ['n2']);
      expect(coll.notesForPlant('missing'), isEmpty);
    });

    test(
        'add invalidates only the affected plant\'s memoized note list',
        () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      coll.add(_note('n2', plantId: 'p2', at: DateTime.utc(2026, 3, 1)));

      // Warm both caches.
      final firstP1 = coll.notesForPlant('p1');
      final firstP2 = coll.notesForPlant('p2');

      // Add to p1 — p1's cache must reflect the new note, p2's must
      // still serve the warm result without re-filtering (identity).
      coll.add(_note('n3', plantId: 'p1', at: DateTime.utc(2026, 3, 5)));
      expect(coll.notesForPlant('p1').map((n) => n.id), ['n3', 'n1']);
      expect(identical(coll.notesForPlant('p2'), firstP2), isTrue,
          reason:
              'p2 cache must survive p1 mutations — otherwise every '
              'home rebuild thrashes both lists.');
      // firstP1 is a snapshot — it should NOT have grown.
      expect(firstP1.length, 1);
    });

    test('update invalidates the affected plant cache', () {
      coll.add(_note(
        'n1',
        plantId: 'p1',
        at: DateTime.utc(2026, 3, 1),
        content: 'Original',
      ));
      // Warm the cache.
      expect(coll.notesForPlant('p1').single.content, 'Original');

      coll.update(_note(
        'n1',
        plantId: 'p1',
        at: DateTime.utc(2026, 3, 1),
        content: 'Edited',
      ));
      expect(coll.notesForPlant('p1').single.content, 'Edited');
    });

    test('deleteById returns the removed note and removes it from views',
        () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      coll.add(_note('n2', plantId: 'p1', at: DateTime.utc(2026, 3, 2)));
      spy.clear();

      final removed = coll.deleteById('n1');
      expect(removed?.id, 'n1');
      expect(coll.notesForPlant('p1').map((n) => n.id), ['n2']);
      expect(spy.calls, [Coll.notes]);
    });

    test('deleteById on an unknown id returns null without marking dirty',
        () {
      expect(coll.deleteById('missing'), isNull);
      expect(spy.calls, isEmpty);
    });

    test('resolve flips isResolved and sets resolvedAt', () {
      coll.add(_note('n1',
          plantId: 'p1',
          at: DateTime.utc(2026, 3, 1),
          category: NoteCategory.issue));
      final at = DateTime.utc(2026, 3, 5);
      coll.resolve('n1', at: at);
      final n = coll.notesForPlant('p1').single;
      expect(n.isResolved, isTrue);
      expect(n.resolvedAt, at);
    });

    test('removeAllForPlant drops every note and marks dirty once', () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      coll.add(_note('n2', plantId: 'p1', at: DateTime.utc(2026, 3, 2)));
      coll.add(_note('n3', plantId: 'p2', at: DateTime.utc(2026, 3, 3)));
      spy.clear();

      final removed = coll.removeAllForPlant('p1');
      expect(removed.map((n) => n.id), containsAll(['n1', 'n2']));
      expect(coll.notesForPlant('p1'), isEmpty);
      expect(coll.notesForPlant('p2').map((n) => n.id), ['n3']);
      // Critically: ONE dirty mark for the batch, not two.
      expect(spy.calls, [Coll.notes]);
    });

    test('removeAllForPlant with no matches makes no notification', () {
      coll.add(_note('n1', plantId: 'p1', at: DateTime.utc(2026, 3, 1)));
      spy.clear();
      coll.removeAllForPlant('missing-plant');
      expect(spy.calls, isEmpty);
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// ExpenseCollection
// ─────────────────────────────────────────────────────────────────────────────

  group('ExpenseCollection', () {
    late _MarkSpy spy;
    late ExpenseCollection coll;

    setUp(() {
      spy = _MarkSpy();
      coll = ExpenseCollection(spy.fn);
    });

    test('add inserts and marks dirty', () {
      coll.add(_expense('x1', plantId: 'p1', amount: 5));
      expect(coll.all, hasLength(1));
      expect(spy.calls, [Coll.expenses]);
    });

    test('forPlant returns only the matching plant, newest-first', () {
      coll.add(_expense('x1',
          plantId: 'p1', date: DateTime.utc(2026, 3, 1)));
      coll.add(_expense('x2',
          plantId: 'p1', date: DateTime.utc(2026, 3, 10)));
      coll.add(_expense('x3',
          plantId: 'p2', date: DateTime.utc(2026, 3, 5)));

      expect(coll.forPlant('p1').map((e) => e.id), ['x2', 'x1']);
      expect(coll.forPlant('p2').map((e) => e.id), ['x3']);
    });

    test(
        'forSpace excludes plant-attributed expenses to avoid double-counting',
        () {
      // A space-only cost (e.g. electricity).
      coll.add(_expense('x1', spaceId: 'space-1', amount: 30));
      // A plant cost that also carries the space — this is the
      // common case for clones / nutrients bought for a plant in a
      // specific tent.  forSpace must NOT return it.
      coll.add(_expense('x2',
          spaceId: 'space-1', plantId: 'p1', amount: 5));

      expect(coll.forSpace('space-1').map((e) => e.id), ['x1']);
      expect(coll.forPlant('p1').map((e) => e.id), ['x2']);
    });

    test('totalForPlant sums every matching expense', () {
      coll.add(_expense('x1', plantId: 'p1', amount: 7.5));
      coll.add(_expense('x2', plantId: 'p1', amount: 12.25));
      coll.add(_expense('x3', plantId: 'p2', amount: 100));
      expect(coll.totalForPlant('p1'), closeTo(19.75, 1e-9));
    });

    test('costPerGram returns null when dry weight is missing or zero',
        () {
      coll.add(_expense('x1', plantId: 'p1', amount: 50));
      expect(coll.costPerGram('p1', null), isNull);
      expect(coll.costPerGram('p1', 0), isNull);
      expect(coll.costPerGram('p1', -1), isNull);
    });

    test('costPerGram returns null when the plant has no expenses', () {
      expect(coll.costPerGram('p1', 50), isNull);
    });

    test('costPerGram divides total by grams', () {
      coll.add(_expense('x1', plantId: 'p1', amount: 100));
      // 100 / 40 = 2.5
      expect(coll.costPerGram('p1', 40), 2.5);
    });

    test('total sums every expense regardless of attribution', () {
      coll.add(_expense('x1', amount: 10));
      coll.add(_expense('x2', plantId: 'p1', amount: 20));
      coll.add(_expense('x3', spaceId: 's1', amount: 30));
      expect(coll.total, 60);
    });

    test('update replaces in place; unknown id is a no-op', () {
      coll.add(_expense('x1', amount: 10));
      spy.clear();
      coll.update(_expense('x1', amount: 99));
      expect(coll.all.single.amount, 99);
      expect(spy.calls, [Coll.expenses]);

      spy.clear();
      coll.update(_expense('missing', amount: 1));
      expect(spy.calls, isEmpty);
    });

    test('deleteById drops the expense and marks dirty', () {
      coll.add(_expense('x1'));
      coll.add(_expense('x2'));
      spy.clear();
      coll.deleteById('x1');
      expect(coll.all.map((e) => e.id), ['x2']);
      expect(spy.calls, [Coll.expenses]);
    });

    test('removeAllForPlant cascades + marks dirty once for the batch',
        () {
      coll.add(_expense('x1', plantId: 'p1'));
      coll.add(_expense('x2', plantId: 'p1'));
      coll.add(_expense('x3', plantId: 'p2'));
      spy.clear();

      final removed = coll.removeAllForPlant('p1');
      expect(removed.map((e) => e.id), containsAll(['x1', 'x2']));
      expect(coll.forPlant('p1'), isEmpty);
      expect(coll.forPlant('p2').map((e) => e.id), ['x3']);
      expect(spy.calls, [Coll.expenses]);
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// HarvestCollection
// ─────────────────────────────────────────────────────────────────────────────

  group('HarvestCollection', () {
    late _MarkSpy spy;
    late HarvestCollection coll;

    setUp(() {
      spy = _MarkSpy();
      coll = HarvestCollection(spy.fn);
    });

    test('add inserts and marks dirty with Coll.harvestLogs', () {
      coll.add(_harvest('h1', plantId: 'p1'));
      expect(coll.all, hasLength(1));
      expect(spy.calls, [Coll.harvestLogs]);
    });

    test('readd inserts WITHOUT going through the "first harvest" path',
        () {
      // Contract: readd is just an add that the streak engine shouldn't
      // re-count.  At the collection layer we can only verify it lands
      // in the list and marks dirty — the streak side-effect is owned
      // by GrowRepository.
      coll.readd(_harvest('h1', plantId: 'p1'));
      expect(coll.all, hasLength(1));
      expect(spy.calls, [Coll.harvestLogs]);
    });

    test('updateDryWeight rewrites dryWeight on the matching plant', () {
      coll.add(_harvest('h1', plantId: 'p1'));
      spy.clear();
      coll.updateDryWeight('p1', 42.5);
      expect(coll.all.single.dryWeight, 42.5);
      expect(spy.calls, [Coll.harvestLogs]);
    });

    test('updateDryWeight on an unknown plant is a no-op', () {
      coll.add(_harvest('h1', plantId: 'p1'));
      spy.clear();
      coll.updateDryWeight('missing-plant', 99);
      expect(coll.all.single.dryWeight, isNull);
      expect(spy.calls, isEmpty);
    });

    test('finalize flips isDraft from true to false', () {
      coll.add(_harvest('h1', plantId: 'p1', isDraft: true));
      spy.clear();
      coll.finalize('p1');
      expect(coll.all.single.isDraft, isFalse);
      expect(spy.calls, [Coll.harvestLogs]);
    });

    test('finalize on a non-existent plant is a no-op', () {
      coll.finalize('missing');
      expect(spy.calls, isEmpty);
    });

    test('updateQuality sets ratings + tasting notes', () {
      coll.add(_harvest('h1', plantId: 'p1'));
      spy.clear();
      coll.updateQuality(
        harvestLogId: 'h1',
        qualityRating: 4.5,
        aromaNote: 'Citrus',
        flavorNotes: 'Sweet',
        effectNotes: 'Cerebral',
        smellRating: 4,
        effectRating: 5,
        bagAppealRating: 4.5,
      );
      final log = coll.all.single;
      expect(log.qualityRating, 4.5);
      expect(log.aromaNote, 'Citrus');
      expect(log.flavorNotes, 'Sweet');
      expect(log.effectNotes, 'Cerebral');
      expect(log.smellRating, 4);
      expect(log.effectRating, 5);
      expect(log.bagAppealRating, 4.5);
      expect(spy.calls, [Coll.harvestLogs]);
    });

    test('updateQuality on a missing log id is a no-op', () {
      coll.updateQuality(harvestLogId: 'nope', qualityRating: 5);
      expect(spy.calls, isEmpty);
    });

    test('removeAllForPlant cascades + marks dirty once', () {
      coll.add(_harvest('h1', plantId: 'p1'));
      coll.add(_harvest('h2', plantId: 'p1'));
      coll.add(_harvest('h3', plantId: 'p2'));
      spy.clear();

      final removed = coll.removeAllForPlant('p1');
      expect(removed.map((l) => l.id), containsAll(['h1', 'h2']));
      expect(coll.all.map((l) => l.id), ['h3']);
      expect(spy.calls, [Coll.harvestLogs]);
    });

    test('removeAllForPlant with no matches makes no notification', () {
      coll.add(_harvest('h1', plantId: 'p1'));
      spy.clear();
      coll.removeAllForPlant('missing-plant');
      expect(spy.calls, isEmpty);
    });
  });
}
