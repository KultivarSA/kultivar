import '../../models/grow_expense.dart';
import '../repo_types.dart';

/// Q1b — Per-collection sub-controller for grow expenses.
///
/// Pure list + read aggregations — no cache because the read paths
/// (`expensesForPlant`, `totalCostForPlant`) are already O(N) and
/// users never have more than a few hundred entries.  Adding a cache
/// here would cost more in invalidation logic than it would save.
class ExpenseCollection {
  ExpenseCollection(this._mark);

  final MarkDirty _mark;

  final List<GrowExpense> _expenses = [];

  // ── Read-only views ───────────────────────────

  List<GrowExpense> get all => List.unmodifiable(_expenses);

  /// All expenses attributed to a specific plant, sorted newest-first.
  List<GrowExpense> forPlant(String plantId) {
    return _expenses.where((e) => e.plantId == plantId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Expenses scoped to a grow space — only those NOT attributed to a
  /// specific plant.  Plant-attributed costs already appear in
  /// [forPlant] and shouldn't be double-counted at the space level.
  List<GrowExpense> forSpace(String spaceId) {
    return _expenses
        .where((e) => e.growSpaceId == spaceId && e.plantId == null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double totalForPlant(String plantId) =>
      forPlant(plantId).fold(0.0, (s, e) => s + e.amount);

  /// Cost per gram for a harvested plant.  Returns null when there
  /// are no expenses or the plant has no recorded dry weight.
  double? costPerGram(String plantId, double? dryWeightGrams) {
    if (dryWeightGrams == null || dryWeightGrams <= 0) return null;
    final total = totalForPlant(plantId);
    if (total <= 0) return null;
    return total / dryWeightGrams;
  }

  /// Sum of ALL expense amounts across every plant and space.
  double get total => _expenses.fold(0.0, (s, e) => s + e.amount);

  // ── Mutations ─────────────────────────────────

  void add(GrowExpense expense) {
    _expenses.add(expense);
    _mark(Coll.expenses);
  }

  void update(GrowExpense updated) {
    final i = _expenses.indexWhere((e) => e.id == updated.id);
    if (i == -1) return;
    _expenses[i] = updated;
    _mark(Coll.expenses);
  }

  void deleteById(String id) {
    _expenses.removeWhere((e) => e.id == id);
    _mark(Coll.expenses);
  }

  // ── Cross-cutting access ──────────────────────

  List<GrowExpense> get rawListForBatch => _expenses;

  void replaceAll(List<GrowExpense> next) {
    _expenses
      ..clear()
      ..addAll(next);
  }

  /// Cascades a plant deletion — drops every expense attributed to
  /// [plantId] in a single pass.  Returns the removed entries so the
  /// caller can stash them in a soft-delete snapshot.
  List<GrowExpense> removeAllForPlant(String plantId) {
    final removed = <GrowExpense>[];
    _expenses.removeWhere((e) {
      if (e.plantId == plantId) {
        removed.add(e);
        return true;
      }
      return false;
    });
    if (removed.isNotEmpty) _mark(Coll.expenses);
    return removed;
  }

  void markDirty() => _mark(Coll.expenses);
}
