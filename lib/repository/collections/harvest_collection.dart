import '../../models/harvest_log.dart';
import '../repo_types.dart';

/// Q1b — Per-collection sub-controller for harvest logs.
///
/// Each plant only ever has one harvest log in practice, but the
/// indirection here keeps the storage + dirty-marking story uniform
/// with the other collections.
class HarvestCollection {
  HarvestCollection(this._mark);

  final MarkDirty _mark;

  final List<HarvestLog> _logs = [];

  // ── Read-only views ───────────────────────────

  List<HarvestLog> get all => List.unmodifiable(_logs);

  // ── Mutations ─────────────────────────────────

  void add(HarvestLog log) {
    _logs.add(log);
    _mark(Coll.harvestLogs);
  }

  /// Re-inserts a previously deleted harvest record without recording
  /// streak activity — used for undo flows.
  void readd(HarvestLog log) {
    _logs.add(log);
    _mark(Coll.harvestLogs);
  }

  void update(HarvestLog updated) {
    final i = _logs.indexWhere((l) => l.id == updated.id);
    if (i == -1) return;
    _logs[i] = updated;
    _mark(Coll.harvestLogs);
  }

  void deleteById(String logId) {
    _logs.removeWhere((l) => l.id == logId);
    _mark(Coll.harvestLogs);
  }

  void updateDryWeight(String plantId, double weight) {
    final i = _logs.indexWhere((l) => l.plantId == plantId);
    if (i == -1) return;
    _logs[i] = _logs[i].copyWith(dryWeight: weight);
    _mark(Coll.harvestLogs);
  }

  void finalize(String plantId) {
    final i = _logs.indexWhere((l) => l.plantId == plantId);
    if (i == -1) return;
    _logs[i] = _logs[i].copyWith(isDraft: false);
    _mark(Coll.harvestLogs);
  }

  /// Updates the qualitative ratings + tasting notes on a harvest log.
  /// Each parameter is optional — only non-null values overwrite the
  /// existing field (matches the original `copyWith` semantics so
  /// passing `null` for one field doesn't blow away an existing rating).
  void updateQuality({
    required String harvestLogId,
    double? qualityRating,
    String? aromaNote,
    String? flavorNotes,
    String? effectNotes,
    double? smellRating,
    double? effectRating,
    double? bagAppealRating,
  }) {
    final idx = _logs.indexWhere((l) => l.id == harvestLogId);
    if (idx == -1) return;
    _logs[idx] = _logs[idx].copyWith(
      qualityRating: qualityRating,
      aromaNote: aromaNote,
      flavorNotes: flavorNotes,
      effectNotes: effectNotes,
      smellRating: smellRating,
      effectRating: effectRating,
      bagAppealRating: bagAppealRating,
    );
    _mark(Coll.harvestLogs);
  }

  // ── Cross-cutting access ──────────────────────

  List<HarvestLog> get rawListForBatch => _logs;

  void replaceAll(List<HarvestLog> next) {
    _logs
      ..clear()
      ..addAll(next);
  }

  /// Cascades a plant deletion — drops every harvest log tied to
  /// [plantId].  Returns the removed entries for soft-delete snapshots.
  List<HarvestLog> removeAllForPlant(String plantId) {
    final removed = <HarvestLog>[];
    _logs.removeWhere((l) {
      if (l.plantId == plantId) {
        removed.add(l);
        return true;
      }
      return false;
    });
    if (removed.isNotEmpty) _mark(Coll.harvestLogs);
    return removed;
  }

  void markDirty() => _mark(Coll.harvestLogs);
}
