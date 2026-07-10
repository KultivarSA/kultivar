// Single source of truth for what each subscription tier is allowed
// to do.  Anything that reads or writes a "free tier limit" should
// import from here instead of hard-coding numbers — that's how the
// 1-space / 3-plant caps drifted out of sync in the old code.
//
// Tiers themselves live in [SubscriptionTier] (services/subscription_service.dart);
// this file is just the rules attached to them.

import 'package:flutter/foundation.dart';

import '../models/plant.dart';
import '../models/time_window.dart';
import '../services/subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Free-tier limits
//
// These are intentionally conservative — the free tier is meant to let
// a casual home grower run one cycle end-to-end so they have data they
// don't want to lose by the time they hit the cap.  The strain library
// + comparison tools are explicitly available on Free as of the
// three-tier rollout: they cost the developer nothing and act as a
// taste of the analytics depth the paid tiers unlock.
// ─────────────────────────────────────────────────────────────────────────────

class FreeTierLimits {
  /// Maximum number of grow spaces a Free user can create.
  static const int maxSpaces = 1;

  /// Maximum number of (non-archived) plants across all spaces.
  /// Archived / completed grows do not count toward the cap so the
  /// limit doesn't get more punishing the longer a user grows.
  static const int maxActivePlants = 3;

  /// How far back the analytics charts will render data for a Free user.
  /// Pro tiers see everything.
  static const Duration analyticsHistoryWindow = Duration(days: 60);

  const FreeTierLimits._();
}

// ─────────────────────────────────────────────────────────────────────────────
// Free-tier gate logic
//
// Pure functions the call-site gates (FAB actions, clone sheet, analytics
// windows) delegate to, so the "what counts toward a cap" rules live in one
// testable place.  Two invariants every caller relies on:
//
//   1. Archived / completed plants NEVER count toward the plant cap — the
//      limit must not get more punishing the longer a user grows.
//   2. Existing over-limit data is never deleted or hidden.  A user who
//      created 5 plants before the caps shipped keeps all 5; the gates only
//      refuse to create NEW entities while over the cap.  (This is also why
//      backup restore and the repository itself stay ungated — enforcement
//      happens at the UI creation flows only.)
// ─────────────────────────────────────────────────────────────────────────────

class FreeTierGate {
  /// Plants that count toward [FreeTierLimits.maxActivePlants].
  /// `isArchived` covers both completed and removed/culled plants.
  static int activePlantCount(Iterable<Plant> plants) =>
      plants.where((p) => !p.isArchived).length;

  /// True when [tier] may create [count] more plant(s) on top of [existing].
  static bool canAddPlants(
    SubscriptionTier tier,
    Iterable<Plant> existing, {
    int count = 1,
  }) {
    if (tier.hasUnlimitedFeatures) return true;
    return activePlantCount(existing) + count <= FreeTierLimits.maxActivePlants;
  }

  /// True when the user is at (or past) the free plant cap — drives the
  /// ProLimitBanner on the Home screen.  Always false on paid tiers.
  static bool atPlantCap(SubscriptionTier tier, Iterable<Plant> existing) =>
      !tier.hasUnlimitedFeatures &&
      activePlantCount(existing) >= FreeTierLimits.maxActivePlants;

  /// True when [tier] may create another grow space.
  static bool canAddSpace(SubscriptionTier tier, int existingSpaceCount) {
    if (tier.hasUnlimitedFeatures) return true;
    return existingSpaceCount < FreeTierLimits.maxSpaces;
  }

  /// Clamps a chart-history window expressed in days (null / negative =
  /// "all time") to [FreeTierLimits.analyticsHistoryWindow] on Free.
  /// Paid tiers pass through unchanged.
  static int? clampHistoryDays(SubscriptionTier tier, int? requestedDays) {
    if (tier.hasUnlimitedFeatures) return requestedDays;
    final cap = FreeTierLimits.analyticsHistoryWindow.inDays;
    if (requestedDays == null || requestedDays < 0 || requestedDays > cap) {
      return cap;
    }
    return requestedDays;
  }

  /// [TimeWindow] flavour of [clampHistoryDays] for the dashboard selector.
  /// On Free, windows wider than the cap fall back to the widest preset
  /// that still fits inside it.
  static TimeWindow clampTimeWindow(
      SubscriptionTier tier, TimeWindow requested) {
    if (tier.hasUnlimitedFeatures) return requested;
    final cap = FreeTierLimits.analyticsHistoryWindow.inDays;
    final days = requested.days;
    if (days != null && days <= cap) return requested;
    TimeWindow widest = TimeWindow.values.first;
    for (final w in TimeWindow.values) {
      final d = w.days;
      if (d != null && d <= cap && d > (widest.days ?? -1)) widest = w;
    }
    return widest;
  }

  /// Window presets [tier] may NOT select — rendered locked in the
  /// selector, tapping them routes to the paywall.
  static Set<TimeWindow> lockedTimeWindows(SubscriptionTier tier) {
    if (tier.hasUnlimitedFeatures) return const {};
    final cap = FreeTierLimits.analyticsHistoryWindow.inDays;
    return {
      for (final w in TimeWindow.values)
        if (w.days == null || w.days! > cap) w,
    };
  }

  const FreeTierGate._();
}

// ─────────────────────────────────────────────────────────────────────────────
// Launch promo
//
// Lifetime Local launches at $49.99 with a 30-day promo at $39.99.  The
// launch date isn't fixed yet, so this is wired to be a no-op until a
// date is set — the paywall renders the standard price and the promo
// badge stays hidden.  When we lock in a launch date, set
// [launchDate] to that DateTime (UTC) and the promo activates
// automatically for the [promoDuration] window.
//
// We deliberately do NOT enforce the promo price client-side — the
// RevenueCat dashboard handles introductory pricing.  This config
// only drives the marketing copy ("Launch Special — $39.99 until …").
// ─────────────────────────────────────────────────────────────────────────────

class LifetimeLaunchPromo {
  /// First day the promo is active.  `null` = no promo configured yet.
  /// When the launch date is locked in, set this to the UTC midnight of
  /// that day.
  static const DateTime? launchDate = null;

  /// How long the promo runs from [launchDate].
  static const Duration promoDuration = Duration(days: 30);

  /// Headline price during the promo window.
  static const String promoPrice = '\$39.99';

  /// Regular price after the promo window.
  static const String regularPrice = '\$49.99';

  /// True when "right now" sits inside the promo window.
  static bool get isActive {
    const start = launchDate;
    if (start == null) return false;
    final now = DateTime.now().toUtc();
    final end = start.add(promoDuration);
    return now.isAfter(start) && now.isBefore(end);
  }

  /// When the promo window closes — for display in the badge
  /// ("Launch Special until {date}").  Null when no promo is active.
  static DateTime? get endsAt {
    const start = launchDate;
    if (start == null) return null;
    return start.add(promoDuration);
  }

  const LifetimeLaunchPromo._();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tier capability matrix
//
// Centralised so the paywall, settings, and call-site gates all read
// the same truth.  Extend this enum-driven map instead of sprinkling
// `if (tier == ...)` checks across the codebase.
// ─────────────────────────────────────────────────────────────────────────────

extension SubscriptionTierCapabilities on SubscriptionTier {
  /// Human-readable label, e.g. shown in the Settings subscription tile.
  String get label {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.lifetimeLocal:
        return 'Lifetime Local';
      case SubscriptionTier.proCloud:
        return 'Kultivar Pro';
    }
  }

  /// True when the tier removes the 1-space / 3-plant / 60-day caps.
  bool get hasUnlimitedFeatures => this != SubscriptionTier.free;

  /// True when the tier has access to community percentile data and
  /// other developer-cost backends.
  bool get hasCommunityAccess => this == SubscriptionTier.proCloud;

  /// True when the tier has a recurring billing relationship that can
  /// be managed via the App Store / Play Store.
  bool get hasManageableSubscription => this == SubscriptionTier.proCloud;
}

// ─────────────────────────────────────────────────────────────────────────────
// Debug self-check
//
// In debug builds, assert that the two getters on SubscriptionService
// agree with the capability extension on the enum.  If they ever drift
// it'll surface immediately at runtime instead of silently letting Free
// users hit Supabase.
// ─────────────────────────────────────────────────────────────────────────────

void debugAssertTierConsistency(SubscriptionService svc) {
  if (!kDebugMode) return;
  assert(
    svc.hasUnlimitedFeatures == svc.tier.hasUnlimitedFeatures,
    'SubscriptionService.hasUnlimitedFeatures disagrees with '
    'SubscriptionTier.${svc.tier.name}.hasUnlimitedFeatures',
  );
  assert(
    svc.hasCommunityAccess == svc.tier.hasCommunityAccess,
    'SubscriptionService.hasCommunityAccess disagrees with '
    'SubscriptionTier.${svc.tier.name}.hasCommunityAccess',
  );
}
