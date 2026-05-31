import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/environment_log.dart';
import '../models/environment_log_adapter.dart';

class HiveService {
  static const _envBoxName = 'environment_logs';
  static Box<EnvironmentLog>? _envBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapter only once
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(EnvironmentLogAdapter());
    }

    _envBox = await Hive.openBox<EnvironmentLog>(_envBoxName);
  }

  /// Test-only initializer.  Bypasses `Hive.initFlutter()` (which
  /// requires the path-provider platform plugin) and instead uses
  /// the raw `Hive.init(path)` so the box can be opened against a
  /// caller-supplied temp directory.  Used by widget tests that need
  /// to pump screens reading from `repo.environmentLogs` without
  /// dragging the path-provider channel mock into every test.
  ///
  /// Pair every call with [resetForTests] in tearDown so a stale box
  /// doesn't leak between tests.
  @visibleForTesting
  static Future<void> initForTests(String tempPath) async {
    Hive.init(tempPath);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(EnvironmentLogAdapter());
    }
    _envBox = await Hive.openBox<EnvironmentLog>(_envBoxName);
  }

  /// Test-only teardown.  Closes the box and clears the static
  /// reference so the next test starts from a clean slate.
  @visibleForTesting
  static Future<void> resetForTests() async {
    await _envBox?.close();
    _envBox = null;
  }

  static Box<EnvironmentLog> get envBox {
    assert(_envBox != null, 'HiveService.init() must be called first');
    return _envBox!;
  }

  // ── Environment logs ──────────────────────────

  static Future<void> addEnvironmentLog(EnvironmentLog log) async {
    await envBox.put(log.id, log);
  }

  static Future<void> addEnvironmentLogs(List<EnvironmentLog> logs) async {
    final map = {for (final l in logs) l.id: l};
    await envBox.putAll(map);
  }

  static List<EnvironmentLog> allEnvironmentLogs() {
    return envBox.values.toList();
  }

  static List<EnvironmentLog> logsForSpace(String spaceId) {
    return envBox.values.where((l) => l.growSpaceId == spaceId).toList();
  }

  static Future<void> deleteLog(String id) async {
    await envBox.delete(id);
  }

  /// Deletes every environment log that belongs to [spaceId].
  /// Called when a grow space is permanently removed so no orphan
  /// records accumulate in the box.
  static Future<void> deleteLogsForSpace(String spaceId) async {
    final keys = envBox.values
        .where((l) => l.growSpaceId == spaceId)
        .map((l) => l.id)
        .toList();
    if (keys.isEmpty) return;
    await envBox.deleteAll(keys);
  }

  static Future<void> clearAllLogs() async {
    await envBox.clear();
  }

  /// One-time migration from shared_preferences
  /// JSON list into Hive. Safe to call multiple
  /// times — skips if already migrated.
  static Future<void> migrateFromJson(List<EnvironmentLog> jsonLogs) async {
    if (envBox.isNotEmpty) return; // already done
    if (jsonLogs.isEmpty) return;
    await addEnvironmentLogs(jsonLogs);
  }
}
