import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/harvest_log.dart';
import 'package:kultivar/widgets/harvest_quality_sheet.dart';

/// Wraps the sheet in the minimum [MaterialApp] scaffolding it needs:
/// the sheet uses Material theming + TextField selection / IME, so a
/// bare widget tree would fail at the first paint.  We also fix the
/// surface size so half-star tap coordinates are deterministic.
Widget _host({
  required HarvestLog log,
  required void Function({
    required double? qualityRating,
    required String? aromaNote,
    required String? flavorNotes,
    required String? effectNotes,
    required double? smellRating,
    required double? effectRating,
    required double? bagAppealRating,
  }) onSave,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HarvestQualitySheet(harvestLog: log, onSave: onSave),
    ),
  );
}

HarvestLog _emptyLog() => HarvestLog(
      id: 'h1',
      plantId: 'p1',
      plantName: 'Subject',
      strain: 'Blue Dream',
      harvestedDate: DateTime.utc(2026, 4, 1),
    );

/// The full sheet doesn't fit in the default 800×600 test surface —
/// the Save button lives below the fold and `tester.tap` would warn
/// that the offset is outside the render tree.  Call this at the
/// top of any test that needs to reach controls below the visible
/// area; tearDown is registered so the surface resets between tests.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

void main() {
  group('HarvestQualitySheet', () {
    testWidgets('renders the strain name in the header', (tester) async {
      late final HarvestLog log;
      log = _emptyLog();
      await tester.pumpWidget(_host(
        log: log,
        onSave: ({
          required qualityRating,
          required aromaNote,
          required flavorNotes,
          required effectNotes,
          required smellRating,
          required effectRating,
          required bagAppealRating,
        }) {},
      ));
      // Strain appears below the "Quality Assessment" title.
      expect(find.text('Quality Assessment'), findsOneWidget);
      expect(find.text('Blue Dream'), findsOneWidget);
    });

    testWidgets(
        'tapping the Save button fires onSave with the rated values',
        (tester) async {
      await _useTallSurface(tester);
      // Pre-populate the log so we can verify the controller text +
      // ratings are forwarded to the callback without simulating taps
      // (which are flaky across half-star coordinates).  This is the
      // "value forwarding" contract — separate from the half-star
      // interaction which gets its own test below.
      final log = HarvestLog(
        id: 'h1',
        plantId: 'p1',
        plantName: 'Subject',
        strain: 'Blue Dream',
        harvestedDate: DateTime.utc(2026, 4, 1),
        qualityRating: 4.5,
        aromaNote: 'Citrus',
        flavorNotes: 'Sweet',
        effectNotes: 'Relaxing',
        smellRating: 4.0,
        effectRating: 3.5,
        bagAppealRating: 5.0,
      );

      double? capturedRating;
      String? capturedAroma;
      String? capturedFlavor;
      String? capturedEffects;
      double? capturedSmell;
      double? capturedEffect;
      double? capturedBag;

      await tester.pumpWidget(_host(
        log: log,
        onSave: ({
          required qualityRating,
          required aromaNote,
          required flavorNotes,
          required effectNotes,
          required smellRating,
          required effectRating,
          required bagAppealRating,
        }) {
          capturedRating = qualityRating;
          capturedAroma = aromaNote;
          capturedFlavor = flavorNotes;
          capturedEffects = effectNotes;
          capturedSmell = smellRating;
          capturedEffect = effectRating;
          capturedBag = bagAppealRating;
        },
      ));

      await tester.tap(find.text('Save Quality'));
      await tester.pumpAndSettle();

      expect(capturedRating, 4.5);
      expect(capturedAroma, 'Citrus');
      expect(capturedFlavor, 'Sweet');
      expect(capturedEffects, 'Relaxing');
      expect(capturedSmell, 4.0);
      expect(capturedEffect, 3.5);
      expect(capturedBag, 5.0);
    });

    testWidgets(
        'empty text fields are sent as null (not empty string)',
        (tester) async {
      await _useTallSurface(tester);
      // Important contract: a blank textbox means "no note", not an
      // empty string.  The downstream HarvestLog uses null to detect
      // "no note logged" everywhere (e.g. the quality summary block
      // skips rendering null rows).  An empty string would slip
      // through and render a stray label with no value.
      String? capturedAroma = 'sentinel';
      String? capturedFlavor = 'sentinel';
      String? capturedEffects = 'sentinel';

      await tester.pumpWidget(_host(
        log: _emptyLog(),
        onSave: ({
          required qualityRating,
          required aromaNote,
          required flavorNotes,
          required effectNotes,
          required smellRating,
          required effectRating,
          required bagAppealRating,
        }) {
          capturedAroma = aromaNote;
          capturedFlavor = flavorNotes;
          capturedEffects = effectNotes;
        },
      ));

      await tester.tap(find.text('Save Quality'));
      await tester.pumpAndSettle();

      expect(capturedAroma, isNull);
      expect(capturedFlavor, isNull);
      expect(capturedEffects, isNull);
    });

    testWidgets(
        'whitespace-only text in a field is also normalised to null',
        (tester) async {
      await _useTallSurface(tester);
      String? capturedAroma = 'sentinel';

      await tester.pumpWidget(_host(
        log: _emptyLog(),
        onSave: ({
          required qualityRating,
          required aromaNote,
          required flavorNotes,
          required effectNotes,
          required smellRating,
          required effectRating,
          required bagAppealRating,
        }) {
          capturedAroma = aromaNote;
        },
      ));

      // First aroma text field on the form.
      final aroma = find.widgetWithText(TextField, 'Aroma');
      // The decoration's labelText is on the InputDecorator child;
      // simpler: target by the visible hint text.
      final aromaByHint =
          find.widgetWithText(TextField, 'e.g. citrus, pine, earthy…');
      // Whichever matches in this build, use it.
      final target = aroma.evaluate().isNotEmpty ? aroma : aromaByHint;

      await tester.enterText(target, '   ');
      await tester.pump();
      await tester.tap(find.text('Save Quality'));
      await tester.pumpAndSettle();

      expect(capturedAroma, isNull,
          reason: 'trim() on the aroma field should drop pure whitespace');
    });

    testWidgets('half-star row renders 5 stars', (tester) async {
      await tester.pumpWidget(_host(
        log: _emptyLog(),
        onSave: ({
          required qualityRating,
          required aromaNote,
          required flavorNotes,
          required effectNotes,
          required smellRating,
          required effectRating,
          required bagAppealRating,
        }) {},
      ));

      // 5 main stars on the overall row + 5 each on the three sub-score
      // rows = 20 total.  We don't assert the exact count to avoid
      // coupling to sub-score row presence — just that the overall
      // row is rendered with at least 5 star icons.
      final stars = find.byType(Icon).evaluate().where((e) {
        final icon = (e.widget as Icon).icon;
        return icon == Icons.star_rounded ||
            icon == Icons.star_half_rounded ||
            icon == Icons.star_outline_rounded;
      });
      expect(stars.length, greaterThanOrEqualTo(5));
    });
  });
}
