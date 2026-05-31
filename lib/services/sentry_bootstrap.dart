import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'error_reporter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Q12 — Sentry / Crashlytics adapter for ErrorReporter
//
// Q3 left `ErrorReporter.setSink(...)` ready as the single seam where
// non-fatal errors fan out to any backend.  This module is the first
// concrete backend wired through it:
//
//   • Reads `SENTRY_DSN` from `--dart-define` at build time.
//   • If the DSN is empty (the default in dev / OSS contributors'
//     machines / CI), Sentry is never initialised and the built-in
//     debug-only `print` sink stays in place — no network egress, no
//     unexpected SDK side effects.
//   • If the DSN is set, `SentryFlutter.init(...)` wraps `appRunner`
//     so unhandled framework errors are also captured automatically,
//     and `ErrorReporter.setSink` is repointed at a thin adapter that
//     forwards each [ErrorRecord] to `Sentry.captureException` with
//     the `operation` tag + `extras` map preserved.
//
// Swapping the backend (e.g. Firebase Crashlytics) is a one-file
// change — the rest of the app doesn't know which reporter is active.
// ─────────────────────────────────────────────────────────────────────────────

/// DSN injected at build time:
///
///   flutter run --dart-define=SENTRY_DSN=https://example@o0.ingest.sentry.io/0
///
/// When unset, this resolves to the empty string and the bootstrapper
/// skips Sentry entirely.  Keeping it as a compile-time const lets the
/// dead-code branch be tree-shaken from release builds where Sentry
/// will not be used (typically: F-Droid / OSS-only forks).
const String kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// True when a DSN was supplied at build time.  Cheap public check
/// callers can use without importing the Sentry SDK.
bool get isSentryConfigured => kSentryDsn.isNotEmpty;

/// Initialises Sentry (when [kSentryDsn] is set AND the user has
/// granted telemetry consent) and runs [appRunner] inside the Sentry
/// error zone.  Call this from `main()` instead of invoking
/// `runApp(...)` directly.
///
/// Behaviour matrix:
///
/// | DSN set | consent       | result                                        |
/// |---------|---------------|-----------------------------------------------|
/// | no      | any           | no-op — runs the appRunner immediately        |
/// | yes     | granted       | Sentry initialised, sink installed            |
/// | yes     | declined / notAsked | no Sentry — appRunner runs normally     |
///
/// [release] is forwarded to `options.release` so the Sentry UI can
/// group issues by app version.  Typically wired to `packageInfo.version`.
///
/// [consentGranted] is the SR6 gate.  When the user later flips
/// consent in Settings, the new state takes effect on next app launch
/// — `SentryFlutter.init` wraps `appRunner` in a `runZonedGuarded`
/// error zone and can't be applied retroactively to an already-running
/// app.  The Settings copy reflects this with a "takes effect on
/// restart" note.
Future<void> bootstrapSentryAndRun({
  required void Function() appRunner,
  required bool consentGranted,
  String? release,
  double tracesSampleRate = 0.1,
}) async {
  if (!isSentryConfigured || !consentGranted) {
    appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = kSentryDsn;
      // 'production' in release builds; 'development' otherwise.  This
      // lets the Sentry dashboard filter dev noise out of prod alerts
      // without forcing the caller to set the env var.
      options.environment = kReleaseMode ? 'production' : 'development';
      if (release != null && release.isNotEmpty) {
        options.release = release;
      }
      options.tracesSampleRate = tracesSampleRate;
      // PII is off by default — Kultivar's error context is entirely
      // technical (operation names, counts, IDs).  Explicitly setting
      // it false here documents the choice for future contributors.
      options.sendDefaultPii = false;
    },
    appRunner: () {
      // Install the sink *after* Sentry is initialised so the very
      // first ErrorReporter.report() call routes correctly.  Anything
      // reported before this point goes to the default debug sink.
      ErrorReporter.setSink(_sentrySink);
      appRunner();
    },
  );
}

/// Adapter — turns an [ErrorRecord] into a Sentry capture.  Kept
/// top-level + non-async so it has no startup cost when the DSN is
/// unset (it's never installed in that case).
void _sentrySink(ErrorRecord record) {
  Sentry.captureException(
    record.error,
    stackTrace: record.stackTrace,
    withScope: (scope) {
      // `operation` is the per-callsite identifier we already pass
      // everywhere (e.g. `StorageService.savePlants`).  Pinning it as
      // a tag lets Sentry's "Top 10 issues by tag" view group errors
      // by failure site without grouping on the exception message
      // (which can vary across locales).
      scope.setTag('operation', record.operation);
      final extras = record.extras;
      if (extras != null && extras.isNotEmpty) {
        // `setExtra` was deprecated in Sentry 8 in favour of
        // structured Contexts.  We collapse the whole [ErrorRecord]
        // extras map into a single 'kultivar' context so it stays
        // grouped under one collapsible block in the Sentry UI
        // rather than scattering across separate fields.
        scope.setContexts('kultivar', Map<String, dynamic>.from(extras));
      }
    },
  );
}
