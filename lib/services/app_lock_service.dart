import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'error_reporter.dart';

class AppLockService {
  static const _kEnabled       = 'app_lock_enabled';
  static const _kPin           = 'app_lock_pin';
  static const _kUseBiometric  = 'app_lock_use_biometric';

  // ── Enabled flag ────────────────────────────────

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  // ── PIN ─────────────────────────────────────────

  static Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPin);
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPin, pin);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEnabled);
    await prefs.remove(_kPin);
    await prefs.remove(_kUseBiometric);
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await getPin();
    return stored != null && stored == pin;
  }

  // ── Biometric preference ─────────────────────────

  static Future<bool> useBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kUseBiometric) ?? false;
  }

  static Future<void> setUseBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseBiometric, value);
  }

  // ── Biometric capability ─────────────────────────

  static Future<bool> canUseBiometric() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e, st) {
      // Capability checks failing is rarely user-actionable but is
      // useful diagnostic data -- a missing FragmentActivity host or a
      // device-policy block both surface here first.
      ErrorReporter.report(
        'AppLockService.canUseBiometric',
        e,
        st,
      );
      return false;
    }
  }

  static Future<bool> authenticateWithBiometric() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      // local_auth 3.x flattened the options into named params on
      // authenticate() — `stickyAuth` is now `persistAcrossBackgrounding`,
      // and `AuthenticationOptions` is constructed internally.
      return await auth.authenticate(
        localizedReason: 'Unlock Kultivar',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e, st) {
      // Bug #168 -- swallowing every exception silently hid the
      // FragmentActivity-required error for the entire pre-launch
      // window; "biometric failed" looked like a user-side issue but
      // was actually a missing host-activity superclass.  We now log
      // structured detail so similar plugin-host mismatches surface
      // immediately.
      //
      // Filter out the codes that correspond to normal user-flow
      // events (cancellation, lockout retry, no enrolment) so the
      // error log doesn't get polluted.  Everything else gets a
      // structured report -- particularly `uiUnavailable`, which is
      // exactly what was firing when MainActivity extended the wrong
      // superclass.
      const userDrivenCodes = <LocalAuthExceptionCode>{
        LocalAuthExceptionCode.userCanceled,
        LocalAuthExceptionCode.systemCanceled,
        LocalAuthExceptionCode.timeout,
        LocalAuthExceptionCode.userRequestedFallback,
        LocalAuthExceptionCode.noCredentialsSet,
        LocalAuthExceptionCode.noBiometricsEnrolled,
        LocalAuthExceptionCode.temporaryLockout,
        LocalAuthExceptionCode.biometricLockout,
      };
      if (!userDrivenCodes.contains(e.code)) {
        ErrorReporter.report(
          'AppLockService.authenticateWithBiometric',
          e,
          st,
          <String, Object?>{
            'auth_code': e.code.name,
            'description': e.description,
            'details': e.details?.toString(),
          },
        );
      }
      return false;
    } catch (e, st) {
      // Non-LocalAuth exceptions (assertion failures, channel teardown)
      // are always worth reporting -- they shouldn't reach here under
      // normal operation.
      ErrorReporter.report(
        'AppLockService.authenticateWithBiometric',
        e,
        st,
      );
      return false;
    }
  }
}
