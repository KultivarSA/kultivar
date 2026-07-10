import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/subscription_service.dart';
import 'package:kultivar/widgets/pro_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [child] under a real SubscriptionService provider.  The service
/// never touches RevenueCat here — no API key is configured in tests, and
/// we drive the tier through debugSetTier (SharedPreferences is mocked).
Future<SubscriptionService> _pump(WidgetTester tester, Widget child) async {
  final svc = SubscriptionService();
  await tester.pumpWidget(
    ChangeNotifierProvider<SubscriptionService>.value(
      value: svc,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  return svc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProGate', () {
    testWidgets('free tier shows the lock instead of the child',
        (tester) async {
      await _pump(
        tester,
        const ProGate(
          feature: 'PDF Export',
          child: Text('gated content'),
        ),
      );

      expect(find.text('gated content'), findsNothing);
      expect(find.text('PDF Export · Pro'), findsOneWidget);
    });

    testWidgets('lifetime tier shows the child', (tester) async {
      final svc = await _pump(
        tester,
        const ProGate(
          feature: 'PDF Export',
          child: Text('gated content'),
        ),
      );
      await svc.debugSetTier(SubscriptionTier.lifetimeLocal);
      await tester.pump();

      expect(find.text('gated content'), findsOneWidget);
      expect(find.text('PDF Export · Pro'), findsNothing);
    });

    testWidgets('reacts to live tier changes in both directions',
        (tester) async {
      // The CustomerInfoUpdateListener pushes tier changes mid-session
      // (purchase validation, renewal, cancellation) — gates must swap
      // without a rebuild being forced from outside.
      final svc = await _pump(
        tester,
        const ProGate(
          feature: 'Widget',
          child: Text('gated content'),
        ),
      );
      expect(find.text('gated content'), findsNothing);

      await svc.debugSetTier(SubscriptionTier.proCloud);
      await tester.pump();
      expect(find.text('gated content'), findsOneWidget);

      await svc.debugSetTier(SubscriptionTier.free);
      await tester.pump();
      expect(find.text('gated content'), findsNothing);
    });

    testWidgets('ProGate.card renders the locked card copy on free',
        (tester) async {
      await _pump(
        tester,
        ProGate.card(
          feature: 'PDF / CSV Export',
          description: 'Export your grow data.',
          icon: Icons.picture_as_pdf_rounded,
        ),
      );

      expect(find.text('PDF / CSV Export'), findsOneWidget);
      expect(find.text('Export your grow data.'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });
  });

  group('ProLimitBanner', () {
    testWidgets('renders the limit message and upgrade affordance',
        (tester) async {
      await _pump(
        tester,
        const ProLimitBanner(
          message: 'You\'ve reached the free plan\'s 3-plant limit.',
        ),
      );

      expect(find.text('You\'ve reached the free plan\'s 3-plant limit.'),
          findsOneWidget);
      expect(find.text('Upgrade →'), findsOneWidget);
    });
  });
}
