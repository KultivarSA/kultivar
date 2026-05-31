import 'package:flutter/foundation.dart';

/// Q3 — Single sink for non-fatal errors.
///
/// Every `catch` block that previously did `debugPrint('… failed: $e')`
/// now routes through here.  Three reasons:
///
/// 1. **Consistency** — the same `[component] action failed: <message>`
///    line shape across the whole codebase, so logs in a release build
///    or in a future crash report are immediately searchable.
/// 2. **Release safety** — `debugPrint` is a no-op in release mode
///    *only when you use the Flutter-recommended `debugPrint` symbol
///    AND don't log secrets in the message string*.  Routing through
///    a single function lets us add release-mode guards once instead
///    of remembering to wrap 30+ catch blocks individually.
/// 3. **Pluggable backend** — when we wire up Sentry / Crashlytics
///    later, we register a single [Sink] here and every catch block
///    starts reporting automatically.  No app-wide refactor needed.
///
/// Usage:
///
/// ```dart
/// try {
///   await someAsyncIo();
/// } catch (e, stack) {
///   ErrorReporter.report(
///     'StorageService.savePlants',  // operation
///     e,
///     stack,                         // optional but encouraged
///     extras: {'count': plants.length},
///   );
/// }
/// ```
///
/// The class is purely static — no `init()` required.  Override the
/// sink in tests (or for production telemetry) by calling
/// [ErrorReporter.setSink].
abstract final class ErrorReporter {
  /// Sink type — receives a finalised, formatted error record.
  ///
  /// Default implementation logs through `debugPrint` (guarded by
  /// [kDebugMode] so release builds stay silent).  Production builds
  /// can swap in a Sentry / Firebase / Crashlytics handler via
  /// [setSink].
  static void Function(ErrorRecord record) _sink = _defaultDebugSink;

  /// Replaces the current sink.  Returns the previous sink so callers
  /// (typically tests) can restore it via `addTearDown`.
  static void Function(ErrorRecord record) setSink(
      void Function(ErrorRecord record) next) {
    final prev = _sink;
    _sink = next;
    return prev;
  }

  /// Resets to the built-in debug-only sink.  Exposed so test teardown
  /// is one call.
  static void resetSink() => _sink = _defaultDebugSink;

  /// Report a non-fatal error.
  ///
  /// [operation] is a short identifier of the failing site — typically
  /// `'<Class>.<method>'`.  Used as the search anchor in logs and as
  /// the breadcrumb name in third-party reporters.
  ///
  /// [error] is the caught object (any type).  [stackTrace] is
  /// optional but encouraged — Sentry / Crashlytics symbolicate
  /// stacks if you provide them.
  ///
  /// [extras] is a free-form map of context the report should carry
  /// (counts, IDs, file paths).  Avoid putting personally identifying
  /// data in here — these maps end up in remote telemetry once
  /// Sentry/Crashlytics is wired in.
  static void report(
    String operation,
    Object error, [
    StackTrace? stackTrace,
    Map<String, Object?>? extras,
  ]) {
    _sink(ErrorRecord(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      extras: extras,
    ));
  }

  /// Built-in sink — formatted log line, debug-only.
  static void _defaultDebugSink(ErrorRecord record) {
    // Hot path is `debugPrint`, which itself is debug-only when used
    // alongside `kDebugMode`.  We gate explicitly so a future change
    // to debugPrint's behaviour doesn't silently start leaking error
    // strings into release logs.
    if (!kDebugMode) return;
    final extras = record.extras;
    final extrasStr = (extras == null || extras.isEmpty)
        ? ''
        : ' · ${extras.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    debugPrint('[error] ${record.operation} → ${record.error}$extrasStr');
    final stack = record.stackTrace;
    if (stack != null) {
      // Stack traces can be many lines — let debugPrint's throttle
      // handle them so we don't blow the Android log buffer when an
      // error cascades.
      debugPrint(stack.toString());
    }
  }
}

/// Immutable record passed to the registered [ErrorReporter] sink.
class ErrorRecord {
  final String operation;
  final Object error;
  final StackTrace? stackTrace;
  final Map<String, Object?>? extras;

  const ErrorRecord({
    required this.operation,
    required this.error,
    this.stackTrace,
    this.extras,
  });
}
