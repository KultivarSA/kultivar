import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/whats_new_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Reset to a clean SharedPreferences store before every test so
    // each transition is exercised in isolation.  shared_preferences
    // ships an in-memory mock that this call resets.
    SharedPreferences.setMockInitialValues({});
  });

  group('WhatsNewService', () {
    test('fresh install returns false and stashes current build', () async {
      // Arrange:  no stored value (the setUp clears everything).
      // Act
      final shouldShow = await WhatsNewService.shouldShow(1);
      // Assert:  no sheet on first run -- onboarding covers v1.
      expect(shouldShow, isFalse);
      // The stashed marker should equal current so the next launch
      // on the same build returns false too.
      expect(await WhatsNewService.shouldShow(1), isFalse);
    });

    test('same build returns false on repeat launch', () async {
      await WhatsNewService.markSeen(5);
      expect(await WhatsNewService.shouldShow(5), isFalse);
    });

    test('higher build returns true exactly once until markSeen', () async {
      await WhatsNewService.markSeen(5);
      // First check after upgrade -> show.
      expect(await WhatsNewService.shouldShow(6), isTrue);
      // shouldShow is idempotent -- it doesn't auto-mark.  Only
      // markSeen flips the stored value.  This lets the caller
      // pop the sheet, wait for the user to interact, THEN
      // commit.  Until they do, every shouldShow call still
      // returns true (e.g. user backgrounds the app mid-sheet).
      expect(await WhatsNewService.shouldShow(6), isTrue);
      // Once marked, subsequent checks behave as "same build".
      await WhatsNewService.markSeen(6);
      expect(await WhatsNewService.shouldShow(6), isFalse);
    });

    test('downgrade returns false (no notification)', () async {
      await WhatsNewService.markSeen(10);
      // Sideloaded older AAB or QA-installed downgrade -- the user
      // already saw the What's New for build 10 when they upgraded.
      // Showing the sheet for a "downgrade to 8" doesn't make sense.
      expect(await WhatsNewService.shouldShow(8), isFalse);
    });

    test('resetForTest restores fresh-install behaviour', () async {
      await WhatsNewService.markSeen(7);
      await WhatsNewService.resetForTest();
      // After reset, the very next call should behave like a fresh
      // install (return false + stash the new current build).
      expect(await WhatsNewService.shouldShow(9), isFalse);
      // Now we're at "stored == 9", so 9 is "same build".
      expect(await WhatsNewService.shouldShow(9), isFalse);
      // And 10 is an upgrade.
      expect(await WhatsNewService.shouldShow(10), isTrue);
    });
  });
}
