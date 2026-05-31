import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/environment_log.dart';
import '../models/grow_expense.dart';
import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/note_template.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain.dart';
import '../services/error_reporter.dart';
import '../services/hive_service.dart';
import '../services/storage_service.dart';
import '../utils/photo_path_resolver.dart';
// Q1b — per-collection sub-controllers composed inside GrowRepository.
import 'collections/expense_collection.dart';
import 'collections/harvest_collection.dart';
import 'collections/note_collection.dart';
import 'collections/plant_collection.dart';
// Q6 — extracted controllers for the cross-cutting concerns.
import 'controllers/backup_controller.dart';
import 'controllers/environment_controller.dart';
import 'repo_types.dart';

class StreakData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;

  const StreakData({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
  });

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate': lastActivityDate?.toIso8601String(),
      };

  factory StreakData.fromMap(Map<String, dynamic> map) => StreakData(
        currentStreak: map['currentStreak'] ?? 0,
        longestStreak: map['longestStreak'] ?? 0,
        lastActivityDate: map['lastActivityDate'] != null
            ? DateTime.parse(map['lastActivityDate'])
            : null,
      );
}

// Q1b — `_Coll` was moved to `repo_types.dart` as the public `Coll`
// enum so the per-collection sub-controllers can reference it without
// a circular import.  A type alias keeps the local short name working
// inside this file's existing call sites.
typedef _Coll = Coll;

/// Snapshot of everything that goes when [GrowRepository.softDeletePlant] is
/// called.  Hand back to [GrowRepository.restoreDeletedPlant] to undo, or
/// [GrowRepository.commitDeletedPlant] to finalise (which physically
/// removes photo files from disk).
///
/// Photo files referenced by the snapshot's notes are NOT deleted until
/// commit — so a 5-second Undo window preserves them on disk and a restore
/// just re-references them via the original photoUrls.
class DeletedPlantSnapshot {
  final Plant plant;
  final List<PlantNote> notes;
  final List<HarvestLog> harvestLogs;
  final List<GrowExpense> expenses;

  const DeletedPlantSnapshot({
    required this.plant,
    required this.notes,
    required this.harvestLogs,
    required this.expenses,
  });
}

class GrowRepository extends ChangeNotifier {
  GrowRepository() {
    // Q1b — each collection gets the same `_mark` callback.  The
    // callback path is:
    //   collection mutation → _mark(Coll) → dirty set + reschedule
    //   debounce + notifyListeners()
    // so the public API surface stays unchanged for callers/tests.
    _plantColl = PlantCollection(_mark);
    _noteColl = NoteCollection(_mark);
    _harvestColl = HarvestCollection(_mark);
    _expenseColl = ExpenseCollection(_mark);

    // Q6 — env controller takes lightweight callbacks instead of a
    // back-reference to this object, keeping it independently testable.
    _envCtrl = EnvironmentController(
      getSpaces: () => _growSpaces,
      onStorageError: _notifyStorageError,
      onChange: notifyListeners,
      onActivity: _recordActivity,
    );
  }

  final _uuid = const Uuid();
  Timer? _debounce;
  final Set<_Coll> _dirty = {};

  // Q1b — composed sub-controllers.  Public mutations on
  // [GrowRepository] forward to these; cross-cutting operations
  // (cascading deletes, backup, load, clearAllData) access the
  // collections' rawListForBatch / replaceAll helpers.
  late final PlantCollection _plantColl;
  late final NoteCollection _noteColl;
  late final HarvestCollection _harvestColl;
  late final ExpenseCollection _expenseColl;
  // Q6 — extracted env-log controller; backup is stateless so it
  // doesn't need to be held here.
  late final EnvironmentController _envCtrl;

  /// Notifier for Hive write errors.  Widgets can listen and surface a SnackBar.
  /// Resets to null one second after being set so the same error can re-fire.
  final ValueNotifier<String?> storageError = ValueNotifier(null);

  void _notifyStorageError(String message) {
    storageError.value = message;
    // Auto-clear so the same error can re-trigger if it recurs.
    Future.delayed(const Duration(seconds: 1), () {
      storageError.value = null;
    });
  }

  // Q6 — env-alert throttle map moved into [EnvironmentController].

  // Private backing lists for the smaller collections — kept inline
  // because their mutation surface is tiny and the cross-cutting code
  // (`removeGrowSpace`, `clearAllData`) is easier to read without
  // another indirection.  Plant/Note/Harvest/Expense moved to dedicated
  // collection classes in Q1b.
  List<GrowSpace> _growSpaces = [];
  List<Strain> _strains = [];
  List<NoteTemplate> _noteTemplates = [];
  StreakData streak = const StreakData();

  // Read-only public views — Q1b forwards plant/note/harvest/expense
  // to their composed collection.  External call sites and tests stay
  // unchanged.
  List<Plant> get plants => _plantColl.all;
  List<GrowSpace> get growSpaces => List.unmodifiable(_growSpaces);
  List<HarvestLog> get harvestLogs => _harvestColl.all;
  List<PlantNote> get notes => _noteColl.all;
  List<Strain> get strains => List.unmodifiable(_strains);
  List<NoteTemplate> get noteTemplates => List.unmodifiable(_noteTemplates);
  List<GrowExpense> get expenses => _expenseColl.all;

  // Q1b — direct private-list aliases so the remaining inline code
  // (cross-cutting cascades, backup/restore, load, clearAllData) reads
  // exactly as it did before the split.  Each alias points at the
  // collection's raw list — mutating it requires manually calling the
  // collection's markDirty()/invalidate*() helpers.
  List<Plant> get _plants => _plantColl.rawListForBatch;
  List<PlantNote> get _notes => _noteColl.rawListForBatch;
  List<HarvestLog> get _harvestLogs => _harvestColl.rawListForBatch;
  List<GrowExpense> get _expenses => _expenseColl.rawListForBatch;

  String newId() => _uuid.v4();

  // ── Environment logs live in Hive ─────────────
  // Q6 — optimistic cache + alert throttling now owned by
  // [EnvironmentController]; the getter delegates so existing call
  // sites (`repo.environmentLogs`) stay unchanged.

  List<EnvironmentLog> get environmentLogs => _envCtrl.all;

  void _invalidateEnvCache() => _envCtrl.invalidateCache();

  // Q1b — note + plant caches moved into their respective collection
  // classes (`PlantCollection._byIdCache`, `NoteCollection._byPlantCache`).
  // The wrapper methods below preserve the public API.
  void _invalidateNotesCache() => _noteColl.invalidateAll();
  void _invalidateNotesCacheFor(String plantId) =>
      _noteColl.invalidateFor(plantId);

  /// O(1) lookup by plant ID.  Returns null when the ID is unknown.
  Plant? plantById(String id) => _plantColl.plantById(id);

  /// Read-only map view of plants keyed by ID.
  Map<String, Plant> get plantsById => _plantColl.byId;

  void _invalidatePlantCache() => _plantColl.invalidateCache();

  // ── Load ──────────────────────────────────────

  /// Set the first time [load] finishes (successfully OR via empty-state
  /// fallback).  Used to distinguish the *initial* load — which races
  /// against user-driven onboarding writes — from explicit subsequent
  /// loads triggered by demo-seed or backup-restore.
  bool _initialLoadDone = false;

  /// True while the *first* `load()` call is in flight, false once it
  /// settles (either with data or with the empty-state fallback).
  /// Surfaces that want to render skeleton placeholders during a cold
  /// start can flip on this — e.g. the Home grid stacks
  /// `SkeletonSpaceCard`s instead of the empty-state hero while the
  /// load is racing.  Stays false for subsequent reloads (demo seed,
  /// backup restore) because those paths already trigger their own
  /// progress UI.
  bool get isLoading => !_initialLoadDone;

  Future<void> load() async {
    final isInitialLoad = !_initialLoadDone;
    try {
      final results = await Future.wait([
        StorageService.loadAll(),
        StorageService.loadStreakData(),
        StorageService.loadLegacyEnvironmentLogs(),
      ]);

      final data = results[0] as Map<String, dynamic>;
      final streakMap = results[1] as Map<String, dynamic>;
      final legacyLogs = results[2] as List<EnvironmentLog>;

      // Race-condition guard for first launch.
      //
      // Provider lazily creates `GrowRepository()..load()` only when
      // someone first reads from it — typically inside the onboarding
      // wizard when the user taps "Create Space".  `addGrowSpace` then
      // mutates the empty repo synchronously while the async load() is
      // still in flight.  If load completes *after* the user-driven
      // writes, the `replaceAll(...)` calls below would clobber the
      // user's data with the empty disk state — destroying the space
      // they just added and orphaning the plant.
      //
      // Defensive fix: on the initial load, if there's already
      // in-memory data, skip the disk-overwrite and trust the user's
      // writes.  Subsequent explicit loads (demo seed, backup import)
      // still clobber as intended.
      final hasInMemoryWrites = _plantColl.rawListForBatch.isNotEmpty ||
          _growSpaces.isNotEmpty ||
          _noteColl.rawListForBatch.isNotEmpty ||
          _harvestColl.rawListForBatch.isNotEmpty ||
          _expenseColl.rawListForBatch.isNotEmpty;

      if (isInitialLoad && hasInMemoryWrites) {
        _initialLoadDone = true;
        _invalidateNotesCache();
        _invalidateEnvCache();
        notifyListeners();
        return;
      }

      // Q1b — load through the collection's replaceAll so caches stay
      // consistent and the lists are owned by the right sub-controller.
      _plantColl.replaceAll(data['plants'] as List<Plant>);
      _growSpaces = data['growSpaces'] as List<GrowSpace>;
      _harvestColl.replaceAll(data['harvestLogs'] as List<HarvestLog>);
      _noteColl.replaceAll(data['notes'] as List<PlantNote>);
      _strains = data['strains'] as List<Strain>;
      _noteTemplates = data['noteTemplates'] as List<NoteTemplate>;
      _expenseColl.replaceAll(
          (data['expenses'] as List<GrowExpense>?) ?? const []);
      // replaceAll already invalidates the per-collection caches.
      streak = streakMap.isNotEmpty
          ? StreakData.fromMap(streakMap)
          : const StreakData();

      // One-time migration of old JSON logs into Hive — guarded so a Hive
      // initialisation failure doesn't crash the whole load sequence.
      try {
        await HiveService.migrateFromJson(legacyLogs);
        await StorageService.clearLegacyEnvironmentLogs();
      } catch (e, stack) {
        ErrorReporter.report('HiveService.migrateFromJson', e, stack);
      }

      // One-time migration: convert any stored absolute photo paths to
      // portable filenames.  Runs silently; save is skipped if nothing changed.
      _migratePhotoPathsIfNeeded();
    } catch (e, stack) {
      // SharedPreferences completely unavailable (rare on Android low-memory
      // kills).  Start with empty state so the UI is functional rather than
      // frozen on a loading spinner — but only if the user hasn't already
      // added data via the same race window guarded above.  Wiping
      // user writes on a failed load would be even worse than a failed
      // load.
      ErrorReporter.report('GrowRepository.load', e, stack);
      final hasInMemoryWrites = _plantColl.rawListForBatch.isNotEmpty ||
          _growSpaces.isNotEmpty ||
          _noteColl.rawListForBatch.isNotEmpty ||
          _harvestColl.rawListForBatch.isNotEmpty ||
          _expenseColl.rawListForBatch.isNotEmpty;
      if (!(isInitialLoad && hasInMemoryWrites)) {
        _plantColl.replaceAll(const []);
        _growSpaces = [];
        _harvestColl.replaceAll(const []);
        _noteColl.replaceAll(const []);
        _strains = [];
        _noteTemplates = [];
        _expenseColl.replaceAll(const []);
        streak = const StreakData();
      }
    }

    _initialLoadDone = true;
    // _notes was fully replaced — any cached per-plant slices are stale.
    _invalidateNotesCache();
    _invalidateEnvCache();
    notifyListeners();
  }

  /// Scans all stored photo URLs and converts legacy absolute paths to
  /// portable filenames (see [PhotoPathResolver]).  Persists the notes
  /// collection only when at least one path was converted.
  void _migratePhotoPathsIfNeeded() {
    bool changed = false;
    // Operates on the raw list because we want a single SharedPreferences
    // write at the end rather than N debounced flushes via NoteCollection.
    final raw = _noteColl.rawListForBatch;
    for (var i = 0; i < raw.length; i++) {
      final note = raw[i];
      if (note.photoUrls.isEmpty) continue;
      final migrated = note.photoUrls.map((p) {
        // Absolute paths contain a path separator; filenames do not.
        if (!p.contains('/') && !p.contains(r'\')) return p;
        final filename = p.split('/').last.split(r'\').last;
        changed = true;
        return filename;
      }).toList();
      if (changed) {
        raw[i] = note.copyWith(photoUrls: migrated);
      }
    }
    if (changed) {
      _noteColl.invalidateAll();
      // Q5 — informational migration log; debug-only.
      if (kDebugMode) {
        debugPrint(
            '[GrowRepository] Migrated photo paths to relative filenames.');
      }
      StorageService.saveNotes(raw);
    }
  }

  // ── Grow spaces ───────────────────────────────

  void addGrowSpace(GrowSpace space) {
    _growSpaces.add(space);
    _mark(_Coll.growSpaces);
  }

  void updateGrowSpace(GrowSpace updated) {
    final i = _growSpaces.indexWhere((s) => s.id == updated.id);
    if (i == -1) return;
    _growSpaces[i] = updated;
    _mark(_Coll.growSpaces);
  }

  /// Removes the grow space and, for safety, archives every plant that
  /// still lives in it (status → removed).  An audit [PlantNote] is added
  /// for each archived plant so the removal appears in the plant's history.
  /// Returns the number of plants that were archived.
  int removeGrowSpace(String spaceId) {
    // Capture name before it's removed from the list.
    final spaceIdx = _growSpaces.indexWhere((s) => s.id == spaceId);
    final spaceName =
        spaceIdx != -1 ? _growSpaces[spaceIdx].name : 'deleted space';

    final orphans = _plants.where((p) => p.growSpaceId == spaceId).toList();
    final now = DateTime.now();
    for (final p in orphans) {
      final i = _plants.indexWhere((pl) => pl.id == p.id);
      if (i == -1) continue;
      _plants[i] = p.copyWith(
        status: PlantStatus.removed,
        isArchived: true,
        archivedAt: now,
        archiveReason: 'Grow space deleted',
        // Clear the dangling space reference so future space-ID queries
        // never accidentally match a new space that reuses this slot.
        growSpaceId: '',
      );
      // Create a visible audit note so the archive history explains the removal.
      _notes.add(PlantNote(
        id: _uuid.v4(),
        plantId: p.id,
        createdAt: now,
        category: NoteCategory.milestone,
        content: 'Plant archived — grow space "$spaceName" was deleted.',
      ));
      _invalidateNotesCacheFor(p.id);
    }

    _growSpaces.removeWhere((s) => s.id == spaceId);

    // Q6 — cascading env-log delete lives on the controller.  The
    // controller eagerly drops cached entries before kicking off the
    // Hive write so the UI reflects the removal immediately.
    _envCtrl.deleteForSpace(spaceId);

    if (orphans.isNotEmpty) {
      // Mirrors what _mark would invalidate — kept inline here because
      // we want to flush plants+notes together without two debounce
      // timer resets.
      _invalidatePlantCache();
      _dirty.add(_Coll.plants);
      _dirty.add(_Coll.notes);
    }
    _mark(_Coll.growSpaces);
    return orphans.length;
  }

  // ── Plants (Q1b — delegates to PlantCollection) ───

  void addPlant(Plant plant) {
    _plantColl.add(plant);
    _recordActivity();
  }

  void updatePlant(Plant updated) => _plantColl.update(updated);

  void movePlant({
    required Plant plant,
    required String newGrowSpaceId,
  }) {
    if (plant.growSpaceId == newGrowSpaceId) return;
    // Use indexWhere so a missing space (e.g. deleted concurrently) returns
    // -1 rather than throwing a StateError.
    final fromIdx = _growSpaces.indexWhere((s) => s.id == plant.growSpaceId);
    final toIdx = _growSpaces.indexWhere((s) => s.id == newGrowSpaceId);
    final from = fromIdx != -1 ? _growSpaces[fromIdx].name : 'unknown space';
    final to = toIdx != -1 ? _growSpaces[toIdx].name : 'unknown space';
    updatePlant(plant.copyWith(growSpaceId: newGrowSpaceId));
    addNote(PlantNote(
      id: newId(),
      plantId: plant.id,
      createdAt: DateTime.now(),
      category: NoteCategory.milestone,
      content: 'Moved from $from → $to',
    ));
  }

  /// Archives a plant as removed. Returns the ID of the auto-created note so
  /// the caller can offer an undo action via [undoArchivePlant].
  String archivePlantWithReason({
    required Plant plant,
    required String reason,
    String? notesText,
  }) {
    final now = DateTime.now();
    final noteId = newId();
    updatePlant(plant.copyWith(
      status: PlantStatus.removed,
      isArchived: true,
      archivedAt: now,
      archiveReason: reason,
    ));
    addNote(PlantNote(
      id: noteId,
      plantId: plant.id,
      createdAt: now,
      category: NoteCategory.issue,
      content: notesText != null && notesText.isNotEmpty
          ? 'Plant removed: $reason\n$notesText'
          : 'Plant removed: $reason',
    ));
    return noteId;
  }

  /// Reverses an [archivePlantWithReason] call — restores the original plant
  /// state and deletes the auto-created removal note.
  void undoArchivePlant(Plant originalPlant, String autoNoteId) {
    updatePlant(originalPlant);
    deleteNote(autoNoteId);
  }

  /// Permanently deletes a plant and all its associated notes, photos,
  /// harvest logs and expenses.  This cannot be undone — callers should
  /// always confirm with the user first.  Notification cancellation is
  /// intentionally left to the caller so the repo has no dependency on
  /// NotificationService.
  ///
  /// Prefer [softDeletePlant] + [commitDeletedPlant] / [restoreDeletedPlant]
  /// when the caller wants a 5-second Undo affordance.
  void deletePlant(String plantId) {
    final snap = softDeletePlant(plantId);
    if (snap != null) commitDeletedPlant(snap);
  }

  /// Removes a plant + its notes + harvest logs + expenses from in-memory
  /// state and flushes the change to storage, but **deliberately keeps
  /// photo files on disk** so the caller can offer Undo.
  ///
  /// Returns a snapshot the caller MUST eventually finalise by calling
  /// either [restoreDeletedPlant] (puts the plant back) or
  /// [commitDeletedPlant] (deletes the now-orphan photo files).  Failing
  /// to call either leaks photo storage — see [reclaimPhotoStorage] for
  /// the GC path.
  ///
  /// Returns null when the plantId isn't found.
  DeletedPlantSnapshot? softDeletePlant(String plantId) {
    // Q1b — `removeById` returns the plant being deleted + marks
    // Coll.plants dirty + invalidates the by-id cache.  The three
    // cascading removeAllForPlant calls each mark their own collection.
    final removedPlant = _plantColl.removeById(plantId);
    if (removedPlant == null) return null;

    return DeletedPlantSnapshot(
      plant: removedPlant,
      notes: _noteColl.removeAllForPlant(plantId),
      harvestLogs: _harvestColl.removeAllForPlant(plantId),
      expenses: _expenseColl.removeAllForPlant(plantId),
    );
  }

  /// Restores a previously soft-deleted plant + everything that went with
  /// it.  Photo files were never touched, so notes get their attachments
  /// back automatically.
  void restoreDeletedPlant(DeletedPlantSnapshot snap) {
    // Q1b — append via raw lists + manual markDirty so all four
    // collections fire one dirty notification each, not N per item.
    _plantColl.rawListForBatch.add(snap.plant);
    _plantColl.invalidateCache();
    _plantColl.markDirty();

    if (snap.notes.isNotEmpty) {
      _noteColl.rawListForBatch.addAll(snap.notes);
      for (final n in snap.notes) {
        _noteColl.invalidateFor(n.plantId);
      }
      _noteColl.markDirty();
    }
    if (snap.harvestLogs.isNotEmpty) {
      _harvestColl.rawListForBatch.addAll(snap.harvestLogs);
      _harvestColl.markDirty();
    }
    if (snap.expenses.isNotEmpty) {
      _expenseColl.rawListForBatch.addAll(snap.expenses);
      _expenseColl.markDirty();
    }
  }

  /// Finalises a soft-delete by physically purging the photo files that
  /// belonged to the deleted notes.  Idempotent — re-running on the same
  /// snapshot is safe (already-missing files are silently skipped).
  void commitDeletedPlant(DeletedPlantSnapshot snap) {
    for (final note in snap.notes) {
      _deleteNotePhotos(note);
    }
  }

  // ── Strains ───────────────────────────────────

  void addStrain(Strain strain) {
    _strains.add(strain);
    _mark(_Coll.strains);
  }

  void updateStrain(Strain updated) {
    final i = _strains.indexWhere((s) => s.id == updated.id);
    if (i == -1) return;
    _strains[i] = updated;
    _mark(_Coll.strains);
  }

  void deleteStrain(String strainId) {
    _strains.removeWhere((s) => s.id == strainId);
    _mark(_Coll.strains);
  }

  Strain? strainById(String? id) {
    if (id == null) return null;
    try {
      return _strains.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Harvest logs (Q1b — delegates to HarvestCollection) ──

  void addHarvestLog(HarvestLog log) {
    _harvestColl.add(log);
    _recordActivity();
  }

  void updateHarvestDryWeight(String plantId, double weight) =>
      _harvestColl.updateDryWeight(plantId, weight);

  void finalizeHarvest(String plantId) => _harvestColl.finalize(plantId);

  /// Permanently removes a single harvest record from the archive.
  /// The associated plant is NOT modified — use [archivePlantWithReason]
  /// separately if the plant should also be removed.
  void deleteHarvestLog(String logId) => _harvestColl.deleteById(logId);

  /// Re-inserts a previously deleted harvest record without recording a
  /// streak activity.  Use this for undo operations where the original
  /// activity was already counted when the log was first created.
  void readdHarvestLog(HarvestLog log) => _harvestColl.readd(log);

  /// Replaces an existing harvest record with [updated].
  ///
  /// Only editable fields (wet weight, dry weight, notes) should differ from
  /// the original; all identity fields (id, plantId, harvestedDate, strain)
  /// are carried through by the caller-constructed object.
  void updateHarvestLog(HarvestLog updated) => _harvestColl.update(updated);

  /// Corrects an existing environment log's temperature, humidity or
  /// notes in place.  Q6 — delegates to [EnvironmentController].
  void updateEnvironmentLog(EnvironmentLog updated) =>
      _envCtrl.update(updated);

  /// Re-inserts a previously deleted environment log without recording
  /// streak activity.  Q6 — delegates to [EnvironmentController].
  void readdEnvironmentLog(EnvironmentLog log) => _envCtrl.readd(log);

  // ── Notes helper ──────────────────────────────

  /// Returns notes for [plantId] sorted by date, newest first by default.
  /// [ascending] = true → oldest first (for session reports).
  ///
  /// Q1b — delegates to [NoteCollection.notesForPlant] which owns the
  /// memoization cache.
  List<PlantNote> notesForPlant(String plantId, {bool ascending = false}) =>
      _noteColl.notesForPlant(plantId, ascending: ascending);

  // ── Environment logs (Hive) ───────────────────
  //
  // Q6 — all per-log logic (optimistic cache, env-alert throttling,
  // stale-env scheduling, batch dispatch) now lives in
  // [EnvironmentController].  These public methods are thin
  // delegations so external call sites (`repo.addEnvironmentLog(...)`
  // etc.) keep working unchanged.

  /// Log a single reading for a specific grow space.
  /// Called by EnvironmentLogScreen and SpaceDetailScreen.
  void addEnvironmentLog(EnvironmentLog log) => _envCtrl.add(log);

  /// Delete a single environment log entry.
  void deleteEnvironmentLog(String id) => _envCtrl.deleteById(id);

  /// Log a reading across ALL grow spaces at once.
  /// Called by the FAB sheet and the dashboard dialog.
  void addBatchEnvironmentLog({
    required double? temperature,
    required double? humidity,
    String? notes,
  }) =>
      _envCtrl.addBatch(
        newId: newId,
        temperature: temperature,
        humidity: humidity,
        notes: notes,
      );

  // ── Notes (Q1b — delegates to NoteCollection) ───

  void addNote(PlantNote note) {
    _noteColl.add(note);
    _recordActivity();
  }

  /// Updates an existing note's content and/or category in place.
  /// The original timestamp is preserved — only the mutable fields change.
  void updateNote(PlantNote updated) => _noteColl.update(updated);

  void deleteNote(String noteId) {
    // Photo files are intentionally NOT deleted here — the caller
    // typically offers a 5-second undo (addNote / readdNote) that
    // restores the DB record.  Deleting files immediately would
    // break undo for notes that have photos.  Orphan files are
    // cleaned up by reclaimPhotoStorage().
    _noteColl.deleteById(noteId);
  }

  /// Re-inserts a previously deleted note without recording a streak activity.
  /// Use this for undo operations where the original activity was already counted.
  void readdNote(PlantNote note) => _noteColl.readd(note);

  /// Deletes all photo files associated with [note] from the app documents
  /// directory.  Best-effort — individual file errors are logged and ignored
  /// so a missing file never prevents the note from being removed.
  void _deleteNotePhotos(PlantNote note) {
    if (kIsWeb || note.photoUrls.isEmpty) return;
    for (final nameOrPath in note.photoUrls) {
      try {
        final file = File(PhotoPathResolver.resolve(nameOrPath));
        if (file.existsSync()) file.deleteSync();
      } catch (e, stack) {
        ErrorReporter.report('GrowRepository._deleteNotePhotos', e, stack,
            {'path': nameOrPath});
      }
    }
  }

  /// Scans the app documents directory for image files that are no longer
  /// referenced by any note's [photoUrls] list, and deletes them.
  ///
  /// Returns the number of orphan files removed.  On web this is a no-op
  /// (returns 0) since there is no local filesystem to clean.
  Future<int> reclaimPhotoStorage() async {
    if (kIsWeb) return 0;

    final dir = await getApplicationDocumentsDirectory();
    final imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

    // Build the set of every filename currently referenced by a note.
    final referenced = <String>{};
    for (final note in _notes) {
      for (final nameOrPath in note.photoUrls) {
        // Store only the basename — PhotoPathResolver may have stored either
        // a bare filename or a legacy absolute path.
        referenced.add(p.basename(nameOrPath));
      }
    }

    int deleted = 0;
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (!imageExtensions.contains(ext)) continue;
        final filename = p.basename(entity.path);
        if (!referenced.contains(filename)) {
          try {
            await entity.delete();
            deleted++;
          } catch (e, stack) {
            ErrorReporter.report(
                'GrowRepository.reclaimPhotoStorage.delete', e, stack,
                {'filename': filename});
          }
        }
      }
    } catch (e, stack) {
      ErrorReporter.report(
          'GrowRepository.reclaimPhotoStorage.scan', e, stack);
    }

    return deleted;
  }

  void resolveNote(String noteId) => _noteColl.resolve(noteId);

  // ── Note templates ────────────────────────────

  void addNoteTemplate(NoteTemplate template) {
    _noteTemplates.add(template);
    _mark(_Coll.noteTemplates);
  }

  void updateNoteTemplate(NoteTemplate updated) {
    final i = _noteTemplates.indexWhere((t) => t.id == updated.id);
    if (i == -1) return;
    _noteTemplates[i] = updated;
    _mark(_Coll.noteTemplates);
  }

  void deleteNoteTemplate(String id) {
    _noteTemplates.removeWhere((t) => t.id == id);
    _mark(_Coll.noteTemplates);
  }

  // ── Streak ────────────────────────────────────

  void _recordActivity() {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final lastDate = streak.lastActivityDate != null
        ? DateTime(
            streak.lastActivityDate!.year,
            streak.lastActivityDate!.month,
            streak.lastActivityDate!.day,
          )
        : null;

    if (lastDate == today) return;

    final isConsecutive =
        lastDate != null && today.difference(lastDate).inDays == 1;

    final newCurrent = isConsecutive ? streak.currentStreak + 1 : 1;
    final newLongest =
        newCurrent > streak.longestStreak ? newCurrent : streak.longestStreak;

    streak = StreakData(
      currentStreak: newCurrent,
      longestStreak: newLongest,
      lastActivityDate: today,
    );

    StorageService.saveStreakData(streak.toMap());
  }

  // ── Force notify (used by settings clear) ─────

  // ── Harvest quality ───────────────────────────

  void updateHarvestQuality({
    required String harvestLogId,
    double? qualityRating,
    String? aromaNote,
    String? flavorNotes,
    String? effectNotes,
    double? smellRating,
    double? effectRating,
    double? bagAppealRating,
  }) =>
      _harvestColl.updateQuality(
        harvestLogId: harvestLogId,
        qualityRating: qualityRating,
        aromaNote: aromaNote,
        flavorNotes: flavorNotes,
        effectNotes: effectNotes,
        smellRating: smellRating,
        effectRating: effectRating,
        bagAppealRating: bagAppealRating,
      );

// ── Backup & restore (Q6 — delegates to BackupController) ────────
//
// The two methods above used to be ~250 LOC of inline logic.  Now
// they're thin wrappers: this file owns the in-memory state, the
// controller owns the file-system + crypto + share-sheet plumbing.

  Future<void> exportBackup() => BackupController.exportBackup(
        plants: _plants,
        growSpaces: _growSpaces,
        harvestLogs: _harvestLogs,
        notes: _notes,
        strains: _strains,
        noteTemplates: _noteTemplates,
        expenses: _expenses,
      );

  /// Restores from a backup file picked by the user.
  ///
  /// Encrypted ZIPs require a passphrase.  [onRequestPassphrase] is
  /// invoked when one is needed — typically wired to a dialog in the
  /// UI layer.  Retried with the user's input when the supplied
  /// passphrase doesn't decrypt, up to [maxPassphraseAttempts].
  /// Returning `null` from the callback cancels the import.
  Future<String?> importBackup({
    Future<String?> Function()? onRequestPassphrase,
    int maxPassphraseAttempts = 3,
  }) =>
      BackupController.importBackup(
        onRequestPassphrase: onRequestPassphrase,
        maxPassphraseAttempts: maxPassphraseAttempts,
        reload: load,
      );

// ── Expenses (Q1b — delegates to ExpenseCollection) ──

  void addExpense(GrowExpense expense) => _expenseColl.add(expense);
  void updateExpense(GrowExpense updated) => _expenseColl.update(updated);
  void deleteExpense(String id) => _expenseColl.deleteById(id);

  /// All expenses attributed to a specific plant, sorted newest-first.
  List<GrowExpense> expensesForPlant(String plantId) =>
      _expenseColl.forPlant(plantId);

  /// All expenses attributed to a specific space (plantId == null),
  /// sorted newest-first.
  List<GrowExpense> expensesForSpace(String spaceId) =>
      _expenseColl.forSpace(spaceId);

  /// Sum of all expense amounts for a plant.
  double totalCostForPlant(String plantId) =>
      _expenseColl.totalForPlant(plantId);

  /// Cost per gram for a harvested plant (currency symbol applied at
  /// the UI layer via CurrencyService).  Returns null if there are no
  /// expenses or the plant has no recorded dry weight.
  double? costPerGram(String plantId, double? dryWeightGrams) =>
      _expenseColl.costPerGram(plantId, dryWeightGrams);

  /// Sum of ALL expenses across every plant and space.
  double get totalExpenditure => _expenseColl.total;

  /// Average cost per gram across all completed harvests that have both
  /// expenses and a recorded dry weight.
  double? get averageCostPerGram {
    double totalCost = 0;
    double totalGrams = 0;
    for (final log in _harvestLogs) {
      if (log.dryWeight == null || log.dryWeight! <= 0) continue;
      final cost = totalCostForPlant(log.plantId);
      if (cost <= 0) continue;
      totalCost += cost;
      totalGrams += log.dryWeight!;
    }
    if (totalGrams <= 0) return null;
    return totalCost / totalGrams;
  }

// ── Clear all data ────────────────────────────

  Future<void> clearAllData() async {
    _debounce?.cancel();
    _dirty.clear();       // discard any queued per-collection saves
    _invalidateEnvCache(); // clear env log memo
    // Delete all on-disk photo files before clearing the notes list.
    if (!kIsWeb) {
      for (final note in _noteColl.rawListForBatch) {
        _deleteNotePhotos(note);
      }
    }
    // Q1b — empty each collection through its replaceAll (which also
    // resets the per-collection cache).  No dirty marks fire because
    // we issue one notifyListeners() at the end and the save below is
    // explicit.
    _plantColl.replaceAll(const []);
    _noteColl.replaceAll(const []);
    _harvestColl.replaceAll(const []);
    _expenseColl.replaceAll(const []);
    _growSpaces.clear();
    _strains.clear();
    _noteTemplates.clear();
    streak = const StreakData();
    await HiveService.clearAllLogs();
    await Future.wait([
      StorageService.saveAll(
        plants: const [],
        growSpaces: _growSpaces,
        harvestLogs: const [],
        notes: const [],
        strains: _strains,
        noteTemplates: _noteTemplates,
      ),
      StorageService.saveExpenses(const []),
    ]);
    await StorageService.saveStreakData({});
    notifyListeners();
  }

  // ── Lifecycle ─────────────────────────────────

  @override
  void dispose() {
    // Flush any pending dirty-set writes synchronously before tearing down.
    _debounce?.cancel();
    if (_dirty.isNotEmpty) {
      // Best-effort: fire-and-forget since dispose() is synchronous.
      _flush();
    }
    storageError.dispose();
    super.dispose();
  }

  // ── Debounced per-collection persist ──────────
  //
  // _mark() records which collections changed and schedules a single debounced
  // flush.  Only the dirty collections are serialised to SharedPreferences,
  // avoiding the cost of re-encoding unchanged data (e.g. editing a note no
  // longer triggers a redundant plants or harvest-log write).

  void _mark(_Coll col) {
    // Q1b — per-collection caches are now self-invalidating inside the
    // collection classes (PlantCollection / NoteCollection).  This
    // method's sole job is to schedule the debounced disk flush and
    // notify widgets of the change.
    _dirty.add(col);
    _debounce?.cancel();
    // _flush is async, but Timer requires a void callback.  We wrap it so that
    // any exception thrown inside _flush() is caught and surfaced via
    // _notifyStorageError rather than silently vanishing into the event loop.
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _flush().catchError((Object e, StackTrace s) {
        ErrorReporter.report('GrowRepository._flush', e, s);
        _notifyStorageError('Failed to save data. Changes may not persist.');
      });
    });
    notifyListeners();
  }

  /// Force an immediate flush of all pending writes to SharedPreferences.
  ///
  /// Cancels any in-flight debounce timer and synchronously awaits [_flush].
  /// Call this before completing onboarding (or any checkpoint that transitions
  /// away from the screen) to guarantee the data is on disk before the app
  /// state changes.
  Future<void> save() async {
    _debounce?.cancel();
    await _flush();
  }

  Future<void> _flush() async {
    final toSave = Set<_Coll>.from(_dirty);
    _dirty.clear();
    final futures = <Future<void>>[];
    if (toSave.contains(_Coll.plants)) {
      futures.add(StorageService.savePlants(_plants));
    }
    if (toSave.contains(_Coll.growSpaces)) {
      futures.add(StorageService.saveGrowSpaces(_growSpaces));
    }
    if (toSave.contains(_Coll.harvestLogs)) {
      futures.add(StorageService.saveHarvestLogs(_harvestLogs));
    }
    if (toSave.contains(_Coll.notes)) {
      futures.add(StorageService.saveNotes(_notes));
    }
    if (toSave.contains(_Coll.strains)) {
      futures.add(StorageService.saveStrains(_strains));
    }
    if (toSave.contains(_Coll.noteTemplates)) {
      futures.add(StorageService.saveNoteTemplates(_noteTemplates));
    }
    if (toSave.contains(_Coll.expenses)) {
      futures.add(StorageService.saveExpenses(_expenses));
    }
    await Future.wait(futures);
  }
}
