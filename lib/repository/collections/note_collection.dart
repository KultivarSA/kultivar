import '../../models/plant_note.dart';
import '../repo_types.dart';

/// Q1b — Per-collection sub-controller for plant notes.
///
/// Owns the in-memory note list and the per-plant memoized lookup
/// cache that powers `notesForPlant()` — by far the hottest read path
/// on the app (the plant detail screen calls it every build).
///
/// The cache is keyed by `'$plantId:asc'` / `'$plantId:desc'` so both
/// sort directions can stay warm simultaneously — PlantDetailScreen
/// reads newest-first while the grow-session report reads oldest-first.
class NoteCollection {
  NoteCollection(this._mark);

  final MarkDirty _mark;

  final List<PlantNote> _notes = [];

  /// Memoization map.  Key: `<plantId>:<asc|desc>`.
  final Map<String, List<PlantNote>> _byPlantCache = {};

  // ── Read-only views ───────────────────────────

  List<PlantNote> get all => List.unmodifiable(_notes);

  /// Notes for [plantId] sorted by date.  Newest-first by default;
  /// `ascending: true` returns oldest-first (used by the
  /// grow-session report).
  ///
  /// Memoized — re-runs the filter+sort only when the underlying note
  /// list has been mutated since the last call for the same plant.
  List<PlantNote> notesForPlant(String plantId, {bool ascending = false}) {
    final cacheKey = ascending ? '$plantId:asc' : '$plantId:desc';
    return _byPlantCache.putIfAbsent(cacheKey, () {
      return _notes.where((n) => n.plantId == plantId).toList()
        ..sort((a, b) {
          final byDate = ascending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt);
          // Stable tiebreaker so same-timestamp notes (e.g. batch
          // auto-notes) always appear in a deterministic order.
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
    });
  }

  // ── Cache helpers ─────────────────────────────

  void _invalidateAll() => _byPlantCache.clear();

  /// Clears both sort-direction cache entries for [plantId].
  void _invalidateFor(String plantId) {
    _byPlantCache.remove('$plantId:asc');
    _byPlantCache.remove('$plantId:desc');
  }

  // ── Mutations ─────────────────────────────────

  void add(PlantNote note) {
    _notes.add(note);
    _invalidateFor(note.plantId);
    _mark(Coll.notes);
  }

  /// Re-inserts a previously deleted note without triggering streak
  /// activity tracking.  Used for undo flows where the original activity
  /// was already counted on the first insertion.
  void readd(PlantNote note) {
    _notes.add(note);
    _invalidateFor(note.plantId);
    _mark(Coll.notes);
  }

  void update(PlantNote updated) {
    final i = _notes.indexWhere((n) => n.id == updated.id);
    if (i == -1) return;
    _invalidateFor(_notes[i].plantId);
    _notes[i] = updated;
    _mark(Coll.notes);
  }

  /// Removes the note with [noteId] and returns it for callers that
  /// need to inspect what was deleted (e.g. to know which photos to
  /// orphan-collect).  Returns null when the id is unknown.
  ///
  /// **Photo files are intentionally NOT deleted here** — the caller
  /// typically offers a 5-second undo that restores the DB record.
  /// Cleaning files would break that.  Use
  /// `GrowRepository.reclaimPhotoStorage()` to GC orphans periodically.
  PlantNote? deleteById(String noteId) {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return null;
    final removed = _notes[idx];
    _invalidateFor(removed.plantId);
    _notes.removeAt(idx);
    _mark(Coll.notes);
    return removed;
  }

  void resolve(String noteId, {DateTime? at}) {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i == -1) return;
    _invalidateFor(_notes[i].plantId);
    _notes[i] = _notes[i].copyWith(
      isResolved: true,
      resolvedAt: at ?? DateTime.now(),
    );
    _mark(Coll.notes);
  }

  // ── Cross-cutting access (see PlantCollection for the rationale) ──

  List<PlantNote> get rawListForBatch => _notes;

  void replaceAll(List<PlantNote> next) {
    _notes
      ..clear()
      ..addAll(next);
    _invalidateAll();
  }

  /// Removes every note tied to [plantId] in one pass and invalidates
  /// just that plant's cache.  Used by cascading plant-delete paths
  /// where issuing N `deleteById` calls would re-mark the collection
  /// dirty N times.
  List<PlantNote> removeAllForPlant(String plantId) {
    final removed = <PlantNote>[];
    _notes.removeWhere((n) {
      if (n.plantId == plantId) {
        removed.add(n);
        return true;
      }
      return false;
    });
    if (removed.isNotEmpty) {
      _invalidateFor(plantId);
      _mark(Coll.notes);
    }
    return removed;
  }

  void invalidateAll() => _invalidateAll();
  void invalidateFor(String plantId) => _invalidateFor(plantId);
  void markDirty() => _mark(Coll.notes);
}
