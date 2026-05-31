import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User's stance on anonymous usage telemetry / crash reporting.
///
/// Stored as an enum (rather than a bare bool) so we can distinguish
/// "user hasn't been asked yet" from "user explicitly declined" — the
/// first-launch consent sheet only fires when the value is [notAsked],
/// otherwise the user's choice persists.
enum TelemetryConsentState {
  /// First-launch default — no prompt has been shown yet.  Sentry is
  /// not initialised; community telemetry doesn't fire.
  notAsked,

  /// User has explicitly opted in.  Sentry will be initialised on the
  /// next app launch; any future analytics SDK can fire from here on.
  granted,

  /// User has explicitly opted out.  No telemetry under any circumstance,
  /// regardless of DSN / SDK configuration at build time.
  declined,
}

/// SR6 — Single source of truth for the user's telemetry consent.
///
/// ## Why a separate service (vs a bool in UiPreferencesService)?
///
/// Consent has a lifecycle the other prefs don't: it must be *asked*
/// (not just defaulted), it must be auditable in case a regulator
/// inquires, and it gates network-touching code paths that need a
/// strict "no — really no" stance until the user has agreed.
///
/// ## Wiring
///
///   1. `main.dart` instantiates the service, calls `init()`, hands
///      its current state to `bootstrapSentryAndRun`.  When state ==
///      [TelemetryConsentState.granted], Sentry initialises; otherwise
///      the app runs in the no-telemetry path.
///   2. After onboarding completes, the shell screen checks
///      [hasBeenAsked].  If false, it shows
///      `TelemetryConsentSheet` once.  Tap-to-dismiss = decline
///      (privacy-first default).
///   3. Settings → Privacy exposes a "Help improve Kultivar" toggle
///      bound to [hasGranted] that calls [grant] / [decline].
///
/// Tier independence: telemetry consent is orthogonal to Pro Cloud's
/// `hasCommunityAccess` gate.  A Pro Cloud user can decline telemetry;
/// a Free user can grant it.  The two never confuse each other.
class TelemetryConsentService extends ChangeNotifier {
  TelemetryConsentService();

  /// SharedPreferences key.  Versioned so a future consent-language
  /// rewrite can roll us back to [TelemetryConsentState.notAsked] if
  /// the spec materially changes (e.g. GDPR-grade re-consent).
  static const String _key = 'telemetry_consent_v1';

  TelemetryConsentState _state = TelemetryConsentState.notAsked;
  bool _isInitialised = false;

  TelemetryConsentState get state => _state;

  /// True when the user has explicitly granted consent.  All network-
  /// touching telemetry code paths gate on this.
  bool get hasGranted => _state == TelemetryConsentState.granted;

  /// True after [grant] or [decline] has been called at least once —
  /// drives the first-launch sheet trigger.
  bool get hasBeenAsked => _state != TelemetryConsentState.notAsked;

  /// True after [init] has completed.  Callers shouldn't read [state]
  /// before this resolves (it'd default to [notAsked] regardless of
  /// the persisted value).
  bool get isInitialised => _isInitialised;

  /// Load the persisted state from SharedPreferences.  Call once at
  /// startup before any code that depends on the consent decision.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _state = TelemetryConsentState.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => TelemetryConsentState.notAsked,
      );
    }
    _isInitialised = true;
    notifyListeners();
  }

  /// Records that the user has explicitly opted in.  Persists +
  /// notifies; callers downstream (Sentry bootstrap, future analytics
  /// SDKs) decide what to do with the news.
  Future<void> grant() => _persist(TelemetryConsentState.granted);

  /// Records that the user has explicitly opted out.  Same persistence
  /// shape as [grant]; the difference is downstream gating treats
  /// declined as "never fire telemetry" regardless of DSN / SDK config.
  Future<void> decline() => _persist(TelemetryConsentState.declined);

  /// Resets to [TelemetryConsentState.notAsked].  Used by:
  ///   • The Settings "Forget my choice" debug action
  ///     (debug builds only — exposed for QA).
  ///   • A future major re-consent prompt (e.g. terms update).
  Future<void> reset() => _persist(TelemetryConsentState.notAsked);

  Future<void> _persist(TelemetryConsentState next) async {
    if (_state == next) return;
    _state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.name);
    notifyListeners();
  }
}
