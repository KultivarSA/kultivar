# Kultivar test suite

This is the starter test suite — covering the highest-value, lowest-cost
targets first. The bootstrap commit shipped 51 tests across seven files;
the Q10 backlog pass added another 38 across the storage round-trip,
workflow state machine, community gating, backup-crypto edge cases, and
the first two widget tests. Q11 added 42 direct tests for the four
collection classes that GrowRepository delegates to. A3 added 8 widget
tests for the new line-art empty-state set (one per `EmptyArt` value
plus EmptyState's contract guards). We're now at **~256 tests**.

## Layout

```
test/
├── models/        Pure data classes — JSON round-trips, computed props
├── services/      Service unit tests (currency, snooze IDs, storage,
│                  community, backup crypto, …)
├── repository/    GrowRepository CRUD without Hive / network deps
├── utils/         Pure utility functions (temp conversion, etc.)
├── widgets/       Widget tests — interaction + value forwarding
├── workflows/     PlantWorkflowService state-machine tests
└── widget_test.dart  Toolchain sanity check (not a real widget test yet)
```

## Running locally

```sh
flutter test                         # all tests
flutter test test/models/            # one folder
flutter test --coverage              # with lcov coverage
flutter test test/models/grow_expense_test.dart  # one file
```

## Conventions

- One `_test.dart` file per production file, mirroring the lib/ layout.
- Use `group()` per logical chunk; tests should read like sentences:
  `'returns null when sunrise or sunset missing'`, not `'test1'`.
- For services that touch SharedPreferences, call
  `SharedPreferences.setMockInitialValues({})` in `setUp()`.
- For GrowRepository tests, **never call `load()`**. Start with empty
  state and call mutations directly — the 300ms debounced flush never
  fires in tests because we don't pump time.

## Where to add coverage next

Priority order (from highest user-impact to lowest):

1. **`Plant.copyWith` sentinel pattern** — the `_unset` token is subtle
   and breakage could silently nuke fields. See `lib/models/plant.dart`.
2. **`HarvestLog.copyWith` with `_AbsentMark`** — same risk.
3. ~~`StorageService.buildBackupPayload` / `restoreFromPayload`~~ — done
   in Q10 (`test/services/storage_service_test.dart`, 12 tests).
4. **`AnalyticsService`** — yield-per-watt, cost-per-gram, time-to-flower
   computations.  Pure functions over repository data — should be easy.
5. ~~`PlantWorkflowService` stage transitions~~ — done in Q10
   (`test/workflows/plant_workflow_service_test.dart`, 8 tests).
6. ~~`CommunityService` short-circuiting~~ — done in Q10
   (`test/services/community_service_test.dart`, 9 tests).
7. ~~Widget tests — start with `HarvestQualitySheet` and
   `DeficiencyWizardSheet`~~ — done in Q10
   (`test/widgets/harvest_quality_sheet_test.dart`, 5 tests +
   `test/widgets/deficiency_wizard_sheet_test.dart`, 5 tests).
8. **`HomeRemindersBuilder`** — extracted from `home_screen.dart` in Q8
   so it's now a pure function over `Plant`/`PlantNote`/`GrowSpace`
   lists.  Worth covering the urgency-ordering + due-soon thresholds.

### Gotchas worth knowing

- **Widget tests of bottom sheets**: `showModalBottomSheet` hangs
  `pumpAndSettle` under the test scheduler.  Pump the wizard widget
  directly inside a bare `Scaffold` instead — see
  `deficiency_wizard_sheet_test.dart` for the pattern.
- **Notifications in tests**: `NotificationService.stubAllCalls = true`
  in `setUp()` short-circuits every cancel/schedule.  Without it, the
  platform channel throws `MissingPluginException`.
- **Surface size**: long sheets render past the 600-px default test
  surface.  `await tester.binding.setSurfaceSize(Size(800, 1400))`
  plus `addTearDown(() => tester.binding.setSurfaceSize(null))` gives
  you room to reach below-the-fold controls.

## What we deliberately don't test (yet)

- **Hive integration** — env logs.  Hive needs `setUp(Hive.init...)` and
  produces real disk I/O.  Worth doing eventually inside an
  `integration_test/` harness, but doesn't fit the unit-test runner.
- **Notification scheduling** — `flutter_local_notifications` doesn't
  have a test mock.  We do test the pure `snoozeIdFor` function though.
- **Image picker / file picker** — UI-driven, awkward to test without
  golden + tap simulation.
- **Subscription flows** — RevenueCat calls live network; the placeholder
  guard is tested implicitly by being a one-line `isEmpty` check.

## CI

`.github/workflows/test.yml` runs `flutter analyze --no-fatal-infos`
followed by `flutter test --coverage` on every push and PR. Coverage
lcov is uploaded as a build artefact.
