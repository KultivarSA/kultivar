import '../../models/plant.dart';
import '../repo_types.dart';

/// Q1b — Per-collection sub-controller owned by [GrowRepository].
///
/// Holds the in-memory plant list and the O(1) by-id cache.  All
/// mutations end with `_mark(Coll.plants)` (the [MarkDirty] callback
/// supplied by the parent), which is what triggers the debounced
/// SharedPreferences flush and `notifyListeners()`.
///
/// The class is intentionally not a `ChangeNotifier` — keeping the
/// `Listenable` contract on a single object ([GrowRepository]) means
/// existing widgets that `context.watch<GrowRepository>()` keep
/// working unchanged.
class PlantCollection {
  PlantCollection(this._mark);

  final MarkDirty _mark;

  /// Backing list — direct mutation outside this class is allowed only
  /// for the cross-cutting operations on [GrowRepository] (cascade
  /// deletes, backup restore, etc.) via [rawListForBatch].  In normal
  /// flow, callers should go through the public methods so caches and
  /// dirty marking are handled correctly.
  final List<Plant> _plants = [];

  // ── by-ID cache (P3) ──────────────────────────
  //
  // Hot lookups like "find the harvest's plant" (dashboard) and
  // "find the open-issues plant" (banner) used to do a linear scan
  // over [_plants] per item.  This map turns those into O(1) reads.
  // Invalidated on every list mutation.
  Map<String, Plant>? _byIdCache;

  void _invalidateCache() => _byIdCache = null;

  // ── Read-only views ───────────────────────────

  List<Plant> get all => List.unmodifiable(_plants);

  /// O(1) lookup by plant ID.  Returns null when the ID is unknown.
  Plant? plantById(String id) {
    final cache = _byIdCache ??= {
      for (final p in _plants) p.id: p,
    };
    return cache[id];
  }

  /// Read-only map view of plants keyed by ID.  Useful when a caller
  /// needs many lookups in one render pass — building the map once and
  /// reading it N times is cheaper than calling [plantById] N times if
  /// the cache wasn't already warm.
  Map<String, Plant> get byId {
    return _byIdCache ??= {
      for (final p in _plants) p.id: p,
    };
  }

  // ── Mutations ─────────────────────────────────

  void add(Plant plant) {
    _plants.add(plant);
    _invalidateCache();
    _mark(Coll.plants);
  }

  void update(Plant updated) {
    final i = _plants.indexWhere((p) => p.id == updated.id);
    if (i == -1) return;
    _plants[i] = updated;
    _invalidateCache();
    _mark(Coll.plants);
  }

  /// Removes the plant with [id] from the list.  Returns the removed
  /// plant for callers that need to capture it (e.g. soft-delete
  /// snapshots), or `null` if no such plant exists.
  ///
  /// Does **not** cascade to notes/harvests/expenses — that's the
  /// parent repo's responsibility.
  Plant? removeById(String id) {
    final i = _plants.indexWhere((p) => p.id == id);
    if (i == -1) return null;
    final removed = _plants.removeAt(i);
    _invalidateCache();
    _mark(Coll.plants);
    return removed;
  }

  // ── Cross-cutting access ──────────────────────
  //
  // Used by [GrowRepository] for batch operations that intentionally
  // skip the [_mark] step (e.g. `clearAllData` clears every collection
  // then issues a single notify, and `load()` populates the list in
  // bulk from disk).  Direct mutators should call [markDirty] and
  // [invalidateCache] themselves when done.

  /// Direct list reference for batch read/write inside the parent
  /// repository.  External callers must invoke [markDirty] +
  /// [invalidateCache] after mutating it.
  List<Plant> get rawListForBatch => _plants;

  /// Replaces the entire backing list — used by [GrowRepository.load]
  /// and `clearAllData`.  Cache is cleared but no dirty notification
  /// is fired (the parent handles that for the full reload path).
  void replaceAll(List<Plant> next) {
    _plants
      ..clear()
      ..addAll(next);
    _invalidateCache();
  }

  void invalidateCache() => _invalidateCache();

  /// Imperatively mark the collection dirty without performing a
  /// mutation.  Used by [GrowRepository] when it touches the raw list
  /// directly inside a multi-collection operation (e.g. cascading a
  /// grow-space deletion to plant archive flags).
  void markDirty() => _mark(Coll.plants);
}
