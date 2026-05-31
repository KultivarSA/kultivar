import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/telemetry_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // SR6 — TelemetryConsentService is the only thing standing between
  // a user who never opted in and Sentry / future analytics SDKs.
  // These tests pin the contract that downstream code depends on:
  //
  //   1. Defaults to `notAsked` (never `granted` by accident).
  //   2. Persists explicit decisions across restarts.
  //   3. notifyListeners fires on every state change.
  //   4. `_persist` is idempotent — same-value writes don't spam
  //      listeners or trigger redundant disk I/O.

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TelemetryConsentService — default state', () {
    test('defaults to notAsked on a fresh install', () async {
      final svc = TelemetryConsentService();
      await svc.init();
      expect(svc.state, TelemetryConsentState.notAsked);
      expect(svc.hasGranted, isFalse);
      expect(svc.hasBeenAsked, isFalse);
      expect(svc.isInitialised, isTrue);
    });

    test('isInitialised is false before init() resolves', () {
      final svc = TelemetryConsentService();
      expect(svc.isInitialised, isFalse);
    });
  });

  group('TelemetryConsentService — persistence', () {
    test('grant() persists and reloads as granted', () async {
      final first = TelemetryConsentService();
      await first.init();
      await first.grant();

      // Simulate app restart: new service instance, same prefs store.
      final second = TelemetryConsentService();
      await second.init();
      expect(second.state, TelemetryConsentState.granted);
      expect(second.hasGranted, isTrue);
      expect(second.hasBeenAsked, isTrue);
    });

    test('decline() persists and reloads as declined', () async {
      final first = TelemetryConsentService();
      await first.init();
      await first.decline();

      final second = TelemetryConsentService();
      await second.init();
      expect(second.state, TelemetryConsentState.declined);
      expect(second.hasGranted, isFalse);
      expect(second.hasBeenAsked, isTrue,
          reason: 'declined still counts as "asked" — sheet must not '
              'reappear on next launch');
    });

    test('reset() returns to notAsked across restarts', () async {
      final first = TelemetryConsentService();
      await first.init();
      await first.grant();
      await first.reset();

      final second = TelemetryConsentService();
      await second.init();
      expect(second.state, TelemetryConsentState.notAsked);
      expect(second.hasBeenAsked, isFalse);
    });

    test('unrecognised persisted value falls back to notAsked', () async {
      // Simulate a future version writing a state name this build
      // doesn't know about — must NOT crash and must NOT silently
      // grant consent.
      SharedPreferences.setMockInitialValues({
        'telemetry_consent_v1': 'someFutureState',
      });
      final svc = TelemetryConsentService();
      await svc.init();
      expect(svc.state, TelemetryConsentState.notAsked,
          reason: 'unknown enum names must downgrade to the safe '
              'no-telemetry default');
    });
  });

  group('TelemetryConsentService — notification semantics', () {
    test('grant() notifies listeners exactly once', () async {
      final svc = TelemetryConsentService();
      await svc.init();
      var ticks = 0;
      svc.addListener(() => ticks++);
      await svc.grant();
      expect(ticks, 1);
    });

    test('granting twice is idempotent — no second notification',
        () async {
      final svc = TelemetryConsentService();
      await svc.init();
      await svc.grant();
      var ticks = 0;
      svc.addListener(() => ticks++);
      await svc.grant();
      expect(ticks, 0,
          reason: 'same-state writes must short-circuit before disk + '
              'listener fan-out');
    });

    test('flipping grant → decline → grant fires three notifications',
        () async {
      final svc = TelemetryConsentService();
      await svc.init();
      var ticks = 0;
      svc.addListener(() => ticks++);
      await svc.grant();
      await svc.decline();
      await svc.grant();
      expect(ticks, 3);
      expect(svc.hasGranted, isTrue);
    });
  });
}
