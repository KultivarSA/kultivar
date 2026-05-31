import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ── Snooze constants & helpers (top-level so the background isolate can use them)
//
// Snooze IDs are derived from the *source* notification's base ID so that
// each plant / space has its own snooze slot.  Cancelling reminders for one
// plant therefore no longer wipes another plant's pending snooze, and an
// archive/delete can target the right slot directly.

/// Derive the snooze notification ID for a given source base ID.
/// The window starts at 510000 to avoid colliding with any other ID range.
int snoozeIdFor(int sourceBase) =>
    (sourceBase & 0x7FFFFFFF) % 100000 + 510000;

/// Encode title + body + source-base into a compact payload for snooze
/// round-tripping.  The [sourceBase] is used in the handler to derive a
/// stable, per-source snooze notification ID.
String _snoozePayload(String title, String body, int sourceBase) =>
    jsonEncode({'t': title, 'b': body, 's': sourceBase});

/// Shared logic: schedule a one-shot notification using [payload] to
/// recover the title, body, and source-base.  The defer interval comes
/// from the user's `snooze_duration_hours` preference (default 4 h) so
/// it can be changed in Settings without code changes here.
Future<void> _scheduleSnoozeNotif(String payload) async {
  String title = 'Care Reminder';
  String body = 'Check on your plants.';
  int sourceBase = 0;
  if (payload.isNotEmpty) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      title = (data['t'] as String?) ?? title;
      body = (data['b'] as String?) ?? body;
      sourceBase = (data['s'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  final plugin = FlutterLocalNotificationsPlugin();
  // Re-initialise in case we're running in a background isolate.
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  tz.initializeTimeZones();

  // Read user's snooze duration directly from SharedPreferences — works
  // in the background isolate without needing to inject UiPreferencesService.
  // Clamped to the same 1–24 h range as the loader for defence in depth.
  int hours = 4;
  try {
    final prefs = await SharedPreferences.getInstance();
    hours = (prefs.getInt('snooze_duration_hours') ?? 4).clamp(1, 24);
  } catch (_) {
    // Fall back to 4 h on any read error — better than not firing at all.
  }

  final fireTime =
      tz.TZDateTime.now(tz.UTC).add(Duration(hours: hours));

  await plugin.zonedSchedule(
    id: snoozeIdFor(sourceBase),
    title: title,
    body: body,
    scheduledDate: fireTime,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'care_reminders',
        'Care Reminders',
        channelDescription: 'Snoozed care reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

/// Foreground/background-app response handler (registered with the plugin).
void _onNotificationResponse(NotificationResponse response) {
  if (response.actionId != 'snooze_4h') return;
  _scheduleSnoozeNotif(response.payload ?? '');
}

/// Background-isolate handler for Android action buttons tapped while the
/// app is fully terminated.  Must be a top-level function.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  if (response.actionId != 'snooze_4h') return;
  _scheduleSnoozeNotif(response.payload ?? '');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  /// Test-only escape hatch.  When true, every schedule / cancel /
  /// permission call short-circuits to `Future.value()` without
  /// touching the platform channel.  The plugin's MethodChannel has
  /// no handler bound under `flutter_test`, so without this flag
  /// every notification call throws `MissingPluginException`.  Set
  /// it true in `setUp()`, leave it false in production.
  @visibleForTesting
  static bool stubAllCalls = false;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Register the iOS notification category that carries the snooze action.
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'care_snooze',
          actions: [
            DarwinNotificationAction.plain(
              'snooze_4h',
              'Snooze',
              // foreground: opens the app when tapped on iOS
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // ── Burping reminders ─────────────────────────
  //
  // Schedules daily repeating notifications at the user's preferred time.
  // Week 1 also schedules a second notification ~12 h later (2x daily).
  // Always cancels previous burping slots before scheduling new ones so
  // changing the schedule / time never stacks up duplicate notifications.

  Future<void> scheduleBurpingReminders({
    required String plantId,
    required String plantName,
    required String schedule,
    TimeOfDay? preferredTime,
  }) async {
    if (kIsWeb) return;

    // Cancel any existing slots first.
    await cancelBurpingReminders(plantId);

    final tod = preferredTime ?? const TimeOfDay(hour: 9, minute: 0);
    final now = tz.TZDateTime.now(tz.local);

    // Build today's fire time; if already past, push to tomorrow.
    var fireTime = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, tod.hour, tod.minute);
    if (fireTime.isBefore(now)) {
      fireTime = fireTime.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'burping_reminder',
        'Burping Reminders',
        channelDescription: 'Reminders to burp curing jars',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final baseId = plantId.hashCode + 2;

    // Primary notification — repeats daily at the preferred time.
    await _notificationsPlugin.zonedSchedule(
      id: baseId,
      title: 'Burping Reminder — $plantName',
      body: _getBurpingInstructions(schedule),
      scheduledDate: fireTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Week 1 only: second daily notification ~12 h after the first.
    if (schedule == 'week1') {
      await _notificationsPlugin.zonedSchedule(
        id: baseId + 1,
        title: 'Burping Reminder — $plantName',
        body: 'Second burp of the day. Open jars for 15–30 minutes.',
        scheduledDate: fireTime.add(const Duration(hours: 12)),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelBurpingReminders(String plantId) async {
    if (kIsWeb) return;
    final baseId = plantId.hashCode + 2;
    await _notificationsPlugin.cancel(id: baseId);
    await _notificationsPlugin.cancel(id: baseId + 1);
  }

  // ── Watering reminders ────────────────────────
  //
  // Schedules 10 exact-date notifications spaced [intervalDays] apart,
  // starting from now + intervalDays. Each fires at [preferredTime] (08:00
  // by default). Cancel-first so updating the interval never stacks duplicates.

  static int _wateringBase(String plantId) =>
      (plantId.hashCode.abs() % 50000) + 110000;

  static int _feedingBase(String plantId) =>
      (plantId.hashCode.abs() % 50000) + 160000;

  static int _ipmBase(String plantId) =>
      (plantId.hashCode.abs() % 50000) + 210000;

  /// How many forward-dated care reminders we schedule per plant per type.
  ///
  /// Android 12+ caps the per-app pending-alarm count at ~500.  Per-plant
  /// care reminders multiply fast:
  ///
  ///   plants × (watering + feeding + IPM) × slots
  ///
  /// With slots = 10 a user with 17 plants would already be at the cap
  /// before space-level reminders, harvest alerts and burping schedules
  /// were even counted.  Five slots keeps a 17-plant grow under 260
  /// pending alarms while still covering:
  ///
  ///   • 10 days at "every 2 days" cadence
  ///   • 35 days at "weekly" cadence
  ///
  /// — comfortably longer than the realistic "user opens the app" window.
  /// On every open the schedulers cancel-and-replay, so users who DO open
  /// the app routinely never run out of future reminders.
  static const int _careSlots = 5;

  Future<void> scheduleWateringReminder({
    required String plantId,
    required String plantName,
    required int intervalDays,
    TimeOfDay? preferredTime,
  }) async {
    if (kIsWeb) return;
    await cancelWateringReminder(plantId);

    final tod = preferredTime ?? const TimeOfDay(hour: 8, minute: 0);
    final now = tz.TZDateTime.now(tz.local);
    final base = _wateringBase(plantId);

    const waterTitle = 'Time to water';
    const waterBody =
        'Your plant is due for watering. Check the soil moisture first.';
    const waterDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'care_reminders',
        'Care Reminders',
        channelDescription: 'Watering and feeding reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: [
          AndroidNotificationAction(
            'snooze_4h',
            'Snooze',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: 'care_snooze'),
    );
    final waterPayload =
        _snoozePayload('$waterTitle — $plantName', waterBody, base);

    for (int i = 0; i < _careSlots; i++) {
      final fireDate = tz.TZDateTime(
        tz.local,
        now.year, now.month, now.day,
        tod.hour, tod.minute,
      ).add(Duration(days: intervalDays * (i + 1)));

      await _notificationsPlugin.zonedSchedule(
        id: base + i,
        title: '$waterTitle — $plantName',
        body: waterBody,
        scheduledDate: fireDate,
        notificationDetails: waterDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: waterPayload,
      );
    }
  }

  Future<void> cancelWateringReminder(String plantId) async {
    if (kIsWeb || stubAllCalls) return;
    final base = _wateringBase(plantId);
    for (int i = 0; i < _careSlots; i++) {
      await _notificationsPlugin.cancel(id: base + i);
    }
    // Also cancel any pending snooze derived from this source — otherwise
    // a snoozed reminder can fire for a plant the user just archived/deleted.
    await _notificationsPlugin.cancel(id: snoozeIdFor(base));
  }

  // ── Feeding reminders ─────────────────────────

  Future<void> scheduleFeedingReminder({
    required String plantId,
    required String plantName,
    required int intervalDays,
    TimeOfDay? preferredTime,
  }) async {
    if (kIsWeb) return;
    await cancelFeedingReminder(plantId);

    final tod = preferredTime ?? const TimeOfDay(hour: 8, minute: 0);
    final now = tz.TZDateTime.now(tz.local);
    final base = _feedingBase(plantId);

    const feedTitle = 'Feeding time';
    const feedBody =
        'Your plant is due for nutrients. Prepare your feed solution.';
    const feedDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'care_reminders',
        'Care Reminders',
        channelDescription: 'Watering and feeding reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: [
          AndroidNotificationAction(
            'snooze_4h',
            'Snooze',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: 'care_snooze'),
    );
    final feedPayload =
        _snoozePayload('$feedTitle — $plantName', feedBody, base);

    for (int i = 0; i < _careSlots; i++) {
      final fireDate = tz.TZDateTime(
        tz.local,
        now.year, now.month, now.day,
        tod.hour, tod.minute,
      ).add(Duration(days: intervalDays * (i + 1)));

      await _notificationsPlugin.zonedSchedule(
        id: base + i,
        title: '$feedTitle — $plantName',
        body: feedBody,
        scheduledDate: fireDate,
        notificationDetails: feedDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: feedPayload,
      );
    }
  }

  Future<void> cancelFeedingReminder(String plantId) async {
    if (kIsWeb || stubAllCalls) return;
    final base = _feedingBase(plantId);
    for (int i = 0; i < _careSlots; i++) {
      await _notificationsPlugin.cancel(id: base + i);
    }
    await _notificationsPlugin.cancel(id: snoozeIdFor(base));
  }

  // ── IPM reminders ────────────────────────────

  Future<void> scheduleIpmReminder({
    required String plantId,
    required String plantName,
    required int intervalDays,
    TimeOfDay? preferredTime,
  }) async {
    if (kIsWeb) return;
    await cancelIpmReminder(plantId);

    final tod = preferredTime ?? const TimeOfDay(hour: 8, minute: 0);
    final now = tz.TZDateTime.now(tz.local);
    final base = _ipmBase(plantId);

    const ipmTitle = 'IPM check';
    const ipmBody = 'Time for your preventative spray or pest inspection.';
    const ipmDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'care_reminders',
        'Care Reminders',
        channelDescription: 'Watering, feeding, and IPM reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: [
          AndroidNotificationAction(
            'snooze_4h',
            'Snooze',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: 'care_snooze'),
    );
    final ipmPayload =
        _snoozePayload('$ipmTitle — $plantName', ipmBody, base);

    for (int i = 0; i < _careSlots; i++) {
      final fireDate = tz.TZDateTime(
        tz.local,
        now.year, now.month, now.day,
        tod.hour, tod.minute,
      ).add(Duration(days: intervalDays * (i + 1)));

      await _notificationsPlugin.zonedSchedule(
        id: base + i,
        title: '$ipmTitle — $plantName',
        body: ipmBody,
        scheduledDate: fireDate,
        notificationDetails: ipmDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: ipmPayload,
      );
    }
  }

  Future<void> cancelIpmReminder(String plantId) async {
    if (kIsWeb) return;
    final base = _ipmBase(plantId);
    for (int i = 0; i < _careSlots; i++) {
      await _notificationsPlugin.cancel(id: base + i);
    }
    await _notificationsPlugin.cancel(id: snoozeIdFor(base));
  }

  // ── Space-level care reminders ────────────────
  //
  // Keyed by spaceId so all plants in a space share one notification stream.
  // ID ranges are separated from per-plant ranges to avoid collisions.

  static int _spaceWateringBase(String spaceId) =>
      (spaceId.hashCode.abs() % 50000) + 260000;
  static int _spaceFeedingBase(String spaceId) =>
      (spaceId.hashCode.abs() % 50000) + 310000;
  static int _spaceIpmBase(String spaceId) =>
      (spaceId.hashCode.abs() % 50000) + 360000;

  static const _careNotifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'care_reminders',
      'Care Reminders',
      channelDescription: 'Space-level watering, feeding, and IPM reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      actions: [
        AndroidNotificationAction(
          'snooze_4h',
          'Snooze',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: 'care_snooze'),
  );

  Future<void> scheduleSpaceWateringReminder({
    required String spaceId,
    required String spaceName,
    required int intervalDays,
  }) async {
    if (kIsWeb) return;
    await cancelSpaceWateringReminder(spaceId);
    final now = tz.TZDateTime.now(tz.local);
    final base = _spaceWateringBase(spaceId);
    const title = 'Time to water';
    final body = 'All plants in $spaceName are due for watering.';
    final payload = _snoozePayload('$title — $spaceName', body, base);
    for (int i = 0; i < _careSlots; i++) {
      final fireDate = tz.TZDateTime(tz.local, now.year, now.month, now.day,
              8, 0)
          .add(Duration(days: intervalDays * (i + 1)));
      await _notificationsPlugin.zonedSchedule(
        id: base + i,
        title: '$title — $spaceName',
        body: body,
        scheduledDate: fireDate,
        notificationDetails: _careNotifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  Future<void> cancelSpaceWateringReminder(String spaceId) async {
    if (kIsWeb) return;
    final base = _spaceWateringBase(spaceId);
    for (int i = 0; i < _careSlots; i++) {
      await _notificationsPlugin.cancel(id: base + i);
    }
    await _notificationsPlugin.cancel(id: snoozeIdFor(base));
  }

  Future<void> scheduleSpaceFeedingReminder({
    required String spaceId,
    required String spaceName,
    required int intervalDays,
  }) async {
    if (kIsWeb) return;
    await cancelSpaceFeedingReminder(spaceId);
    final now = tz.TZDateTime.now(tz.local);
    final base = _spaceFeedingBase(spaceId);
    const title = 'Feeding time';
    final body = 'Prepare nutrients for all plants in $spaceName.';
    final payload = _snoozePayload('$title — $spaceName', body, base);
    for (int i = 0; i < _careSlots; i++) {
      final fireDate = tz.TZDateTime(tz.local, now.year, now.month, now.day,
              8, 0)
          .add(Duration(days: intervalDays * (i + 1)));
      await _notificationsPlugin.zonedSchedule(
        id: base + i,
        title: '$title — $spaceName',
        body: body,
        scheduledDate: fireDate,
        notificationDetails: _careNotifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  Future<void> cancelSpaceFeedingReminder(String spaceId) async {
    if (kIsWeb) return;
    final base = _spaceFeedingBase(spaceId);
    for (int i = 0; i < _careSlots; i++) {
      await _notificationsPlugin.cancel(id: base + i);
    }
    await _notificationsPlugin.cancel(id: snoozeIdFor(base));
  }

  Future<void> scheduleSpaceIpmReminder({
    required String spaceId,
    required String spaceName,
    required int intervalDays,
  }) async {
    if (kIsWeb) return;
    await cancelSpaceIpmReminder(spaceId);
    final now = tz.TZDateTime.now(tz.local);
    final base = _spaceIpmBase(spaceId);
    const title = 'IPM check';
    final body = 'Time for preventative spray or pest inspection in $spaceName.';
    final payload = _snoozePayload('$title — $spaceName', body, base);
    for (int i = 0; i < _careSlots; i++) {
      final fireDate = tz.TZDateTime(tz.local, now.year, now.month, now.day,
              8, 0)
          .add(Duration(days: intervalDays * (i + 1)));
      await _notificationsPlugin.zonedSchedule(
        id: base + i,
        title: '$title — $spaceName',
        body: body,
        scheduledDate: fireDate,
        notificationDetails: _careNotifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  Future<void> cancelSpaceIpmReminder(String spaceId) async {
    if (kIsWeb) return;
    final base = _spaceIpmBase(spaceId);
    for (int i = 0; i < _careSlots; i++) {
      await _notificationsPlugin.cancel(id: base + i);
    }
    await _notificationsPlugin.cancel(id: snoozeIdFor(base));
  }

  /// Legacy single-shot helper — kept for call-sites that haven't migrated yet.
  @Deprecated('Use scheduleBurpingReminders instead')
  Future<void> scheduleBurpingReminder(
    String plantName,
    String schedule,
    int notificationId,
  ) async {
    if (kIsWeb) return;
    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(hours: 8));
    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Burping Reminder: $plantName',
      body: _getBurpingInstructions(schedule),
      scheduledDate: scheduledTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'burping_reminder',
          'Burping Reminders',
          channelDescription: 'Reminders to burp curing jars',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  String _getBurpingInstructions(String schedule) {
    switch (schedule) {
      case 'week1':
        return 'Open jars for 15–30 minutes. Repeat 1–2× today.';
      case 'week2':
        return 'Open jars for 10–15 minutes. Check smell & moisture.';
      case 'week3':
        return 'Open jars for a few minutes. Burp every 2–3 days.';
      case 'week4plus':
        return 'Check humidity (target 58–62 %RH). Burp if needed.';
      default:
        return 'Open curing jars for 15–30 minutes.';
    }
  }

  Future<void> scheduleCuringComplete(
    String plantName,
    DateTime curingEndDate,
    int notificationId,
  ) async {
    if (kIsWeb) return;
    final scheduledTime = tz.TZDateTime.from(curingEndDate, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: '✨ Curing Complete: $plantName',
      body: 'Your plant has finished curing! Ready for storage or use.',
      scheduledDate: scheduledTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'curing_complete',
          'Curing Complete',
          channelDescription: 'Notifications when curing is complete',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleDryingCheckReminder(
    String plantName,
    DateTime checkTime,
    int notificationId,
  ) async {
    if (kIsWeb) return;
    final scheduledTime = tz.TZDateTime.from(checkTime, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: '🌾 Drying Check: $plantName',
      body: 'Check on your drying plant. Humidity should be 45-55%.',
      scheduledDate: scheduledTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'drying_check',
          'Drying Check Reminders',
          channelDescription: 'Reminders to check on drying plants',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Fires an immediate (non-scheduled) heads-up notification when an
  /// environment reading lands outside a space's optimal thresholds.
  ///
  /// [spaceId] is used to derive a stable notification ID so repeated alerts
  /// for the same space overwrite the previous one rather than stacking up.
  Future<void> showEnvironmentAlert({
    required String spaceName,
    required String spaceId,
    required String body,
  }) async {
    if (kIsWeb) return;
    // Derive a stable positive int ID for this space's env-alert slot.
    final id = (spaceId.hashCode & 0x7FFFFFFF) % 100000 + 50000;

    await _notificationsPlugin.show(
      id: id,
      title: '⚠️ Environment Alert: $spaceName',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'env_alert',
          'Environment Alerts',
          channelDescription:
              'Alerts when temperature or humidity leaves the optimal range',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Stale environment alerts ──────────────────
  //
  // Scheduled 48 h after the most recent environment log.  When a new log
  // arrives the previous alert is cancelled and a fresh one is re-armed so
  // the notification only fires if the space truly goes silent for 48 h.
  //
  // ID range: (spaceId.hashCode & 0x7FFFFFFF) % 100000 + 410000

  static int _staleEnvId(String spaceId) =>
      (spaceId.hashCode & 0x7FFFFFFF) % 100000 + 410000;

  static const _staleEnvDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'env_stale',
      'Stale Environment Alerts',
      channelDescription:
          'Alerts when no environment reading has been logged for 48 hours',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Cancels any existing stale-env alert for [spaceId] and schedules a new
  /// one to fire at [fireAt] (defaults to 48 h from now when omitted).
  Future<void> scheduleStaleEnvAlert({
    required String spaceId,
    required String spaceName,
    DateTime? fireAt,
  }) async {
    if (kIsWeb) return;
    final id = _staleEnvId(spaceId);
    await _notificationsPlugin.cancel(id: id);

    final target = fireAt ?? DateTime.now().add(const Duration(hours: 48));
    // Don't schedule in the past.
    if (target.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: '📡 No env reading — $spaceName',
      body: 'No temperature or humidity logged in 48 h. Is your sensor online?',
      scheduledDate: tz.TZDateTime.from(target, tz.local),
      notificationDetails: _staleEnvDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels the stale-env alert for [spaceId] (call when a fresh log arrives).
  Future<void> cancelStaleEnvAlert(String spaceId) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id: _staleEnvId(spaceId));
  }

  // ── Target harvest reminders ──────────────────
  //
  // Two one-shot notifications per plant: 7 days before and 1 day before the
  // target harvest date.  Both are cancelled when the plant is archived.
  //
  // ID range:  base   = (plantId.hashCode & 0x7FFFFFFF) % 50000 + 460000
  //            base+1 = 1-day-before slot

  static int _harvestBase(String plantId) =>
      (plantId.hashCode & 0x7FFFFFFF) % 50000 + 460000;

  static const _harvestDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'harvest_reminder',
      'Harvest Reminders',
      channelDescription: 'Reminders when a plant is approaching harvest',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Schedules (or re-schedules) harvest reminders for [plantId].
  ///
  /// Fires at 08:00 on the day 7 days before [targetDate] (base ID) and
  /// at 08:00 on the day 1 day before [targetDate] (base + 1).
  /// Slots that fall in the past are silently skipped.
  Future<void> scheduleHarvestReminder({
    required String plantId,
    required String plantName,
    required DateTime targetDate,
  }) async {
    if (kIsWeb) return;
    await cancelHarvestReminder(plantId);

    final base = _harvestBase(plantId);
    final now = DateTime.now();

    final offsets = [
      (id: base,     daysBeforeHarvest: 7, label: '7 days'),
      (id: base + 1, daysBeforeHarvest: 1, label: 'tomorrow'),
    ];

    for (final slot in offsets) {
      final fireDate = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        8, 0,
      ).subtract(Duration(days: slot.daysBeforeHarvest));

      if (fireDate.isBefore(now)) continue; // past — skip silently

      await _notificationsPlugin.zonedSchedule(
        id: slot.id,
        title: '🌿 Harvest in ${slot.label} — $plantName',
        body: 'Your target harvest date is approaching. Start preparing.',
        scheduledDate: tz.TZDateTime.from(fireDate, tz.local),
        notificationDetails: _harvestDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Cancels both harvest reminder slots for [plantId].
  Future<void> cancelHarvestReminder(String plantId) async {
    if (kIsWeb || stubAllCalls) return;
    final base = _harvestBase(plantId);
    await _notificationsPlugin.cancel(id: base);
    await _notificationsPlugin.cancel(id: base + 1);
  }

  // ── Android 13+ permission ────────────────────

  /// Requests the POST_NOTIFICATIONS runtime permission on Android 13+.
  ///
  /// No-ops on iOS (handled via [DarwinInitializationSettings]) and on
  /// Android < 13 where the permission does not exist.
  Future<void> requestAndroidPermission() async {
    if (kIsWeb) return;
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> cancelNotification(int notificationId) async {
    if (kIsWeb || stubAllCalls) return;
    await _notificationsPlugin.cancel(id: notificationId);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }
}
