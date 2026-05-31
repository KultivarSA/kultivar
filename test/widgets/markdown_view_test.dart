import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/legal/privacy_policy.dart';
import 'package:kultivar/legal/terms_of_service.dart';
import 'package:kultivar/widgets/markdown_view.dart';

void main() {
  group('MarkdownView block parser (smoke + structural)', () {
    testWidgets('renders an H1 heading from a # prefix', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MarkdownView(source: '# Heading')),
      ));
      expect(find.text('Heading'), findsOneWidget);
    });

    testWidgets('renders bullet items from "- " lines', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MarkdownView(source: '- First\n- Second\n- Third'),
        ),
      ));
      // SelectableText renders each item; the body text is the
      // bullet content (without the dash).
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('renders a horizontal rule from "---" on its own line',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MarkdownView(source: 'Above\n\n---\n\nBelow'),
        ),
      ));
      expect(find.text('Above'), findsOneWidget);
      expect(find.text('Below'), findsOneWidget);
      // Divider widget appears for the horizontal rule.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets(
        'inline **bold** + [link](url) markers render as styled spans',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MarkdownView(
            source:
                'Plain **bold** and a [click here](https://example.com) span.',
          ),
        ),
      ));
      // The whole compiled string should be present in the
      // SelectableText payload — we don't try to assert individual
      // span styling (that would couple the test to TextSpan tree
      // shape), but the text content must round-trip without the
      // markdown markers.
      final selectable =
          tester.widget<SelectableText>(find.byType(SelectableText));
      final compiled = (selectable.textSpan!.toPlainText());
      expect(compiled, contains('Plain bold and a click here span.'));
      // No markdown markers should leak through.
      expect(compiled, isNot(contains('**')));
      expect(compiled, isNot(contains('[click here]')));
    });
  });

  group('Bundled legal documents are renderable', () {
    // Smoke tests — the real protection here is that the full
    // privacy policy + terms of service strings parse + render
    // without throwing.  If we accidentally introduce a malformed
    // markdown marker that crashes the renderer (e.g. an unclosed
    // bold), this catches it before the App Store reviewer does.

    testWidgets('Privacy Policy renders without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MarkdownView(source: kPrivacyPolicyMarkdown)),
      ));
      // First H1 of the doc should be on screen.
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('Terms of Service renders without throwing',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MarkdownView(source: kTermsOfServiceMarkdown)),
      ));
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    test('Document version constants match the YYYY-MM-DD shape', () {
      // App store reviewers (and us, when we run a "what changed
      // between two builds" audit) rely on the version stamp being
      // sortable.  Lock the shape so a future copy-edit doesn't
      // accidentally drop the date.
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      expect(kPrivacyPolicyVersion, matches(iso));
      expect(kTermsOfServiceVersion, matches(iso));
    });
  });
}
