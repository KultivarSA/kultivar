// Boot-the-app smoke test.
//
// Purpose: catch first-run-flow regressions cheaply.  If the home
// screen ever stops rendering plant cards after a populated repo
// loads, this test fails *before* the next test build hits a
// reviewer's TestFlight or a user's emulator.
//
// What it covers:
//
//   1. The widget tree boots without throwing under a representative
//      service stack — GrowRepository, SubscriptionService,
//      CurrencyService — wired through MultiProvider the same way
//      `KultivarApp` wires them in production.
//
//   2. The shape of data the user sees after tapping "Explore with
//      sample data" actually reaches the rendered grid.  We seed the
//      repository with a subset of what `DemoDataService.seed`
//      produces (the parts that don't require Hive / native plugins);
//      if that wiring breaks (e.g. a future Provider refactor drops
//      the GrowRepository, or HomeScreen starts reading from
//      somewhere new), this test catches the regression.
//
//   3. The home grid actually renders cards — not an empty state,
//      not a perpetual skeleton.  We assert by visible plant name +
//      visible space name; reliable across theme changes.
//
// What it does NOT cover (deliberate scope cut):
//
//   • The full `DemoDataService.seed` env-log insertion path —
//     that one line writes to Hive which requires a path-provider
//     mock.  We mirror the data shape directly via the repo API,
//     which is a faithful representation of what the user sees.
//   • Onboarding navigation chrome — pumped directly into Home so
//     this stays a unit-grade widget test (sub-second), not a slow
//     integration_test.
//   • The Costs / Archive / Analytics tabs — single-screen scope.
//     Add a sibling smoke test if those grow risky.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/l10n/app_localizations.dart';
import 'package:kultivar/models/grow_space.dart';
import 'package:kultivar/models/plant.dart';
import 'package:kultivar/models/strain.dart';
import 'package:kultivar/repository/grow_repository.dart';
import 'package:kultivar/screens/home_screen.dart';
import 'package:kultivar/services/currency_service.dart';
import 'package:kultivar/services/hive_service.dart';
import 'package:kultivar/services/subscription_service.dart';
import 'package:kultivar/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the same MultiProvider shell `KultivarApp` builds in
/// production, but anchored at a chosen child widget.  Keeps the
/// test honest about real provider scope — if a widget reads from a
/// provider that isn't here, the test fails loudly with a clear
/// "ProviderNotFoundException".
Widget _bootShell({
  required GrowRepository repo,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<GrowRepository>.value(value: repo),
      ChangeNotifierProvider<SubscriptionService>(
        // Default-construct: free tier, no RevenueCat init.  All
        // gated features simply remain locked, which is what the
        // home grid sees on a fresh install anyway.
        create: (_) => SubscriptionService(),
      ),
      ChangeNotifierProvider<CurrencyService>(
        // Default symbol — CurrencyService picks one from the OS
        // locale on first use.  We don't drive any currency text
        // through Home directly in this test but it's wired so
        // descendant widgets (e.g. cost banners) don't crash.
        create: (_) => CurrencyService(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Seeds the repository with a small, deterministic set of spaces
/// and plants — same shape `DemoDataService.seed` produces, minus
/// the Hive-backed env-log insertion.  This is the "what the user
/// sees after Explore with sample data" snapshot, modulo
/// historical analytics.
void _seedFakeDemo(GrowRepository repo) {
  // ── Strains ────────────────────────────────────────────────────
  final fixedCreatedAt = DateTime.utc(2026, 1, 1);
  repo.addStrain(Strain(
    id: 's-blue-dream',
    name: 'Blue Dream',
    genetics: 'Blueberry × Haze',
    type: 'Hybrid',
    expectedFlowerDays: 63,
    createdAt: fixedCreatedAt,
  ));
  repo.addStrain(Strain(
    id: 's-og-kush',
    name: 'OG Kush',
    genetics: 'Chemdawg × Hindu Kush',
    type: 'Indica',
    expectedFlowerDays: 56,
    createdAt: fixedCreatedAt,
  ));

  // ── Spaces ─────────────────────────────────────────────────────
  const vegTent = GrowSpace(
    id: 'space-veg',
    name: 'Veg Tent',
    type: 'Indoor Tent',
    notes: 'T5 LED, 18/6 schedule.',
    tempMin: 20, tempMax: 28,
    humidityMin: 50, humidityMax: 70,
    wattage: 200, areaSqM: 0.9,
  );
  const flowerRoom = GrowSpace(
    id: 'space-flower',
    name: 'Flower Room',
    type: 'Flower Room',
    notes: 'HPS 1000W + supplemental LED.',
    tempMin: 20, tempMax: 27,
    humidityMin: 40, humidityMax: 55,
    wattage: 1200, areaSqM: 2.4,
  );
  repo.addGrowSpace(vegTent);
  repo.addGrowSpace(flowerRoom);

  // ── Plants ─────────────────────────────────────────────────────
  // Two active plants per space so the cards have visible card
  // bodies (not just space chrome).  The names are explicit so
  // the test can assert them.
  final now = DateTime.now();
  repo.addPlant(Plant(
    id: 'plant-1',
    name: 'Blue Dream #1',
    strain: 'Blue Dream',
    growSpaceId: vegTent.id,
    startDate: now.subtract(const Duration(days: 14)),
    status: PlantStatus.growing,
  ));
  repo.addPlant(Plant(
    id: 'plant-2',
    name: 'Blue Dream #2',
    strain: 'Blue Dream',
    growSpaceId: vegTent.id,
    startDate: now.subtract(const Duration(days: 12)),
    status: PlantStatus.growing,
  ));
  repo.addPlant(Plant(
    id: 'plant-3',
    name: 'OG Kush #1',
    strain: 'OG Kush',
    growSpaceId: flowerRoom.id,
    startDate: now.subtract(const Duration(days: 45)),
    status: PlantStatus.growing,
  ));
  repo.addPlant(Plant(
    id: 'plant-4',
    name: 'OG Kush #2',
    strain: 'OG Kush',
    growSpaceId: flowerRoom.id,
    startDate: now.subtract(const Duration(days: 50)),
    status: PlantStatus.growing,
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempHiveDir;

  setUp(() async {
    // GrowRepository's debounced writes are routed through
    // SharedPreferences.  We never advance the debounce timer in
    // this test, but the streak-update side path can fire on the
    // very first addPlant call and needs the mock to exist.
    SharedPreferences.setMockInitialValues({});

    // HomeScreen reads `repo.environmentLogs`, which lazy-loads via
    // HiveService.allEnvironmentLogs().  We can't call the
    // production HiveService.init() under test (it uses
    // `Hive.initFlutter()` which needs the path-provider plugin),
    // so we use the @visibleForTesting initializer with a fresh
    // temp dir per test.
    tempHiveDir = await Directory.systemTemp.createTemp('kultivar_hive_');
    await HiveService.initForTests(tempHiveDir.path);
  });

  tearDown(() async {
    await HiveService.resetForTests();
    if (tempHiveDir.existsSync()) {
      tempHiveDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Home renders space + plant cards after demo seed',
      (tester) async {
    final repo = GrowRepository();
    _seedFakeDemo(repo);

    await tester.pumpWidget(_bootShell(
      repo: repo,
      child: const HomeScreen(),
    ));

    // First frame — let providers settle and any post-frame work
    // (skeleton dissolves, sliver builds out the visible viewport)
    // complete.  We advance by 400 ms which is the comfortable
    // ceiling above the GrowRepository's 300 ms persistence
    // debounce; without this the debounced SharedPreferences
    // write fires after teardown and the binding flags a pending
    // timer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // ── Plant cards visible ───────────────────────────────────
    //
    // We assert two of the four seeded names show.  Asserting all
    // four would over-couple to the SliverList's overscan; asserting
    // a single one would let a "first card renders, rest broken"
    // regression slip past.  Two is the sweet spot — confirms the
    // list iterates without locking the assertion to a magic count.
    expect(find.text('Blue Dream #1'), findsOneWidget,
        reason: 'Active plant should render in the home grid');
    expect(find.text('OG Kush #1'), findsOneWidget,
        reason: 'Active plant in the second space should also render');

    // ── Space chrome visible ──────────────────────────────────
    //
    // The space names are part of the card header, so finding them
    // proves the SliverList has actually built the card containers
    // (not just rendered orphan text nodes).
    //
    // We use findsAtLeastNWidgets(1) instead of findsOneWidget here
    // because the home card surfaces a space name in two slots — the
    // title at AppTypography.titleMedium and (when the type happens
    // to match the name) the type subtitle at AppTypography.bodySmall.
    // We don't care whether both fire, only that the space is on
    // screen *at least* once.
    expect(find.text('Veg Tent'), findsAtLeastNWidgets(1),
        reason: 'First space header should be rendered');
    expect(find.text('Flower Room'), findsAtLeastNWidgets(1),
        reason: 'Second space header should be rendered');
  });

  testWidgets('Home does not crash on an empty repo', (tester) async {
    // Sibling smoke test — fresh-install path.  Empty repo →
    // empty-state art, no exceptions.  Catches regressions where
    // the home grid starts assuming a non-null first plant /
    // first space.
    final repo = GrowRepository();
    await tester.pumpWidget(_bootShell(
      repo: repo,
      child: const HomeScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The empty repo should NOT have plant cards.  We check by
    // absence of a known seed name; if any of the seed-demo plant
    // names ever appear here it'd mean state is leaking between
    // tests.
    expect(find.text('Blue Dream #1'), findsNothing);
    expect(find.text('OG Kush #1'), findsNothing);

    // And the framework should be in a healthy state — no caught
    // exceptions buffered by the test binding.
    expect(tester.takeException(), isNull,
        reason: 'Empty home should render without throwing');
  });
}
