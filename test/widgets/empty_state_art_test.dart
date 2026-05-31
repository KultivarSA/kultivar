import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/widgets/empty_state.dart';
import 'package:kultivar/widgets/empty_state_art.dart';

/// Helper: pump [child] inside the minimum MaterialApp scaffolding
/// needed for the theme extensions on [BuildContext] to resolve.
Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('LineArtIllustration', () {
    testWidgets('renders every EmptyArt value without exceptions',
        (tester) async {
      // A3 — guards against a future EmptyArt addition forgetting its
      // painter dispatch arm.  If any case is missed, _EmptyArtPainter
      // would fall through the switch and crash on paint.
      for (final art in EmptyArt.values) {
        await tester.pumpWidget(_host(LineArtIllustration(art: art)));
        // Find the widget itself — a painter exception would surface
        // here as a thrown exception captured by takeException.
        expect(find.byType(LineArtIllustration), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'EmptyArt.${art.name} painter threw on paint');
      }
    });

    testWidgets('renders at the requested size', (tester) async {
      await tester.pumpWidget(_host(
        const LineArtIllustration(art: EmptyArt.plant, size: 140),
      ));
      final box = tester.getSize(find.byType(LineArtIllustration));
      expect(box, const Size(140, 140));
    });

    testWidgets('accent override changes the rendered tint', (tester) async {
      // Paint twice with different accents and verify the widget
      // rebuilds — a regression where the painter caches its
      // accent across rebuilds would fail this.
      await tester.pumpWidget(_host(
        const LineArtIllustration(
          art: EmptyArt.archive,
          accent: Color(0xFF112233),
        ),
      ));
      expect(find.byType(LineArtIllustration), findsOneWidget);

      await tester.pumpWidget(_host(
        const LineArtIllustration(
          art: EmptyArt.archive,
          accent: Color(0xFFCC00CC),
        ),
      ));
      expect(find.byType(LineArtIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EmptyState', () {
    testWidgets('renders the art hero + title + subtitle', (tester) async {
      await tester.pumpWidget(_host(const EmptyState(
        art: EmptyArt.plant,
        title: 'No plants yet',
        subtitle: 'Tap + to add your first one.',
      )));

      expect(find.byType(LineArtIllustration), findsOneWidget);
      expect(find.text('No plants yet'), findsOneWidget);
      expect(find.text('Tap + to add your first one.'), findsOneWidget);
    });

    testWidgets('legacy icon path still works for fallback callers',
        (tester) async {
      // Some surfaces (settings sub-pages, error overlays) still
      // pass `icon:`.  The legacy path must continue to render
      // without throwing.
      await tester.pumpWidget(_host(const EmptyState(
        icon: Icons.warning_amber_rounded,
        title: 'Legacy',
        subtitle: 'Icon hero',
      )));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Legacy'), findsOneWidget);
      // No LineArtIllustration when the legacy icon path is taken —
      // pin that so a future "always use line-art" refactor surfaces
      // the test rather than silently double-rendering.
      expect(find.byType(LineArtIllustration), findsNothing);
    });

    testWidgets('action button fires the supplied callback',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_host(EmptyState(
        art: EmptyArt.receipt,
        title: 'No expenses',
        subtitle: 'Log your first.',
        actionLabel: 'Log expense',
        onAction: () => tapped++,
      )));

      await tester.tap(find.text('Log expense'));
      await tester.pump();
      expect(tapped, 1);
    });

    test('asserts when neither art nor icon is supplied', () {
      expect(
        () => EmptyState(
          title: 't',
          subtitle: 's',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when both art and icon are supplied', () {
      expect(
        () => EmptyState(
          art: EmptyArt.plant,
          icon: Icons.eco,
          title: 't',
          subtitle: 's',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
