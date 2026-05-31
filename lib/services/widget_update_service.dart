import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../utils/temp_format.dart';
import '../utils/vpd_analytics.dart';
import 'error_reporter.dart';

/// Pushes a summary of the current grow state to the iOS / Android home-screen
/// widget so the user can glance at their tent without opening the app.
///
/// ## Data pushed
/// - Space name and latest env reading (temp / RH / VPD status)
/// - Next upcoming care event across all active plants
/// - A human-readable "X min/h/d ago" freshness label
///
/// ## Native integration
/// ### Android
/// The widget reads these values from SharedPreferences under the `flutter.*`
/// key prefix that `home_widget` writes.  See:
///   `android/app/src/main/kotlin/com/example/Kultivar/KultivarHomeWidget.kt`
///
/// ### iOS
/// The widget reads from the App Group's UserDefaults.  See:
///   `ios/KultivarWidget/KultivarWidget.swift`
///
/// iOS requires Xcode project setup — see comments in KultivarWidget.swift.
class WidgetUpdateService {
  WidgetUpdateService._();

  /// App Group ID shared between the Runner target and the WidgetKit extension.
  /// Must match the value configured in Xcode → Runner → Signing & Capabilities
  /// → App Groups, AND in the KultivarWidget extension's entitlements.
  static const _appGroupId = 'group.com.example.Kultivar';

  /// iOS WidgetKit `kind` string declared in `KultivarWidget.swift`.
  static const _iosWidgetName = 'KultivarWidget';

  /// Android `AppWidgetProvider` class name (unqualified).
  static const _androidWidgetName = 'KultivarHomeWidget';

  // ── Keys written to the widget data store ────────────────────────────────
  //
  // Keep these in sync with the native widget files.

  static const _kSpaceName  = 'widget_space_name';
  static const _kTemp       = 'widget_temp';
  static const _kHumidity   = 'widget_humidity';
  static const _kVpd        = 'widget_vpd';
  static const _kVpdStatus  = 'widget_vpd_status';
  static const _kAge        = 'widget_age';
  static const _kNextCare   = 'widget_next_care';
  static const _kPlantCount = 'widget_plant_count';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Updates the home-screen widget with the latest data from the repository.
  ///
  /// Safe to call from any isolate-safe code path (app resume, post-mutation).
  /// All errors are swallowed — widget data is always non-critical.
  static Future<void> update({
    required List<GrowSpace> spaces,
    required List<EnvironmentLog> envLogs,
    required List<Plant> plants,
    required List<PlantNote> notes,
  }) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      await _writeData(spaces: spaces, envLogs: envLogs, plants: plants, notes: notes);
      await HomeWidget.updateWidget(
        iOSName: _iosWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (e, stack) {
      ErrorReporter.report('WidgetUpdateService.update', e, stack);
    }
  }

  // ── Data computation ──────────────────────────────────────────────────────

  static Future<void> _writeData({
    required List<GrowSpace> spaces,
    required List<EnvironmentLog> envLogs,
    required List<Plant> plants,
    required List<PlantNote> notes,
  }) async {
    // ── Latest env reading ──────────────────────────────────────────────────
    //
    // Pick the space with the most recently logged reading.
    EnvironmentLog? latest;
    GrowSpace? latestSpace;

    for (final space in spaces) {
      final spaceLogs = envLogs
          .where((l) => l.growSpaceId == space.id)
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      if (spaceLogs.isEmpty) continue;
      if (latest == null ||
          spaceLogs.first.recordedAt.isAfter(latest.recordedAt)) {
        latest = spaceLogs.first;
        latestSpace = space;
      }
    }

    final spaceName = latestSpace?.name ?? '—';
    final tempDisplay = latest?.temperature != null
        ? fromStorageTemp(latest!.temperature!).toStringAsFixed(1) +
          tempUnitSuffix
        : '—';
    final humDisplay = latest?.humidity != null
        ? '${latest!.humidity!.toStringAsFixed(0)}%'
        : '—';

    String vpdDisplay = '—';
    String vpdStatus = '';
    if (latest?.temperature != null && latest?.humidity != null) {
      final vpd =
          computeVpd(latest!.temperature!, latest.humidity!);
      vpdDisplay = '${vpd.toStringAsFixed(2)} kPa';
      vpdStatus = vpd < 0.4
          ? 'low'
          : vpd > 1.6
              ? 'high'
              : 'ideal';
    }

    final ageDisplay = latest != null
        ? _readingAge(latest.recordedAt)
        : '—';

    // ── Next care event ──────────────────────────────────────────────────────
    final nextCare = _nextCareLabel(plants, notes);

    // ── Active plant count ───────────────────────────────────────────────────
    final activePlants =
        plants.where((p) => !p.isArchived).length;

    // ── Write to widget store ────────────────────────────────────────────────
    await Future.wait([
      HomeWidget.saveWidgetData<String>(_kSpaceName, spaceName),
      HomeWidget.saveWidgetData<String>(_kTemp, tempDisplay),
      HomeWidget.saveWidgetData<String>(_kHumidity, humDisplay),
      HomeWidget.saveWidgetData<String>(_kVpd, vpdDisplay),
      HomeWidget.saveWidgetData<String>(_kVpdStatus, vpdStatus),
      HomeWidget.saveWidgetData<String>(_kAge, ageDisplay),
      HomeWidget.saveWidgetData<String>(_kNextCare, nextCare ?? '—'),
      HomeWidget.saveWidgetData<int>(_kPlantCount, activePlants),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns a short human-readable age string for a past timestamp.
  static String _readingAge(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  /// Finds the single nearest upcoming (or overdue) care event across all
  /// active plants and returns a short label like "Water in 2d" or
  /// "Feed ${plantName} today".
  ///
  /// Priority order: overdue events first, then earliest upcoming.
  static String? _nextCareLabel(
      List<Plant> plants, List<PlantNote> notes) {
    final now = DateTime.now();
    DateTime? earliest;
    String? label;

    void consider(DateTime due, String text) {
      if (earliest == null || due.isBefore(earliest!)) {
        earliest = due;
        label = text;
      }
    }

    final activePlants = plants
        .where((p) => !p.isArchived && p.status == PlantStatus.growing)
        .toList();

    for (final plant in activePlants) {
      // ── Target harvest date ──────────────────────────────────────────────
      if (plant.targetHarvestDate != null) {
        final d = plant.targetHarvestDate!;
        final days = d.difference(now).inDays;
        if (days >= 0) {
          consider(
            d,
            days == 0
                ? 'Harvest today! — ${plant.name}'
                : 'Harvest in ${days}d — ${plant.name}',
          );
        }
      }

      // ── Watering ─────────────────────────────────────────────────────────
      if (plant.wateringReminderEnabled && plant.wateringIntervalDays > 0) {
        final next = _nextDueDate(
          plant: plant,
          notes: notes,
          category: NoteCategory.watering,
          intervalDays: plant.wateringIntervalDays,
        );
        final days = next.difference(now).inDays;
        consider(
          next,
          days <= 0
              ? 'Water ${plant.name} today'
              : 'Water in ${days}d — ${plant.name}',
        );
      }

      // ── Feeding ───────────────────────────────────────────────────────────
      if (plant.feedingReminderEnabled && plant.feedingIntervalDays > 0) {
        final next = _nextDueDate(
          plant: plant,
          notes: notes,
          category: NoteCategory.feeding,
          intervalDays: plant.feedingIntervalDays,
        );
        final days = next.difference(now).inDays;
        consider(
          next,
          days <= 0
              ? 'Feed ${plant.name} today'
              : 'Feed in ${days}d — ${plant.name}',
        );
      }

      // ── IPM ───────────────────────────────────────────────────────────────
      if (plant.ipmReminderEnabled && plant.ipmIntervalDays > 0) {
        final next = _nextDueDate(
          plant: plant,
          notes: notes,
          category: NoteCategory.ipm,
          intervalDays: plant.ipmIntervalDays,
        );
        final days = next.difference(now).inDays;
        consider(
          next,
          days <= 0
              ? 'IPM check — ${plant.name} today'
              : 'IPM in ${days}d — ${plant.name}',
        );
      }
    }

    return label;
  }

  /// Computes the next due date for a care [category] given the plant's
  /// [intervalDays] and the most recent matching note timestamp.
  ///
  /// Falls back to `plant.startDate + intervalDays` when no note exists.
  static DateTime _nextDueDate({
    required Plant plant,
    required List<PlantNote> notes,
    required NoteCategory category,
    required int intervalDays,
  }) {
    final relevant = notes
        .where(
            (n) => n.plantId == plant.id && n.category == category)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final lastDate =
        relevant.isNotEmpty ? relevant.first.createdAt : plant.startDate;
    return lastDate.add(Duration(days: intervalDays));
  }
}
