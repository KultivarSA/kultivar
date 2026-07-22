import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'community_service.dart';
import 'error_reporter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RevenueCat configuration
//
// Keys are injected at build time via `--dart-define` so they never live in
// source control.  Pre-release checklist:
//
// 1. Create a RevenueCat account at https://app.revenuecat.com
// 2. Create apps for iOS and/or Android
// 3. Create TWO Entitlements:
//      • "pro_cloud"      → attach pro_cloud_monthly + pro_cloud_annual
//      • "lifetime_local" → attach lifetime_local (non-consumable IAP)
// 4. Build / run with the API keys passed via dart-define, e.g.:
//
//    flutter run --dart-define-from-file=env.json
//
//    or one-shot:
//
//    flutter run \
//      --dart-define=REVENUECAT_IOS_KEY=appl_xxx \
//      --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
//
// Grandfathering: existing customers who own the legacy "pro" entitlement
// are also treated as pro_cloud holders so the upgrade doesn't downgrade
// anyone.  See [_resolveTier] below.
//
// When either key is empty (the default in dev) the service silently
// falls back to Free tier — paid features stay gated.  See BUILD.md for
// the full env.json template.
// ─────────────────────────────────────────────────────────────────────────────

const _kApiKeyIos =
    String.fromEnvironment('REVENUECAT_IOS_KEY');
const _kApiKeyAndroid =
    String.fromEnvironment('REVENUECAT_ANDROID_KEY');

/// Entitlement identifiers — must match the RevenueCat dashboard.
const _kEntitlementProCloud = 'pro_cloud';
const _kEntitlementLifetimeLocal = 'lifetime_local';

/// Legacy entitlement from the previous single-tier model.  Anyone who
/// purchased before the multi-tier rollout owns this; treat them as
/// pro_cloud so they keep every feature they were paying for.
const _kEntitlementLegacyPro = 'pro';

/// Identifier of the "lifetime_local" package as configured inside the
/// current RevenueCat offering.  Lifetime is a non-consumable so it lives
/// outside the monthly/annual convenience getters on [Offering].
const _kPackageLifetimeLocal = 'lifetime_local';

/// SharedPreferences key — persists dev Pro override across hot restarts.
const _kDevTierKey = 'dev_tier_override';

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionTier
// ─────────────────────────────────────────────────────────────────────────────

/// The three monetisation tiers the app supports.
///
/// Ranked least → most capable.  Use [compareTo] when you need to check
/// "at least this tier" semantics (e.g. `tier.index >= proCloud.index`).
enum SubscriptionTier {
  /// 1 space, 3 plants, 60-day analytics, local strain library.
  /// No paid features, no community / cloud calls.
  free,

  /// One-time purchase.  Unlocks every *local* feature forever:
  /// unlimited plants + spaces, full analytics history, exports,
  /// widget, full strain comparisons.  Does NOT include community
  /// benchmarking or any future cloud sync.
  lifetimeLocal,

  /// Subscription.  Everything Lifetime Local has, PLUS the
  /// cloud-cost features: community percentile benchmarking, future
  /// cross-device sync, future cloud auto-backup, priority support.
  proCloud,
}

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionService
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionService extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────

  SubscriptionTier _tier = SubscriptionTier.free;
  bool _isInitialising = true;
  bool _isPurchasing = false;
  String? _lastError;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;

  /// The active tier for this user (free / lifetimeLocal / proCloud).
  SubscriptionTier get tier => _tier;

  /// True when the user has any paid tier (Lifetime Local OR Pro Cloud).
  /// Use this for "unlimited spaces / plants / analytics history /
  /// exports / widget / strain comparison" gating.
  bool get hasUnlimitedFeatures => _tier != SubscriptionTier.free;

  /// True only when the user is on Pro Cloud.  Use this to gate any
  /// feature that touches a developer-cost backend — community
  /// percentile fetches, future cross-device sync, cloud backup.
  bool get hasCommunityAccess => _tier == SubscriptionTier.proCloud;

  /// Backwards-compatible shim.  Existing call sites still ask `isPro`;
  /// they generally mean "has unlimited features" rather than the
  /// stricter cloud-access semantic, so we map it to the looser check.
  /// New code should prefer [hasUnlimitedFeatures] / [hasCommunityAccess].
  bool get isPro => hasUnlimitedFeatures;

  bool get isInitialising => _isInitialising;
  bool get isPurchasing => _isPurchasing;
  String? get lastError => _lastError;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;

  /// Convenience — monthly package from the current offering.
  Package? get monthlyPackage => _offerings?.current?.monthly;

  /// Convenience — annual package from the current offering.
  Package? get annualPackage => _offerings?.current?.annual;

  /// Convenience — lifetime package from the current offering.  Lifetime
  /// is a non-consumable so it isn't exposed via the `monthly`/`annual`
  /// shortcuts; we look it up by package identifier instead.
  Package? get lifetimePackage {
    final pkgs = _offerings?.current?.availablePackages;
    if (pkgs == null) return null;
    for (final p in pkgs) {
      if (p.identifier == _kPackageLifetimeLocal) return p;
      // Some RevenueCat configs use the built-in "lifetime" alias.
      if (p.packageType == PackageType.lifetime) return p;
    }
    return null;
  }

  // ── Tier resolution ───────────────────────────────────────────────────────

  /// Maps an [Entitlements] bundle from RevenueCat to the highest tier
  /// the user owns.  Pro Cloud wins over Lifetime; legacy `pro`
  /// entitlement is grandfathered into Pro Cloud.
  SubscriptionTier _resolveTier(CustomerInfo? info) {
    if (info == null) return SubscriptionTier.free;
    final active = info.entitlements.active;
    if (active.containsKey(_kEntitlementProCloud) ||
        active.containsKey(_kEntitlementLegacyPro)) {
      return SubscriptionTier.proCloud;
    }
    if (active.containsKey(_kEntitlementLifetimeLocal)) {
      return SubscriptionTier.lifetimeLocal;
    }
    return SubscriptionTier.free;
  }

  /// Setter for the active tier.  Centralised so we never forget to
  /// keep [CommunityService.hasAccess] in sync — community calls cost
  /// us money and must NOT run when the user isn't on Pro Cloud.
  void _setTier(SubscriptionTier next) {
    _tier = next;
    CommunityService.hasAccess = hasCommunityAccess;
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    // Dev shortcut — debug builds can pin a tier without a real purchase.
    if (kDebugMode) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDevTierKey);
      if (raw != null) {
        _setTier(SubscriptionTier.values.firstWhere(
          (t) => t.name == raw,
          orElse: () => SubscriptionTier.free,
        ));
        _isInitialising = false;
        notifyListeners();
        return;
      }
    }

    try {
      final apiKey = defaultTargetPlatform == TargetPlatform.android
          ? _kApiKeyAndroid
          : _kApiKeyIos;

      // Bail gracefully when keys weren't supplied at build time (dev
      // workflow / open-source contributors).  App runs fully in Free
      // tier.  See BUILD.md for how to wire real keys via --dart-define.
      if (apiKey.isEmpty) {
        _isInitialising = false;
        notifyListeners();
        return;
      }

      final config = PurchasesConfiguration(apiKey);
      await Purchases.configure(config);

      // React to every entitlement change the SDK learns about —
      // including server-side validation that completes moments AFTER
      // purchasePackage() already returned.  Without this listener a
      // freshly-bought tier could stay invisible until the next app
      // launch: the purchase call's synchronous CustomerInfo sometimes
      // lags validation, and the follow-up push had no subscriber.
      // Also covers renewals, cancellations, and cross-device changes.
      Purchases.addCustomerInfoUpdateListener((info) {
        _customerInfo = info;
        _setTier(_resolveTier(info));
        notifyListeners();
      });
    } catch (e, stack) {
      // StoreKit / Billing unavailable — fail silently, user stays Free.
      ErrorReporter.report('SubscriptionService.init', e, stack);
      _isInitialising = false;
      notifyListeners();
      return;
    }

    _isInitialising = false;
    notifyListeners();

    // Boot-time fix (15 s splash hang): the customer-info + offerings
    // prefetch is NETWORK-bound — RevenueCat API plus a Google Play
    // Billing connection.  When Billing is slow (or the Play products
    // aren't configured yet) the pair can block for 10-15 s, and main()
    // used to await it before the first frame.  configure() above is
    // local and already exposes RevenueCat's on-device entitlement
    // cache, so the fresh fetch now runs unawaited in the background
    // and notifies when the tier resolves.  Until then the user is
    // treated as Free — the same state every gate already handles.
    unawaited(_refreshEntitlementsAndOfferings());
  }

  /// Background refresh of customer info + offerings.  Never awaited on
  /// the boot path; must swallow its own errors (an uncaught async error
  /// from an unawaited future would surface as a zone error).
  Future<void> _refreshEntitlementsAndOfferings() async {
    try {
      final results = await Future.wait([
        Purchases.getCustomerInfo(),
        Purchases.getOfferings(),
      ]);
      _customerInfo = results[0] as CustomerInfo;
      _offerings = results[1] as Offerings;
      _setTier(_resolveTier(_customerInfo));
    } catch (e, stack) {
      // Network unavailable — fail silently, user stays on the cached /
      // Free tier until the next refresh opportunity.
      ErrorReporter.report(
          'SubscriptionService.refreshEntitlements', e, stack);
    }
    notifyListeners();
  }

  // ── Offerings ─────────────────────────────────────────────────────────────

  /// Fetches (or returns cached) offerings from RevenueCat.
  Future<Offerings?> fetchOfferings() async {
    if (_offerings != null) return _offerings;
    try {
      _offerings = await Purchases.getOfferings();
      notifyListeners();
    } catch (e, stack) {
      ErrorReporter.report('SubscriptionService.fetchOfferings', e, stack);
    }
    return _offerings;
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  /// Returns true if the purchase succeeded and the user's tier was
  /// upgraded as a result.  Works for any package — monthly, annual,
  /// or the lifetime non-consumable.
  Future<bool> purchasePackage(Package package) async {
    if (_isPurchasing) return false;
    _isPurchasing = true;
    _lastError = null;
    notifyListeners();

    try {
      // purchases_flutter 10.x: purchasePackage() is deprecated in favour
      // of purchase(PurchaseParams); the call returns a PurchaseResult
      // (CustomerInfo + StoreTransaction) rather than a bare CustomerInfo.
      // We only need the refreshed entitlements to resolve the tier.
      final result =
          await Purchases.purchase(PurchaseParams.package(package));
      final info = result.customerInfo;
      _customerInfo = info;
      final newTier = _resolveTier(info);
      final upgraded = newTier.index > _tier.index;
      _setTier(newTier);
      notifyListeners();
      // "Success" = either upgraded (new tier) or stayed at the same
      // paid tier (re-purchase of an active sub).  Returning the
      // upgrade flag would falsely report failure on the latter, so
      // anchor on "are we on a paid tier now?"
      return _tier != SubscriptionTier.free || upgraded;
    } catch (e) {
      // A cancelled purchase is not a user-visible error.
      final msg = e.toString().toLowerCase();
      if (!msg.contains('cancel') && !msg.contains('usercancel')) {
        _lastError = _friendlyError(e);
        notifyListeners();
      }
      return false;
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  /// Restores past purchases. Returns true if any paid tier was restored.
  Future<bool> restorePurchases() async {
    _lastError = null;
    _isPurchasing = true;
    notifyListeners();

    try {
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      _setTier(_resolveTier(info));
      notifyListeners();
      return _tier != SubscriptionTier.free;
    } catch (e) {
      _lastError = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  // ── Refresh ───────────────────────────────────────────────────────────────

  /// Re-validates entitlements.  Called after the user returns from
  /// the platform's Manage Subscription page so a freshly-purchased
  /// upgrade (or cancellation) propagates without an app relaunch.
  ///
  /// Failures here are silent to the user -- their tier stays at
  /// whatever was last successfully resolved, which keeps the UI
  /// consistent rather than reverting to Free on a transient blip.
  /// However we MUST route the underlying error to ErrorReporter:
  /// a paying customer whose tier doesn't update is the most expensive
  /// possible bug for us (refund disputes + lost trust), and pre-this
  /// fix the failure was wholly invisible to the developer side.
  ///
  /// Matches the catch shape used by [init] and [fetchOfferings]
  /// elsewhere in this file.
  Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _customerInfo = info;
      _setTier(_resolveTier(info));
      notifyListeners();
    } catch (e, stack) {
      ErrorReporter.report('SubscriptionService.refresh', e, stack);
    }
  }

  // ── Manage subscription (platform-deep-link) ─────────────────────────────
  //
  // Apple (§3.1.1) and Google both REQUIRE that users cancel and modify
  // their subscriptions through the App Store / Play Store rather than
  // inside the app.  RevenueCat's `showManageSubscriptions` opens the
  // platform's native subscription-management UI in-context.
  //
  // This is also where users would change tier (monthly ↔ annual),
  // restore a paused subscription, or update payment method.
  //
  // Lifetime Local has nothing to manage (no recurring charge) — callers
  // should hide the entry point when [tier] == [SubscriptionTier.lifetimeLocal].

  /// Opens the App Store (iOS) or Play Store (Android) subscription
  /// management page.  No-ops on web.  RevenueCat's `purchases_flutter`
  /// 8.x doesn't ship a built-in launcher anymore; the canonical
  /// pattern in their docs is to deep-link to the platform's account
  /// subscriptions URL via `url_launcher`.
  Future<void> openManageSubscriptions() async {
    if (kIsWeb) return;
    final url = defaultTargetPlatform == TargetPlatform.android
        // The optional sku/package params can be appended to deep-link
        // straight into the current product's row, but the bare URL is
        // accepted on all Play versions and lands users on the same
        // subscriptions list either way.
        ? Uri.parse('https://play.google.com/store/account/subscriptions')
        : Uri.parse('https://apps.apple.com/account/subscriptions');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e, stack) {
      ErrorReporter.report(
          'SubscriptionService.openManageSubscriptions', e, stack);
    }
  }

  // ── Renewal info ──────────────────────────────────────────────────────────

  /// Expiration date of the active Pro Cloud entitlement, or null when
  /// the user is on Free / Lifetime Local / has never subscribed.  Used
  /// by the Settings tile to render "Renews / Expires on …" copy.
  ///
  /// Lifetime Local doesn't have an expiry by definition — callers
  /// should check [tier] first and only consult this getter when the
  /// active tier is Pro Cloud.
  DateTime? get proExpiryDate {
    final ent = _customerInfo?.entitlements.active[_kEntitlementProCloud] ??
        _customerInfo?.entitlements.active[_kEntitlementLegacyPro];
    final raw = ent?.expirationDate;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// True when the active Pro Cloud subscription is set to auto-renew
  /// at expiry.  Useful for distinguishing "Renews on …" vs "Expires
  /// on …" copy.  Always false for Lifetime Local and Free.
  bool get willRenew {
    final ent = _customerInfo?.entitlements.active[_kEntitlementProCloud] ??
        _customerInfo?.entitlements.active[_kEntitlementLegacyPro];
    return ent?.willRenew ?? false;
  }

  // ── Dev helpers ───────────────────────────────────────────────────────────

  /// Cycles through Free → Lifetime Local → Pro Cloud → Free.  Debug
  /// builds only.  Persists across restarts.
  Future<void> debugCycleTier() async {
    assert(kDebugMode);
    _setTier(SubscriptionTier.values[
        (_tier.index + 1) % SubscriptionTier.values.length]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDevTierKey, _tier.name);
    notifyListeners();
  }

  /// Pins the dev override to a specific tier.  Debug builds only.
  Future<void> debugSetTier(SubscriptionTier tier) async {
    assert(kDebugMode);
    _setTier(tier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDevTierKey, _tier.name);
    notifyListeners();
  }

  /// Legacy debug shortcut kept so existing paywall code compiles.
  /// Toggles between Free and Pro Cloud; for the Lifetime tier use
  /// [debugSetTier].
  Future<void> debugTogglePro() async {
    assert(kDebugMode);
    await debugSetTier(
      _tier == SubscriptionTier.free
          ? SubscriptionTier.proCloud
          : SubscriptionTier.free,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    if (msg.contains('billing')) {
      return 'Billing not available on this device.';
    }
    return 'Purchase failed. Please try again.';
  }
}
