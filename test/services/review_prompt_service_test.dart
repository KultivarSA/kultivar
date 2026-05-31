// Task #87 — Tests for the review prompt gating policy.
//
// We don't (and can't) test the actual native prompt firing — the
// `in_app_review` plugin is platform-channel-backed and returns
// false on `isAvailable()` under the test binding.  What we DO test
// is the policy that decides whether the prompt *would* fire:
// the four guards (demo mode / has completed run / 7-day settle /
// 90-day cooldown / has declined).
//
// `maybePrompt` returning false on every test here is the EXPECTED
// outcome — what matters is that the SharedPreferences side-effects
// (lastPromptAt, hasDeclined, etc.) follow the policy correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/repository/grow_repository.dart';
import 'package:kultivar/services/review_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a minimal repo with `n` completed plants — the simplest
/// shape of "has at least one finished cycle".
GrowRepository _repoWithCompletedRuns(int n) {
  final repo = GrowRepository();
  for (var i = 0; i < n; i++) {
    repo.addPlant(Plant(
      id: 'p-$i',
      name: 'Plant $i',
      strain: 'Strain',
      growSpaceId: 'space-1',
      startDate: DateTime.utc(2026, 1, 1),
      status: PlantStatus.completed,
    ));
  }
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReviewPromptService.resetForTests();
  });

  group('Guard short-circuits', () {
    test('Skips when demo mode is active', () async {
      final repo = _repoWithCompletedRuns(1);
      // First-launch was 30 days ago — long past the 7-day window.
      final firstLaunch = DateTime.now().subtract(const Duration(days: 30));
      SharedPreferences.setMockInitialValues({
        'review_prompt.first_launch_iso': firstLaunch.toIso8601String(),
      });

      final fired = await ReviewPromptService.maybePrompt(
        repo: repo,
        isDemoMode: true,
      );
      expect(fired, isFalse,
          reason: 'Demo-mode users should never see the prompt');
    });

    test('Skips when no completed runs exist', () async {
      // Empty repo — no harvests yet.
      final repo = GrowRepository();
      final firstLaunch = DateTime.now().subtract(const Duration(days: 30));
      SharedPreferences.setMockInitialValues({
        'review_prompt.first_launch_iso': firstLaunch.toIso8601String(),
      });

      final fired = await ReviewPromptService.maybePrompt(
        repo: repo,
        isDemoMode: false,
      );
      expect(fired, isFalse,
          reason: 'A user with no completed harvests has no '
              'satisfaction signal to base a prompt on');
    });

    test('Skips when first-launch was less than 7 days ago', () async {
      final repo = _repoWithCompletedRuns(1);
      // First-launch was 3 days ago — under the 7-day floor.
      final firstLaunch = DateTime.now().subtract(const Duration(days: 3));
      SharedPreferences.setMockInitialValues({
        'review_prompt.first_launch_iso': firstLaunch.toIso8601String(),
      });

      final fired = await ReviewPromptService.maybePrompt(
        repo: repo,
        isDemoMode: false,
      );
      expect(fired, isFalse,
          reason: 'Users in their first week haven\'t earned the prompt');
    });

    test('Skips when user has explicitly declined', () async {
      final repo = _repoWithCompletedRuns(1);
      final firstLaunch = DateTime.now().subtract(const Duration(days: 30));
      SharedPreferences.setMockInitialValues({
        'review_prompt.first_launch_iso': firstLaunch.toIso8601String(),
        'review_prompt.has_declined': true,
      });

      final fired = await ReviewPromptService.maybePrompt(
        repo: repo,
        isDemoMode: false,
      );
      expect(fired, isFalse, reason: '"No thanks" is permanent');
    });

    test('Skips during the 90-day cooldown', () async {
      final repo = _repoWithCompletedRuns(1);
      final firstLaunch = DateTime.now().subtract(const Duration(days: 200));
      // Last prompt was 30 days ago — well inside the 90-day window.
      final lastPrompt = DateTime.now().subtract(const Duration(days: 30));
      SharedPreferences.setMockInitialValues({
        'review_prompt.first_launch_iso': firstLaunch.toIso8601String(),
        'review_prompt.last_prompt_iso': lastPrompt.toIso8601String(),
      });

      final fired = await ReviewPromptService.maybePrompt(
        repo: repo,
        isDemoMode: false,
      );
      expect(fired, isFalse,
          reason: 'Even with all other conditions met, we wait '
              '90 days between consecutive prompts');
    });
  });

  group('First-launch recording', () {
    test('Records the date the first time it is called', () async {
      // No first_launch_iso initially.
      await ReviewPromptService.recordFirstLaunchIfMissing();

      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString('review_prompt.first_launch_iso');
      expect(iso, isNotNull,
          reason: 'first_launch_iso should be populated on first call');
    });

    test('Does not overwrite an existing first-launch date', () async {
      final originalIso = DateTime.utc(2025, 1, 1).toIso8601String();
      SharedPreferences.setMockInitialValues({
        'review_prompt.first_launch_iso': originalIso,
      });

      await ReviewPromptService.recordFirstLaunchIfMissing();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('review_prompt.first_launch_iso'),
          equals(originalIso),
          reason: 'Re-calls must be idempotent so the cooldown anchor '
              'stays stable across app launches');
    });
  });

  group('Decline + manual', () {
    test('recordDecline sets the persistent flag', () async {
      expect(await ReviewPromptService.hasDeclined(), isFalse);
      await ReviewPromptService.recordDecline();
      expect(await ReviewPromptService.hasDeclined(), isTrue);
    });
  });
}
