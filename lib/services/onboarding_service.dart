import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const _key = 'onboarding_complete';

  // SharedPreferences keys used by StorageService to persist user data.
  static const _keyPlants     = 'plants';
  static const _keyGrowSpaces = 'grow_spaces';

  /// Returns true when onboarding has been completed.
  ///
  /// Treats existing SharedPreferences data (spaces or plants already saved)
  /// as proof that onboarding was done, even if the onboarding flag itself
  /// was wiped independently (e.g. during development hot-restarts or
  /// OS-level storage clears that only reset app preferences).
  /// This prevents the user from being sent back through onboarding and
  /// creating duplicate data on top of their existing records.
  static Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) return true;

    // Secondary check: if StorageService already persisted spaces or plants
    // the user has been through setup — mark complete now and return true.
    final hasData = _hasItems(prefs, _keyGrowSpaces) ||
        _hasItems(prefs, _keyPlants);
    if (hasData) {
      await prefs.setBool(_key, true);
      return true;
    }

    return false;
  }

  /// Returns true when [key] contains a non-empty JSON array in [prefs].
  static bool _hasItems(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return false;
      final list = jsonDecode(raw);
      return list is List && list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
