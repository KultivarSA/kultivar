import 'dart:async';

import '../../main.dart';
import '../../models/environment_log.dart';
import '../../models/grow_space.dart';
import '../../services/error_reporter.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../utils/temp_format.dart';

/// Q6 — Sub-controller for environment logs (composed inside
/// [GrowRepository]).
///
/// Owns three pieces of state that used to live on the repo directly:
///
/// 1. **Optimistic cache** (`_cachedEnvLogs`) — Hive's reads are
///    synchronous from a snapshot, but writes are async.  Appending to
///    the cache eagerly lets the UI redraw on the next frame instead
///    of waiting for the disk flush; the cache is invalidated once
///    the Hive write resolves so subsequent reads come from the
///    authoritative box.
///
/// 2. **Env-alert throttle map** (`_lastEnvAlert`) — keyed by spaceId,
///    holds the timestamp of the most recent alert fired for that
///    space.  Used to suppress duplicate notifications within a
///    30-minute window.
///
/// 3. **Stale-env reschedule** — every new log re-arms a 48 h alert so
///    the user gets pinged when a tent goes unmonitored.
///
/// Callbacks let the controller stay decoupled from [GrowRepository]:
///   * [getSpaces]        — lookup `List<GrowSpace>` when an alert
///                          needs the space name / optimal thresholds.
///   * [onStorageError]   — surface a one-shot SnackBar via the
///                          repo's `storageError` notifier.
///   * [onChange]         — repo's `notifyListeners()` so widgets
///                          re-render after every mutation.
///   * [onActivity]       — streak tracker, only fired for fresh
///                          additions (not re-adds or updates).
class EnvironmentController {
  EnvironmentController({
    required List<GrowSpace> Function() getSpaces,
    required void Function(String message) onStorageError,
    required void Function() onChange,
    required void Function() onActivity,
  })  : _getSpaces = getSpaces,
        _onStorageError = onStorageError,
        _onChange = onChange,
        _onActivity = onActivity;

  final List<GrowSpace> Function() _getSpaces;
  final void Function(String) _onStorageError;
  final void Function() _onChange;
  final void Function() _onActivity;

  /// Cached list — `HiveService.allEnvironmentLogs()` iterates the Box
  /// on every call.  We memoize and update optimistically so reads
  /// between write and disk flush always reflect the latest in-memory
  /// state.
  List<EnvironmentLog>? _cached;

  /// Throttle map for environment alerts: spaceId → last alert time.
  /// Prevents re-firing for the same space within 30 minutes.
  final Map<String, DateTime> _lastAlert = {};

  // ── Reads ─────────────────────────────────────

  List<EnvironmentLog> get all =>
      _cached ??= HiveService.allEnvironmentLogs();

  void invalidateCache() => _cached = null;

  // ── Mutations ─────────────────────────────────

  /// Log a single reading for a specific grow space.
  void add(EnvironmentLog log) {
    // Optimistically append to the in-memory cache so the UI sees the new
    // entry immediately, without waiting for the Hive disk flush to complete.
    _cached = [...all, log];

    unawaited(HiveService.addEnvironmentLog(log).then((_) {
      // Flush successful: drop the optimistic copy so the next read
      // comes from the authoritative Hive box.
      invalidateCache();
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report('HiveService.addEnvironmentLog', e, s);
      // Revert: remove the optimistic entry and let the UI reconcile.
      invalidateCache();
      _onStorageError('Failed to save environment log.');
      _onChange();
    }));

    _maybeFireAlert(log);
    _rescheduleStaleAlert(log);

    _onActivity();
    _onChange();
  }

  /// Corrects an existing environment log's temperature, humidity or
  /// notes in place.  Uses the same optimistic-cache pattern as [add].
  void update(EnvironmentLog updated) {
    if (_cached != null) {
      final i = _cached!.indexWhere((l) => l.id == updated.id);
      if (i != -1) {
        final copy = [..._cached!];
        copy[i] = updated;
        _cached = copy;
      }
    }
    // HiveService.addEnvironmentLog uses box.put() which is an upsert —
    // storing with the same key overwrites the existing entry.
    unawaited(HiveService.addEnvironmentLog(updated).then((_) {
      invalidateCache();
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report('HiveService.updateEnvironmentLog', e, s,
          {'logId': updated.id});
      invalidateCache();
      _onStorageError('Failed to update environment log.');
      _onChange();
    }));
    _onChange();
  }

  /// Re-inserts a previously deleted environment log without recording
  /// streak activity — undo flows already counted the original add.
  void readd(EnvironmentLog log) {
    _cached = [...all, log];
    unawaited(HiveService.addEnvironmentLog(log).then((_) {
      invalidateCache();
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report('HiveService.readdEnvironmentLog', e, s);
      invalidateCache();
      _onStorageError('Failed to restore environment log.');
      _onChange();
    }));
    _onChange();
  }

  /// Delete a single environment log entry.
  void deleteById(String id) {
    // Optimistically remove from cache so the entry disappears immediately.
    if (_cached != null) {
      _cached = _cached!.where((l) => l.id != id).toList();
    }
    unawaited(HiveService.deleteLog(id).then((_) {
      invalidateCache(); // next read comes from authoritative Hive box
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report('HiveService.deleteLog', e, s, {'logId': id});
      invalidateCache(); // revert — next read will show the entry again
      _onStorageError('Failed to delete log entry.');
      _onChange();
    }));
    _onChange();
  }

  /// Cascading delete used by [GrowRepository.removeGrowSpace] — drops
  /// the optimistic cache entries first so the UI reflects the removal
  /// immediately, then deletes from Hive in the background.
  void deleteForSpace(String spaceId) {
    if (_cached != null) {
      _cached = _cached!.where((l) => l.growSpaceId != spaceId).toList();
    }
    unawaited(HiveService.deleteLogsForSpace(spaceId).then((_) {
      invalidateCache();
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report('HiveService.deleteLogsForSpace', e, s,
          {'spaceId': spaceId});
      invalidateCache(); // revert optimistic filter on error
    }));
  }

  /// Log a reading across ALL grow spaces at once (FAB sheet, dashboard).
  void addBatch({
    required String Function() newId,
    required double? temperature,
    required double? humidity,
    String? notes,
  }) {
    final spaces = _getSpaces();
    final now = DateTime.now();
    final newLogs = spaces
        .map((space) => EnvironmentLog(
              id: newId(),
              growSpaceId: space.id,
              recordedAt: now,
              temperature: temperature,
              humidity: humidity,
              notes: notes,
            ))
        .toList();

    // Optimistic update: append all new logs to the cache immediately.
    _cached = [...all, ...newLogs];

    // Collect all Hive write futures so we can invalidate the cache
    // once they all complete (success or failure) and let the next
    // read reconcile with the authoritative Hive box state.
    final writeFutures = newLogs.map((log) {
      return HiveService.addEnvironmentLog(log)
          .catchError((Object e, StackTrace s) {
        ErrorReporter.report(
            'HiveService.addBatchEnvironmentLog', e, s,
            {'spaceId': log.growSpaceId});
        final spaceIdx =
            spaces.indexWhere((s) => s.id == log.growSpaceId);
        final name = spaceIdx != -1 ? spaces[spaceIdx].name : log.growSpaceId;
        _onStorageError('Failed to save environment log for $name.');
      });
    }).toList();

    Future.wait(writeFutures).whenComplete(invalidateCache);

    _onActivity();
    _onChange();
  }

  // ── Alerts ────────────────────────────────────

  /// Cancels the previous stale-env scheduled alert for this space and
  /// arms a new one to fire 48 h from [log.recordedAt].  Only runs
  /// when the env-alerts preference is enabled.
  void _rescheduleStaleAlert(EnvironmentLog log) {
    if (!KultivarApp.notifEnvAlertsEnabled.value) return;
    final spaces = _getSpaces();
    final space = spaces.where((s) => s.id == log.growSpaceId).firstOrNull;
    if (space == null) return;
    unawaited(
      NotificationService().scheduleStaleEnvAlert(
        spaceId: space.id,
        spaceName: space.name,
        fireAt: log.recordedAt.add(const Duration(hours: 48)),
      ),
    );
  }

  /// Checks whether [log] is outside the space's optimal thresholds
  /// and fires an immediate push notification if env-alerts are
  /// enabled and the space hasn't been alerted in the last 30 minutes.
  void _maybeFireAlert(EnvironmentLog log) {
    // Skip if the user has disabled env alerts.
    if (!KultivarApp.notifEnvAlertsEnabled.value) return;

    final spaces = _getSpaces();
    final space = spaces.where((s) => s.id == log.growSpaceId).firstOrNull;
    if (space == null) return;

    // Throttle: only fire once per 30 minutes per space.
    final lastAlert = _lastAlert[space.id];
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inMinutes < 30) {
      return;
    }

    // Build the alert message for each out-of-range metric.
    final issues = <String>[];

    if (log.temperature != null) {
      final displayTemp = fromStorageTemp(log.temperature!);
      final minDisplay = fromStorageTemp(space.tempMin);
      final maxDisplay = fromStorageTemp(space.tempMax);
      if (!space.isOptimalTemp(log.temperature!)) {
        final dir = log.temperature! < space.tempMin ? 'low' : 'high';
        issues.add(
          'Temp ${displayTemp.toStringAsFixed(1)}$tempUnitSuffix '
          '(range $minDisplay–${maxDisplay.toStringAsFixed(0)}$tempUnitSuffix) — too $dir',
        );
      }
    }

    if (log.humidity != null && !space.isOptimalHumidity(log.humidity!)) {
      final dir = log.humidity! < space.humidityMin ? 'low' : 'high';
      issues.add(
        'Humidity ${log.humidity!.toStringAsFixed(0)}% '
        '(range ${space.humidityMin.toStringAsFixed(0)}–${space.humidityMax.toStringAsFixed(0)}%) '
        '— too $dir',
      );
    }

    if (issues.isEmpty) return;

    _lastAlert[space.id] = DateTime.now();
    unawaited(
      NotificationService().showEnvironmentAlert(
        spaceName: space.name,
        spaceId: space.id,
        body: issues.join('  ·  '),
      ),
    );
  }
}
