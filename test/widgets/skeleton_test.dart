import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/widgets/skeleton.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('Skeleton', () {
    testWidgets('renders at the requested dimensions', (tester) async {
      await tester.pumpWidget(_host(
        const Skeleton(width: 120, height: 24),
      ));
      final box = tester.getSize(find.byType(Skeleton));
      expect(box, const Size(120, 24));
    });

    testWidgets('animate: false renders a static box (no shimmer ticker)',
        (tester) async {
      // Plain animate=false should NOT register a recurring
      // AnimationController.  We can't easily probe the ticker
      // directly, but we can verify the widget builds, paints,
      // and reaches a steady state via pumpAndSettle without
      // timing out — which a repeating ticker would prevent.
      await tester.pumpWidget(_host(
        const Skeleton(width: 80, height: 16, animate: false),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('shimmer ticker repaints on each frame', (tester) async {
      // The animated path is driven by AnimatedBuilder + an internal
      // controller — pumping should advance frames without throwing.
      await tester.pumpWidget(_host(
        const Skeleton(width: 80, height: 16),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('Composed primitives', () {
    testWidgets('SkeletonLine renders', (tester) async {
      await tester.pumpWidget(_host(const SkeletonLine(width: 150)));
      expect(find.byType(SkeletonLine), findsOneWidget);
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('SkeletonCircle renders with equal sides', (tester) async {
      await tester.pumpWidget(_host(const SkeletonCircle(diameter: 32)));
      final box = tester.getSize(find.byType(SkeletonCircle));
      expect(box, const Size(32, 32));
    });

    testWidgets('SkeletonCard wraps its child in the card chrome',
        (tester) async {
      await tester.pumpWidget(_host(const SkeletonCard(
        child: SkeletonLine(width: 80),
      )));
      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.byType(SkeletonLine), findsOneWidget);
    });
  });

  group('Domain skeletons', () {
    testWidgets('SkeletonSpaceCard composes circle + lines + thumbnails',
        (tester) async {
      await tester.pumpWidget(_host(const SkeletonSpaceCard()));
      // 1 header circle + 2 lines in the title stack + 1 trailing
      // line + 3 thumbnail boxes = at least 4 Skeleton instances.
      expect(find.byType(SkeletonCircle), findsOneWidget);
      expect(find.byType(SkeletonLine), findsAtLeast(3));
      // 3 thumbnail Skeletons are plain Skeleton (not the line
      // helper), bringing the total to ≥ 7.
      expect(find.byType(Skeleton), findsAtLeast(7));
    });

    testWidgets('SkeletonBenchmarkCard mirrors the loaded card shape',
        (tester) async {
      await tester.pumpWidget(_host(const SkeletonBenchmarkCard()));
      expect(find.byType(SkeletonCircle), findsOneWidget);
      expect(find.byType(SkeletonLine), findsAtLeast(2));
    });

    testWidgets('SkeletonWeatherCard renders without exceptions',
        (tester) async {
      await tester.pumpWidget(_host(const SkeletonWeatherCard()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SkeletonWeatherCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SkeletonImage renders at the requested dimensions',
        (tester) async {
      await tester.pumpWidget(_host(
        const SkeletonImage(width: 60, height: 60),
      ));
      final box = tester.getSize(find.byType(SkeletonImage));
      expect(box, const Size(60, 60));
    });
  });
}
