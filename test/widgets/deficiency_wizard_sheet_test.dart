import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/widgets/deficiency_wizard_sheet.dart';

/// Pumps the wizard directly — bypassing `showModalBottomSheet`.  We
/// originally drove the sheet via its `.show()` helper, but the modal
/// barrier's fade animation never reaches a terminal state under the
/// test scheduler (Flutter framework issue: the scrim's opacity
/// driver loops forever, hanging `pumpAndSettle` and even bounded
/// `pump` cycles for ten minutes plus).  The widget itself is
/// self-contained — its state machine + Navigator.pop interaction
/// work fine in a bare `Scaffold` host — so we test the contract
/// without the modal scaffolding.
Future<WizardResult?> _mountSheet(WidgetTester tester) async {
  // The wizard sizes itself to 82% of the host's height — give the
  // surface enough room that every CTA button lands in the hit-test
  // box without needing to scroll.
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final completer = _ResultCompleter();

  await tester.pumpWidget(
    MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (ctx) => Scaffold(
            body: PopScope<WizardResult?>(
              canPop: true,
              onPopInvokedWithResult: (didPop, result) {
                completer.set(result);
              },
              child: const DeficiencyWizardSheet(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return completer.future;
}

/// A tiny one-shot holder.  We can't use `Completer<WizardResult?>`
/// directly because PopScope fires on every pop (including the
/// initial route push) — this guard captures only the first non-null
/// pop result.
class _ResultCompleter {
  WizardResult? _result;
  bool _set = false;
  void set(WizardResult? r) {
    if (_set) return;
    _set = true;
    _result = r;
  }

  Future<WizardResult?> get future async => _result;
}

void main() {
  group('DeficiencyWizardSheet', () {
    testWidgets('opens on step 1 (location picker)', (tester) async {
      await _mountSheet(tester);

      // Header copy is the most stable identifier — locale-fixed in
      // English, doesn't depend on which symptom list is rendered.
      expect(find.text('Issue Identifier'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // Step 1 lists 5 location options.  Spot-check two of them so
      // the test fails loudly if the location list shape changes.
      expect(find.text('Lower / older leaves'), findsOneWidget);
      expect(find.text('Upper / newer leaves'), findsOneWidget);
    });

    testWidgets(
        'selecting a location advances to the symptom page (step 2)',
        (tester) async {
      await _mountSheet(tester);

      await tester.tap(find.text('Lower / older leaves'));
      // PageView controller animates over 300ms — pump just past that.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Step 2 of 3'), findsOneWidget);

      // The "lower-leaves" symptom set must include the nitrogen
      // and magnesium prompts.  Asserting these locks the location
      // → symptom mapping (a refactor that wires "upper" symptoms
      // to "lower" would break here, not silently in prod).
      expect(find.text('Yellowing overall'), findsOneWidget);
      expect(find.text('Yellow between veins, green veins stay'),
          findsOneWidget);
    });

    testWidgets(
        'selecting a symptom advances to the diagnosis page (step 3)',
        (tester) async {
      await _mountSheet(tester);

      await tester.tap(find.text('Lower / older leaves'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Yellowing overall'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Likely Diagnosis'), findsOneWidget);
      // Nitrogen-deficiency mapping for "lower yellowing overall".
      expect(find.text('Nitrogen Deficiency'), findsOneWidget);
      expect(find.text('SYMPTOMS'), findsOneWidget);
      expect(find.text('RECOMMENDED FIX'), findsOneWidget);
    });

    testWidgets('tapping Back returns to the previous step',
        (tester) async {
      await _mountSheet(tester);

      await tester.tap(find.text('Lower / older leaves'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Step 2 of 3'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Step 1 of 3'), findsOneWidget);
    });

    testWidgets(
        '"Try Different Symptoms" resets the wizard back to step 1',
        (tester) async {
      await _mountSheet(tester);

      await tester.tap(find.text('Lower / older leaves'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Yellowing overall'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Step 3 of 3'), findsOneWidget);

      // Diagnosis page can render below the fold when the diagnosis
      // copy is long — scroll the button into view before tapping.
      await tester.ensureVisible(find.text('Try Different Symptoms'));
      await tester.pump();
      await tester.tap(find.text('Try Different Symptoms'));
      // Reset spans both a setState (immediate) and a PageView
      // animation (~300ms); pump generously to let both settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Step 1 of 3'), findsOneWidget);
      // The location options must be back on screen so the user
      // doesn't get stranded mid-flow with no controls.
      expect(find.text('Lower / older leaves'), findsOneWidget);
    });
  });
}
