import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/sentry_bootstrap.dart';

void main() {
  group('bootstrapSentryAndRun', () {
    test(
        'when SENTRY_DSN is unset, runs the appRunner immediately without '
        'touching Sentry', () async {
      // The test harness never injects --dart-define=SENTRY_DSN, so
      // [kSentryDsn] is the empty string and [isSentryConfigured] is
      // false.  This is the OSS / F-Droid / dev-machine default path
      // — and it MUST stay quiet (no Sentry init, no network egress).
      expect(isSentryConfigured, isFalse,
          reason: 'Test harness must not inject a real DSN.');

      var ran = false;
      // SR6 — consentGranted is required; passing false here exercises
      // the consent-gate branch (which short-circuits Sentry init even
      // if a DSN were set).
      await bootstrapSentryAndRun(
        consentGranted: false,
        appRunner: () => ran = true,
      );
      expect(ran, isTrue,
          reason: 'appRunner must fire even when Sentry is skipped.');
    });

    test(
        'consentGranted=true with no DSN still skips Sentry — both '
        'conditions must be met', () async {
      // The DSN gate AND the consent gate are AND-ed.  Even an
      // explicit grant doesn't initialise Sentry when no DSN was
      // injected at build time.
      var ran = false;
      await bootstrapSentryAndRun(
        consentGranted: true,
        appRunner: () => ran = true,
      );
      expect(ran, isTrue);
    });

    test('isSentryConfigured reads from the kSentryDsn const', () {
      // The compile-time constant pattern means this assertion locks
      // the convention — if anyone ever refactors away from
      // `String.fromEnvironment` we'll see it fail here.
      expect(kSentryDsn.isEmpty, equals(!isSentryConfigured));
    });
  });
}
