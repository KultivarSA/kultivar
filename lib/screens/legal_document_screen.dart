import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/markdown_view.dart';

/// Generic viewer for the legal documents bundled in `lib/legal/`.
///
/// Used by the "Privacy Policy" and "Terms of Service" tiles in
/// Settings → Legal.  Keeping it generic means we don't need a
/// separate screen per document — any future bundled markdown
/// (cookie policy, EULA, etc.) can reuse this with one tile addition
/// in Settings.
class LegalDocumentScreen extends StatelessWidget {
  /// Title shown in the app bar.  Usually "Privacy Policy" or
  /// "Terms of Service".
  final String title;

  /// Markdown source — typically `kPrivacyPolicyMarkdown` or
  /// `kTermsOfServiceMarkdown`.
  final String markdown;

  /// Optional version stamp.  When provided, renders as a small
  /// muted footer below the document so users + reviewers can see
  /// which revision they're looking at without scrolling back to
  /// the "Last updated" line at the top.
  final String? version;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.markdown,
    this.version,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AppTypography.headlineMedium(context)),
      ),
      body: Column(
        children: [
          Expanded(child: MarkdownView(source: markdown)),
          if (version != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.colBorderFaint),
                ),
              ),
              child: Text(
                'Document revision: $version',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
