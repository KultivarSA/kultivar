/// Shared types used by [GrowRepository] and its composed collection
/// classes (Q1b).
///
/// Each collection class takes a [MarkDirty] callback in its
/// constructor.  When a mutation completes, the collection invokes the
/// callback with its [Coll] tag — `GrowRepository` then records which
/// collection changed, schedules a debounced [StorageService] write,
/// and calls `notifyListeners()`.
///
/// Keeping these types in a standalone file avoids a circular import
/// between the repository and the collection files.
library;

/// Identifies which SharedPreferences collections need to be flushed to
/// disk.  Using an enum + dirty-set lets [GrowRepository._flush] write
/// only the changed collection on each debounce tick — no redundant
/// re-serialisation of unchanged data.
enum Coll {
  plants,
  growSpaces,
  harvestLogs,
  notes,
  strains,
  noteTemplates,
  expenses,
}

/// Signature handed to each collection's constructor.  Implementations
/// (in `GrowRepository`) typically:
///   1. Insert the [Coll] into the dirty set.
///   2. (Re)schedule the debounced flush timer.
///   3. Call `notifyListeners()` so widgets re-render.
typedef MarkDirty = void Function(Coll col);
