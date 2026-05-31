import 'package:flutter/material.dart';

import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../theme/app_colors.dart';
import 'date_format.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home reminders + per-plant care status
//
// This module owns every "is this plant / space due for attention?"
// computation that powers the Home tab.  It used to live as a swarm of
// private helpers at the bottom of home_screen.dart, which made the
// screen file balloon past 1900 lines and tightly coupled the
// reminder-card rendering to the reminder-logic itself.  Moving it
// here:
//
//   • lets the home screen + the per-plant care-strip widget share one
//     source of truth instead of recomputing the same statuses
//     independently;
//   • makes the rules unit-testable in isolation;
//   • gives any future surface (e.g. an iOS widget, a notification
//     digest, a watchOS complication) a single function to call
//     rather than scraping reminder-card view models.
//
// The rules themselves are unchanged from the original implementation.
// ─────────────────────────────────────────────────────────────────────────────

/// Per-plant per-category care state.  `dueSoon` is "within 24 h of the
/// configured interval" — early enough to nudge without crying wolf.
enum CareStatus { ok, dueSoon, overdue }

// ─────────────────────────────────────────────────────────────────────────────
// Reminder view-model
// ─────────────────────────────────────────────────────────────────────────────

/// A single attention-needed item surfaced on the home reminder bell.
///
/// Both plant-care reminders (watering / feeding / IPM / drying / curing
/// completion / target harvest) and space-environment alerts (stale data,
/// out-of-range readings) collapse into this shape so the home-screen
/// sheet can render them in one sorted list.
@immutable
class Reminder {
  /// Either the plant name (plant reminders) or the space name
  /// (environment alerts).  Used as the bolded label in list rows.
  final String plantName;

  /// Short human-readable description ("Watering overdue",
  /// "Curing ends in 2d (10 Jun)").
  final String message;

  final IconData icon;
  final Color color;

  /// Drives priority: urgent items get sorted to the top and rendered
  /// in the warning/danger colour.  Use [color] for the actual paint.
  final bool isUrgent;

  /// When the reminder *fires* — used for sort ordering and for any
  /// surfaces that want to show a relative time.
  final DateTime date;

  const Reminder({
    required this.plantName,
    required this.message,
    required this.icon,
    required this.color,
    required this.isUrgent,
    required this.date,
  });

  /// UX10 — compact phrase used by the home reminder bell's tooltip
  /// peek.  Format: "<plant> · <message>" so a glance reveals both
  /// which plant needs attention AND what kind of attention it
  /// needs.  Falls back to either field alone when the other is empty.
  String get peekLabel {
    if (plantName.isEmpty) return message;
    if (message.isEmpty) return plantName;
    return '$plantName · $message';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-plant care status
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the most recent note that matches [plantId] and [category],
/// or `null` if the plant has never logged that care category.  Folded
/// instead of sorted because we only need the max and don't want to
/// allocate a sorted copy on every Home rebuild.
DateTime? _lastCareDate(
    List<PlantNote> notes, String plantId, NoteCategory category) {
  return notes
      .where((n) => n.plantId == plantId && n.category == category)
      .map((n) => n.createdAt)
      .fold<DateTime?>(
          null, (prev, d) => prev == null || d.isAfter(prev) ? d : prev);
}

/// Computes whether a plant is due / overdue for a care category
/// (watering, feeding, IPM).  Care reminders only fire while a plant is
/// actively growing — drying/curing/archived plants don't water.
///
/// F10 — `intervalDays == 0` is the "skip" signal emitted by
/// `Plant.effective*IntervalDays()` for stages where the care category
/// doesn't make sense (e.g. no feeding during flush).
CareStatus computeCareStatus({
  required bool enabled,
  required PlantStatus plantStatus,
  required DateTime startDate,
  required int intervalDays,
  required List<PlantNote> notes,
  required String plantId,
  required NoteCategory category,
}) {
  if (!enabled || plantStatus != PlantStatus.growing) return CareStatus.ok;
  if (intervalDays <= 0) return CareStatus.ok;
  final now = DateTime.now();
  final lastDate = _lastCareDate(notes, plantId, category);
  final daysSince = now.difference(lastDate ?? startDate).inDays;
  if (daysSince >= intervalDays) return CareStatus.overdue;
  if (daysSince >= intervalDays - 1) return CareStatus.dueSoon;
  return CareStatus.ok;
}

// ─────────────────────────────────────────────────────────────────────────────
// Space environment alerts
// ─────────────────────────────────────────────────────────────────────────────

/// Scans [spaces] for stale data and out-of-range readings in [envLogs].
///
/// Rules:
///  • No reading in > 48 h → info-level "unmonitored" reminder.
///  • Latest reading out of range → warning (single) or urgent danger
///    (streak ≥ 3).
///  • Logs with only one value (temp-only or humidity-only) are
///    skipped when evaluating range — both values must be present for
///    a threshold check.
List<Reminder> buildSpaceAlerts(
  List<GrowSpace> spaces,
  List<EnvironmentLog> envLogs,
) {
  final now = DateTime.now();
  final alerts = <Reminder>[];

  for (final space in spaces) {
    // Collect this space's logs newest-first.
    final spaceLogs = envLogs
        .where((l) => l.growSpaceId == space.id)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (spaceLogs.isEmpty) continue;

    final latest = spaceLogs.first;
    final ageHours = now.difference(latest.recordedAt).inHours;

    // ── Stale data ─────────────────────────
    if (ageHours > 48) {
      final ageDays = now.difference(latest.recordedAt).inDays;
      alerts.add(Reminder(
        plantName: space.name,
        message: 'No reading in ${ageDays}d — environment unmonitored',
        icon: Icons.sensors_off_rounded,
        color: AppColors.warning,
        isUrgent: false,
        date: latest.recordedAt,
      ));
      continue; // stale → skip range check
    }

    // ── Out-of-range check (requires both values) ──
    if (latest.temperature == null || latest.humidity == null) continue;
    final inRange = space.isOptimal(latest.temperature!, latest.humidity!);
    if (inRange) continue;

    // Count the consecutive out-of-range streak (skip partial readings).
    var streak = 0;
    for (final log in spaceLogs) {
      if (log.temperature == null || log.humidity == null) continue;
      if (space.isOptimal(log.temperature!, log.humidity!)) break;
      streak++;
    }

    // Describe which parameter(s) are off.
    final parts = <String>[];
    if (!space.isOptimalTemp(latest.temperature!)) parts.add('temp');
    if (!space.isOptimalHumidity(latest.humidity!)) parts.add('humidity');
    final what = parts.join(' & ');

    final isUrgent = streak >= 3;
    alerts.add(Reminder(
      plantName: space.name,
      message: streak >= 3
          ? '$what out of range ($streak readings)'
          : '$what out of range',
      icon: Icons.thermostat_rounded,
      color: isUrgent ? AppColors.danger : AppColors.warning,
      isUrgent: isUrgent,
      date: latest.recordedAt,
    ));
  }

  return alerts;
}

// ─────────────────────────────────────────────────────────────────────────────
// All-up home reminders
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the full reminder list for the Home tab — drying / curing /
/// target-harvest deadlines, per-plant care intervals, and space
/// environment alerts, sorted urgent-first then oldest-first.
///
/// Pass [spaces] and [envLogs] when you also want environment-driven
/// reminders; omit them (the default empty lists) on surfaces that
/// only care about plant care (e.g. a per-plant detail strip).
List<Reminder> buildHomeReminders(
  List<Plant> plants,
  List<PlantNote> notes, {
  List<GrowSpace> spaces = const [],
  List<EnvironmentLog> envLogs = const [],
}) {
  final now = DateTime.now();
  final reminders = <Reminder>[];

  for (final plant in plants) {
    if (plant.isArchived) continue;

    // ── Drying completion ──────────────────
    if (plant.status == PlantStatus.drying &&
        plant.dryingEndDate != null) {
      final end = plant.dryingEndDate!;
      final diff = end.difference(now).inDays;
      if (end.isBefore(now)) {
        reminders.add(Reminder(
          plantName: plant.name,
          message: 'Drying overdue by ${now.difference(end).inDays}d',
          icon: Icons.air,
          color: AppColors.danger,
          isUrgent: true,
          date: end,
        ));
      } else if (diff <= 7) {
        reminders.add(Reminder(
          plantName: plant.name,
          message: diff == 0
              ? 'Drying ends today'
              : 'Drying ends in ${diff}d (${fmtShortDate(end)})',
          icon: Icons.air,
          color: AppColors.drying,
          isUrgent: diff <= 1,
          date: end,
        ));
      }
    }

    // ── Curing completion ──────────────────
    if (plant.status == PlantStatus.curing &&
        plant.curingEndDate != null) {
      final end = plant.curingEndDate!;
      final diff = end.difference(now).inDays;
      if (end.isBefore(now)) {
        reminders.add(Reminder(
          plantName: plant.name,
          message: 'Curing overdue by ${now.difference(end).inDays}d',
          icon: Icons.science_rounded,
          color: AppColors.danger,
          isUrgent: true,
          date: end,
        ));
      } else if (diff <= 7) {
        reminders.add(Reminder(
          plantName: plant.name,
          message: diff == 0
              ? 'Curing ends today'
              : 'Curing ends in ${diff}d (${fmtShortDate(end)})',
          icon: Icons.science_rounded,
          color: AppColors.curing,
          isUrgent: diff <= 1,
          date: end,
        ));
      }
    }

    // ── Target harvest ─────────────────────
    if (plant.status == PlantStatus.growing &&
        plant.targetHarvestDate != null) {
      final target = plant.targetHarvestDate!;
      final diff = target.difference(now).inDays;
      if (target.isBefore(now)) {
        reminders.add(Reminder(
          plantName: plant.name,
          message:
              'Target harvest passed ${now.difference(target).inDays}d ago',
          icon: Icons.agriculture_rounded,
          color: AppColors.warning,
          isUrgent: true,
          date: target,
        ));
      } else if (diff <= 7) {
        reminders.add(Reminder(
          plantName: plant.name,
          message: diff == 0
              ? 'Target harvest is today!'
              : 'Harvest in ${diff}d (${fmtShortDate(target)})',
          icon: Icons.agriculture_rounded,
          color: AppColors.harvested,
          isUrgent: diff <= 1,
          date: target,
        ));
      }
    }

    // ── Watering reminder ──────────────────
    // F10 — `effective*IntervalDays()` returns the stage-adjusted
    // cadence when `plant.autoAdjustIntervalsByStage` is on, else
    // the user's base value.  A returned 0 signals "skip" — e.g. no
    // feeds in seedling, no IPM during flush.
    final waterStatus = computeCareStatus(
      enabled: plant.wateringReminderEnabled,
      plantStatus: plant.status,
      startDate: plant.startDate,
      intervalDays: plant.effectiveWateringIntervalDays(),
      notes: notes,
      plantId: plant.id,
      category: NoteCategory.watering,
    );
    if (waterStatus != CareStatus.ok) {
      reminders.add(Reminder(
        plantName: plant.name,
        message: waterStatus == CareStatus.overdue
            ? 'Watering overdue'
            : 'Watering due soon',
        icon: Icons.water_drop_rounded,
        color: AppColors.water,
        isUrgent: waterStatus == CareStatus.overdue,
        date: DateTime.now(),
      ));
    }

    // ── Feeding reminder ───────────────────
    final feedStatus = computeCareStatus(
      enabled: plant.feedingReminderEnabled,
      plantStatus: plant.status,
      startDate: plant.startDate,
      intervalDays: plant.effectiveFeedingIntervalDays(),
      notes: notes,
      plantId: plant.id,
      category: NoteCategory.feeding,
    );
    if (feedStatus != CareStatus.ok) {
      reminders.add(Reminder(
        plantName: plant.name,
        message: feedStatus == CareStatus.overdue
            ? 'Feeding overdue'
            : 'Feeding due soon',
        icon: Icons.eco_rounded,
        color: AppColors.accent,
        isUrgent: feedStatus == CareStatus.overdue,
        date: DateTime.now(),
      ));
    }

    // ── IPM reminder ───────────────────────
    final ipmStatus = computeCareStatus(
      enabled: plant.ipmReminderEnabled,
      plantStatus: plant.status,
      startDate: plant.startDate,
      intervalDays: plant.effectiveIpmIntervalDays(),
      notes: notes,
      plantId: plant.id,
      category: NoteCategory.ipm,
    );
    if (ipmStatus != CareStatus.ok) {
      reminders.add(Reminder(
        plantName: plant.name,
        message: ipmStatus == CareStatus.overdue
            ? 'IPM spray overdue'
            : 'IPM spray due soon',
        icon: Icons.bug_report_rounded,
        color: AppColors.ipmColor,
        isUrgent: ipmStatus == CareStatus.overdue,
        date: DateTime.now(),
      ));
    }
  }

  // ── Environment alerts ─────────────────
  reminders.addAll(buildSpaceAlerts(spaces, envLogs));

  // Sort: urgent first, then by date.
  reminders.sort((a, b) {
    if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
    return a.date.compareTo(b.date);
  });
  return reminders;
}
