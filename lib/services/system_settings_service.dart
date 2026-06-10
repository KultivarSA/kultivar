import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'error_reporter.dart';

/// Task #178 — thin wrapper over the `io.kultivar.app/system_settings`
/// MethodChannel registered in MainActivity.kt.
///
/// Exists for the notification-reliability UX:
///   * Samsung One UI (and other OEM skins) aggressively kill
///     background-scheduled notifications.  Exempting the app from
///     battery optimization is the documented fix, and the only way to
///     get there is a system settings deep-link.
///   * A user who denied POST_NOTIFICATIONS at the first prompt can't be
///     re-asked by the OS — the recovery path is the per-app
///     notification settings page.
///
/// Android-only by nature; every method no-ops (returns false) on web
/// and iOS so call sites don't need platform guards.
class SystemSettingsService {
  SystemSettingsService._();

  static const _channel = MethodChannel('io.kultivar.app/system_settings');

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Opens the per-app notification settings page (API 26+) or the app
  /// details page (older).  Returns true when the intent fired.
  static Future<bool> openNotificationSettings() async {
    if (!_isAndroid) return false;
    try {
      await _channel.invokeMethod<bool>('openNotificationSettings');
      return true;
    } catch (e, stack) {
      ErrorReporter.report(
          'SystemSettingsService.openNotificationSettings', e, stack);
      return false;
    }
  }

  /// Opens the system battery-optimization list so the user can exempt
  /// Kultivar.  Returns true when the intent fired.
  static Future<bool> openBatteryOptimizationSettings() async {
    if (!_isAndroid) return false;
    try {
      await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return true;
    } catch (e, stack) {
      ErrorReporter.report(
          'SystemSettingsService.openBatteryOptimizationSettings', e, stack);
      return false;
    }
  }

  /// True when the app is already exempt from battery optimization.
  /// Used to render the "done" state on the Settings tile.  Defaults to
  /// true on non-Android (no equivalent concept) so the prompt hides.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      return await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (e, stack) {
      ErrorReporter.report(
          'SystemSettingsService.isIgnoringBatteryOptimizations', e, stack);
      return false;
    }
  }
}
