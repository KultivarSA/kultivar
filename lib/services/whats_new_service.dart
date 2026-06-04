import 'package:shared_preferences/shared_preferences.dart';

/// Detects "first launch after a Play Store update" and surfaces the
/// What's New sheet exactly once per upgrade.
///
/// State machine:
///
///   * **Fresh install** — no `_kLastSeenBuild` key exists yet.
///     [shouldShow] stashes the current buildNumber, returns `false`.
///     Rationale:  the welcome onboarding already covers v1 first run;
///     a second sheet would feel like double-onboarding.  See PR
///     discussion that picked "Option A — no v1.0 fallback content".
///
///   * **Repeat launch on the same build** — stored == current.
///     Returns `false` (no notification queued).
///
///   * **Launch after an update** — current > stored.  Returns `true`
///     **once**.  Caller is responsible for presenting the sheet and
///     then invoking [markSeen] to flip the stored value forward.
///
///   * **Downgrade** (current < stored — happens if a tester sideloads
///     an older AAB) — returns `false`.  Not worth alerting on; the
///     What's New for that older version was already shown at the
///     time the user originally upgraded to the higher build.
///
/// Stored as `int` (buildNumber == versionCode in pubspec.yaml).  We
/// intentionally do **not** track the semantic versionName ("1.0.0")
/// because Play increments versionCode mechanically with every
/// upload while the semantic version is only bumped on user-facing
/// releases.
abstract final class WhatsNewService {
  static const String _kLastSeenBuild = 'whats_new.last_seen_build';

  /// Should the What's New sheet be presented for the current build?
  ///
  /// [currentBuildNumber] is the `int` value of
  /// `PackageInfo.fromPlatform().buildNumber`.  We accept it as a
  /// parameter (rather than calling PackageInfo here) so unit tests
  /// can simulate version upgrades without mocking the plugin.
  ///
  /// Side effect on fresh install:  stashes [currentBuildNumber]
  /// straight into prefs so subsequent calls behave as "repeat
  /// launch on the same build".  This is the "Option A — no first-
  /// install fallback" decision in code form.
  static Future<bool> shouldShow(int currentBuildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_kLastSeenBuild);

    if (stored == null) {
      // Fresh install -- skip the sheet, plant the marker forward so
      // we treat any subsequent same-build launch as "already seen".
      await prefs.setInt(_kLastSeenBuild, currentBuildNumber);
      return false;
    }

    return currentBuildNumber > stored;
  }

  /// Persist [currentBuildNumber] as the last build the user has been
  /// shown.  Call this from the sheet's dismiss handler so the sheet
  /// doesn't re-appear on the next app start.
  static Future<void> markSeen(int currentBuildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSeenBuild, currentBuildNumber);
  }

  /// Test-only escape hatch.  Resets the stored build so the next
  /// [shouldShow] behaves as if this were a fresh install.  Wraps the
  /// SharedPreferences key in case future revisions add more keys.
  static Future<void> resetForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSeenBuild);
  }
}
