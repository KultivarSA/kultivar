// Task #87 — In-app review prompt.
//
// Asks the user to rate Kultivar on the App Store / Play Store at a
// high-satisfaction moment — specifically after they tap "View
// Grow Report" on a completed harvest.  The completed Grow Report is
// the payoff of the entire app: a polished, shareable PDF of months
// of work.  It's the only moment where "rate this app" lands as
// "yes, this app deserves it" rather than as the usual mid-flow
// interruption that earns one-star revenge ratings.
//
// Trigger policy:
//
//   1. The user has at least ONE completed harvest in the repo.
//      (Demo-mode users — checked via `KultivarApp.isDemoModeNotifier`
//      — are excluded; the sample data isn't theirs to rate the app
//      on.)
//   2. They've used the app for ≥ 7 days (`firstLaunchAt` is stored
//      on first init; we never prompt sooner).
//   3. We haven't asked them in the last 90 days
//      (`lastPromptAt`).  Apple's framework caps at 3 prompts /
//      365 days regardless of how often we call requestReview, so
//      our 90-day cooldown is the *inner* limit — we want to spread
//      the three Apple-permitted prompts across the year.
//   4. They've never explicitly declined "Rate Kultivar" from
//      Settings (`hasDeclined`).  Once they say "no thanks", we
//      never ask again automatically — Settings has a manual entry
//      so they can opt in later if they change their mind.
//
// What happens when we call [maybePrompt]:
//
//   • If all four conditions hold, `InAppReview.instance.requestReview()`
//     fires the native UI.  We update `lastPromptAt` immediately
//     (regardless of whether the user actually rates) so we don't
//     re-ask if they navigate away and come back.
//   • Otherwise the call is a no-op.  No logs, no banners — silently
//     skip.  The caller doesn't need to know which condition failed.
//
// On unsupported platforms (web, desktop), `isAvailable()` returns
// false and we no-op too.

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plant.dart';
import '../repository/grow_repository.dart';

class ReviewPromptService {
  ReviewPromptService._();

  // ── Storage keys ──────────────────────────────────────────────────
  static const _firstLaunchKey = 'review_prompt.first_launch_iso';
  static const _lastPromptKey = 'review_prompt.last_prompt_iso';
  static const _hasDeclinedKey = 'review_prompt.has_declined';

  // ── Tunables ──────────────────────────────────────────────────────
  /// We wait at least this long after first launch before asking.
  /// Users who churn in week one shouldn't see a prompt at all.
  static const _minDaysSinceFirstLaunch = 7;

  /// Wait at least this long between consecutive prompts.  Inner
  /// limit, sits below Apple's 3-per-365-days cap.
  @visibleForTesting
  static const minDaysBetweenPrompts = 90;

  /// In-memory cache of the `InAppReview` shim so callers don't
  /// re-allocate on every Grow Report view.
  static final InAppReview _reviewer = InAppReview.instance;

  /// Records the first-launch date the very first time it's called.
  /// Cheap to call on every app start — does nothing if already set.
  /// Wire from main() after SharedPreferences is available.
  static Future<void> recordFirstLaunchIfMissing() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_firstLaunchKey) != null) return;
    await prefs.setString(_firstLaunchKey, DateTime.now().toIso8601String());
  }

  /// Manual user-driven entry from Settings.  Fires the native
  /// prompt unconditionally (well — only if available on the
  /// platform).  Use for a "Rate Kultivar" tile that users tap
  /// themselves; bypasses every cooldown.
  static Future<void> showManualPrompt() async {
    if (!await _reviewer.isAvailable()) return;
    await _reviewer.requestReview();
    // Update lastPromptAt so an automatic prompt doesn't fire on
    // the heels of a manual one.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptKey, DateTime.now().toIso8601String());
    // Clear the declined flag — by tapping the Settings entry, the
    // user has implicitly re-opted-in to being asked.
    await prefs.setBool(_hasDeclinedKey, false);
  }

  /// User said "no thanks" via a Settings-side opt-out toggle.
  /// Suppresses every future automatic prompt.
  static Future<void> recordDecline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasDeclinedKey, true);
  }

  /// Whether the user has explicitly declined automatic prompts.
  /// Read-only — the Settings screen uses this to decorate the
  /// toggle's current state.
  static Future<bool> hasDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasDeclinedKey) ?? false;
  }

  /// The heart of the policy.  Call from the Grow Report viewer
  /// after the user has dwelt on the share / save screen for a
  /// moment — that's the satisfaction signal.
  ///
  /// Returns true if the prompt was actually triggered, false if
  /// any guard short-circuited.  Callers shouldn't act on the
  /// return value — it's purely for tests.
  static Future<bool> maybePrompt({
    required GrowRepository repo,
    required bool isDemoMode,
    DateTime? nowOverride,
  }) async {
    // Guard 0: demo data isn't theirs to rate the app on.
    if (isDemoMode) return false;

    // Guard 1: at least one completed plant.
    final hasCompletedRun = repo.plants.any(
      (p) => p.status == PlantStatus.completed,
    );
    if (!hasCompletedRun) return false;

    final prefs = await SharedPreferences.getInstance();

    // Guard 2: never if the user has declined.
    if (prefs.getBool(_hasDeclinedKey) ?? false) return false;

    final now = nowOverride ?? DateTime.now();

    // Guard 3: ≥ 7 days since first launch.
    final firstLaunchIso = prefs.getString(_firstLaunchKey);
    if (firstLaunchIso == null) {
      // Defensive — if main() didn't seed this, do it now and skip.
      // This guarantees the next viable session can prompt.
      await prefs.setString(_firstLaunchKey, now.toIso8601String());
      return false;
    }
    final firstLaunch = DateTime.tryParse(firstLaunchIso);
    if (firstLaunch == null) return false;
    if (now.difference(firstLaunch).inDays < _minDaysSinceFirstLaunch) {
      return false;
    }

    // Guard 4: ≥ 90 days since the last prompt.
    final lastPromptIso = prefs.getString(_lastPromptKey);
    if (lastPromptIso != null) {
      final lastPrompt = DateTime.tryParse(lastPromptIso);
      if (lastPrompt != null &&
          now.difference(lastPrompt).inDays < minDaysBetweenPrompts) {
        return false;
      }
    }

    // Guard 5: platform supports it.  Web / desktop return false.
    if (!await _reviewer.isAvailable()) return false;

    // All guards passed — fire the native prompt and stamp the
    // cooldown.  Update the timestamp BEFORE awaiting the request
    // so re-entry into the Grow Report screen doesn't double-fire
    // while the dialog is animating in.
    await prefs.setString(_lastPromptKey, now.toIso8601String());
    await _reviewer.requestReview();
    return true;
  }

  // ── Test hooks ────────────────────────────────────────────────────
  /// Reset every persisted flag.  Used by widget tests that need a
  /// clean slate between scenarios.
  @visibleForTesting
  static Future<void> resetForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstLaunchKey);
    await prefs.remove(_lastPromptKey);
    await prefs.remove(_hasDeclinedKey);
  }
}
