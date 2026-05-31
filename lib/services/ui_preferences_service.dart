import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/time_window.dart';

class UiPreferencesService {
  static const _bandsKey = 'show_confidence_bands';
  static const _tempUnitKey = 'use_fahrenheit';
  static const _hiddenSeriesKey = 'hidden_series';
  static const _timeWindowKey = 'time_window_index';

  // ── Confidence bands ─────────────────────────────
  static Future<bool> loadShowBands() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bandsKey) ?? true;
  }

  static Future<void> saveShowBands(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bandsKey, value);
  }

  // ── Temperature unit ──────────────────────────────
  static Future<bool> loadUseFahrenheit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tempUnitKey) ?? false;
  }

  static Future<void> saveUseFahrenheit(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tempUnitKey, value);
  }

  // ── Time window ───────────────────────────────────
  static Future<TimeWindow> loadTimeWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_timeWindowKey) ?? TimeWindow.last30.index;
    return TimeWindow.values[index.clamp(0, TimeWindow.values.length - 1)];
  }

  static Future<void> saveTimeWindow(TimeWindow window) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeWindowKey, window.index);
  }

  // ── Theme mode ────────────────────────────────────
  static const _themeModeKey = 'theme_mode';

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeModeKey)) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      _ => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }

  // ── Notification preferences ──────────────────────
  static const _notifDryingKey = 'notif_drying';
  static const _notifCuringKey = 'notif_curing';
  static const _notifBurpingKey = 'notif_burping';

  static Future<bool> loadNotifDrying() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifDryingKey) ?? true;
  }

  static Future<void> saveNotifDrying(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifDryingKey, value);
  }

  static Future<bool> loadNotifCuring() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifCuringKey) ?? true;
  }

  static Future<void> saveNotifCuring(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifCuringKey, value);
  }

  static Future<bool> loadNotifBurping() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifBurpingKey) ?? true;
  }

  static Future<void> saveNotifBurping(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifBurpingKey, value);
  }

  // ── Watering / Feeding reminders ─────────────────
  static const _notifWateringKey = 'notif_watering';
  static const _notifFeedingKey  = 'notif_feeding';
  static const _notifIpmKey      = 'notif_ipm';

  static Future<bool> loadNotifWatering() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifWateringKey) ?? true;
  }

  static Future<void> saveNotifWatering(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifWateringKey, value);
  }

  static Future<bool> loadNotifFeeding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifFeedingKey) ?? true;
  }

  static Future<void> saveNotifFeeding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifFeedingKey, value);
  }

  static Future<bool> loadNotifIpm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifIpmKey) ?? true;
  }

  static Future<void> saveNotifIpm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifIpmKey, value);
  }

  // ── Last backup timestamp ────────────────────────

  static const _lastBackupKey = 'last_backup_time';

  static Future<DateTime?> loadLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastBackupKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  static Future<void> saveLastBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, time.millisecondsSinceEpoch);
  }

  // ── Target harvest reminders ──────────────────────
  static const _notifTargetHarvestKey = 'notif_target_harvest';

  static Future<bool> loadNotifTargetHarvest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifTargetHarvestKey) ?? true;
  }

  static Future<void> saveNotifTargetHarvest(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifTargetHarvestKey, value);
  }

  // ── Environment alert ─────────────────────────────
  static const _envAlertsKey = 'notif_env_alerts';

  static Future<bool> loadEnvAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_envAlertsKey) ?? true;
  }

  static Future<void> saveEnvAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_envAlertsKey, value);
  }

  // ── Hidden chart series ───────────────────────────
  static Future<List<String>> loadHiddenSeries() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenSeriesKey) ?? [];
  }

  static Future<void> saveHiddenSeries(List<String> series) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenSeriesKey, series);
  }

  // ── Community data sharing ────────────────────────
  //
  // Null = user has not yet been asked (show the prompt).
  // true = user opted in.
  // false = user declined (never ask again).
  static const _communityShareKey = 'community_share_enabled';

  static Future<bool?> loadCommunityShareEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Returns null when the key doesn't exist yet (never asked).
    if (!prefs.containsKey(_communityShareKey)) return null;
    return prefs.getBool(_communityShareKey);
  }

  static Future<void> saveCommunityShareEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityShareKey, value);
  }

  // ── Notification snooze duration ───────────────────
  //
  // How many hours to defer a reminder when the user taps "Snooze" on a
  // care notification.  Defaults to 4 — matches the original hardcoded
  // value so existing users see no behavioural change.
  static const _snoozeHoursKey = 'snooze_duration_hours';

  /// Valid choices presented in the Settings dropdown.
  static const List<int> snoozeHourChoices = [1, 2, 4, 8];

  static Future<int> loadSnoozeHours() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_snoozeHoursKey) ?? 4;
    // Clamp to a sensible range so a stray write can't end up scheduling
    // a notification for next year (or instantly).
    if (raw < 1) return 1;
    if (raw > 24) return 24;
    return raw;
  }

  static Future<void> saveSnoozeHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeHoursKey, hours.clamp(1, 24));
  }

  // ── F11 — Locale persistence ──────────────────────
  //
  // Stored as a BCP-47 language tag (`en`, `es`, `de`).  Empty string
  // is the "system default" sentinel — restores the platform locale.
  // Anything not in [_supportedLocales] silently falls back to system
  // default to keep the app from getting stuck in a broken state if
  // the saved value is stale after a translation is removed.
  static const _localeKey = 'ui_locale_tag';
  // F11 — keep in sync with `lib/l10n/app_*.arb` and the picker
  // options in settings_screen.dart.  Anything not in this set is
  // treated as "system default" so a stale write can't lock the app
  // into a locale we no longer ship translations for.
  static const Set<String> supportedLocales = {
    'en', 'es', 'de', 'fr', 'pt', 'it', 'nl',
  };

  /// Returns the persisted locale tag, or null if "system default".
  static Future<String?> loadLocaleTag() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localeKey);
    if (raw == null || raw.isEmpty) return null;
    if (!supportedLocales.contains(raw)) return null;
    return raw;
  }

  /// Persists the chosen locale tag.  Pass `null` (or empty) to reset
  /// to system default.
  static Future<void> saveLocaleTag(String? tag) async {
    final prefs = await SharedPreferences.getInstance();
    if (tag == null || tag.isEmpty) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, tag);
    }
  }

  // ── Currency symbol ────────────────────────────────
  //
  // Stored as a short string prefix (e.g. '£', '$', '€').  Returns
  // null when the key has never been written — lets the caller
  // distinguish "user explicitly chose £" from "fresh install,
  // pick a sensible default for the OS locale" (see CurrencyService
  // SA2 — auto-defaults Rand for ZA, USD for US, EUR for eurozone,
  // and falls back to £ when the locale is unknown).
  static const _currencyKey = 'currency_symbol';

  static Future<String?> loadCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey);
  }

  static Future<void> saveCurrencySymbol(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
  }

  // ── Demo mode ─────────────────────────────────────
  static const _isDemoModeKey = 'is_demo_mode';

  static Future<bool> loadIsDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDemoModeKey) ?? false;
  }

  static Future<void> saveIsDemoMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDemoModeKey, value);
  }
}
