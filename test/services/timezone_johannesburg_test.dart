import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  // SA3 — Africa/Johannesburg timezone smoke test.
  //
  // The notification-scheduling layer composes `TZDateTime` values
  // from the host machine's local time plus the user-picked time of
  // day.  When we ship to South Africa, the host timezone is
  // Africa/Johannesburg (SAST = UTC+2, no DST).  These tests pin the
  // contract that the `timezone` package handles SAST correctly so a
  // 9 AM reminder fires at 9 AM SAST regardless of which UTC offset
  // the test runner happens to be in.
  //
  // Also serves as a regression net for the UP4 timezone 0.9 → 0.11
  // upgrade — if the package ever changes how `TZDateTime` parses
  // SAST, these tests light up before any reminder mis-fires in the
  // real app.

  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('SAST (Africa/Johannesburg)', () {
    test('database has the location and reports a fixed UTC+2 offset',
        () {
      final sast = tz.getLocation('Africa/Johannesburg');
      // SAST is one of the rare timezones with NO daylight-saving
      // transitions in the modern era — the offset is a flat +2 h
      // year-round.  If `timezone` ever drops or relabels this
      // location, every reminder for a SA user would silently fire
      // at the wrong moment.  Lock the invariant.
      final january = tz.TZDateTime(sast, 2026, 1, 15, 12);
      final july = tz.TZDateTime(sast, 2026, 7, 15, 12);
      expect(january.timeZoneOffset, const Duration(hours: 2),
          reason: 'SAST should be UTC+2 in January');
      expect(july.timeZoneOffset, const Duration(hours: 2),
          reason: 'SAST should still be UTC+2 in July — no DST.');
      expect(january.timeZoneName, 'SAST');
    });

    test('9 AM SAST converts to 7 AM UTC consistently', () {
      // Concrete reminder scenario: a SA user sets "watering at 9 AM".
      // We want to confirm that the resulting `TZDateTime` lines up
      // with the right UTC instant — that's what
      // `flutter_local_notifications` schedules against.
      final sast = tz.getLocation('Africa/Johannesburg');
      final nineAm = tz.TZDateTime(sast, 2026, 3, 17, 9, 0);
      expect(nineAm.toUtc().hour, 7,
          reason: '9 AM SAST is 7 AM UTC year-round.');
      expect(nineAm.toUtc().day, 17,
          reason: 'No date roll-over crossing the 02:00 UTC boundary.');
    });

    test('midnight SAST stays on the same calendar date', () {
      // Edge case: a midnight reminder. In UTC this becomes
      // 22:00 on the *previous* day. We confirm the local
      // representation does NOT roll back the date so the reminder
      // label "set on 2026-03-17" matches what the user expects.
      final sast = tz.getLocation('Africa/Johannesburg');
      final midnight = tz.TZDateTime(sast, 2026, 3, 17, 0, 0);
      expect(midnight.day, 17);
      expect(midnight.hour, 0);
      // The corresponding UTC instant is 22:00 on the previous day.
      expect(midnight.toUtc().day, 16);
      expect(midnight.toUtc().hour, 22);
    });

    test('TZDateTime.from preserves the underlying instant when '
        'converting across zones', () {
      // The notification layer often does:
      //   tz.TZDateTime.from(plant.dryingEndDate, tz.local)
      // which converts a `DateTime` (in the host's local zone) to
      // a `TZDateTime` in the requested zone.  Verify the result
      // refers to the same absolute moment.
      final sast = tz.getLocation('Africa/Johannesburg');
      final utc = tz.TZDateTime.utc(2026, 6, 30, 18, 30);
      final inSast = tz.TZDateTime.from(utc, sast);
      expect(inSast.toUtc(), utc,
          reason: 'TZDateTime.from must preserve the underlying '
              'instant — only the wall-clock representation changes.');
      // 18:30 UTC → 20:30 SAST.
      expect(inSast.hour, 20);
      expect(inSast.minute, 30);
    });

    test('addDuration crosses day boundary without DST flicker', () {
      // SA has no DST, but the test pattern matters as a template
      // for adding new locales later (e.g. an EU-based grower whose
      // reminders span a DST boundary).
      final sast = tz.getLocation('Africa/Johannesburg');
      // 2026-04-04 was the historical SA DST cutover date back in the
      // 1940s; modern SA does not observe DST.  We confirm an
      // afternoon → next morning addition stays at exact +1 day +
      // some hours with no second / minute slip.
      final start = tz.TZDateTime(sast, 2026, 4, 4, 14, 30);
      final next = start.add(const Duration(hours: 18));
      expect(next.day, 5);
      expect(next.hour, 8);
      expect(next.minute, 30);
      expect(next.timeZoneOffset, const Duration(hours: 2));
    });
  });
}
