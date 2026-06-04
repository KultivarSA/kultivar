import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Captures every Flutter framework assertion + uncaught async error to a
/// local file in the app's documents directory.
///
/// Intent (Marco's S22 testing): the FAB add-space / add-plant flow keeps
/// hitting `_dependents.isEmpty` despite layered safety nets, and the device
/// is untethered from `flutter logs`.  We want a tap-to-share log that
/// surfaces the *exact* stack trace + widget tree path of the next crash,
/// without requiring a Sentry account or rebuilding from source.
///
/// Behaviour:
///   * Installs handlers in [install], from `main()` before any UI.
///   * Appends each error to `kultivar-crash.log` in the docs dir.
///   * Keeps the file capped at ~64 KB (rolls oldest half on overflow).
///   * Exposes [readLog] / [logFile] / [clear] for the Settings share-tile.
///   * Completely separate from Sentry — works in debug + release, with or
///     without DSN, regardless of telemetry consent (the log never leaves
///     the device unless the user explicitly taps share).
abstract final class LocalCrashLog {
  static const _filename = 'kultivar-crash.log';
  static const _maxBytes = 64 * 1024;

  static bool _installed = false;
  static File? _cachedFile;

  /// One-time install.  Idempotent.
  static Future<void> install() async {
    if (_installed) return;
    _installed = true;

    // Resolve + cache the file path so each capture doesn't pay an
    // async PathProvider hop (FlutterError.onError is synchronous).
    try {
      final dir = await getApplicationDocumentsDirectory();
      _cachedFile = File('${dir.path}/$_filename');
    } catch (_) {
      // If we can't resolve docs dir, fall through — captures become
      // no-ops but install() must not throw and break startup.
    }

    final priorFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Always defer to the existing handler first so the standard
      // red-screen-of-death still renders and other listeners (Sentry,
      // dev-tools) keep firing.
      priorFlutterHandler?.call(details);
      _captureSync(
        kind: 'FlutterError',
        message: details.exceptionAsString(),
        stack: details.stack,
        library: details.library,
        context: details.context?.toString(),
      );
    };

    final priorPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _captureSync(
        kind: 'AsyncUncaught',
        message: error.toString(),
        stack: stack,
      );
      return priorPlatformHandler?.call(error, stack) ?? false;
    };
  }

  /// Returns the log file path, or null if [install] hasn't been called
  /// yet (or docs-dir resolution failed during install).
  static File? get logFile => _cachedFile;

  /// Reads the full log as a string.  Returns an empty string if the
  /// file doesn't exist yet.  Cheap enough to call from the share sheet
  /// even on the UI thread (capped at ~64 KB).
  static Future<String> readLog() async {
    final f = _cachedFile;
    if (f == null) return '';
    if (!await f.exists()) return '';
    try {
      return await f.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Write a manual diagnostic note (non-crash) to the same log file.
  ///
  /// Used to surface state snapshots that help debug visual bugs which
  /// don't throw assertions -- e.g. a chart that renders empty despite
  /// having data.  Marco taps Share Diagnostics, the log carries the
  /// snapshot to the next debugging round.
  static void info(String tag, String message) {
    _captureSync(kind: 'Info ($tag)', message: message);
  }

  /// Wipes the log.  Used by the "Clear log" action.
  static Future<void> clear() async {
    final f = _cachedFile;
    if (f == null) return;
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort.
    }
  }

  // ── Internal capture helpers ─────────────────────────────────────────

  static void _captureSync({
    required String kind,
    required String message,
    StackTrace? stack,
    String? library,
    String? context,
  }) {
    final f = _cachedFile;
    if (f == null) return;
    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('[${DateTime.now().toIso8601String()}] $kind')
      ..writeln('msg: $message');
    if (library != null && library.isNotEmpty) buf.writeln('lib: $library');
    if (context != null && context.isNotEmpty) buf.writeln('ctx: $context');
    if (stack != null) {
      buf
        ..writeln('stack:')
        ..writeln(stack.toString().trim());
    }
    final entry = buf.toString();
    try {
      f.writeAsStringSync(entry, mode: FileMode.append, flush: true);
      _maybeRollSync(f);
    } catch (_) {
      // Last-resort: don't crash inside the crash handler.
    }
  }

  /// If the log has grown past [_maxBytes], drop the oldest half so we
  /// never grow without bound (cheap synchronous truncation).
  static void _maybeRollSync(File f) {
    try {
      final stat = f.statSync();
      if (stat.size <= _maxBytes) return;
      final all = f.readAsStringSync();
      // Cut at the first '---' delimiter past the midpoint so we don't
      // truncate mid-entry.
      final mid = all.length ~/ 2;
      var cut = all.indexOf('\n---\n', mid);
      cut = (cut < 0) ? mid : cut + 1; // keep the '---' line as new top.
      f.writeAsStringSync(all.substring(cut), flush: true);
    } catch (_) {
      // Best-effort.
    }
  }
}
